import Cocoa
import SwiftUI
import HotKey

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var sidebarPanel: SidebarPanel!
    private var sidebarViewModel: SidebarViewModel!
    private var hotZoneManager: HotZoneManager!
    private var hotKeysManager: HotKeysManager!
    private var menuBarManager: MenuBarManager!
    private var settingsStore: SettingsStore!
    private var sceneStore: SceneStore!
    private var spaceNameStore: SpaceNameStore!
    private var settingsWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore.shared
        sceneStore = SceneStore.shared
        spaceNameStore = SpaceNameStore.shared
        
        // Initialize ViewModel
        sidebarViewModel = SidebarViewModel()
        sidebarViewModel.sceneStore = sceneStore
        
        // Initialize Sidebar Panel
        sidebarPanel = SidebarPanel()
        let sidebarView = SidebarView(
            viewModel: sidebarViewModel,
            sceneStore: sceneStore,
            spaceNameStore: spaceNameStore,
            onDismiss: { [weak self] in
                self?.dismissSidebar()
            },
            onOpenSettings: { [weak self] in
                self?.openSettings()
            }
        )
        sidebarPanel.setSwiftUIContent(sidebarView)
        sidebarPanel.onDismiss = { [weak self] in
            self?.sidebarViewModel.stopPolling()
        }
        
        // Initialize Hot Zone
        hotZoneManager = HotZoneManager()
        hotZoneManager.delay = settingsStore.hotZoneDelay
        hotZoneManager.isEnabled = settingsStore.hotZoneEnabled
        hotZoneManager.hotZoneWidth = settingsStore.hotZoneWidth
        hotZoneManager.onTrigger = { [weak self] screen in
            self?.showSidebar(on: screen)
        }
        hotZoneManager.start()
        
        // Initialize Hot Keys
        hotKeysManager = HotKeysManager()
        hotKeysManager.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }
        // 使用用户保存的快捷键，否则默认 Option+Tab
        let keyCombo = settingsStore.sidebarKeyCombo ?? KeyCombo(key: .tab, modifiers: .option)
        hotKeysManager.updateSidebarHotKey(keyCombo: keyCombo)
        
        // Initialize Menu Bar
        menuBarManager = MenuBarManager()
        menuBarManager.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        menuBarManager.setup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Sidebar Control
    
    private func showSidebar(on screen: NSScreen) {
        guard !sidebarPanel.isVisible else { return }
        
        sidebarPanel.show(on: screen, width: settingsStore.sidebarWidth)
        sidebarPanel.updateSidebarColor(color: settingsStore.sidebarNSColor, opacity: settingsStore.sidebarOpacity)
        sidebarViewModel.loadData(withThumbnails: settingsStore.showThumbnails)
        sidebarViewModel.startPolling()
    }
    
    private func dismissSidebar() {
        sidebarPanel.dismiss()
    }
    
    private func toggleSidebar() {
        if sidebarPanel.isVisible {
            dismissSidebar()
        } else {
            let mouseLocation = NSEvent.mouseLocation
            let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main ?? NSScreen.screens[0]
            showSidebar(on: screen)
        }
    }
    
    // MARK: - Settings
    
    private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(store: settingsStore)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vista Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}
