import Foundation
import HotKey
import Carbon

class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()
    
    // MARK: - Published Properties
    @Published var hotZoneDelay: TimeInterval = AppConstants.hotZoneDelay
    @Published var hotZoneEnabled: Bool = true
    @Published var sidebarWidth: CGFloat = AppConstants.defaultSidebarWidth
    @Published var showThumbnails: Bool = true
    @Published var launchAtLogin: Bool = false
    
    // Hot key stored as key code + modifiers
    @Published var sidebarHotKeyCode: UInt32?
    @Published var sidebarHotKeyModifiers: UInt32?
    
    // MARK: - Persistence
    
    private var settingsURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppConstants.settingsDirectoryName)
        return dir.appendingPathComponent(AppConstants.settingsFileName)
    }
    
    init() {
        load()
    }
    
    func save() {
        var settings: [String: Any] = [
            "hotZoneDelay": hotZoneDelay,
            "hotZoneEnabled": hotZoneEnabled,
            "sidebarWidth": sidebarWidth,
            "showThumbnails": showThumbnails,
            "launchAtLogin": launchAtLogin,
        ]
        if let code = sidebarHotKeyCode {
            settings["sidebarHotKeyCode"] = code
        }
        if let mods = sidebarHotKeyModifiers {
            settings["sidebarHotKeyModifiers"] = mods
        }
        
        do {
            let dir = settingsURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)
            try data.write(to: settingsURL)
        } catch {
            print("Failed to save settings: \(error)")
        }
    }
    
    func load() {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        if let val = settings["hotZoneDelay"] as? TimeInterval { hotZoneDelay = val }
        if let val = settings["hotZoneEnabled"] as? Bool { hotZoneEnabled = val }
        if let val = settings["sidebarWidth"] as? CGFloat { sidebarWidth = val }
        if let val = settings["showThumbnails"] as? Bool { showThumbnails = val }
        if let val = settings["launchAtLogin"] as? Bool { launchAtLogin = val }
        if let val = settings["sidebarHotKeyCode"] as? UInt32 { sidebarHotKeyCode = val }
        if let val = settings["sidebarHotKeyModifiers"] as? UInt32 { sidebarHotKeyModifiers = val }
    }
    
    // MARK: - HotKey Helper
    
    var sidebarKeyCombo: KeyCombo? {
        guard let code = sidebarHotKeyCode, let mods = sidebarHotKeyModifiers else { return nil }
        return KeyCombo(carbonKeyCode: code, carbonModifiers: mods)
    }
}
