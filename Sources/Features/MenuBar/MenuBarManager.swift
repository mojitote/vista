import Cocoa

class MenuBarManager {
    
    private var statusItem: NSStatusItem?
    
    var onToggleSidebar: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "sidebar.left", accessibilityDescription: "Vista")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        
        let menu = NSMenu()
        
        let toggleItem = NSMenuItem(title: "Toggle Sidebar", action: #selector(toggleSidebar), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit Vista", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleSidebar() {
        onToggleSidebar?()
    }
    
    @objc private func openSettings() {
        onOpenSettings?()
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
