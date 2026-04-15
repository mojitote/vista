import Foundation

struct VistaScene: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol 名称
    var spaceUUIDs: [String]  // 绑定的 Space UUID 列表（稳定标识，不受位置变化影响）
    var colorHex: String  // 主题颜色（hex，如 "#FF6B6B"）
    
    // 向后兼容：旧数据可能有 spaceIndices
    var spaceIndices: [Int]?
    
    init(id: UUID = UUID(), name: String, icon: String = "square.grid.2x2", spaceUUIDs: [String] = [], colorHex: String = "#5E9EFF") {
        self.id = id
        self.name = name
        self.icon = icon
        self.spaceUUIDs = spaceUUIDs
        self.colorHex = colorHex
    }
}
