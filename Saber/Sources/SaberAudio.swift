import AVFoundation

// A small synthesised track (kick, hi-hat, bass) in time with the chart, plus cut and miss sounds.
final class SaberAudio {
    enum Sound { case good, bad, miss }
    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private let lock = NSLock()
    private var pending: [Sound] = []
    private var voices: [(sound: Sound, age: Int)] = []
    private var sample = 0
    private var playing = false
    private var noise = SplitMix(99)
    private let log: EventLog
    init(log: EventLog) { self.log = log }
    func start(at seconds: Double = 0) {
        let rate = engine.outputNode.outputFormat(forBus:0).sampleRate
        guard rate > 0, let format = AVAudioFormat(standardFormatWithSampleRate:rate,channels:1) else {
            log.write("AUDIO","No audio output available; playing without sound"); return
        }
        lock.lock(); sample = Int(seconds*rate); playing = true; voices = []; pending = []; lock.unlock()
        if node == nil {
            let source = AVAudioSourceNode(format:format) { [unowned self] _,_,frames,buffers in
                render(Int(frames),UnsafeMutableAudioBufferListPointer(buffers),rate:rate); return noErr
            }
            engine.attach(source); engine.connect(source,to:engine.mainMixerNode,format:format); node = source
        }
        do { try engine.start() } catch { log.write("AUDIO","Audio could not start: \(error.localizedDescription); playing without sound") }
    }
    func pause() { lock.lock(); playing = false; lock.unlock() }
    func resume() { lock.lock(); playing = true; lock.unlock() }
    func stop() { pause(); engine.pause() }
    func play(_ sound: Sound) { lock.lock(); pending.append(sound); lock.unlock() }
    private func render(_ frames: Int, _ buffers: UnsafeMutableAudioBufferListPointer, rate: Double) {
        // Never block the audio thread; a missed lock only delays a sound by one buffer.
        guard lock.try() else { for buffer in buffers { memset(buffer.mData,0,Int(buffer.mDataByteSize)) }; return }
        voices += pending.map { ($0,0) }; pending = []
        let beatLength = 60/Chart.bpm
        let bass: [Double] = [55,55,43.65,49]
        for i in 0..<frames {
            var value = 0.0
            if playing {
                let t = Double(sample)/rate, beat = t/beatLength, since = (beat-beat.rounded(.down))*beatLength
                let bar = Int(beat/4)%4
                value += sin(2 * .pi*(48+70*exp(-since*30))*since)*exp(-since*14)*0.55 // kick
                let half = since-beatLength/2
                if half > 0 { value += (Double(noise.next()%2000)/1000-1)*exp(-half*70)*0.12 } // hi-hat
                value += sin(2 * .pi*bass[bar]*2*t)*min(1,since*40)*exp(-since*3)*0.22 // bass
                sample += 1
            }
            for v in voices.indices {
                let age = Double(voices[v].age)/rate
                switch voices[v].sound {
                case .good: value += ((Double(noise.next()%2000)/1000-1)*0.35+sin(2 * .pi*1320*age)*0.25)*exp(-age*28)
                case .bad: value += sin(2 * .pi*180*age)*exp(-age*16)*0.4
                case .miss: value += sin(2 * .pi*90*age)*exp(-age*10)*0.25
                }
                voices[v].age += 1
            }
            if i == frames-1 { voices.removeAll { Double($0.age)/rate > 0.4 } }
            for buffer in buffers { buffer.mData!.assumingMemoryBound(to:Float.self)[i] = Float(max(-1,min(1,value))) }
        }
        lock.unlock()
    }
}
