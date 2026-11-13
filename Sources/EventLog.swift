import Foundation

// Plain-text diagnostics, one line per event. Repeats of the same key are counted, not written,
// so a failing loop cannot flood the file while the count still shows how often it happened.
final class EventLog {
    let url: URL
    private let queue = DispatchQueue(label:"EventLog")
    private let handle: FileHandle?
    private let clock: () -> Double
    private let time = DateFormatter()
    private var recent: [String:(time:Double,suppressed:Int)] = [:]
    init(directory: URL, prefix: String, keep: Int = 20, clock: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        let files = FileManager.default
        try? files.createDirectory(at:directory,withIntermediateDirectories:true)
        let old = ((try? files.contentsOfDirectory(at:directory,includingPropertiesForKeys:nil)) ?? [])
            .filter { $0.lastPathComponent.hasPrefix(prefix+"-") && $0.pathExtension == "log" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for file in old.dropFirst(max(0,keep-1)) { try? files.removeItem(at:file) }
        let stamp = DateFormatter(); stamp.locale = Locale(identifier:"en_US_POSIX"); stamp.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        var name = "\(prefix)-\(stamp.string(from:Date()))"
        if files.fileExists(atPath:directory.appendingPathComponent(name+".log").path) { name += "-\(UInt16.random(in:0...UInt16.max))" }
        url = directory.appendingPathComponent(name+".log")
        files.createFile(atPath:url.path,contents:nil)
        handle = try? FileHandle(forWritingTo:url)
        time.locale = Locale(identifier:"en_US_POSIX"); time.dateFormat = "HH:mm:ss.SSS"
        self.clock = clock
    }
    func write(_ category: String, _ message: String, key: String? = nil, every interval: Double = 1) {
        let now = clock(), date = Date()
        queue.async {
            var text = message
            if let key {
                if let entry = self.recent[key], now-entry.time < interval { self.recent[key] = (entry.time,entry.suppressed+1); return }
                if let suppressed = self.recent[key]?.suppressed, suppressed > 0 { text += " (+\(suppressed) similar since the last line)" }
                self.recent[key] = (now,0)
            }
            self.handle?.write(Data("\(self.time.string(from:date)) [\(category)] \(text)\n".utf8))
        }
    }
    func wait() { queue.sync {} }
}
