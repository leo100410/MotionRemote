import Foundation

let root = FileManager.default.temporaryDirectory.appendingPathComponent("motionremote-jit-tests-\(UUID())")
defer { try? FileManager.default.removeItem(at: root) }
let file = root.appendingPathComponent("StikJIT/pairingFile.plist")
let good = try PropertyListSerialization.data(fromPropertyList: ["HostID": "test-only"], format: .binary, options: 0)
try storeJITPairing(good, at: file)
let stored = try Data(contentsOf: file)
assert(stored == good)
for bad in [Data(), Data("not a plist".utf8), try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .xml, options: 0), Data(repeating: 1, count: 4 * 1024 * 1024 + 1)] {
  do { try storeJITPairing(bad, at: file); fatalError("Invalid pairing accepted") } catch {}
  let preserved = try Data(contentsOf: file)
  assert(preserved == good, "Invalid import must preserve existing pairing")
}
let id = UUID()
let request = BuiltInJITRequest(id: id, operation: "enable", pid: 42, pairing: good, needsScript: true)
let decoded = try JSONDecoder().decode(BuiltInJITRequest.self, from: JSONEncoder().encode(request))
assert(decoded.id == id && decoded.pid == 42 && decoded.needsScript && decoded.pairing == good)
let response = BuiltInJITResponse(id: id, success: false, message: "Actual DDI error")
let result = try JSONDecoder().decode(BuiltInJITResponse.self, from: JSONEncoder().encode(response))
assert(result.id == id && !result.success && result.message == "Actual DDI error")
print("PASS: pairing validation, atomic replacement, rejected import preserves data, helper IPC round trip")
