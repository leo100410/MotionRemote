import SwiftUI
import AppKit
import SceneKit
import Charts
import simd

@main struct MonitorApp: App {
    @StateObject private var model = MonitorModel()
    var body: some Scene {
        WindowGroup("MotionRemote Monitor") {
            MonitorView(model:model).onAppear {
                if let url = Bundle.main.url(forResource:"AppIcon",withExtension:"png") { NSApp.applicationIconImage = NSImage(contentsOf:url) }
                model.browse()
                // For scripted checks: open … --args -autoconnect YES -phoneAddress 127.0.0.1
                if UserDefaults.standard.bool(forKey:"autoconnect") { model.connect() }
            }
        }.defaultSize(width:1180,height:780)
    }
}

struct MonitorView: View {
    @ObservedObject var model: MonitorModel
    private let titles = ["Acceleration (g)","Rotation rate (°/s)","Orientation (°)","Packet gap (ms)"]
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Picker("iPhone",selection:$model.selected) {
                    if model.phones.isEmpty { Text("Searching…").tag("") }
                    ForEach(model.phones,id:\.self) { Text($0.name).tag($0.name) }
                }.frame(maxWidth:230)
                TextField("or IPv4 address",text:$model.address).textFieldStyle(.roundedBorder).frame(width:150)
                Picker("Player",selection:$model.player) { ForEach(1...4,id:\.self) { Text("\($0)").tag($0) } }.frame(width:110)
                Button("Connect") { model.connect() }.buttonStyle(.borderedProminent)
                Button("Disconnect") { model.disconnect() }
                Toggle("Pause",isOn:$model.paused).toggleStyle(.button)
                Spacer()
                Circle().fill(model.receiving ? .green : .gray).frame(width:10,height:10)
                Text(model.status).foregroundStyle(.secondary)
            }
            HStack(alignment:.top,spacing:12) {
                VStack(alignment:.leading,spacing:6) {
                    PhoneScene(scene:model.scene).clipShape(RoundedRectangle(cornerRadius:10))
                    Text("Live phone orientation with the path of its top edge over the last 3 seconds. With camera tracking on, the phone also moves through space. Drag to rotate the view.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(model.buttons.isEmpty ? "Buttons: none" : "Buttons: "+model.buttons.joined(separator:" · ")).font(.callout.monospaced())
                    Text(model.summary).font(.callout.monospacedDigit())
                }.frame(minWidth:380)
                VStack(spacing:8) {
                    ForEach(titles,id:\.self) { title in
                        Plot(title:title,points:model.plots[title] ?? [],marks:title == "Packet gap (ms)" ? model.lostTimes : [])
                    }
                }.frame(minWidth:520)
            }
            Text("Shows this phone's Wi-Fi stream and can run next to Dolphin. Red lines mark lost packets. Start MotionRemote on the iPhone and press Connect there first.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(16).frame(minWidth:960,minHeight:640)
    }
}

struct Plot: View {
    let title: String
    let points: [PlotPoint]
    let marks: [Double]
    var body: some View {
        VStack(alignment:.leading,spacing:2) {
            Text(title).font(.caption.bold())
            Chart {
                ForEach(points) { p in
                    LineMark(x:.value("Seconds",p.time),y:.value(title,p.value)).foregroundStyle(by:.value("Axis",p.series))
                }
                ForEach(marks,id:\.self) { RuleMark(x:.value("Seconds",$0)).foregroundStyle(.red.opacity(0.6)) }
            }
            .chartXScale(domain:-MonitorModel.window...0)
            .chartLegend(position:.trailing)
        }
    }
}

struct PhoneScene: NSViewRepresentable {
    let scene: MonitorScene
    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = scene.scene
        view.backgroundColor = NSColor(red:0.055,green:0.075,blue:0.11,alpha:1)
        view.autoenablesDefaultLighting = true
        view.allowsCameraControl = true
        view.antialiasingMode = .multisampling4X
        view.pointOfView = scene.camera
        view.setAccessibilityLabel("3D view of the phone orientation and motion path")
        return view
    }
    func updateNSView(_ view: SCNView, context: Context) {}
}
