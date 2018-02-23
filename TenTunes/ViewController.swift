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

func setButtonText(button: NSButton, text: String) {
    button.attributedTitle = NSAttributedString(string: text, attributes: button.attributedTitle.attributes(at: 0, effectiveRange: nil))
}

func setButtonColor(button: NSButton, color: NSColor) {
    if let mutableAttributedTitle = button.attributedTitle.mutableCopy() as? NSMutableAttributedString {
        mutableAttributedTitle.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutableAttributedTitle.length))
        button.attributedTitle = mutableAttributedTitle
    }
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
    
    var database: [Int: Track]! = [:]
    var playlistDatabase: [String: Playlist]! = [:]
    var playlists: [Playlist]! = []

    var playlist: Playlist!
    var player: AKPlayer!
    var playing: Track?
    var playingIndex: Int?
    
    var visualTimer: Timer!
    
    var shuffle = true
    
    @IBOutlet var playlistController: PlaylistController!
    @IBOutlet var trackController: TrackController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
        self.view.layer!.backgroundColor = NSColor.darkGray.cgColor
        
        setButtonColor(button: _play, color: NSColor.white)
        setButtonColor(button: _previous, color: NSColor.white)
        setButtonColor(button: _next, color: NSColor.white)
        
        self.player = AKPlayer()
        self.player.completionHandler = { [unowned self] in
            self.play(moved: 1)
        }

        AudioKit.output = self.player
        try! AudioKit.start()

        let path = "/Volumes/Lukebox/iTunes/iTunes Library.xml"
        
        if !FileManager.default.fileExists(atPath: path) {
            print("FILE UNAVAILABLE")
            exit(1)
        }

        let nsdict = NSDictionary(contentsOfFile: path)!
        
        for (id, trackData) in nsdict.object(forKey: "Tracks") as! NSDictionary {
            let trackData = trackData as! NSDictionary
            
            let track = Track()
            
            track.id = Int(id as! String)!
            track.title = trackData["Name"] as? String
            track.author = trackData["Artist"] as? String
            track.album = trackData["Album"] as? String
            track.path = trackData["Location"] as? String
            
            self.database[Int(id as! String)!] = track
        }
        
        var mainPlaylist: Playlist? = nil
        for playlistData in nsdict.object(forKey: "Playlists") as! NSArray {
            let playlistData = playlistData as! NSDictionary
            let playlist = Playlist()

            playlist.name = playlistData.object(forKey: "Name") as! String
            playlist.id = playlistData.object(forKey: "Playlist Persistent ID") as! String

            for trackData in playlistData.object(forKey: "Playlist Items") as? NSArray ?? [] {
                let trackData = trackData as! NSDictionary
                let id = trackData["Track ID"] as! Int
                playlist.tracks.append(self.database[id]!)
            }
            
            if playlistData.object(forKey: "Master") as? Bool ?? false {
                mainPlaylist = playlist
            }
            
            self.playlistDatabase[playlist.id] = playlist
            
            if let parent = playlistData.object(forKey: "Parent Persistent ID") as? String {
                self.playlistDatabase[parent]?.children.append(playlist)
            }
            else {
                self.playlists.append(playlist)
            }
        }
        
        self.playlistController.selectionDidChange = { [unowned self] in
            self.playlistSelected($0)
        }
        self.playlistController.playlists = self.playlists

        self.trackController.playTrack = { [unowned self] in
            self.play($0, at: $1)
        }
        self.trackController.playlist = mainPlaylist!

        self.updatePlaying()
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            return self.keyDown(with: $0)
        }

        self.visualTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true ) { [unowned self] (timer) in
            self._spectrumView.setBy(player: self.player) // TODO Apparently this loops back when the track is done (or rather just before)
            
            // Only fetch one at once
            if !self._fetchingMetadata {
                self.fetchOneMetadata()
            }
        }
    }
    
    var _fetchingMetadata: Bool = false
    
    func fetchOneMetadata() {
        for view in trackController.visibleTracks {
            if let track = view.track, !track.metadataFetched  {
                fetchMetadata(for: track, updating: view)
                return
            }
        }
        
        for track in self.trackController.playlist.tracks {
            if !track.metadataFetched  {
                fetchMetadata(for: track, wait: true)
                return
            }
        }
    }
    
    func fetchMetadata(for track: Track, updating: TrackCellView? = nil, wait: Bool = false) {
        self._fetchingMetadata = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            track.fetchMetadata()

            // Update on main thread
            DispatchQueue.main.async {
                self.trackController.update(view: updating, with: track)
            }
            
            if wait {
                sleep(1)
            }

            self._fetchingMetadata = false
        }
        
    }
    
    func keyDown(with event: NSEvent) -> NSEvent? {
        if let keyString = event.charactersIgnoringModifiers, keyString == " " {
            self._play.performClick(self)
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
            self.player.stop()

            setButtonText(button: self._play, text: playString)
            
            self._title.stringValue = ""
            self._subtitle.stringValue = ""
            
            return
        }
        
        setButtonText(button: self._play, text: self.isPaused() ? playString : pauseString)
        
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
                
                // Async anyway so run first
                self._spectrumView.analyze(file: akfile)
                
                self.player.load(audioFile: akfile)
                
                player.play()
                self.playing = track
            } catch let error {
                print(error.localizedDescription)
                self.player.stop()
                self.playing = nil
                self._spectrumView.analyze(file: nil)
            }
        }
        else {
            self.player.stop()
            self.playing = nil
            self._spectrumView.analyze(file: nil)
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
            self.trackController.playCurrentTrack()
        }
        
        self.updatePlaying()
    }
    
    func pause() {
        self.player.play(from: self.player.currentTime, to: self.player.duration)
        self.player.stop()
    }
    
    @IBAction func stop(_ sender: Any) {
        self.play(track: nil)
    }
    
    func play(moved: Int) {
        if playlist.size == 0 {
            self.playingIndex = nil
            self.play(track: nil)
            return
        }
        
        if shuffle {
            self.playingIndex = Int(arc4random_uniform(UInt32(playlist.size)))
            let track = self.playlist.track(at: self.playingIndex!)
            self.play(track: track)
            return
        }
        
        if let playingIndex = self.playingIndex {
            self.playingIndex = playingIndex + moved
        }
        else {
            self.playingIndex = moved > 0 ? 0 : playlist.size - 1
        }
        
        if self.playingIndex! >= playlist.size || self.playingIndex! < 0 {
            self.playingIndex = nil
            self.play(track: nil)
            return
        }
        
        let track = self.playlist.track(at: self.playingIndex!)
        self.play(track: track)
        
        if track == nil {
            self.playingIndex = nil
        }
    }
    
    @IBAction func nextTrack(_ sender: Any) {
        self.play(moved: 1)
    }
    
    @IBAction func previousTrack(_ sender: Any) {
        self.play(moved: -1)
    }
        
    @IBAction func clickSpectrumView(_ sender: Any) {
        self.player.setPosition(self._spectrumView.getBy(player: self.player)!)
    }
    
    @IBAction func toggleShuffle(_ sender: Any) {
        shuffle = !shuffle
        let img = NSImage(named: NSImage.Name(rawValue: "shuffle"))
        _shuffle.image = shuffle ? img : img?.tinted(in: NSColor.gray)
    }
    
    func play(_ track: Track, at: Int) {
        self.playlist = trackController.playlist
        self.playingIndex = at
        self.play(track: track)
    }
    
    func playlistSelected(_ playlist: Playlist) {
        trackController.playlist = playlist
    }
}

