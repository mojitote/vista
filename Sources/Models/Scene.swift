import Foundation

/// 绑定到某个 Scene（或 All Scene）的应用快捷入口。
/// 点击 → 在当前 display 聚焦该应用的窗口；没有就开一个。
struct StickyApp: Codable, Identifiable, Equatable {
    var id: UUID
    /// 持久化键，例如 "com.apple.Safari"。
    var bundleID: String
    /// UI 展示用名称（locale 相关，仅用于显示，不参与匹配）。
    var displayName: String
    /// 没找到目标 display 上的窗口时是否强制新开窗口（默认开启）。
    var forceNewWindow: Bool
    /// 自定义新建窗口快捷键的 Carbon keyCode；nil 表示使用默认 ⌘N。
    var newWindowKeyCode: UInt32?
    /// 自定义新建窗口快捷键的 Carbon modifier flags；nil 表示使用默认 ⌘。
    var newWindowModifiers: UInt32?
    
    init(
        id: UUID = UUID(),
        bundleID: String,
        displayName: String,
        forceNewWindow: Bool = true,
        newWindowKeyCode: UInt32? = nil,
        newWindowModifiers: UInt32? = nil
    ) {
        self.id = id
        self.bundleID = bundleID
        self.displayName = displayName
        self.forceNewWindow = forceNewWindow
        self.newWindowKeyCode = newWindowKeyCode
        self.newWindowModifiers = newWindowModifiers
    }
    
    enum CodingKeys: String, CodingKey {
        case id, bundleID, displayName, forceNewWindow, newWindowKeyCode, newWindowModifiers
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.bundleID = try c.decode(String.self, forKey: .bundleID)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.forceNewWindow = try c.decodeIfPresent(Bool.self, forKey: .forceNewWindow) ?? true
        self.newWindowKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .newWindowKeyCode)
        self.newWindowModifiers = try c.decodeIfPresent(UInt32.self, forKey: .newWindowModifiers)
    }
}

struct VistaScene: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol 名称
    var spaceUUIDs: [String]  // 绑定的 Space UUID 列表（稳定标识，不受位置变化影响）
    var colorHex: String  // 主题颜色（hex，如 "#FF6B6B"）
    var gradientColors: [String]  // 渐变色 hex 数组（空 = 单色模式）
    var colorOpacity: Double  // 颜色叠加透明度
    var gradientAngle: Double  // 渐变角度（度）
    
    // 快捷键（Carbon key code + modifier flags）
    var hotkeyKeyCode: UInt32?
    var hotkeyModifiers: UInt32?
    
    /// 这个 Scene 顶上 sticky bar 里的应用列表。
    var stickyApps: [StickyApp]
    
    init(id: UUID = UUID(), name: String, icon: String = "square.grid.2x2", spaceUUIDs: [String] = [], colorHex: String = "#5E9EFF", gradientColors: [String] = [], colorOpacity: Double = 0.5, gradientAngle: Double = -45, hotkeyKeyCode: UInt32? = nil, hotkeyModifiers: UInt32? = nil, stickyApps: [StickyApp] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.spaceUUIDs = spaceUUIDs
        self.colorHex = colorHex
        self.gradientColors = gradientColors
        self.colorOpacity = colorOpacity
        self.gradientAngle = gradientAngle
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
        self.stickyApps = stickyApps
    }
    
    // Codable: 旧数据没有 stickyApps 字段时回落到空数组
    enum CodingKeys: String, CodingKey {
        case id, name, icon, spaceUUIDs, colorHex, gradientColors, colorOpacity, gradientAngle, hotkeyKeyCode, hotkeyModifiers, stickyApps
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.name = try c.decode(String.self, forKey: .name)
        self.icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "square.grid.2x2"
        self.spaceUUIDs = try c.decodeIfPresent([String].self, forKey: .spaceUUIDs) ?? []
        self.colorHex = try c.decodeIfPresent(String.self, forKey: .colorHex) ?? "#5E9EFF"
        self.gradientColors = try c.decodeIfPresent([String].self, forKey: .gradientColors) ?? []
        self.colorOpacity = try c.decodeIfPresent(Double.self, forKey: .colorOpacity) ?? 0.5
        self.gradientAngle = try c.decodeIfPresent(Double.self, forKey: .gradientAngle) ?? -45
        self.hotkeyKeyCode = try c.decodeIfPresent(UInt32.self, forKey: .hotkeyKeyCode)
        self.hotkeyModifiers = try c.decodeIfPresent(UInt32.self, forKey: .hotkeyModifiers)
        self.stickyApps = try c.decodeIfPresent([StickyApp].self, forKey: .stickyApps) ?? []
    }
}
