import AppKit
import SceneKit
import simd

final class MonitorScene {
    let scene = SCNScene()
    let camera = SCNNode()
    private let phone = SCNNode()
    private var path = SCNNode()
    init() {
        camera.camera = SCNCamera(); camera.camera?.zNear = 0.01
        camera.position = SCNVector3(1.9,1.3,3.3); camera.look(at:SCNVector3Zero)
        scene.rootNode.addChildNode(camera)
        let body = SCNNode(geometry:SCNBox(width:0.65,height:1.3,length:0.09,chamferRadius:0.06))
        body.geometry?.firstMaterial?.diffuse.contents = NSColor.systemGray
        let screen = SCNNode(geometry:SCNBox(width:0.56,height:1.13,length:0.012,chamferRadius:0.035))
        screen.position.z = 0.055; screen.geometry?.firstMaterial?.diffuse.contents = NSColor.systemBlue
        let notch = SCNNode(geometry:SCNCapsule(capRadius:0.025,height:0.18))
        notch.eulerAngles.z = .pi/2; notch.position = SCNVector3(0,0.49,0.07)
        notch.geometry?.firstMaterial?.diffuse.contents = NSColor.black
        for node in [body,screen,notch] { phone.addChildNode(node) }
        scene.rootNode.addChildNode(phone)
        let axes: [(SIMD3<Float>,NSColor,String)] = [(.init(1.6,0,0),.systemRed,"X"),(.init(0,1.6,0),.systemGreen,"Up"),(.init(0,0,1.6),.systemBlue,"Z")]
        for (end,color,name) in axes {
            scene.rootNode.addChildNode(Self.line([.init(repeating:0),end],color:color))
            let text = SCNText(string:name,extrusionDepth:0); text.font = .systemFont(ofSize:0.15)
            text.firstMaterial?.diffuse.contents = color
            let label = SCNNode(geometry:text); label.simdPosition = end
            label.constraints = [SCNBillboardConstraint()]; scene.rootNode.addChildNode(label)
        }
    }
    func update(rotation: simd_quatf, position: SIMD3<Float>, trail: [SIMD3<Float>]) {
        SCNTransaction.begin(); SCNTransaction.animationDuration = 0
        phone.simdOrientation = rotation; phone.simdPosition = position
        path.removeFromParentNode()
        path = Self.line(trail,color:NSColor.systemCyan.withAlphaComponent(0.8)); scene.rootNode.addChildNode(path)
        SCNTransaction.commit()
    }
    static func line(_ points: [SIMD3<Float>], color: NSColor) -> SCNNode {
        guard points.count > 1 else { return SCNNode() }
        let indices = (0..<(points.count-1)).flatMap { [UInt32($0),UInt32($0+1)] }
        let geometry = SCNGeometry(sources:[SCNGeometrySource(vertices:points.map { SCNVector3($0) })],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)])
        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.lightingModel = .constant
        return SCNNode(geometry:geometry)
    }
}
