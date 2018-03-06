//
//  TrackController.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 23.02.18.
//  Copyright © 2018 ivorius. All rights reserved.
//

import Cocoa

import AVFoundation

class PlayHistorySetup {
    var completion: (PlayHistory) -> Swift.Void
    
    init(completion: @escaping (PlayHistory) -> Swift.Void) {
        self.completion = completion
    }
    
    var semaphore = DispatchSemaphore(value: 1)
    var _changed = false
    
    var filter: ((Track) -> Bool)? {
        didSet {
            _changed = true
        }
    }
    
    var sort: ((Track, Track) -> Bool)? {
        didSet {
            _changed = true
        }
    }
}

class TrackController: NSViewController {
    @IBOutlet var _tableView: NSTableView!
    @IBOutlet weak var _searchField: NSSearchField!
    @IBOutlet var _searchBarHeight: NSLayoutConstraint!
    @IBOutlet weak var _searchBarClose: NSButton!
    
    @IBOutlet weak var _sortLabel: NSTextField!
    @IBOutlet weak var _sortBar: NSView!
    
    var playTrack: ((Track, Int, Double?) -> Swift.Void)?
    
    @IBOutlet weak var _menuRemoveFromPlaylist: NSMenuItem!
    
    var history: PlayHistory! {
        didSet {
            _tableView.reloadData()
        }
    }
    var desired: PlayHistorySetup!
    
    var isDark: Bool {
        return self.view.window!.appearance?.name == NSAppearance.Name.vibrantDark
    }
    
    override func awakeFromNib() {
        desired = PlayHistorySetup { self.history = $0 }
        
        _tableView.registerForDraggedTypes([Track.pasteboardType])
        _tableView.setDraggingSourceOperationMask(.every, forLocal: false) // ESSENTIAL
        
        _searchBarHeight.constant = CGFloat(0)
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            return self.keyDown(with: $0)
        }
    }
    
    override func viewDidAppear() {
        // Appearance is not yet set in willappear
        _tableView.backgroundColor = isDark ? NSColor(white: 0.07, alpha: 1.0) : NSColor(white: 0.73, alpha: 1.0)
    
        // Hide border by painting it in the background color
        // TODO Match window bg color exactly - it returns white by default...
        _tableView.headerView!.wantsLayer = true
        _tableView.headerView!.layer!.borderColor = (isDark ? NSColor(white: 0.12, alpha: 1.0) : NSColor(white: 1, alpha: 1.0)).cgColor
        _tableView.headerView!.layer!.borderWidth = 1
    }
    
    func set(playlist: PlaylistProtocol) {
        self.history = PlayHistory(playlist: playlist)
        
        if self.desired.filter != nil || self.desired.sort != nil {
            self.desired._changed = true // The new history doesn't yet have our desireds applied
        }
    }
    
    var visibleTracks: [Track] {
        var tracks: [Track] = []
        
        if let visibleRect = self._tableView.enclosingScrollView?.contentView.visibleRect {
            let visibleRows = self._tableView.rows(in: visibleRect)
            
            for row in visibleRows.lowerBound...visibleRows.upperBound {
                if let track = history.track(at: row) {
                    tracks.append(track)
                }
            }
        }
        
        return tracks
    }
    
    var selectedTrack: Track? {
        let row = self._tableView.selectedRow
        return row >= 0 ? history.track(at: row) : nil
    }
    
    func playCurrentTrack() {
        if let selectedTrack = selectedTrack, let playTrack = playTrack {
            playTrack(selectedTrack, self._tableView.selectedRow, nil)
        }
    }
    
    @IBAction func doubleClick(_ sender: Any) {
        let row = self._tableView.clickedRow
        
        if let playTrack = playTrack {
            if let track = history.track(at: row) {
                playTrack(track, row, nil)
            }
        }
    }
    
    @IBAction func menuPlay(_ sender: Any) {
        self.doubleClick(sender)
    }
    
    @IBAction func menuShowInFinder(_ sender: Any) {
        let row = self._tableView.clickedRow
        let track = history.track(at: row)!
        if let url = track.url { // TODO Disable Button if we can't find the url
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }
    
    func keyDown(with event: NSEvent) -> NSEvent? {
        if Keycodes.enterKey.matches(event: event) || Keycodes.returnKey.matches(event: event) {
            self.playCurrentTrack()
        }
        else {
            return event
        }
        
        return nil
    }
    
    func reload(track: Track) {
        if let row = history.indexOf(track: track) {
            _tableView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(0..<_tableView.numberOfColumns))
        }
    }
    
    @IBAction func spectrumViewClicked(_ sender: Any?) {
        if let view = sender as? TrackSpectrumView {
            if let row = view.superview ?=> _tableView.row, let track = history.track(at: row), let playTrack = playTrack {
                playTrack(track, row, view.location)
            }
            
            view.location = nil
        }
    }
    
    func remove(indices: [Int]?) {
        if let indices = indices {
            Library.shared.remove(tracks: indices.flatMap { history.track(at: $0) }, from: history.playlist as! PlaylistManual)
            // Don't reload data, we'll be updated in async
        }
    }
}

extension TrackController: NSTableViewDelegate {
    fileprivate enum CellIdentifiers {
        static let artwork = NSUserInterfaceItemIdentifier(rawValue: "artworkCell")
        static let waveform = NSUserInterfaceItemIdentifier(rawValue: "waveformCell")
        static let title = NSUserInterfaceItemIdentifier(rawValue: "titleCell")
        static let genre = NSUserInterfaceItemIdentifier(rawValue: "genreCell")
        static let bpm = NSUserInterfaceItemIdentifier(rawValue: "bpmCell")
        static let key = NSUserInterfaceItemIdentifier(rawValue: "keyCell")
        static let duration = NSUserInterfaceItemIdentifier(rawValue: "durationCell")
    }
    
    fileprivate enum ColumnIdentifiers {
        static let artwork = NSUserInterfaceItemIdentifier(rawValue: "artworkColumn")
        static let waveform = NSUserInterfaceItemIdentifier(rawValue: "waveformColumn")
        static let title = NSUserInterfaceItemIdentifier(rawValue: "titleColumn")
        static let genre = NSUserInterfaceItemIdentifier(rawValue: "genreColumn")
        static let bpm = NSUserInterfaceItemIdentifier(rawValue: "bpmColumn")
        static let key = NSUserInterfaceItemIdentifier(rawValue: "keyColumn")
        static let duration = NSUserInterfaceItemIdentifier(rawValue: "durationColumn")
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let track = history.track(at: row)!
        
        if tableColumn?.identifier == ColumnIdentifiers.artwork, let view = tableView.makeView(withIdentifier: CellIdentifiers.artwork, owner: nil) as? NSImageView {
            view.wantsLayer = true
            
            view.layer!.borderWidth = 1.0
            view.layer!.borderColor = NSColor.lightGray.cgColor.copy(alpha: CGFloat(0.333))
            view.layer!.cornerRadius = 3.0
            view.layer!.masksToBounds = true

            view.image = track.rPreview

            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.waveform, let view = tableView.makeView(withIdentifier: CellIdentifiers.waveform, owner: nil) as? TrackSpectrumView {
            
            // Doesn't work from interface builder
            view.target = self
            view.action = #selector(spectrumViewClicked)
            
            // More detailed
            view.barWidth = 1
            view.spaceWidth = 1
            
            // For the small previews, less fps is enough (for performance)
            view.updateTime = 1 / 10
            view.lerpRatio = 1 / 2
            view.completeTransitionSteps = 6

            view.setInstantly(analysis: track.analysis)
            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.title, let view = tableView.makeView(withIdentifier: CellIdentifiers.title, owner: nil) as? TitleSubtitleCellView {
            view.textField?.stringValue = track.rTitle
            view.subtitleTextField?.stringValue = track.rSource
            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.genre, let view = tableView.makeView(withIdentifier: CellIdentifiers.genre, owner: nil) as? NSTableCellView {
            view.textField?.stringValue = track.genre ?? ""
            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.bpm, let view = tableView.makeView(withIdentifier: CellIdentifiers.bpm, owner: nil) as? NSTableCellView {
            view.textField?.stringValue = (track.bpm ?=> String.init) ?? ""
            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.key, let view = tableView.makeView(withIdentifier: CellIdentifiers.key, owner: nil) as? NSTableCellView {
            view.textField?.attributedStringValue = track.rKey
            view.textField?.setAlignment(.center) // Is reset when setting attributed string
            return view
        }
        else if tableColumn?.identifier == ColumnIdentifiers.duration, let view = tableView.makeView(withIdentifier: CellIdentifiers.duration, owner: nil) as? NSTableCellView {
            view.textField?.stringValue = track.rLength 
            return view
        }

        return nil
    }
    
    func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
        if let track = history.track(at: row) {
            let exists = track.url != nil
            if !exists {
                rowView.backgroundColor = NSColor(white: 0.03, alpha: 1.0)
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return VibrantTableRowView()
    }
    
    // Pasteboard, Dragging
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        Library.shared.writeTrack(history.track(at: row)!, toPasteboarditem: item)
        return item
    }
    
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above, Library.shared.isEditable(playlist: history.playlist), history.isUnsorted {
            return .move
        }
        return []
    }
    
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        let pasteboard = info.draggingPasteboard()
        let tracks = (pasteboard.pasteboardItems ?? []).flatMap(Library.shared.readTrack)
        
        Library.shared.addTracks(tracks, to: history.playlist as! PlaylistManual, above: row)
        Library.shared.save()

        return true
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        // TODO We only care about the first
        if let descriptor = tableView.sortDescriptors.first, let key = descriptor.key, key != "none" {
            switch key {
            case "title":
                desired.sort = { $0.rTitle < $1.rTitle }
            case "genre":
                desired.sort = { Optional<String>.compare($0.genre, $1.genre) }
            case "key":
                desired.sort = { Optional<Key>.compare($0.key, $1.key) }
            case "bpm":
                desired.sort = { ($0.bpm ?? 0) < ($1.bpm ?? 0)  }
            case "duration":
                desired.sort = { ($0.duration ?? kCMTimeZero) < ($1.duration ?? kCMTimeZero)  }
            default:
                fatalError("Unknown Sort Descriptor Key")
            }
            
            // Hax
            if !descriptor.ascending {
                let sorter = desired.sort!
                desired.sort = { !sorter($0, $1) }
            }
        }
        else {
            desired.sort = nil
        }
        
        desired._changed = true
    }
}

extension TrackController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return history.size;
    }
}

extension TrackController: NSSearchFieldDelegate {
    override func controlTextDidChange(_ obj: Notification) {
        desired.filter = PlayHistory.filter(findText: _searchField.stringValue)
    }
    
    func searchFieldDidEndSearching(_ sender: NSSearchField) {
        closeSearchBar(self)
    }
}

extension TrackController: NSMenuDelegate {
    var menuTracks: [Track] {
        return _tableView.clickedRows.flatMap { history.track(at: $0) }
    }
    
    func menuNeedsUpdate(_ menu: NSMenu) {
        if menuTracks.count < 1 {
            menu.cancelTrackingWithoutAnimation()
        }

        _menuRemoveFromPlaylist.isHidden = !Library.shared.isPlaylist(playlist: history.playlist)
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // Probably the main Application menu
        if menuItem.menu?.delegate !== self {
            return validateUserInterfaceItem(menuItem)
        }

        // Right Click Menu
        if menuItem == _menuRemoveFromPlaylist { return Library.shared.isEditable(playlist: history.playlist) }
        
        return true
    }
    
    @IBAction func removeTrack(_ sender: Any) {
        remove(indices: _tableView.clickedRows)
    }
    
    @IBAction func deleteTrack(_ sender: Any) {
        Library.shared.delete(tracks: menuTracks)
    }
}

extension TrackController: NSUserInterfaceValidations {
    
    func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else {
            return false
        }

        if action == #selector(delete as (AnyObject) -> Swift.Void) {
            return Library.shared.isEditable(playlist: history.playlist)
        }

        if action == #selector(performFindPanelAction) { return true }

        return false
    }
    
    @IBAction func delete(_ sender: AnyObject) {
        remove(indices: Array(_tableView.selectedRowIndexes))
    }
    
    @IBAction func performFindPanelAction(_ sender: AnyObject) {
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.2
            _searchBarHeight.animator().constant = CGFloat(26)
        })
        _searchField.window?.makeFirstResponder(_searchField)
    }
    
    @IBAction func closeSearchBar(_ sender: Any) {
        desired.filter = nil
        
        _searchField.resignFirstResponder()
        NSAnimationContext.runAnimationGroup({_ in
            NSAnimationContext.current.duration = 0.2
            _searchBarHeight.animator().constant = CGFloat(0)
        })
        view.window?.makeFirstResponder(view)
    }
}

