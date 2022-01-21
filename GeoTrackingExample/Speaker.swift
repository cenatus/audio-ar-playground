//
//  Speaker.swift
//  GeoTrackingExample
//
//  Created by msp on 21/01/2022.
//  Copyright © 2022 Apple. All rights reserved.
//

import Foundation
import UIKit
import PHASE
import ARKit

class Speaker {
    let name : String
    
    let lat: Double
    let lon: Double
    let ele: Double
    
    let audioFile: String
    let color: UIColor
    let geoAnchor : ARGeoAnchor
    
    init(_ config: [String: String]) {
        
        self.name = config["name"]!
        self.lat = Double(config["lat"]!)!
        self.lon = Double(config["lon"]!)!
        self.ele = Double(config["ele"]!)!
        self.audioFile = config["audiofile"]!
        
        self.color = UIColor(red: Double(config["r"]!)!,
                             green: Double(config["g"]!)!,
                             blue: Double(config["b"]!)!,
                             alpha: Double(config["a"]!)!
        )
        
        self.geoAnchor = ARGeoAnchor(
            name: name,
            coordinate: CLLocationCoordinate2D(
                latitude: self.lat,
                longitude: self.lon),
            altitude: CLLocationDistance(self.ele)
        )
    }
}
