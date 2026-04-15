import Foundation

struct VistaScene: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol 名称
    var spaceIndices: [Int]  // 绑定的 Space 编号列表
    var colorHex: String  // 主题颜色（hex，如 "#FF6B6B"）
    
    init(id: UUID = UUID(), name: String, icon: String = "square.grid.2x2", spaceIndices: [Int] = [], colorHex: String = "#5E9EFF") {
        self.id = id
        self.name = name
        self.icon = icon
        self.spaceIndices = spaceIndices
        self.colorHex = colorHex
    }
}
