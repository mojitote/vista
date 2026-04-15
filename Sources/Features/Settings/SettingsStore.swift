import Foundation
import HotKey
import Carbon

enum FullscreenDropAction: String {
    case toast = "toast"
    case exitAndMove = "exitAndMove"
}

enum SidebarTriggerMode: String {
    case hotZoneAndHotKey = "hotZoneAndHotKey"
    case threeFingerTap = "threeFingerTap"
}

class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()
    
    // MARK: - Published Properties
    @Published var hotZoneDelay: TimeInterval = AppConstants.hotZoneDelay
    @Published var hotZoneEnabled: Bool = true
    @Published var hotZoneWidth: CGFloat = AppConstants.hotZoneWidth
    @Published var sidebarWidth: CGFloat = AppConstants.defaultSidebarWidth
    @Published var showThumbnails: Bool = true
    @Published var launchAtLogin: Bool = false
    @Published var fullscreenDropAction: FullscreenDropAction = .toast
    @Published var triggerMode: SidebarTriggerMode = .hotZoneAndHotKey
    
    // Sidebar appearance
    @Published var sidebarColorHex: String?  // nil = 系统默认毛玻璃
    @Published var sidebarOpacity: Double = 0.85
    
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
            "hotZoneWidth": hotZoneWidth,
            "sidebarWidth": sidebarWidth,
            "showThumbnails": showThumbnails,
            "launchAtLogin": launchAtLogin,
            "fullscreenDropAction": fullscreenDropAction.rawValue,
            "triggerMode": triggerMode.rawValue,
            "sidebarOpacity": sidebarOpacity,
        ]
        if let hex = sidebarColorHex {
            settings["sidebarColorHex"] = hex
        }
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
        if let val = settings["hotZoneWidth"] as? CGFloat { hotZoneWidth = val }
        if let val = settings["sidebarWidth"] as? CGFloat { sidebarWidth = val }
        if let val = settings["showThumbnails"] as? Bool { showThumbnails = val }
        if let val = settings["launchAtLogin"] as? Bool { launchAtLogin = val }
        if let val = settings["sidebarHotKeyCode"] as? UInt32 { sidebarHotKeyCode = val }
        if let val = settings["sidebarHotKeyModifiers"] as? UInt32 { sidebarHotKeyModifiers = val }
        if let val = settings["fullscreenDropAction"] as? String,
           let action = FullscreenDropAction(rawValue: val) { fullscreenDropAction = action }
        if let val = settings["triggerMode"] as? String,
           let mode = SidebarTriggerMode(rawValue: val) { triggerMode = mode }
        if let val = settings["sidebarColorHex"] as? String { sidebarColorHex = val }
        if let val = settings["sidebarOpacity"] as? Double { sidebarOpacity = val }
    }
    
    // MARK: - HotKey Helper
    
    var sidebarKeyCombo: KeyCombo? {
        guard let code = sidebarHotKeyCode, let mods = sidebarHotKeyModifiers else { return nil }
        return KeyCombo(carbonKeyCode: code, carbonModifiers: mods)
    }
    
    // MARK: - Color Helper
    
    var sidebarNSColor: NSColor? {
        guard let hex = sidebarColorHex else { return nil }
        return NSColor(hex: hex)
    }
}

import AppKit

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6, let rgb = UInt64(hexSanitized, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255.0,
            green: CGFloat((rgb >> 8) & 0xFF) / 255.0,
            blue: CGFloat(rgb & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
    
    var hexString: String {
        guard let rgb = usingColorSpace(.sRGB) else { return "#000000" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
}
