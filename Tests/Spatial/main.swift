import Foundation
import simd
let identity = DSU.Identity(uuid:UUID(uuidString:"01234567-89AB-CDEF-0123-456789ABCDEF")!)
var pose = SpatialPose(timestamp:123.5,epoch:12,sequence:4,tracking:2,position:SIMD3(0.25,-0.5,1),orientation:SIMD4(0,0,0,1))
let b = DSU.pose(pose,slot:2,identity:identity)!
assert(b.count == 68 && DSU.get(b,16,4) == 0x100004 && b[20] == 2 && b[21] == 2)
assert(DSU.get(b,24,4) == 12 && DSU.get(b,28,4) == 4 && DSU.get(b,32,8) == 123_500_000)
assert(Float(bitPattern:UInt32(DSU.get(b,40,4))) == 0.25)
assert(Float(bitPattern:UInt32(DSU.get(b,44,4))) == -0.5)
assert(Float(bitPattern:UInt32(DSU.get(b,64,4))) == 1)
var copy = b; DSU.put(UInt32(0),8,&copy); assert(DSU.get(b,8,4) == DSU.crc(copy))
try Data(b).write(to:URL(fileURLWithPath:"/tmp/motionremote-spatial.bin"))
pose.timestamp = 1e300; assert(DSU.pose(pose,slot:2,identity:identity) == nil)
pose.timestamp = 1; pose.position.x = .nan; assert(!pose.isValid)
pose.position.x = 0; pose.orientation = .zero; assert(!pose.isValid)
pose.orientation = SIMD4(0,0,0,1); pose.tracking = 3; assert(!pose.isValid)
print("Spatial protocol tests passed: packet length, axes/metres, rotation quaternion, clock, CRC and invalid input")
