import Foundation

/// 待办事项。
///
/// - `sceneID`：绑定的 Scene；nil 表示「未绑定（全局）」。当前 filter 策略：
///   - 激活某个具体 scene 时，只显示 `sceneID == 那个 scene` 的 todo。
///   - All scene 视图显示全部（含未绑定）。
/// - `dueDate`：可选截止日期。nil 表示未设置。
/// - `sortOrder`：用户手动排序时的位置。
struct TodoItem: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var done: Bool
    var createdAt: Date
    var sceneID: UUID?
    /// 起始日期。与 dueDate 搭配表示一个「时间段」；单独设置 dueDate 表示只有截止。
    var startDate: Date?
    var dueDate: Date?
    var sortOrder: Int
    /// 完成时刻，用于「最近完成」面板排序。
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        title: String,
        done: Bool = false,
        createdAt: Date = Date(),
        sceneID: UUID? = nil,
        startDate: Date? = nil,
        dueDate: Date? = nil,
        sortOrder: Int = 0,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.done = done
        self.createdAt = createdAt
        self.sceneID = sceneID
        self.startDate = startDate
        self.dueDate = dueDate
        self.sortOrder = sortOrder
        self.completedAt = completedAt
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, done, createdAt, sceneID, startDate, dueDate, sortOrder, completedAt
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(UUID.self, forKey: .id)
        self.title = try c.decode(String.self, forKey: .title)
        self.done = try c.decodeIfPresent(Bool.self, forKey: .done) ?? false
        self.createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.sceneID = try c.decodeIfPresent(UUID.self, forKey: .sceneID)
        self.startDate = try c.decodeIfPresent(Date.self, forKey: .startDate)
        self.dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        self.sortOrder = try c.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        self.completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

enum TodoDueStatus {
    case overdue
    case today
    case upcoming(daysAway: Int)
    case none
}

extension TodoItem {
    /// 根据 dueDate 计算显示状态。以「今天 00:00」为基准，纯日期比较。
    var dueStatus: TodoDueStatus {
        guard let due = dueDate else { return .none }
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let dueStart = cal.startOfDay(for: due)
        let days = cal.dateComponents([.day], from: todayStart, to: dueStart).day ?? 0
        if days < 0 { return .overdue }
        if days == 0 { return .today }
        return .upcoming(daysAway: days)
    }
    
    /// 紧凑的日期 chip 文本。
    /// - 只有 dueDate：相对表达（今天/明天/昨天/N天后/逾期N天/具体日期）
    /// - 同时有 startDate 和 dueDate：「M/d - M/d」
    var dueBadgeText: String? {
        if let start = startDate, let due = dueDate {
            return Self.rangeBadgeText(from: start, to: due)
        }
        guard let due = dueDate else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let that = cal.startOfDay(for: due)
        let diff = cal.dateComponents([.day], from: today, to: that).day ?? 0
        switch diff {
        case 0: return "今天"
        case 1: return "明天"
        case -1: return "昨天"
        case 2...6: return "\(diff)天后"
        case -6 ... -2: return "逾期\(-diff)天"
        default:
            let fmt = DateFormatter()
            fmt.dateFormat = cal.isDate(due, equalTo: Date(), toGranularity: .year) ? "M/d" : "yyyy/M/d"
            return fmt.string(from: due)
        }
    }
    
    private static func rangeBadgeText(from start: Date, to end: Date) -> String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        let sameYear = cal.isDate(start, equalTo: end, toGranularity: .year)
            && cal.isDate(start, equalTo: Date(), toGranularity: .year)
        fmt.dateFormat = sameYear ? "M/d" : "yyyy/M/d"
        return "\(fmt.string(from: start)) - \(fmt.string(from: end))"
    }
}
