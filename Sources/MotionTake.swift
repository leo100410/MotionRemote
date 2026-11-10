import Foundation
import simd

struct MotionFrame: Codable {
    var time: Double
    var attitude: SIMD4<Double>
    var acceleration: SIMD3<Double> // Device axes, user acceleration in g (gravity excluded).
    var angularVelocity: SIMD3<Double> // Device axes, radians per second.
    var buttons: [String]
    var isValid: Bool {
        time.isFinite && time >= 0 && (0..<4).allSatisfy { attitude[$0].isFinite }
        && (0..<3).allSatisfy { acceleration[$0].isFinite && angularVelocity[$0].isFinite }
        && simd_length_squared(attitude).isFinite && simd_length_squared(attitude) > 0.000001
        && (0..<3).allSatisfy { Float(acceleration[$0]).isFinite && Float(angularVelocity[$0]).isFinite }
    }
}

struct MotionTake: Codable, Identifiable {
    let version: Int
    let id: UUID
    let date: Date
    let sport: String
    let player: Int
    var frames: [MotionFrame]
    var duration: Double { frames.last?.time ?? 0 }
    var isValid: Bool {
        version == 1 && frames.count >= 2 && frames.count <= 12_001
        && frames.first?.time == 0 && duration <= 120.01
        && frames.allSatisfy(\.isValid)
        && zip(frames,frames.dropFirst()).allSatisfy { $0.time < $1.time }
    }
    func frame(at time: Double) -> MotionFrame {
        guard frames.count > 1 else { return frames[0] }
        let t = min(duration,max(0,time))
        var low = 0, high = frames.count-1
        while low+1 < high {
            let mid = (low+high)/2
            if frames[mid].time <= t { low = mid } else { high = mid }
        }
        let a = frames[low], b = frames[high]
        let f = (t-a.time)/(b.time-a.time)
        let rotation = simd_slerp(simd_normalize(simd_quatd(vector:a.attitude)),simd_normalize(simd_quatd(vector:b.attitude)),f)
        return MotionFrame(time:t,attitude:rotation.vector,
                           acceleration:a.acceleration+(b.acceleration-a.acceleration)*f,
                           angularVelocity:a.angularVelocity+(b.angularVelocity-a.angularVelocity)*f,
                           buttons:t >= b.time ? b.buttons : a.buttons)
    }
    func rotation(at time: Double) -> simd_quatf {
        let first = simd_normalize(simd_quatd(vector:frames[0].attitude))
        let current = simd_normalize(simd_quatd(vector:frame(at:time).attitude))
        let relative = simd_mul(first.inverse,current)
        return simd_quatf(vector:SIMD4<Float>(relative.vector))
    }
}

struct TakeBuffer {
    private(set) var take: MotionTake
    private var origin: Double?
    init(sport: String, player: Int) {
        take = MotionTake(version:1,id:UUID(),date:Date(),sport:sport,player:player,frames:[])
    }
    mutating func append(_ sample: MotionFrame) -> Bool {
        guard sample.isValid else { return false }
        let start = origin ?? sample.time
        let elapsed = sample.time-start
        guard elapsed >= 0, take.frames.last.map({ elapsed > $0.time }) ?? true else { return false }
        if elapsed > 120 || take.frames.count >= 12_001 { return true }
        origin = start
        var frame = sample; frame.time = elapsed
        take.frames.append(frame)
        return elapsed >= 120
    }
}
