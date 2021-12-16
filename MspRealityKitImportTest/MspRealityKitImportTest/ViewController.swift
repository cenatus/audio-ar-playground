//
//  ViewController.swift
//  MspRealityKitImportTest
//
//  Created by msp on 16/12/2021.
//

import UIKit
import RealityKit

class ViewController: UIViewController {
    
    @IBOutlet var arView: ARView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        guard let anchor = try? WaterBottle.loadScene() else { print("---------------------- OH FECK IT!"); return }
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(anchor)
    }
}
