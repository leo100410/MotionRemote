import ARKit
import Combine

final class SpatialTracker: NSObject, ARSessionDelegate {
    let session = ARSession()
    var onPose: ((SpatialPose) -> Void)?
    private var active = false
    private var origin: SIMD3<Float>?
    private var epoch: UInt32 = 0
    private var sequence: UInt32 = 0
    override init() {
        super.init()
        session.delegate = self
        session.delegateQueue = .main
    }
    func start() {
        guard ARWorldTrackingConfiguration.isSupported else { emitUnavailable(); return }
        active = true; origin = nil; epoch = UInt32.random(in:1...UInt32.max); sequence = 0
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        session.run(configuration,options:[.resetTracking,.removeExistingAnchors])
    }
    func stop() { active = false; session.pause(); emitUnavailable() }
    private func emitUnavailable() {
        sequence &+= 1
        onPose?(SpatialPose(timestamp:ProcessInfo.processInfo.systemUptime,epoch:epoch,sequence:sequence,
                            tracking:0,position:.zero,orientation:SIMD4(0,0,0,1)))
    }
    func session(_ session:ARSession,didUpdate frame:ARFrame) {
        guard active else { return }
        let quality: UInt8
        switch frame.camera.trackingState {
        case .normal: quality = 2
        case .limited: quality = 1
        default: quality = 0
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
    }
    func sessionWasInterrupted(_ session:ARSession) { emitUnavailable() }
    func session(_ session:ARSession,didFailWithError error:Error) { emitUnavailable() }
}
