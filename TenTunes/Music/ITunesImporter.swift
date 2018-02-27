//
//  ITunesImporter.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 24.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

class ITunesImporter {
    static func parse(url: URL) -> Library? {
        guard let nsdict = NSDictionary(contentsOf: url) else {
            return nil
        }
        
        // TODO Store persistent IDs for playlists and tracks so we can automatically update them
        // i.e. We have a non-editable 'iTunes' folder that has a right click update and cannot be edit
        // Though it needs to be duplicatable into an editable copy
        
        let library = Library()
        
        var iTunesTracks: [Int:Track] = [:]
        var iTunesPlaylists: [String:Playlist] = [:]

        for (_, trackData) in nsdict.object(forKey: "Tracks") as! NSDictionary {
            let trackData = trackData as! NSDictionary
            
            let track = Track()
            
            track.title = trackData["Name"] as? String
            track.author = trackData["Artist"] as? String
            track.album = trackData["Album"] as? String
            track.path = trackData["Location"] as? String
            
            library.addTrackToLibrary(track)
            iTunesTracks[trackData["Track ID"] as! Int] = track
        }
        
        for playlistData in nsdict.object(forKey: "Playlists") as! NSArray {
            let playlistData = playlistData as! NSDictionary
            if playlistData.object(forKey: "Master") as? Bool ?? false {
                continue
            }
            if playlistData.object(forKey: "Distinguished Kind") as? Int != nil {
                continue // TODO At least give the option
            }
            
            let isFolder = playlistData.object(forKey: "Folder") as? Bool ?? false
            let playlist = Playlist(folder: isFolder)
            
            playlist.name = playlistData.object(forKey: "Name") as! String
            
            if !isFolder {
                for trackData in playlistData.object(forKey: "Playlist Items") as? NSArray ?? [] {
                    let trackData = trackData as! NSDictionary
                    let id = trackData["Track ID"] as! Int
                    playlist.tracks.append(iTunesTracks[id]!)
                }
            }
            
            if let parent = playlistData.object(forKey: "Parent Persistent ID") as? String {
                library.addPlaylist(playlist, to: iTunesPlaylists[parent]!)
            }
            else {
                library.addPlaylist(playlist)
            }
            
            iTunesPlaylists[playlistData.object(forKey: "Playlist Persistent ID") as! String] = playlist
        }
        
        return library
    }
}
