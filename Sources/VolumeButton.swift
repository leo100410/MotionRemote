import Foundation

// Separate sources allow both volume buttons and on-screen B to be held together.
enum VolumeButton {
    static func mapping(channel: String, trigger: String) -> (button: String, source: String)? {
        switch channel {
        case "Primary": return ("B", "volume-down")
        case "Secondary": return (trigger, "volume-up")
        default: return nil
        }
    }
}

// Keep a tap visible across Dolphin input polls; long holds release immediately.
struct VolumeTapTiming {
    private var presses: [String:(time:Double, token:UUID)] = [:]
    mutating func begin(source: String, now: Double) {
        presses[source] = (now,UUID())
    }
    func release(source: String, now: Double) -> (delay:Double, token:UUID)? {
        guard let press = presses[source] else { return nil }
        return (max(0,0.05-(now-press.time)),press.token)
    }
    func matches(source: String, token: UUID) -> Bool { presses[source]?.token == token }
    mutating func cancel(source: String) { presses.removeValue(forKey:source) }
    mutating func reset() { presses.removeAll() }
}
