import SwiftUI

struct SceneEditorView: View {
    @ObservedObject var sceneStore: SceneStore
    var editingScene: VistaScene?
    
    @State private var name: String = ""
    @State private var icon: String = "square.grid.2x2"
    @State private var selectedSpaceUUIDs: Set<String> = []
    @State private var availableSpaces: [(uuid: String, index: Int)] = []
    @State private var selectedColorHex: String = "#5E9EFF"
    
    @Environment(\.dismiss) private var dismiss
    
    private var isEditing: Bool { editingScene != nil }
    
    private let iconOptions = [
        "square.grid.2x2", "laptopcomputer", "bubble.left.and.bubble.right",
        "paintbrush", "doc.text", "music.note", "gamecontroller",
        "envelope", "calendar", "folder", "globe", "wrench.and.screwdriver"
    ]
    
    private let colorOptions: [(name: String, hex: String)] = [
        ("蓝", "#5E9EFF"), ("绿", "#4ECDC4"), ("紫", "#9B59B6"),
        ("橙", "#F39C12"), ("红", "#E74C3C"), ("粉", "#FD79A8"),
        ("青", "#00CEC9"), ("黄", "#FDCB6E"), ("灰", "#95A5A6"),
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑场景" : "新建场景")
                .font(.headline)
            
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
            
            // 主题颜色选择
            VStack(alignment: .leading, spacing: 4) {
                Text("主题颜色")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 9), spacing: 8) {
                    ForEach(colorOptions, id: \.hex) { option in
                        Circle()
                            .fill(Color(nsColor: NSColor(hex: option.hex) ?? .systemBlue))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(selectedColorHex == option.hex ? Color.primary : Color.clear, lineWidth: 2)
                            )
                            .onTapGesture {
                                selectedColorHex = option.hex
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
                        ForEach(availableSpaces, id: \.uuid) { space in
                            let occupiedBy = occupyingScene(forUUID: space.uuid)
                            let isOccupied = occupiedBy != nil
                            let isSelected = selectedSpaceUUIDs.contains(space.uuid)
                            
                            Button(action: {
                                guard !isOccupied else { return }
                                if isSelected {
                                    selectedSpaceUUIDs.remove(space.uuid)
                                } else {
                                    selectedSpaceUUIDs.insert(space.uuid)
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Text("Space \(space.index)")
                                        .font(.system(size: 10))
                                    if let scene = occupiedBy {
                                        Text(scene.name)
                                            .font(.system(size: 8))
                                            .foregroundColor(Color(nsColor: NSColor(hex: scene.colorHex) ?? .gray))
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(isSelected ? Color.accentColor.opacity(0.2) :
                                              isOccupied ? Color.primary.opacity(0.02) :
                                              Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSelected ? Color.accentColor :
                                                isOccupied ? Color.clear : Color.clear, lineWidth: 1)
                                )
                                .opacity(isOccupied ? 0.5 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
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
                selectedSpaceUUIDs = Set(scene.spaceUUIDs)
                selectedColorHex = scene.colorHex
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
            scene.spaceUUIDs = Array(selectedSpaceUUIDs)
            scene.colorHex = selectedColorHex
            sceneStore.updateScene(scene)
        } else {
            let scene = VistaScene(
                name: trimmedName,
                icon: icon,
                spaceUUIDs: Array(selectedSpaceUUIDs),
                colorHex: selectedColorHex
            )
            sceneStore.addScene(scene)
        }
    }
    
    private func loadAvailableSpaces() {
        DispatchQueue.global(qos: .userInitiated).async {
            let spaces = (try? YabaiService.shared.querySpaces()) ?? []
            let mapped = spaces.map { (uuid: $0.uuid, index: $0.index) }.sorted { $0.index < $1.index }
            DispatchQueue.main.async {
                self.availableSpaces = mapped
            }
        }
    }
    
    private func occupyingScene(forUUID uuid: String) -> VistaScene? {
        sceneStore.scenes.first(where: {
            $0.id != editingScene?.id && $0.spaceUUIDs.contains(uuid)
        })
    }
}
