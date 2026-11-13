import Foundation
import simd

struct SpatialPose {
    var timestamp: Double
    var epoch: UInt32
    var sequence: UInt32
    var tracking: UInt8 // 0 unavailable, 1 limited, 2 normal.
    var position: SIMD3<Float>
    var orientation: SIMD4<Float>
    var isValid: Bool {
        timestamp.isFinite && timestamp >= 0 && timestamp < Double(UInt64.max)/1_000_000 && tracking <= 2
        && (0..<3).allSatisfy { position[$0].isFinite && abs(position[$0]) <= 1000 }
        && (0..<4).allSatisfy { orientation[$0].isFinite }
        && simd_length_squared(orientation).isFinite && simd_length_squared(orientation) > 0.00001
    }
}

// Phone pose in the calibrated screen frame: origin at the screen centre, x right along the screen,
// y up (gravity), z towards the player, metres. Sent at the camera frame rate as packet 0x100007.
struct ScreenPose {
    var timestamp: Double
    var sequence: UInt32
    var tracking: UInt8 // 0 unavailable, 1 limited, 2 normal.
    var reason: Reason
    var calibrated: Bool
    var relocalizing: Bool // a saved room was loaded and has not been recognised yet
    var lidar: Bool
    var width: Float // measured screen width, metres
    var position: SIMD3<Float>
    var orientation: SIMD4<Float>
    enum Reason: UInt8 {
        case normal, initializing, excessiveMotion, insufficientFeatures, relocalizing, unavailable, interrupted, failed, off
        var text: String {
            switch self {
            case .normal: return "Tracking normally"
            case .initializing: return "Starting camera tracking — move the phone slowly so it can see the room"
            case .excessiveMotion: return "Phone moved too fast for the camera"
            case .insufficientFeatures: return "Camera sees too little detail (dark room, blank wall or ceiling, covered lens)"
            case .relocalizing: return "Recognising the saved room — look around the desk"
            case .unavailable: return "Camera tracking unavailable"
            case .interrupted: return "Camera tracking interrupted (app in background or camera used elsewhere)"
            case .failed: return "Camera tracking failed"
            case .off: return "Camera tracking switched off — motion only"
            }
        }
    }
}
