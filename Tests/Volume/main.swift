import Foundation

for trigger in ["A", "B"] {
    let up = VolumeButton.mapping(channel:"Secondary",trigger:trigger)!
    let down = VolumeButton.mapping(channel:"Primary",trigger:trigger)!
    assert(up.button == trigger && down.button == "B")
    assert(up.source != down.source)
    var sources = [up.source:up.button,down.source:down.button,"touch-B":"B"]
    sources.removeValue(forKey:up.source)
    assert(Set(sources.values).contains("B"))
    sources.removeValue(forKey:down.source)
    assert(Set(sources.values).contains("B"))
    sources.removeValue(forKey:"touch-B")
    assert(sources.isEmpty)
}
assert(VolumeButton.mapping(channel:"Unknown",trigger:"A") == nil)
print("Volume mapping passed: down=B, configurable up, independent hold/release sources and unknown channel rejection")

var timing = VolumeTapTiming()
timing.begin(source:"volume-up",now:10)
let tap = timing.release(source:"volume-up",now:10.005)!
assert(abs(tap.delay-0.045)<0.000001)
assert(timing.matches(source:"volume-up",token:tap.token))
timing.begin(source:"volume-down",now:10.01)
assert(timing.release(source:"volume-down",now:11)!.delay == 0)
timing.begin(source:"volume-up",now:10.02)
assert(!timing.matches(source:"volume-up",token:tap.token))
let fresh = timing.release(source:"volume-up",now:10.021)!
timing.cancel(source:"volume-up")
assert(!timing.matches(source:"volume-up",token:fresh.token))
assert(timing.release(source:"volume-down",now:11) != nil)
timing.reset()
assert(timing.release(source:"volume-down",now:11) == nil)
print("Tap timing passed: minimum pulse, immediate long-hold release, independent buttons, retrigger, cancellation and stop")
