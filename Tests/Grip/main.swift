import simd
// swiftc Sources/Grip.swift Tests/Grip/main.swift -o /tmp/grip && /tmp/grip
func near(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Bool { simd_length(a-b) < 1e-9 }
// Display up, top forward: gravity is -z. Racket with the display facing left: device +x points up, so gravity is -x.
precondition(near(Grip.remote.vector([0,0,-1]),[0,0,-1]))
precondition(near(Grip.racketLeft.vector([-1,0,0]),[0,0,-1]))
precondition(near(Grip.racketRight.vector([1,0,0]),[0,0,-1]))
// The long axis is unchanged, and the display normal ends up pointing up.
for g in Grip.allCases { precondition(near(g.vector([0,1,0]),[0,1,0])) }
precondition(near(Grip.racketLeft.vector([0,0,1]),[-1,0,0]) && near(Grip.racketRight.vector([0,0,1]),[1,0,0]))
// An attitude rotates virtual-frame vectors the same way the original rotates device-frame vectors.
let q = simd_quatd(angle:0.7,axis:simd_normalize(SIMD3(0.3,-0.5,0.8)))
for g in Grip.allCases {
    let v = SIMD3(0.2,-0.4,0.9)
    precondition(near(g.orientation(q).act(g.vector(v)),q.act(v)))
}
// Wii accel as Dolphin builds it from DSU (x, -z, -y) must match a real Wii Remote:
// flat buttons up z = +1, pointing end up y = -1 (Y+ is back), right side down x = +1 (X+ is left).
func wii(_ raw: SIMD3<Double>) -> SIMD3<Float> { let v = dsuMotion(accel:raw,rate:.zero); return SIMD3(v[0],-v[2],-v[1]) }
precondition(wii([0,0,-1]) == SIMD3(0,0,1))
precondition(wii([0,-1,0]) == SIMD3(0,-1,0))
precondition(wii([1,0,0]) == SIMD3(1,0,0))
// Grip detection: only calm, level, steady holding switches the grip.
let still = SIMD3<Double>(0,0,0)
func hold(_ d: inout GripDetector, gravity g: SIMD3<Double>, from t0: Double, seconds: Double, accel: SIMD3<Double> = still) -> Grip? {
    var found: Grip?
    for i in 0..<Int(seconds*100) { found = d.update(gravity:g,userAcceleration:accel,rotation:still,time:t0+Double(i)/100) ?? found }
    return found
}
var d = GripDetector(.remote)
precondition(hold(&d,gravity:[-1,0,0],from:0,seconds:0.5) == nil)              // not long enough yet
precondition(hold(&d,gravity:[-1,0,0],from:0.5,seconds:0.2) == .racketLeft)    // 0.6 s steady: display left
precondition(hold(&d,gravity:[1,0,0],from:1,seconds:0.3) == nil)
precondition(hold(&d,gravity:[1,0,0],from:1.3,seconds:0.2,accel:[0.5,0,0]) == nil) // movement resets the window
precondition(hold(&d,gravity:[1,0,0],from:1.5,seconds:0.4) == nil)
precondition(hold(&d,gravity:[1,0,0],from:1.9,seconds:0.3) == .racketRight)
precondition(hold(&d,gravity:[0,-1,0],from:3,seconds:2) == nil)                 // pointing down: roll undefined
precondition(hold(&d,gravity:simd_normalize([-0.7,0,-0.7]),from:5,seconds:2) == nil) // 45°: between grips
precondition(hold(&d,gravity:simd_normalize([0,0.5,-0.85]),from:7,seconds:1) == .remote) // pitched 30°, display up
precondition(d.current == .remote)
print("grip ok")
