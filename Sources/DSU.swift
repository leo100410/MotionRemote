import Foundation

// DSU v1001: little-endian packets with CRC32 over the zeroed checksum field.
enum DSU {
    struct Identity {
        let uid: UInt32
        let mac: [UInt8]
        init(uuid: UUID) {
            var bytes = uuid.uuid
            let data = withUnsafeBytes(of:&bytes) { Array($0) }
            uid = UInt32(data[0]) | UInt32(data[1]) << 8 | UInt32(data[2]) << 16 | UInt32(data[3]) << 24
            mac = [2] + Array(data[4..<9])
        }
    }
    static func acceptsRumble(_ b: [UInt8], slot: UInt8, clientUID: UInt64) -> Bool {
        valid(b) && b.count == 28 && get(b,16,4) == 0x100003 && b[20] == slot && get(b,12,4) == clientUID
    }
    static func isNewer(_ sequence: UInt32, than previous: UInt32) -> Bool {
        let difference = sequence &- previous
        return difference != 0 && difference < 0x80000000
    }
    static let legacyIdentity = Identity(uuid:UUID(uuidString:"4D52454D-4D52-0000-0100-000000000000")!)
    static func acceptsRegistration(_ b: [UInt8], slot: UInt8, identity: Identity) -> Bool {
        guard valid(b), b.count == 28, get(b,16,4) == 0x100002, b[20] & ~UInt8(3) == 0 else { return false }
        return (b[20] & 1 == 0 || b[21] == slot) && (b[20] & 2 == 0 || Array(b[22..<28]) == identity.mac)
    }

    static func crc(_ bytes: [UInt8]) -> UInt32 {
        var c: UInt32 = 0xffffffff
        for b in bytes {
            c ^= UInt32(b)
            for _ in 0..<8 { c = (c >> 1) ^ ((c & 1) == 1 ? 0xedb88320 : 0) }
        }
        return ~c
    }
    static func put<T: FixedWidthInteger>(_ v: T, _ offset: Int, _ bytes: inout [UInt8]) {
        for i in 0..<MemoryLayout<T>.size { bytes[offset+i] = UInt8(truncatingIfNeeded: v >> (i*8)) }
    }
    static func get(_ bytes: [UInt8], _ offset: Int, _ count: Int) -> UInt64 {
        (0..<count).reduce(0) { $0 | UInt64(bytes[offset+$1]) << ($1*8) }
    }
    static func packet(_ type: UInt32, size: Int, identity: Identity = legacyIdentity) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: size)
        b.replaceSubrange(0..<4, with: Array("DSUS".utf8))
        put(UInt16(1001),4,&b); put(UInt16(size-16),6,&b)
        put(identity.uid,12,&b); put(type,16,&b)
        return b
    }
    static func pose(_ pose: SpatialPose, slot: UInt8, identity: Identity) -> [UInt8]? {
        guard pose.isValid else { return nil }
        var b = packet(0x100004,size:68,identity:identity)
        b[20] = slot; b[21] = pose.tracking
        put(pose.epoch,24,&b); put(pose.sequence,28,&b)
        put(UInt64(pose.timestamp*1_000_000),32,&b)
        for i in 0..<3 { put(pose.position[i].bitPattern,40+i*4,&b) }
        for i in 0..<4 { put(pose.orientation[i].bitPattern,52+i*4,&b) }
        finish(&b); return b
    }
    // MotionRemote extension for the Mac monitor: the fused Core Motion attitude.
    static func attitude(_ q: SIMD4<Float>, timestamp: UInt64, slot: UInt8, identity: Identity) -> [UInt8] {
        var b = packet(0x100006,size:48,identity:identity)
        b[20] = slot; put(timestamp,24,&b)
        for i in 0..<4 { put((q[i].isFinite ? q[i] : 0).bitPattern,32+i*4,&b) }
        finish(&b); return b
    }
    static func screen(_ pose: ScreenPose, slot: UInt8, identity: Identity) -> [UInt8] {
        var b = packet(0x100007,size:68,identity:identity)
        b[20] = slot; b[21] = pose.tracking; b[22] = pose.reason.rawValue
        b[23] = (pose.calibrated ? 1 : 0) | (pose.relocalizing ? 2 : 0) | (pose.lidar ? 4 : 0)
        put(pose.sequence,24,&b); put(UInt64(max(0,pose.timestamp)*1_000_000),28,&b)
        put((pose.width.isFinite ? pose.width : 0).bitPattern,36,&b)
        for i in 0..<3 { put((pose.position[i].isFinite ? pose.position[i] : 0).bitPattern,40+i*4,&b) }
        for i in 0..<4 { put((pose.orientation[i].isFinite ? pose.orientation[i] : 0).bitPattern,52+i*4,&b) }
        finish(&b); return b
    }
    static func finish(_ b: inout [UInt8]) { put(UInt32(0),8,&b); put(crc(b),8,&b) }
    static func valid(_ b: [UInt8]) -> Bool {
        guard b.count >= 20, b.count <= 1024, Array(b[0..<4]) == Array("DSUC".utf8), get(b,4,2) <= 1001, Int(get(b,6,2))+16 == b.count else { return false }
        var copy = b; put(UInt32(0),8,&copy)
        return UInt64(crc(copy)) == get(b,8,4)
    }
    static func info(_ b: inout [UInt8], connected: Bool = true, slot: UInt8 = 0, identity: Identity = legacyIdentity) {
        b[20] = slot; b[21] = connected ? 2 : 0; b[22] = 2; b[23] = 2
        b.replaceSubrange(24..<30, with: identity.mac); b[30] = 5
    }
    static func state(buttons: Set<String>, motion: [Float], timestamp: UInt64, counter: UInt32, slot: UInt8 = 0, identity: Identity = legacyIdentity) -> [UInt8] {
        var b = packet(0x100002,size:100,identity:identity); info(&b,slot:slot,identity:identity); b[31] = 1
        put(counter,32,&b)
        for i in 40...43 { b[i] = 128 }
        let analog = ["Left":44,"Down":45,"Right":46,"Up":47,"1":48,"A":49,"B":50,"2":51,"+":52,"-":53]
        for button in buttons {
            if let i = analog[button] { b[i] = 255 }
            if button == "+" { b[36] |= 8 }; if button == "-" { b[36] |= 1 }
            if button == "Zentrieren" { b[36] |= 4 }
            if button == "Home" { b[38] = 1 }
        }
        put(timestamp,68,&b)
        for (i,v) in motion.prefix(6).enumerated() { put((v.isFinite ? v : 0).bitPattern,76+i*4,&b) }
        finish(&b); return b
    }
}
