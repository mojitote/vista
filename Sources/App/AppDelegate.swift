import Cocoa
import SwiftUI
import HotKey
import Combine

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
    private var presentationStore = SidebarPresentationStore()
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()
    private var popupAnchor: (screen: NSScreen, mousePosition: NSPoint)?
    
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
            presentationStore: presentationStore,
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
            self?.popupAnchor = nil
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
        
        applyTriggerMode(settingsStore.triggerMode, initial: true)
        
        // Initialize Hot Keys
        hotKeysManager = HotKeysManager()
        hotKeysManager.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }
        // 使用用户保存的快捷键，否则默认 Option+Tab
        let keyCombo = settingsStore.sidebarKeyCombo ?? KeyCombo(key: .tab, modifiers: .option)
        hotKeysManager.updateSidebarHotKey(keyCombo: keyCombo)
        
        // Scene 快捷键
        hotKeysManager.onGotoScene = { [weak self] scene in
            self?.sidebarViewModel.gotoScene(scene)
        }
        hotKeysManager.onActivateAll = { [weak self] in
            self?.sceneStore.activateScene(id: SceneStore.allSceneID)
        }
        hotKeysManager.updateSceneHotKeys(scenes: sceneStore.scenes)
        hotKeysManager.updateAllHotKey(keyCode: sceneStore.allHotkeyKeyCode, modifiers: sceneStore.allHotkeyModifiers)
        
        // 监听 sceneStore 变化，更新快捷键
        sceneStore.$scenes
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scenes in
                self?.hotKeysManager.updateSceneHotKeys(scenes: scenes)
            }
            .store(in: &cancellables)
        
        sceneStore.$allHotkeyKeyCode
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.hotKeysManager.updateAllHotKey(keyCode: self.sceneStore.allHotkeyKeyCode, modifiers: self.sceneStore.allHotkeyModifiers)
            }
            .store(in: &cancellables)
        
        // Initialize Menu Bar
        menuBarManager = MenuBarManager()
        menuBarManager.onToggleSidebar = { [weak self] in
            self?.toggleSidebar()
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        menuBarManager.onOpenOnboarding = {
            OnboardingWindowController.shared.show()
        }
        menuBarManager.setup()
        
        // 首次启动 / 关键依赖缺失时自动弹出向导
        OnboardingWindowController.shared.showIfFirstLaunch()
        
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
        
        sidebarViewModel.$displayGroups
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopupLayoutIfNeeded()
            }
            .store(in: &cancellables)
        
        sceneStore.$scenes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopupLayoutIfNeeded()
            }
            .store(in: &cancellables)
        
        sceneStore.$activeSceneID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.presentationStore.mode == .popup && self.sidebarPanel.isVisible {
                    self.sidebarPanel.suppressDismissTemporarily()
                }
                self.updatePopupLayoutIfNeeded()
                self.applySidebarColor()
            }
            .store(in: &cancellables)
        
        settingsStore.$sidebarWidth
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePopupLayoutIfNeeded()
            }
            .store(in: &cancellables)
        
        // 监听毛玻璃 / tint / 渐变设置变化，即时应用
        Publishers.MergeMany(
            settingsStore.$sidebarBlurMaterial.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarColorMode.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarColorHex.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarOpacity.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarGradientColors.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarGradientAngle.map { _ in () }.eraseToAnyPublisher(),
            settingsStore.$sidebarGradientTexture.map { _ in () }.eraseToAnyPublisher()
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.applySidebarAppearance()
        }
        .store(in: &cancellables)
        
        // 同步 launch-at-login 到系统
        LaunchAtLoginService.syncIfNeeded(enabled: settingsStore.launchAtLogin)
        settingsStore.$launchAtLogin
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { enabled in
                LaunchAtLoginService.setEnabled(enabled)
            }
            .store(in: &cancellables)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    // MARK: - Sidebar Control
    
    private func showSidebar(on screen: NSScreen) {
        guard !sidebarPanel.isVisible else { return }
        presentationStore.mode = .fullHeight
        popupAnchor = nil
        
        sidebarPanel.show(on: screen, width: settingsStore.sidebarWidth)
        applySidebarAppearance()
        updateActiveDisplay(for: screen)
        sidebarViewModel.loadData()
        sidebarViewModel.startPolling()
    }
    
    private func showSidebarAtPosition(on screen: NSScreen, mousePosition: NSPoint) {
        guard !sidebarPanel.isVisible else {
            // 三指点击时如果已经显示则关闭
            dismissSidebar()
            return
        }
        presentationStore.mode = .popup
        popupAnchor = (screen, mousePosition)
        let height = popupPanelHeight(for: screen, mousePosition: mousePosition)
        presentationStore.popupContentMaxHeight = popupContentMaxHeight(forPanelHeight: height)
        sidebarPanel.showAtPosition(
            on: screen,
            mousePosition: mousePosition,
            width: settingsStore.sidebarWidth,
            height: height
        )
        applySidebarAppearance()
        updateActiveDisplay(for: screen)
        sidebarViewModel.loadData()
        sidebarViewModel.startPolling()
    }
    
    /// 把 NSScreen 映射到 yabai display index：
    /// 1) 通过 NSScreen 的 NSDeviceDescription 拿到 CGDirectDisplayID。
    /// 2) 用 CGDisplayCreateUUIDFromDisplayID 得到 UUID 字符串。
    /// 3) 在 sidebarViewModel.displayGroups 里匹配 uuid。
    /// 任何步骤失败时回落到 frame 匹配（NSScreen.frame ≈ yabai display.frame）。
    private func updateActiveDisplay(for screen: NSScreen) {
        guard !sidebarViewModel.displayGroups.isEmpty else {
            // 数据还没载入，先记着；等 displayGroups 更新后由外部观察者补一次。
            // 这里靠 polling 后下一帧 UI 用 fallback.first 兜底，问题不大。
            return
        }
        if let uuid = screenUUIDString(for: screen),
           let g = sidebarViewModel.displayGroups.first(where: { $0.uuid == uuid }) {
            sidebarViewModel.activeDisplayIndex = g.index
            return
        }
        // fallback：找 frame 最匹配的
        let target = screen.frame
        if let g = sidebarViewModel.displayGroups.min(by: { distance($0.frame, target) < distance($1.frame, target) }) {
            sidebarViewModel.activeDisplayIndex = g.index
        }
    }
    
    private func screenUUIDString(for screen: NSScreen) -> String? {
        guard let raw = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        let displayID = CGDirectDisplayID(raw.uint32Value)
        guard let uuidRef = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuidRef) as String
    }
    
    private func distance(_ a: YabaiFrame, _ b: NSRect) -> CGFloat {
        let dx = a.x - b.origin.x
        let dy = a.y - b.origin.y
        return dx * dx + dy * dy
    }
    
    /// 切换触发模式。initial=true 时只在 `threeFingerTap` 下才启动 trackpad，
    /// 否则始终按新模式重启动相应 manager。
    private func applyTriggerMode(_ mode: SidebarTriggerMode, initial: Bool = false) {
        switch mode {
        case .hotZoneAndHotKey:
            trackpadManager.isEnabled = false
            trackpadManager.stop()
            hotZoneManager.isEnabled = settingsStore.hotZoneEnabled
            hotZoneManager.start()
        case .threeFingerTap:
            // 初始化时仍 start hotZone（但 disabled）以便后续切换时免 start
            hotZoneManager.isEnabled = false
            if initial {
                hotZoneManager.start()
            } else {
                hotZoneManager.stop()
            }
            trackpadManager.isEnabled = true
            trackpadManager.start()
        }
    }
    
    private func dismissSidebar() {
        popupAnchor = nil
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
        // 设置窗口期间 sidebar 不应自动消失，方便实时预览
        sidebarPanel.isDismissSuspended = true
        
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
        if sender === settingsWindow {
            sidebarPanel.isDismissSuspended = false
        }
        return false
    }
    
    private func updatePopupLayoutIfNeeded() {
        guard presentationStore.mode == .popup,
              sidebarPanel.isVisible,
              let popupAnchor else { return }
        let height = popupPanelHeight(for: popupAnchor.screen, mousePosition: popupAnchor.mousePosition)
        presentationStore.popupContentMaxHeight = popupContentMaxHeight(forPanelHeight: height)
        sidebarPanel.resizePopup(
            on: popupAnchor.screen,
            mousePosition: popupAnchor.mousePosition,
            width: settingsStore.sidebarWidth,
            height: height
        )
    }
    
    /// 根据激活 Scene 更新面板底色：有 Scene 用主题色，否则用用户设置的颜色/渐变
    private func applySidebarColor() {
        // Scene 主题色优先覆盖用户设置
        if let scene = sceneStore.activeScene {
            if !scene.gradientColors.isEmpty {
                let nsColors = scene.gradientColors.compactMap { NSColor(hex: $0) }
                if !nsColors.isEmpty {
                    sidebarPanel.updateSidebarGradient(
                        colors: nsColors,
                        angle: scene.gradientAngle,
                        opacity: scene.colorOpacity
                    )
                    return
                }
            }
            if let color = NSColor(hex: scene.colorHex) {
                sidebarPanel.updateSidebarColor(color: color, opacity: scene.colorOpacity)
                return
            }
        }
        
        // Fallback to global settings
        switch settingsStore.sidebarColorMode {
        case .gradient:
            let nsColors = settingsStore.sidebarGradientNSColors
            if !nsColors.isEmpty {
                sidebarPanel.updateSidebarGradient(
                    colors: nsColors,
                    angle: settingsStore.sidebarGradientAngle,
                    opacity: settingsStore.sidebarOpacity
                )
            } else {
                sidebarPanel.updateSidebarColor(color: nil, opacity: 0)
            }
        case .solid:
            sidebarPanel.updateSidebarColor(color: settingsStore.sidebarNSColor, opacity: settingsStore.sidebarOpacity)
        }
    }
    
    /// 同时应用毛玻璃 material + tint 颜色
    private func applySidebarAppearance() {
        sidebarPanel.updateBlurMaterial(settingsStore.sidebarBlurMaterial.nsMaterial)
        applySidebarColor()
    }
    
    private func popupPanelHeight(for screen: NSScreen, mousePosition: NSPoint) -> CGFloat {
        let availableHeight = max(
            AppConstants.popupMinHeight,
            mousePosition.y - screen.visibleFrame.minY
        )
        return min(estimatedPopupHeight(), availableHeight)
    }
    
    private func popupContentMaxHeight(forPanelHeight panelHeight: CGFloat) -> CGFloat {
        max(80, panelHeight - AppConstants.popupHeaderHeight)
    }
    
    private func estimatedPopupHeight() -> CGFloat {
        if !sidebarViewModel.isYabaiRunning {
            return 220
        }
        
        if sidebarViewModel.isLoading && sidebarViewModel.displayGroups.isEmpty {
            return 150
        }
        
        let groups = sidebarViewModel.filteredDisplayGroups
        var height = AppConstants.popupHeaderHeight + AppConstants.popupSectionTopBottomPadding
        
        for group in groups {
            height += AppConstants.popupDisplayHeaderHeight
            for space in group.spaces {
                height += AppConstants.popupSpaceRowHeight
                if space.isExpanded {
                    height += CGFloat(space.windows.count) * AppConstants.popupWindowRowHeight
                }
            }
            height += AppConstants.popupSectionDividerHeight
        }
        
        height += AppConstants.popupSceneHeaderHeight
        if sceneStore.scenes.isEmpty {
            height += AppConstants.popupEmptySceneHeight
        } else {
            height += CGFloat(sceneStore.scenes.count) * AppConstants.popupSceneRowHeight
        }
        
        return max(AppConstants.popupMinHeight, height)
    }
}
