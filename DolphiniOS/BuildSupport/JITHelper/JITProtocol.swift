// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation

struct BuiltInJITRequest: Codable {
  static let key = "motionremote-jit-request"
  let id: UUID
  let operation: String
  let pid: Int32
  let pairing: Data?
  let needsScript: Bool
}
struct BuiltInJITResponse: Codable {
  static let key = "motionremote-jit-response"
  let id: UUID
  let success: Bool
  let message: String
}

func validateJITPairing(_ data: Data) throws {
  guard !data.isEmpty, data.count <= 4 * 1024 * 1024,
        let dictionary = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
        !dictionary.isEmpty else {
    throw NSError(domain: "BuiltInJIT", code: 1,
                  userInfo: [NSLocalizedDescriptionKey: "Choose a non-empty pairing plist for this iPad. The file was not replaced."])
  }
}

func storeJITPairing(_ data: Data, at url: URL) throws {
  try validateJITPairing(data)
  try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
  try data.write(to: url, options: [.atomic, .completeFileProtection])
}
