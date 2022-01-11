//
//  ViewController.swift
//  TestARKitObjectDetection
//
//  Created by Tim on 15/12/21.
//

import UIKit
import SceneKit
import ARKit
import PHASE
import CoreMotion

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, CMHeadphoneMotionManagerDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    
    var phaseEngine: PHASEEngine!
    var phaseListener: PHASEListener!
    var soundEvents: [String : PHASESoundEvent] = [:]
    var sources: [String: PHASESource] = [:]
    var headphoneTransform: simd_float4x4 = matrix_identity_float4x4;
    let hmm = CMHeadphoneMotionManager()
    let anchorFileMapping = Dictionary(uniqueKeysWithValues: [
        ("serres_parasite", "guitar"),
        ("douglas_purity_danger", "drone"),
        ("morton_being_ecological", "piano")
    ])
    
    let innerMaterial = SCNMaterial()
    
    
    let outerMaterial = SCNMaterial()
   
    
    let DEFAULT_RADIUS : Float = 0.0142
    let DEFAULT_CULL_DISTANCE : Double = 5.0
    let DEFAULT_ROLLOFF_FACTOR : Double = 2.0
    
    func setupMaterials() {
        innerMaterial.isDoubleSided = true
        innerMaterial.diffuse.contents = UIColor.systemYellow
        innerMaterial.fillMode = .lines
        
        outerMaterial.isDoubleSided = true
        outerMaterial.diffuse.contents = UIColor.systemBlue
        outerMaterial.fillMode = .lines
    }
    
    func setupSceneView() {
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        sceneView.autoenablesDefaultLighting = true
    }
    
    func setupHMM() {
        hmm.delegate = self
        guard hmm.isDeviceMotionAvailable else {
            fatalError("Sorry, your device is not supported.")
        }
        hmm.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {[weak self] motion, error  in
             guard let motion = motion, error == nil else { return }
             self?.handleHeadMovement(motion)
         })
    }
    
    func setupPhase() {
        phaseEngine = PHASEEngine(updateMode: .automatic)
        phaseListener = PHASEListener(engine: phaseEngine)
        phaseListener.transform = matrix_identity_float4x4
        try! phaseEngine.rootObject.addChild(phaseListener)
        
        let spatialPipelineFlags : PHASESpatialPipeline.Flags = [.directPathTransmission, .lateReverb]
        let spatialPipeline = PHASESpatialPipeline(flags: spatialPipelineFlags)!
        spatialPipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.1;
        phaseEngine.defaultReverbPreset = .mediumRoom
        
        let spatialMixerDefinition = PHASESpatialMixerDefinition(spatialPipeline: spatialPipeline)
        
        let distanceModelParameters = PHASEGeometricSpreadingDistanceModelParameters()
        distanceModelParameters.fadeOutParameters =
        PHASEDistanceModelFadeOutParameters(cullDistance: DEFAULT_CULL_DISTANCE)
        distanceModelParameters.rolloffFactor = DEFAULT_ROLLOFF_FACTOR
        spatialMixerDefinition.distanceModelParameters = distanceModelParameters
        
        
        for (anchorName, fileName) in anchorFileMapping {
            let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")!
            try! phaseEngine.assetRegistry.registerSoundAsset(
                url: url, identifier: fileName, assetType: .resident,
                channelLayout: nil, normalizationMode: .dynamic
            )
            
            let samplerNodeDefinition = PHASESamplerNodeDefinition(
                soundAssetIdentifier: fileName, mixerDefinition: spatialMixerDefinition
            )
            samplerNodeDefinition.playbackMode = .looping
            samplerNodeDefinition.setCalibrationMode(calibrationMode: .relativeSpl, level: 12)
            samplerNodeDefinition.cullOption = .sleepWakeAtRealtimeOffset
            try! phaseEngine.assetRegistry.registerSoundEventAsset(rootNode:samplerNodeDefinition, identifier: anchorName)
            
            let mesh = MDLMesh.newIcosahedron(withRadius: DEFAULT_RADIUS, inwardNormals: false, allocator: nil)
            let shape = PHASEShape(engine: phaseEngine, mesh: mesh)
            let source = PHASESource(engine: phaseEngine, shapes: [shape])
            sources[anchorName] = source
            try! phaseEngine.rootObject.addChild(source)
            
            let mixerParameters = PHASEMixerParameters()
            mixerParameters.addSpatialMixerParameters(
                identifier: spatialMixerDefinition.identifier,
                source: source, listener: phaseListener
            )
    
            let soundEvent = try! PHASESoundEvent(
                engine: phaseEngine, assetIdentifier: anchorName,
                mixerParameters: mixerParameters
            )
            
            soundEvents[anchorName] = soundEvent
        }
        try! phaseEngine.start()
    }
    
    func setupTracking() {
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "Anchors", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        configuration.detectionObjects = referenceObjects
        sceneView.session.run(configuration)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMaterials()
        setupSceneView()
        setupHMM()
        setupPhase()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        phaseEngine.stop()
    }

    // MARK: - ARSCNViewDelegate
    
    func displaySourceSpheres(transform: float4x4, inner_radius: Float, outer_radius: Float) {
        let innerSphereGeometry = SCNSphere(radius: CGFloat(inner_radius))
        innerSphereGeometry.isGeodesic = true
        innerSphereGeometry.segmentCount = 48
        
        let outerSphereGeometry = SCNSphere(radius: CGFloat(outer_radius))
        outerSphereGeometry.isGeodesic = true
        outerSphereGeometry.segmentCount = 48
        
        innerSphereGeometry.firstMaterial = innerMaterial
        outerSphereGeometry.firstMaterial = outerMaterial
        
        let innerSphereNode = SCNNode(geometry: innerSphereGeometry)
        let outerSphereNode = SCNNode(geometry: outerSphereGeometry)
        
        innerSphereNode.transform = SCNMatrix4(transform)
        outerSphereNode.transform = SCNMatrix4(transform)
        
        sceneView.scene.rootNode.addChildNode(innerSphereNode)
        sceneView.scene.rootNode.addChildNode(outerSphereNode)
    }
    
    func playAudioSource(name: String, transform: float4x4) {
        let source = sources[name]!
        source.transform = transform
        let soundEvent = soundEvents[name]!
        soundEvent.start()
    }
    
    // Override to create and configure nodes for anchors added to the view's session.
    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let name = anchor.name!
        let transform = anchor.transform
        
        print("********* SEEN ANCHOR \(name)")
        
        displaySourceSpheres(transform: transform, inner_radius: DEFAULT_RADIUS, outer_radius: Float(DEFAULT_CULL_DISTANCE))
        
        playAudioSource(name: name, transform: transform)
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        phaseListener.transform = transform * headphoneTransform
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func handleHeadMovement(_ motion: CMDeviceMotion) {
        let m = motion.attitude.rotationMatrix
        let x = SIMD4(Float(m.m11), Float(m.m21), Float(m.m31), 0)
        let y = SIMD4(Float(m.m12), Float(m.m22), Float(m.m32), 0)
        let z = SIMD4(Float(m.m13), Float(m.m23), Float(m.m33), 0)
        let w = SIMD4(Float(0), Float(0), Float(0), Float(1))
        headphoneTransform = simd_float4x4(columns: (x, y, z, w))
    }
}
