import Foundation
import Network
import Combine
import simd

struct FoundPhone: Hashable { let name: String; let endpoint: NWEndpoint }

// Connects to MotionRemote over Wi-Fi like Dolphin does (a DSU client) and decides which sensor drives the sword.
final class SaberLink: ObservableObject {
    enum Source: String { case none = "No tracking", camera = "Camera tracking", motion = "Motion only" }
    struct Input { var source: Source; var position: SIMD3<Float>?; var orientation: simd_quatf }
    @Published var phones: [FoundPhone] = []
    @Published var selected = ""
    @Published var address = UserDefaults.standard.string(forKey:"phoneAddress") ?? ""
    @Published var player = 1
    @Published private(set) var connected = false
    @Published private(set) var status = "Not connected"
    @Published private(set) var source = Source.none
    @Published private(set) var tracking = ""
    @Published private(set) var calibration = ""
    let log: EventLog
    var displayWidth: Float? // physical width of the game's display, metres
    var onButton: ((String) -> Void)?
    private let clock: () -> Double
    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var generation = UUID()
    private var slot: UInt8 = 0
    private var identity = DSU.Identity(uuid:UUID())
    private var lastRegister = -Double.infinity
    // Controller stream
    private var counter: UInt32?
    private var phoneStamp: UInt64 = 0
    private var networkGaps: [Double] = []
    private var cameraYaw = simd_quatf(angle:0,axis:SIMD3(0,1,0)) // manual recenter while camera-tracked
    private var lastPad = -Double.infinity
    private var stalledSince: Double?
    private var lostDuringStall = 0
    private var buttons = Set<String>()
    private var acceleration = SIMD3<Float>(0,0,-1)
    private var rotationRate = SIMD3<Float>(repeating:0)
    // Orientation sources
    private var attitude: (q: simd_quatf, time: Double)?
    private var screen: (pose: ScreenPose, time: Double)?
    private var screenSeen = -Double.infinity
    private var offset: simd_quatf? // maps Core Motion attitude into the screen frame
    private var attitudeInverted: Bool?
    private var conventionVotes = (direct: 0, inverse: 0)
    private var lastReason: ScreenPose.Reason?
    private var lastCalibrated: Bool?
    private var lastRelocalizing: Bool?
    private var widthChecked = false
    private var rumbleSequence: UInt32 = 0
    // Statistics for the periodic summary
    private var stats = Stats()
    private var lastSummary = 0.0
    struct Stats { var pads = 0, attitudes = 0, screens = 0, lost = 0, duplicates = 0, maxGap = 0.0, camera = 0.0, motion = 0.0, none = 0.0, networkGaps = 0, droppedGaps = 0, phoneGaps = 0 }
    // Short gaps hold the last pose instead of dropping the sword; real Wi-Fi bursts last up to ~0.4 s.
    static let fresh = 0.4
    // Pointing at the screen centre with the phone flat: top edge forward, display up.
    static let forward = simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0))

    init(log: EventLog, clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.log = log; self.clock = clock; lastSummary = clock()
    }
    func browse() {
        guard browser == nil else { return }
        let b = NWBrowser(for:.bonjour(type:"_motionremote._udp",domain:nil),using:.udp)
        b.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state { self?.log.write("LINK","Phone discovery failed: \(error.localizedDescription). Allow Local Network access or enter the phone address.") }
        }
        b.browseResultsChangedHandler = { [weak self] results,_ in
            guard let self else { return }
            phones = results.compactMap { result in
                if case let .service(name,_,_,_) = result.endpoint { return FoundPhone(name:name,endpoint:result.endpoint) }
                return nil
            }.sorted { $0.name < $1.name }
            if !phones.contains(where: { $0.name == self.selected }) { selected = phones.first?.name ?? "" }
        }
        b.start(queue:.main); browser = b
    }
    func connect() {
        disconnect()
        let manual = address.trimmingCharacters(in:.whitespacesAndNewlines)
        let endpoint: NWEndpoint, label: String
        if !manual.isEmpty {
            endpoint = .hostPort(host:NWEndpoint.Host(manual),port:26760); label = manual
            UserDefaults.standard.set(manual,forKey:"phoneAddress")
        } else if let phone = phones.first(where: { $0.name == selected }) {
            endpoint = phone.endpoint; label = phone.name
            // Discovery names start with the phone's player: "P2 1a2b3c4d".
            if phone.name.hasPrefix("P"), let p = Int(phone.name.dropFirst().prefix(1)), (1...4).contains(p) { player = p }
        } else { status = "No phone found. Start MotionRemote on the phone and press Connect there."; return }
        slot = UInt8(player-1); identity = DSU.Identity(uuid:UUID()); let token = generation
        let c = NWConnection(to:endpoint,using:.udp)
        connection = c; status = "Connecting to \(label)…"
        log.write("LINK","Connecting to \(label) (player \(player))")
        c.stateUpdateHandler = { [weak self] state in
            guard let self, generation == token else { return }
            switch state {
            case .ready: log.write("LINK","Socket ready; requesting controller data"); register(); receive(c,token:token)
            case .waiting(let error): log.write("LINK","Connection waiting: \(error.localizedDescription)",key:"waiting",every:5)
            case .failed(let error): log.write("LINK","Connection failed: \(error.localizedDescription)"); disconnect(); status = error.localizedDescription
            default: break
            }
        }
        c.start(queue:.main)
    }
    func disconnect() {
        if connection != nil { log.write("LINK","Disconnected by the game") }
        generation = UUID(); connection?.cancel(); connection = nil
        connected = false; status = "Not connected"; counter = nil; lastPad = -.infinity; stalledSince = nil
        attitude = nil; screen = nil; buttons = []; lastReason = nil; lastCalibrated = nil; lastRelocalizing = nil; widthChecked = false
        setSource(.none,why:"disconnected")
    }
    func recenter() {
        guard let attitude else { log.write("CALIBRATION","Recenter ignored: no motion data from the phone"); return }
        if source == .camera, let pose = screen?.pose {
            // Corrects a slightly misaligned screen calibration: only the heading, gravity stays exact.
            let blade = simd_quatf(vector:pose.orientation).act(SIMD3(0,1,0))
            guard simd_length(SIMD2(blade.x,blade.z)) > 0.3 else { log.write("CALIBRATION","Recenter ignored: point the phone at the screen, not up or down"); return }
            cameraYaw = simd_quatf(angle:atan2(blade.x,-blade.z),axis:SIMD3(0,1,0))
            log.write("CALIBRATION",String(format:"Camera heading recentered by %.1f°. If this is often needed, calibrate the screen again.",atan2(blade.x,-blade.z)*180 / .pi))
            return
        }
        offset = Self.forward*oriented(attitude.q).inverse
        log.write("CALIBRATION","Motion recentered: pointing at the screen centre is now straight ahead")
    }
    // One packet per effect: an on/off pair could arrive in the same Wi-Fi burst and cancel out.
    func haptic(_ effect: MonitorWire.Haptic) {
        guard connected else { return }
        rumbleSequence &+= 1
        send(MonitorWire.rumble(1,sequence:rumbleSequence,slot:slot,identity:identity,haptic:effect))
    }
    private func register() { send(MonitorWire.register(slot:slot,identity:identity)); lastRegister = clock() }
    private func send(_ bytes: [UInt8]) {
        connection?.send(content:Data(bytes),completion:.contentProcessed { [weak self] error in
            if let error { self?.log.write("LINK","Send failed: \(error.localizedDescription)",key:"send",every:2) }
        })
    }
    private func receive(_ c: NWConnection, token: UUID) {
        c.receiveMessage { [weak self] data,_,_,error in
            guard let self, generation == token else { return }
            if let data { consume(Array(data)) }
            if let error { log.write("LINK","Receive failed: \(error.localizedDescription)"); disconnect(); status = "Connection closed" }
            else { receive(c,token:token) }
        }
    }
    func consume(_ b: [UInt8]) {
        let now = clock()
        if let state = MonitorWire.state(b,slot:slot) { pad(state,now:now) }
        else if let q = MonitorWire.attitude(b,slot:slot) { stats.attitudes += 1; attitude = (q,now); checkConvention() }
        else if let pose = MonitorWire.screen(b,slot:slot) { stats.screens += 1; screenPose(pose,now:now) }
    }
    private func pad(_ state: MonitorWire.State, now: Double) {
        // The counter restarts with the phone app; after a silent second any number is accepted.
        if let previous = counter, now-lastPad < 1 {
            guard DSU.isNewer(state.counter,than:previous) else { stats.duplicates += 1; return }
            let lost = Int(state.counter &- previous)-1, gap = (now-lastPad)*1000
            stats.lost += lost; stats.maxGap = max(stats.maxGap,gap)
            if gap > 80 {
                // The phone stamps each packet with its sensor time: equal stamps but late arrival means the network held them.
                let sent = state.timestamp > phoneStamp ? Double(state.timestamp-phoneStamp)/1000 : 0
                let cause: String, kind: String
                if sent < gap/2 { stats.networkGaps += 1; networkGaps.append(now); kind = "held"; cause = String(format:"phone sent them %.0f ms apart, so Wi-Fi held them back",sent) }
                else if lost > 0 { stats.droppedGaps += 1; kind = "dropped"; cause = "the phone kept sending, the packets were lost on the way" }
                else { stats.phoneGaps += 1; kind = "paused"; cause = String(format:"the phone itself paused sending for %.0f ms",sent) }
                if stalledSince != nil { lostDuringStall += lost }
                else { log.write("LINK",String(format:"Packet gap %.0f ms, %d lost (#%u → #%u): %@",gap,lost,previous,state.counter,cause),key:"gap-\(kind)",every:1) }
            } else if stalledSince != nil { lostDuringStall += lost }
        }
        if let since = stalledSince {
            log.write("LINK",String(format:"Controller data resumed after %.0f ms (%d packets lost)",(now-since)*1000,lostDuringStall))
            stalledSince = nil
        }
        counter = state.counter; phoneStamp = state.timestamp; lastPad = now; stats.pads += 1
        acceleration = state.acceleration; rotationRate = state.rotationRate
        if !connected { connected = true; status = "Connected · player \(player)"; log.write("LINK","Receiving controller data") }
        let pressed = Set(state.buttons)
        for name in pressed.subtracting(buttons) { if name == "Recenter" { recenter() }; onButton?(name) }
        buttons = pressed
    }
    private func screenPose(_ pose: ScreenPose, now: Double) {
        if pose.reason != lastReason {
            log.write("TRACKING","Phone reports: \(pose.reason.text)\(pose.lidar ? " · LiDAR" : " · no LiDAR")",key:"reason-\(pose.reason.rawValue)",every:2)
            lastReason = pose.reason
        }
        if pose.calibrated != lastCalibrated || (pose.calibrated && abs(pose.width-(screen?.pose.width ?? pose.width)) > 0.001) {
            cameraYaw = simd_quatf(angle:0,axis:SIMD3(0,1,0))
        }
        if pose.calibrated != lastCalibrated {
            log.write("CALIBRATION",pose.calibrated ? String(format:"Phone has a screen calibration (%.1f cm wide)",pose.width*100) : "Phone has no screen calibration; using motion only until the screen is calibrated")
            lastCalibrated = pose.calibrated; widthChecked = false
        }
        if pose.relocalizing != lastRelocalizing {
            if pose.relocalizing { log.write("CALIBRATION","Phone is recognising its saved room; motion only meanwhile") }
            lastRelocalizing = pose.relocalizing
        }
        if pose.calibrated && !widthChecked, let displayWidth {
            widthChecked = true
            if abs(pose.width-displayWidth) > 0.04 {
                log.write("CALIBRATION",String(format:"Calibrated width %.1f cm differs from this display (%.1f cm). The touches were not on the display edges, or the calibration belongs to another screen. Calibrate again on the phone.",pose.width*100,displayWidth*100))
            }
        }
        screen = (pose,now); screenSeen = now
        if let attitude, pose.tracking == 2, pose.calibrated, now-attitude.time < 0.05 {
            // While the camera is good, keep the motion fallback aligned with it so switching does not jump.
            offset = cameraYaw*simd_quatf(vector:pose.orientation)*oriented(attitude.q).inverse
        }
        calibration = pose.calibrated ? String(format:"Screen calibrated · %.1f cm",pose.width*100) : (pose.relocalizing ? "Recognising saved room…" : "Screen not calibrated")
        tracking = pose.reason.text
    }
    // Core Motion's quaternion convention is checked against gravity before the motion sword relies on it.
    private func checkConvention() {
        guard attitudeInverted == nil, let attitude, abs(simd_length(acceleration)-1) < 0.05, simd_length(rotationRate) < 5 else { return }
        let down = SIMD3<Float>(0,0,-1), g = simd_normalize(acceleration)
        let direct = simd_distance(attitude.q.act(g),down), inverse = simd_distance(attitude.q.inverse.act(g),down)
        guard abs(direct-inverse) > 0.3 else { return } // phone flat: both agree, no information
        if direct < inverse { conventionVotes.direct += 1 } else { conventionVotes.inverse += 1 }
        if conventionVotes.direct+conventionVotes.inverse >= 20 {
            attitudeInverted = conventionVotes.inverse > conventionVotes.direct
            log.write("TRACKING","Motion orientation check: \(conventionVotes.direct) of 20 still samples match device→world\(attitudeInverted! ? "; using the inverse convention" : "")")
            offset = nil
        }
    }
    private func oriented(_ q: simd_quatf) -> simd_quatf { attitudeInverted == true ? q.inverse : q }
    // Called every frame by the game.
    func input(now: Double) -> Input {
        if connection != nil, now-lastRegister > 1 { register() }
        if connected, now-lastPad > Self.fresh, stalledSince == nil {
            stalledSince = lastPad; lostDuringStall = 0
            log.write("LINK",String(format:"No controller data for 400 ms (last packet #%u). Phone app in background or locked, Wi-Fi interference, or the phone is overloaded.",counter ?? 0))
        }
        if connected, now-lastPad > 3 {
            connected = false; status = "Phone silent · waiting"
            log.write("LINK","Phone silent for 3 s; still trying. Check that MotionRemote is open and connected on the phone.")
        }
        if now-screenSeen > 0.5, screen != nil, screen!.pose.tracking == 2 {
            log.write("TRACKING","Camera pose stream stopped while tracking was normal (transfer problem or camera switched off on the phone)",key:"pose-stall",every:5)
            screen = nil; tracking = "Camera pose stream stopped"
        }
        var next: Input
        if let screen, screen.pose.tracking == 2, screen.pose.calibrated, now-screen.time < Self.fresh {
            next = Input(source:.camera,position:cameraYaw.act(screen.pose.position),orientation:simd_normalize(cameraYaw*simd_quatf(vector:screen.pose.orientation)))
        } else if let attitude, now-attitude.time < Self.fresh {
            if offset == nil {
                offset = Self.forward*oriented(attitude.q).inverse
                log.write("CALIBRATION","Motion only: centred on the current phone direction. Point at the screen centre and press the crosshair on the phone to recenter.")
            }
            next = Input(source:.motion,position:nil,orientation:offset!*oriented(attitude.q))
        } else { next = Input(source:.none,position:nil,orientation:Self.forward) }
        if next.source != source {
            let why: String
            switch next.source {
            case .camera: why = "screen-calibrated camera pose available"
            case .motion: why = screen.map { $0.pose.tracking != 2 ? $0.pose.reason.text : ($0.pose.calibrated ? "camera pose late" : "screen not calibrated") } ?? "no camera pose from the phone"
            case .none: why = connected ? "no fresh motion data" : "not receiving data"
            }
            setSource(next.source,why:why)
        }
        summarize(now:now)
        return next
    }
    func frame(dt: Double) {
        switch source { case .camera: stats.camera += dt; case .motion: stats.motion += dt; case .none: stats.none += dt }
    }
    private func setSource(_ next: Source, why: String) {
        guard next != source else { return }
        // Only rapid flapping between the same two sources is summarised; every other change is written.
        log.write("TRACKING","Sword source: \(source.rawValue) → \(next.rawValue) (\(why))",key:"source-\(source)-\(next)",every:2)
        source = next
    }
    private func summarize(now: Double) {
        guard now-lastSummary >= 10 else { return }
        let seconds = now-lastSummary; lastSummary = now
        if connection != nil || stats.pads > 0 {
            let total = Double(stats.pads+stats.lost)
            log.write("SUMMARY",String(format:"10 s: %.0f pad/s, %.0f attitude/s, %.0f camera poses/s · %d lost (%.1f%%), %d duplicates, longest gap %.0f ms · gaps > 80 ms: %d held by Wi-Fi, %d dropped by Wi-Fi, %d phone paused%@ · sword: camera %.0f%%, motion %.0f%%, none %.0f%%",
                Double(stats.pads)/seconds,Double(stats.attitudes)/seconds,Double(stats.screens)/seconds,stats.lost,total > 0 ? 100*Double(stats.lost)/total : 0,
                stats.duplicates,stats.maxGap,stats.networkGaps,stats.droppedGaps,stats.phoneGaps,Self.rhythm(networkGaps),100*stats.camera/seconds,100*stats.motion/seconds,100*stats.none/seconds))
        }
        stats = Stats(); networkGaps = []
    }
    // Wi-Fi gaps at a steady rhythm point to the radio pausing on purpose (AirDrop/Handoff scanning, power saving).
    static func rhythm(_ times: [Double]) -> String {
        let intervals = zip(times,times.dropFirst()).map { $1-$0 }
        guard intervals.count >= 3 else { return "" }
        let mean = intervals.reduce(0,+)/Double(intervals.count)
        let spread = sqrt(intervals.reduce(0) { $0+($1-mean)*($1-mean) }/Double(intervals.count))
        return spread < mean*0.2 ? String(format:" (regular, every %.2f s: typical of AirDrop/Handoff radio scanning or Wi-Fi power saving)",mean) : ""
    }
}
