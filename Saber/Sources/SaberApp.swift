import SwiftUI
import AppKit
import SceneKit
import QuartzCore
import simd

@main struct MotionSaberApp: App {
    @StateObject private var model = SaberModel()
    var body: some Scene {
        WindowGroup("MotionSaber") {
            SaberView(model:model).onAppear {
                if let url = Bundle.main.url(forResource:"AppIcon",withExtension:"png") { NSApp.applicationIconImage = NSImage(contentsOf:url) }
                model.launch()
            }
        }.defaultSize(width:1280,height:800)
    }
}

final class SaberModel: ObservableObject {
    enum Phase { case menu, playing, paused, results }
    @Published private(set) var phase = Phase.menu
    @Published private(set) var hud = (score:0,combo:0,multiplier:1,good:0,bad:0,missed:0,accuracy:1.0,maxCombo:0)
    @Published private(set) var countdown = ""
    let log: EventLog
    let link: SaberLink
    let scene = SaberScene()
    private let audio: SaberAudio
    private var game = SaberGame()
    private var mapper = SwordMapper()
    private var sword = Sword(hilt:SwordMapper.base,tip:SwordMapper.base+SIMD3(0,0,-SaberGame.bladeLength))
    private var songTime = -2.0
    private var lastFrame: Double?
    private var slowFrames = 0
    private var trackingLossMisses = 0
    private var displayLink: CADisplayLink?
    init() {
        let logs = FileManager.default.urls(for:.libraryDirectory,in:.userDomainMask)[0].appendingPathComponent("Logs/MotionSaber")
        log = EventLog(directory:logs,prefix:"MotionSaber")
        link = SaberLink(log:log)
        audio = SaberAudio(log:log)
        let info = Bundle.main.infoDictionary
        log.write("APP","MotionSaber \(info?["CFBundleShortVersionString"] ?? "dev") on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        link.onButton = { [weak self] name in self?.button(name) }
    }
    func launch() {
        link.browse()
        guard displayLink == nil, let view = NSApp.windows.first?.contentView else { return }
        if let screen = NSApp.windows.first?.screen,
           let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            let size = CGDisplayScreenSize(number.uint32Value)
            link.displayWidth = Float(size.width/1000)
            log.write("APP",String(format:"Display %@: %.1f × %.1f cm",screen.localizedName,size.width/10,size.height/10))
        }
        let display = view.displayLink(target:self,selector:#selector(frame(_:)))
        display.add(to:.main,forMode:.common); displayLink = display
        // For scripted checks: open … --args -autoconnect YES -phoneAddress 127.0.0.1 -autostart YES
        if UserDefaults.standard.bool(forKey:"autoconnect") { link.connect() }
        if UserDefaults.standard.bool(forKey:"autostart") { DispatchQueue.main.asyncAfter(deadline:.now()+1.5) { self.start() } }
        NSEvent.addLocalMonitorForEvents(matching:.keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.charactersIgnoringModifiers {
            case " ": phase == .playing || phase == .paused ? togglePause() : start(); return nil
            case "r": link.recenter(); return nil
            default: return event
            }
        }
    }
    func start() {
        game = SaberGame(); scene.reset(); songTime = -Double(Chart.leadInBeats)*60/Chart.bpm
        trackingLossMisses = 0; slowFrames = 0
        audio.stop(); audio.start(at:0)
        phase = .playing; publish()
        log.write("GAME","Song started · \(game.notes.count) blocks · sword source: \(link.source.rawValue)")
    }
    func togglePause() {
        if phase == .playing { phase = .paused; audio.pause(); log.write("GAME","Paused") }
        else if phase == .paused { phase = .playing; audio.resume(); log.write("GAME","Resumed") }
    }
    func toMenu() { phase = .menu; audio.stop(); scene.reset() }
    private func button(_ name: String) {
        switch (name,phase) {
        case ("A",.menu),("A",.results): start()
        case ("Home",.playing),("Home",.paused),("+",.playing),("+",.paused): togglePause()
        default: break
        }
    }
    @objc private func frame(_ display: CADisplayLink) {
        let now = CACurrentMediaTime()
        let dt = min(0.1,now-(lastFrame ?? now)); lastFrame = now
        if dt > 0.05 { slowFrames += 1 }
        let input = link.input(now:ProcessInfo.processInfo.systemUptime)
        link.frame(dt:dt)
        let previous = sword
        sword = mapper.sword(position:input.position,orientation:input.orientation,dt:dt)
        if phase == .playing {
            songTime += dt
            for event in game.update(time:songTime,previous:previous,current:sword,dt:dt) {
                switch event {
                case let .cut(note,good,normal,speed,angle):
                    scene.cut(note,good:good,normal:normal); audio.play(good ? .good : .bad)
                    if !good { log.write("GAME",String(format:"Block #%d %@: wrong direction, swing %.0f° off the arrow (speed %.1f)",note.id,Self.describe(note),angle,speed)) }
                    link.haptic(good ? .good : .bad)
                case let .miss(note):
                    scene.miss(note); audio.play(.miss); link.haptic(.miss)
                    log.write("GAME",Self.explain(note))
                    if input.source != .camera { trackingLossMisses += 1 }
                }
            }
            if songTime > game.finishTime { finish() }
        }
        scene.update(time:songTime,game:game,sword:sword,tracked:input.source != .none)
        if Int(now*15) != Int((now-dt)*15) { publish() }
    }
    static func describe(_ note: Note) -> String {
        let arrow = note.direction.map { ["↑","↓","←","→"][$0.rawValue] } ?? "•"
        return "(column \(note.column+1), row \(note.row+1), \(arrow))"
    }
    // Why a block was missed, so hit rules can be tuned from real play.
    static func explain(_ note: Note) -> String {
        let why: String
        if note.closest > 2 { why = note.closest.isFinite ? String(format:"sword never came near (closest %.1f× the hit size)",note.closest) : "sword never came near" }
        else if note.closest >= 1 { why = String(format:"just past it (closest %.1f× the hit size)",note.closest) }
        else if note.fastest < SaberGame.minSpeed { why = String(format:"touched, but the swing was too slow (%.1f, needs %.1f)",note.fastest,SaberGame.minSpeed) }
        else { why = "touched only in the wrong direction while it was still far away" }
        return "Block #\(note.id) \(describe(note)) missed: \(why)\(note.ignoredWrong > 0 ? " · \(note.ignoredWrong) early wrong-direction sweeps ignored" : "")"
    }
    private func finish() {
        phase = .results; audio.stop(); publish()
        log.write("GAME",String(format:"Song finished · score %d · %d good, %d bad cuts, %d missed (%d of them without camera tracking) · accuracy %.0f%% · max combo %d · %d slow frames (> 50 ms)",
                               game.score,game.good,game.bad,game.missed,trackingLossMisses,game.accuracy*100,game.maxCombo,slowFrames))
    }
    private func publish() {
        hud = (game.score,game.combo,game.multiplier,game.good,game.bad,game.missed,game.accuracy,game.maxCombo)
        countdown = phase == .playing && songTime < 0 ? "\(Int(-songTime*Chart.bpm/60)+1)" : ""
    }
}

struct SaberView: View {
    @ObservedObject var model: SaberModel
    @ObservedObject var link: SaberLink
    init(model: SaberModel) { self.model = model; link = model.link }
    var body: some View {
        ZStack {
            SceneSurface(scene:model.scene).ignoresSafeArea()
            VStack {
                HStack(alignment:.top) {
                    if model.phase != .menu { score }
                    Spacer()
                    status
                }
                Spacer()
                switch model.phase {
                case .menu: menu
                case .paused: card { Text("Paused").font(.largeTitle.bold()); Text("Space, Home or + on the phone to continue"); Button("Quit to menu") { model.toMenu() } }
                case .results: results
                case .playing: Text(model.countdown).font(.system(size:96,weight:.heavy,design:.rounded)).foregroundStyle(.white)
                }
                Spacer()
                if link.source == .motion && model.phase != .results { hint("Motion only: no hand position. Point at the screen centre and press the crosshair on the phone (or R) to recenter.") }
                Text("Diagnostics log: \(model.log.url.path)").font(.caption2).foregroundStyle(.white.opacity(0.45))
                    .onTapGesture { NSWorkspace.shared.activateFileViewerSelecting([model.log.url]) }
            }.padding(24)
            if link.calibration == "Screen not calibrated" && link.connected { edgeMarkers }
        }.background(.black)
    }
    private var score: some View {
        VStack(alignment:.leading,spacing:2) {
            Text("\(model.hud.score)").font(.system(size:44,weight:.heavy,design:.rounded)).monospacedDigit()
            Text("×\(model.hud.multiplier)  ·  combo \(model.hud.combo)").font(.title3.weight(.semibold))
        }.foregroundStyle(.white)
    }
    private var status: some View {
        VStack(alignment:.trailing,spacing:4) {
            HStack(spacing:8) {
                Circle().fill(link.source == .camera ? .green : (link.source == .motion ? .yellow : .red)).frame(width:10,height:10)
                Text(link.connected ? link.source.rawValue : link.status).font(.callout.weight(.semibold))
            }
            if link.connected { Text(link.calibration).font(.caption) }
            if link.connected && link.source != .camera && !link.tracking.isEmpty { Text(link.tracking).font(.caption).multilineTextAlignment(.trailing).frame(maxWidth:360,alignment:.trailing) }
        }.foregroundStyle(.white).padding(10).background(.black.opacity(0.45),in:RoundedRectangle(cornerRadius:10))
    }
    private var menu: some View {
        card {
            Text("MotionSaber").font(.system(size:44,weight:.heavy,design:.rounded))
            Text("Your iPhone is the sword. Cut each block in the direction of its arrow; dots can be cut in any direction.").multilineTextAlignment(.center)
            HStack {
                Picker("iPhone",selection:$link.selected) {
                    if link.phones.isEmpty { Text("Searching…").tag("") }
                    ForEach(link.phones,id:\.self) { Text($0.name).tag($0.name) }
                }.frame(maxWidth:240)
                TextField("or IPv4 address",text:$link.address).textFieldStyle(.roundedBorder).frame(width:150)
                Button(link.connected ? "Reconnect" : "Connect") { link.connect() }
            }
            Button("Start (Space or A on the phone)") { model.start() }.buttonStyle(.borderedProminent).controlSize(.large)
            Text("Camera tracking with a calibrated screen gives the sword position and direction. Without it the game uses motion only. Calibrate on the phone: Calibrate pointer → Screen calibration.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
    }
    private var results: some View {
        card {
            Text("\(model.hud.score)").font(.system(size:56,weight:.heavy,design:.rounded))
            Text("\(model.hud.good) cut · \(model.hud.bad) wrong direction · \(model.hud.missed) missed")
            Text(String(format:"Accuracy %.0f%% · max combo %d",model.hud.accuracy*100,model.hud.maxCombo))
            HStack { Button("Play again") { model.start() }.buttonStyle(.borderedProminent); Button("Menu") { model.toMenu() } }
        }
    }
    private var edgeMarkers: some View {
        HStack {
            Label("Touch the left screen edge here with the phone's camera corner, then tap Mark left edge",systemImage:"arrowtriangle.left.fill")
            Spacer()
            Label("…then the right edge and Mark right edge",systemImage:"arrowtriangle.right.fill").labelStyle(TrailingIcon())
        }.font(.callout.weight(.semibold)).foregroundStyle(.yellow).padding(.horizontal,4)
    }
    private func hint(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(.white).padding(10).background(.black.opacity(0.5),in:RoundedRectangle(cornerRadius:10))
    }
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing:16,content:content).padding(28).frame(maxWidth:640).background(.regularMaterial,in:RoundedRectangle(cornerRadius:18))
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View { HStack { configuration.title; configuration.icon } }
}

struct SceneSurface: NSViewRepresentable {
    let scene: SaberScene
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene.scene; view.pointOfView = scene.camera
        view.antialiasingMode = .multisampling4X; view.rendersContinuously = true
        view.setAccessibilityLabel("Game view: blocks fly towards you; the glowing sword follows the phone")
        return view
    }
    func updateNSView(_ view: SCNView, context: Context) {}
}
