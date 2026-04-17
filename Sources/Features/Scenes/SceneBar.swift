import SwiftUI

struct SceneBar: View {
    @ObservedObject var sceneStore: SceneStore
    var onOpenSettings: (() -> Void)?
    var onGotoScene: ((VistaScene) -> Void)?
    @State private var showEditor = false
    @State private var editingScene: VistaScene?
    @State private var showAllHotkeyEditor = false
    
    private var activeScene: VistaScene? {
        sceneStore.activeScene
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // 激活 Scene 标题行（仅在有激活 Scene 时显示）
            if let scene = activeScene {
                HStack(spacing: 6) {
                    Image(systemName: scene.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: NSColor(hex: scene.colorHex) ?? .systemBlue))
                    
                    Text(scene.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(DesignTokens.Colors.primaryText)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: { onGotoScene?(scene) }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    .help("跳转到此场景的所有 Space")
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
                .padding(.vertical, DesignTokens.Spacing.sm)
            }
            
            // 底部工具行：齿轮 | All(小人) + scene icons (滚动) | ➕
            HStack(spacing: 8) {
                // 齿轮 — 打开应用设置
                Button(action: { onOpenSettings?() }) {
                    Image(systemName: "gear")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
                .buttonStyle(.plain)
                
                // Scene 图标列表（横向滚动），最左侧是 All（小人 icon）
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        // All — 小人 icon
                        let isAll = sceneStore.isAllActive
                        Button(action: {
                            sceneStore.activateScene(id: SceneStore.allSceneID)
                        }) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 14))
                                .foregroundColor(isAll ? DesignTokens.Colors.activeIndicator : DesignTokens.Colors.subtleText)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                        .fill(isAll ? DesignTokens.Colors.activeIndicator.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("设置快捷键") {
                                showAllHotkeyEditor = true
                            }
                        }
                        .help("显示全部")
                        
                        // 各 Scene icon
                        ForEach(sceneStore.scenes) { scene in
                            let isActive = sceneStore.activeSceneID == scene.id
                            let sceneColor = Color(nsColor: NSColor(hex: scene.colorHex) ?? .systemBlue)
                            
                            Button(action: {
                                if isActive {
                                    sceneStore.activateScene(id: SceneStore.allSceneID)
                                } else {
                                    sceneStore.activateScene(id: scene.id)
                                }
                            }) {
                                Image(systemName: scene.icon)
                                    .font(.system(size: 14))
                                    .foregroundColor(isActive ? sceneColor : DesignTokens.Colors.subtleText)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                            .fill(isActive ? sceneColor.opacity(0.15) : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("编辑") {
                                    editingScene = scene
                                    showEditor = true
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    sceneStore.deleteScene(id: scene.id)
                                }
                            }
                            .help(scene.name)
                        }
                    }
                }
                
                // ➕ 新建场景
                Button(action: {
                    editingScene = nil
                    showEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .sheet(isPresented: $showEditor) {
            SceneEditorView(
                sceneStore: sceneStore,
                editingScene: editingScene
            )
        }
        .sheet(isPresented: $showAllHotkeyEditor) {
            AllHotkeyEditorView(sceneStore: sceneStore)
        }
    }
}

// MARK: - All Hotkey Editor

struct AllHotkeyEditorView: View {
    @ObservedObject var sceneStore: SceneStore
    @State private var hotkeyKeyCode: UInt32?
    @State private var hotkeyModifiers: UInt32?
    @State private var isRecordingHotkey = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Text("All 快捷键")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷键")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                HStack {
                    if isRecordingHotkey {
                        Text("按下快捷键...")
                            .font(.system(size: 12))
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.accentColor, lineWidth: 1)
                            )
                    } else if let keyCode = hotkeyKeyCode, let mods = hotkeyModifiers {
                        Text(hotkeyDisplayString(keyCode: keyCode, modifiers: mods))
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.05))
                            )
                    } else {
                        Text("未设置")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.primary.opacity(0.05))
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
                Button("保存") {
                    sceneStore.updateAllHotkey(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 260)
        .onAppear {
            hotkeyKeyCode = sceneStore.allHotkeyKeyCode
            hotkeyModifiers = sceneStore.allHotkeyModifiers
        }
    }
    
    private func hotkeyDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
        HotkeyDisplay.string(keyCode: keyCode, modifiers: modifiers)
    }
}
