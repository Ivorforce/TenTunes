//
//  TrackSpectrumView.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 17.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

let sampleCount = 200

class Analysis {
    var file: AVAudioFile
    
    var amplitudes: [CGFloat]
    var turns: [Int]
    
    init(file: AVAudioFile, samples: Int) {
        self.file = file
        amplitudes = Array(repeating: CGFloat(0), count: samples)
        turns = []
    }
    
    init(from: Analysis) {
        file = from.file
        amplitudes = from.amplitudes
        turns = from.turns
    }
    
    func analyze(shift: Int) {
        let startPos = file.framePosition
        
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: file.fileFormat.channelCount, interleaved: false)!
        
        let skipSamples = AVAudioFrameCount(Int(file.length) / amplitudes.count - 1)
        
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: UInt32(1))!
        
        // Shuffle order to hopefully speed up result accuracy
        42.seed()
        var order = Array(0...skipSamples)
        order.shuffle()
        file.framePosition = Int64(order[shift])
        
        for i in 0..<amplitudes.count {
            do {
                try file.read(into: buf, frameCount: AVAudioFrameCount(1))
            }
            catch let error {
                print(error.localizedDescription)
                return
            }
            
            let val = abs(CGFloat(UnsafeBufferPointer(start: buf.floatChannelData?[0], count:1).first!))
            file.framePosition += Int64(skipSamples)
            
            if shift > 0 {
                amplitudes[i] = amplitudes[i] / CGFloat(shift + 1) * CGFloat(shift)
            }
            amplitudes[i] += val / CGFloat(shift + 1)
        }
        
        file.framePosition = startPos
    }
    
    var frequencies: [CGFloat] {
        var result: [CGFloat] = []
        for i in 0..<amplitudes.count {
            result.append(CGFloat(0.0))
        }
        return result
    }
}

func lerp(_ left: [CGFloat], _ right: [CGFloat], _ amount: CGFloat) -> [CGFloat] {
    return zip(left, right).map { (cur, sam) in
        return cur * (CGFloat(1.0) - amount) + sam * amount
    }
}

class TrackSpectrumView: NSControl {
    var location: Double? {
        didSet {
            self.setNeedsDisplay()
        }
    }
    
    var curSamples: [CGFloat] = Array(repeating: CGFloat(0), count: sampleCount) {
        didSet {
            self.setNeedsDisplay()
        }
    }
    var curFrequencies: [CGFloat] = Array(repeating: CGFloat(0), count: sampleCount) {
        didSet {
            self.setNeedsDisplay()
        }
    }

    var _drawSamples: [CGFloat] { return self.analysis?.amplitudes ?? Array(repeating: CGFloat(0), count: sampleCount) }
    var _drawFrequencies: [CGFloat] { return self.analysis?.frequencies ?? Array(repeating: CGFloat(0), count: sampleCount) }

    var analysis: Analysis? = nil
    
    var timer: Timer? = nil
    
    override func awakeFromNib() {
        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { _ in
            self.curSamples = lerp(self.curSamples, self._drawSamples, CGFloat(1.0 / 30.0))
            self.curFrequencies = lerp(self.curFrequencies, self._drawFrequencies, CGFloat(1.0 / 30.0))
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.lightGray.set() // choose color
        
        let samples = self.curSamples
    
        var bars: [CGFloat] = []

        let numBars = Int(self.bounds.width / 5)
        for bar in 0..<Int(self.bounds.width / 5) {
            let trackPosStart = Double(bar) / Double(numBars + 1)
            let trackPosEnd = Double(bar + 1) / Double(numBars + 1)
            let trackRange = Int(trackPosStart * Double(samples.count))...Int(trackPosEnd * Double(samples.count))
            
            bars.append(samples[trackRange].reduce(0, +) / CGFloat(trackRange.count))
        }
        
        let samplesMax = max(samples.max()!, 0.2) // Make sure if it goes against 0 it does go
        bars = bars.map {$0 / samplesMax}

        for bar in 0..<Int(self.bounds.width / 5) {
            let val = bars[bar]

            let figure = NSBezierPath()

            figure.move(to: NSMakePoint(CGFloat(bar * 5), val * self.bounds.minY))
            figure.line(to: NSMakePoint(CGFloat(bar * 5), val * self.bounds.maxY))
            
            figure.lineWidth = 3
            figure.stroke()
        }
        
        if let location = self.location {
            NSColor.white.set() // choose color
            let position = NSBezierPath()
            
            position.move(to: NSMakePoint(CGFloat(location) * self.bounds.width, self.bounds.minY))
            position.line(to: NSMakePoint(CGFloat(location) * self.bounds.width, self.bounds.maxY))
            
            position.lineWidth = 1
            position.stroke()
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    func click(at: NSPoint) {
        self.location = Float(at.x) / Float(self.bounds.width)
        
        if let action = self.action, let target = self.target {
            NSApp.sendAction(action, to: target, from: self)
        }
    }
    
    override func mouseDragged(with event: NSEvent) {
        self.click(at: self.convert(event.locationInWindow, from: nil))
    }
    
    override func mouseDown(with event: NSEvent) {
        self.click(at: self.convert(event.locationInWindow, from: nil))
    }
}

import AudioKit
import AudioKitUI

extension TrackSpectrumView {
    func setBy(player: AKPlayer) {
        if player.audioFile != nil {
            self.setBy(time: player.currentTime, max: player.duration)
        }
        else {
            self.location = nil
        }
    }
    
    func setBy(time: Double, max: Double) {
        self.location = time / max
    }
    
    func getBy(player: AKPlayer) -> Double? {
        return player.audioFile != nil ? self.getBy(max: player.duration) : nil
    }

    func getBy(max: Double) -> Double? {
        return self.location != nil ? self.location! * max : nil
    }
    
    func analyze(file: AVAudioFile?) {
        if let file = file {
            self.analysis = Analysis(file: file, samples: sampleCount)

            // Run Async
            DispatchQueue.global(qos: .userInitiated).async {
                let analysis: Analysis = Analysis(file: file, samples: sampleCount)
                
                for i in 0..<sampleCount {
                    analysis.analyze(shift: i)
                    
                    if self.analysis?.file != analysis.file {
                        return
                    }
                    
                    // Update on main thread
                    DispatchQueue.main.async {
                        self.analysis = Analysis(from: analysis)
                    }
                }
            }
        }
        else {
            self.analysis = nil
        }
    }    
}
