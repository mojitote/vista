import Cocoa
import Combine

// MARK: - View Data Models

struct WindowItem: Identifiable {
    let id: Int
    let pid: Int
    let app: String
    let title: String
    let hasFocus: Bool
    let isMinimized: Bool
    var appIcon: NSImage?
    var thumbnail: NSImage?
}

struct SpaceItem: Identifiable {
    let id: Int64
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
}

struct DisplayGroup: Identifiable {
    let id: Int
    let index: Int
    let label: String
    let hasFocus: Bool
    var spaces: [SpaceItem]
    
    var displayName: String {
        if !label.isEmpty {
            return label
        }
        return "Display \(index)"
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
        guard let filter = sceneStore?.filteredSpaceIndices else {
            return displayGroups
        }
        return displayGroups.compactMap { group in
            let filteredSpaces = group.spaces.filter { filter.contains($0.index) }
            guard !filteredSpaces.isEmpty else { return nil }
            var g = group
            g.spaces = filteredSpaces
            return g
        }
    }
    
    private var pollingTimer: Timer?
    private var appIconCache: [Int: NSImage] = [:]  // pid -> icon
    private let yabaiService = YabaiService.shared
    private let thumbnailService = WindowThumbnailService.shared
    private let loadQueue = DispatchQueue(label: "com.vista.sidebar.load")
    
    // MARK: - Data Loading
    
    func loadData(withThumbnails: Bool = true) {
        isLoading = true
        error = nil
        
        loadQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let displays = try self.yabaiService.queryDisplays()
                let spaces = try self.yabaiService.querySpaces()
                let windows = try self.yabaiService.queryWindows()
                
                // Capture thumbnails if enabled
                var thumbnails: [CGWindowID: NSImage] = [:]
                if withThumbnails {
                    let windowIDs = windows.map { CGWindowID($0.id) }
                    thumbnails = self.thumbnailService.captureAll(windowIDs: windowIDs)
                }
                
                // Build hierarchy
                let groups = self.buildHierarchy(displays: displays, spaces: spaces, windows: windows, thumbnails: thumbnails)
                
                DispatchQueue.main.async {
                    self.displayGroups = groups
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
        windows: [YabaiWindow],
        thumbnails: [CGWindowID: NSImage]
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
                            let thumb = thumbnails[CGWindowID(window.id)]
                            return WindowItem(
                                id: window.id,
                                pid: window.pid,
                                app: window.app,
                                title: window.title,
                                hasFocus: window.hasFocus,
                                isMinimized: window.isMinimized,
                                appIcon: icon,
                                thumbnail: thumb
                            )
                        }
                    
                    return SpaceItem(
                        id: space.id,
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
                index: display.index,
                label: display.label,
                hasFocus: display.hasFocus,
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
            self?.loadData(withThumbnails: false)
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    // MARK: - Actions
    
    func focusSpace(index: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.focusSpace(index: index)
        }
    }
    
    func focusWindow(id: Int, spaceIndex: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.focusSpace(index: spaceIndex)
            Thread.sleep(forTimeInterval: 0.3)
            try? self?.yabaiService.focusWindow(id: id)
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
                self?.loadData(withThumbnails: false)
            }
        }
    }
    
    func closeWindow(id: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            try? self?.yabaiService.closeWindow(id: id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.loadData(withThumbnails: false)
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
                self?.loadData(withThumbnails: false)
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
