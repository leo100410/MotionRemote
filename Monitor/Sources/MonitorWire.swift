import Foundation
import simd

// Reads what the phone sends (DSUS packets); DSU.valid only accepts client packets.
enum MonitorWire {
    struct State {
        var counter: UInt32
        var timestamp: UInt64
        var buttons: [String]
        var acceleration: SIMD3<Float> // g, phone axes
        var rotationRate: SIMD3<Float> // deg/s, phone axes
    }
    static func valid(_ b: [UInt8]) -> Bool {
        guard b.count >= 20, b.count <= 1024, Array(b[0..<4]) == Array("DSUS".utf8),
              DSU.get(b,4,2) == 1001, Int(DSU.get(b,6,2))+16 == b.count else { return false }
        var copy = b; DSU.put(UInt32(0),8,&copy)
        return UInt64(DSU.crc(copy)) == DSU.get(b,8,4)
    }
    static func float(_ b: [UInt8], _ offset: Int) -> Float { Float(bitPattern:UInt32(DSU.get(b,offset,4))) }
    static func register(slot: UInt8, identity: DSU.Identity) -> [UInt8] {
        var b = DSU.packet(0x100002,size:28,identity:identity)
        b[3] = 67; b[20] = 1; b[21] = slot; DSU.finish(&b); return b
    }
    static func state(_ b: [UInt8], slot: UInt8) -> State? {
        guard valid(b), b.count == 100, DSU.get(b,16,4) == 0x100002, b[20] == slot else { return nil }
        let v = (0..<6).map { float(b,76+$0*4) }
        guard v.allSatisfy(\.isFinite) else { return nil }
        var buttons = [String]()
        for (name,index) in [("Up",47),("Down",45),("Left",44),("Right",46),("A",49),("B",50),("1",48),("2",51),("+",52),("-",53)] where b[index] > 0 { buttons.append(name) }
        if b[38] != 0 { buttons.append("Home") }
        if b[36] & 4 != 0 { buttons.append("Recenter") }
        // Undo the DSU axis order of Controller.sample so the graphs use the phone's own axes.
        return State(counter:UInt32(DSU.get(b,32,4)),timestamp:DSU.get(b,68,8),buttons:buttons,
                     acceleration:SIMD3(-v[0],-v[2],v[1]),rotationRate:SIMD3(v[3],v[5],-v[4]))
    }
    static func attitude(_ b: [UInt8], slot: UInt8) -> simd_quatf? {
        guard valid(b), b.count == 48, DSU.get(b,16,4) == 0x100006, b[20] == slot else { return nil }
        let q = SIMD4(float(b,32),float(b,36),float(b,40),float(b,44))
        guard (0..<4).allSatisfy({ q[$0].isFinite }), simd_length_squared(q) > 0.00001 else { return nil }
        return simd_normalize(simd_quatf(vector:q))
    }
    static func pose(_ b: [UInt8], slot: UInt8) -> SpatialPose? {
        guard valid(b), b.count == 68, DSU.get(b,16,4) == 0x100004, b[20] == slot else { return nil }
        let p = SpatialPose(timestamp:Double(DSU.get(b,32,8))/1_000_000,epoch:UInt32(DSU.get(b,24,4)),sequence:UInt32(DSU.get(b,28,4)),tracking:b[21],
                            position:SIMD3(float(b,40),float(b,44),float(b,48)),orientation:SIMD4(float(b,52),float(b,56),float(b,60),float(b,64)))
        return p.isValid ? p : nil
    }
    static func screen(_ b: [UInt8], slot: UInt8) -> ScreenPose? {
        guard valid(b), b.count == 68, DSU.get(b,16,4) == 0x100007, b[20] == slot, b[21] <= 2 else { return nil }
        let p = ScreenPose(timestamp:Double(DSU.get(b,28,8))/1_000_000,sequence:UInt32(DSU.get(b,24,4)),tracking:b[21],
                           reason:ScreenPose.Reason(rawValue:b[22]) ?? .unavailable,calibrated:b[23] & 1 != 0,relocalizing:b[23] & 2 != 0,
                           lidar:b[23] & 4 != 0,width:float(b,36),position:SIMD3(float(b,40),float(b,44),float(b,48)),
                           orientation:SIMD4(float(b,52),float(b,56),float(b,60),float(b,64)))
        guard p.width.isFinite, (0..<3).allSatisfy({ p.position[$0].isFinite && abs(p.position[$0]) < 100 }),
              (0..<4).allSatisfy({ p.orientation[$0].isFinite }), simd_length_squared(p.orientation) > 0.00001 || p.tracking < 2 else { return nil }
        return p
    }
    // Byte 22 asks MotionRemote 1.15+ for a one-shot haptic effect instead of continuous rumble; Dolphin leaves it 0.
    enum Haptic: UInt8 { case good = 1, bad, miss }
    // Client packet; the phone plays it through the same path as Dolphin's game rumble.
    static func rumble(_ strength: Float, sequence: UInt32, slot: UInt8, identity: DSU.Identity, haptic: Haptic? = nil) -> [UInt8] {
        var b = DSU.packet(0x100003,size:28,identity:identity)
        b[3] = 67; b[20] = slot; b[21] = UInt8(max(0,min(1,strength))*255); b[22] = haptic?.rawValue ?? 0
        DSU.put(sequence,24,&b); DSU.finish(&b); return b
    }
    // Degrees about the phone's X (pitch), Y (roll) and Z (yaw) axes.
    static func angles(_ rotation: simd_quatf) -> SIMD3<Float> {
        let q = rotation.vector
        let pitch = atan2(2*(q.w*q.x+q.y*q.z),1-2*(q.x*q.x+q.y*q.y))
        let roll = asin(max(-1,min(1,2*(q.w*q.y-q.z*q.x))))
        let yaw = atan2(2*(q.w*q.z+q.x*q.y),1-2*(q.y*q.y+q.z*q.z))
        return SIMD3(pitch,roll,yaw)*(180 / .pi)
    }
}
