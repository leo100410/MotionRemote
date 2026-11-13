import SwiftUI
import AVFoundation
import AVKit
import ARKit

// Logs/ in Documents is visible in the Files app (On My iPhone → MotionRemote).
let appLog: EventLog = {
    let documents = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
    let log = EventLog(directory:documents.appendingPathComponent("Logs"),prefix:"MotionRemote")
    let info = Bundle.main.infoDictionary
    log.write("APP","MotionRemote \(info?["CFBundleShortVersionString"] ?? "?") (\(info?["CFBundleVersion"] ?? "?")) on \(UIDevice.current.model), iOS \(UIDevice.current.systemVersion)")
    return log
}()

@main struct MotionRemoteApp: App {
    var body: some Scene { WindowGroup { RemoteView() } }
}

final class Probe: ObservableObject {
    @Published var status = "Volume trigger idle"
    @Published var events: [String] = []
    @Published var held = Set<String>()
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera")
    private var configured = false
    private var generation = 0
    let spatial = SpatialTracker()
    @Published private(set) var spatialEnabled = false
    var onEvent: ((String, AVCaptureEventPhase) -> Void)?
    func start(spatial useSpatial:Bool = false) {
        generation += 1; let token = generation
        spatialEnabled = useSpatial
        spatial.stop()
        AVCaptureDevice.requestAccess(for:.video) { allowed in
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                guard allowed else { self.status = "Camera access denied — enable it in Settings"; return }
                self.queue.async {
                    self.session.stopRunning()
                    if useSpatial {
                        DispatchQueue.main.async {
                            guard self.generation == token else { return }
                            self.spatial.start()
                            self.status = "Spatial camera active — keep rear camera clear"
                        }
                        return
                    }
                    do {
                        if !self.configured {
                            guard let camera = AVCaptureDevice.default(for:.video) else { return }
                            let input = try AVCaptureDeviceInput(device:camera)
                            self.session.beginConfiguration(); self.session.sessionPreset = .low
                            guard self.session.canAddInput(input) else {
                                self.session.commitConfiguration(); throw NSError(domain:"Camera",code:1)
                            }
                            self.session.addInput(input); self.session.commitConfiguration(); self.configured = true
                        }
                        self.session.startRunning()
                        DispatchQueue.main.async {
                            if self.generation == token { self.status = "Volume trigger ready" }
                        }
                    } catch { DispatchQueue.main.async { self.status = error.localizedDescription } }
                }
            }
        }
    }
    func stop() {
        generation += 1
        held.removeAll(); status = "Volume trigger stopped"
        spatial.stop()
        queue.async { self.session.stopRunning() }
    }
    func event(_ source: String, _ event: AVCaptureEvent) {
        onEvent?(source, event.phase)
        let phase: String
        switch event.phase {
        case .began: held.insert(source); phase = "pressed"
        case .ended: held.remove(source); phase = "released"
        default: held.remove(source); phase = "cancelled"
        }
        events.insert("\(Date().formatted(date: .omitted, time: .standard)) · \(source): \(phase)", at: 0)
        events = Array(events.prefix(300))
    }
}

struct CaptureSurface: UIViewRepresentable {
    let probe: Probe
    func makeUIView(context:Context) -> CameraSurface {
        let view = CameraSurface(probe:probe)
        view.addInteraction(AVCaptureEventInteraction(primary:{ probe.event("Primary",$0) },secondary:{ probe.event("Secondary",$0) }))
        return view
    }
    func updateUIView(_ view:CameraSurface,context:Context) {
        view.ar.isHidden = !probe.spatialEnabled
        view.preview.isHidden = probe.spatialEnabled
    }
    final class CameraSurface: UIView {
        let preview = AVCaptureVideoPreviewLayer()
        let ar = ARSCNView(frame:.zero)
        init(probe:Probe) {
            super.init(frame:.zero)
            clipsToBounds = true
            preview.session = probe.session; preview.videoGravity = .resizeAspectFill
            layer.addSublayer(preview)
            ar.session = probe.spatial.session
            probe.spatial.session.delegate = probe.spatial
            addSubview(ar)
        }
        required init?(coder:NSCoder) { fatalError("init(coder:) is not supported") }
        override func layoutSubviews() { super.layoutSubviews(); preview.frame = bounds; ar.frame = bounds }
    }
}
