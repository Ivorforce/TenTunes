//
//  PlaylistSmart+CoreDataProperties.swift
//  
//
//  Created by Lukas Tenbrink on 19.07.18.
//
//

import Foundation
import CoreData

extension PlaylistSmart {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlaylistSmart> {
        return NSFetchRequest<PlaylistSmart>(entityName: "PlaylistSmart")
    }
    
    @NSManaged public var rules: SmartPlaylistRules!

    var rrules: SmartPlaylistRules {
        return rules ?? SmartPlaylistRules()
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        if rules == nil { rules = SmartPlaylistRules() }
    }
    
    public override func awakeFromFetch() {
        if rules == nil { rules = SmartPlaylistRules() }
    }
}
