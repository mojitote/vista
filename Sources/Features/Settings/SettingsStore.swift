import Foundation
import AppKit
import HotKey

enum FullscreenDropAction: String {
    case toast = "toast"
    case exitAndMove = "exitAndMove"
}

enum SidebarTriggerMode: String {
    case hotZoneAndHotKey = "hotZoneAndHotKey"
    case threeFingerTap = "threeFingerTap"
}

/// 激活 scene 时，若某个 display 上没有该 scene 的 space 应如何处理
enum SceneDisplayFallback: String {
    case stayPut          // 不动这个 display
    case firstNonFullscreen  // 切到第一个非全屏 space
}

/// 侧边栏毛玻璃强度。NSVisualEffectView 不支持直接调 blur 半径，
/// 通过切换 material 在苹果预设档位间选：各 material 的 blur 半径、tint、饱和度都不同。
enum SidebarBlurMaterial: String, CaseIterable {
    case subtle   // .popover —— 浅、blur 较小
    case regular  // .sidebar —— 标准边栏质感，中等 blur + 高饱和度
    case strong   // .fullScreenUI —— 最浑厚，blur 大 tint 重
    case hud      // .hudWindow —— HUD 风格，深色 tint
    
    var nsMaterial: NSVisualEffectView.Material {
        switch self {
        case .subtle:  return .popover
        case .regular: return .sidebar
        case .strong:  return .fullScreenUI
        case .hud:     return .hudWindow
        }
    }
    
    var displayName: String {
        switch self {
        case .subtle:  return "Subtle"
        case .regular: return "Regular"
        case .strong:  return "Strong"
        case .hud:     return "HUD"
        }
    }
}

class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()
    
    // MARK: - Published Properties
    @Published var hotZoneDelay: TimeInterval = AppConstants.hotZoneDelay
    @Published var hotZoneEnabled: Bool = true
    @Published var hotZoneWidth: CGFloat = AppConstants.hotZoneWidth
    @Published var sidebarWidth: CGFloat = AppConstants.defaultSidebarWidth
    @Published var launchAtLogin: Bool = false
    @Published var fullscreenDropAction: FullscreenDropAction = .toast
    @Published var sceneDisplayFallback: SceneDisplayFallback = .stayPut
    @Published var triggerMode: SidebarTriggerMode = .hotZoneAndHotKey
    @Published var doubleTapDelay: TimeInterval = 0.20  // 双击等待超时（秒）
    
    // Preview
    @Published var previewEnabled: Bool = true
    @Published var previewMaxWidth: CGFloat = 480
    
    // Sidebar appearance
    @Published var sidebarColorHex: String?  // nil = 系统默认毛玻璃
    @Published var sidebarOpacity: Double = 0.4  // tint 叠加透明度（0 = 无 tint，1 = 纯色）
    @Published var sidebarBlurMaterial: SidebarBlurMaterial = .regular
    
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
            "launchAtLogin": launchAtLogin,
            "fullscreenDropAction": fullscreenDropAction.rawValue,
            "sceneDisplayFallback": sceneDisplayFallback.rawValue,
            "triggerMode": triggerMode.rawValue,
            "doubleTapDelay": doubleTapDelay,
            "sidebarOpacity": sidebarOpacity,
            "sidebarBlurMaterial": sidebarBlurMaterial.rawValue,
            "previewEnabled": previewEnabled,
            "previewMaxWidth": previewMaxWidth,
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
        if let val = settings["launchAtLogin"] as? Bool { launchAtLogin = val }
        if let val = settings["sidebarHotKeyCode"] as? UInt32 { sidebarHotKeyCode = val }
        if let val = settings["sidebarHotKeyModifiers"] as? UInt32 { sidebarHotKeyModifiers = val }
        if let val = settings["fullscreenDropAction"] as? String,
           let action = FullscreenDropAction(rawValue: val) { fullscreenDropAction = action }
        if let val = settings["sceneDisplayFallback"] as? String,
           let mode = SceneDisplayFallback(rawValue: val) { sceneDisplayFallback = mode }
        if let val = settings["triggerMode"] as? String,
           let mode = SidebarTriggerMode(rawValue: val) { triggerMode = mode }
        if let val = settings["doubleTapDelay"] as? TimeInterval { doubleTapDelay = val }
        if let val = settings["sidebarColorHex"] as? String { sidebarColorHex = val }
        if let val = settings["sidebarOpacity"] as? Double { sidebarOpacity = val }
        if let val = settings["sidebarBlurMaterial"] as? String,
           let m = SidebarBlurMaterial(rawValue: val) { sidebarBlurMaterial = m }
        if let val = settings["previewEnabled"] as? Bool { previewEnabled = val }
        if let val = settings["previewMaxWidth"] as? CGFloat { previewMaxWidth = val }
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
