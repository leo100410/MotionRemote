import SwiftUI

private let ink = Color(red:0.12,green:0.16,blue:0.21)
private let accent = Color(red:0.04,green:0.43,blue:0.96)

struct RemoteKey: View {
    let title: String
    var symbol: String? = nil
    var size: CGFloat = 54
    var dark = false
    let active: Bool
    let action: (Bool) -> Void
    @State private var down = false
    var body: some View {
        Group {
            if let symbol { Image(systemName:symbol).font(.system(size:20,weight:.semibold)) }
            else { Text(title).font(.system(size:size > 70 ? 32 : 23,weight:.semibold,design:.rounded)) }
        }
        .foregroundStyle(active ? .white : (dark ? .white : ink))
        .frame(width:size,height:size)
        .background(active ? accent : (dark ? ink : .white),in:Circle())
        .overlay(Circle().strokeBorder(.black.opacity(0.07),lineWidth:1))
        .shadow(color:.black.opacity(active ? 0 : 0.09),radius:4,y:3)
        .scaleEffect(active ? 0.94 : 1)
        .overlay(TouchSurface { pressed in down = pressed; action(pressed) }.clipShape(Circle()))
        .onDisappear { if down { down = false; action(false) } }
        .accessibilityLabel(title).accessibilityAddTraits(.isButton)
        .accessibilityAction { action(true); DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { action(false) } }
    }
}

struct RemoteView: View {
    @StateObject private var internetTest = InternetTest()
    @State private var calibrationSheet = false
    @StateObject private var controller = Controller()
    @StateObject private var probe = Probe()
    @Environment(\.scenePhase) private var scene
    @State private var settings = false
    @State private var running = false
    private func key(_ name:String, symbol:String? = nil, size:CGFloat = 50, dark:Bool = false) -> some View {
        RemoteKey(title:name,symbol:symbol,size:size,dark:dark,active:controller.held.contains(name)) {
            controller.button(name,source:"touch-\(name)",down:$0)
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 720
            let cross: CGFloat = compact ? 132 : 156
            let gap: CGFloat = compact ? 3 : 8
            VStack(spacing:0) {
                HStack {
                    Button { settings = true } label: {
                        Image(systemName:"slider.horizontal.3").frame(width:44,height:44)
                    }.accessibilityLabel("Settings")
                    Spacer()
                    HStack(spacing:8) {
                        Image(systemName:"dot.radiowaves.left.and.right").foregroundStyle(accent)
                        Text("MOTIONREMOTE").font(.system(size:13,weight:.bold,design:.rounded)).tracking(1.5)
                    }
                    Spacer()
                    Button { stop() } label: {
                        Image(systemName:"power").frame(width:44,height:44)
                    }.accessibilityLabel("Stop controller")
                }.foregroundStyle(ink)
                HStack(spacing:6) {
                    Circle().fill(running ? Color.green : Color.gray.opacity(0.5)).frame(width:6,height:6)
                    Text(controller.status).font(.system(size:11,weight:.medium)).lineLimit(1).minimumScaleFactor(0.75)
                }.foregroundStyle(.secondary).padding(.bottom,12)
                HStack(spacing:4) {
                    ForEach(["Golf","Bowling","Tennis"],id:\.self) { sport in
                        Button {
                            controller.button("",source:"volume-up",down:false); controller.profile = sport
                        } label: {
                            HStack(spacing:6) {
                                Image(systemName:sport == "Golf" ? "flag.fill" : (sport == "Bowling" ? "figure.bowling" : "tennisball.fill"))
                                Text(sport)
                            }.font(.system(size:12,weight:.semibold)).frame(maxWidth:.infinity).padding(.vertical,11)
                                .foregroundStyle(controller.profile == sport ? .white : ink.opacity(0.6))
                                .background(controller.profile == sport ? ink : .clear,in:Capsule())
                        }.buttonStyle(.plain)
                    }
                }.padding(4).background(.black.opacity(0.035),in:Capsule())
                Spacer(minLength:gap)
                dpad(size:cross)
                Spacer(minLength:gap)
                key("A",size:compact ? 72 : 88)
                Spacer(minLength:gap)
                HStack(spacing:32) {
                    key("-",symbol:"minus",size:44)
                    key("Home",symbol:"house.fill",size:44)
                    key("+",symbol:"plus",size:44)
                }
                Spacer(minLength:gap)
                HStack(spacing:26) {
                    key("B",size:54,dark:true)
                    VStack(alignment:.leading,spacing:3) {
                        Text("SIDE TRIGGER").font(.system(size:9,weight:.bold)).tracking(1.4).foregroundStyle(.secondary)
                        Label("Vol + → \(controller.trigger) · Vol − → B",systemImage:"speaker.plus.fill").font(.system(size:12,weight:.medium))
                    }
                }
                Spacer(minLength:gap)
                if compact {
                    HStack(spacing:20) { key("1",size:44); key("2",size:44) }
                } else {
                    VStack(spacing:12) { key("1",size:44); key("2",size:44) }
                }
                Spacer(minLength:gap)
                HStack(spacing:8) {
                    ForEach(0..<4) { i in
                        RoundedRectangle(cornerRadius:2).fill(i == controller.player-1 && running ? accent : accent.opacity(0.13)).frame(width:8,height:5)
                    }
                }.accessibilityLabel(running ? "Player \(controller.player) active" : "Controller stopped")
                Spacer(minLength:gap)
                footer
            }
            .padding(.horizontal,24).padding(.top,4).padding(.bottom,8)
            .frame(width:geometry.size.width,height:geometry.size.height)
        }
        .background(LinearGradient(colors:[Color(red:0.96,green:0.97,blue:0.98),Color(red:0.89,green:0.92,blue:0.95)],startPoint:.topLeading,endPoint:.bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.light)
        .onAppear {
            probe.spatial.onPose = { controller.updateSpatialPose($0) }
            probe.spatial.onScreen = { controller.updateScreenPose($0) }
            probe.onEvent = { channel,phase in
                guard running else { return }
                controller.volumeEvent(channel:channel,phase:phase)
            }
        }
        .onChange(of:controller.spatialEnabled) { _,_ in
            controller.button("",source:"volume-up",down:false)
            controller.button("",source:"volume-down",down:false)
            if running { probe.stop(); probe.start(spatial:controller.spatialEnabled) }
        }
        .onChange(of:scene) { _,phase in if phase == .background { stop() } }
        .onReceive(NotificationCenter.default.publisher(for:.AVCaptureSessionWasInterrupted)) { _ in stop() }
        .sheet(isPresented:$settings) { settingsView }
        .sheet(isPresented:$calibrationSheet) {
            ScrollView { VStack(spacing:24) {
                Text("Calibrate pointer").font(.title.bold())
                ScreenCalibrationView(tracker:probe.spatial)
                Divider()
                Text("Connect first. Keep the rear camera uncovered and scan the room briefly.")
                Text(controller.trackingStatus)
                Text(controller.calibrationMessage)
                Button("Measure again") { controller.calibrate() }
                Button("Set screen centre") {
                    controller.button("Zentrieren",source:"calibration",down:true)
                    DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { controller.button("Zentrieren",source:"calibration",down:false) }
                    calibrationSheet = false
                }.disabled(!controller.calibrationReady || !controller.trackingStatus.hasPrefix("Position tracked"))
            }.padding() }.presentationDetents([.medium,.large])
        }
    }
    private func dpad(size:CGFloat) -> some View {
        let cell = size/3
        return ZStack {
            RoundedRectangle(cornerRadius:10).fill(ink).frame(width:cell,height:size)
            RoundedRectangle(cornerRadius:10).fill(ink).frame(width:size,height:cell)
            Circle().stroke(.white.opacity(0.15),lineWidth:1).frame(width:20,height:20)
            ForEach(0..<4) { index in
                let names = ["Up","Right","Down","Left"]
                let icons = ["chevron.up","chevron.right","chevron.down","chevron.left"]
                let x: CGFloat = index == 1 ? cell : (index == 3 ? -cell : 0)
                let y: CGFloat = index == 2 ? cell : (index == 0 ? -cell : 0)
                Image(systemName:icons[index]).font(.system(size:16,weight:.bold))
                    .foregroundStyle(controller.held.contains(names[index]) ? accent : .white.opacity(0.8))
                    .frame(width:cell,height:cell)
                    .overlay(TouchSurface { controller.button(names[index],source:"touch-\(names[index])",down:$0) })
                    .accessibilityLabel(names[index]).offset(x:x,y:y)
            }
        }.frame(width:size,height:size).shadow(color:ink.opacity(0.2),radius:5,y:4)
    }
    private var footer: some View {
        VStack(spacing:8) {
            RecordingControls(controller:controller,library:controller.recordings,onPlayback:{stop()})
            HStack(spacing:10) {
                Button {
                    stop(); running = true; controller.start(); probe.start(spatial:controller.spatialEnabled)
                } label: {
                    Label(running ? "Reconnect" : "Connect",systemImage:"antenna.radiowaves.left.and.right")
                        .font(.system(size:14,weight:.semibold)).frame(maxWidth:.infinity).frame(height:46)
                        .foregroundStyle(.white).background(accent,in:RoundedRectangle(cornerRadius:15))
                }
                key("Zentrieren",symbol:"scope",size:46)
                    .accessibilityLabel("Recenter pointer")
                Button {
                    controller.spatialEnabled = true
                    if !running { running = true; controller.start(); probe.start(spatial:true) }
                    calibrationSheet = true; controller.calibrate()
                } label: {
                    Image(systemName:"gyroscope").frame(width:46,height:46)
                        .background(.white.opacity(0.8),in:Circle())
                }.accessibilityLabel("Calibrate: keep phone still for one second")
            }.buttonStyle(.plain)
            HStack(spacing:8) {
                Text(running ? "\(controller.address) · 26760" : "Ready when you are")
                    .font(.system(size:10,weight:.medium,design:.monospaced)).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                Text("CAM").font(.system(size:8,weight:.bold)).foregroundStyle(.secondary)
                CaptureSurface(probe:probe).frame(width:24,height:18).clipShape(RoundedRectangle(cornerRadius:4))
                    .accessibilityLabel("Local camera preview for volume trigger")
            }
        }
    }
    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Connections") {
                    Toggle("Allow Bluetooth connections",isOn:$controller.bluetoothEnabled).disabled(running)
                    BluetoothStatus(controller:controller.bluetooth)
                    LabeledContent("Phone in Dolphin",value:controller.discoveryName)
                    Text("Press Connect on this phone. On the Mac open Options → MotionRemote Connections; on the iPad open Settings → Controllers → Connections. Select this phone over Wi-Fi or Bluetooth. Player profiles are applied automatically.")
                    Text("Bluetooth pairing may require confirmation on both devices. Keep the app open. Stop the controller before changing Bluetooth settings.")
                }
                Section("Network test") {
                    Text(internetTest.status)
                    Text(internetTest.result).font(.footnote)
                    Button(internetTest.running ? "Cancel Internet test" : "Test Internet ping & speed") {
                        if internetTest.running { internetTest.cancel() } else { internetTest.start() }
                    }
                    Text("The optional test sends up to 10 MB to/from Cloudflare over Wi-Fi. Pause gameplay while testing. Dolphin's controller-link test measures the actual phone connection and compares Wi-Fi with Bluetooth.").font(.footnote)
                }
                Section("Multiplayer") {
                    Picker("Player",selection:$controller.player) {
                        ForEach(1...4,id:\.self) { Text("Player \($0)").tag($0) }
                    }.disabled(running)
                    Text("Choose a different player on each iPhone. Stop the controller before changing players.")
                    LabeledContent("DSU server name",value:controller.serverName)
                    LabeledContent("Dolphin profile",value:controller.player == 1 ? "MotionRemote" : "MotionRemote P\(controller.player)")
                }
                Section("Haptics") {
                    Toggle("Button feedback",isOn:$controller.hapticsEnabled)
                    Toggle("Game rumble",isOn:$controller.gameHapticsEnabled)
                    Button("Test game rumble") { controller.gameHaptics.set(0.7) }
                        .disabled(!controller.gameHapticsEnabled || !controller.gameHaptics.supported)
                    Text(controller.gameHaptics.supported ? "Button taps work with any Dolphin version. Game rumble uses Dolphin MotionRemote and its Motor output." : "This device does not support game haptics.")
                }
                Section("Volume buttons") {
                    Text("Volume Down always holds B. Releasing either volume button releases only that button’s input.")
                    Picker("Maps to",selection:$controller.triggerOverride) {
                        Text("Sport default").tag("Automatic"); Text("A").tag("A"); Text("B").tag("B")
                    }.onChange(of:controller.triggerOverride) { _,_ in controller.button("",source:"volume-up",down:false) }
                    Text("Golf and Tennis use A. Bowling uses B. Hold the side button to hold the game button; release to let go.")
                }
                Section("Dolphin setup") {
                    Text("Use the new Connections menu to discover and connect automatically. Manual DSU setup is still available for older Dolphin builds on UDP 26760.")
                    LabeledContent("Phone address",value:controller.address.isEmpty ? "Connect to show address" : controller.address)
                }
                Section("Spatial overlay") {
                    Toggle("Camera tracking & pointer stabilization",isOn:$controller.spatialEnabled)
                    Text(controller.trackingStatus)
                    Text("Uses ARKit to measure a real 3D path relative to your starting point. Keep the rear camera uncovered and the room well lit. Tracking pauses when the camera cannot locate the phone. No camera images are sent to the Mac.")
                    Text("Enable Options → MotionRemote overlay in Dolphin MotionRemote Overlay. If Volume Up does not respond in this mode, use on-screen A/B or switch camera position tracking off.")
                }
                Section("Diagnostics") {
                    ShareLink("Share current log",item:appLog.url)
                    Text("Every session writes a log that explains connection, tracking and calibration problems. All logs are also in the Files app under On My iPhone → MotionRemote → Logs.").font(.footnote)
                }
                Section("Motion") {
                    Text("Keep your phone flat and still for one second when calibrating. Point at the middle of the screen and tap the crosshair to recenter.")
                }
                Section("Camera & privacy") {
                    Text("A small local camera preview keeps the volume-button trigger available. No pictures or audio are saved or sent. Switching away from the app stops the controller.")
                    Text(probe.status)
                }
            }.navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { settings = false } } }
        }
    }
    private func stop() { running = false; probe.stop(); controller.stop() }
}

private struct TouchSurface: UIViewRepresentable {
    let action: (Bool) -> Void
    func makeUIView(context: Context) -> TouchView { let v = TouchView(); v.action = action; return v }
    func updateUIView(_ view: TouchView, context: Context) { view.action = action }
    final class TouchView: UIView {
        var action: ((Bool) -> Void)?
        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { action?(true) }
        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) { action?(false) }
        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { action?(false) }
    }
}

private struct BluetoothStatus: View {
    @ObservedObject var controller: BluetoothController
    var body: some View { LabeledContent("Bluetooth",value:controller.status) }
}

// The virtual sensor bar: the phone learns where the screen is once and keeps it with the saved room.
private struct ScreenCalibrationView: View {
    @ObservedObject var tracker: SpatialTracker
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Screen calibration").font(.headline)
            Text("Touch the left edge of the Mac screen at middle height with the phone’s top camera corner, then tap Mark left edge. Repeat on the right edge. The room is saved, so this is needed once per desk.")
                .font(.footnote)
            Text(tracker.hasLiDAR ? "LiDAR available: tracking starts quickly." : "No LiDAR: camera tracking still works. Move the phone slowly for a few seconds after starting.")
                .font(.footnote).foregroundStyle(.secondary)
            Text(tracker.screenStatus).font(.callout.weight(.semibold))
            HStack {
                Button("Mark left edge") { tracker.mark() }.disabled(!tracker.canMark || tracker.leftMarked)
                Button("Mark right edge") { tracker.mark() }.disabled(!tracker.canMark || !tracker.leftMarked)
            }.buttonStyle(.borderedProminent)
            Button("Forget screen calibration",role:.destructive) { tracker.forget() }.disabled(!tracker.calibrated)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
