import Foundation

class SceneStore: ObservableObject {
    
    static let shared = SceneStore()
    static let allSceneID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    @Published var scenes: [VistaScene] = []
    @Published var activeSceneID: UUID?
    
    // All 场景的快捷键
    @Published var allHotkeyKeyCode: UInt32?
    @Published var allHotkeyModifiers: UInt32?
    
    /// All Scene 的 sticky apps（独立存储，因为 All Scene 不在 scenes 数组里）。
    @Published var allSceneStickyApps: [StickyApp] = []
    
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppConstants.settingsDirectoryName)
        return dir.appendingPathComponent("scenes.json")
    }
    
    var activeScene: VistaScene? {
        guard let id = activeSceneID else { return nil }
        if id == SceneStore.allSceneID { return nil }
        return scenes.first(where: { $0.id == id })
    }
    
    /// 当前是否为 All 模式（activeSceneID 为 nil 或 allSceneID）
    var isAllActive: Bool {
        activeSceneID == nil || activeSceneID == SceneStore.allSceneID
    }
    
    /// 当前 Scene 下的 Space UUID 集合，nil 表示显示全部
    var filteredSpaceUUIDs: Set<String>? {
        guard let scene = activeScene else { return nil }
        return scene.spaceUUIDs.isEmpty ? nil : Set(scene.spaceUUIDs)
    }
    
    /// 根据 Space UUID 查找归属的 Scene
    func scene(forSpaceUUID uuid: String) -> VistaScene? {
        scenes.first(where: { $0.spaceUUIDs.contains(uuid) })
    }
    
    init() {
        load()
    }
    
    func addScene(_ scene: VistaScene) {
        scenes.append(scene)
        save()
    }
    
    func updateScene(_ scene: VistaScene) {
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[idx] = scene
            save()
        }
    }
    
    func deleteScene(id: UUID) {
        scenes.removeAll(where: { $0.id == id })
        if activeSceneID == id {
            activeSceneID = nil
        }
        save()
    }
    
    func activateScene(id: UUID?) {
        activeSceneID = id
        save()
    }
    
    func updateAllHotkey(keyCode: UInt32?, modifiers: UInt32?) {
        allHotkeyKeyCode = keyCode
        allHotkeyModifiers = modifiers
        save()
    }
    
    // MARK: - Sticky Apps
    
    /// 当前激活 Scene 的 sticky apps；All Scene 时返回 allSceneStickyApps。
    var currentStickyApps: [StickyApp] {
        if isAllActive { return allSceneStickyApps }
        return activeScene?.stickyApps ?? []
    }
    
    /// 在当前激活 Scene 的 sticky bar 末尾追加一个 app（重复 bundleID 直接忽略）。
    func addStickyAppToCurrent(bundleID: String, displayName: String) {
        let new = StickyApp(bundleID: bundleID, displayName: displayName)
        if isAllActive {
            guard !allSceneStickyApps.contains(where: { $0.bundleID == bundleID }) else { return }
            allSceneStickyApps.append(new)
            save()
            return
        }
        guard let id = activeSceneID, let idx = scenes.firstIndex(where: { $0.id == id }) else { return }
        guard !scenes[idx].stickyApps.contains(where: { $0.bundleID == bundleID }) else { return }
        scenes[idx].stickyApps.append(new)
        save()
    }
    
    /// 从当前激活 Scene 的 sticky bar 中移除指定 app。
    func removeStickyAppFromCurrent(id: UUID) {
        if isAllActive {
            allSceneStickyApps.removeAll(where: { $0.id == id })
            save()
            return
        }
        guard let activeID = activeSceneID, let idx = scenes.firstIndex(where: { $0.id == activeID }) else { return }
        scenes[idx].stickyApps.removeAll(where: { $0.id == id })
        save()
    }
    
    /// 重排当前激活 Scene 的 sticky apps（用于拖拽排序）。
    func reorderStickyAppsInCurrent(_ newOrder: [StickyApp]) {
        if isAllActive {
            allSceneStickyApps = newOrder
            save()
            return
        }
        guard let activeID = activeSceneID, let idx = scenes.firstIndex(where: { $0.id == activeID }) else { return }
        scenes[idx].stickyApps = newOrder
        save()
    }
    
    /// 切换某个 sticky app 的 forceNewWindow 选项。
    func toggleForceNewWindow(stickyAppID: UUID) {
        mutateStickyApp(id: stickyAppID) { $0.forceNewWindow.toggle() }
    }
    
    /// 设置某个 sticky app 的「新建窗口」快捷键（nil/nil 即恢复默认 ⌘N）。
    func updateStickyAppShortcut(id: UUID, keyCode: UInt32?, modifiers: UInt32?) {
        mutateStickyApp(id: id) {
            $0.newWindowKeyCode = keyCode
            $0.newWindowModifiers = modifiers
        }
    }
    
    private func mutateStickyApp(id: UUID, _ mutator: (inout StickyApp) -> Void) {
        if isAllActive {
            if let idx = allSceneStickyApps.firstIndex(where: { $0.id == id }) {
                mutator(&allSceneStickyApps[idx])
                save()
            }
            return
        }
        guard let activeID = activeSceneID,
              let sceneIdx = scenes.firstIndex(where: { $0.id == activeID }),
              let appIdx = scenes[sceneIdx].stickyApps.firstIndex(where: { $0.id == id }) else { return }
        mutator(&scenes[sceneIdx].stickyApps[appIdx])
        save()
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            let payload = SceneStorePayload(
                scenes: scenes,
                activeSceneID: activeSceneID,
                allHotkeyKeyCode: allHotkeyKeyCode,
                allHotkeyModifiers: allHotkeyModifiers,
                allSceneStickyApps: allSceneStickyApps
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storeURL)
        } catch {
            print("Failed to save scenes: \(error)")
        }
    }
    
    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let payload = try? JSONDecoder().decode(SceneStorePayload.self, from: data) else {
            return
        }
        scenes = payload.scenes
        activeSceneID = payload.activeSceneID
        allHotkeyKeyCode = payload.allHotkeyKeyCode
        allHotkeyModifiers = payload.allHotkeyModifiers
        allSceneStickyApps = payload.allSceneStickyApps ?? []
    }
}

private struct SceneStorePayload: Codable {
    var scenes: [VistaScene]
    var activeSceneID: UUID?
    var allHotkeyKeyCode: UInt32?
    var allHotkeyModifiers: UInt32?
    var allSceneStickyApps: [StickyApp]?  // optional 让旧数据无痛升级
}
