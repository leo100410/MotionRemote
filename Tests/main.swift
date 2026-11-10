import Foundation
assert(DSU.crc(Array("123456789".utf8)) == 0xcbf43926)
let b = DSU.state(buttons:["A","B","1","+","Home","Zentrieren"],motion:[0,-1,0,90,0,0],timestamp:123456,counter:42)
assert(b.count == 100 && b[49] == 255 && b[50] == 255 && b[48] == 255)
assert(b[36] == 12 && b[38] == 1)
assert(DSU.get(b,68,8) == 123456 && DSU.get(b,32,4) == 42)
assert(Float(bitPattern: UInt32(DSU.get(b,80,4))) == -1)
let released = DSU.state(buttons:[],motion:[],timestamp:0,counter:43)
assert(released[36..<40].allSatisfy { $0 == 0 })
assert(released[44..<56].allSatisfy { $0 == 0 })
var request = DSU.packet(0x100002,size:28)
request[3] = 67; DSU.finish(&request)
assert(DSU.valid(request))
request[25] ^= 1; assert(!DSU.valid(request))
for n in 0..<20 { assert(!DSU.valid(Array(repeating:0,count:n))) }
try Data(b).write(to:URL(fileURLWithPath:"/tmp/motionremote-packet.bin"))
print("DSU packet, CRC, axis units, button release and malformed input checks passed")

let identities = (0..<4).map { DSU.Identity(uuid:UUID(uuidString:"0102030\($0)-000\($0)-4000-8000-00000000000\($0)")!) }
assert(Set(identities.map(\.uid)).count == 4)
assert(Set(identities.map { Data($0.mac) }).count == 4)
for player in 0..<4 {
    let identity = identities[player]
    let state = DSU.state(buttons:player == 0 ? ["A"] : ["B"],motion:[],timestamp:1,counter:1,slot:UInt8(player),identity:identity)
    assert(state[20] == player && Array(state[24..<30]) == identity.mac)
    assert(DSU.get(state,12,4) == identity.uid)
    assert(state[49] == (player == 0 ? 255 : 0))
    for target in 0..<4 {
        var request = DSU.packet(0x100002,size:28)
        request[3] = 67; request[20] = 1; request[21] = UInt8(target); DSU.finish(&request)
        assert(DSU.acceptsRegistration(request,slot:UInt8(player),identity:identity) == (target == player))
        request[20] = 2; request.replaceSubrange(22..<28,with:identities[target].mac); DSU.finish(&request)
        assert(DSU.acceptsRegistration(request,slot:UInt8(player),identity:identity) == (target == player))
        request[20] = 3; request[21] = UInt8((player+1)%4); DSU.finish(&request)
        assert(!DSU.acceptsRegistration(request,slot:UInt8(player),identity:identity))
    }
}
print("Four-player identity, slot, isolated button states and subscription filtering checks passed")
var rumble = DSU.packet(0x100003,size:28)
rumble[3] = 67; rumble[20] = 2; rumble[21] = 200
DSU.put(UInt32(123),12,&rumble); DSU.put(UInt32.max,24,&rumble); DSU.finish(&rumble)
assert(DSU.acceptsRumble(rumble,slot:2,clientUID:123))
assert(!DSU.acceptsRumble(rumble,slot:1,clientUID:123))
assert(!DSU.acceptsRumble(rumble,slot:2,clientUID:124))
rumble[21] ^= 1; assert(!DSU.acceptsRumble(rumble,slot:2,clientUID:123))
assert(DSU.isNewer(0,than:UInt32.max))
assert(!DSU.isNewer(10,than:10) && !DSU.isNewer(9,than:10))
print("Rumble CRC, device routing, client identity, duplicate/reordered packets and sequence wrap checks passed")
let nativeRumble = Array(try Data(contentsOf:URL(fileURLWithPath:"/tmp/motionremote-native-rumble.bin")))
assert(DSU.acceptsRumble(nativeRumble,slot:2,clientUID:123))
assert(nativeRumble[21] == 255 && DSU.get(nativeRumble,24,4) == 9)
print("Swift accepts the actual Dolphin C++ rumble packet")
