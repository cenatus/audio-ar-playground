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
    
    let PLAYER_CONFIG_FILE_NAME = "sounds"
    
    var phasePlayer : PHASEPlayer!
    var debugRenderer : PHASEPlayerDebugRenderer!
    
    let hmm = CMHeadphoneMotionManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupHMM()
        setupPhase()
        setupDebugRenderer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setupTracking()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
        phasePlayer.teardown()
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
    
    func setupTracking() {
        let configuration = ARWorldTrackingConfiguration()
        guard let referenceObjects = ARReferenceObject.referenceObjects(inGroupNamed: "Anchors", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        }
        configuration.detectionObjects = referenceObjects
        sceneView.session.run(configuration)
    }
    
    func setupPhase() {
        phasePlayer = PHASEPlayer(PLAYER_CONFIG_FILE_NAME)
        phasePlayer.setup()
    }
    
    func setupDebugRenderer() {
        debugRenderer = PHASEPlayerDebugRenderer(sceneView.scene)
    }
    
    // MARK: - ARSCNViewDelegate
        
    // Override to create and configure nodes for anchors added to the view's session.
    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let name = anchor.name!
        let transform = anchor.transform
        
        print("********* SEEN ANCHOR \(name)")
        
        let sound = phasePlayer.playSampleAtPosition(sample: name, position: transform)
        debugRenderer.displaySoundSource(sound)
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let transform = frame.camera.transform
        phasePlayer.devicePosition = transform
    }
    
    // MARK: - CMHeadphoneMotionManagerDelegate
    
    func handleHeadMovement(_ motion: CMDeviceMotion) {
        let transform = motion.attitude.rotationMatrix.toFloat4x4()
        phasePlayer.headPosition = transform
    }
}

extension CMRotationMatrix {
    func toFloat4x4() -> float4x4 {
        let m = self
        let x = SIMD4(Float(m.m11), Float(m.m21), Float(m.m31), 0)
        let y = SIMD4(Float(m.m12), Float(m.m22), Float(m.m32), 0)
        let z = SIMD4(Float(m.m13), Float(m.m23), Float(m.m33), 0)
        let w = SIMD4(Float(0), Float(0), Float(0), Float(1))
        return simd_float4x4(columns: (x, y, z, w))
    }
}
