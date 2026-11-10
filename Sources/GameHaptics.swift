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
    func stop() {
        generation &+= 1
        try? player?.stop(atTime:0)
        player = nil
    }
}
