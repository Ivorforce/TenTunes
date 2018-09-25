//
//  PlaylistController+Menu.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 26.03.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Foundation

extension PlaylistController: NSUserInterfaceValidations {
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else {
            return false
        }
        
        if action == #selector(delete as (AnyObject) -> Swift.Void) {
            return selectedPlaylists.map({ $0.1 }).allSatisfy { Library.shared.isPlaylist(playlist: $0) && !$0.parent!.automatesChildren }
        }
        if action == #selector(performFindPanelAction) { return true }
        
        if action == #selector(newDocument(_:)) { return true }
        if action == #selector(createGroup(_:)) { return true }

        return false
    }
    
    @IBAction func delete(_ sender: AnyObject) {
        delete(indices: Array(_outlineView.selectedRowIndexes))
    }
    
    @IBAction func newDocument(_ sender: Any) {
        createPlaylist(sender)
    }
}
