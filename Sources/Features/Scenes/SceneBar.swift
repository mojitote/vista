import SwiftUI
import AppKit

struct SceneBar: View {
    @ObservedObject var sceneStore: SceneStore
    var onOpenSettings: (() -> Void)?
    var onGotoScene: ((VistaScene) -> Void)?
    @State private var showEditor = false
    @State private var editingScene: VistaScene?
    @State private var showAllHotkeyEditor = false
    @State private var colorEditingScene: VistaScene?
    @State private var colorPanelController = ColorEditorPanelController()
    
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
                            .foregroundColor(DesignTokens.Colors.onDarkSurface)
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
                                Button("设置颜色") {
                                    colorEditingScene = scene
                                    let sbPanel = NSApp.windows.first(where: { $0 is SidebarPanel }) as? SidebarPanel
                                    colorPanelController.show(sceneStore: sceneStore, scene: scene, near: sbPanel?.frame, sidebarPanel: sbPanel)
                                }
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

// MARK: - Scene Color Editor

private struct SceneColorEditorView: View {
    @ObservedObject var sceneStore: SceneStore
    let scene: VistaScene
    var onClose: (() -> Void)?
    var onColorChange: ((_ colorHex: String, _ gradientColors: [String], _ opacity: Double, _ angle: Double) -> Void)?
    
    @State private var colorHex: String
    @State private var gradientColors: [String]
    @State private var colorOpacity: Double
    @State private var gradientAngle: Double
    @State private var texture: Double
    @Environment(\.dismiss) private var dismiss
    
    init(sceneStore: SceneStore, scene: VistaScene, onClose: (() -> Void)? = nil, onColorChange: ((_ colorHex: String, _ gradientColors: [String], _ opacity: Double, _ angle: Double) -> Void)? = nil) {
        self.sceneStore = sceneStore
        self.scene = scene
        self.onClose = onClose
        self.onColorChange = onColorChange
        _colorHex = State(initialValue: scene.colorHex)
        _gradientColors = State(initialValue: scene.gradientColors)
        _colorOpacity = State(initialValue: scene.colorOpacity)
        _gradientAngle = State(initialValue: scene.gradientAngle)
        _texture = State(initialValue: 0)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: scene.icon)
                    .font(.system(size: 14))
                    .foregroundColor(Color(nsColor: NSColor(hex: colorHex) ?? .systemBlue))
                Text(scene.name)
                    .font(.headline)
                Spacer()
            }
            
            ZenColorPickerView(
                colorHex: $colorHex,
                gradientColors: $gradientColors,
                opacity: $colorOpacity,
                gradientAngle: $gradientAngle,
                texture: $texture
            )
            
            HStack {
                Button("取消") { 
                    // 恢复原始颜色
                    onColorChange?(scene.colorHex, scene.gradientColors, scene.colorOpacity, scene.gradientAngle)
                    if let onClose = onClose { onClose() } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") {
                    var updated = scene
                    updated.colorHex = colorHex
                    updated.gradientColors = gradientColors
                    updated.colorOpacity = colorOpacity
                    updated.gradientAngle = gradientAngle
                    sceneStore.updateScene(updated)
                    if let onClose = onClose { onClose() } else { dismiss() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onChange(of: colorHex) { _ in notifyColorChange() }
        .onChange(of: gradientColors) { _ in notifyColorChange() }
        .onChange(of: colorOpacity) { _ in notifyColorChange() }
        .onChange(of: gradientAngle) { _ in notifyColorChange() }
    }
    
    private func notifyColorChange() {
        onColorChange?(colorHex, gradientColors, colorOpacity, gradientAngle)
    }
}

// MARK: - Floating Color Editor Panel

final class ColorEditorPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var sidebarPanel: SidebarPanel?
    
    func show(sceneStore: SceneStore, scene: VistaScene, near sidebarFrame: NSRect?, sidebarPanel: SidebarPanel?) {
        // Close existing
        close()
        
        self.sidebarPanel = sidebarPanel
        sidebarPanel?.isDismissSuspended = true
        
        let colorEditor = SceneColorEditorView(
            sceneStore: sceneStore,
            scene: scene,
            onClose: { [weak self] in
                self?.close()
            },
            onColorChange: { [weak sidebarPanel] hex, gradientColors, opacity, angle in
                // 实时预览：直接更新 sidebar 颜色
                guard let panel = sidebarPanel else { return }
                if !gradientColors.isEmpty {
                    let nsColors = gradientColors.compactMap { NSColor(hex: $0) }
                    if !nsColors.isEmpty {
                        panel.updateSidebarGradient(colors: nsColors, angle: angle, opacity: opacity)
                        return
                    }
                }
                if let color = NSColor(hex: hex) {
                    panel.updateSidebarColor(color: color, opacity: opacity)
                }
            }
        )
        let hostingView = NSHostingView(rootView: colorEditor)
        hostingView.frame = NSRect(x: 0, y: 0, width: 340, height: 520)
        
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 520),
            styleMask: [.titled, .closable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isMovableByWindowBackground = false  // IMPORTANT: prevent panel dragging by content
        panel.isMovable = true  // Can still drag by title bar area
        panel.level = .floating
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = NSColor(named: "WindowBackgroundColor") ?? NSColor.windowBackgroundColor
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        
        // Position to the right of the sidebar
        if let sbFrame = sidebarFrame {
            let x = sbFrame.maxX + 12
            let y = sbFrame.midY - 260
            panel.setFrameOrigin(NSPoint(x: x, y: max(y, 50)))
        } else {
            panel.center()
        }
        
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }
    
    func close() {
        sidebarPanel?.isDismissSuspended = false
        panel?.close()
        panel = nil
    }
    
    // NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        sidebarPanel?.isDismissSuspended = false
        panel = nil
    }
}
