import ARKit
import Combine

final class SpatialTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    var onPose: ((SpatialPose) -> Void)?
    var onScreen: ((ScreenPose) -> Void)?
    // LiDAR helps ARKit start and recognise rooms; camera tracking works without it.
    let hasLiDAR = ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
    @Published private(set) var screenStatus = "Camera tracking off — the game uses motion only"
    @Published private(set) var canMark = false
    @Published private(set) var leftMarked = false
    @Published private(set) var calibrated = false
    // A saved room exists or is being searched for; forgetting it must work in either case.
    @Published private(set) var hasSavedRoom = false
    private var roomStored = false
    private var active = false
    private var origin: SIMD3<Float>?
    private var epoch: UInt32 = 0
    private var sequence: UInt32 = 0
    private var camera: simd_float4x4? // latest transform while tracking is normal
    private var left: SIMD3<Float>?
    private var screen: (transform: simd_float4x4, width: Float)?
    private var loadedRoom = false
    private var relocalizingSince: Double?
    private var warnedRelocalizing = false
    private var savePending = false
    private var lastSaveAttempt = -Double.infinity
    private var verify: (until: Double, sum: Float, count: Int)?
    private var reason: ScreenPose.Reason?
    private var mapping: ARFrame.WorldMappingStatus?
    private static let anchorName = "MotionRemote.screen"
    private let feedback = UINotificationFeedbackGenerator()
    private let roomURL = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
        .appendingPathComponent("MotionRemote/ScreenRoom.worldmap")
    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
        roomStored = FileManager.default.fileExists(atPath:roomURL.path)
        hasSavedRoom = roomStored
    }
    func start() {
        guard ARWorldTrackingConfiguration.isSupported else {
            appLog.write("TRACKING","Camera tracking is not supported on this device; the game uses motion only.")
            emitUnavailable(.unavailable); return
        }
        active = true; origin = nil; epoch = UInt32.random(in:1...UInt32.max); sequence = 0
        camera = nil; left = nil; screen = nil; reason = nil; mapping = nil; verify = nil; warnedRelocalizing = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        loadedRoom = false; relocalizingSince = nil
        if let map = loadRoom() { configuration.initialWorldMap = map; loadedRoom = true; relocalizingSince = now }
        session.run(configuration,options:[.resetTracking,.removeExistingAnchors])
        appLog.write("TRACKING","Camera tracking started · LiDAR \(hasLiDAR ? "available" : "not available (camera-only mode: move the phone slowly at the start)") · saved room \(loadedRoom ? "loaded" : "none")")
        publish()
    }
    func stop() {
        if active { appLog.write("TRACKING","Camera tracking stopped") }
        active = false; session.pause(); emitUnavailable(.off)
    }
    // First call marks the left screen edge, second the right one.
    func mark() {
        guard let camera else {
            appLog.write("CALIBRATION","Mark ignored: camera tracking is not normal (\(reason?.text ?? "not started"))")
            feedback.notificationOccurred(.error); return
        }
        let point = ScreenCalibration.touchPoint(camera)
        guard let left else {
            self.left = point
            appLog.write("CALIBRATION",String(format:"Left edge marked at (%.3f, %.3f, %.3f) m",point.x,point.y,point.z))
            feedback.notificationOccurred(.success); publish(); return
        }
        self.left = nil
        guard let result = ScreenCalibration.frame(left:left,right:point) else {
            appLog.write("CALIBRATION",String(format:"Calibration rejected: marks %.1f cm apart. Touch the left edge first, then the right edge of the same screen.",simd_distance(left,point)*100))
            feedback.notificationOccurred(.error); publish(); return
        }
        if abs(point.y-left.y) > 0.03 {
            appLog.write("CALIBRATION",String(format:"Warning: the marks differ %.1f cm in height; touch both edges at the same height.",abs(point.y-left.y)*100))
        }
        replaceAnchor(result.transform,width:result.width)
        verify = (now+2,0,0); feedback.notificationOccurred(.success)
        appLog.write("CALIBRATION",String(format:"Screen calibrated: %.1f cm wide, centre (%.3f, %.3f, %.3f) m",result.width*100,result.transform.columns.3.x,result.transform.columns.3.y,result.transform.columns.3.z))
        publish()
    }
    func forget() {
        for anchor in session.currentFrame?.anchors ?? [] where Self.width(of:anchor) != nil { session.remove(anchor:anchor) }
        screen = nil; left = nil; savePending = false; loadedRoom = false; relocalizingSince = nil
        do { if FileManager.default.fileExists(atPath:roomURL.path) { try FileManager.default.removeItem(at:roomURL) }; roomStored = false }
        catch { appLog.write("CALIBRATION","Could not delete the saved room: \(error.localizedDescription)") }
        appLog.write("CALIBRATION","Screen calibration and saved room deleted")
        // A session started with the old room keeps searching for it; start fresh so the edges can be marked.
        if active { start() } else { publish() }
    }
    private var now: Double { ProcessInfo.processInfo.systemUptime }
    private func replaceAnchor(_ transform: simd_float4x4, width: Float) {
        for anchor in session.currentFrame?.anchors ?? [] where Self.width(of:anchor) != nil { session.remove(anchor:anchor) }
        session.add(anchor:ARAnchor(name:String(format:"%@:%.4f",Self.anchorName,width),transform:transform))
        screen = (transform,width); loadedRoom = false; relocalizingSince = nil; savePending = true; lastSaveAttempt = -.infinity
    }
    private static func width(of anchor: ARAnchor) -> Float? {
        guard let name = anchor.name, name.hasPrefix(anchorName+":") else { return nil }
        return Float(name.dropFirst(anchorName.count+1))
    }
    private func loadRoom() -> ARWorldMap? {
        guard FileManager.default.fileExists(atPath:roomURL.path) else { return nil }
        do {
            let data = try Data(contentsOf:roomURL)
            guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass:ARWorldMap.self,from:data) else { throw CocoaError(.coderReadCorrupt) }
            guard map.anchors.contains(where: { Self.width(of:$0) != nil }) else {
                appLog.write("CALIBRATION","Saved room has no screen calibration; ignoring it"); return nil
            }
            appLog.write("CALIBRATION","Loaded saved room (\(map.rawFeaturePoints.points.count) feature points, \(data.count/1024) KB)")
            return map
        } catch {
            appLog.write("CALIBRATION","Could not load the saved room: \(error.localizedDescription). Calibrate the screen again.")
            return nil
        }
    }
    private func saveRoom() {
        lastSaveAttempt = now
        session.getCurrentWorldMap { map,error in
            DispatchQueue.main.async {
                guard let map else {
                    appLog.write("CALIBRATION","Room not saved yet (\(error?.localizedDescription ?? "no map")). Move the phone slowly around the desk; retrying.",key:"save",every:10)
                    return
                }
                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject:map,requiringSecureCoding:true)
                    try FileManager.default.createDirectory(at:self.roomURL.deletingLastPathComponent(),withIntermediateDirectories:true)
                    try data.write(to:self.roomURL,options:.atomic)
                    self.savePending = false; self.roomStored = true
                    appLog.write("CALIBRATION","Room saved (\(data.count/1024) KB, \(map.rawFeaturePoints.points.count) feature points). The next start restores the calibration automatically.")
                } catch { appLog.write("CALIBRATION","Saving the room failed: \(error.localizedDescription)") }
                self.publish()
            }
        }
    }
    private static func state(_ state: ARCamera.TrackingState) -> (UInt8,ScreenPose.Reason) {
        switch state {
        case .normal: return (2,.normal)
        case .notAvailable: return (0,.unavailable)
        case .limited(.initializing): return (1,.initializing)
        case .limited(.excessiveMotion): return (1,.excessiveMotion)
        case .limited(.insufficientFeatures): return (1,.insufficientFeatures)
        case .limited(.relocalizing): return (1,.relocalizing)
        case .limited: return (1,.unavailable)
        }
    }
    private func emitUnavailable(_ why: ScreenPose.Reason) {
        sequence &+= 1
        let time = now
        onPose?(SpatialPose(timestamp:time,epoch:epoch,sequence:sequence,tracking:0,position:.zero,orientation:SIMD4(0,0,0,1)))
        onScreen?(ScreenPose(timestamp:time,sequence:sequence,tracking:0,reason:why,calibrated:false,relocalizing:false,lidar:hasLiDAR,
                             width:0,position:.zero,orientation:SIMD4(0,0,0,1)))
        reason = why; camera = nil; publish()
    }
    func session(_ session:ARSession,didUpdate frame:ARFrame) {
        guard active else { return }
        let (quality,why) = Self.state(frame.camera.trackingState)
        if why != reason {
            let light = frame.lightEstimate.map { String(format:" · light %.0f lm%@",$0.ambientIntensity,$0.ambientIntensity < 250 ? " (dark)" : "") } ?? ""
            appLog.write("TRACKING","\(why.text) · \(frame.rawFeaturePoints?.points.count ?? 0) feature points\(light)",key:"state-\(why.rawValue)",every:2)
            reason = why
        }
        if frame.worldMappingStatus != mapping {
            mapping = frame.worldMappingStatus
            let names: [ARFrame.WorldMappingStatus:String] = [.notAvailable:"not available",.limited:"limited",.extending:"extending",.mapped:"mapped"]
            appLog.write("TRACKING","Room mapping \(names[frame.worldMappingStatus] ?? "unknown")",key:"mapping",every:2)
        }
        // The UI is portrait-locked; this adjusts ARKit's camera basis to that orientation.
        let transform = simd_inverse(frame.camera.viewMatrix(for:.portrait))
        let position = SIMD3(transform.columns.3.x,transform.columns.3.y,transform.columns.3.z)
        if quality == 2 && origin == nil { origin = position }
        let rotation = simd_quatf(simd_float3x3(columns:(SIMD3(transform.columns.0.x,transform.columns.0.y,transform.columns.0.z),
                                                                      SIMD3(transform.columns.1.x,transform.columns.1.y,transform.columns.1.z),
                                                                      SIMD3(transform.columns.2.x,transform.columns.2.y,transform.columns.2.z))))
        sequence &+= 1
        onPose?(SpatialPose(timestamp:frame.timestamp,epoch:epoch,sequence:sequence,tracking:quality,
                            position:position-(origin ?? position),orientation:rotation.vector))
        camera = quality == 2 ? transform : nil
        // Anchors of a saved room appear once ARKit recognises it; ARKit may also refine them later.
        if let anchor = frame.anchors.first(where: { Self.width(of:$0) != nil }), let width = Self.width(of:anchor) {
            if screen == nil, let since = relocalizingSince {
                appLog.write("CALIBRATION",String(format:"Saved room recognised after %.1f s; screen calibration restored (%.1f cm)",now-since,width*100))
            }
            screen = (anchor.transform,width); relocalizingSince = nil
        }
        if let since = relocalizingSince, screen == nil, now-since > 20, !warnedRelocalizing {
            warnedRelocalizing = true
            appLog.write("CALIBRATION","Saved room not recognised after 20 s. Point the camera at the desk as during calibration, add light, or calibrate again if the Mac was moved.")
        }
        if savePending, frame.worldMappingStatus == .mapped || frame.worldMappingStatus == .extending, now-lastSaveAttempt > 3 { saveRoom() }
        var pose = ScreenPose(timestamp:frame.timestamp,sequence:sequence,tracking:quality,reason:why,calibrated:screen != nil,
                              relocalizing:relocalizingSince != nil,lidar:hasLiDAR,width:screen?.width ?? 0,position:.zero,orientation:SIMD4(0,0,0,1))
        if let screen, quality == 2 {
            let relative = ScreenCalibration.pose(camera:transform,screen:screen.transform)
            pose.position = relative.position; pose.orientation = relative.orientation.vector
            if var check = verify {
                check.sum += relative.position.z; check.count += 1; verify = check
                if now > check.until {
                    verify = nil
                    if check.count > 0, check.sum/Float(check.count) < -0.05 {
                        replaceAnchor(ScreenCalibration.flipped(screen.transform),width:screen.width)
                        appLog.write("CALIBRATION","Edges were marked right-to-left; the screen direction was corrected automatically")
                    }
                }
            }
        }
        onScreen?(pose)
        publish()
    }
    func sessionWasInterrupted(_ session:ARSession) {
        appLog.write("TRACKING","Camera session interrupted (app in background, camera used elsewhere or device overheating)")
        emitUnavailable(.interrupted)
    }
    func sessionInterruptionEnded(_ session:ARSession) {
        appLog.write("TRACKING","Camera session resumed; ARKit has to find its position again")
    }
    func session(_ session:ARSession,didFailWithError error:Error) {
        let code = (error as? ARError).map { " (ARError \($0.code.rawValue))" } ?? ""
        appLog.write("TRACKING","Camera tracking failed: \(error.localizedDescription)\(code)")
        emitUnavailable(.failed)
    }
    private func publish() {
        let status: String
        if !active { status = "Camera tracking off — the game uses motion only" }
        else if loadedRoom && screen == nil {
            status = warnedRelocalizing ? "Saved room not recognised. Look around the desk, or tap Forget Saved Room and calibrate again."
                : (reason == .normal || reason == .relocalizing ? "Recognising saved room — look around the desk" : (reason ?? .initializing).text)
        }
        else if reason != .normal { status = (reason ?? .initializing).text }
        else if left != nil { status = "Left edge marked. Touch the right edge, then tap Mark right edge." }
        else if let screen { status = String(format:"Screen calibrated · %.1f cm wide%@",screen.width*100,savePending ? " · saving room…" : " · room saved") }
        else { status = "Not calibrated. Touch the left screen edge with the camera corner, then tap Mark left edge." }
        if screenStatus != status { screenStatus = status }
        if canMark != (camera != nil) { canMark = camera != nil }
        if leftMarked != (left != nil) { leftMarked = left != nil }
        if calibrated != (screen != nil) { calibrated = screen != nil }
        let saved = roomStored || screen != nil || loadedRoom
        if hasSavedRoom != saved { hasSavedRoom = saved }
    }
}
