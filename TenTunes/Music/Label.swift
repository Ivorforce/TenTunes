//
//  Label.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 19.07.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

@objc public class PlaylistRules : NSObject, NSCoding {
    var labels: [Label]

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(labels, forKey: "labels")
    }
    
    func filter(in context: NSManagedObjectContext) -> ((Track) -> Bool) {
        let filters = labels.map { $0.filter(in: context) }
        return { track in
            return filters.allMatch { $0(track) }
        }
    }

    public required init?(coder aDecoder: NSCoder) {
        labels = aDecoder.decodeObject(forKey: "labels") as? [Label] ?? []
    }
    
    init(labels: [Label] = []) {
        self.labels = labels
    }
    
    public override var description: String {
        return "[\((labels.map { $0.representation() }).joined(separator: ", "))]"
    }
    
    public override var hashValue: Int {
        return (labels.map { $0.representation() }).reduce(0, { (hash, string) in
            hash ^ string.hash
        })
    }
    
    override public func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? PlaylistRules else {
            return false
        }
        
        return labels == object.labels
    }
}

@objc class Label : NSObject, NSCoding {
    func encode(with aCoder: NSCoder) {
        
    }
    
    override init() {
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        
    }
    
    func filter(in context: NSManagedObjectContext) -> (Track) -> Bool {
        return { _ in return false }
    }
    
    func representation(in context: NSManagedObjectContext? = nil) -> String { return "" }
    
    var data : NSData { return NSKeyedArchiver.archivedData(withRootObject: self) as NSData }
    
    override func isEqual(_ object: Any?) -> Bool {
        guard let object = object as? Label else {
            return false
        }
        return data == object.data
    }
}

class LabelSearch : Label {
    var string: String
    
    init(string: String) {
        self.string = string
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let string = aDecoder.decodeObject(forKey: "string") as? String else {
            return nil
        }
        self.string = string
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(string, forKey: "string")
        super.encode(with: aCoder)
    }
    
    override func filter(in context: NSManagedObjectContext?) -> (Track) -> Bool {
        return PlayHistory.filter(findText: string)!
    }
    
    override func representation(in context: NSManagedObjectContext? = nil) -> String {
        return "Search: " + string
    }
}

class LabelPlaylist : Label {
    var playlistID: NSManagedObjectID?
    var isTag: Bool
    
    init(playlist: Playlist?, isTag: Bool) {
        self.playlistID = playlist?.objectID
        self.isTag = isTag
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        playlistID = (aDecoder.decodeObject(forKey: "playlistID") as? URL) ?=> Library.shared.persistentStoreCoordinator.managedObjectID
        isTag = aDecoder.decodeBool(forKey: "isTag")
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(isTag, forKey: "isTag")
        aCoder.encode(playlistID?.uriRepresentation(), forKey: "playlistID")
        super.encode(with: aCoder)
    }
    
    func playlist(in context: NSManagedObjectContext) -> Playlist? {
        guard let playlistID = self.playlistID else {
            return nil
        }
        return Library.shared.playlist(byId: playlistID, in: context)
    }
    
    override func filter(in context: NSManagedObjectContext) -> (Track) -> Bool {
        guard let tracks = playlist(in: context)?.tracksList else {
            return super.filter(in: context)
        }
        
        let trackIDs = tracks.map { $0.objectID }
        
        return { track in
            return trackIDs.contains(track.objectID)
        }
    }
    
    override func representation(in context: NSManagedObjectContext? = nil) -> String {
        let playlistName = context != nil ? playlist(in: context!)?.name : playlistID?.description
        return (isTag ? "🏷 " : "📁 ") + (playlistName ?? "Invalid Playlist")
    }
}

class LabelAuthor : Label {
    var author: String
    
    init(author: String) {
        self.author = author
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let author = aDecoder.decodeObject(forKey: "author") as? String else {
            return nil
        }
        self.author = author
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(author, forKey: "author")
        super.encode(with: aCoder)
    }
    
    override func filter(in context: NSManagedObjectContext?) -> (Track) -> Bool {
        return { $0.rAuthor.lowercased() == self.author.lowercased() }
    }
    
    override func representation(in context: NSManagedObjectContext? = nil) -> String {
        return "👥 " + author
    }
}

class LabelAlbum : Label {
    var album: Album
    
    init(album: Album) {
        self.album = album
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let title = aDecoder.decodeObject(forKey: "title") as? String, let author = aDecoder.decodeObject(forKey: "author") as? String else {
            return nil
        }
        self.album = Album(title: title, by: author)
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(album.title, forKey: "title")
        aCoder.encode(album.author, forKey: "author")
        super.encode(with: aCoder)
    }
    
    override func filter(in context: NSManagedObjectContext?) -> (Track) -> Bool {
        return { Album(of: $0) == self.album }
    }
    
    override func representation(in context: NSManagedObjectContext? = nil) -> String {
        return "💿 \(album.title) 👥 \(album.author)"
    }
}

class LabelGenre : Label {
    var genre: String
    
    init(genre: String) {
        self.genre = genre
        super.init()
    }
    
    required init?(coder aDecoder: NSCoder) {
        guard let genre = aDecoder.decodeObject(forKey: "genre") as? String else {
            return nil
        }
        self.genre = genre
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(genre, forKey: "genre")
        super.encode(with: aCoder)
    }
    
    override func filter(in context: NSManagedObjectContext?) -> (Track) -> Bool {
        return { $0.genre?.lowercased() == self.genre.lowercased() }
    }
    
    override func representation(in context: NSManagedObjectContext? = nil) -> String {
        return "📗 " + genre
    }
}