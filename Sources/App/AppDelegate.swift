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
    private var trackpadManager: TrackpadTriggerManager!
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
        
        // Initialize Trackpad Trigger
        trackpadManager = TrackpadTriggerManager()
        trackpadManager.isEnabled = settingsStore.triggerMode == .threeFingerTap
        trackpadManager.onTrigger = { [weak self] mouseLocation, screen in
            self?.showSidebarAtPosition(on: screen, mousePosition: mouseLocation)
        }
        trackpadManager.start()
        
        // 根据 trigger mode 启用/禁用对应管理器
        applyTriggerMode()
        
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
    
    private func showSidebarAtPosition(on screen: NSScreen, mousePosition: NSPoint) {
        guard !sidebarPanel.isVisible else {
            // 三指点击时如果已经显示则关闭
            dismissSidebar()
            return
        }
        
        // 在鼠标位置显示侧边栏
        let width = settingsStore.sidebarWidth
        let height = screen.visibleFrame.height
        let x = max(screen.frame.minX, min(mousePosition.x - width / 2, screen.frame.maxX - width))
        let y = screen.visibleFrame.minY
        
        sidebarPanel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        sidebarPanel.alphaValue = 0
        sidebarPanel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            sidebarPanel.animator().alphaValue = 1
        }
        sidebarPanel.updateSidebarColor(color: settingsStore.sidebarNSColor, opacity: settingsStore.sidebarOpacity)
        sidebarViewModel.loadData(withThumbnails: settingsStore.showThumbnails)
        sidebarViewModel.startPolling()
    }
    
    private func applyTriggerMode() {
        switch settingsStore.triggerMode {
        case .hotZoneAndHotKey:
            hotZoneManager.isEnabled = settingsStore.hotZoneEnabled
            trackpadManager.isEnabled = false
        case .threeFingerTap:
            hotZoneManager.isEnabled = false
            trackpadManager.isEnabled = true
        }
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
        // 复用已有窗口
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let settingsView = SettingsView(store: settingsStore)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 550),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Vista Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
}
