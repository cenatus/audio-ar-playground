//
//  PHASEPlayer.swift
//  TestARKitObjectDetection
//
//  Created by Tim on 11/1/22.
//

import Foundation
import PHASE

class PHASEPlayer {
    
    struct Config: Codable {
        let sounds : [PHASEPlayerSound.Config]
    }
    
    let engine: PHASEEngine!
    let listener: PHASEListener!
    
    var sounds: [String : PHASEPlayerSound] = [:]
    
    private var _devicePosition: simd_float4x4 = matrix_identity_float4x4;
    private var _headPosition: simd_float4x4 = matrix_identity_float4x4;
    
    var listenerPosition : simd_float4x4 {
        get { return listener.transform }
    }
    
    var devicePosition : simd_float4x4 {
        get { return _devicePosition }
        set(position) {
            _devicePosition = position
            listener.transform = matrix_multiply(_devicePosition, _headPosition)
        }
    }
    
    var headPosition: simd_float4x4 {
        get { return _headPosition }
        set(position) {
            _headPosition = position
            listener.transform = matrix_multiply(_devicePosition,  _headPosition)
        }
    }
    
    init(_ configFileName : String) {
        self.engine = PHASEEngine(updateMode: .automatic)
        self.engine.defaultReverbPreset = .largeRoom
        self.listener = PHASEListener(engine: self.engine)
        self.listener.transform = matrix_identity_float4x4
        try! self.engine.rootObject.addChild(self.listener)
        
        let path = Bundle.main.path(forResource: configFileName, ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let decoder = JSONDecoder()
        let config = try! decoder.decode(Config.self, from: data)
    
        for soundConfig in config.sounds {
            sounds[soundConfig.anchor_name] = PHASEPlayerSound(player: self, config: soundConfig)
        }
    }
    
    func setup() {
        try! self.engine.start()
    }
    
    func teardown() {
        self.engine.stop()
    }
    
    func playSampleAtPosition(sample : String, position : float4x4) -> PHASEPlayerSound {
        let sound = sounds[sample]!
        sound.startAtPosition(position)
        return sound
    }
}
