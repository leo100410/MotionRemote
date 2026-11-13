import Foundation

@MainActor final class InternetTest: ObservableObject {
    @Published var status = "Optional Internet test · up to 10 MB · Wi-Fi only"
    @Published var result = "Controller recommendations use the local link test in Dolphin, not Internet speed."
    @Published var running = false
    private var task: Task<Void,Never>?
    func cancel() { task?.cancel(); task = nil; status = "Test cancelled" }
    func start() {
        guard !running else { return }
        running = true
        task = Task {
            let config = URLSessionConfiguration.ephemeral
            config.allowsCellularAccess = false
            config.timeoutIntervalForRequest = 10
            config.timeoutIntervalForResource = 15
            let session = URLSession(configuration:config)
            defer { session.invalidateAndCancel(); running = false }
            do {
                var times = [Double]()
                for i in 0..<7 {
                    try Task.checkCancellation(); status = "Internet round trip \(i+1)/7…"
                    let before = ProcessInfo.processInfo.systemUptime
                    let (data,response) = try await session.data(for:request(path:"__down?bytes=0"))
                    try check(response)
                    _ = data
                    if i > 0 { times.append((ProcessInfo.processInfo.systemUptime-before)*1000) }
                }
                status = "Measuring download (8 MB)…"
                let before = ProcessInfo.processInfo.systemUptime
                let (download,response) = try await session.data(for:request(path:"__down?bytes=8000000"))
                try check(response)
                guard download.count == 8_000_000 else { throw URLError(.badServerResponse) }
                let down = Double(download.count)*8/max(0.001,ProcessInfo.processInfo.systemUptime-before)/1_000_000
                try Task.checkCancellation(); status = "Measuring upload (2 MB)…"
                var upload = request(path:"__up")
                upload.httpMethod = "POST"; upload.setValue("application/octet-stream",forHTTPHeaderField:"Content-Type")
                upload.httpBody = Data(repeating:0,count:2_000_000)
                let uploadStart = ProcessInfo.processInfo.systemUptime
                let (_,uploadResponse) = try await session.data(for:upload)
                try check(uploadResponse)
                let up = 16/max(0.001,ProcessInfo.processInfo.systemUptime-uploadStart)
                let sorted = times.sorted(), ping = sorted[sorted.count/2]
                let jitter = zip(times,times.dropFirst()).map { abs($0-$1) }.reduce(0,+)/Double(times.count-1)
                result = String(format:"HTTP round trip %.0f ms · jitter %.0f ms\nApprox. download %.1f Mbps · upload %.1f Mbps\n\nThis measures the Internet path to Cloudflare. Use Dolphin → MotionRemote Connections → Test controller link on both transports for a Wi-Fi/Bluetooth recommendation.",ping,jitter,down,up)
                status = "Internet test complete"
            } catch {
                status = Task.isCancelled ? "Test cancelled" : "Internet test failed: \(error.localizedDescription)"
                result = "Internet failure does not prove the local controller link is bad. Bluetooth and local Wi-Fi control work without Internet."
            }
        }
    }
    private func request(path: String) -> URLRequest {
        var request = URLRequest(url:URL(string:"https://speed.cloudflare.com/\(path)\(path.contains("?") ? "&" : "?")nonce=\(UUID())")!)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }
    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw URLError(.badServerResponse) }
    }
}
