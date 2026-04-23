import Foundation
import Combine

/// Todo 数据中枢。单例，UI 订阅 @Published。
/// 持久化到 Application Support / Vista / todos.json。
final class TodoStore: ObservableObject {
    
    static let shared = TodoStore()
    
    @Published var todos: [TodoItem] = []
    
    private var storeURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent(AppConstants.settingsDirectoryName)
        return dir.appendingPathComponent("todos.json")
    }
    
    init() {
        load()
    }
    
    // MARK: - Filtering
    
    /// 当前 scene 下应显示的 todos（已排序）。
    /// - 具体 scene：只显示 sceneID == 当前 scene
    /// - All scene：显示全部（含未绑定）
    /// 排序规则：未完成在前、按 dueDate 升序（无 due 排后）、sortOrder 兜底。
    func filteredTodos(for sceneStore: SceneStore) -> [TodoItem] {
        let filtered: [TodoItem]
        if sceneStore.isAllActive {
            filtered = todos
        } else if let activeID = sceneStore.activeSceneID {
            filtered = todos.filter { $0.sceneID == activeID }
        } else {
            filtered = todos
        }
        return filtered.sorted(by: todoOrdering)
    }
    
    private func todoOrdering(_ a: TodoItem, _ b: TodoItem) -> Bool {
        // 1. 未完成在前
        if a.done != b.done { return !a.done }
        // 2. 按 dueDate 升序（nil 放最后）
        switch (a.dueDate, b.dueDate) {
        case let (aDue?, bDue?) where aDue != bDue:
            return aDue < bDue
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }
        // 3. sortOrder 兜底
        if a.sortOrder != b.sortOrder { return a.sortOrder < b.sortOrder }
        return a.createdAt < b.createdAt
    }
    
    // MARK: - Mutations
    
    @discardableResult
    func add(title: String, sceneID: UUID?, startDate: Date? = nil, dueDate: Date? = nil) -> TodoItem? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let nextOrder = (todos.map(\.sortOrder).max() ?? 0) + 1
        let item = TodoItem(
            title: trimmed,
            sceneID: sceneID,
            startDate: startDate,
            dueDate: dueDate,
            sortOrder: nextOrder
        )
        todos.append(item)
        save()
        return item
    }
    
    func toggleDone(id: UUID) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].done.toggle()
        todos[idx].completedAt = todos[idx].done ? Date() : nil
        save()
    }
    
    func rename(id: UUID, newTitle: String) {
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].title = trimmed
        save()
    }
    
    func setDueDate(id: UUID, dueDate: Date?) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].dueDate = dueDate
        if dueDate == nil { todos[idx].startDate = nil }
        save()
    }
    
    /// 同时设置开始 / 截止日期。任一为 nil 时清空。
    func setDateRange(id: UUID, startDate: Date?, dueDate: Date?) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].startDate = startDate
        todos[idx].dueDate = dueDate
        save()
    }
    
    func setSceneBinding(id: UUID, sceneID: UUID?) {
        guard let idx = todos.firstIndex(where: { $0.id == id }) else { return }
        todos[idx].sceneID = sceneID
        save()
    }
    
    func delete(id: UUID) {
        todos.removeAll(where: { $0.id == id })
        save()
    }
    
    /// 清除当前过滤集合里所有已完成项。
    func clearCompleted(for sceneStore: SceneStore) {
        let idsToRemove = Set(filteredTodos(for: sceneStore).filter(\.done).map(\.id))
        todos.removeAll(where: { idsToRemove.contains($0.id) })
        save()
    }
    
    // MARK: - Persistence
    
    func save() {
        do {
            let dir = storeURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(todos)
            try data.write(to: storeURL)
        } catch {
            print("Failed to save todos: \(error)")
        }
    }
    
    func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let items = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return
        }
        todos = items
    }
}
