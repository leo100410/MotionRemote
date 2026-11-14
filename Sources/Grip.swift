import simd

// How the phone is held. The racket grips roll the phone 90° about its long axis; turning the
// measurements back makes Dolphin see a Wii Remote held display up.
enum Grip: String, CaseIterable, Identifiable {
    case remote, racketLeft, racketRight
    var id: Self { self }
    var title: String {
        switch self {
        case .remote: "Wii Remote"
        case .racketLeft: "Racket, screen left"
        case .racketRight: "Racket, screen right"
        }
    }
    /// Rotates device-frame vectors into the frame of a phone held display up (x right, y top edge, z display).
    var turn: simd_quatd {
        switch self {
        case .remote: simd_quatd(ix:0,iy:0,iz:0,r:1)
        case .racketLeft: simd_quatd(angle:-.pi/2,axis:SIMD3(0,1,0))
        case .racketRight: simd_quatd(angle:.pi/2,axis:SIMD3(0,1,0))
        }
    }
    func vector(_ v: SIMD3<Double>) -> SIMD3<Double> { turn.act(v) }
    /// For orientations that map device axes to the world (Core Motion attitude, ARKit pose).
    func orientation(_ q: simd_quatd) -> simd_quatd { q*turn.inverse }
}

/// Picks the grip from gravity, but only while the phone is held still and roughly level (pointing at the
/// screen) for HoldTime: a swing or wind-up resets the window, so the grip never changes mid-stroke.
struct GripDetector {
    static let holdTime = 0.6, maxUserAcceleration = 0.15, maxRotation = 1.0, maxPitch = 0.7
    private(set) var current: Grip
    private var candidate: Grip?
    private var since = 0.0
    init(_ grip: Grip) { current = grip }
    /// Core Motion gravity and user acceleration in g (device frame), rotation in rad/s, time in seconds.
    /// Returns the grip when it changes.
    mutating func update(gravity g: SIMD3<Double>, userAcceleration a: SIMD3<Double>, rotation w: SIMD3<Double>, time t: Double) -> Grip? {
        guard simd_length(a) < Self.maxUserAcceleration, simd_length(w) < Self.maxRotation, abs(g.y) < Self.maxPitch,
              let seen = Self.classify(g) else { candidate = nil; return nil }
        if seen != candidate { candidate = seen; since = t; return nil }
        guard seen != current, t-since >= Self.holdTime else { return nil }
        current = seen
        return seen
    }
    /// Roll about the long axis: 0° display up, -90° display left, +90° display right; the gaps between are ignored.
    static func classify(_ g: SIMD3<Double>) -> Grip? {
        switch atan2(g.x,-g.z)*180 / .pi {
        case -35...35: .remote
        case -125 ... -55: .racketLeft
        case 55...125: .racketRight
        default: nil
        }
    }
}

/// DSU motion for Dolphin from Core Motion gravity+userAcceleration (g, gravity pointing down) and rotation rate (deg/s).
/// Dolphin turns DSU accel (x, y, z) into Wii accel (x, -z, -y). Its own swing emulation (EmulateSwing) uses
/// X+ to the left, Y+ back towards the player and Z+ out of the buttons; the accelerometer reads specific force.
func dsuMotion(accel a: SIMD3<Double>, rate w: SIMD3<Double>) -> [Float] {
    [Float(a.x),Float(a.z),Float(-a.y),Float(w.x),Float(-w.z),Float(w.y)]
}
