import Foundation
func wait(_ predicate: () -> Bool) {
    let deadline = Date().addingTimeInterval(8)
    while !predicate() && Date() < deadline { _ = RunLoop.current.run(mode:.default,before:Date().addingTimeInterval(0.01)) }
    assert(predicate(),"Asynchronous storage operation did not finish")
}
func capture(_ library: MotionLibrary) {
    library.begin(sport:"Golf",player:1)
    library.append(MotionFrame(time:100,attitude:SIMD4(0,0,0,1),acceleration:.zero,angularVelocity:.zero,buttons:[]))
    library.append(MotionFrame(time:101,attitude:SIMD4(0,0,0,1),acceleration:.zero,angularVelocity:.zero,buttons:["A"]))
    library.finish()
}
let root = FileManager.default.temporaryDirectory.appendingPathComponent("motion-store-"+UUID().uuidString)
try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:root) }
let library = MotionLibrary(directory:root.appendingPathComponent("takes"))
capture(library)
wait { library.entries.count == 1 && library.pendingSave == nil }
assert(!library.isRecording && library.elapsed == 1)
var loaded = false
Task { @MainActor in
    do {
        let take = try await library.load(library.entries[0])
        assert(take.isValid && take.frames[1].buttons == ["A"])
        loaded = true
    } catch { fatalError("Saved take did not load: \(error)") }
}
wait { loaded }
library.delete(IndexSet(integer:0))
wait { library.entries.isEmpty }
let blocked = root.appendingPathComponent("blocked")
try Data([1]).write(to:blocked)
let failure = MotionLibrary(directory:blocked)
capture(failure)
wait { failure.error?.hasPrefix("Could not save recording:") == true }
let id = failure.pendingSave!.id
assert(failure.pendingSave!.isValid)
try FileManager.default.removeItem(at:blocked)
failure.retrySave()
wait { failure.pendingSave == nil && failure.entries.count == 1 }
let restored = try JSONDecoder().decode(MotionTake.self,from:Data(contentsOf:failure.entries[0].url))
assert(restored.id == id)
try Data("{ broken json".utf8).write(to:failure.entries[0].url)
var rejected = false
Task { @MainActor in
    do { _ = try await failure.load(failure.entries[0]); assertionFailure("Corrupt data must fail") }
    catch { rejected = true }
}
wait { rejected }
print("Recording storage tests passed: atomic save, async playback load, deletion, failed-write preservation and retry, corrupt recording rejection")
