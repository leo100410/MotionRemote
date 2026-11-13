import Foundation
import Network
import Combine
import simd

struct MonitorSample {
    var time: Double
    var acceleration: SIMD3<Float>
    var rotationRate: SIMD3<Float>
    var angles: SIMD3<Float>
    var gap: Double // ms since the previous packet
    var lost: Int
}
struct PlotPoint: Identifiable { let id: Int; let time: Double; let value: Double; let series: String }
struct Phone: Hashable { let name: String; let endpoint: NWEndpoint }

final class MonitorModel: ObservableObject {
    static let window = 10.0
    @Published var phones: [Phone] = []
    @Published var selected = ""
    @Published var address = UserDefaults.standard.string(forKey:"phoneAddress") ?? ""
    @Published var player = 1
    @Published var status = "Disconnected"
    @Published var receiving = false
    @Published var paused = false
    @Published var plots: [String:[PlotPoint]] = [:]
    @Published var lostTimes: [Double] = []
    @Published var buttons: [String] = []
    @Published var summary = ""
    let scene = MonitorScene()
    private(set) var samples: [MonitorSample] = []
    private var attitude = simd_quatf(ix:0,iy:0,iz:0,r:1)
    private var pose: (SpatialPose,Double)?
    private var trail: [(SIMD3<Float>,Double)] = []
    private var counter: UInt32?
    private var lastInput = -Double.infinity
    private var lastRegister = -Double.infinity
    private var slot: UInt8 = 0
    private var identity = DSU.Identity(uuid:UUID())
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var timer: Timer?
    private var generation = UUID()
    private var frame = 0
    private let clock: () -> Double
    init(clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) { self.clock = clock }

    func browse() {
        guard browser == nil else { return }
        let b = NWBrowser(for:.bonjour(type:"_motionremote._udp",domain:nil),using:.udp)
        b.browseResultsChangedHandler = { [weak self] results,_ in
            guard let self else { return }
            self.phones = results.compactMap { result -> Phone? in
                if case let .service(name,_,_,_) = result.endpoint { return Phone(name:name,endpoint:result.endpoint) }
                return nil
            }.sorted { $0.name < $1.name }
            if !self.phones.contains(where: { $0.name == self.selected }) { self.selected = self.phones.first?.name ?? "" }
        }
        b.start(queue:.main); browser = b
        let t = Timer(timeInterval:1.0/30,repeats:true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t,forMode:.common); timer = t
    }
    func connect() {
        disconnect()
        let manual = address.trimmingCharacters(in:.whitespacesAndNewlines)
        let endpoint: NWEndpoint
        if let phone = phones.first(where: { $0.name == selected }), manual.isEmpty {
            endpoint = phone.endpoint
            // Discovery names start with the player: "P2 1a2b3c4d".
            if phone.name.hasPrefix("P"), let p = Int(phone.name.dropFirst().prefix(1)), (1...4).contains(p) { player = p }
        } else if !manual.isEmpty {
            endpoint = .hostPort(host:NWEndpoint.Host(manual),port:26760)
            UserDefaults.standard.set(manual,forKey:"phoneAddress")
        } else { status = "No iPhone found. Start MotionRemote on the phone or enter its address."; return }
        slot = UInt8(player-1); identity = DSU.Identity(uuid:UUID()); let token = generation
        let c = NWConnection(to:endpoint,using:.udp)
        connection = c; status = "Connecting…"
        c.stateUpdateHandler = { [weak self] state in
            guard let self, self.generation == token else { return }
            switch state {
            case .ready: self.status = "Waiting for phone data · Player \(self.player)"; self.register(); self.receive(c,token:token)
            case .failed(let error): self.disconnect(); self.status = error.localizedDescription
            default: break
            }
        }
        c.start(queue:.main)
    }
    func disconnect() {
        generation = UUID(); connection?.cancel(); connection = nil
        receiving = false; status = "Disconnected"; counter = nil; lastInput = -.infinity; lastRegister = -.infinity
        buttons = []; pose = nil
    }
    private func register() {
        connection?.send(content:Data(MonitorWire.register(slot:slot,identity:identity)),completion:.contentProcessed { _ in })
        lastRegister = clock()
    }
    private func receive(_ c: NWConnection, token: UUID) {
        c.receiveMessage { [weak self] data,_,_,error in
            guard let self, self.generation == token else { return }
            if let data { self.consume(Array(data)) }
            if error == nil { self.receive(c,token:token) } else { self.disconnect(); self.status = "Connection closed" }
        }
    }
    func consume(_ b: [UInt8]) {
        guard !paused else { return }
        let now = clock()
        if let state = MonitorWire.state(b,slot:slot) {
            // The counter restarts with the phone app; a silent second accepts any number.
            var lost = 0, gap = 0.0
            if let previous = counter, now-lastInput < 1 {
                guard DSU.isNewer(state.counter,than:previous) else { return }
                lost = Int(state.counter &- previous)-1; gap = (now-lastInput)*1000
            }
            counter = state.counter; lastInput = now
            samples.append(MonitorSample(time:now,acceleration:state.acceleration,rotationRate:state.rotationRate,
                                         angles:MonitorWire.angles(attitude),gap:gap,lost:lost))
            if buttons != state.buttons { buttons = state.buttons }
        } else if let q = MonitorWire.attitude(b,slot:slot) { attitude = q }
        else if let p = MonitorWire.pose(b,slot:slot) { pose = (p,now) }
    }
    private func tick() {
        let now = clock()
        if connection != nil, now-lastRegister > 1 { register() }
        let live = now-lastInput < 0.5
        if live != receiving {
            receiving = live
            if connection != nil { status = live ? "Receiving · Player \(player)" : "Waiting for phone data · Player \(player)" }
        }
        guard !paused else { return }
        samples.removeAll { now-$0.time > Self.window }
        // Metres are small next to the phone model, so the tracked position is enlarged.
        var position = SIMD3<Float>(repeating:0)
        if let (p,time) = pose, p.tracking == 2, now-time < 0.3 { position = p.position*4 }
        // Core Motion's reference has Z up; SceneKit has Y up.
        let rotation = simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0))*attitude
        if live { trail.append((position+rotation.act(SIMD3(0,0.75,0)),now)) }
        trail.removeAll { now-$0.1 > 3 }
        scene.update(rotation:rotation,position:position,trail:trail.map { $0.0 })
        frame += 1
        if frame % 3 == 0 { publish(now:now) }
    }
    private func publish(now: Double) {
        var result: [String:[PlotPoint]] = ["Acceleration (g)":[],"Rotation rate (°/s)":[],"Orientation (°)":[],"Packet gap (ms)":[]]
        // Every second sample keeps the charts light; gaps and losses are never skipped.
        for (i,s) in samples.enumerated() {
            let t = s.time-now
            if i % 2 == 0 {
                for (axis,name) in ["X","Y","Z"].enumerated() {
                    result["Acceleration (g)"]!.append(PlotPoint(id:i*8+axis,time:t,value:Double(s.acceleration[axis]),series:name))
                    result["Rotation rate (°/s)"]!.append(PlotPoint(id:i*8+axis,time:t,value:Double(s.rotationRate[axis]),series:name))
                }
                for (axis,name) in ["Pitch","Roll","Yaw"].enumerated() {
                    result["Orientation (°)"]!.append(PlotPoint(id:i*8+axis,time:t,value:Double(s.angles[axis]),series:name))
                }
            }
            if i % 2 == 0 || s.gap > 25 || s.lost > 0 { result["Packet gap (ms)"]!.append(PlotPoint(id:i,time:t,value:s.gap,series:"Gap")) }
        }
        plots = result
        lostTimes = samples.filter { $0.lost > 0 }.map { $0.time-now }
        let lost = samples.reduce(0) { $0+$1.lost }
        let rate = samples.filter { now-$0.time <= 1 }.count
        let worst = samples.map(\.gap).max() ?? 0
        let tracked = pose.map { $0.0.tracking == 2 && now-$0.1 < 0.3 } ?? false
        summary = samples.isEmpty ? "" : String(format:"%d packets/s · %d lost in %.0f s (%.1f%%) · longest gap %.0f ms · %@",
            rate,lost,Self.window,100*Double(lost)/Double(max(1,lost+samples.count)),worst,tracked ? "camera position tracked" : "orientation only")
    }
}
