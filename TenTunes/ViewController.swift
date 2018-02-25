//
//  ViewController.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 17.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa
import Foundation
import AudioKit
import AudioKitUI

import MediaKeyTap

let playString = "▶"
let pauseString = "||"

extension AVPlayer {
    var isPlaying: Bool {
        return rate != 0 && error == nil
    }
}

func synced(_ lock: Any, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

class ViewController: NSViewController {

    @IBOutlet var _title: NSTextField!
    @IBOutlet var _subtitle: NSTextField!
    
    @IBOutlet var _play: NSButton!
    @IBOutlet var _stop: NSButton!
    @IBOutlet var _previous: NSButton!
    @IBOutlet var _next: NSButton!
    
    @IBOutlet var _spectrumView: TrackSpectrumView!
    
    @IBOutlet var _shuffle: NSButton!
    
    @IBOutlet var _timePlayed: NSTextField!
    @IBOutlet var _timeLeft: NSTextField!
    
    @IBOutlet var _volume: NSSlider!
    
    var database: [Int: Track] = [:]
    var masterPlaylist: Playlist = Playlist(folder: true)
    var library: Playlist = Playlist(folder: false)

    var history: PlayHistory? {
        didSet {
            self.history?.reorder(shuffle: self.shuffle)
        }
    }
    var player: AKPlayer!
    var playing: Track?
    
    var visualTimer: Timer!
    var completionTimer: Timer?

    var _workerSemaphore = DispatchSemaphore(value: 3)
    var _filterSemaphore = DispatchSemaphore(value: 1)

    var shuffle = true {
        didSet {
            self.history?.reorder(shuffle: self.shuffle)
        }
    }
    
    var mediaKeyTap: MediaKeyTap?
    
    @IBOutlet var playlistController: PlaylistController!
    @IBOutlet var trackController: TrackController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.player = AKPlayer()
        // The completion handler sucks...
        // TODO When it stops sucking, replace our completion timer hack
//        self.player.completionHandler = { [unowned self] in
//            self.play(moved: 1)
//        }

        AudioKit.output = self.player
        try! AudioKit.start()

        let path = "/Volumes/Lukebox/iTunes/iTunes Library.xml"
        
        if let (pdatabase, pmasterPlaylist) = ITunesImporter.parse(path: path) {
            database = pdatabase
            masterPlaylist = pmasterPlaylist
        }
        else {
            print("FILE UNAVAILABLE")
        }
        
        for (_, track) in database {
            library.tracks.append(track)
        }
        
        self.playlistController.selectionDidChange = { [unowned self] in
            self.playlistSelected($0)
        }
        self.playlistController.playPlaylist = { [unowned self] in
            self.playlistSelected($0)
            self.history = self.trackController.history
            self.play(moved: 0)
        }
        self.playlistController.masterPlaylist = masterPlaylist
        self.playlistController.library = library

        self.trackController.playTrack = { [unowned self] in
            self.play($0, at: $1, in: self.trackController.history)
        }
        self.trackController.history = PlayHistory(playlist: library)

        self.updatePlaying()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            return self.keyDown(with: $0)
        }
        
        mediaKeyTap = MediaKeyTap(delegate: self)
        mediaKeyTap?.start()

        startBackgroundTasks()
    }
    
    override func viewDidAppear() {
        self.view.window!.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark)
        
        _timePlayed.alphaValue = 0.5
        _timeLeft.alphaValue = 0.5
        
        _play.set(color: NSColor.lightGray)
        _previous.set(color: NSColor.lightGray)
        _next.set(color: NSColor.lightGray)
    }
        
    func keyDown(with event: NSEvent) -> NSEvent? {
        let keyString = event.charactersIgnoringModifiers
        
        if keyString == " ", trackController._tableView.window?.firstResponder == trackController._tableView {
            self._play.performClick(self) // Grab the spaces from the table since it takes forever for those
        } else if keyString == "f" && NSEvent.modifierFlags.contains(.command) {
            trackController.openSearchBar(self)
        }
        else {
            return event
        }
        
        return nil
    }
    
    func isPlaying() -> Bool {
        return self.player.isPlaying
    }

    func isPaused() -> Bool {
        return !self.isPlaying()
    }

    func updatePlaying() {
        guard let track = self.playing else {
            _play.set(text: playString)
            
            self._title.stringValue = ""
            self._subtitle.stringValue = ""
            
            return
        }
        
        _play.set(text: self.isPaused() ? playString : pauseString)
        
        self._title.stringValue = track.rTitle
        self._subtitle.stringValue = track.rSource
    }
    
    func play(track: Track?) -> Void {
        if player.isPlaying {
            player.stop()
        }
        
        if let track = track, let url = track.url {
            do {
                let akfile = try AKAudioFile(forReading: url)
                
                _spectrumView.analysis = track.analysis // If it's not analyzed, our worker threads will handle
                
                player.load(audioFile: akfile)
                player.play()
                playing = track
            } catch let error {
                print(error.localizedDescription)
                player.stop()
                playing = nil
                _spectrumView.analysis = nil
            }
        }
        else {
            player.stop()
            playing = nil
            _spectrumView.analysis = nil
        }
        
        self.updatePlaying()
    }
            
    @IBAction func play(_ sender: Any) {
        if self.playing != nil {
            if self.isPaused() {
                self.player.play()
            }
            else {
                self.pause()
            }
        }
        else {
            if let track = trackController.selectedTrack {
                play(track, at: trackController._tableView.selectedRow, in: trackController.history)
            }
            else {
                play(moved: 0)
            }
        }
        
        self.updatePlaying()
    }
    
    func play(moved: Int) {
        if history == nil {
            history = trackController.history
        }
        else if moved == 0 {
            history!.reorder(shuffle: shuffle)
            history!.move(to: nil) // Select random track next
        }
        
        self.play(track: self.history!.move(moved))
    }
    
    func pause() {
        // The set position is reset when we play again
        self.player.play(from: self.player.currentTime, to: self.player.duration)
        self.player.stop()
    }
    
    @IBAction func nextTrack(_ sender: Any) {
        self.play(moved: 1)
    }
    
    @IBAction func previousTrack(_ sender: Any) {
        self.play(moved: -1)
    }
        
    @IBAction func clickSpectrumView(_ sender: Any) {
        if let position = self._spectrumView.getBy(player: self.player) {
            self.player.setPosition(position)
        }
    }
    
    @IBAction func toggleShuffle(_ sender: Any) {
        shuffle = !shuffle
        let img = NSImage(named: NSImage.Name(rawValue: "shuffle"))
        _shuffle.image = shuffle ? img : img?.tinted(in: NSColor.gray)
    }
    
    func play(_ track: Track, at: Int, in history: PlayHistory? = nil) {
        if let history = history {
            self.history = history
        }
        else if self.history == nil {
            self.history = trackController.history
        }
        
        self.history!.move(to: at)
        self.play(track: track)
    }
    
    func playlistSelected(_ playlist: Playlist) {
        trackController.history = PlayHistory(playlist: playlist)
    }
    
    @IBAction func volumeChanged(_ sender: Any) {
        player.volume = Float(_volume.intValue) / 100
    }
}

extension ViewController: MediaKeyTapDelegate {
    func handle(mediaKey: MediaKey, event: KeyEvent) {
        switch mediaKey {
        case .playPause:
            _play.performClick(self)
        case .previous, .rewind:
            _previous.performClick(self)
        case .next, .fastForward:
            _next.performClick(self)
        }
    }
}
