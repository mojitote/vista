import Foundation

class SceneStore: ObservableObject {
    
    static let shared = SceneStore()
    
    @Published var scenes: [VistaScene] = []
    @Published var activeSceneID: UUID?
    
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppConstants.settingsDirectoryName)
        return dir.appendingPathComponent("scenes.json")
    }
    
    var activeScene: VistaScene? {
        guard let id = activeSceneID else { return nil }
        return scenes.first(where: { $0.id == id })
    }
    
    /// 当前 Scene 下的 Space 编号集合，nil 表示显示全部
    var filteredSpaceIndices: Set<Int>? {
        guard let scene = activeScene else { return nil }
        return scene.spaceIndices.isEmpty ? nil : Set(scene.spaceIndices)
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
    
    // MARK: - Persistence
    
    func save() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            let payload = SceneStorePayload(scenes: scenes, activeSceneID: activeSceneID)
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
    }
}

private struct SceneStorePayload: Codable {
    var scenes: [VistaScene]
    var activeSceneID: UUID?
}
