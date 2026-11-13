import Foundation
import simd

func near(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ tolerance: Float = 0.002) -> Bool { simd_distance(a,b) < tolerance }
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("saber-tests-\(UUID().uuidString)")

// Screen calibration: marks 30 cm apart at y = 0.2 m on a screen facing +z (player at +z).
let calibrated = ScreenCalibration.frame(left:SIMD3(-0.15,0.2,-1),right:SIMD3(0.15,0.21,-1))!
assert(abs(calibrated.width-0.3) < 0.001)
assert(near(SIMD3(calibrated.transform.columns.3.x,calibrated.transform.columns.3.y,calibrated.transform.columns.3.z),SIMD3(0,0.205,-1)))
assert(near(SIMD3(calibrated.transform.columns.2.x,calibrated.transform.columns.2.y,calibrated.transform.columns.2.z),SIMD3(0,0,1))) // z towards player, levelled
assert(ScreenCalibration.frame(left:SIMD3(0,0,0),right:SIMD3(0.05,0,0)) == nil)
assert(ScreenCalibration.frame(left:SIMD3(0,0,0),right:SIMD3(0,0.5,0)) == nil) // vertical marks give no direction
// A phone 40 cm in front of the screen centre, top edge pointing at the screen, display up.
var camera = matrix_identity_float4x4
let pointing = simd_float3x3(simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0)))
camera.columns.0 = SIMD4(pointing.columns.0,0); camera.columns.1 = SIMD4(pointing.columns.1,0); camera.columns.2 = SIMD4(pointing.columns.2,0)
camera.columns.3 = SIMD4(0,0.205,-0.6,1)
let relative = ScreenCalibration.pose(camera:camera,screen:calibrated.transform)
assert(near(relative.position,SIMD3(0,0,0.4)))
assert(near(relative.orientation.act(SIMD3(0,1,0)),SIMD3(0,0,-1))) // blade into the screen
let reversed = ScreenCalibration.frame(left:SIMD3(0.15,0.21,-1),right:SIMD3(-0.15,0.2,-1))!
assert(ScreenCalibration.pose(camera:camera,screen:reversed.transform).position.z < 0) // detected as behind the screen …
assert(near(ScreenCalibration.pose(camera:camera,screen:ScreenCalibration.flipped(reversed.transform)).position,SIMD3(0,0,0.4))) // … and corrected
// The camera-corner offset moves the touch point up and right in device axes.
assert(near(ScreenCalibration.touchPoint(matrix_identity_float4x4),ScreenCalibration.cornerOffset))

// Screen pose packet round trip.
let identity = DSU.Identity(uuid:UUID())
let sent = ScreenPose(timestamp:12.5,sequence:9,tracking:2,reason:.normal,calibrated:true,relocalizing:false,lidar:true,width:0.3,
                      position:SIMD3(0.1,-0.2,0.4),orientation:relative.orientation.vector)
let packet = DSU.screen(sent,slot:0,identity:identity)
assert(packet.count == 68 && MonitorWire.valid(packet))
let received = MonitorWire.screen(packet,slot:0)!
assert(received.sequence == 9 && received.calibrated && received.lidar && !received.relocalizing && received.reason == .normal)
assert(received.position == sent.position && received.width == 0.3 && abs(received.timestamp-12.5) < 1e-6)
assert(MonitorWire.screen(packet,slot:1) == nil && MonitorWire.pose(packet,slot:0) == nil) // Dolphin's pose parser ignores it
var limited = sent; limited.tracking = 1; limited.reason = .insufficientFeatures; limited.calibrated = false
assert(MonitorWire.screen(DSU.screen(limited,slot:0,identity:identity),slot:0)?.reason == .insufficientFeatures)
let rumble = MonitorWire.rumble(0.5,sequence:3,slot:0,identity:identity)
assert(DSU.valid(rumble) && DSU.acceptsRumble(rumble,slot:0,clientUID:UInt64(identity.uid)))

// Event log: repeats are counted, not written; old files are rotated away.
var clock = 0.0
let logDir = scratch.appendingPathComponent("logs")
try! FileManager.default.createDirectory(at:logDir,withIntermediateDirectories:true)
for i in 1...3 { try! Data().write(to:logDir.appendingPathComponent("Test-2000-01-0\(i)_00-00-00.log")) }
let log = EventLog(directory:logDir,prefix:"Test",keep:2,clock:{ clock })
for _ in 0..<5 { log.write("LINK","gap",key:"gap") }
clock = 1.5; log.write("LINK","gap",key:"gap"); log.write("APP","plain")
log.wait()
let text = try! String(contentsOf:log.url,encoding:.utf8)
assert(text.components(separatedBy:"\n").filter { !$0.isEmpty }.count == 3)
assert(text.contains("[LINK] gap (+4 similar since the last line)") && text.contains("[APP] plain"))
assert(try! FileManager.default.contentsOfDirectory(atPath:logDir.path).count <= 2)

// Game: cuts are judged on screen. Aim the blade above a block, then below it: a fast downward sweep.
let note = Note(id:0,time:1,column:1,row:1,direction:.down)
var game = SaberGame(notes:[note])
let center = SaberGame.position(note,at:1)
assert(abs(center.z) < 0.001)
func aimed(at point: SIMD3<Float>, hilt: SIMD3<Float> = SwordMapper.base) -> Sword {
    Sword(hilt:hilt,tip:hilt+simd_normalize(point-hilt)*SaberGame.bladeLength)
}
let above = aimed(at:center+SIMD3(0,0.45,0)), below = aimed(at:center-SIMD3(0,0.45,0))
var events = game.update(time:1,previous:above,current:below,dt:1.0/60)
if case let .cut(_,good,_,_,_)? = events.first { assert(good) } else { assert(false,"expected a cut") }
assert(game.score == 100 && game.combo == 1)
// A sweep across the block's screen position counts even though the blade never reaches the block's depth.
game = SaberGame(notes:[note])
let short = { (s: Sword) in Sword(hilt:s.hilt,tip:s.hilt+(s.tip-s.hilt)*0.5) }
assert(GameView.project(short(above).tip).z < GameView.project(center).z-0.3)
if case let .cut(_,good,_,_,_)? = game.update(time:1,previous:short(above),current:short(below),dt:1.0/60).first { assert(good) } else { assert(false,"short blade should cut on screen") }
// The same swing upwards is a wrong-direction cut and breaks the combo.
game = SaberGame(notes:[note])
events = game.update(time:1,previous:below,current:above,dt:1.0/60)
if case let .cut(_,good,_,_,angle)? = events.first { assert(!good && angle > 170) } else { assert(false,"expected a bad cut") }
assert(game.bad == 1 && game.combo == 0)
// Winding up through a block that is still far away is ignored; the later correct cut still counts.
game = SaberGame(notes:[note])
assert(game.update(time:0.9,previous:below,current:above,dt:1.0/60).isEmpty)
assert(game.notes[0].ignoredWrong == 1)
if case let .cut(_,good,_,_,_)? = game.update(time:1,previous:above,current:below,dt:1.0/60).first { assert(good) } else { assert(false,"expected the real cut") }
// Stabbing straight at the block barely moves the tip on screen: no cut.
game = SaberGame(notes:[note])
let stab = aimed(at:center), deeper = Sword(hilt:stab.hilt-SIMD3(0,0,0.15),tip:stab.tip-SIMD3(0,0,0.15))
assert(game.update(time:1,previous:stab,current:deeper,dt:1.0/60).isEmpty)
// A sweep beside the block does not cut it; the block then passes and is missed.
game = SaberGame(notes:[note])
let side = SIMD3<Float>(0.9,0,0)
assert(game.update(time:1,previous:aimed(at:center+side+SIMD3(0,0.45,0)),current:aimed(at:center+side-SIMD3(0,0.45,0)),dt:1.0/60).isEmpty)
events = game.update(time:1.2,previous:above,current:above,dt:1.0/60)
if case let .miss(missed)? = events.first { assert(game.missed == 1 && missed.closest >= 1) } else { assert(false,"expected a miss") }
// Multiplier: 2 good cuts → ×2, 4 more → ×4; a miss halves it.
var many = SaberGame(notes:(0..<7).map { Note(id:$0,time:Double($0+1),column:1,row:1,direction:nil) })
for i in 0..<6 { _ = many.update(time:Double(i+1),previous:above,current:below,dt:1.0/60) }
assert(many.multiplier == 4 && many.combo == 6)
_ = many.update(time:9,previous:above,current:above,dt:1.0/60)
assert(many.multiplier == 2 && many.combo == 0 && many.missed == 1)
// The chart is deterministic and every block lies in the 4 × 3 grid.
let chart = Chart.make()
assert(chart.count == Chart.make().count && chart.count > 40 && chart.allSatisfy { (0...3).contains($0.column) && (0...2).contains($0.row) })
assert(zip(chart,chart.dropFirst()).allSatisfy { $0.time < $1.time })

// Sword mapping: pointing at the screen puts the tip into the corridor; hand movement is enlarged around its average.
var mapper = SwordMapper()
let still = mapper.sword(position:SIMD3(0,0,0.4),orientation:simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0)),dt:1.0/60)
assert(near(still.hilt,SwordMapper.base) && still.tip.z < still.hilt.z-1)
let moved = mapper.sword(position:SIMD3(0.1,0,0.4),orientation:simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0)),dt:1.0/60)
assert(moved.hilt.x > 0.2)

// Link: camera pose wins while fresh; when it stops, motion takes over aligned with it; both switches are logged.
var now = 100.0
let linkLog = EventLog(directory:scratch.appendingPathComponent("link"),prefix:"Link",clock:{ now })
let link = SaberLink(log:linkLog,clock:{ now })
link.displayWidth = 0.30
let phone = DSU.Identity(uuid:UUID())
var counter: UInt32 = 0
func feed(attitude q: simd_quatf, screen: ScreenPose?) {
    counter += 1
    link.consume(DSU.state(buttons:[],motion:[0,-1,0,0,0,0],timestamp:UInt64(counter)*10_000,counter:counter,slot:0,identity:phone))
    link.consume(DSU.attitude(q.vector,timestamp:UInt64(counter)*10_000,slot:0,identity:phone))
    if let screen { link.consume(DSU.screen(screen,slot:0,identity:phone)) }
}
var tracked = sent; tracked.width = 0.36 // 6 cm wider than this display: must be reported
let attitude = simd_quatf(angle:0.3,axis:SIMD3(0,0,1))
feed(attitude:attitude,screen:tracked)
var input = link.input(now:now)
assert(input.source == .camera && input.position == tracked.position)
now += 0.45; counter += 20 // 20 packets lost, camera stopped
feed(attitude:attitude,screen:nil)
input = link.input(now:now)
assert(input.source == .motion && input.position == nil)
assert(simd_distance(input.orientation.act(SIMD3(0,1,0)),relative.orientation.act(SIMD3(0,1,0))) < 0.001) // no jump
var lost = tracked; lost.tracking = 1; lost.reason = .insufficientFeatures
now += 0.01; feed(attitude:attitude,screen:lost)
assert(link.input(now:now).source == .motion)
now += 0.5; _ = link.input(now:now) // 500 ms silence
now += 0.01; feed(attitude:attitude,screen:lost)
now += 10; _ = link.input(now:now)
linkLog.wait()
let linkText = try! String(contentsOf:linkLog.url,encoding:.utf8)
for expected in ["Receiving controller data","differs from this display","Sword source: No tracking → Camera tracking",
                 "Packet gap 450 ms, 20 lost (#1 → #22): phone sent them 210 ms apart, so Wi-Fi held them back","Sword source: Camera tracking → Motion only",
                 "Camera sees too little detail","No controller data for 400 ms","Controller data resumed after","[SUMMARY]"] {
    assert(linkText.contains(expected),"log is missing: \(expected)\n\(linkText)")
}
// A Wi-Fi burst: sent 10 ms apart, arrived 150 ms apart, at a steady one-second rhythm.
func burst(_ at: Double, _ number: UInt32) {
    now = at
    link.consume(DSU.state(buttons:[],motion:[0,-1,0,0,0,0],timestamp:UInt64(number)*10_000,counter:number,slot:0,identity:phone))
}
for second in 0..<5 {
    let base = 200+Double(second), first = UInt32(1000+second*100)
    burst(base,first); burst(base+0.15,first+1)
}
now = 215; _ = link.input(now:now)
// Recentering while camera-tracked turns only the heading.
var skewed = sent; skewed.orientation = (simd_quatf(angle:0.2,axis:SIMD3(0,1,0))*simd_quatf(angle:-.pi/2,axis:SIMD3(1,0,0))).vector
now += 0.01; feed(attitude:attitude,screen:skewed); _ = link.input(now:now); link.recenter()
now += 0.01; feed(attitude:attitude,screen:skewed)
let straight = link.input(now:now)
assert(straight.source == .camera && simd_distance(straight.orientation.act(SIMD3(0,1,0)),SIMD3(0,0,-1)) < 0.001)
linkLog.wait()
let rhythmText = try! String(contentsOf:linkLog.url,encoding:.utf8)
for expected in ["phone sent them 10 ms apart, so Wi-Fi held them back","held by Wi-Fi","regular, every 1.00 s","Camera heading recentered by -11.5°"] {
    assert(rhythmText.contains(expected),"log is missing: \(expected)\n\(rhythmText)")
}
// Haptic request: one packet the phone accepts, effect in byte 22.
let hapticPacket = MonitorWire.rumble(1,sequence:4,slot:0,identity:identity,haptic:.bad)
assert(DSU.acceptsRumble(hapticPacket,slot:0,clientUID:UInt64(identity.uid)) && hapticPacket[22] == 2 && rumble[22] == 0)
try? FileManager.default.removeItem(at:scratch)
print("saber ok")
