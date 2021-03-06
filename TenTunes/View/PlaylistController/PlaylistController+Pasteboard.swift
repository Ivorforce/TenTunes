//
//  PlaylistController+Pasteboard.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 11.05.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

extension PlaylistController {
    var pasteboardTypes: [NSPasteboard.PasteboardType] {
        return Array(Set(PlaylistPromise.pasteboardTypes + TrackPromise.pasteboardTypes))
    }
    
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        return (item as? Item)?.asPlaylist.map(Library.shared.export().pasteboardItem)
    }
    
    func outlineView(_ outlineView: NSOutlineView, validateDrop info: NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
        let pasteboard = info.draggingPasteboard

        guard let item = self.item(raw: item), let playlist = item.asPlaylist else {
            return []
        }

        if TrackPromise.inside(pasteboard: pasteboard, for: Library.shared) != nil {
            return ((playlist as? ModifiablePlaylist)?.supports(action: .add) ?? false) ? .link : []
        }
        
        if PlaylistPromise.inside(pasteboard: pasteboard, for: Library.shared) != nil {
            // We can always rearrange, except into playlists
            guard let parent = playlist as? PlaylistFolder, !parent.automatesChildren else {
                return []
            }
            let playlists = (pasteboard.pasteboardItems ?? []).compactMap(Library.shared.import().playlist)

            guard playlists.allSatisfy({ Library.shared.isPlaylist(playlist: $0) == (item != masterItem) }) else {
                // Only allow special playlists in master playlist, but nowhere else
                return []
            }

            // If any dropping playlist contains (or is) the new parent, don't drop
            guard playlists.noneSatisfy({Library.find(parent: $0, of: parent)}) else {
                return []
            }
            
            return playlists.anySatisfy { $0.parent!.automatesChildren } ? .copy : .move
        }

        return []
    }
    
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        let pasteboard = info.draggingPasteboard
        
        guard let parent = (item as! Item).asPlaylist else {
            return false
        }
        
        if let promises = TrackPromise.inside(pasteboard: pasteboard, for: Library.shared) {
            guard (parent as! ModifiablePlaylist).confirm(action: .add) else {
                return false
            }

            let tracks = promises.compactMap { $0.fire() }
            (parent as! ModifiablePlaylist).addTracks(tracks)

            try! Library.shared.viewContext.save()
            return true
        }
        
        if let promises = PlaylistPromise.inside(pasteboard: pasteboard, for: Library.shared) {
            let playlists = promises.compactMap { $0.fire() }
                .map { $0.parent!.automatesChildren ? $0.duplicate() : $0 }
            
            for playlist in playlists {
                (parent as! PlaylistFolder).addPlaylist(playlist, above: index >= 0 ? index : nil)
            }
            
            try! Library.shared.viewContext.save()
            return true
        }
        
        return false
    }
}
