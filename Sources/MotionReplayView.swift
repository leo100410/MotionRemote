import SwiftUI
import SceneKit
import simd

struct RecordingControls: View {
    let controller: Controller
    @ObservedObject var library: MotionLibrary
    let onPlayback: () -> Void
    @State private var showLibrary = false
    var body: some View {
        HStack {
            Button { controller.toggleRecording() } label: {
                Label(library.isRecording ? String(format:"Stop · %.1fs",library.elapsed) : "Record motion",
                      systemImage:library.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundStyle(library.isRecording ? .red : .primary)
            }
            Spacer()
            Button { onPlayback(); showLibrary = true } label: { Label("Playback",systemImage:"cube.transparent") }
                .disabled(library.isRecording)
        }.font(.system(size:12,weight:.semibold)).frame(height:32)
        .fullScreenCover(isPresented:$showLibrary) { RecordingsView(library:library) }
        .alert("Motion recording",isPresented:Binding(get:{library.error != nil && !showLibrary},set:{if !$0 { library.error = nil }})) {
            Button("OK") { library.error = nil }
        } message: { Text(library.error ?? "") }
    }
}

struct RecordingsView: View {
    @ObservedObject var library: MotionLibrary
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Record up to two minutes while playing, or record without connecting to Dolphin. Motion is saved only on this iPhone. Opening Playback stops the live controller; reconnect when you are done.")
                }
                if let error = library.error {
                    Section("Recording issue") {
                        Text(error).foregroundStyle(.red)
                        Button("Dismiss") { library.error = nil }
                    }
                }
                if library.pendingSave != nil {
                    Section("Unsaved take") { Button("Retry save") { library.retrySave() } }
                }
                Section("Your recordings") {
                    if library.entries.isEmpty {
                        ContentUnavailableView("No recordings yet",systemImage:"record.circle",description:Text("Close this screen and tap Record motion."))
                    }
                    ForEach(library.entries) { entry in
                        NavigationLink {
                            LoadReplayView(library:library,entry:entry)
                        } label: {
                            Label(entry.date.formatted(date:.abbreviated,time:.standard),systemImage:"waveform.path")
                        }
                    }.onDelete(perform:library.delete)
                }
            }.navigationTitle("Motion recordings")
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { dismiss() } } }
                .onAppear { library.refresh() }
        }
    }
}

private struct LoadReplayView: View {
    let library: MotionLibrary
    let entry: RecordingEntry
    @State private var take: MotionTake?
    @State private var failure: String?
    var body: some View {
        Group {
            if let take { MotionReplayView(take:take) }
            else if let failure { ContentUnavailableView("Cannot open recording",systemImage:"exclamationmark.triangle",description:Text(failure)) }
            else { ProgressView("Loading motion…") }
        }.task {
            do { take = try await library.load(entry) }
            catch { failure = error.localizedDescription }
        }
    }
}

private struct MotionReplayView: View {
    let take: MotionTake
    @State private var time = 0.0
    @State private var playing = false
    @State private var speed = 1.0
    @State private var lastTick = Date()
    @State private var resetCamera = 0
    @Environment(\.scenePhase) private var scenePhase
    private let timer = Timer.publish(every:1/30,on:.main,in:.common).autoconnect()
    var body: some View {
        VStack(spacing:12) {
            ZStack(alignment:.topTrailing) {
                MotionScene(take:take,time:time,reset:resetCamera)
                Button { resetCamera += 1 } label: {
                    Image(systemName:"viewfinder").padding(14).background(.ultraThinMaterial,in:Circle())
                }.padding(12).accessibilityLabel("Reset 3D camera")
            }.frame(maxHeight:.infinity).clipShape(RoundedRectangle(cornerRadius:20))
            Text("Drag to orbit · Pinch to zoom").font(.caption).foregroundStyle(.secondary)
            Text("The phone rotates relative to the first frame. Blue trail: top-edge direction. Yellow arrow: acceleration without gravity. This is not a position path.")
                .font(.caption).foregroundStyle(.secondary)
            let frame = take.frame(at:time)
            HStack {
                metric("Acceleration",String(format:"%.2f g",simd_length(frame.acceleration)))
                Spacer()
                metric("Rotation",String(format:"%.0f °/s",simd_length(frame.angularVelocity)*180 / .pi))
                Spacer()
                metric("Buttons",frame.buttons.isEmpty ? "—" : frame.buttons.map { $0 == "Zentrieren" ? "Recenter" : $0 }.joined(separator:" + "))
            }
            Slider(value:$time,in:0...max(take.duration,0.001),onEditingChanged:{ if $0 { playing = false } })
                .accessibilityLabel("Recording timeline")
            HStack {
                Text(String(format:"%.2f / %.2f s",time,take.duration)).font(.caption.monospacedDigit())
                Spacer()
                Picker("Speed",selection:$speed) {
                    ForEach([0.25,0.5,1.0,2.0],id:\.self) { Text(String(format:"%g×",$0)).tag($0) }
                }.pickerStyle(.menu).accessibilityLabel("Playback speed")
                Button {
                    if time >= take.duration { time = 0 }
                    lastTick = Date(); playing.toggle()
                } label: { Image(systemName:playing ? "pause.fill" : "play.fill").frame(width:44,height:44) }
                    .buttonStyle(.borderedProminent).accessibilityLabel(playing ? "Pause" : "Play")
            }
        }.padding().navigationTitle("\(take.sport) · Player \(take.player)").navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { now in
            defer { lastTick = now }
            guard playing else { return }
            time = min(take.duration,time+max(0,now.timeIntervalSince(lastTick))*speed)
            if time >= take.duration { playing = false }
        }
        .onChange(of:scenePhase) { _,phase in if phase != .active { playing = false } }
        .onChange(of:playing) { _,active in UIApplication.shared.isIdleTimerDisabled = active }
        .onDisappear { playing = false; UIApplication.shared.isIdleTimerDisabled = false }
    }
    private func metric(_ title:String,_ value:String) -> some View {
        VStack(alignment:.leading,spacing:3) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size:12,weight:.semibold,design:.monospaced)).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

private struct MotionScene: UIViewRepresentable {
    let take: MotionTake
    let time: Double
    let reset: Int
    func makeCoordinator() -> Coordinator { Coordinator(take:take) }
    func makeUIView(context:Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.backgroundColor = UIColor(red:0.055,green:0.075,blue:0.11,alpha:1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        view.pointOfView = context.coordinator.camera
        view.defaultCameraController.target = SCNVector3Zero
        view.accessibilityLabel = "3D recording: phone orientation and acceleration vector"
        return view
    }
    func updateUIView(_ view:SCNView,context:Context) {
        let c = context.coordinator
        SCNTransaction.begin(); SCNTransaction.animationDuration = 0
        let rotation = take.rotation(at:time)
        c.phone.simdOrientation = rotation
        c.tip.simdPosition = rotation.act(SIMD3<Float>(0,1.2,0))
        let a = SIMD3<Float>(take.frame(at:time).acceleration)
        let magnitude = simd_length(a)
        c.acceleration.isHidden = magnitude < 0.02
        if magnitude >= 0.02 {
            c.acceleration.simdOrientation = simd_quatf(from:SIMD3<Float>(0,1,0),to:a/magnitude)
            c.acceleration.simdScale = SIMD3<Float>(1,min(2.5,magnitude),1)
        }
        if c.reset != reset {
            c.reset = reset; c.camera.position = SCNVector3(2.6,1.7,4.5)
            c.camera.look(at:SCNVector3Zero); view.pointOfView = c.camera
        }
        SCNTransaction.commit()
    }
    final class Coordinator {
        let scene = SCNScene()
        let phone = SCNNode()
        let camera = SCNNode()
        let acceleration = SCNNode()
        let tip = SCNNode(geometry:SCNSphere(radius:0.055))
        var reset = 0
        init(take:MotionTake) {
            camera.camera = SCNCamera(); camera.camera?.zNear = 0.01
            camera.position = SCNVector3(2.6,1.7,4.5); camera.look(at:SCNVector3Zero)
            scene.rootNode.addChildNode(camera)
            let body = SCNNode(geometry:SCNBox(width:0.65,height:1.3,length:0.09,chamferRadius:0.06))
            body.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGray4
            phone.addChildNode(body)
            let screen = SCNNode(geometry:SCNBox(width:0.56,height:1.13,length:0.012,chamferRadius:0.035))
            screen.position.z = 0.055; screen.geometry?.firstMaterial?.diffuse.contents = UIColor.systemBlue
            phone.addChildNode(screen)
            let notch = SCNNode(geometry:SCNCapsule(capRadius:0.025,height:0.18))
            notch.eulerAngles.z = .pi/2; notch.position = SCNVector3(0,0.49,0.07)
            notch.geometry?.firstMaterial?.diffuse.contents = UIColor.black; phone.addChildNode(notch)
            scene.rootNode.addChildNode(phone)
            phone.addChildNode(acceleration)
            let shaft = SCNNode(geometry:SCNCylinder(radius:0.018,height:0.85)); shaft.position.y = 0.425
            let head = SCNNode(geometry:SCNCone(topRadius:0,bottomRadius:0.07,height:0.15)); head.position.y = 0.925
            for node in [shaft,head] { node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemYellow; acceleration.addChildNode(node) }
            tip.geometry?.firstMaterial?.diffuse.contents = UIColor.systemCyan; scene.rootNode.addChildNode(tip)
            let axes: [(SIMD3<Float>,UIColor,String)] = [(.init(1.6,0,0),.systemRed,"X"),(.init(0,1.6,0),.systemGreen,"Y"),(.init(0,0,1.6),.systemBlue,"Z")]
            for (end,color,name) in axes {
                scene.rootNode.addChildNode(Self.line([SCNVector3Zero,SCNVector3(end)],color:color))
                let text = SCNText(string:name,extrusionDepth:0); text.font = .systemFont(ofSize:0.15)
                text.firstMaterial?.diffuse.contents = color
                let label = SCNNode(geometry:text); label.simdPosition = end
                label.constraints = [SCNBillboardConstraint()]; scene.rootNode.addChildNode(label)
            }
            let step = max(1,take.frames.count/1000)
            let trace = stride(from:0,to:take.frames.count,by:step).map {
                SCNVector3(take.rotation(at:take.frames[$0].time).act(SIMD3<Float>(0,1.2,0)))
            }
            scene.rootNode.addChildNode(Self.line(trace,color:.systemCyan.withAlphaComponent(0.45)))
        }
        static func line(_ points:[SCNVector3],color:UIColor) -> SCNNode {
            guard points.count > 1 else { return SCNNode() }
            let indices = (0..<(points.count-1)).flatMap { [UInt32($0),UInt32($0+1)] }
            let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:points)],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)])
            geometry.firstMaterial?.diffuse.contents = color
            geometry.firstMaterial?.lightingModel = .constant
            return SCNNode(geometry:geometry)
        }
    }
}
