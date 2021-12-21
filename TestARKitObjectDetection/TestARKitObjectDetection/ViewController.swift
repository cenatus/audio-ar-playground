//
//  ViewController.swift
//  TestARKitObjectDetection
//
//  Created by Tim on 15/12/21.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    
    
    var playerNodes: [String: AVAudioPlayerNode] = [:]
    var objectNodes: [String: SCNNode] = [:]
    var playing: [String: Bool] = [:]
        
    let anchorFileMapping = Dictionary(uniqueKeysWithValues: [
        ("serres_parasite", "guitar"),
        ("douglas_purity_danger", "drone"),
        ("morton_being_ecological", "piano")
    ])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.audioEnvironmentNode.distanceAttenuationParameters.referenceDistance = 0.2
        sceneView.audioEnvironmentNode.distanceAttenuationParameters.maximumDistance = 1.5
        sceneView.audioEnvironmentNode.reverbParameters.enable = true
        sceneView.audioEnvironmentNode.reverbParameters.level = 6
        sceneView.audioEnvironmentNode.reverbParameters.loadFactoryReverbPreset(AVAudioUnitReverbPreset.plate)
        sceneView.audioEnvironmentNode.reverbBlend = 0.5

        for (anchorName, fileName) in anchorFileMapping {
            let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")!
            let file = try! AVAudioFile(forReading: url)
            let playerNode = AVAudioPlayerNode()
            let format = file.processingFormat
            let frameCount = UInt32(file.length)
            let buffer = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: frameCount
            )
            try! file.read(into: buffer!)
            
            sceneView.audioEngine.attach(playerNode)
            sceneView.audioEngine.connect(
                playerNode, to: sceneView.audioEnvironmentNode, format: format
            )
        
            playerNode.scheduleBuffer(
                buffer!, at: nil, options:.loops, completionHandler: nil
            )
            //player.numberOfLoops = -1 // infinite loop
            //player.prepareToPlay();
            //let audioSource = SCNAudioSource(url: url)!
            //audioSource.loops = true
            //audioSource.load()
            playerNodes[anchorName] = playerNode
            objectNodes[anchorName] = SCNNode()
            playing[anchorName] = false
        }
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
        for(_, objectNode) in objectNodes {
            objectNode.removeAllAudioPlayers()
        }
        sceneView.session.pause()
    }

    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    internal func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        let name = anchor.name!
        print("********* SEEN ANCHOR \(name)")
        if let objectNode = objectNodes[name] {
            if(!playing[name]!) {
                playing[name] = true
                let playerNode = playerNodes[name]!
                objectNode.removeAllAudioPlayers()
                objectNode.addAudioPlayer(SCNAudioPlayer(avAudioNode: playerNode))
                node.addChildNode(objectNode)
                playerNode.play()
                //let action = SCNAction.playAudio(audioSource, waitForCompletion: false)
                //objectNode.runAction(action)
            }
        } else {
            print("No sound registered for anchor \(name)")
        }
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
