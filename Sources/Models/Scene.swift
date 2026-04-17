import Foundation

struct VistaScene: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol 名称
    var spaceUUIDs: [String]  // 绑定的 Space UUID 列表（稳定标识，不受位置变化影响）
    var colorHex: String  // 主题颜色（hex，如 "#FF6B6B"）
    
    // 快捷键（Carbon key code + modifier flags）
    var hotkeyKeyCode: UInt32?
    var hotkeyModifiers: UInt32?
    
    init(id: UUID = UUID(), name: String, icon: String = "square.grid.2x2", spaceUUIDs: [String] = [], colorHex: String = "#5E9EFF", hotkeyKeyCode: UInt32? = nil, hotkeyModifiers: UInt32? = nil) {
        self.id = id
        self.name = name
        self.icon = icon
        self.spaceUUIDs = spaceUUIDs
        self.colorHex = colorHex
        self.hotkeyKeyCode = hotkeyKeyCode
        self.hotkeyModifiers = hotkeyModifiers
    }
}
