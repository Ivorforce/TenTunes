//
//  PlayHistory.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 24.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

extension Array {
    mutating func removeAll(keepTrackOf index: inout Int, where remove: (Element) -> Bool) {
        let realisticIndex = (0...count).clamp(index)
        self[0..<realisticIndex].removeAll {
            let removed = remove($0)
            if removed { index -= 1 }
            return removed
        }
        self[realisticIndex..<count].removeAll(where: remove)
    }
}

class PlayHistory {
    var playlist: PlaylistProtocol

    var order: [Track]
    var shuffled: [Track]?
    var playingIndex: Int = -1
    
    init(playlist: PlaylistProtocol) {
        self.playlist = playlist
        self.order = Array(playlist.tracksList)
    }
    
    init(from: PlayHistory) {
        playlist = from.playlist
        
        order = from.order
        playingIndex = from.playingIndex
    }
    
    var isUntouched: Bool {
        return order == Array(playlist.tracksList)
    }
    
    var isUnsorted: Bool {
        return order.sharesOrder(with: playlist.tracksList)
    }
    
    func convert(to mox: NSManagedObjectContext) {
        playlist = playlist.convert(to: mox) ?? PlaylistEmpty()
        order = mox.compactConvert(order)
        shuffled = shuffled ?=> mox.compactConvert
    }
        
    // Order, Filter
    func filter(by filter: @escaping (Track) -> Bool) {
        if shuffled != nil {
            shuffled!.removeAll(keepTrackOf: &playingIndex) { !filter($0) }
            order.removeAll { !filter($0) }
        }
        else {
            order.removeAll(keepTrackOf: &playingIndex) { !filter($0) }
        }
    }
    
    static func filter(findText text: String?) -> ((Track) -> Bool)? {
        guard let text = text, text.count > 0 else {
            return nil
        }
        
        let terms = (text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty })
            .map { $0.lowercased() }
        return { (track) in
            return terms.allSatisfy { (term) -> Bool in
                return track.searchable.anySatisfy { (key) -> Bool in
                    return key.lowercased().contains(term)
                }
            }
        }
    }
    
    func sort(by sort: (Track, Track) -> Bool) {
        let playing = order[safe: playingIndex]
        
        order = order.sorted(by: sort)
        
        if shuffled == nil, let playing = playing {
            playingIndex = order.index(of: playing)!
        }
    }
    
    func unshuffle() {
        let playing = playingTrack
        shuffled = nil
        if let playing = playing {
            playingIndex = order.index(of: playing)!
        }
        // Else we were at start or end
    }
    
    func shuffle() {
        let playing = playingTrack
        
        shuffled = order
        shuffled!.shuffle()
        
        if let playing = playing {
            let idx = shuffled!.index(of: playing)!
            shuffled?.swapAt(0, idx)
            playingIndex = 0
        }
    }
    
    func insert(tracks: [Track], before: Int) {
        if shuffled != nil  { shuffled!.insert(contentsOf: tracks, at: min(shuffled!.count, before)) }
        else                { order.insert(contentsOf: tracks, at: min(order.count, before)) }
    }

    func rearrange(tracks: [Track], before: Int) {
        // TODO Doesn't work with the same track being in the playlist twice

        let playing = playingTrack
        
        if shuffled != nil  { shuffled!.rearrange(elements: tracks, to: before) }
        else                { order.rearrange(elements: tracks, to: before) }
        
        if let previous = playing {
            playingIndex = indexOf(track: previous)! 
        }
    }
    
    func remove(indices: [Int]) {
        if shuffled != nil  { shuffled!.remove(at: indices) }
        else                { order.remove(at: indices) }
    }
    
    // Query
    
    var count: Int { return tracks.count }
    
    var tracks: [Track] {
        return shuffled ?? order
    }
    
    func track(at: Int) -> Track? {
        return tracks[safe: at]
    }
    
    func indexOf(track: Track) -> Int? {
        return tracks.index(of: track)
    }
    
    func move(to: Int) {
        playingIndex = (-1...(tracks.count > 0 ? tracks.count : -1)).clamp(to)
    }
    
    func move(by: Int) -> Track? {
        move(to: playingIndex + by)
        return track(at: playingIndex)
    }
    
    var playingTrack: Track? { return track(at: playingIndex) }
}
