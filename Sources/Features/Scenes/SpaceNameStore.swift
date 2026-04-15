import Foundation

class SpaceNameStore: ObservableObject {
    
    static let shared = SpaceNameStore()
    
    @Published var names: [Int: String] = [:]
    
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Vista")
        return dir.appendingPathComponent("space-names.json")
    }
    
    init() {
        load()
    }
    
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
    
    func save() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // Convert Int keys to String for JSON
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
}
