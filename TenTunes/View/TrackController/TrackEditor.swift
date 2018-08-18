//
//  FileTagEditor.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 10.03.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

class TrackEditor: NSViewController {
        
    var context: NSManagedObjectContext!
    @objc dynamic var tracks: [Track] = []
    @IBOutlet var tracksController: NSArrayController!
    
    var manyTracks: [Track] = []
    
    @IBOutlet var _contentView: NSView!
    @IBOutlet var _manyPlaceholder: NSView!
    @IBOutlet var _errorPlaceholder: NSView!
    @IBOutlet var _errorTextField: NSTextField!
    
    @IBOutlet var _tagEditor: LabelTextField!
    @IBOutlet var _editorOutline: NSOutlineView!
    
    override func viewDidLoad() {
        showError(text: "No Tracks Selected")
        _editorOutline.expandItem(nil, expandChildren: true)
    }
        
    func present(tracks: [Track]) {
        if tracks.count == 0 {
            showError(text: "No Tracks Selected")
        }
        else if tracks.contains(where: { $0.url == nil }) {
            // TODO Show what we know but don't make it editable
            showError(text: "Tracks Not Found")
        }
        else if tracks.count < 2 {
            show(tracks: tracks)
        }
        else {
            suggest(tracks: tracks)
        }
    }
    
    func show(tracks: [Track]) {
//        context = Library.shared.newConcurrentContext()
//        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy // User is always right
        context = Library.shared.viewContext
        self.tracks = context.compactConvert(tracks)
        
        _editorOutline.deselectAll(self) // Hack because selection looks shit but we need it for now
        
        for track in self.tracks {
            try! track.fetchMetadata()
        }
        
        let (omittedTags, sharedTags) = findShares(in: self.tracks.map { $0.tags })
        _tagEditor.objectValue = (omittedTags.count > 0 ? [omittedTags] as [AnyObject] : [])
            + (sharedTags.sorted { $0.name < $1.name } as [AnyObject])
        
        view.setFullSizeContent(_contentView)
    }
    
    func showError(text: String) {
        _errorTextField.stringValue = text
        view.setFullSizeContent(_errorPlaceholder)
    }
    
    func suggest(tracks: [Track]) {
        manyTracks = tracks
        
        view.setFullSizeContent(_manyPlaceholder)
    }
    
    @IBAction func trackChanged(_ sender: Any) {
        for track in tracks {
            // Don't call the collection method since it auto-saves in the wrong context
            Library.shared.mediaLocation.updateLocation(of: track)
        }
        
        try! context.save()

        for track in tracks {
            track.writeMetadata()
        }
    }
    
    @IBAction func showSuggestedTracks(_ sender: Any) {
        show(tracks: manyTracks)
    }
}

extension TrackEditor: NSOutlineViewDelegate {
    fileprivate enum CellIdentifiers {
        static let GroupTitleCell = NSUserInterfaceItemIdentifier(rawValue: "groupTitleCell")
        static let NameCell = NSUserInterfaceItemIdentifier(rawValue: "nameCell")
        static let ValueCell = NSUserInterfaceItemIdentifier(rawValue: "valueCell")
    }
    
    fileprivate enum ColumnIdentifiers {
        static let name = NSUserInterfaceItemIdentifier(rawValue: "nameColumn")
        static let value = NSUserInterfaceItemIdentifier(rawValue: "valueColumn")
    }
    
    typealias GroupData = (String, NSImage)
    typealias EditData = (String, String, [NSBindingOption: Any]?)
    
    var data : [(GroupData, [EditData])] {
        return [
            (("Musical", #imageLiteral(resourceName: "music")), [
                ("Genre", "genre", nil),
                ("BPM", "bpmString", nil),
                ("Initial Key", "keyString", nil),
            ]),
            (("Album", #imageLiteral(resourceName: "album")), [
                ("Album Artist", "albumArtist", nil),
                ("Year", "year", [.valueTransformerName: "IntStringNullable"]),
                ("Track No.", "trackNumber", [.valueTransformerName: "IntStringNullable"]),
            ]),
        ]
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return item == nil ? data.count : (item as! (GroupData, [EditData])).1.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        if let ((title, image), _) = item as? (GroupData, [EditData]) {
            switch tableColumn!.identifier {
            case ColumnIdentifiers.name:
                if let view = outlineView.makeView(withIdentifier: CellIdentifiers.GroupTitleCell, owner: nil) as? NSTableCellView {
                    view.textField?.stringValue = title
                    view.imageView?.image = image
                    return view
                }
            default:
                break
            }
        }
        else if let data = item as? EditData {
            switch tableColumn!.identifier {
            case ColumnIdentifiers.name:
                if let view = outlineView.makeView(withIdentifier: CellIdentifiers.NameCell, owner: nil) as? NSTableCellView {
                    view.textField?.stringValue = data.0
                    return view
                }
            case ColumnIdentifiers.value:
                if let view = outlineView.makeView(withIdentifier: CellIdentifiers.ValueCell, owner: nil) as? NSTableCellView {
                    view.textField?.bind(.value, to: tracksController, withKeyPath: "selection." + data.1, options: (data.2 ?? [:]).merging([.nullPlaceholder: "..."], uniquingKeysWith: { (a, _) in a }))
                    view.textField?.action = #selector(trackChanged(_:))
                    view.textField?.target = self
                    return view
                }
            default:
                break
            }
        }
        
        return nil
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return item == nil ? data[index] : (item as! (GroupData, [EditData])).1[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return item is (GroupData, [EditData])
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
        // TODO With this active we can't edit the cells
        return item is EditData
    }
}

extension TrackEditor: NSOutlineViewDataSource {
    
}
