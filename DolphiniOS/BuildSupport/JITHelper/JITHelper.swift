// SPDX-License-Identifier: GPL-2.0-or-later
import Foundation
import StikJIT

@objc(MotionRemoteJITHelper)
final class JITHelper: NSObject, NSExtensionRequestHandling {
  private static let queue = DispatchQueue(label: "motionremote.jit.helper")
  func beginRequest(with context: NSExtensionContext) {
    let payload = (context.inputItems.first as? NSExtensionItem)?.userInfo?[BuiltInJITRequest.key] as? Data
    guard let payload, let request = try? JSONDecoder().decode(BuiltInJITRequest.self, from: payload) else {
      context.cancelRequest(withError: NSError(domain: "BuiltInJIT", code: 2,
        userInfo: [NSLocalizedDescriptionKey: "The JIT helper received an invalid request."]))
      return
    }
    Self.queue.async {
      let response: BuiltInJITResponse
      do {
        let root = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
          .appendingPathComponent("StikJIT", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let paths = DDIPaths.default(in: root)
        if request.operation == "reset" {
          try StikJIT.resetCachedDDI(at: paths)
        } else {
          guard request.operation == "enable", request.pid > 0, request.pid != getpid(),
                let data = request.pairing else {
            throw NSError(domain: "BuiltInJIT", code: 3,
              userInfo: [NSLocalizedDescriptionKey: "Invalid JIT target or missing pairing file."])
          }
          try validateJITPairing(data)
          let temporary = root.appendingPathComponent("pairing-\(request.id).plist")
          try data.write(to: temporary, options: [.atomic, .completeFileProtection])
          defer { try? FileManager.default.removeItem(at: temporary) }
          // DolphiniOS's allocator uses one BRK #0x69, handled by the bundled legacy script.
          try StikJIT.enableJIT(targetPID: request.pid, pairingFile: temporary, ddiPaths: paths,
                               script: .legacy, forceScript: request.needsScript)
        }
        response = .init(id: request.id, success: true,
                         message: request.operation == "reset" ? "Developer Disk Image cache reset." : "JIT enabled.")
      } catch {
        response = .init(id: request.id, success: false, message: error.localizedDescription)
      }
      let item = NSExtensionItem()
      item.userInfo = [BuiltInJITResponse.key: (try? JSONEncoder().encode(response)) ?? Data()]
      context.completeRequest(returningItems: [item], completionHandler: nil)
    }
  }
}
