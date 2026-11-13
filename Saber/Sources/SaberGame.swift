import Foundation
import simd

// Game space: metres, x right, y up, z towards the player. Blocks fly along -z to +z and are cut at z = 0.
enum CutDirection: Int, CaseIterable {
    case up, down, left, right
    var vector: SIMD2<Float> { [SIMD2(0,1),SIMD2(0,-1),SIMD2(-1,0),SIMD2(1,0)][rawValue] }
}

struct Note {
    let id: Int
    let time: Double // seconds after the song start when the block reaches the cut plane
    let column: Int  // 0...3
    let row: Int     // 0...2
    let direction: CutDirection? // nil: cut in any direction
    var result: Result?
    var closest = Float.infinity // nearest sweep, in block radii (diagnostics)
    var fastest: Float = 0       // fastest tip speed while in reach
    var ignoredWrong = 0         // wrong-direction sweeps while still far away
    enum Result { case good, bad, miss }
}

struct Sword {
    var hilt: SIMD3<Float>
    var tip: SIMD3<Float>
}

enum Chart {
    static let bpm = 96.0
    static let leadInBeats = 4
    static func make(seed: UInt64 = 7, beats: Int = 64) -> [Note] {
        var random = SplitMix(seed)
        var notes: [Note] = []
        var last = CutDirection.up
        func add(_ beat: Double) {
            // One sword: mostly alternate down/up like a real swing, sometimes sideways or free.
            let direction: CutDirection?
            if random.chance(0.12) { direction = nil }
            else if random.chance(0.2) { direction = random.chance(0.5) ? .left : .right }
            else { direction = last == .down ? .up : .down }
            if let direction { last = direction }
            let column: Int, row: Int
            switch direction {
            case .left?: column = random.chance(0.5) ? 2 : 3; row = 1
            case .right?: column = random.chance(0.5) ? 0 : 1; row = 1
            case .down?: column = random.pick([1,2,1,2,0,3]); row = random.chance(0.6) ? 2 : 1
            case .up?: column = random.pick([1,2,1,2,0,3]); row = random.chance(0.6) ? 0 : 1
            case nil: column = random.pick([1,2]); row = 1
            }
            notes.append(Note(id:notes.count,time:(Double(leadInBeats)+beat)*60/bpm,column:column,row:row,direction:direction))
        }
        for beat in 0..<beats where beat >= 16 || beat % 2 == 0 {
            add(Double(beat))
            if beat >= 48 && beat < beats-1 && random.chance(0.35) { add(Double(beat)+0.5) }
        }
        return notes
    }
}

struct SplitMix {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z^(z>>30)) &* 0xBF58476D1CE4E5B9; z = (z^(z>>27)) &* 0x94D049BB133111EB
        return z^(z>>31)
    }
    mutating func chance(_ p: Double) -> Bool { Double(next()%10_000)/10_000 < p }
    mutating func pick(_ values: [Int]) -> Int { values[Int(next()%UInt64(values.count))] }
}

// The game camera. Cuts are judged on screen: a block counts as hit when the sword visibly sweeps across it.
enum GameView {
    static let eye = SIMD3<Float>(0,1.5,2.75)
    static let target = SIMD3<Float>(0,1.05,-6)
    static let fieldOfView: Float = 55
    private static let forward = simd_normalize(target-eye)
    private static let right = simd_normalize(simd_cross(forward,SIMD3(0,1,0)))
    private static let up = simd_cross(right,forward)
    private static let scale = 1/tan(fieldOfView/2 * .pi/180)
    // x, y in half screen heights from the centre; z is the depth in metres.
    static func project(_ p: SIMD3<Float>) -> SIMD3<Float> {
        let d = p-eye, depth = simd_dot(d,forward)
        return SIMD3(simd_dot(d,right)*scale/depth,simd_dot(d,up)*scale/depth,depth)
    }
}

struct SaberGame {
    static let speed: Float = 8           // block speed, m/s
    static let spawnTime: Double = 2.4    // seconds a block is visible before the cut plane
    static let blockHalf: Float = 0.16
    static let bladeLength: Float = 1.05
    static let minSpeed: Float = 1.0      // tip speed on screen, half screen heights per second
    static let directionTolerance: Float = 0.5 // cos 60°
    static let window: ClosedRange<Float> = -1.0...0.6 // block z where cuts count
    // Winding up for a cut often crosses the block early; a wrong direction only counts once it is this close.
    static let wrongFrom: Float = -0.3
    enum Event {
        case cut(Note,good: Bool,normal: SIMD3<Float>,speed: Float,angle: Float)
        case miss(Note)
    }
    private(set) var notes: [Note]
    private(set) var score = 0, combo = 0, maxCombo = 0, multiplier = 1, good = 0, bad = 0, missed = 0
    private var progress = 0
    init(notes: [Note] = Chart.make()) { self.notes = notes }
    var finishTime: Double { (notes.last?.time ?? 0)+1.5 }
    var resolved: Int { good+bad+missed }
    var accuracy: Double { resolved == 0 ? 1 : Double(good)/Double(resolved) }
    static func position(_ note: Note, at time: Double) -> SIMD3<Float> {
        SIMD3(Float(note.column)*0.42-0.63,0.78+Float(note.row)*0.36,-Float(note.time-time)*speed)
    }
    static func visible(_ note: Note, at time: Double) -> Bool { note.result == nil && time > note.time-spawnTime }
    mutating func update(time: Double, previous: Sword, current: Sword, dt: Double) -> [Event] {
        var events: [Event] = []
        let a = GameView.project(previous.tip), b = GameView.project(current.tip)
        let across = SIMD2(b.x-a.x,b.y-a.y)/Float(max(dt,0.001)), speed = simd_length(across)
        for i in notes.indices where notes[i].result == nil {
            let center = Self.position(notes[i],at:time)
            if center.z > Self.window.upperBound+0.2 {
                notes[i].result = .miss; missed += 1; breakCombo(); events.append(.miss(notes[i])); continue
            }
            guard Self.window.contains(center.z) else { continue }
            let reach = Self.closest(previous,current,to:center)
            notes[i].closest = min(notes[i].closest,reach)
            if reach < 1 { notes[i].fastest = max(notes[i].fastest,speed) }
            guard reach < 1, speed >= Self.minSpeed else { continue }
            let direction = across/speed
            let angle = notes[i].direction.map { acos(max(-1,min(1,simd_dot(direction,$0.vector))))*180 / .pi } ?? 0
            let good = angle <= acos(Self.directionTolerance)*180 / .pi
            if !good && center.z < Self.wrongFrom { notes[i].ignoredWrong += 1; continue }
            notes[i].result = good ? .good : .bad
            if good {
                self.good += 1; combo += 1; maxCombo = max(maxCombo,combo); score += 100*multiplier
                progress += 1
                // Beat Saber style: 2 hits to ×2, 4 more to ×4, 8 more to ×8.
                if multiplier < 8 && progress >= multiplier*2 { multiplier *= 2; progress = 0 }
            } else { bad += 1; breakCombo() }
            events.append(.cut(notes[i],good:good,normal:simd_normalize(SIMD3(-direction.y,direction.x,0)),speed:speed,angle:angle))
        }
        return events
    }
    private mutating func breakCombo() { combo = 0; progress = 0; multiplier = max(1,multiplier/2) }
    static func swept(_ a: Sword, _ b: Sword, hits center: SIMD3<Float>) -> Bool { closest(a,b,to:center) < 1 }
    // Nearest distance between the sweeping blade and the block on screen, in (enlarged) block radii.
    // Fast swings move the blade far between frames, so the path in between is checked as well.
    static func closest(_ a: Sword, _ b: Sword, to center: SIMD3<Float>) -> Float {
        let block = GameView.project(center)
        // A little larger than the drawn block so near misses still count.
        let radius = blockHalf*1.5/max(block.z,0.1)/tan(GameView.fieldOfView/2 * .pi/180)
        var nearest = Float.infinity
        for step in 0...6 {
            let f = Float(step)/6
            let hilt = GameView.project(a.hilt+(b.hilt-a.hilt)*f), tip = GameView.project(a.tip+(b.tip-a.tip)*f)
            guard hilt.z > 0.1, tip.z > 0.1 else { continue }
            nearest = min(nearest,distance(SIMD2(block.x,block.y),SIMD2(hilt.x,hilt.y),SIMD2(tip.x,tip.y))/radius)
        }
        return nearest
    }
    static func distance(_ p: SIMD2<Float>, _ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let ab = b-a, t = max(0,min(1,simd_dot(p-a,ab)/max(simd_length_squared(ab),0.000001)))
        return simd_distance(p,a+ab*t)
    }
}

// Maps the phone into game space. Orientation is used 1:1 in the screen frame; the hilt follows hand
// movement around its recent average, enlarged so desk-sized movements reach all four columns.
struct SwordMapper {
    static let base = SIMD3<Float>(0,0.95,0.95)
    static let scale: Float = 2.2
    private var rest: SIMD3<Float>?
    mutating func sword(position: SIMD3<Float>?, orientation: simd_quatf, dt: Double) -> Sword {
        var hilt = Self.base
        if let position {
            let blend = Float(1-exp(-dt/4))
            let center = rest.map { $0+(position-$0)*blend } ?? position
            rest = center
            hilt = simd_clamp(Self.base+(position-center)*Self.scale,SIMD3(-0.9,0.35,0.5),SIMD3(0.9,1.8,1.4))
        } else { rest = nil }
        return Sword(hilt:hilt,tip:hilt+orientation.act(SIMD3(0,1,0))*SaberGame.bladeLength)
    }
}
