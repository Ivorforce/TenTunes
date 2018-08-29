//
//  Artist.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 29.08.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

class Artist {
    static let splitRegex = try! NSRegularExpression(pattern: "\\S*(,|(f(ea)?t(uring)?(.)?))\\S*", options: [])
    static let unknown = "Unknown Artist"
    
    let name: String
    
    init(name: String) {
        self.name = name
    }

    class func all(in string: String) -> [Artist] {
        return splitRegex.split(string: string).map(Artist.init)
    }
}

extension Artist : CustomStringConvertible {
    class func describe(_ artist: Artist?) -> String {
        return artist?.description ?? Artist.unknown
    }
    
    class func describe(_ artists: [Artist]) -> String {
        return artists.isEmpty ? Artist.unknown : artists.map { $0.description }.joined(separator: ", ")
    }
    
    var description: String {
        return name
    }
}

extension Artist : Hashable {
    var hashValue: Int {
        return name.lowercased().hashValue
    }
    
    static func == (lhs: Artist, rhs: Artist) -> Bool {
        return lhs.name.lowercased() == rhs.name.lowercased()
    }
}