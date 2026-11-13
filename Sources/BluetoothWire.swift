import Foundation

// A route identifies one UDP client inside the BLE tunnel (discovery, input or diagnostics).
enum BluetoothWire {
    static let service = "AE904FB0-21B6-46C5-ACB3-186947A6B100"
    static let input = "AE904FB0-21B6-46C5-ACB3-186947A6B101"
    static let output = "AE904FB0-21B6-46C5-ACB3-186947A6B102"
    static func frames(_ data: Data, route: UInt8, sequence: UInt8, mtu: Int) -> [Data] {
        guard route < 16, !data.isEmpty, data.count <= 1024, mtu > 4 else { return [] }
        let size = mtu-4, count = (data.count+size-1)/size
        guard count <= 64 else { return [] }
        return (0..<count).map { i in Data([route,sequence,UInt8(i),UInt8(count)]) + data.subdata(in:i*size..<min(data.count,(i+1)*size)) }
    }
    struct Decoder {
        private var parts: [UInt8:(UInt8,UInt8,UInt8,Double,Data)] = [:]
        mutating func accept(_ frame: Data, now: Double) -> (UInt8,Data)? {
            let b = [UInt8](frame)
            guard b.count > 4, b[0] < 16, b[3] > 0, b[3] <= 64, b[2] < b[3] else { return nil }
            parts = parts.filter { now-$0.value.3 < 0.25 }
            if b[2] == 0 { parts[b[0]] = (b[1],b[3],0,now,Data()) }
            guard var p = parts[b[0]], p.0 == b[1], p.1 == b[3], p.2 == b[2], p.4.count+b.count-4 <= 1024 else { parts.removeValue(forKey:b[0]); return nil }
            p.4.append(contentsOf:b.dropFirst(4)); p.2 += 1
            if p.2 == p.1 { parts.removeValue(forKey:b[0]); return (b[0],p.4) }
            parts[b[0]] = p; return nil
        }
    }
}
