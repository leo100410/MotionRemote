import Foundation
func hex(_ data: Data) -> String { data.map { String(format:"%02x",$0) }.joined() }
func bytes(_ text: String) -> Data { let b=Array(text.utf8); return Data(stride(from:0,to:b.count,by:2).map { UInt8(String(bytes:b[$0..<$0+2],encoding:.utf8)!,radix:16)! }) }
let path = CommandLine.arguments[2]
if CommandLine.arguments[1] == "write" {
    var lines = [String]()
    for mtu in [20,64,185,512] {
        for length in [1,32,68,100,1024] {
            for route in [UInt8(0),15] {
                let packet=Data((0..<length).map { UInt8(truncatingIfNeeded:$0*7) })
                let frames=BluetoothWire.frames(packet,route:route,sequence:255,mtu:mtu)
                assert(!frames.isEmpty && frames.allSatisfy { $0.count <= mtu })
                var decoder=BluetoothWire.Decoder();var result:(UInt8,Data)?
                for frame in frames { result=decoder.accept(frame,now:1) }
                assert(result?.0==route && result?.1==packet)
                lines.append("\(route):\(hex(packet)):\(frames.map(hex).joined(separator:","))")
            }
        }
    }
    assert(BluetoothWire.frames(Data([1]),route:16,sequence:0,mtu:20).isEmpty)
    assert(BluetoothWire.frames(Data(repeating:0,count:1025),route:0,sequence:0,mtu:20).isEmpty)
    assert(BluetoothWire.frames(Data([1]),route:0,sequence:0,mtu:4).isEmpty)
    let frames=BluetoothWire.frames(Data(repeating:4,count:100),route:0,sequence:0,mtu:20)
    var decoder=BluetoothWire.Decoder()
    assert(decoder.accept(frames[0],now:0)==nil)
    assert(decoder.accept(frames[1],now:0.3)==nil)
    assert(decoder.accept(Data([16,0,0,1,3]),now:0)==nil)
    try lines.joined(separator:"\n").write(toFile:path,atomically:true,encoding:.utf8)
} else {
    for line in try String(contentsOfFile:path,encoding:.utf8).split(separator:"\n") {
        let parts=line.split(separator:":");let route=UInt8(parts[0])!,packet=bytes(String(parts[1]));var decoder=BluetoothWire.Decoder();var value:(UInt8,Data)?
        for frame in parts[2].split(separator:",") { value=decoder.accept(bytes(String(frame)),now:0) }
        assert(value?.0==route && value?.1==packet)
    }
    print("PASS: C++ host → Swift iPhone framing interoperability, MTUs 20–512, routes 0/15, packets 1–1024 bytes")
}
