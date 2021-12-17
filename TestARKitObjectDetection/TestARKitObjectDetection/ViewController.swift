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
    
    
    var audioSources: [String: SCNAudioSource] = [:]
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
        
        for (anchorName, fileName) in anchorFileMapping {
            let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")!
            let audioSource = SCNAudioSource(url: url)!
            audioSource.loops = true
            audioSource.load()
            audioSources[anchorName] = audioSource
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
        print("********************* SETTING REFS \(referenceObjects)")
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
                let audioSource = audioSources[name]!
                objectNode.removeAllAudioPlayers()
                objectNode.addAudioPlayer(SCNAudioPlayer(source: audioSource))
                node.addChildNode(objectNode)
                let action = SCNAction.playAudio(audioSource, waitForCompletion: false)
                objectNode.runAction(action)
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
