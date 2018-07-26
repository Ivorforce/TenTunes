//
//  Playlist+CoreDataClass.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 03.03.18.
//  Copyright © 2018 ivorius. All rights reserved.
//
//

import Foundation
import CoreData

@objc(Playlist)
public class Playlist: NSManagedObject, PlaylistProtocol {
    
    static let pasteboardType = NSPasteboard.PasteboardType(rawValue: "tentunes.playlist")

    func convert(to: NSManagedObjectContext) -> Self? {
        return to.convert(self)
    }
    
    public override init(entity: NSEntityDescription, insertInto context: NSManagedObjectContext?) {
        super.init(entity: entity, insertInto: context)
        
        NotificationCenter.default.addObserver(self, selector: #selector(managedObjectContextObjectsDidChange), name: .NSManagedObjectContextObjectsDidChange, object: context)
    }
    
    @IBAction func managedObjectContextObjectsDidChange(notification: NSNotification) {
        guard let userInfo = notification.userInfo else { return }
        
        let inserts = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let updates = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()
        let deletes = userInfo[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
        
        // Modified library?
        if !inserts.isEmpty || !updates.isEmpty || !deletes.isEmpty {
            _tracksList = nil
        }
    }
    
    var _tracksList: [Track]?
    var _freshTracksList: [Track] {
        return []
    }

    var tracksList: [Track] {
        get {
            if _tracksList == nil {
                _tracksList = _freshTracksList
            }
            
            return _tracksList!
        }
    }

    func track(at: Int) -> Track? {
        return tracksList[at]
    }
    
    var size: Int {
        return tracksList.count
    }
    
    var icon: NSImage {
        return #imageLiteral(resourceName: "playlist")
    }
}
