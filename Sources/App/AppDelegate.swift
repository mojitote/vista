import Cocoa
import SwiftUI
import HotKey
import Combine

private func vistaDebugReport(
    hypothesisId: String,
    location: String,
    msg: String,
    data: [String: Any] = [:]
) {
    // #region debug-point A:appdelegate-report
    guard let url = URL(string: "http://127.0.0.1:7777/event") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
        "sessionId": "trackpad-trigger-chain",
        "runId": "pre-fix",
        "hypothesisId": hypothesisId,
        "location": location,
        "msg": "[DEBUG] \(msg)",
        "data": data,
        "ts": Int(Date().timeIntervalSince1970 * 1000)
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request).resume()
    // #endregion
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
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
    private var cancellables = Set<AnyCancellable>()
    
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
            settingsStore: settingsStore,
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
        hotZoneManager.hotZoneWidth = settingsStore.hotZoneWidth
        hotZoneManager.onTrigger = { [weak self] screen in
            self?.showSidebar(on: screen)
        }
        
        // Initialize Trackpad Trigger
        trackpadManager = TrackpadTriggerManager()
        trackpadManager.onTrigger = { [weak self] mouseLocation, screen in
            self?.showSidebarAtPosition(on: screen, mousePosition: mouseLocation)
        }
        
        // 根据保存的模式决定初始状态
        if settingsStore.triggerMode == .threeFingerTap {
            hotZoneManager.isEnabled = false
            hotZoneManager.start()  // start 但 disabled，切换时不用重新 start
            trackpadManager.isEnabled = true
            trackpadManager.start()
            // #region debug-point A:initial-mode-three-finger
            vistaDebugReport(
                hypothesisId: "A",
                location: "AppDelegate.applicationDidFinishLaunching",
                msg: "initial mode applied",
                data: [
                    "mode": settingsStore.triggerMode.rawValue,
                    "hotZoneEnabled": hotZoneManager.isEnabled,
                    "trackpadEnabled": trackpadManager.isEnabled
                ]
            )
            // #endregion
        } else {
            hotZoneManager.isEnabled = settingsStore.hotZoneEnabled
            hotZoneManager.start()
            // trackpadManager 不 start，节省资源
            // #region debug-point A:initial-mode-hotzone
            vistaDebugReport(
                hypothesisId: "A",
                location: "AppDelegate.applicationDidFinishLaunching",
                msg: "initial mode applied",
                data: [
                    "mode": settingsStore.triggerMode.rawValue,
                    "hotZoneEnabled": hotZoneManager.isEnabled,
                    "trackpadEnabled": trackpadManager.isEnabled
                ]
            )
            // #endregion
        }
        
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
        
        // 监听设置变化，实时应用
        settingsStore.$triggerMode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMode in
                self?.applyTriggerMode(newMode)
            }
            .store(in: &cancellables)
        
        settingsStore.$hotZoneEnabled
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if self.settingsStore.triggerMode == .hotZoneAndHotKey {
                    self.hotZoneManager.isEnabled = enabled
                }
            }
            .store(in: &cancellables)
        
        settingsStore.$hotZoneWidth
            .dropFirst()
            .sink { [weak self] width in
                self?.hotZoneManager.hotZoneWidth = width
            }
            .store(in: &cancellables)
        
        settingsStore.$hotZoneDelay
            .dropFirst()
            .sink { [weak self] delay in
                self?.hotZoneManager.delay = delay
            }
            .store(in: &cancellables)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Sidebar Control
    
    private func showSidebar(on screen: NSScreen) {
        guard !sidebarPanel.isVisible else { return }
        // #region debug-point E:show-sidebar
        vistaDebugReport(
            hypothesisId: "E",
            location: "AppDelegate.showSidebar",
            msg: "showSidebar invoked",
            data: [
                "screenMinX": screen.frame.minX,
                "screenMinY": screen.frame.minY,
                "screenWidth": screen.frame.width,
                "screenHeight": screen.frame.height
            ]
        )
        // #endregion
        
        sidebarPanel.show(on: screen, width: settingsStore.sidebarWidth)
        sidebarPanel.updateSidebarColor(color: settingsStore.sidebarNSColor, opacity: settingsStore.sidebarOpacity)
        sidebarViewModel.loadData(withThumbnails: settingsStore.showThumbnails)
        sidebarViewModel.startPolling()
    }
    
    private func showSidebarAtPosition(on screen: NSScreen, mousePosition: NSPoint) {
        guard !sidebarPanel.isVisible else {
            // 三指点击时如果已经显示则关闭
            // #region debug-point E:toggle-sidebar-visible
            vistaDebugReport(
                hypothesisId: "E",
                location: "AppDelegate.showSidebarAtPosition",
                msg: "sidebar already visible, dismissing",
                data: [
                    "mouseX": mousePosition.x,
                    "mouseY": mousePosition.y
                ]
            )
            // #endregion
            dismissSidebar()
            return
        }
        // #region debug-point E:show-sidebar-at-position
        vistaDebugReport(
            hypothesisId: "E",
            location: "AppDelegate.showSidebarAtPosition",
            msg: "showSidebarAtPosition invoked",
            data: [
                "mouseX": mousePosition.x,
                "mouseY": mousePosition.y,
                "screenMinX": screen.frame.minX,
                "screenMaxX": screen.frame.maxX
            ]
        )
        // #endregion
        
        sidebarPanel.showAtPosition(
            on: screen,
            mousePosition: mousePosition,
            width: settingsStore.sidebarWidth
        )
        sidebarPanel.updateSidebarColor(color: settingsStore.sidebarNSColor, opacity: settingsStore.sidebarOpacity)
        sidebarViewModel.loadData(withThumbnails: settingsStore.showThumbnails)
        sidebarViewModel.startPolling()
    }
    
    private func applyTriggerMode(_ mode: SidebarTriggerMode) {
        // #region debug-point A:apply-trigger-mode-entry
        vistaDebugReport(
            hypothesisId: "A",
            location: "AppDelegate.applyTriggerMode",
            msg: "applyTriggerMode entry",
            data: [
                "mode": mode.rawValue,
                "settingsHotZoneEnabled": settingsStore.hotZoneEnabled,
                "currentTrackpadEnabled": trackpadManager.isEnabled,
                "currentHotZoneEnabled": hotZoneManager.isEnabled
            ]
        )
        // #endregion
        switch mode {
        case .hotZoneAndHotKey:
            // 关闭 trackpad
            trackpadManager.isEnabled = false
            trackpadManager.stop()
            // 恢复 hotZone
            hotZoneManager.isEnabled = settingsStore.hotZoneEnabled
            hotZoneManager.start()
            // #region debug-point A:apply-trigger-mode-hotzone
            vistaDebugReport(
                hypothesisId: "A",
                location: "AppDelegate.applyTriggerMode",
                msg: "applyTriggerMode exit hotZoneAndHotKey",
                data: [
                    "mode": mode.rawValue,
                    "hotZoneEnabled": hotZoneManager.isEnabled,
                    "trackpadEnabled": trackpadManager.isEnabled
                ]
            )
            // #endregion
        case .threeFingerTap:
            // 关闭 hotZone
            hotZoneManager.isEnabled = false
            hotZoneManager.stop()
            // 启动 trackpad
            trackpadManager.isEnabled = true
            trackpadManager.start()
            // #region debug-point A:apply-trigger-mode-trackpad
            vistaDebugReport(
                hypothesisId: "A",
                location: "AppDelegate.applyTriggerMode",
                msg: "applyTriggerMode exit threeFingerTap",
                data: [
                    "mode": mode.rawValue,
                    "hotZoneEnabled": hotZoneManager.isEnabled,
                    "trackpadEnabled": trackpadManager.isEnabled
                ]
            )
            // #endregion
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
        window.delegate = self
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }
    
    // MARK: - NSWindowDelegate
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // 隐藏窗口而不是关闭，避免 NSHostingView 渲染管线失效
        sender.orderOut(nil)
        return false
    }
}
