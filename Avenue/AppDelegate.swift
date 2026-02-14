//
//  AppDelegate.swift
//  Avenue
//
//  Created by Vincent on 7/7/19.
//  Copyright © 2019 Vincent. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var toggleMiniMap: NSMenuItem!
    
    // false == mini map will be SHOWN
    var hideMiniMap = false
    
    let launch = NSWindowController(windowNibName: "LaunchWindow")
    let prefs = Preferences.shared
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        let prefs = Preferences.shared.hideMiniMap
        hideMiniMap = prefs
        switchTitle(hideMiniMap)
        
        // to remove "Start Dictation" and "Emoji & Symbols" menu items.
        if let editMenu = NSApplication.shared.mainMenu?.item(withTitle: "Edit")?.submenu {
            if editMenu.items.last?.action?.description == "orderFrontCharacterPalette:" {
                editMenu.removeItem(at: editMenu.items.count - 1)
            }
            if editMenu.items.last?.action?.description == "orderFrontCharacterPalette:" {
                editMenu.removeItem(at: editMenu.items.count - 1)
            }
            if editMenu.items.last?.action?.description == "orderFrontCharacterPalette:" {
                editMenu.removeItem(at: editMenu.items.count - 1)
            }
            if editMenu.items.last?.action?.description == "startDictation:" {
                editMenu.removeItem(at: editMenu.items.count - 1)
            }
            if editMenu.items.last?.action?.description == "startDictation:" {
                editMenu.removeItem(at: editMenu.items.count - 1)
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        var openedAny = false
        for filename in filenames {
            let url = URL(fileURLWithPath: filename)
            let ext = url.pathExtension.lowercased()
            guard ext == "gpx" || ext == "rgp" else { continue }
            openedAny = openGPXCompatibleDocument(at: url) || openedAny
        }
        sender.reply(toOpenOrPrint: openedAny ? .success : .failure)
    }
    

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        print("Launch Screen will be launched")
        launch.showWindow(self)
        launch.window?.standardWindowButton(.zoomButton)?.isHidden = true
        launch.window?.standardWindowButton(.miniaturizeButton)?.isHidden = true
        disableViewMenuItem()
        return false
    }
    
    func closeLaunchWindow() {
        launch.window?.performClose(self)
    }
    
    @IBAction func hideMiniMapClicked(_ sender: NSMenuItem) {
        hideMiniMap = !hideMiniMap
        switchTitle(hideMiniMap)
        NotificationCenter.default.post(name: .miniMapAction, object: nil)
    }
    
    
    func switchTitle(_ state: Bool) {
        if state {
            //show mini map, meaning mini map is HIDDEN
            toggleMiniMap.title = "Show Mini Map"
        }
        else {
            toggleMiniMap.title = "Hide Mini Map"
        }
    }
    
    /// Disables entire "View" menu item
    func disableViewMenuItem() {
        let main = NSApplication.shared.menu?.item(withTitle: "View")
        main?.isHidden = true
    }
    
    /// Enables entire "View" menu item
    func enableViewMenuItem() {
        let main = NSApplication.shared.menu?.item(withTitle: "View")
        main?.isHidden = false
    }
    
    @IBAction func fileAnIssue(_ sender: Any) {
        NSWorkspace.shared.open(URL(string: "https://github.com/vincentneo/Avenue-GPX-Viewer/issues")!)
    }

    @IBAction func openSupportedDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedFileTypes = ["gpx", "rgp"]
        panel.allowsOtherFileTypes = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            _ = self.openGPXCompatibleDocument(at: url)
        }
    }

    @discardableResult
    private func openGPXCompatibleDocument(at url: URL) -> Bool {
        do {
            let controller = NSDocumentController.shared
            let document = Document()
            let data = try Data(contentsOf: url)
            try document.read(from: data, ofType: "GPX File")
            document.fileURL = url
            controller.addDocument(document)
            document.makeWindowControllers()
            document.showWindows()
            controller.noteNewRecentDocumentURL(url)
            return true
        } catch {
            NSApp.presentError(error)
            return false
        }
    }
    
}

extension NSNotification.Name {
    static let miniMapAction = Notification.Name("MiniMapAction")
}

extension NSApplication {
    @IBAction func openSupportedDocument(_ sender: Any?) {
        (delegate as? AppDelegate)?.openSupportedDocument(sender)
    }
}
