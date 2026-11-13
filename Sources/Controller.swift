import Foundation
import Network
import CoreMotion
import UIKit
import Darwin
import AVKit

final class Controller: ObservableObject {
    @Published var status = "Stopped"
    let bluetooth = BluetoothController()
    @Published var bluetoothEnabled = true
    private var discovery: NetService?
    @Published var held = Set<String>()
    @Published var profile = "Golf"
    @Published var triggerOverride = "Automatic"
    @Published var address = ""
    @Published var spatialEnabled = false
    @Published var trackingStatus = "Spatial tracking off"
    private var latestPose: SpatialPose?
    private var latestScreen: ScreenPose?
    private var sentScreen: UInt32?
    private var normalTrackingSince: Double?
    func updateSpatialPose(_ pose: SpatialPose) {
        guard spatialEnabled else {
            normalTrackingSince = nil
            queue.async { self.latestPose = nil }
            if trackingStatus != "Spatial tracking off" { trackingStatus = "Spatial tracking off" }
            return
        }
        guard pose.isValid else { return }
        queue.async { self.latestPose = pose }
        if pose.tracking != 2 { normalTrackingSince = nil }
        else if normalTrackingSince == nil { normalTrackingSince = pose.timestamp }
        let stable = pose.tracking == 2 && pose.timestamp-(normalTrackingSince ?? pose.timestamp) >= 0.5
        let status = stable ? "Position tracked · metres" : (pose.tracking == 1 ? "Tracking limited — path paused" : "Position tracking unavailable")
        if trackingStatus != status { trackingStatus = status }
    }
    func updateScreenPose(_ pose: ScreenPose) {
        let enabled = spatialEnabled
        queue.async { self.latestScreen = enabled ? pose : nil }
    }
    @Published var player = min(4,max(1,UserDefaults.standard.integer(forKey:"player"))) {
        didSet { UserDefaults.standard.set(player,forKey:"player") }
    }
    @Published var hapticsEnabled = UserDefaults.standard.object(forKey:"hapticsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(hapticsEnabled,forKey:"hapticsEnabled") }
    }
    @Published var gameHapticsEnabled = UserDefaults.standard.object(forKey:"gameHapticsEnabled") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(gameHapticsEnabled,forKey:"gameHapticsEnabled")
            if !gameHapticsEnabled { gameHaptics.stop() }
        }
    }
    let gameHaptics = GameHaptics()
    private var clientUIDs: [ObjectIdentifier:UInt64] = [:]
    private var rumbleSequences: [ObjectIdentifier:UInt32] = [:]
    var discoveryName: String { "P\(player) \(String(identity.uid,radix:16))" }
    var serverName: String { player == 1 ? "MotionRemote" : "MotionRemote P\(player)" }
    private let feedback = UIImpactFeedbackGenerator(style:.light)
    private let identity: DSU.Identity = {
        let key = "controllerIdentity"
        let uuid = UserDefaults.standard.string(forKey:key).flatMap(UUID.init(uuidString:)) ?? UUID()
        UserDefaults.standard.set(uuid.uuidString,forKey:key)
        return DSU.Identity(uuid:uuid)
    }()
    private var slot: UInt8 = 0
    private var sessionGeneration: UInt64 = 0
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "MotionRemote.DSU")
    private var accepted: [ObjectIdentifier:Double] = [:]
    private var clients: [ObjectIdentifier:(NWConnection,Double)] = [:]
    private let motion = CMMotionManager()
    let recordings = MotionLibrary()
    private var recordingRequested = false
    private var networkingActive = false
    private var lastRecordedStamp = -1.0
    private var timer: DispatchSourceTimer?
    private var values = [Float](repeating:0,count:6)
    private var stamp: UInt64 = 0
    private var attitude = SIMD4<Float>(0,0,0,1)
    private var counter: UInt32 = 0
    private var buttons = Set<String>()
    private var sources: [String:String] = [:]
    private var bias = [Double](repeating:0,count:3)
    private var calibration: [[Double]] = []
    @Published var calibrationMessage = ""
    @Published var calibrationReady = false
    private var calibrationStamp = -1.0
    private var calibrating = false
    init() {
        recordings.onStopped = { [weak self] in
            guard let self else { return }
            self.queue.sync { self.recordingRequested = false }
            if self.listener == nil { self.stopSampling() }
        }
    }
    func toggleRecording() {
        if recordings.isRecording { recordings.finish(); return }
        guard motion.isDeviceMotionAvailable else { recordings.error = "Motion sensors are unavailable on this device."; return }
        recordings.begin(sport:profile,player:player)
        guard recordings.isRecording else { return }
        queue.sync { recordingRequested = true; lastRecordedStamp = -1 }
        ensureSampling()
    }
    private func ensureSampling() {
        guard timer == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = true
        motion.deviceMotionUpdateInterval = 0.01
        motion.startDeviceMotionUpdates()
        let t = DispatchSource.makeTimerSource(queue:queue)
        t.schedule(deadline:.now(),repeating:.milliseconds(10))
        t.setEventHandler { self.sample(); self.send() }
        timer = t; t.resume()
    }
    private func stopSampling() {
        queue.sync { timer?.cancel(); timer = nil }
        motion.stopDeviceMotionUpdates()
        UIApplication.shared.isIdleTimerDisabled = false
    }
    var trigger: String { triggerOverride == "Automatic" ? (profile == "Bowling" ? "B" : "A") : triggerOverride }
    private var volumeTapTiming = VolumeTapTiming()
    func volumeEvent(channel: String, phase: AVCaptureEventPhase) {
        guard let mapping = VolumeButton.mapping(channel:channel,trigger:trigger) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if phase == .began {
            volumeTapTiming.begin(source:mapping.source,now:now)
            button(mapping.button,source:mapping.source,down:true)
        } else if phase == .ended, let release = volumeTapTiming.release(source:mapping.source,now:now) {
            if release.delay == 0 { button(mapping.button,source:mapping.source,down:false) }
            else {
                DispatchQueue.main.asyncAfter(deadline:.now()+release.delay) { [weak self] in
                    guard let self, self.volumeTapTiming.matches(source:mapping.source,token:release.token) else { return }
                    self.button(mapping.button,source:mapping.source,down:false)
                }
            }
        } else { button(mapping.button,source:mapping.source,down:false) }
    }
    func button(_ name: String, source: String, down: Bool) {
        if !down { volumeTapTiming.cancel(source:source) }
        if down && sources[source] == nil && hapticsEnabled { feedback.impactOccurred(intensity:0.65); feedback.prepare() }
        if down { sources[source] = name } else { sources.removeValue(forKey:source) }
        held = Set(sources.values)
        let state = held
        queue.async { self.buttons = state; self.send() }
    }
    func calibrate() {
        calibrationReady = false; calibrationMessage = "Keep the phone still for one second."
        queue.async { self.calibration = []; self.calibrationStamp = -1; self.calibrating = true }
    }
    func start() {
        guard listener == nil else { return }
        appLog.write("LINK","Controller started · player \(player) · \(discoveryName) · Bluetooth \(bluetoothEnabled ? "on" : "off") · camera tracking \(spatialEnabled ? "on" : "off")")
        queue.sync { slot = UInt8(player-1); sessionGeneration &+= 1; networkingActive = true }
        feedback.prepare()
        if bluetoothEnabled { bluetooth.start(player:player,identity:String(identity.uid,radix:16)) }
        address = Self.addresses()
        UIApplication.shared.isIdleTimerDisabled = true
        do {
            let l = try NWListener(using:.udp,on:26760)
            listener = l
            l.stateUpdateHandler = { state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        appLog.write("LINK","Listening on UDP 26760 · address \(Self.addresses())")
                        self.status = "Ready · waiting for Dolphin"
                        let service = NetService(domain:"local.",type:"_motionremote._udp.",name:"P\(self.player) \(String(self.identity.uid,radix:16))",port:26760)
                        service.setTXTRecord(NetService.data(fromTXTRecord:["player":Data(String(self.player).utf8)]))
                        self.discovery = service; service.publish()
                    case .failed(let error): appLog.write("LINK","UDP listener failed: \(error.localizedDescription)"); self.status = error.localizedDescription
                    case .waiting(let error): appLog.write("LINK","UDP listener waiting: \(error.localizedDescription)",key:"listen-wait",every:5)
                    default: break
                    }
                }
            }
            l.newConnectionHandler = { connection in
                guard self.clients.count < 8 else { appLog.write("LINK","Rejected \(connection.endpoint): 8 clients already connected",key:"full",every:5); connection.cancel(); return }
                appLog.write("LINK","Client \(connection.endpoint) connected",key:"client-\(connection.endpoint)",every:5)
                self.clients[ObjectIdentifier(connection)] = (connection,0)
                self.accepted[ObjectIdentifier(connection)] = ProcessInfo.processInfo.systemUptime
                connection.start(queue:self.queue)
                self.receive(connection)
            }
            l.start(queue:queue)
            ensureSampling()
        } catch { appLog.write("LINK","Could not open UDP 26760: \(error.localizedDescription)"); status = error.localizedDescription; stop() }
    }
    private func receive(_ c: NWConnection) {
        c.receiveMessage { data,_,_,error in
            if let data = data, data.count == 32, data.starts(with:Data("MRPING01".utf8)) {
                c.send(content:data,completion:.contentProcessed { _ in })
            } else if let data = data {
                self.accepted[ObjectIdentifier(c)] = ProcessInfo.processInfo.systemUptime
                let b = Array(data)
                if DSU.valid(b) {
                    let type = DSU.get(b,16,4)
                    if type == 0x100003 {
                        let id = ObjectIdentifier(c)
                        if let uid = self.clientUIDs[id], let (_,last) = self.clients[id],
                           ProcessInfo.processInfo.systemUptime-last < 5,
                           DSU.acceptsRumble(b,slot:self.slot,clientUID:uid) {
                            let sequence = UInt32(DSU.get(b,24,4))
                            if self.rumbleSequences[id].map({ DSU.isNewer(sequence,than:$0) }) ?? true {
                                self.rumbleSequences[id] = sequence
                                let strength = Float(b[21])/255, effect = b[22]
                                let generation = self.sessionGeneration
                                DispatchQueue.main.async {
                                    guard self.gameHapticsEnabled && self.sessionGeneration == generation else { return }
                                    // Byte 22 = one-shot effect from MotionSaber; Dolphin sends 0 for continuous rumble.
                                    if effect != 0 { self.gameHaptics.play(effect) } else { self.gameHaptics.set(strength) }
                                }
                            }
                        }
                    } else if type == 0x100000 {
                        var reply = DSU.packet(0x100000,size:24,identity:self.identity); DSU.put(UInt16(1001),20,&reply); DSU.finish(&reply); self.reply(reply,c)
                    } else if type == 0x100001, b.count == 28 {
                        let count = Int(DSU.get(b,20,4))
                        if count <= 4 {
                            for id in b[24..<(24+count)] where id < 4 {
                                var reply = DSU.packet(0x100001,size:32,identity:self.identity); DSU.info(&reply,connected:id == self.slot,slot:id,identity:self.identity); reply[20] = id; DSU.finish(&reply); self.reply(reply,c)
                            }
                        }
                    } else if type == 0x100002, b.count == 28 {
                        if DSU.acceptsRegistration(b,slot:self.slot,identity:self.identity) {
                            self.clients[ObjectIdentifier(c)] = (c,ProcessInfo.processInfo.systemUptime)
                            let id = ObjectIdentifier(c)
                            let uid = DSU.get(b,12,4)
                            if self.clientUIDs[id] != uid { self.rumbleSequences.removeValue(forKey:id) }
                            self.clientUIDs[id] = uid
                        }
                    }
                }
            }
            if let error { appLog.write("LINK","Receive from \(c.endpoint) failed: \(error.localizedDescription)"); self.clients.removeValue(forKey:ObjectIdentifier(c)); c.cancel() } else { self.receive(c) }
        }
    }
    private func reply(_ bytes: [UInt8], _ c: NWConnection) {
        c.send(content:Data(bytes),completion:.contentProcessed { error in
            if let error { appLog.write("LINK","Sending to \(c.endpoint) failed: \(error.localizedDescription)",key:"send-\(c.endpoint)",every:2) }
        })
    }
    private func sample() {
        guard let m = motion.deviceMotion else { return }
        let r = [m.rotationRate.x,m.rotationRate.y,m.rotationRate.z]
        if calibrating && m.timestamp > calibrationStamp {
            calibrationStamp = m.timestamp
            calibration.append(r)
            if calibration.count == 100 {
                let mean = (0..<3).map { i in calibration.reduce(0) { $0+$1[i] } / 100 }
                let variance = calibration.reduce(0.0) { total,row in total + (0..<3).reduce(0.0) { $0 + pow(row[$1]-mean[$1],2) } } / Double(calibration.count)
                let meanSpeed = sqrt(mean.reduce(0.0) { $0+$1*$1 })
                let quiet = sqrt(variance) < 0.12 && meanSpeed < 0.18
                // Hand tremor must not be learned as a sensor offset.
                if sqrt(variance) < 0.015 && meanSpeed < 0.03 { bias = mean }
                DispatchQueue.main.async {
                    self.calibrationReady = quiet
                    self.calibrationMessage = quiet ? "Point at the screen centre, then confirm. Wait for normal camera tracking." : "Movement detected. Try again."
                }
                calibrating = false
            }
        }
        // Core Motion gravity is downwards; DSU acceleration uses specific force (rest: Y = -1 g).
        values = [Float(-(m.gravity.x+m.userAcceleration.x)),Float(m.gravity.z+m.userAcceleration.z),Float(-(m.gravity.y+m.userAcceleration.y)),Float((r[0]-bias[0])*180 / .pi),Float(-(r[2]-bias[2])*180 / .pi),Float((r[1]-bias[1])*180 / .pi)]
        stamp = UInt64(max(0,m.timestamp)*1_000_000)
        let attitude = m.attitude.quaternion
        self.attitude = SIMD4(Float(attitude.x),Float(attitude.y),Float(attitude.z),Float(attitude.w))
        if recordingRequested && m.timestamp > lastRecordedStamp {
            lastRecordedStamp = m.timestamp
            let q = m.attitude.quaternion
            let a = m.userAcceleration
            let frame = MotionFrame(time:m.timestamp,attitude:SIMD4(q.x,q.y,q.z,q.w),
                                    acceleration:SIMD3(a.x,a.y,a.z),angularVelocity:SIMD3(r[0],r[1],r[2]),buttons:buttons.sorted())
            DispatchQueue.main.async { self.recordings.append(frame) }
        }
    }
    private func send() {
        guard networkingActive else { return }
        let now = ProcessInfo.processInfo.systemUptime
        for (id,last) in accepted where now-last > 10 {
            appLog.write("LINK","Client \(clients[id]?.0.endpoint.debugDescription ?? "?") silent for 10 s; dropped")
            clients[id]?.0.cancel(); clients.removeValue(forKey:id); accepted.removeValue(forKey:id); clientUIDs.removeValue(forKey:id); rumbleSequences.removeValue(forKey:id)
        }
        let active = clients.values.filter { now-$0.1 < 5 }
        counter &+= 1
        let packet = DSU.state(buttons:buttons,motion:values,timestamp:stamp,counter:counter,slot:slot,identity:identity)
        for (c,_) in active { reply(packet,c) }
        // Attitude at the full sample rate keeps the motion-only sword smooth.
        let attitudeData = DSU.attitude(attitude,timestamp:stamp,slot:slot,identity:identity)
        for (c,_) in active { reply(attitudeData,c) }
        if let screen = latestScreen, screen.sequence != sentScreen {
            sentScreen = screen.sequence
            let data = DSU.screen(screen,slot:slot,identity:identity)
            for (c,_) in active { reply(data,c) }
        }
        if counter % 3 == 0, var pose = latestPose {
            if now-pose.timestamp > 0.3 { pose.tracking = 0 }
            if let data = DSU.pose(pose,slot:slot,identity:identity) {
                for (c,_) in active { reply(data,c) }
            }
        }
        if counter % 100 == 0 {
            DispatchQueue.main.async { self.status = active.isEmpty ? "Ready · waiting for Dolphin" : "Connected to Dolphin" }
        }
    }
    func stop() {
        if listener != nil { appLog.write("LINK","Controller stopped") }
        bluetooth.stop(); discovery?.stop(); discovery = nil
        recordings.finish()
        gameHaptics.stop()
        volumeTapTiming.reset()
        sources.removeAll(); held.removeAll()
        queue.sync {
            sessionGeneration &+= 1
            buttons.removeAll(); values = [0,-1,0,0,0,0]; send()
            networkingActive = false
            timer?.cancel(); timer = nil
            let closing = clients.values.map { $0.0 }
            queue.asyncAfter(deadline:.now()+0.1) { for c in closing { c.cancel() } }
            clients.removeAll(); accepted.removeAll(); clientUIDs.removeAll(); rumbleSequences.removeAll()
            latestScreen = nil; sentScreen = nil
        }
        motion.stopDeviceMotionUpdates(); listener?.cancel(); listener = nil
        UIApplication.shared.isIdleTimerDisabled = false
        status = "Stopped · buttons released"
    }
    static func addresses() -> String {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0 else { return "Address unavailable" }
        defer { freeifaddrs(list) }
        var p = list; var result = [String]()
        while let item = p {
            let a = item.pointee
            if let addr = a.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET), String(cString:a.ifa_name) == "en0" {
                var host = [CChar](repeating:0,count:Int(NI_MAXHOST))
                if getnameinfo(addr,socklen_t(addr.pointee.sa_len),&host,socklen_t(host.count),nil,0,NI_NUMERICHOST) == 0 { result.append(String(cString:host)) }
            }
            p = a.ifa_next
        }
        return result.joined(separator:", ")
    }
}
