//
//  PlaylistSmart+CoreDataClass.swift
//  
//
//  Created by Lukas Tenbrink on 19.07.18.
//
//

import Foundation
import CoreData

@objc(PlaylistSmart)
public class PlaylistSmart: Playlist {
    override var tracksList: [Track] {
        get {
            let all = managedObjectContext!.convert(Library.shared.allTracks.tracksList)
            return all.filter(filter(in: managedObjectContext!))
        }
    }
        
    func filter(in context: NSManagedObjectContext) -> (Track) -> Bool {
        return rules?.filter(in: context) ?? { _ in false }
    }
}