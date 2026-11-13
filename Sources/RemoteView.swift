import SwiftUI

// Semantic system colours only, so the remote reads correctly in light and dark mode.
private let accent = Color.accentColor
// The Wii Remote's dark controls: black in light mode, graphite in dark mode so they stay dark keys.
private let graphite = Color(UIColor { $0.userInterfaceStyle == .dark ? .systemGray3 : .label })

struct RemoteKey: View {
    let title: String
    var symbol: String? = nil
    var size: CGFloat = 54
    var dark = false
    let active: Bool
    let action: (Bool) -> Void
    @State private var down = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        let fill = active ? accent : (dark ? graphite : Color(.secondarySystemGroupedBackground))
        let ink = active || dark ? Color.white : Color(.label)
        Group {
            if let symbol { Image(systemName:symbol).font(.system(size:size*0.38,weight:.semibold)) }
            else { Text(title).font(.system(size:size > 70 ? 32 : 23,weight:.semibold,design:.rounded)).tracking(size > 70 ? -0.6 : 0) }
        }
        .foregroundStyle(ink)
        .frame(width:size,height:size)
        .background(fill,in:Circle())
        .overlay(Circle().strokeBorder(Color(.separator).opacity(active ? 0 : 0.5),lineWidth:0.5))
        .shadow(color:.black.opacity(active ? 0 : 0.12),radius:active ? 1 : 4,y:active ? 0 : 2)
        // Feedback starts on touch-down. A critically damped spring keeps rapid presses interruptible.
        .scaleEffect(active && !reduceMotion ? 0.93 : 1)
        .animation(reduceMotion ? nil : .spring(response:0.16,dampingFraction:1),value:active)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settings = false
    @State private var running = false
    private func key(_ name:String, symbol:String? = nil, size:CGFloat = 50, dark:Bool = false) -> some View {
        RemoteKey(title:name,symbol:symbol,size:size,dark:dark,active:controller.held.contains(name)) {
            controller.button(name,source:"touch-\(name)",down:$0)
        }
    }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 600
            let cross: CGFloat = compact ? 124 : 150
            VStack(spacing:0) {
                Picker("Sport",selection:$controller.profile) {
                    ForEach(["Golf","Bowling","Tennis"],id:\.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                // A held Volume Up belongs to the previous sport's button.
                .onChange(of:controller.profile) { _,_ in controller.button("",source:"volume-up",down:false) }
                Spacer(minLength:8)
                dpad(size:cross)
                Spacer(minLength:8)
                key("A",size:compact ? 72 : 86)
                Spacer(minLength:8)
                HStack(spacing:32) {
                    key("-",symbol:"minus",size:44)
                    key("Home",symbol:"house.fill",size:44)
                    key("+",symbol:"plus",size:44)
                }
                Spacer(minLength:8)
                HStack(spacing:22) {
                    key("B",size:54,dark:true)
                    VStack(alignment:.leading,spacing:2) {
                        Text("Side buttons").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text("Volume + → \(controller.trigger) · Volume − → B").font(.footnote)
                    }
                }
                Spacer(minLength:8)
                HStack(spacing:28) { key("1",size:44); key("2",size:44) }
                Spacer(minLength:8)
                HStack(spacing:8) {
                    ForEach(0..<4) { i in
                        Capsule().fill(i == controller.player-1 && running ? accent : Color(.tertiaryLabel).opacity(0.4)).frame(width:10,height:5)
                    }
                }.accessibilityElement().accessibilityLabel(running ? "Player \(controller.player) active" : "Controller stopped")
            }
            .padding(.horizontal,24).padding(.vertical,compact ? 8 : 14)
            .frame(width:geometry.size.width,height:geometry.size.height)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .safeAreaInset(edge:.top,spacing:0) { header }
        .safeAreaInset(edge:.bottom,spacing:0) { footer }
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
        .sheet(isPresented:$calibrationSheet) { calibrationView }
    }
    private var statusColor: Color {
        !running ? Color(.tertiaryLabel) : (controller.status.hasPrefix("Connected") ? .green : .orange)
    }
    // Translucent bars: the remote stays the focus, navigation and status float above it.
    private var header: some View {
        HStack(spacing:8) {
            Button { settings = true } label: {
                Image(systemName:"slider.horizontal.3").font(.body.weight(.semibold)).frame(width:44,height:44)
            }.accessibilityLabel("Settings")
            VStack(spacing:2) {
                Text("MotionRemote").font(.headline)
                HStack(spacing:6) {
                    Circle().fill(statusColor).frame(width:7,height:7)
                    Text(controller.status).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                }
                .animation(reduceMotion ? nil : .spring(response:0.3,dampingFraction:1),value:controller.status)
            }
            .frame(maxWidth:.infinity).accessibilityElement(children:.combine)
            Button { stop() } label: {
                Image(systemName:"power").font(.body.weight(.semibold)).frame(width:44,height:44)
            }.accessibilityLabel("Stop controller").disabled(!running)
        }
        .padding(.horizontal,8).padding(.bottom,4)
        .background(.bar)
    }
    private var footer: some View {
        VStack(spacing:10) {
            HStack(spacing:12) {
                Button {
                    stop(); running = true; controller.start(); probe.start(spatial:controller.spatialEnabled)
                } label: {
                    Label(running ? "Reconnect" : "Connect",systemImage:"antenna.radiowaves.left.and.right")
                        .font(.body.weight(.semibold)).frame(maxWidth:.infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                VStack(spacing:3) {
                    key("Zentrieren",symbol:"scope",size:44).accessibilityLabel("Recenter pointer")
                    Text("Center").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(spacing:3) {
                    Button {
                        controller.spatialEnabled = true
                        if !running { running = true; controller.start(); probe.start(spatial:true) }
                        calibrationSheet = true; controller.calibrate()
                    } label: {
                        Image(systemName:"viewfinder").font(.system(size:17,weight:.semibold)).frame(width:44,height:44)
                            .background(Color(.secondarySystemGroupedBackground),in:Circle())
                    }.buttonStyle(.plain).accessibilityLabel("Calibrate screen and sensors")
                    Text("Calibrate").font(.caption2).foregroundStyle(.secondary)
                }
            }
            RecordingControls(controller:controller,library:controller.recordings,onPlayback:{stop()})
            HStack(spacing:8) {
                Text(running ? "\(controller.address) · UDP 26760" : "Tap Connect to start the controller")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                Spacer()
                Text("CAM").font(.system(size:8,weight:.bold)).foregroundStyle(.secondary)
                CaptureSurface(probe:probe).frame(width:24,height:18).clipShape(RoundedRectangle(cornerRadius:4))
                    .accessibilityLabel("Local camera preview for volume trigger")
            }
        }
        .padding(.horizontal,16).padding(.top,10).padding(.bottom,4)
        .background(.bar)
    }
    private var calibrationView: some View {
        NavigationStack {
            Form {
                Section {
                    ScreenCalibrationView(tracker:probe.spatial)
                } header: { Text("Screen") } footer: {
                    Text("Once calibrated, pointing at the screen centre is always straight ahead in Dolphin and MotionSaber.")
                }
                Section {
                    Text(controller.trackingStatus)
                    if !controller.calibrationMessage.isEmpty { Text(controller.calibrationMessage).foregroundStyle(.secondary) }
                    Button("Measure Gyro Again") { controller.calibrate() }
                    Button("Set Screen Centre") {
                        controller.button("Zentrieren",source:"calibration",down:true)
                        DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { controller.button("Zentrieren",source:"calibration",down:false) }
                        calibrationSheet = false
                    }.disabled(!controller.calibrationReady || !controller.trackingStatus.hasPrefix("Position tracked"))
                } header: { Text("Motion sensors") } footer: {
                    Text("Keep the phone still for a second to measure the gyro. Without a screen calibration, point at the screen centre and set it here or with Center.")
                }
            }
            .navigationTitle("Calibrate").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { calibrationSheet = false } } }
        }
        .presentationDetents([.medium,.large])
    }
    private func dpad(size:CGFloat) -> some View {
        let cell = size/3
        return ZStack {
            RoundedRectangle(cornerRadius:10).fill(graphite).frame(width:cell,height:size)
            RoundedRectangle(cornerRadius:10).fill(graphite).frame(width:size,height:cell)
            Circle().stroke(.white.opacity(0.2),lineWidth:1).frame(width:20,height:20)
            ForEach(0..<4) { index in
                let names = ["Up","Right","Down","Left"]
                let icons = ["chevron.up","chevron.right","chevron.down","chevron.left"]
                let x: CGFloat = index == 1 ? cell : (index == 3 ? -cell : 0)
                let y: CGFloat = index == 2 ? cell : (index == 0 ? -cell : 0)
                let pressed = controller.held.contains(names[index])
                Image(systemName:icons[index]).font(.system(size:16,weight:.bold))
                    .foregroundStyle(pressed ? accent : .white.opacity(0.85))
                    .scaleEffect(pressed && !reduceMotion ? 0.85 : 1)
                    .animation(reduceMotion ? nil : .spring(response:0.16,dampingFraction:1),value:pressed)
                    .frame(width:cell,height:cell)
                    .overlay(TouchSurface { controller.button(names[index],source:"touch-\(names[index])",down:$0) })
                    .accessibilityLabel(names[index]).offset(x:x,y:y)
            }
        }.frame(width:size,height:size).shadow(color:.black.opacity(0.18),radius:5,y:3)
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
            Text("Touch the left edge of the Mac screen at middle height with the phone’s top camera corner, then tap Mark left edge. Repeat on the right edge. The room is saved, so this is needed once per desk.")
                .font(.footnote)
            Text(tracker.hasLiDAR ? "LiDAR available: tracking starts quickly." : "No LiDAR: camera tracking still works. Move the phone slowly for a few seconds after starting.")
                .font(.footnote).foregroundStyle(.secondary)
            Text(tracker.screenStatus).font(.callout.weight(.semibold))
            HStack {
                Button("Mark left edge") { tracker.mark() }.disabled(!tracker.canMark || tracker.leftMarked)
                Button("Mark right edge") { tracker.mark() }.disabled(!tracker.canMark || !tracker.leftMarked)
            }.buttonStyle(.borderedProminent)
            Button("Forget Saved Room",role:.destructive) { tracker.forget() }.disabled(!tracker.hasSavedRoom)
        }.frame(maxWidth:.infinity,alignment:.leading)
    }
}
