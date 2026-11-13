import CoreHaptics
import Foundation

final class GameHaptics {
    private var engine: CHHapticEngine?
    private var player: CHHapticAdvancedPatternPlayer?
    private var generation: UInt64 = 0
    let supported = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    func set(_ strength: Float) {
        generation &+= 1
        let current = generation
        guard supported, strength.isFinite, strength > 0 else { stop(); return }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.playsHapticsOnly = true
                e.isAutoShutdownEnabled = true
                e.resetHandler = { [weak self] in DispatchQueue.main.async { self?.player = nil } }
                e.stoppedHandler = { [weak self] _ in DispatchQueue.main.async { self?.player = nil } }
                engine = e
            }
            guard let engine else { return }
            try engine.start()
            if player == nil {
                let event = CHHapticEvent(eventType:.hapticContinuous,parameters:[
                    CHHapticEventParameter(parameterID:.hapticIntensity,value:1),
                    CHHapticEventParameter(parameterID:.hapticSharpness,value:0.3)
                ],relativeTime:0,duration:1)
                let p = try engine.makeAdvancedPlayer(with:CHHapticPattern(events:[event],parameters:[]))
                p.loopEnabled = true
                player = p
                try p.sendParameters([CHHapticDynamicParameter(parameterID:.hapticIntensityControl,value:min(strength,1),relativeTime:0)],atTime:0)
                try p.start(atTime:0)
            } else {
                try player?.sendParameters([CHHapticDynamicParameter(parameterID:.hapticIntensityControl,value:min(strength,1),relativeTime:0)],atTime:0)
            }
            // A missing release or disconnected Mac must never leave the motor running.
            DispatchQueue.main.asyncAfter(deadline:.now()+0.35) { [weak self] in
                guard let self, self.generation == current else { return }
                self.stop()
            }
        } catch { stop() }
    }
    // One-shot effects for MotionSaber: 1 clean cut, 2 wrong-direction cut, 3 missed block.
    func play(_ effect: UInt8) {
        guard supported, (1...3).contains(effect) else { return }
        func event(_ type: CHHapticEvent.EventType, _ intensity: Float, _ sharpness: Float, at time: Double, for duration: Double = 0) -> CHHapticEvent {
            CHHapticEvent(eventType:type,parameters:[CHHapticEventParameter(parameterID:.hapticIntensity,value:intensity),
                                                     CHHapticEventParameter(parameterID:.hapticSharpness,value:sharpness)],relativeTime:time,duration:duration)
        }
        let events: [CHHapticEvent]
        switch effect {
        case 1: events = [event(.hapticTransient,1,0.9,at:0),event(.hapticContinuous,0.6,0.4,at:0,for:0.06)]
        case 2: events = [event(.hapticContinuous,1,0.1,at:0,for:0.16)]
        default: events = [event(.hapticTransient,0.4,0.2,at:0)]
        }
        do {
            if engine == nil {
                let e = try CHHapticEngine()
                e.playsHapticsOnly = true
                e.isAutoShutdownEnabled = true
                e.resetHandler = { [weak self] in DispatchQueue.main.async { self?.player = nil } }
                e.stoppedHandler = { [weak self] _ in DispatchQueue.main.async { self?.player = nil } }
                engine = e
            }
            try engine?.start()
            try engine?.makePlayer(with:CHHapticPattern(events:events,parameters:[])).start(atTime:CHHapticTimeImmediate)
        } catch { appLog.write("HAPTICS","Haptic effect failed: \(error.localizedDescription)",key:"haptic",every:5) }
    }
    func stop() {
        generation &+= 1
        try? player?.stop(atTime:0)
        player = nil
    }
}
