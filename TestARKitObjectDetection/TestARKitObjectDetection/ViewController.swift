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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    var phaseEngine: PHASEEngine!
    var phaseListener: PHASEListener!
    var soundEvents: [String : PHASESoundEvent] = [:]
    var sources: [String: PHASESource] = [:]
    
    let anchorFileMapping = Dictionary(uniqueKeysWithValues: [
        ("serres_parasite", "guitar"),
        ("douglas_purity_danger", "drone"),
        ("morton_being_ecological", "piano")
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = selfg
        sceneView.showsStatistics = true
        
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
        PHASEDistanceModelFadeOutParameters(cullDistance: 10.0)
        distanceModelParameters.rolloffFactor = 0.25
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
        print("********* POS: \(transform.columns.3)")
        source.transform = transform
        let soundEvent = soundEvents[name]!
        soundEvent.start()
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        print("********* CAMERA: \(transform.columns.3)")
        phaseListener.transform = transform
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
}
