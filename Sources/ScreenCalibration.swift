import simd

// The "virtual sensor bar": two touches on the screen edges define where the screen is in the camera-tracked room.
enum ScreenCalibration {
    // Rear camera to the phone's top camera corner, device axes (x right, y up, z out of the display).
    // shortcut: one offset for all iPhones and iPads (about ±1.5 cm), measure per model if the hilt must be exact.
    static let cornerOffset = SIMD3<Float>(0.015,0.015,0.004)
    static func touchPoint(_ camera: simd_float4x4) -> SIMD3<Float> {
        let p = camera*SIMD4(cornerOffset,1)
        return SIMD3(p.x,p.y,p.z)
    }
    // Origin between the marks, x from left to right mark (levelled), y world up, z towards the player.
    static func frame(left: SIMD3<Float>, right: SIMD3<Float>) -> (transform: simd_float4x4, width: Float)? {
        var x = right-left; x.y = 0
        let width = simd_length(right-left)
        guard simd_length(x) > 0.1, width <= 2.5 else { return nil }
        x = simd_normalize(x)
        let y = SIMD3<Float>(0,1,0), z = simd_cross(x,y), c = (left+right)/2
        return (simd_float4x4(columns:(SIMD4(x,0),SIMD4(y,0),SIMD4(z,0),SIMD4(c,1))),width)
    }
    // Marks taken in the wrong order put the player behind the screen; turning the frame half way fixes it.
    static func flipped(_ transform: simd_float4x4) -> simd_float4x4 {
        var t = transform
        t.columns.0 = -t.columns.0; t.columns.2 = -t.columns.2
        return t
    }
    static func pose(camera: simd_float4x4, screen: simd_float4x4) -> (position: SIMD3<Float>, orientation: simd_quatf) {
        let m = simd_inverse(screen)*camera
        let rotation = simd_float3x3(columns:(SIMD3(m.columns.0.x,m.columns.0.y,m.columns.0.z),
                                              SIMD3(m.columns.1.x,m.columns.1.y,m.columns.1.z),
                                              SIMD3(m.columns.2.x,m.columns.2.y,m.columns.2.z)))
        return (SIMD3(m.columns.3.x,m.columns.3.y,m.columns.3.z),simd_normalize(simd_quatf(rotation)))
    }
}
