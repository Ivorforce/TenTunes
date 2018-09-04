//
//  FileImporter.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 11.05.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

extension Library.Import {
    func track(url: URL) -> Track? {
        // TODO Hash all audio some time and then check the hashes on import to avoid duplicates
        if let track = library.allTracks.tracksList.filter({ $0.url == url }).first {
            return track
        }

        let track = Track(context: Library.shared.viewContext)
        
        track.path = url.absoluteString // Possibly temporary location
        track.title = url.lastPathComponent // Temporary title
        
        context.insert(track)
        
        Library.shared.initialAdd(track: track)
        
        return track
    }
}
