import AppKit
import SceneKit
import simd

final class SaberScene {
    let scene = SCNScene()
    let camera = SCNNode()
    private let sword = SCNNode()
    private let blade = SCNNode()
    private var blocks: [Int:SCNNode] = [:]
    private lazy var arrow = Self.image(arrow:true)
    private lazy var dot = Self.image(arrow:false)
    init() {
        scene.background.contents = NSColor(red:0.02,green:0.02,blue:0.05,alpha:1)
        scene.fogStartDistance = 10; scene.fogEndDistance = 26; scene.fogColor = NSColor(red:0.02,green:0.02,blue:0.06,alpha:1)
        camera.camera = SCNCamera()
        camera.camera?.projectionDirection = .vertical; camera.camera?.fieldOfView = CGFloat(GameView.fieldOfView); camera.camera?.zNear = 0.05; camera.camera?.zFar = 60
        camera.camera?.wantsHDR = true; camera.camera?.wantsExposureAdaptation = false; camera.camera?.bloomIntensity = 1.4; camera.camera?.bloomThreshold = 0.5; camera.camera?.bloomBlurRadius = 10
        camera.simdPosition = GameView.eye; camera.simdLook(at:GameView.target)
        scene.rootNode.addChildNode(camera)
        let ambient = SCNNode(); ambient.light = SCNLight(); ambient.light?.type = .ambient; ambient.light?.intensity = 300
        let key = SCNNode(); key.light = SCNLight(); key.light?.type = .directional; key.light?.intensity = 700; key.eulerAngles = SCNVector3(-0.8,0.3,0)
        scene.rootNode.addChildNode(ambient); scene.rootNode.addChildNode(key)
        let floor = SCNNode(geometry:SCNBox(width:2.2,height:0.02,length:40,chamferRadius:0))
        floor.geometry?.firstMaterial?.diffuse.contents = NSColor(red:0.05,green:0.05,blue:0.09,alpha:1)
        floor.position = SCNVector3(0,0,-18); scene.rootNode.addChildNode(floor)
        for (i,x) in [-1.08,-0.42,0,0.42,1.08].enumerated() {
            let edge = i == 0 || i == 4
            let line = SCNNode(geometry:SCNBox(width:edge ? 0.03 : 0.01,height:0.012,length:40,chamferRadius:0))
            line.geometry?.firstMaterial?.emission.contents = edge ? NSColor(red:0.9,green:0.1,blue:0.25,alpha:1) : NSColor(white:0.25,alpha:1)
            line.position = SCNVector3(x,0.016,-18); scene.rootNode.addChildNode(line)
        }
        // Cut plane guide: a faint frame where blocks must be hit.
        let frame = SCNNode(geometry:SCNBox(width:1.8,height:0.006,length:0.006,chamferRadius:0))
        frame.geometry?.firstMaterial?.emission.contents = NSColor(white:0.35,alpha:1)
        frame.position = SCNVector3(0,0.56,0); scene.rootNode.addChildNode(frame)
        let grip = SCNNode(geometry:SCNCylinder(radius:0.035,height:0.2))
        grip.geometry?.firstMaterial?.diffuse.contents = NSColor(white:0.15,alpha:1); grip.position.y = -0.1
        blade.geometry = SCNCylinder(radius:0.02,height:CGFloat(SaberGame.bladeLength))
        blade.geometry?.firstMaterial?.emission.contents = NSColor(red:0.2,green:0.75,blue:1,alpha:1)
        blade.geometry?.firstMaterial?.diffuse.contents = NSColor.black
        blade.position.y = CGFloat(SaberGame.bladeLength/2)
        sword.addChildNode(grip); sword.addChildNode(blade); scene.rootNode.addChildNode(sword)
    }
    func update(time: Double, game: SaberGame, sword pose: Sword, tracked: Bool) {
        SCNTransaction.begin(); SCNTransaction.disableActions = true
        sword.simdPosition = pose.hilt
        let direction = simd_normalize(pose.tip-pose.hilt)
        sword.simdOrientation = simd_quatf(from:SIMD3(0,1,0),to:direction)
        sword.opacity = tracked ? 1 : 0.35
        for note in game.notes {
            if SaberGame.visible(note,at:time) {
                let node = blocks[note.id] ?? makeBlock(note)
                node.simdPosition = SaberGame.position(note,at:time)
            } else if note.result == nil, let node = blocks.removeValue(forKey:note.id) { node.removeFromParentNode() }
        }
        SCNTransaction.commit()
    }
    func cut(_ note: Note, good: Bool, normal: SIMD3<Float>) {
        guard let node = blocks.removeValue(forKey:note.id) else { return }
        let center = node.simdPosition; node.removeFromParentNode()
        for side: Float in [-1,1] {
            let half = SCNNode(geometry:SCNBox(width:0.3,height:0.15,length:0.3,chamferRadius:0.03))
            half.geometry?.firstMaterial?.emission.contents = good ? NSColor(red:0.95,green:0.15,blue:0.25,alpha:1) : NSColor(white:0.4,alpha:1)
            half.simdPosition = center+normal*side*0.08
            half.simdOrientation = simd_quatf(from:SIMD3(0,1,0),to:normal)
            scene.rootNode.addChildNode(half)
            let push = normal*side*0.7+SIMD3(0,-0.2,1.2)
            half.runAction(.sequence([.group([.move(by:SCNVector3(push),duration:0.45),.rotateBy(x:CGFloat(side)*2,y:0,z:1,duration:0.45),.fadeOut(duration:0.45)]),.removeFromParentNode()]))
        }
    }
    func miss(_ note: Note) {
        guard let node = blocks.removeValue(forKey:note.id) else { return }
        node.runAction(.sequence([.fadeOut(duration:0.25),.removeFromParentNode()]))
    }
    func reset() { for node in blocks.values { node.removeFromParentNode() }; blocks = [:] }
    private func makeBlock(_ note: Note) -> SCNNode {
        let node = SCNNode(geometry:SCNBox(width:0.3,height:0.3,length:0.3,chamferRadius:0.04))
        node.geometry?.firstMaterial?.diffuse.contents = NSColor(red:0.55,green:0.04,blue:0.1,alpha:1)
        node.geometry?.firstMaterial?.emission.contents = NSColor(red:0.35,green:0.02,blue:0.06,alpha:1)
        let face = SCNNode(geometry:SCNPlane(width:0.24,height:0.24))
        face.geometry?.firstMaterial?.diffuse.contents = note.direction == nil ? dot : arrow
        face.geometry?.firstMaterial?.emission.contents = note.direction == nil ? dot : arrow
        face.geometry?.firstMaterial?.isDoubleSided = true
        face.position.z = 0.152
        // The texture arrow points up; turn it to the required cut direction.
        face.eulerAngles.z = CGFloat([0,Float.pi,Float.pi/2,-Float.pi/2][note.direction?.rawValue ?? 0])
        node.addChildNode(face)
        scene.rootNode.addChildNode(node); blocks[note.id] = node
        return node
    }
    private static func image(arrow: Bool) -> NSImage {
        NSImage(size:NSSize(width:128,height:128),flipped:false) { _ in
            NSColor.white.setFill()
            if arrow {
                let path = NSBezierPath()
                path.move(to:NSPoint(x:20,y:44)); path.line(to:NSPoint(x:64,y:100)); path.line(to:NSPoint(x:108,y:44)); path.close()
                path.fill()
            } else { NSBezierPath(ovalIn:NSRect(x:44,y:44,width:40,height:40)).fill() }
            return true
        }
    }
}
