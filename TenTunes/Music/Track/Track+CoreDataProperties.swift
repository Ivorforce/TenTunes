//
//  Track+CoreDataProperties.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 04.03.18.
//  Copyright © 2018 ivorius. All rights reserved.
//
//

import Foundation
import CoreData


extension Track {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Track> {
        return NSFetchRequest<Track>(entityName: "Track")
    }
    
    var forcedVisuals: TrackVisuals {
        if let visuals = visuals {
            return visuals
        }
        
        visuals = TrackVisuals(context: managedObjectContext!)
        return visuals!
    }

    @NSManaged public var id: UUID
    @NSManaged public var creationDate: NSDate
    
    @NSManaged public var album: String?
    @NSManaged public var albumArtist: String?
    @NSManaged public var author: String?
    @NSManaged public var loudness: Float
    @NSManaged public var bpmString: String?
    @NSManaged public var bitrate: Float
    @NSManaged public var comments: NSString?
    @NSManaged public var containingPlaylists: NSSet
    @NSManaged public var durationR: Int64
    @NSManaged public var genre: String?
    @NSManaged public var iTunesID: String?
    @NSManaged public var keyString: String?
    @NSManaged public var metadataFetchDate: Date?
    // Note: Might be a relative path from library location
    @NSManaged public var path: String?
    @NSManaged public var playCount: Int32
    @NSManaged public var relatedTracks: NSSet
    @NSManaged public var remixAuthor: String?
    @NSManaged public var title: String?
    @NSManaged public var trackNumber: Int16
    @NSManaged public var usesMediaDirectory: Bool
    @NSManaged public var visuals: TrackVisuals?
    @NSManaged public var year: Int16

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        creationDate = NSDate()
    }
}

// MARK: Generated accessors for containingPlaylists
extension Track {
    
    @objc(addContainingPlaylistsObject:)
    @NSManaged public func addToContainingPlaylists(_ value: PlaylistManual)
    
    @objc(removeContainingPlaylistsObject:)
    @NSManaged public func removeFromContainingPlaylists(_ value: PlaylistManual)
    
    @objc(addContainingPlaylists:)
    @NSManaged public func addToContainingPlaylists(_ values: NSSet)
    
    @objc(removeContainingPlaylists:)
    @NSManaged public func removeFromContainingPlaylists(_ values: NSSet)
    
}

// MARK: Generated accessors for relatedTracks
extension Track {
    
    @objc(addRelatedTracksObject:)
    @NSManaged public func addToRelatedTracks(_ value: Track)
    
    @objc(removeRelatedTracksObject:)
    @NSManaged public func removeFromRelatedTracks(_ value: Track)
    
    @objc(addRelatedTracks:)
    @NSManaged public func addToRelatedTracks(_ values: NSSet)
    
    @objc(removeRelatedTracks:)
    @NSManaged public func removeFromRelatedTracks(_ values: NSSet)
    
}
