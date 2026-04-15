import Foundation

struct VistaScene: Codable, Identifiable {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol 名称
    var spaceIndices: [Int]  // 绑定的 Space 编号列表
    
    init(id: UUID = UUID(), name: String, icon: String = "square.grid.2x2", spaceIndices: [Int] = []) {
        self.id = id
        self.name = name
        self.icon = icon
        self.spaceIndices = spaceIndices
    }
}
