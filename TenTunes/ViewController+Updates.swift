//
//  ViewController+Updates.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 25.03.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Foundation

extension ViewController {
    func registerObservers() {
        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(managedObjectContextObjectsDidChange), name: .NSManagedObjectContextObjectsDidChange, object: Library.shared.viewContext)
    }
    
    @IBAction func managedObjectContextObjectsDidChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        
        let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
        
        for update in updates {
            // Modified track info?
            if let track = update as? Track {
                trackController.reload(track: track)
            }
            
            // Modified playlist contents?
            if let playlist = update as? Playlist {
                // When deleting playlists the parent is updated since it loses a child
                if Library.shared.isAffected(playlist: trackController.history.playlist, whenChanging: playlist) {
                    trackController.desired._changed = true
                }
                
                if let listening = history?.playlist, Library.shared.isAffected(playlist: listening, whenChanging: playlist) {
                    let left = Set(self.history!.playlist.tracksList)
                    history!.filter { left.contains($0) }
                }
            }
        }

        // Modified library?
        if inserts.of(type: Track.self).count > 0 || deletes.of(type: Track.self).count > 0 {
            if trackController.history.playlist is PlaylistLibrary {
                trackController.desired._changed = true
            }
        }
        
        // Modified playlists?
        playlistController._outlineView.animateDelete(elements: Array(deletes.of(type: Playlist.self)))
        playlistController._outlineView.animateInsert(elements: Array(inserts.of(type: Playlist.self))) {
            let (parent, idx) = Library.shared.position(of: $0)!
            return (idx, parent == Library.shared.masterPlaylist ? nil : parent)
        }

        if let viewingPlaylist = trackController.history.playlist as? Playlist, deletes.of(type: Playlist.self).contains(viewingPlaylist) {
            
            // Deleted our current playlist! :<
            // TODO What to do when deleting listening playlist?
            trackController.set(playlist: Library.shared.allTracks)
        }
    }
}
