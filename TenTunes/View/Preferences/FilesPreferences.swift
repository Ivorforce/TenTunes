//
//  ExportsPreferences.swift
//  TenTunes
//
//  Created by Lukas Tenbrink on 08.02.19.
//  Copyright © 2019 ivorius. All rights reserved.
//

import Cocoa
import Preferences

import Defaults

extension Defaults.Keys {
    static let forceSimpleFilePaths = Key<Bool>("forceSimpleFilePaths", default: true, suite: AppDelegate.defaults)

    static let skipExportITunes = Key<Bool>("skipExportITunes", default: false, suite: AppDelegate.defaults)
    static let skipExportM3U = Key<Bool>("skipExportM3U", default: false, suite: AppDelegate.defaults)
    static let skipExportAlias = Key<Bool>("skipExportAlias", default: false, suite: AppDelegate.defaults)

    enum InitialKeyWrite: String, Codable {
        case openKey = "openKey", camelot = "camelot", english = "english", german = "german"
        
        static let values: [InitialKeyWrite] = [.openKey, .camelot, .english, .german]
        
        var title: String {
            switch(self) {
            case .german: return "German"
            case .camelot: return "Camelot"
            case .openKey: return "Open Key"
            case .english: return "English"
            }
        }
    }

    static let initialKeyWrite = Key<InitialKeyWrite>("initialKeyWrite", default: .english, suite: AppDelegate.defaults)
}

class FilesPreferences: NSViewController, PreferencePane {
    var preferencePaneIdentifier = Preferences.PaneIdentifier.files
    var preferencePaneTitle = "Files"
    var toolbarItemIcon = NSImage(named: NSImage.Name.folderSmartName)!
    
    override var nibName: NSNib.Name? {
        return "FilesPreferences"
    }

    @IBOutlet var initialKeyWrite: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        PopupEnum<Defaults.Keys.InitialKeyWrite>.bind(initialKeyWrite, toUserDefaultsKey: .initialKeyWrite, with: Defaults.Keys.InitialKeyWrite.values, title: { $0.title })
    }
    
}
