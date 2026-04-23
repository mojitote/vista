import SwiftUI
import AppKit

/// 待办列表栏。位于 StickyAppBar 下方，display 列表上方。
///
/// 行为：
/// - 空态：一行「+ 添加待办」按钮（节约空间）。
/// - 非空：展示未完成项；已完成折叠到底部「已完成 (N)」可展开。
/// - 列表项支持：勾选、重命名（双击）、日期 chip（点击改日期/时间段）、右键菜单。
/// - 绑定了 Scene 的待办行会染上该 Scene 的主题底色，和 SpaceRow 保持一致。
struct TodoBar: View {
    @ObservedObject var store: TodoStore
    @ObservedObject var sceneStore: SceneStore
    
    @State private var isAdding = false
    @State private var newTitle: String = ""
    @State private var newStartDate: Date? = nil
    @State private var newDueDate: Date? = nil
    @State private var showCompleted = false
    @State private var editingTitleID: UUID?
    @State private var editingTitleText: String = ""
    @State private var datePickerForID: UUID?
    @State private var showNewDatePicker = false
    
    private var visible: [TodoItem] {
        store.filteredTodos(for: sceneStore)
    }
    
    private var pending: [TodoItem] { visible.filter { !$0.done } }
    private var completed: [TodoItem] { visible.filter { $0.done } }
    
    var body: some View {
        VStack(spacing: 0) {
            if pending.isEmpty && completed.isEmpty && !isAdding {
                emptyRow
            } else {
                header
                
                if !pending.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(pending) { todo in
                            todoRow(todo)
                        }
                    }
                }
                
                if isAdding {
                    addRow
                }
                
                if !completed.isEmpty {
                    completedSection
                }
            }
        }
        .padding(.vertical, 6)
        .background(todoBackground)
    }
    
    // MARK: - Backgrounds
    
    private var todoBackground: some View {
        Rectangle()
            .fill(DesignTokens.Colors.subtleText.opacity(0.04))
            .overlay(
                Rectangle()
                    .fill(DesignTokens.Colors.separator)
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    /// 待办所归属 Scene 的主题色（无绑定或绑定的 Scene 被删除时返回 nil）
    private func sceneColor(for todo: TodoItem) -> Color? {
        guard let sceneID = todo.sceneID,
              let scene = sceneStore.scenes.first(where: { $0.id == sceneID }),
              let nsColor = NSColor(hex: scene.colorHex) else { return nil }
        return Color(nsColor: nsColor)
    }
    
    // MARK: - Empty state
    
    private var emptyRow: some View {
        Button(action: startAdding) {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                Text("添加待办")
                    .font(.system(size: 11))
                Spacer()
            }
            .foregroundColor(DesignTokens.Colors.secondaryText)
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 6) {
            Text("待办")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.sectionHeader)
                .textCase(.uppercase)
                .tracking(0.5)
            
            if !pending.isEmpty {
                Text("\(pending.count)")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
            
            Spacer()
            
            Button(action: startAdding) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .help("添加待办")
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }
    
    // MARK: - Todo Row
    
    @ViewBuilder
    private func todoRow(_ todo: TodoItem) -> some View {
        let color = sceneColor(for: todo)
        HStack(spacing: 8) {
            checkbox(for: todo)
            
            if editingTitleID == todo.id {
                TextField("", text: $editingTitleText, onCommit: {
                    store.rename(id: todo.id, newTitle: editingTitleText)
                    editingTitleID = nil
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onExitCommand { editingTitleID = nil }
            } else {
                Text(todo.title)
                    .font(.system(size: 12))
                    .foregroundColor(todo.done ? DesignTokens.Colors.secondaryText : .primary)
                    .strikethrough(todo.done)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        editingTitleID = todo.id
                        editingTitleText = todo.title
                    }
            }
            
            Spacer(minLength: 4)
            
            if let badge = todo.dueBadgeText {
                dueChip(todo: todo, text: badge)
            } else {
                Button(action: { datePickerForID = todo.id }) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.subtleText.opacity(0.7))
                        .padding(2)
                }
                .buttonStyle(.plain)
                .help("设置日期 / 时间段")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(color?.opacity(0.12) ?? Color.clear)
                .padding(.horizontal, DesignTokens.Spacing.md)
        )
        .contextMenu { rowMenu(for: todo) }
        .popover(isPresented: bindingDatePopover(for: todo.id), arrowEdge: .top) {
            TodoDatePicker(
                initialStart: todo.startDate,
                initialDue: todo.dueDate,
                onPick: { start, due in
                    store.setDateRange(id: todo.id, startDate: start, dueDate: due)
                    datePickerForID = nil
                },
                onClear: {
                    store.setDateRange(id: todo.id, startDate: nil, dueDate: nil)
                    datePickerForID = nil
                }
            )
        }
    }
    
    private func bindingDatePopover(for id: UUID) -> Binding<Bool> {
        Binding(
            get: { datePickerForID == id },
            set: { newValue in
                if !newValue && datePickerForID == id { datePickerForID = nil }
            }
        )
    }
    
    @ViewBuilder
    private func checkbox(for todo: TodoItem) -> some View {
        Button(action: { store.toggleDone(id: todo.id) }) {
            Image(systemName: todo.done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundColor(todo.done ? DesignTokens.Colors.activeIndicator : DesignTokens.Colors.secondaryText)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func dueChip(todo: TodoItem, text: String) -> some View {
        let color = chipColor(for: todo.dueStatus)
        Button(action: { datePickerForID = todo.id }) {
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                )
        }
        .buttonStyle(.plain)
        .help("点击修改日期 / 时间段")
    }
    
    private func chipColor(for status: TodoDueStatus) -> Color {
        switch status {
        case .overdue: return Color.red
        case .today:   return Color.orange
        case .upcoming(let d) where d <= 2: return Color.blue
        case .upcoming: return DesignTokens.Colors.secondaryText
        case .none:    return DesignTokens.Colors.secondaryText
        }
    }
    
    // MARK: - Add Row
    
    private var addRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle")
                .font(.system(size: 13))
                .foregroundColor(DesignTokens.Colors.subtleText)
            
            TextField("输入待办...", text: $newTitle, onCommit: commitNew)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onExitCommand { cancelNew() }
            
            if let badge = newDateBadgeText {
                Text(badge)
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.blue.opacity(0.15)))
                    .onTapGesture { clearNewDates() }
            }
            
            Menu {
                Button("今天") {
                    newStartDate = nil
                    newDueDate = Calendar.current.startOfDay(for: Date())
                }
                Button("明天") {
                    newStartDate = nil
                    newDueDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                }
                Button("下周") {
                    newStartDate = nil
                    newDueDate = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))
                }
                Button("自定义…") { showNewDatePicker = true }
                Button("时间段…") { showNewDatePicker = true }
                Divider()
                Button("清除") { clearNewDates() }
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .popover(isPresented: $showNewDatePicker, arrowEdge: .top) {
                TodoDatePicker(
                    initialStart: newStartDate,
                    initialDue: newDueDate,
                    onPick: { start, due in
                        newStartDate = start
                        newDueDate = due
                        showNewDatePicker = false
                    },
                    onClear: {
                        clearNewDates()
                        showNewDatePicker = false
                    }
                )
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
        .padding(.vertical, 3)
    }
    
    /// 添加行里当前已选日期的预览 chip 文本
    private var newDateBadgeText: String? {
        if let start = newStartDate, let due = newDueDate {
            let cal = Calendar.current
            let fmt = DateFormatter()
            let sameYear = cal.isDate(start, equalTo: due, toGranularity: .year)
                && cal.isDate(start, equalTo: Date(), toGranularity: .year)
            fmt.dateFormat = sameYear ? "M/d" : "yyyy/M/d"
            return "\(fmt.string(from: start)) - \(fmt.string(from: due))"
        }
        if let due = newDueDate {
            return chipText(for: due)
        }
        return nil
    }
    
    private func clearNewDates() {
        newStartDate = nil
        newDueDate = nil
    }
    
    private func chipText(for date: Date) -> String {
        let cal = Calendar.current
        let diff = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        switch diff {
        case 0: return "今天"
        case 1: return "明天"
        default:
            let fmt = DateFormatter(); fmt.dateFormat = "M/d"; return fmt.string(from: date)
        }
    }
    
    private func startAdding() {
        isAdding = true
        newTitle = ""
        clearNewDates()
    }
    
    private func cancelNew() {
        isAdding = false
        newTitle = ""
        clearNewDates()
    }
    
    private func commitNew() {
        let sceneID: UUID? = sceneStore.isAllActive ? nil : sceneStore.activeSceneID
        _ = store.add(title: newTitle, sceneID: sceneID, startDate: newStartDate, dueDate: newDueDate)
        newTitle = ""
        clearNewDates()
        // 留在 add 模式，方便连续添加；按 Esc 或空标题回车退出。
    }
    
    // MARK: - Completed Section
    
    private var completedSection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { showCompleted.toggle() } }) {
                HStack(spacing: 4) {
                    Image(systemName: showCompleted ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9))
                        .foregroundColor(DesignTokens.Colors.subtleText)
                    Text("已完成 (\(completed.count))")
                        .font(.system(size: 10))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                    Spacer()
                    if showCompleted {
                        Button("清除") { store.clearCompleted(for: sceneStore) }
                            .buttonStyle(.plain)
                            .font(.system(size: 10))
                            .foregroundColor(DesignTokens.Colors.secondaryText)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            if showCompleted {
                ForEach(completed) { todo in
                    todoRow(todo)
                }
            }
        }
    }
    
    // MARK: - Row Context Menu
    
    @ViewBuilder
    private func rowMenu(for todo: TodoItem) -> some View {
        Button(todo.done ? "标记未完成" : "标记完成") {
            store.toggleDone(id: todo.id)
        }
        Button("重命名…") {
            editingTitleID = todo.id
            editingTitleText = todo.title
        }
        
        Menu("设置日期") {
            Button("今天") {
                store.setDateRange(id: todo.id, startDate: nil, dueDate: Calendar.current.startOfDay(for: Date()))
            }
            Button("明天") {
                let d = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))
                store.setDateRange(id: todo.id, startDate: nil, dueDate: d)
            }
            Button("下周") {
                let d = Calendar.current.date(byAdding: .day, value: 7, to: Calendar.current.startOfDay(for: Date()))
                store.setDateRange(id: todo.id, startDate: nil, dueDate: d)
            }
            Button("自定义 / 时间段…") {
                datePickerForID = todo.id
            }
            if todo.dueDate != nil || todo.startDate != nil {
                Divider()
                Button("清除日期") { store.setDateRange(id: todo.id, startDate: nil, dueDate: nil) }
            }
        }
        
        Menu("绑定 Scene") {
            Button("未绑定（全局）\(todo.sceneID == nil ? " ✓" : "")") {
                store.setSceneBinding(id: todo.id, sceneID: nil)
            }
            Divider()
            ForEach(sceneStore.scenes, id: \.id) { scene in
                Button("\(scene.name)\(todo.sceneID == scene.id ? " ✓" : "")") {
                    store.setSceneBinding(id: todo.id, sceneID: scene.id)
                }
            }
        }
        
        Divider()
        
        Button("删除", role: .destructive) {
            store.delete(id: todo.id)
        }
    }
}

// MARK: - Date picker popover

/// 日期选择器。支持单日截止和时间段两种模式，通过顶部 Toggle 切换。
///
/// - 单日模式：只选 `dueDate`，确认后 `onPick(nil, dueDate)`。
/// - 时间段模式：选 `startDate` 和 `dueDate`，保证 start <= due，确认后 `onPick(start, due)`。
struct TodoDatePicker: View {
    let initialStart: Date?
    let initialDue: Date?
    let onPick: (Date?, Date) -> Void
    let onClear: () -> Void
    
    @State private var useRange: Bool
    @State private var start: Date
    @State private var due: Date
    
    init(
        initialStart: Date?,
        initialDue: Date?,
        onPick: @escaping (Date?, Date) -> Void,
        onClear: @escaping () -> Void
    ) {
        self.initialStart = initialStart
        self.initialDue = initialDue
        self.onPick = onPick
        self.onClear = onClear
        let today = Calendar.current.startOfDay(for: Date())
        let initialDueValue = initialDue ?? today
        _useRange = State(initialValue: initialStart != nil)
        _start = State(initialValue: initialStart ?? initialDueValue)
        _due = State(initialValue: initialDueValue)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $useRange) {
                Text("时间段")
                    .font(.system(size: 11))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            if useRange {
                VStack(alignment: .leading, spacing: 6) {
                    DatePicker("开始", selection: $start, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(.system(size: 11))
                    DatePicker("截止", selection: $due, in: start..., displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .font(.system(size: 11))
                }
            } else {
                DatePicker("截止日期", selection: $due, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
            
            HStack {
                Button("清除") { onClear() }
                    .disabled(initialDue == nil && initialStart == nil)
                Spacer()
                Button("确定") {
                    let cal = Calendar.current
                    let dueDay = cal.startOfDay(for: due)
                    if useRange {
                        let startDay = cal.startOfDay(for: start)
                        onPick(startDay, max(startDay, dueDay))
                    } else {
                        onPick(nil, dueDay)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
