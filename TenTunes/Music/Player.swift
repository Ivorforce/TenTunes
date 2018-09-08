//
//  Player.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 04.04.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Foundation
import AudioKit

extension AKPlayer {
    func createFakeCompletionHandler(completion: @escaping () -> Swift.Void) -> Timer {
        return Timer.scheduledTimer(withTimeInterval: 1.0 / 300.0, repeats: true ) { [unowned self] (timer) in
            // Kids, don't try this at home
            // Really
            // Holy shit
            if self.isPlaying && Int64(self.frameCount) - self.currentFrame < 100 {
                completion()
            }
        }
    }
}

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

class Player {
    var history: PlayHistory?
    var player: AKPlayer!
    var backingPlayer: AKPlayer!
    var playing: Track?
    
    var completionTimers: (Timer?, Timer?)
    
    var updatePlaying: ((Track?) -> Swift.Void)?
    var historyProvider: (() -> PlayHistory)?
    
    var mixer: AKMixer
    var outputNode: AKBooster
    var fft: AKFFTTap

    var shuffle = true {
        didSet {
            (shuffle ? history?.shuffle() : history?.unshuffle())
        }
    }

    init() {
        player = AKPlayer()
        backingPlayer = AKPlayer()
        mixer = AKMixer(player, backingPlayer)
        outputNode = AKBooster(mixer)
                
        fft = AKFFTTap(mixer)

        // The completion handler sucks...
        // TODO When it stops sucking, replace our completion timer hack
        //        self.player.completionHandler =
        completionTimers = (player.createFakeCompletionHandler { [unowned self] in
            self.play(moved: 1)
            }, backingPlayer.createFakeCompletionHandler { [unowned self] in
                self.play(moved: 1)
        })
    }
    
    func start() {
        AudioKit.output = outputNode
    }
    
    
    var isPlaying : Bool {
        return player.isPlaying
    }
    
    var isPaused : Bool {
        return !isPlaying
    }

    func play(at: Int?, in history: PlayHistory?) {
        if let history = history {
            self.history = PlayHistory(from: history)
        }
        
        self.history!.move(to: at ?? -1)
        if shuffle && history != nil { self.history!.shuffle() } // Move there before shuffling so the position is retained
        if at == nil { self.history!.move(to: 0) }
        
        let track = self.history!.playingTrack
        
        do {
            try play(track: track)
        }
        catch PlayError.missing {
            let track = track!
            if track.path == nil {
                if NSAlert.confirm(action: "Invalid File", text: "The file could not be played since no path was provided? That's kinda weird.", confirmTitle: "Choose file", style: .warning), askReplacement(for: track) {
                    play(at: at, in: history)
                }
            }
            else {
                if NSAlert.confirm(action: "Missing File", text: "The file could not be played since the file could not be found.", confirmTitle: "Choose file", style: .warning), askReplacement(for: track) {
                    play(at: at, in: history)
                }
            }
        }
        catch PlayError.error(let message) {
            NSAlert.warning(title: "Error", text: message ?? "An unknown error occured when playing the file.")
        }
        catch let error {
            fatalError(error.localizedDescription)
        }
    }
    
    func notifyPlay(of: Track) {
        let notification = NSUserNotification()
        notification.title = of.rTitle
        notification.subtitle = of.rSource
        if notification.responds(to: Selector(("set_identityImage:"))) {
            notification.perform(Selector(("set_identityImage:")), with: of.artworkPreview ?? Album.missingArtwork)
        }
        else {
            print("Failed to set identity image of notification!")
        }
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    func sanityCheck() {
        if !AudioKit.engine.isRunning {
            try! AudioKit.start()
        }
    }
    
    func togglePlay() {        
        if isPaused {
            sanityCheck()
            player.play()
            updatePlaying?(playing)
        }
        else {
            self.pause()
        }
    }

    enum PlayError : Error {
        case missing
        case error(message: String?)
    }
    
    func enqueue(tracks: [Track]) {
        if history == nil {
            let history = PlayHistory(playlist: PlaylistEmpty())
            play(at: -1, in: history)
        }
        
        history!.insert(tracks: tracks, before: history!.playingIndex + 1)
    }

    func play(track: Track?) throws {
        defer {
            updatePlaying?(playing)
        }
        
        if player.isPlaying {
            player.stop()
        }
        
        sanityCheck()
        
        if let track = track {
            if let url = track.url {
                do {
                    let akfile = try AKAudioFile(forReading: url)
                    player.load(audioFile: akfile)
                    backingPlayer.load(audioFile: akfile)
                } catch let error {
                    print(error.localizedDescription)
                    player.stop()
                    playing = nil
                    
                    throw PlayError.error(message: error.localizedDescription)
                }
                
                guard player.duration < 100000 else {
                    playing = nil
                    throw PlayError.error(message: "File duration is too long! The file is probably bugged.") // Likely bugged file and we'd crash otherwise
                }
                
                player.play()
                playing = track
                
                if !NSApp.isActive {
                    notifyPlay(of: track)
                }
            }
            else {
                // We are at a track but it's not playable :<
                playing = nil
                
                throw PlayError.missing
            }
        }
        else {
            // Somebody decided we should stop playing
            // Or we're at start / end of list
            playing = nil
        }
    }
    
    func play(moved: Int) {
        if (history?.count ?? 0) == 0 {
            guard let historyProvider = historyProvider else {
                return
            }
            play(at: nil, in: historyProvider())
        }
        else if moved == 0 {
            history!.shuffle()
            history!.move(to: 0) // Select random track next
        }
        
        let didPlay = (try? play(track: history!.move(by: moved))) != nil
        
        // Should play but didn't
        // And we are trying to move in some direction
        if moved != 0, history?.playingTrack != nil, !didPlay {
            if let playing = playing {
                print("Skipped unplayable track \(playing.objectID.description): \(String(describing: playing.path))")
            }
            
            play(moved: moved)
        }
    }
    
    func setPosition(_ position: Double) {
        sanityCheck()
        
        let time = position * player.duration
        guard abs(time - player.currentTime) > 0.04 else {
            return // Baaasically the same, so skip doing extra work
        }
        
        guard isPlaying else {
            player.setPosition(time)
            return
        }
        
        // This code block makes jumping the tiniest bit smoother
        // TODO Maybe determine this heuristically? lol
        let magicAdd = 0.04 // Hacky absolute that makes it even smoother
        backingPlayer.setPosition(time + magicAdd)
        backingPlayer.volume = 0
        backingPlayer.play()
        
        let _player = self.player
        self.player = self.backingPlayer
        self.backingPlayer = _player

        // Slowly switch states. Kinda hacky but improves listening result
        for _ in 0..<100 {
            self.player.volume += 1.0 / 100
            self.backingPlayer.volume -= 1.0 / 100
            Thread.sleep(forTimeInterval: 0.001)
        }
        
        self.backingPlayer.stop()
    }
    
    func pause() {
        sanityCheck()
        
        // The set position is reset when we play again
        player.play(from: player.currentTime, to: player.duration)
        player.stop()
        
        updatePlaying?(playing)
    }
    
    @discardableResult
    func askReplacement(for track: Track) -> Bool {
        let dialogue = Library.Import.dialogue(allowedFiles: .track)
        dialogue.allowsMultipleSelection = false
        dialogue.runModal()
        
        guard let url = dialogue.url else {
            return false
        }
        
        track.path = url.absoluteString
        track.usesMediaDirectory = false
        
        return true
    }
}
