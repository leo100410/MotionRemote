import Foundation
import Combine

struct RecordingEntry: Identifiable {
    let url: URL
    let date: Date
    var id: URL { url }
}

final class MotionLibrary: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed = 0.0
    @Published private(set) var entries: [RecordingEntry] = []
    @Published var error: String?
    @Published private(set) var pendingSave: MotionTake?
    var onStopped: (() -> Void)?
    private var buffer: TakeBuffer?
    private let io = DispatchQueue(label:"MotionRemote.recordings",qos:.utility)
    private let directory: URL
    init(directory: URL = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Recordings",isDirectory:true)) {
        self.directory = directory
        refresh()
    }
    func begin(sport: String, player: Int) {
        guard !isRecording else { return }
        guard pendingSave == nil else { error = "Retry saving your previous take before starting another recording."; return }
        error = nil; elapsed = 0
        buffer = TakeBuffer(sport:sport,player:player); isRecording = true
    }
    func append(_ frame: MotionFrame) {
        guard isRecording, buffer != nil else { return }
        let full = buffer!.append(frame)
        if buffer!.take.frames.count % 10 == 0 { elapsed = buffer!.take.duration }
        if full { finish() }
    }
    func finish() {
        guard let take = buffer?.take else { return }
        buffer = nil; isRecording = false; elapsed = take.duration
        onStopped?()
        guard take.isValid else { error = "Recording was too short or contained no motion samples. Try recording for at least one second."; return }
        save(take)
    }
    private func save(_ take: MotionTake) {
        pendingSave = take
        io.async {
            do {
                try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
                let data = try JSONEncoder().encode(take)
                try data.write(to:self.directory.appendingPathComponent(take.id.uuidString+".json"),options:.atomic)
                DispatchQueue.main.async {
                    if self.pendingSave?.id == take.id { self.pendingSave = nil; self.error = nil }
                    self.refresh()
                }
            } catch {
                DispatchQueue.main.async {
                    if self.pendingSave?.id == take.id {
                        self.error = "Could not save recording: \(error.localizedDescription). Your take is kept in memory; use Retry save."
                    }
                }
            }
        }
    }
    func retrySave() { if let pendingSave { save(pendingSave) } }
    func refresh() {
        io.async {
            do {
                try FileManager.default.createDirectory(at:self.directory,withIntermediateDirectories:true)
                let files = try FileManager.default.contentsOfDirectory(at:self.directory,includingPropertiesForKeys:[.creationDateKey])
                let entries = try files.filter { $0.pathExtension == "json" }.map {
                    RecordingEntry(url:$0,date:try $0.resourceValues(forKeys:[.creationDateKey]).creationDate ?? .distantPast)
                }.sorted { $0.date > $1.date }
                DispatchQueue.main.async { self.entries = entries }
            } catch { DispatchQueue.main.async { self.error = error.localizedDescription } }
        }
    }
    func load(_ entry: RecordingEntry) async throws -> MotionTake {
        try await withCheckedThrowingContinuation { continuation in
            io.async {
                do {
                    let size = try entry.url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
                    guard size <= 30_000_000 else { throw CocoaError(.fileReadTooLarge) }
                    let take = try JSONDecoder().decode(MotionTake.self,from:Data(contentsOf:entry.url))
                    guard take.isValid else { throw CocoaError(.fileReadCorruptFile) }
                    continuation.resume(returning:take)
                } catch { continuation.resume(throwing:error) }
            }
        }
    }
    func delete(_ offsets: IndexSet) {
        let files = offsets.map { entries[$0].url }
        io.async {
            do { for file in files { try FileManager.default.removeItem(at:file) }; self.refresh() }
            catch { DispatchQueue.main.async { self.error = error.localizedDescription } }
        }
    }
}
