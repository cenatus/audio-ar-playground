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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.showsStatistics = true
        
        hmm.delegate = self
        guard hmm.isDeviceMotionAvailable else {
            fatalError("Sorry, your device is not supported.")
        }
        hmm.startDeviceMotionUpdates(to: OperationQueue.current!, withHandler: {[weak self] motion, error  in
             guard let motion = motion, error == nil else { return }
             self?.handleHeadMovement(motion)
         })
        
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
        PHASEDistanceModelFadeOutParameters(cullDistance: 5.0)
        distanceModelParameters.rolloffFactor = 2.0
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
            
            let mesh = MDLMesh.newIcosahedron(withRadius: 00.0142, inwardNormals: false, allocator: nil)
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "Anchors", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        configuration.detectionObjects = referenceObjects
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        phaseEngine.stop()
    }

    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let name = anchor.name!
        print("********* SEEN ANCHOR \(name)")
        let source = sources[name]!
        let transform = anchor.transform
        source.transform = transform
        let soundEvent = soundEvents[name]!
        soundEvent.start()
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
