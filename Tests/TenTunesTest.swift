//
//  TestDatabase.swift
//  Tests
//
//  Created by Lukas Tenbrink on 04.02.19.
//  Copyright © 2019 ivorius. All rights reserved.
//

import XCTest

@testable import TenTunes

func XCTAssertFileExists(at url: URL,
                         file: StaticString = #file, line: UInt = #line) {
    XCTAssert(FileManager.default.fileExists(atPath: url.path), String(format: "File doesn't exist: %@", url.path),
              file: file, line: line)
}

func XCTAssertFileNotExists(at url: URL,
                            file: StaticString = #file, line: UInt = #line) {
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), String(format: "File exists: %@", url.path),
                   file: file, line: line)
}

class TenTunesTest: XCTestCase {
    var tracks: [Track] = []
    var groups: [PlaylistFolder] = []
    var tags: [PlaylistManual] = []

    var library: Library {
        return Library.shared
    }

    var context: NSManagedObjectContext {
        return library.viewContext
    }
    
    func create(tracks: Int = 0, groups: Int = 0, tags: Int = 0) {
        assert(self.tracks.isEmpty, "Tracks created twice")
        self.tracks = (0 ..< tracks).map { idx in
            let track = Track(context: self.context)
            track.title = String(format: "Track %d", idx)
            
            let file = String(format: "%@/%@.mp3", NSTemporaryDirectory(), UUID().uuidString)
            try! "sproing".write(toFile: file, atomically: true, encoding: .utf8)
            track.path = file
            
            return track
        }

        assert(self.groups.isEmpty, "Groups created twice")
        self.groups = (0 ..< groups).map { idx in
            let group = PlaylistFolder(context: self.context)
            group.name = String(format: "Group %d", idx)

            self.library[PlaylistRole.playlists].addToChildren(group)
            
            return group
        }
        
        assert(self.tags.isEmpty, "Tags created twice")
        self.tags = ((0 ..< tags).map { idx in
            let tag = PlaylistManual(context: self.context)
            tag.name = String(format: "Tag %d", idx)
            
            self.library[PlaylistRole.tags].addToChildren(tag)
            
            return tag
        })
        
        try! context.save()
    }
    
    func runSynchronousTask(_ task: Task) {
        task.waitOnExecute = true
        task.execute()
        
        XCTAssertTrue(task.completionRun)
    }
    
    override func setUp() {
        if !AppDelegate.isTest {
            fatalError("Not in a test environment!")
        }

        if library.directory.deletingLastPathComponent() != FileManager.default.temporaryDirectory {
            fatalError("Library is not temp directory")
        }

        if library.mediaLocation.directory.deletingLastPathComponent().deletingLastPathComponent() != FileManager.default.temporaryDirectory {
            fatalError("Media Directory is not temp directory")
        }
        
        if AppDelegate.defaults.bool(forKey: "WelcomeWindow") {
            fatalError("Welcome Window consumed! Most likely wrong user defaults!")
        }
    }

    override func tearDown() {
        // Delete all creations
        
        context.delete(all: groups)
        groups = []
        
        for track in tracks {
            try? (track.path.map(FileManager.default.removeItem))
        }
        context.delete(all: tracks)
        tracks = []
        
        context.delete(all: tags)
        tags = []
        
        try! context.save()
    }
}
