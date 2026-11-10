import Foundation
import simd
func sample(_ time:Double,_ rotation:simd_quatd = simd_quatd(angle:0,axis:SIMD3(0,1,0))) -> MotionFrame {
    MotionFrame(time:time,attitude:rotation.vector,acceleration:SIMD3(1,0,0),angularVelocity:SIMD3(0,2,0),buttons:["A"])
}
var buffer = TakeBuffer(sport:"Golf",player:2)
assert(!buffer.append(sample(100)))
assert(!buffer.append(sample(100)))
assert(!buffer.append(sample(99)))
assert(!buffer.append(sample(.nan)))
assert(buffer.take.frames.count == 1)
let halfTurn = simd_quatd(angle:.pi,axis:SIMD3(0,1,0))
assert(!buffer.append(sample(102,halfTurn)))
let take = buffer.take
assert(take.isValid && take.duration == 2 && take.frames[0].time == 0)
let midpoint = take.rotation(at:1).act(SIMD3<Float>(0,0,1))
assert(abs(abs(midpoint.x)-1) < 0.00001 && abs(midpoint.z) < 0.00001)
assert(take.frame(at:-5).time == 0 && take.frame(at:20).time == 2)
assert(simd_length(take.rotation(at:0).vector-SIMD4<Float>(0,0,0,1)) < 0.00001)
let data = try JSONEncoder().encode(take)
let restored = try JSONDecoder().decode(MotionTake.self,from:data)
assert(restored.id == take.id && restored.isValid && restored.frames[1].buttons == ["A"])
var malformed = take
malformed.frames[1].time = 0; assert(!malformed.isValid)
malformed = take; malformed.frames[0].attitude = .zero; assert(!malformed.isValid)
malformed = take; malformed.frames[0].attitude = SIMD4(repeating:1e300); assert(!malformed.isValid)
malformed = take; malformed.frames[1].acceleration.x = .infinity; assert(!malformed.isValid)
var signFlip = take; signFlip.frames[1].attitude = -signFlip.frames[0].attitude
assert(abs(signFlip.rotation(at:1).real-1) < 0.00001)
var long = TakeBuffer(sport:"Tennis",player:1)
for i in 0...12_000 { let full = long.append(sample(Double(i)/100)); assert(full == (i == 12_000)) }
assert(long.take.isValid && long.take.frames.count == 12_001 && long.take.duration == 120)
assert(long.append(sample(121)))
assert(long.take.frames.count == 12_001)
let url = URL(fileURLWithPath:"/tmp/motionremote-recording-roundtrip.json")
try data.write(to:url,options:.atomic)
let fromDisk = try JSONDecoder().decode(MotionTake.self,from:Data(contentsOf:url))
assert(fromDisk.isValid)
print("Recording tests passed: relative timestamps, duplicates/out-of-order samples, 2-minute bound, JSON disk round-trip, corrupt data, quaternion interpolation and relative orientation")
