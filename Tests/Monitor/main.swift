import Foundation
import simd

// The monitor must read exactly what the phone builds (DSU.swift).
let identity = DSU.Identity(uuid:UUID())

let state = DSU.state(buttons:["A","Up","Home"],motion:[0.1,-1,0.25,10,20,30],timestamp:123_456,counter:77,slot:1,identity:identity)
let parsed = MonitorWire.state(state,slot:1)!
assert(parsed.counter == 77 && parsed.timestamp == 123_456)
assert(Set(parsed.buttons) == ["A","Up","Home"])
assert(parsed.acceleration == SIMD3(-0.1,-0.25,-1) && parsed.rotationRate == SIMD3(10,30,-20))
assert(MonitorWire.state(state,slot:0) == nil)
var broken = state; broken[80] ^= 1
assert(MonitorWire.state(broken,slot:1) == nil)
assert(!DSU.valid(state)) // a server packet is never mistaken for a client request

// 90 degrees about Z reads as yaw; the attitude packet carries it unchanged.
let turn = simd_quatf(angle:.pi/2,axis:SIMD3(0,0,1))
let attitude = DSU.attitude(turn.vector,timestamp:5,slot:1,identity:identity)
assert(attitude.count == 48)
let q = MonitorWire.attitude(attitude,slot:1)!
assert(simd_length(q.vector-turn.vector) < 1e-5)
let angles = MonitorWire.angles(q)
assert(abs(angles.z-90) < 0.01 && abs(angles.x) < 0.01 && abs(angles.y) < 0.01)
assert(MonitorWire.attitude(DSU.attitude(SIMD4(0,0,0,0),timestamp:5,slot:1,identity:identity),slot:1) == nil)
assert(MonitorWire.attitude(state,slot:1) == nil)

let pose = SpatialPose(timestamp:2,epoch:3,sequence:4,tracking:2,position:SIMD3(0.1,0.2,0.3),orientation:SIMD4(0,0,0,1))
let readPose = MonitorWire.pose(DSU.pose(pose,slot:1,identity:identity)!,slot:1)!
assert(readPose.epoch == 3 && readPose.sequence == 4 && readPose.tracking == 2 && readPose.position == pose.position)

// The registration is one the phone accepts.
let register = MonitorWire.register(slot:1,identity:identity)
assert(DSU.acceptsRegistration(register,slot:1,identity:identity) && !DSU.acceptsRegistration(register,slot:2,identity:identity))

// Model: duplicates and old packets are ignored, lost packets and gaps are counted, restarts accepted.
var now = 100.0
let model = MonitorModel(clock:{ now })
func feed(_ counter: UInt32) { model.consume(DSU.state(buttons:[],motion:[0,-1,0,1,2,3],timestamp:UInt64(counter)*10_000,counter:counter,slot:0,identity:identity)) }
feed(10); now += 0.01; feed(11); feed(11); feed(9)
assert(model.samples.count == 2 && abs(model.samples[1].gap-10) < 1e-6 && model.samples[1].lost == 0)
now += 0.05; feed(15)
assert(model.samples.count == 3 && model.samples[2].lost == 3 && abs(model.samples[2].gap-50) < 1e-6)
now += 2; feed(1)
assert(model.samples.count == 4 && model.samples[3].lost == 0)
model.consume(attitude.enumerated().map { $0 == 20 ? UInt8(0) : $1 }) // slot byte changed: CRC fails
model.paused = true; now += 0.01; feed(2); assert(model.samples.count == 4)
print("monitor ok")
