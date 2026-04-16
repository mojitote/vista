import Cocoa
import Combine

// MARK: - View Data Models

struct WindowItem: Identifiable, Equatable {
    let id: Int
    let pid: Int
    let app: String
    let title: String
    let hasFocus: Bool
    let isMinimized: Bool
    var appIcon: NSImage?
    
    static func == (lhs: WindowItem, rhs: WindowItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.app == rhs.app &&
        lhs.title == rhs.title &&
        lhs.hasFocus == rhs.hasFocus &&
        lhs.isMinimized == rhs.isMinimized
    }
}

struct SpaceItem: Identifiable, Equatable {
    let id: Int64
    let uuid: String
    let index: Int
    let label: String
    let hasFocus: Bool
    let isVisible: Bool
    let isNativeFullscreen: Bool
    var windows: [WindowItem]
    
    var displayName: String {
        if !label.isEmpty {
            return label
        }
        return "Space \(index)"
    }
    
    var isExpanded: Bool = true
    
    static func == (lhs: SpaceItem, rhs: SpaceItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.uuid == rhs.uuid &&
        lhs.index == rhs.index &&
        lhs.label == rhs.label &&
        lhs.hasFocus == rhs.hasFocus &&
        lhs.isVisible == rhs.isVisible &&
        lhs.isNativeFullscreen == rhs.isNativeFullscreen &&
        lhs.windows == rhs.windows
    }
}

struct DisplayGroup: Identifiable, Equatable {
    let id: Int
    let uuid: String
    let index: Int
    let label: String
    let hasFocus: Bool
    let frame: YabaiFrame
    var spaces: [SpaceItem]
    
    var displayName: String {
        if !label.isEmpty {
            return label
        }
        return "Display \(index)"
    }
    
    /// 分辨率描述，如 "2560×1440"
    var resolution: String {
        "\(Int(frame.w))×\(Int(frame.h))"
    }
    
    /// 位置描述，如 "(0, 0)"
    var position: String {
        "(\(Int(frame.x)), \(Int(frame.y)))"
    }
    
    static func == (lhs: DisplayGroup, rhs: DisplayGroup) -> Bool {
        lhs.id == rhs.id &&
        lhs.index == rhs.index &&
        lhs.hasFocus == rhs.hasFocus &&
        lhs.spaces == rhs.spaces
    }
}

// MARK: - ViewModel

class SidebarViewModel: ObservableObject {
    
    @Published var displayGroups: [DisplayGroup] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var isYabaiRunning = false
    @Published var toastMessage: String?
    
    /// 窗口自定义显示名称（运行时，windowID -> 自定义名称）
    @Published var windowNames: [Int: String] = [:]
    
    var sceneStore: SceneStore?
    
    /// 根据当前 Scene 过滤后的 displayGroups
    var filteredDisplayGroups: [DisplayGroup] {
        guard let filter = sceneStore?.filteredSpaceUUIDs else {
            return displayGroups
        }
        return displayGroups.compactMap { group in
            let filteredSpaces = group.spaces.filter { filter.contains($0.uuid) }
            guard !filteredSpaces.isEmpty else { return nil }
            var g = group
            g.spaces = filteredSpaces
            return g
        }
    }
    
    private var pollingTimer: Timer?
    private var appIconCache: [Int: NSImage] = [:]  // pid -> icon
    private let yabaiService = YabaiService.shared
    private let loadQueue = DispatchQueue(label: "com.vista.sidebar.load")
    
    // MARK: - Data Loading
    
    func loadData() {
        // #region debug-point D:load-start
        DebugReport.send(hypothesisId: "D", location: "SidebarViewModel.loadData", msg: "[DEBUG] loadData start", data: ["ts": CFAbsoluteTimeGetCurrent()])
        // #endregion
        if displayGroups.isEmpty {
            isLoading = true
        }
        error = nil
        
        loadQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let displays = try self.yabaiService.queryDisplays()
                let spaces = try self.yabaiService.querySpaces()
                let windows = try self.yabaiService.queryWindows()
                
                let groups = self.buildHierarchy(displays: displays, spaces: spaces, windows: windows)
                
                DispatchQueue.main.async {
                    // #region debug-point D:main-update
                    let changed = self.displayGroups != groups
                    DebugReport.send(hypothesisId: "D", location: "SidebarViewModel.mainUpdate", msg: "[DEBUG] main thread update", data: ["dataChanged": changed, "ts": CFAbsoluteTimeGetCurrent()])
                    // #endregion
                    if self.displayGroups != groups {
                        self.displayGroups = groups
                    }
                    self.isLoading = false
                    self.isYabaiRunning = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.error = error.localizedDescription
                    self.isLoading = false
                    if case .socketNotFound = error as? YabaiError {
                        self.isYabaiRunning = false
                    } else {
                        self.isYabaiRunning = true
                    }
                }
            }
        }
    }
    
    private func buildHierarchy(
        displays: [YabaiDisplay],
        spaces: [YabaiSpace],
        windows: [YabaiWindow]
    ) -> [DisplayGroup] {
        
        // Index windows by space
        var windowsBySpace: [Int: [YabaiWindow]] = [:]
        for window in windows {
            windowsBySpace[window.space, default: []].append(window)
        }
        
        // Index spaces by display
        var spacesByDisplay: [Int: [YabaiSpace]] = [:]
        for space in spaces {
            spacesByDisplay[space.display, default: []].append(space)
        }
        
        return displays.sorted(by: { $0.index < $1.index }).map { display in
            let displaySpaces = (spacesByDisplay[display.index] ?? [])
                .sorted(by: { $0.index < $1.index })
                .map { space -> SpaceItem in
                    let spaceWindows = (windowsBySpace[space.index] ?? [])
                        .map { window -> WindowItem in
                            let icon = getAppIcon(pid: window.pid)
                            return WindowItem(
                                id: window.id,
                                pid: window.pid,
                                app: window.app,
                                title: window.title,
                                hasFocus: window.hasFocus,
                                isMinimized: window.isMinimized,
                                appIcon: icon
                            )
                        }
                    
                    return SpaceItem(
                        id: space.id,
                        uuid: space.uuid,
                        index: space.index,
                        label: space.label,
                        hasFocus: space.hasFocus,
                        isVisible: space.isVisible,
                        isNativeFullscreen: space.isNativeFullscreen,
                        windows: spaceWindows
                    )
                }
            
            return DisplayGroup(
                id: display.id,
                uuid: display.uuid,
                index: display.index,
                label: display.label,
                hasFocus: display.hasFocus,
                frame: display.frame,
                spaces: displaySpaces
            )
        }
    }
    
    // MARK: - App Icon
    
    private func getAppIcon(pid: Int) -> NSImage? {
        if let cached = appIconCache[pid] {
            return cached
        }
        
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return NSImage(named: NSImage.applicationIconName)
        }
        
        let icon = app.icon ?? NSImage(named: NSImage.applicationIconName)
        if let icon = icon {
            appIconCache[pid] = icon
        }
        return icon
    }
    
    // MARK: - Polling
    
    func startPolling() {
        stopPolling()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.pollingInterval, repeats: true) { [weak self] _ in
            self?.loadData()
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Actions
    
    func focusSpace(index: Int, warpMouse: Bool = false) {
        // 查找目标 space 所属 display 的 frame
        let displayFrame: YabaiFrame? = warpMouse ? displayGroups.first(where: { $0.spaces.contains(where: { $0.index == index }) })?.frame : nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.focusSpace(index: index)
            if warpMouse, let frame = displayFrame {
                Thread.sleep(forTimeInterval: 0.15)
                Self.warpMouseToCenter(of: frame)
            }
        }
    }
    
    func focusWindow(id: Int, spaceIndex: Int, warpMouse: Bool = false) {
        let windowPid = displayGroups.flatMap(\.spaces).flatMap(\.windows).first(where: { $0.id == id })?.pid
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.focusSpace(index: spaceIndex)
            Thread.sleep(forTimeInterval: 0.3)
            do {
                try self?.yabaiService.focusWindow(id: id)
            } catch {
                NSLog("[Vista] yabai focusWindow failed for id=\(id), trying NSRunningApplication fallback")
                if let pid = windowPid {
                    DispatchQueue.main.async {
                        if let app = NSRunningApplication(processIdentifier: pid_t(pid)) {
                            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                        }
                    }
                }
            }
            // 跳转完成后，查询窗口最新 frame 并移动鼠标
            if warpMouse {
                Thread.sleep(forTimeInterval: 0.1)
                if let windows = try? self?.yabaiService.queryWindows(),
                   let win = windows.first(where: { $0.id == id }) {
                    Self.warpMouseToCenter(of: win.frame)
                }
            }
        }
    }
    
    /// 将鼠标移到指定 frame 的中心点
    private static func warpMouseToCenter(of frame: YabaiFrame) {
        let point = CGPoint(x: frame.x + frame.w / 2, y: frame.y + frame.h / 2)
        CGWarpMouseCursorPosition(point)
        // 解除鼠标与上一个事件的关联，避免拖拽残留
        CGAssociateMouseAndMouseCursorPosition(1)
    }
    
    /// 跳转到 Scene：每个显示屏切换到该 Scene 对应的 Space
    func gotoScene(_ scene: VistaScene) {
        let sceneUUIDs = Set(scene.spaceUUIDs)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            for group in self.displayGroups {
                // 找该 display 中属于此 scene 的 space
                let targetSpace = group.spaces.first(where: { sceneUUIDs.contains($0.uuid) })
                // 找不到则用该 display 的第一个非全屏 space
                let fallbackSpace = group.spaces.first(where: { !$0.isNativeFullscreen })
                
                if let space = targetSpace ?? fallbackSpace {
                    try? self.yabaiService.focusSpace(index: space.index)
                    Thread.sleep(forTimeInterval: 0.15)
                }
            }
        }
    }
    
    func moveWindowToSpace(windowID: Int, spaceIndex: Int) {
        // 全屏 Space 无法移入窗口
        let targetSpace = displayGroups.flatMap(\.spaces).first(where: { $0.index == spaceIndex })
        if targetSpace?.isNativeFullscreen == true {
            showToast("无法移入：目标 Space 处于全屏模式")
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.moveWindowToSpace(windowID: windowID, spaceIndex: spaceIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.loadData()
            }
        }
    }
    
    func moveSpaceToDisplay(spaceIndex: Int, displayIndex: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.moveSpaceToDisplay(spaceIndex: spaceIndex, displayIndex: displayIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.loadData()
            }
        }
    }
    
    func closeWindow(id: Int) {
        // 先从本地列表中移除，立即更新 UI
        for i in displayGroups.indices {
            for j in displayGroups[i].spaces.indices {
                displayGroups[i].spaces[j].windows.removeAll { $0.id == id }
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.closeWindow(id: id)
            // 全屏窗口关闭有动画，延迟更久再刷新
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.loadData()
            }
        }
    }
    
    func destroySpace(index: Int) {
        // 检查是否是该 Display 上最后一个普通 Space
        let displayIndex = displayGroups.first(where: { $0.spaces.contains(where: { $0.index == index }) })?.index
        if let displayIndex = displayIndex {
            let group = displayGroups.first(where: { $0.index == displayIndex })
            let normalSpaces = group?.spaces.filter({ !$0.isNativeFullscreen }) ?? []
            if normalSpaces.count <= 1 {
                showToast("无法关闭：这是该显示器上最后一个普通 Space")
                return
            }
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.destroySpace(index: index)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.loadData()
            }
        }
    }
    
    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
    
    // MARK: - Toggle Space Expand/Collapse
    
    func toggleSpaceExpanded(spaceId: Int64) {
        for i in displayGroups.indices {
            for j in displayGroups[i].spaces.indices {
                if displayGroups[i].spaces[j].id == spaceId {
                    displayGroups[i].spaces[j].isExpanded.toggle()
                    return
                }
            }
        }
    }
    
    deinit {
        stopPolling()
    }
}
