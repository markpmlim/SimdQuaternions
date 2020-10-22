/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation of iOS view controller that demonstrates differetent quaternion use cases.
*/

#if os(iOS)
import UIKit
typealias PlatformViewController = UIViewController
typealias PlatformToolbar = UIToolbar
typealias PlatformBarItem = UIBarButtonItem
typealias PlatformSegmentedControl = UISegmentedControl
typealias PlatformDisplayLink = CADisplayLink
#else
import AppKit
typealias PlatformViewController = NSViewController
typealias PlatformToolbar = NSToolbar
typealias PlatformBarItem = NSToolbarItem
typealias PlatformSegmentedControl = NSSegmentedControl
typealias PlatformDisplayLink = CVDisplayLink
#endif
import simd
import SceneKit

public extension Float {
    static func random(min: Float, max: Float) -> Float {
    #if os(iOS)
        let r32 = Float(arc4random()) / Float(UInt32.max)
    #else
        let r32 = Float(arc4random_uniform(UInt32.max)) / Float(UInt32.max)
    #endif
        return (r32 * (max - min)) + min
    }
}

class ViewController: PlatformViewController {

    enum DemoMode: String {
        case simpleRotation = "Simple"
        case compositeRotation = "Composite"
        case sphericalInterpolate = "Spherical"
        case splineInterpolate = "Spline"
        case splineRotationIn3D = "Cube: spline"
        case slerpRotationIn3D = "Cube: slerp"
    }

#if os(macOS)
    var displayLink: PlatformDisplayLink?
    var displaySource: DispatchSource!
    var currentTime = CVTimeStamp()
#endif

    var mode: DemoMode = .simpleRotation {
        didSet {
            switchDemo()
        }
    }

    @IBOutlet var sceneKitView: SCNView!
#if os(iOS)
    @IBOutlet var toolbar: PlatformToolbar!
#endif

    let defaultColor = PlatformColor.orange

    // The UI for the macOS version is instantiated in IB.
#if os(iOS)
    let modeSegmentedControlItem: PlatformBarItem = {
        let segmentedControl = PlatformSegmentedControl(items: [
            DemoMode.simpleRotation.rawValue,
            DemoMode.compositeRotation.rawValue,
            DemoMode.sphericalInterpolate.rawValue,
            DemoMode.splineInterpolate.rawValue,
            DemoMode.slerpRotationIn3D.rawValue,
            DemoMode.splineRotationIn3D.rawValue])

        segmentedControl.selectedSegmentIndex = 0

        segmentedControl.addTarget(self,
                                   action: #selector(modeSegmentedControlChangeHandler),
                                   for: .valueChanged)

        return PlatformBarItem(customView: segmentedControl)
    }()
#endif

    lazy var scene = setupSceneKit()

    override func viewDidLoad() {
        super.viewDidLoad()
    #if os(iOS)
        toolbar.setItems([modeSegmentedControlItem,
                          PlatformBarItem(barButtonSystemItem: .flexibleSpace,
                                          target: nil,
                                          action: nil),
                          PlatformBarItem(barButtonSystemItem: .play,
                                          target: self,
                                          action: #selector(runButtonTouchHandler))],
                         animated: false)
    #endif
        switchDemo()
    }


#if os(macOS)
    override func viewDidDisappear() {
        stopDisplayLink()
    }

    func newFrame(target: Any,
                  action handler: Selector) {
        let object = target as! ViewController
        // All NSObjects conform to the protocol NSObjectProtocol
        if object.responds(to: handler) {
            //let methodName = NSStringFromSelector(handler)
            perform(handler, with: displayLink)
        }
    }
    
    func setupDisplayLink(action actionHandler: Selector) {
         if self.displayLink != nil {
            stopDisplayLink()
        }
        let queue = DispatchQueue.main
        displaySource = DispatchSource.makeUserDataAddSource(queue: queue) as? DispatchSource
        displaySource.setEventHandler {
            self.newFrame(target: self,
                          action: actionHandler)
        }
        displaySource.resume()

        var cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        cvReturn = CVDisplayLinkSetCurrentCGDisplay(displayLink!, CGMainDisplayID())
        cvReturn = CVDisplayLinkSetOutputCallback(displayLink!, {
            (timer: CVDisplayLink, inNow: UnsafePointer<CVTimeStamp>, inOutputTime: UnsafePointer<CVTimeStamp>, flagsIn: CVOptionFlags, flagsOut: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer?) ->
            CVReturn in
            let sourceUnmanaged = Unmanaged<DispatchSourceUserDataAdd>.fromOpaque(displayLinkContext!)
            sourceUnmanaged.takeUnretainedValue().add(data: 1)
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(displaySource).toOpaque())

        CVDisplayLinkStart(displayLink!)
    }

    // This method will stop the currently active display link
    func stopDisplayLink() {
        if self.displayLink != nil {
            CVDisplayLinkStop(self.displayLink!)
            // Don't evoke the display source's event handler.
            displaySource.cancel()
            // Releases the CVDisplayLink object
            self.displayLink = nil
            /*
             if isRunning {
                 let winController = self.view.window?.windowController as! WindowController
                 let playStopButton = winController.playStopButton!
                 playStopButton.label = "Play"
                 playStopButton.image = NSImage(named: .slideshowTemplate)
             }
             */
        }
    }
#endif

    func switchDemo() {
        scene = setupSceneKit()
        isRunning = false
    #if os(iOS)
        displaylink?.invalidate()
    #endif
        switch mode {
        case .simpleRotation:
            simpleRotation()
        case .compositeRotation:
            compositeRotation()
        case .sphericalInterpolate:
            sphericalInterpolate()
        case .splineInterpolate:
            splineInterpolate()
        case .splineRotationIn3D:
            vertexRotation(useSpline: true)
        case .slerpRotationIn3D:
            vertexRotation(useSpline: false)
        }
    }

    // Also called by macOS version (WindowController method runButtonHandler)
    @objc
    func runButtonTouchHandler() {
        switchDemo()
        isRunning = true
    }

#if os(iOS)
    @objc
    func modeSegmentedControlChangeHandler(segmentedControl: PlatformSegmentedControl) {
        guard let newModeName = segmentedControl.titleForSegment(at: segmentedControl.selectedSegmentIndex),
              let newMode = DemoMode(rawValue: newModeName)
        else {
            return
        }
        mode = newMode
    }

#else
    // macOS
    @objc
    func modeSegmentedControlChangeHandler(segmentedControl: PlatformSegmentedControl) {
        let index = segmentedControl.indexOfSelectedItem
        if index != -1 {
            let newModeName = segmentedControl.label(forSegment: index)
            let newMode = DemoMode(rawValue: newModeName!)
            mode = newMode!
        }
        else {
            return
        }
    }
#endif

    var isRunning: Bool = false {
        didSet {
        #if os(iOS)
            toolbar.isUserInteractionEnabled = !isRunning
            toolbar.alpha = isRunning ? 0.5 : 1
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.5

            SCNTransaction.commit()
        #endif
        }
    }

#if os(iOS)
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func preferredScreenEdgesDeferringSystemGestures() -> UIRectEdge {
         return .bottom
    }

    // MARK: Demos
    var displaylink: PlatformDisplayLink?
#endif


    // MARK: Simple Rotation Demo

    var angle: Float = 0
    // Unit vector from origin to the surface of the sphere along the +z axis.
    let originVector = simd_float3(0, 0, 1)
    var previousSphere: SCNNode?

    func simpleRotation() {
        addMainSphere(scene: scene)

        angle = 0
        previousSphere = nil

        // Since the big sphere's radius is 1.0 and "originVector" is a normalized vector,
        // the (little) red dot appears to be on the surface of the big sphere.
        addSphereAt(position: originVector,
                    radius: 0.04,
                    color: .red,
                    scene: scene)
    #if os(iOS)
        displaylink = PlatformDisplayLink(target: self,
                                          selector: #selector(simpleRotationStep))

        displaylink?.add(to: .current,
                         forMode: .defaultRunLoopMode)
    #else
        setupDisplayLink(action: #selector(ViewController.simpleRotationStep))
    #endif
    }

    @objc
    func simpleRotationStep(displaylink: PlatformDisplayLink) {
        guard isRunning
        else {
            return
        }

        // On the first run, "previousSphere" is nil.
        previousSphere?.removeFromParentNode()
        angle -= 1.0

        // The axis of the quaternion below is already normalized.
        let quaternion = simd_quatf(angle: degreesToRadians(angle),
                                    axis: simd_float3(x: 1, y: 0, z: 0))

        // Note: "quaternion" must be a unit quaternion.
        let rotatedVector = quaternion.act(originVector)

        previousSphere = addSphereAt(position: rotatedVector,
                                     radius: 0.04,
                                     color: defaultColor,
                                     scene: scene)

        if angle < -60 {
        #if os(iOS)
            displaylink.invalidate()
        #else
            stopDisplayLink()
        #endif
            isRunning = false
        }
    }

    // MARK: Composite Rotation Demo

    // `previousSphereA` and `previousSphereB` show component quaternions
    var previousSphereA: SCNNode?
    var previousSphereB: SCNNode?

    func compositeRotation() {
        addMainSphere(scene: scene)

        angle = 0
        previousSphere = nil
        previousSphereA = nil
        previousSphereB = nil

        addSphereAt(position: originVector,
                    radius: 0.04,
                    color: .red,
                    scene: scene)
    #if os(iOS)
        displaylink = PlatformDisplayLink(target: self,
                                          selector: #selector(compositeRotationStep))

        displaylink?.add(to: .current,
                         forMode: .defaultRunLoopMode)
    #else
        setupDisplayLink(action: #selector(ViewController.compositeRotationStep))
    #endif
    }

    @objc
    func compositeRotationStep(displaylink: PlatformDisplayLink) {
        guard isRunning
        else {
            return
        }

        previousSphere?.removeFromParentNode()
        previousSphereA?.removeFromParentNode()
        previousSphereB?.removeFromParentNode()

        angle -= 1

        // Observation: if the axis is a normalized vector, then the quat is a unit quaternion.
        let quaternionA = simd_quatf(angle: degreesToRadians(angle),
                                     axis: simd_float3(x: 1, y: 0, z: 0))

        let quaternionB = simd_quatf(angle: degreesToRadians(angle),
                                     axis: simd_normalize(simd_float3(x: 0, y: -0.75, z: -0.5)))

        let rotatedVectorA = quaternionA.act(originVector)
        previousSphereA = addSphereAt(position: rotatedVectorA,
                                      radius: 0.02,
                                      color: .green,
                                      scene: scene)

        let rotatedVectorB = quaternionB.act(originVector)
        previousSphereB = addSphereAt(position: rotatedVectorB,
                                      radius: 0.02,
                                      color: .red,
                                      scene: scene)

        let quaternion = quaternionA * quaternionB

        // "quaternion" is a unit quaternion
        let rotatedVector = quaternion.act(originVector)

        previousSphere = addSphereAt(position: rotatedVector,
                                     radius: 0.04,
                                     color: defaultColor,
                                     scene: scene)

        if angle <= -360 {
        // All 3 spheres will converge at the same (starting) point
        #if os(iOS)
            displaylink.invalidate()
        #else
            stopDisplayLink()
        #endif
            isRunning = false
        }
    }

    // MARK: Spherical Interpolate Demo

    var sphericalInterpolateTime: Float = 0

    // Unit vector from origin to the surface of the sphere along the +z axis.
    let origin = simd_float3(0, 0, 1)

    // The axis of q0 is already normalized so it is a unit quaternion.
    let q0 = simd_quatf(angle: .pi / 6,
                        axis: simd_float3(x: 0, y: -1, z: 0))

    // Normalizing the axis will produce a unit quaternion.
    let q1 = simd_quatf(angle: .pi / 6,
                        axis: simd_normalize(simd_float3(x: -1, y: 1, z: 0)))

    let q2 = simd_quatf(angle: .pi / 20,
                        axis: simd_normalize(simd_float3(x: 1, y: 0, z: -1)))

    func sphericalInterpolate() {
        addMainSphere(scene: scene)

        sphericalInterpolateTime = 0

        // q0, q1, q2 are unit quaternions
        let u0 = simd_act(q0, origin)
        let u1 = simd_act(q1, origin)
        let u2 = simd_act(q2, origin)
        for u in [u0, u1, u2] {
            addSphereAt(position: u,
                        radius: 0.04,
                        color: defaultColor,
                        scene: scene)
        }
    #if os(iOS)
        displaylink = PlatformDisplayLink(target: self,
                                          selector: #selector(sphericalInterpolateStep))

        displaylink?.add(to: .current,
                         forMode: .defaultRunLoopMode)
    #else
        setupDisplayLink(action: #selector(ViewController.sphericalInterpolateStep))
   #endif
        previousShortestInterpolationPoint = nil
        previousLongestInterpolationPoint = nil
    }

    // On first run, these 2 points are nil.
    var previousShortestInterpolationPoint: simd_float3?
    var previousLongestInterpolationPoint: simd_float3?

    @objc
    func sphericalInterpolateStep(displaylink: PlatformDisplayLink) {
        guard isRunning
        else {
            return
        }

        let increment: Float = 0.005
        sphericalInterpolateTime += increment

        // simd_slerp
        do {
            // interpolate the shortest arc btwn q0 & q1
            let q = simd_slerp(q0, q1, sphericalInterpolateTime)
            let interpolationPoint = simd_act(q, origin)
            if let previousShortestInterpolationPoint = previousShortestInterpolationPoint {
                addLineBetweenVertices(vertexA: previousShortestInterpolationPoint,
                                       vertexB: interpolationPoint,
                                       inScene: scene)
            }
            previousShortestInterpolationPoint = interpolationPoint
        }

        // simd_slerp_longest
        do {
            for t in [sphericalInterpolateTime, sphericalInterpolateTime + increment * 0.5] {
                let q = simd_slerp_longest(q1, q2, t)
                let interpolationPoint = simd_act(q, origin)
                if let previousLongestInterpolationPoint = previousLongestInterpolationPoint {
                    addLineBetweenVertices(vertexA: previousLongestInterpolationPoint,
                                           vertexB: interpolationPoint,
                                           inScene: scene)
                }
                previousLongestInterpolationPoint = interpolationPoint
            }
        }

        if !(sphericalInterpolateTime < 1) {
        #if os(iOS)
            displaylink.invalidate()
        #else
            stopDisplayLink()
        #endif
            isRunning = false
        }
    }

    // MARK: Spline Interpolate Demo

    var splineInterpolateTime: Float = 0
    // All rotations represented by unit quaternions.
    var rotations = [simd_quatf]()
    var markers = [SCNNode]()

    var index = 0 {
        didSet {
            if !markers.isEmpty {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                if oldValue < markers.count {
                    markers[oldValue].geometry?.firstMaterial?.diffuse.contents = defaultColor
                }
                if index < markers.count {
                    markers[index].geometry?.firstMaterial?.diffuse.contents = PlatformColor.yellow
                }
                SCNTransaction.commit()
            }
        }
    }

    func splineInterpolate() {
        rotations.removeAll()

        // Unit vector from origin to the surface of the big sphere along the +z axis.
        let origin = simd_float3(0, 0, 1)
        let q_origin = simd_quatf(angle: 0,
                                  axis: simd_float3(x: 1, y: 0, z: 0))

        rotations.append(q_origin)

        let markerCount = 12
        markers.removeAll()

        for i in 0 ... markerCount {
            // Range for angle: [0, π/6, π/3, ... 11π/6, 2π]
            let angle = (.pi * 2) / Float(markerCount) * Float(i)
            let latitudeRotation = simd_quatf(angle: (angle - .pi / 2) * 0.3,
                                              axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0)))
            var dir: Float = 0.0
            if i % 2 == 0 {
                dir =  -1.0
            }
            else {
                dir = 1.0
            }
            let rnd = Float.random(min: 0.0, max: 0.25)
            let longitudeRotation = simd_quatf(angle: .pi / 4 *  rnd * dir,
                                               axis: simd_normalize(simd_float3(x: 1, y: 0, z: 0)))

            let q = latitudeRotation * longitudeRotation

            let u = simd_act(q, origin)

            rotations.append(q)

            // There are 12 markers and therefore 12 tiny spheres.
            if  i != markerCount {
                markers.append(addSphereAt(position: u,
                                           radius: 0.01,
                                           color: defaultColor,
                                           scene: scene))
            }
        } // for
        addMainSphere(scene: scene)

        splineInterpolateTime = 0
        // The 2nd spherical marker is yellow in colour.
        // The value of index = 1 before the method splineInterpolateStep: is called.
        index = 1
    #if os(iOS)
        displaylink = PlatformDisplayLink(target: self,
                                          selector: #selector(splineInterpolateStep))

        displaylink?.add(to: .current,
                         forMode: .defaultRunLoopMode)
    #else
        setupDisplayLink(action: #selector(ViewController.splineInterpolateStep))
    #endif
        previousSplinePoint = nil
    }

    var previousSplinePoint: simd_float3?

    @objc
    func splineInterpolateStep(displaylink: PlatformDisplayLink) {
        guard isRunning
        else {
            return
        }

        let increment: Float = 0.04
        splineInterpolateTime += increment

        // The "simd_spline" method requires 4 unit quaternions.
        // The spline is made up of 14 quaternions with rotation[0] and rotation[13]
        // being the surrounding unit quaternions.
        let q = simd_spline(rotations[index - 1],       // before
                            rotations[index + 0],
                            rotations[index + 1],
                            rotations[index + 2],       // after
                            splineInterpolateTime)

        // Assumes q is a unit quaternion.
        let splinePoint = simd_act(q, origin)

        if let previousSplinePoint = previousSplinePoint {
            addLineBetweenVertices(vertexA: previousSplinePoint,
                                   vertexB: splinePoint,
                                   inScene: scene)
        }

        previousSplinePoint = splinePoint

        if !(splineInterpolateTime < 1) {
            index += 1
            splineInterpolateTime = 0

            if index > rotations.count - 3 {
            #if os(iOS)
                displaylink.invalidate()
            #else
                stopDisplayLink()
            #endif
                isRunning = false
            }
        }
    }

    // MARK: Rotating vertices in 3D

    /*
     spline interpolation requires a quaternion before the current value
     and a quaternion after the next value to compute the interpolated value.
    */
    let vertexRotations: [simd_quatf] = [
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),    // before
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),
        simd_quatf(angle: .pi * 0.05,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: .pi * 0.1,
                   axis: simd_normalize(simd_float3(x: 1, y: 0, z: -1))),
        simd_quatf(angle: .pi * 0.15,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: .pi * 0.2,
                   axis: simd_normalize(simd_float3(x: -1, y: 0, z: 1))),
        simd_quatf(angle: .pi * 0.15,
                   axis: simd_normalize(simd_float3(x: 0, y: -1, z: 0))),
        simd_quatf(angle: .pi * 0.1,
                   axis: simd_normalize(simd_float3(x: 1, y: 0, z: -1))),
        simd_quatf(angle: .pi * 0.05,
                   axis: simd_normalize(simd_float3(x: 0, y: 1, z: 0))),
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1))),
        simd_quatf(angle: 0,
                   axis: simd_normalize(simd_float3(x: 0, y: 0, z: 1)))     // after
    ]

    var vertexRotationUsesSpline = true
    var vertexRotationIndex = 0
    var vertexRotationTime: Float = 0
    var previousCube: SCNNode?
    var previousVertexMarker: SCNNode?

    // Initial position vectors of 8 corners of a unit cube.
    let cubeVertexOrigins: [simd_float3] = [
        simd_float3(x: -0.5, y: -0.5, z: 0.5),
        simd_float3(x: 0.5, y: -0.5, z: 0.5),
        simd_float3(x: -0.5, y: -0.5, z: -0.5),
        simd_float3(x: 0.5, y: -0.5, z: -0.5),
        simd_float3(x: -0.5, y: 0.5, z: 0.5),
        simd_float3(x: 0.5, y: 0.5, z: 0.5),
        simd_float3(x: -0.5, y: 0.5, z: -0.5),
        simd_float3(x: 0.5, y: 0.5, z: -0.5)
    ]

    // This set will be modified.
    lazy var cubeVertices = cubeVertexOrigins

    let sky = MDLSkyCubeTexture(name: "sky",
                                channelEncoding: MDLTextureChannelEncoding.float16,
                                textureDimensions: simd_int2(x: 128, y: 128),
                                turbidity: 0.5,
                                sunElevation: 0.5,
                                sunAzimuth: 0.5,
                                upperAtmosphereScattering: 0.5,
                                groundAlbedo: 0.5)

    func vertexRotation(useSpline: Bool) {
        scene.lightingEnvironment.contents = sky
        scene.rootNode.childNode(withName: "cameraNode",
                                 recursively: false)?.camera?.usesOrthographicProjection = false

        vertexRotationUsesSpline = useSpline

        vertexRotationTime = 0
        vertexRotationIndex = 1

        // Instantiate a cube with the initial set of positions and show it
        previousCube = addCube(vertices: cubeVertexOrigins,
                               inScene: scene)
    #if os(iOS)
        displaylink = PlatformDisplayLink(target: self,
                                          selector: #selector(vertexRotationStep))

        displaylink?.add(to: .current,
                         forMode: .defaultRunLoopMode)
    #else
        setupDisplayLink(action: #selector(ViewController.vertexRotationStep))
    #endif
    }

    // The method below is called per frame update
    @objc
    func vertexRotationStep(displaylink: PlatformDisplayLink) {
        guard isRunning
        else {
            return
        }

        previousCube?.removeFromParentNode()

        let increment: Float = 0.02
        vertexRotationTime += increment

        let q: simd_quatf
        if vertexRotationUsesSpline {
            q = simd_spline(vertexRotations[vertexRotationIndex - 1],       // before
                            vertexRotations[vertexRotationIndex + 0],
                            vertexRotations[vertexRotationIndex + 1],
                            vertexRotations[vertexRotationIndex + 2],       // after
                            vertexRotationTime)
        }
        else {
            q = simd_slerp(vertexRotations[vertexRotationIndex + 0],
                           vertexRotations[vertexRotationIndex + 1],
                           vertexRotationTime)
        }

        // Assume q is a unit quaternion.

        previousVertexMarker?.removeFromParentNode()
        // The corner whose initial position is (0.5, 0.5, 0.5)
        let vertex = cubeVertices[5]        // save a copy
        // Generate a new set of positions for the cube's vertices.
        cubeVertices = cubeVertexOrigins.map {
            return q.act($0)
        }

        previousVertexMarker = addSphereAt(position: cubeVertices[5], //vertex,
                                           radius: 0.01,
                                           color: .red,
                                           scene: scene)

        addLineBetweenVertices(vertexA: vertex,
                               vertexB: cubeVertices[5],
                               inScene: scene,
                               color: .white)

        previousCube = addCube(vertices: cubeVertices,
                               inScene: scene)

        if vertexRotationTime >= 1 {
            vertexRotationIndex += 1
            vertexRotationTime = 0

            if vertexRotationIndex > vertexRotations.count - 3 {
            #if os(iOS)
                displaylink.invalidate()
            #else
                stopDisplayLink()
            #endif
                isRunning = false
            }
        }
    }
}
