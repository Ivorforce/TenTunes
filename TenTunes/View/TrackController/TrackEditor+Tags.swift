//
//  TrackEditor+Tags.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 16.08.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

extension TrackEditor : TTTokenFieldDelegate {
    var viewTags : [Any] {
        return _editorOutline.children(ofItem: data[0]).compactMap { item in
            let view = _editorOutline.view(atColumn: 0, forItem: item, makeIfNecessary: false) as! NSTableCellView
            return view.textField!.objectValue as! [Any]
        }
    }
    
    func findShares<T : Hashable>(in ts: [Set<T>]) -> (Set<T>, Set<T>) {
        guard !ts.isEmpty else {
            return (Set(), Set())
        }
        
        return ts.dropFirst().reduce((Set(), ts.first!)) { (acc, t) in
            var (omitted, shared) = acc
            
            omitted = omitted.union(t.symmetricDifference(shared))
            shared = shared.intersection(t)
            
            return (omitted, shared)
        }
    }

    func tagResults(search: String, exact: Bool = false) -> [PlaylistManual] {
        return Library.shared.allTags(in: context).of(type: PlaylistManual.self).filter { exact ? $0.name.lowercased() == search : $0.name.lowercased().range(of: search) != nil }
            .sorted { (a, b) in a.name.count < b.name.count }
    }
    
    func tokenField(_ tokenField: NSTokenField, completionGroupsForSubstring substring: String, indexOfToken tokenIndex: Int, indexOfSelectedItem selectedIndex: UnsafeMutablePointer<Int>?) -> [TTTokenField.TokenGroup]? {
        let compareSubstring = substring.lowercased()
        var groups: [TTTokenField.TokenGroup] = []
        
        groups.append(.init(title: "Tag", contents: tagResults(search: compareSubstring)))
        
        return groups
    }
    
    func tokenField(_ tokenField: NSTokenField, displayStringForRepresentedObject representedObject: Any) -> String? {
        return (representedObject as? PlaylistManual)?.name ?? "<Multiple Values>"
    }
    
    func tokenField(_ tokenField: NSTokenField, changedTokens tokens: [Any]) {
        let newLabels = (tokenField.objectValue as! [Any]).of(type: Playlist.self) // First might be multiple values
        
        guard newLabels.count > 0 else {
            return
        }
        
        let labelPlaylists = tagTokens.of(type: Playlist.self)
        
        // Insert we don't add after add element
        let addLabels = newLabels.filter { label in !labelPlaylists.contains { $0 == label } } as [Any]
        tagTokens.insert(contentsOf: addLabels, at: tagTokens.count - 1)
        
        if var omitted = tagTokens[0] as? Set<Playlist> {
            omitted.remove(contentsOf: Set(newLabels.of(type: Playlist.self)))
            if omitted.isEmpty {
                tagTokens.remove(at: 0)
                // Little hacky but multiple values are always the first, and remove by item doesn't work because it's an array (copy by value)
                _editorOutline.removeItems(at: IndexSet(integer: 0), inParent: data[0], withAnimation: .slideDown)
            }
            else {
                tagTokens[0] = omitted
            }
        }
        
        tokensChanged()
        
        _editorOutline.insertItems(at: IndexSet(integersIn: (tagTokens.count - 2)..<(tagTokens.count + addLabels.count - 2)), inParent: data[0], withAnimation: .slideDown)

        tokenField.objectValue = []
    }
    
    func tokensChanged() {
        let labels = tagTokens
        let allowedOthers = labels.of(type: Set<PlaylistManual>.self).first ?? Set()
        let newTags = Set(labels.of(type: PlaylistManual.self))
        
        for track in tracks where track.tags != newTags {
            track.tags = newTags.union(track.tags.intersection(allowedOthers))
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        // TODO Hack, let LabelTextField observe this instead
        (obj.object as? TTTokenField)?.controlTextDidChange(obj)
    }
    
    func tokenField(_ tokenField: NSTokenField, shouldAdd tokens: [Any], at index: Int) -> [Any] {
        return tokens.compactMap {
            guard let compareSubstring = ($0 as? String)?.lowercased() else {
                return $0
            }
            
            if let match = tagResults(search: compareSubstring, exact: true).first {
                return match
            }
            
            // Must create a new one
            // TODO
            return nil
        }
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let labelField = control as? TTTokenField else {
            return false
        }
        
        if commandSelector == #selector(NSResponder.insertNewlineIgnoringFieldEditor(_:)) {
            // Use the first matching tag
            let compareSubstring = labelField.editingString.lowercased()
            
            let applicable = tagResults(search: compareSubstring)
            if let tag = applicable.first {
                labelField.autocomplete(with: tag)
            }

            // Always consume the alt enter
            return true
        }
        
        return false
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
        if let labelField = obj.object as? TTTokenField {
            labelField.objectValue = [] // Clear instead of letting it become a Token
        }
    }
}
