import Foundation

class SpaceNameStore: ObservableObject {
    
    static let shared = SpaceNameStore()
    
    @Published var names: [Int: String] = [:]
    @Published var displayNames: [String: String] = [:]  // display uuid -> custom name
    
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Vista")
        return dir.appendingPathComponent("space-names.json")
    }
    
    private var displayStoreURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Vista")
        return dir.appendingPathComponent("display-names.json")
    }
    
    init() {
        load()
        loadDisplayNames()
    }
    
    // MARK: - Space Names
    
    func setName(_ name: String?, forSpaceIndex index: Int) {
        if let name = name, !name.isEmpty {
            names[index] = name
        } else {
            names.removeValue(forKey: index)
        }
        save()
    }
    
    func name(forSpaceIndex index: Int) -> String? {
        return names[index]
    }
    
    // MARK: - Display Names
    
    func setDisplayName(_ name: String?, forUUID uuid: String) {
        if let name = name, !name.isEmpty {
            displayNames[uuid] = name
        } else {
            displayNames.removeValue(forKey: uuid)
        }
        saveDisplayNames()
    }
    
    func displayName(forUUID uuid: String) -> String? {
        return displayNames[uuid]
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let stringDict = names.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
            let data = try JSONSerialization.data(withJSONObject: stringDict, options: .prettyPrinted)
            try data.write(to: storeURL)
        } catch {
            print("Failed to save space names: \(error)")
        }
    }
    
    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return
        }
        names = dict.reduce(into: [Int: String]()) { result, pair in
            if let key = Int(pair.key) {
                result[key] = pair.value
            }
        }
    }
    
    private func saveDisplayNames() {
        do {
            let dir = displayStoreURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: displayNames, options: .prettyPrinted)
            try data.write(to: displayStoreURL)
        } catch {
            print("Failed to save display names: \(error)")
        }
    }
    
    private func loadDisplayNames() {
        guard let data = try? Data(contentsOf: displayStoreURL),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return
        }
        displayNames = dict
    }
}
