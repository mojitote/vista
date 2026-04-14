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
                    self.isYabaiRunning = (error as? YabaiError) != .socketNotFound
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
            try? self?.yabaiService.focusWindow(id: id)
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
