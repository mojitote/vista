import SwiftUI

struct SceneEditorView: View {
    @ObservedObject var sceneStore: SceneStore
    var editingScene: VistaScene?
    
    @State private var name: String = ""
    @State private var icon: String = "square.grid.2x2"
    @State private var selectedSpaces: Set<Int> = []
    @State private var availableSpaces: [Int] = []
    
    @Environment(\.dismiss) private var dismiss
    
    private var isEditing: Bool { editingScene != nil }
    
    // 常用 SF Symbol 图标
    private let iconOptions = [
        "square.grid.2x2", "laptopcomputer", "bubble.left.and.bubble.right",
        "paintbrush", "doc.text", "music.note", "gamecontroller",
        "envelope", "calendar", "folder", "globe", "wrench.and.screwdriver"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑场景" : "新建场景")
                .font(.headline)
            
            // 名称
            TextField("场景名称", text: $name)
                .textFieldStyle(.roundedBorder)
            
            // 图标选择
            VStack(alignment: .leading, spacing: 4) {
                Text("图标")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 6), spacing: 8) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        Image(systemName: iconName)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(icon == iconName ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(icon == iconName ? Color.accentColor : Color.clear, lineWidth: 1)
                            )
                            .onTapGesture {
                                icon = iconName
                            }
                    }
                }
            }
            
            // Space 选择
            VStack(alignment: .leading, spacing: 4) {
                Text("包含的 Space")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if availableSpaces.isEmpty {
                    Text("加载中...")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(60)), count: 4), spacing: 8) {
                        ForEach(availableSpaces, id: \.self) { spaceIndex in
                            Button(action: {
                                if selectedSpaces.contains(spaceIndex) {
                                    selectedSpaces.remove(spaceIndex)
                                } else {
                                    selectedSpaces.insert(spaceIndex)
                                }
                            }) {
                                Text("Space \(spaceIndex)")
                                    .font(.system(size: 10))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(selectedSpaces.contains(spaceIndex) ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.05))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(selectedSpaces.contains(spaceIndex) ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // 按钮
            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isEditing ? "保存" : "创建") {
                    saveScene()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            if let scene = editingScene {
                name = scene.name
                icon = scene.icon
                selectedSpaces = Set(scene.spaceIndices)
            }
            loadAvailableSpaces()
        }
    }
    
    private func saveScene() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        if var scene = editingScene {
            scene.name = trimmedName
            scene.icon = icon
            scene.spaceIndices = Array(selectedSpaces).sorted()
            sceneStore.updateScene(scene)
        } else {
            let scene = VistaScene(
                name: trimmedName,
                icon: icon,
                spaceIndices: Array(selectedSpaces).sorted()
            )
            sceneStore.addScene(scene)
        }
    }
    
    private func loadAvailableSpaces() {
        DispatchQueue.global(qos: .userInitiated).async {
            let spaces = (try? YabaiService.shared.querySpaces()) ?? []
            let indices = spaces.map(\.index).sorted()
            DispatchQueue.main.async {
                self.availableSpaces = indices
            }
        }
    }
}
