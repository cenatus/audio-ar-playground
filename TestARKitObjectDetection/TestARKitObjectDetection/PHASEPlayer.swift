//
//  PHASEPlayer.swift
//  TestARKitObjectDetection
//
//  Created by Tim on 11/1/22.
//

import Foundation
import PHASE

class PHASEPlayer {
    
    var radius : Float
    var cullDistance : Double
    var rolloffFactor : Double
    
    var engine: PHASEEngine!
    var listener: PHASEListener!
    var spatialMixerDefinition: PHASESpatialMixerDefinition!
    
    var samples: [String : String]
    
    var soundEvents: [String : PHASESoundEvent] = [:]
    var sources: [String: PHASESource] = [:]
    
    var listenerPosition: simd_float4x4 = matrix_identity_float4x4;
    var listenerHeadPosition: simd_float4x4 = matrix_identity_float4x4;

    
    init(samples : [String : String], radius : Float, cullDistance : Double, rolloffFactor : Double) {
        self.samples = samples
        self.radius = radius
        self.cullDistance = cullDistance
        self.rolloffFactor = rolloffFactor
        self.engine = PHASEEngine(updateMode: .automatic)
    }
    
    func setup() {
        self.spatialMixerDefinition = self.setupSpatialMixerDefinition()
        self.listener = self.setupListener()
        
        for (anchorName, fileName) in self.samples {
            self.registerSoundWithPhase(anchorName: anchorName, fileName: fileName)
        }
        
        try! self.engine.start()
    }
    
    func teardown() {
        self.engine.stop()
    }
    
    func playSampleAtPosition(sample : String, position : float4x4) {
        let source = sources[sample]!
        source.transform = position
        let soundEvent = soundEvents[sample]!
        soundEvent.start()
    }
    
    func updateListenerPosition(position: float4x4) {
        self.listenerPosition = position
        self.updatePosition()
    }
    
    func updateListenerHeadPosition(position: float4x4) {
        self.listenerHeadPosition = position
        self.updatePosition()
    }
    
    private func setupListener() -> PHASEListener {
        let listener = PHASEListener(engine: self.engine)
        listener.transform = matrix_identity_float4x4
        try! self.engine.rootObject.addChild(listener)
        return listener
    }
    
    private func setupSpatialMixerDefinition() -> PHASESpatialMixerDefinition {
        let spatialPipeline = self.setupSpatialPipeline()
        let distanceModelParameters = self.setupDistanceModelParameters()
        
        let spatialMixerDefinition = PHASESpatialMixerDefinition(spatialPipeline: spatialPipeline)
        spatialMixerDefinition.distanceModelParameters = distanceModelParameters
        
        return spatialMixerDefinition
    }
    
    private func setupSpatialPipeline() -> PHASESpatialPipeline {
        let spatialPipelineFlags : PHASESpatialPipeline.Flags = [.directPathTransmission, .lateReverb]
        let spatialPipeline = PHASESpatialPipeline(flags: spatialPipelineFlags)!
        spatialPipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.1;
        self.engine.defaultReverbPreset = .mediumRoom
        return spatialPipeline
    }
    
    private func setupDistanceModelParameters() -> PHASEDistanceModelParameters {
        let distanceModelParameters = PHASEGeometricSpreadingDistanceModelParameters()
        distanceModelParameters.fadeOutParameters =
        PHASEDistanceModelFadeOutParameters(cullDistance: self.cullDistance)
        distanceModelParameters.rolloffFactor = self.rolloffFactor
        return distanceModelParameters
    }
    
    private func registerSoundWithPhase(anchorName : String, fileName : String) {
        let url = Bundle.main.url(forResource: fileName, withExtension: "mp3")!
        
        try! self.engine.assetRegistry.registerSoundAsset(
            url: url, identifier: fileName, assetType: .resident,
            channelLayout: nil, normalizationMode: .dynamic
        )
        
        let samplerNodeDefinition = PHASESamplerNodeDefinition(
            soundAssetIdentifier: fileName, mixerDefinition: self.spatialMixerDefinition
        )
        
        samplerNodeDefinition.playbackMode = .looping
        samplerNodeDefinition.setCalibrationMode(calibrationMode: .relativeSpl, level: 12)
        samplerNodeDefinition.cullOption = .sleepWakeAtRealtimeOffset
        
        try! engine.assetRegistry.registerSoundEventAsset(rootNode: samplerNodeDefinition, identifier: anchorName)
        
        let mesh = MDLMesh.newIcosahedron(withRadius: self.radius, inwardNormals: false, allocator: nil)
        
        let shape = PHASEShape(engine: self.engine, mesh: mesh)
        let source = PHASESource(engine: self.engine, shapes: [shape])
        sources[anchorName] = source
        try! self.engine.rootObject.addChild(source)
        
        let mixerParameters = PHASEMixerParameters()
        mixerParameters.addSpatialMixerParameters(
            identifier: self.spatialMixerDefinition.identifier,
            source: source, listener: self.listener
        )

        let soundEvent = try! PHASESoundEvent(
            engine: self.engine, assetIdentifier: anchorName,
            mixerParameters: mixerParameters
        )
        
        soundEvents[anchorName] = soundEvent
    }
    
    private func updatePosition() {
        self.listener.transform = self.listenerPosition * self.listenerHeadPosition
    }

}
