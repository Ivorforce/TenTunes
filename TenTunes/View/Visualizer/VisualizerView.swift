//
//  VisualizerView.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 07.09.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

import OpenGL
import Darwin

@objc protocol VisualizerViewDelegate {
    @objc optional func visualizerViewUpdate(_ view: VisualizerView)
    
    @objc optional func setControlsHidden(_ hidden: Bool)
    
    @discardableResult
    // Actually Visualizer.PauseResult, but can't be represented
    @objc func togglePlay() -> AnyObject
}

// For Namespace
class Visualizer {
    enum PauseResult {
        case paused, played
    }
}

class VisualizerView: SyphonableOpenGLView {
    typealias Number = Float
    
    static let skipFrequencies = 4
    static let resonanceSteepness = 15.0
    
    @objc @IBOutlet
    weak var delegate: VisualizerViewDelegate?
    
    var deepResonance: [[Number]] = Array(repeating: [], count: 6)
    
    var resonance: [Number] = []
    var numbness: [Number] = []
    var totalResonance: Number = 0
    var highResonance: Number = 0
    
    var startDate = NSDate().addingTimeInterval(-TimeInterval(Int.random(in: 50...10_000)))
    var time : Number { return Number(-startDate.timeIntervalSinceNow) }
        
    // Settings
    @objc var effectStrength: Number = 0.0
    @objc var colorVariance: Number = 0.3
    @objc var brightness: Number = 0.7
    @objc var psychedelic: Number = 0.5
    @objc var details: Number = 0.75
    @objc var frantic: Number = 0.5

    var distortionRands = (0 ..< 100).map { _ in Number.random(in: 0 ..< 1 ) }
    
    // Controls
    
    var trackingArea : NSTrackingArea?
    
    func update(withFFT fft: [Number]) {
        let desiredLength = min(Int(details * 6 + 4), 10)
        
        if resonance.count != desiredLength {
            resonance = resonance.remap(toSize: desiredLength, default: 0)
            numbness = numbness.remap(toSize: desiredLength, default: 0)
            deepResonance = deepResonance.map { return $0.remap(toSize: desiredLength, default: 0) }
        }

        let desired: [Number] = (0 ..< resonance.count).map { idx in
            let middle = (pow(2.0, Number(idx)) - 1) / pow(2, Number(resonance.count)) * Number(fft.count - VisualizerView.skipFrequencies) + Number(VisualizerView.skipFrequencies)
            
            // Old method
            let steepness: Number = 4.0
            let gain = pow(0.5, -steepness)
            
            return fft.enumerated().map { (idx, val) in
                // Later frequencies stretch across more values
                let stretch = 1 + Number(idx) / 2
                // Frequencies that are farther away shall not be picked up as strongly
                let dist = abs(Number(idx) - middle)
                // Multiply since this diminishes the carefully balanced values a bit
                return pow(val / (1 + pow(dist / stretch, steepness) * gain) * 2.2, 0.9 + frantic * 0.2)
                }.reduce(0, +) / (Interpolation.linear(1, 0.001 + numbness[idx], amount: max(0, (frantic - 0.4) * 2.5)))
            
            //            return fft.enumerated().map { (idx, val) in
            //                // Later frequencies stretch across more values
            //                let variance = pow((1 + Double(idx)) / VisualizerView.resonanceSteepness, 2)
            //                let scalar = pow(4.0 / VisualizerView.resonanceSteepness, 2)
            //                // Frequencies that are farther away shall not be picked up as strongly
            //                let dist = pow(Double(Double(idx) - middle), 2)
            //                // Normal distribution
            //                let resonance = 1 / sqrt(2 * Double.pi * scalar) * pow(Darwin.M_E, (-dist / (2 * variance))) * 5
            //                return val * resonance
            //                }.reduce(0, +)
        }

        deepResonance = deepResonance.enumerated().map { (idx, resonance) in
            let lerp = pow(0.6, Number(idx) + 3) + frantic * 0.1
            return Interpolation.linear(resonance, desired, amount: lerp)
        }
        
        let lerp = 0.1 + frantic * 0.1
        resonance = Array(arrayZip(deepResonance)).map { $0.reduce(0, +) / Float(deepResonance.count) }
        
        totalResonance = Interpolation.linear(totalResonance, fft.reduce(0, +) / Number(fft.count) * 650, amount: lerp)
        let highFFT = fft.enumerated().map { (idx, val) in val * pow(Number(idx) / Number(fft.count), 3) }
        highResonance = Interpolation.linear(highResonance, highFFT.reduce(0, +) / Number(highFFT.count) * 900, amount: lerp)

        numbness = Interpolation.linear(numbness, resonance, amount: lerp * 0.5)
    }
    
    @discardableResult
    func compile(shader: Shader, vertexResource: String, fragmentResource: String) -> Bool {
        do {
            try shader.compile(vertexResource: vertexResource, fragmentResource: fragmentResource)
        }
        catch Shader.CompileFailure.load {
            print("Failed to load shaders: \(vertexResource) . \(fragmentResource)")
            return false
        }
        catch Shader.CompileFailure.vertexCompile {
            print("Failed to compile vertex shader: \(vertexResource)")
            return false
        }
        catch Shader.CompileFailure.fragmentCompile {
            print("Failed to compile fragment shader: \(fragmentResource)")
            return false
        }
        catch {
            print("Failed to \(error) shaders: \(vertexResource) . \(fragmentResource)")
            return false
        }

        return true
    }
        
    override func animate() {
        DispatchQueue.main.async {
            if let window = self.window {
                if window.isKeyWindow, window.isMouseInside, RFOpenGLView.timeMouseIdle() > 2 {
                    NSCursor.setHiddenUntilMouseMoves(true)
                    self.delegate?.setControlsHidden?(true)
                }
            }
        }
        
        delegate?.visualizerViewUpdate?(self)
    }
    
    func color(_ idx: Int, time: Number, darknessBonus: Number = 0) -> NSColor {
        let resonanceVal = resonance[safe: idx] ?? 0
        
        let prog = Number(idx) / Number(resonance.count - 1)
        let ratio = resonanceVal / totalResonance
        
        let loudnessColorChange = (ratio * 0.1 + resonanceVal * 0.05) * (colorVariance * 0.5 + 0.4 + frantic * 0.2)
        let localDarkness = pow(2, ((1 - brightness) * (darknessBonus * 2 + 1)) + 0.4)
        let brightnessBoost = pow(0.5, ((1 - ratio) * 0.4 + 0.4) / (highResonance / 15 + 1)) + ratio * 0.2
        let desaturationBoost = (0.5 + prog * 0.5) * totalResonance / (55 - frantic * 30) + prog

        // 0.6 so that extremely high and low sounds are far apart in color
        return NSColor(hue: CGFloat(prog * colorVariance + (time * 0.02321) + loudnessColorChange).truncatingRemainder(dividingBy: 1),
                       saturation: CGFloat(max(0, min(1, 0.2 + ratio * 4 * (0.8 + colorVariance) - desaturationBoost))),
                       brightness: CGFloat(min(1, resonanceVal * (1 + prog) + brightnessBoost * 0.4) / localDarkness + 0.4),
                       alpha: 1)
    }
    
    func rgb(_ color: NSColor) -> [Number] {
        return [Number(color.redComponent), Number(color.greenComponent), Number(color.blueComponent)]
    }
    
    func uploadDefaultUniforms(onto shader: Shared) {
        glUniform1f(shader.guTime, time);
        glUniform2f(shader.guResolution, GLfloat(bounds.size.width), GLfloat(bounds.size.height));
    }
    
    override func mouseMoved(with event: NSEvent) {
        delegate?.setControlsHidden?(false)
    }
    
    override func mouseExited(with event: NSEvent) {
        delegate?.setControlsHidden?(true)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        trackingArea.map(removeTrackingArea)
        trackingArea = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow], owner: self, userInfo: nil)
        addTrackingArea(trackingArea!)
    }
    
    enum PauseResult {
        case paused, played
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.characters == " " {
            // TODO Show that we pressed with a small visualization
            delegate?.togglePlay()
            return
        }
        
        super.keyDown(with: event)
    }
}
