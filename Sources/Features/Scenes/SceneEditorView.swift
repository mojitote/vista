import SwiftUI
import Carbon

struct SceneEditorView: View {
    @ObservedObject var sceneStore: SceneStore
    var editingScene: VistaScene?
    var preselectedSpaceUUID: String?
    
    @State private var name: String = ""
    @State private var icon: String = "square.grid.2x2"
    @State private var selectedSpaceUUIDs: Set<String> = []
    @State private var availableSpaces: [(uuid: String, index: Int)] = []
    @State private var selectedColorHex: String = "#5E9EFF"
    @State private var selectedGradientColors: [String] = []
    @State private var selectedColorOpacity: Double = 0.5
    @State private var selectedGradientAngle: Double = -45
    @State private var selectedTexture: Double = 0
    @State private var hotkeyKeyCode: UInt32?
    @State private var hotkeyModifiers: UInt32?
    @State private var isRecordingHotkey = false
    
    @Environment(\.dismiss) private var dismiss
    
    private var isEditing: Bool { editingScene != nil }
    
    private let iconOptions = [
        "square.grid.2x2", "laptopcomputer", "bubble.left.and.bubble.right",
        "paintbrush", "doc.text", "music.note", "gamecontroller",
        "envelope", "calendar", "folder", "globe", "wrench.and.screwdriver"
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
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 6), spacing: 8) {
                    ForEach(iconOptions, id: \.self) { iconName in
                        Image(systemName: iconName)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(icon == iconName ? DesignTokens.Colors.activeIndicator.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(icon == iconName ? DesignTokens.Colors.activeIndicator : Color.clear, lineWidth: 1)
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
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                ZenColorPickerView(
                    colorHex: $selectedColorHex,
                    gradientColors: $selectedGradientColors,
                    opacity: $selectedColorOpacity,
                    gradientAngle: $selectedGradientAngle,
                    texture: $selectedTexture
                )
            }
            
            // Space 选择
            VStack(alignment: .leading, spacing: 4) {
                Text("包含的 Space")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                if availableSpaces.isEmpty {
                    Text("加载中...")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
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
                                        .fill(isSelected ? DesignTokens.Colors.activeIndicator.opacity(0.2) :
                                              isOccupied ? DesignTokens.Colors.subtleBackground :
                                              DesignTokens.Colors.subtleBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(isSelected ? DesignTokens.Colors.activeIndicator :
                                                isOccupied ? Color.clear : Color.clear, lineWidth: 1)
                                )
                                .opacity(isOccupied ? 0.5 : 1.0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            
            // 快捷键绑定
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷键")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                
                HStack {
                    if isRecordingHotkey {
                        Text("按下快捷键...")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.activeIndicator)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(DesignTokens.Colors.activeIndicator, lineWidth: 1)
                            )
                    } else if let keyCode = hotkeyKeyCode, let mods = hotkeyModifiers {
                        Text(hotkeyDisplayString(keyCode: keyCode, modifiers: mods))
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.subtleBackground)
                            )
                    } else {
                        Text("未设置")
                            .font(.system(size: 12))
                            .foregroundColor(DesignTokens.Colors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(DesignTokens.Colors.subtleBackground)
                            )
                    }
                    
                    Button(isRecordingHotkey ? "取消" : "录制") {
                        isRecordingHotkey.toggle()
                    }
                    .font(.system(size: 11))
                    
                    if hotkeyKeyCode != nil {
                        Button("清除") {
                            hotkeyKeyCode = nil
                            hotkeyModifiers = nil
                            isRecordingHotkey = false
                        }
                        .font(.system(size: 11))
                    }
                }
            }
            .background(
                // 隐形按键监听器
                HotkeyRecorderView(
                    isRecording: $isRecordingHotkey,
                    keyCode: $hotkeyKeyCode,
                    modifiers: $hotkeyModifiers
                )
                .frame(width: 0, height: 0)
            )
            
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
        .frame(width: 340)
        .onAppear {
            if let scene = editingScene {
                name = scene.name
                icon = scene.icon
                selectedSpaceUUIDs = Set(scene.spaceUUIDs)
                selectedColorHex = scene.colorHex
                selectedGradientColors = scene.gradientColors
                selectedColorOpacity = scene.colorOpacity
                selectedGradientAngle = scene.gradientAngle
                hotkeyKeyCode = scene.hotkeyKeyCode
                hotkeyModifiers = scene.hotkeyModifiers
            } else if let uuid = preselectedSpaceUUID {
                selectedSpaceUUIDs = [uuid]
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
            scene.gradientColors = selectedGradientColors
            scene.colorOpacity = selectedColorOpacity
            scene.gradientAngle = selectedGradientAngle
            scene.hotkeyKeyCode = hotkeyKeyCode
            scene.hotkeyModifiers = hotkeyModifiers
            sceneStore.updateScene(scene)
        } else {
            let scene = VistaScene(
                name: trimmedName,
                icon: icon,
                spaceUUIDs: Array(selectedSpaceUUIDs),
                colorHex: selectedColorHex,
                gradientColors: selectedGradientColors,
                colorOpacity: selectedColorOpacity,
                gradientAngle: selectedGradientAngle,
                hotkeyKeyCode: hotkeyKeyCode,
                hotkeyModifiers: hotkeyModifiers
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
    
    private func hotkeyDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
        HotkeyDisplay.string(keyCode: keyCode, modifiers: modifiers)
    }
}

// MARK: - Hotkey Recorder NSView

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var keyCode: UInt32?
    @Binding var modifiers: UInt32?
    
    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKeyRecorded = { code, mods in
            DispatchQueue.main.async {
                self.keyCode = code
                self.modifiers = mods
                self.isRecording = false
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        if isRecording {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

class HotkeyRecorderNSView: NSView {
    var isRecording = false
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        
        let mods = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !mods.isEmpty else { return }
        
        onKeyRecorded?(UInt32(event.keyCode), mods.carbonFlags)
    }
}

extension NSEvent.ModifierFlags {
    init(carbonFlags: UInt32) {
        self.init()
        if carbonFlags & UInt32(cmdKey) != 0 { insert(.command) }
        if carbonFlags & UInt32(shiftKey) != 0 { insert(.shift) }
        if carbonFlags & UInt32(optionKey) != 0 { insert(.option) }
        if carbonFlags & UInt32(controlKey) != 0 { insert(.control) }
    }
    
    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) { flags |= UInt32(cmdKey) }
        if contains(.shift) { flags |= UInt32(shiftKey) }
        if contains(.option) { flags |= UInt32(optionKey) }
        if contains(.control) { flags |= UInt32(controlKey) }
        return flags
    }
}
