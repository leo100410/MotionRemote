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
