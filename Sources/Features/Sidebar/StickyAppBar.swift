import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Scene 顶部的快捷启动栏。
/// 点击图标 → 在 sidebar 弹出来源 display 上 focus / 新开应用窗口。
/// 点击不会关闭 sidebar，方便用户连续操作或查看结果。
struct StickyAppBar: View {
    @ObservedObject var sceneStore: SceneStore
    @ObservedObject var viewModel: SidebarViewModel
    var onDismiss: (() -> Void)?  // 保留参数以兼容调用方，但点击 sticky 不再使用
    
    @State private var editingShortcutForApp: StickyApp?
    
    private let iconSize: CGFloat = 24
    private let rowHeight: CGFloat = 36
    
    private var apps: [StickyApp] {
        sceneStore.currentStickyApps
    }
    
    var body: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(apps) { app in
                        appButton(app)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.xl)
            }
            
            addButton
                .padding(.trailing, DesignTokens.Spacing.xl)
        }
        .frame(height: rowHeight)
        .background(stickyBackground)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleAppDrop(providers: providers)
        }
        .sheet(item: $editingShortcutForApp) { app in
            StickyAppShortcutEditor(
                app: app,
                onSave: { keyCode, modifiers in
                    sceneStore.updateStickyAppShortcut(id: app.id, keyCode: keyCode, modifiers: modifiers)
                    editingShortcutForApp = nil
                },
                onCancel: { editingShortcutForApp = nil }
            )
        }
    }
    
    // MARK: - Subviews
    
    private var stickyBackground: some View {
        Rectangle()
            .fill(DesignTokens.Colors.subtleText.opacity(0.04))
            .overlay(
                Rectangle()
                    .fill(DesignTokens.Colors.separator)
                    .frame(height: 1),
                alignment: .bottom
            )
    }
    
    @ViewBuilder
    private func appButton(_ app: StickyApp) -> some View {
        Button(action: {
            viewModel.focusStickyApp(app)
        }) {
            iconView(for: app)
        }
        .buttonStyle(StickyAppButtonStyle())
        .help(tooltip(for: app))
        .contextMenu {
            // —— 新建窗口动作 ——
            Button("新建窗口（\(currentDisplayLabel)）") {
                viewModel.newWindowForStickyApp(app)
            }
            
            if viewModel.displayGroups.count > 1 {
                Menu("在指定 Display 新建窗口") {
                    ForEach(viewModel.displayGroups, id: \.id) { group in
                        Button(group.displayName) {
                            viewModel.newWindowForStickyApp(app, onDisplay: group.index)
                        }
                    }
                }
            }
            
            Divider()
            
            // —— 配置 ——
            Button("设置新建窗口快捷键（当前 \(shortcutLabel(for: app))）…") {
                editingShortcutForApp = app
            }
            
            Divider()
            
            Button("从快捷栏移除", role: .destructive) {
                sceneStore.removeStickyAppFromCurrent(id: app.id)
            }
        }
    }
    
    private var currentDisplayLabel: String {
        if let idx = viewModel.activeDisplayIndex,
           let group = viewModel.displayGroups.first(where: { $0.index == idx }) {
            return group.displayName
        }
        return "默认"
    }
    
    private func shortcutLabel(for app: StickyApp) -> String {
        if let kc = app.newWindowKeyCode, let mods = app.newWindowModifiers {
            return HotkeyDisplay.string(keyCode: kc, modifiers: mods)
        }
        return "⌘N"
    }
    
    @ViewBuilder
    private func iconView(for app: StickyApp) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
        } else {
            Image(systemName: "questionmark.app.dashed")
                .font(.system(size: iconSize - 4))
                .foregroundColor(DesignTokens.Colors.subtleText)
                .frame(width: iconSize, height: iconSize)
        }
    }
    
    private func tooltip(for app: StickyApp) -> String {
        let display: String
        if let idx = viewModel.activeDisplayIndex,
           let group = viewModel.displayGroups.first(where: { $0.index == idx }) {
            display = group.displayName
        } else {
            display = "默认"
        }
        return "\(app.displayName)\n左键：聚焦任意窗口（优先 \(display)）\n右键：新建窗口"
    }
    
    private var addButton: some View {
        Button(action: pickApp) {
            Image(systemName: "plus.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .frame(width: iconSize, height: iconSize)
        }
        .buttonStyle(StickyAppButtonStyle())
        .help("添加应用到快捷栏")
    }
    
    // MARK: - Actions
    
    private func pickApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "选择要加入快捷栏的应用（可多选）"
        if panel.runModal() == .OK {
            for url in panel.urls {
                addApp(from: url)
            }
        }
    }
    
    private func handleAppDrop(providers: [NSItemProvider]) -> Bool {
        var added = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "app" else { return }
                DispatchQueue.main.async {
                    addApp(from: url)
                }
            }
            added = true
        }
        return added
    }
    
    private func addApp(from url: URL) {
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            viewModel.showToast("无法识别应用：\(url.lastPathComponent)")
            return
        }
        let displayName = (FileManager.default.displayName(atPath: url.path)
            .replacingOccurrences(of: ".app", with: ""))
        sceneStore.addStickyAppToCurrent(bundleID: bundleID, displayName: displayName)
    }
}

// MARK: - Shortcut Editor Sheet

private struct StickyAppShortcutEditor: View {
    let app: StickyApp
    let onSave: (UInt32?, UInt32?) -> Void
    let onCancel: () -> Void
    
    @State private var isRecording = false
    @State private var keyCode: UInt32?
    @State private var modifiers: UInt32?
    
    private var shortcutString: String {
        if let kc = keyCode, let mods = modifiers {
            return HotkeyDisplay.string(keyCode: kc, modifiers: mods)
        }
        return "⌘N（默认）"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(app.displayName) — 新建窗口快捷键")
                .font(.system(size: 13, weight: .semibold))
            
            Text("点击「录制」后按下你想发给该应用的组合键。\n大多数 app 用 ⌘N，部分用 ⌘⇧N（Safari 私密窗）或 ⌘⌥N。")
                .font(.system(size: 11))
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            
            HStack(spacing: 8) {
                Text(isRecording ? "按下组合键…" : shortcutString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(isRecording ? DesignTokens.Colors.activeIndicator : DesignTokens.Colors.primaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 120, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(DesignTokens.Colors.subtleBackground)
                    )
                
                Button(isRecording ? "取消录制" : "录制") {
                    isRecording.toggle()
                }
                .font(.system(size: 11))
                
                if keyCode != nil {
                    Button("清除（用默认 ⌘N）") {
                        keyCode = nil
                        modifiers = nil
                        isRecording = false
                    }
                    .font(.system(size: 11))
                }
            }
            .background(
                HotkeyRecorderView(
                    isRecording: $isRecording,
                    keyCode: $keyCode,
                    modifiers: $modifiers
                )
                .frame(width: 0, height: 0)
            )
            
            HStack {
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("保存") { onSave(keyCode, modifiers) }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear {
            keyCode = app.newWindowKeyCode
            modifiers = app.newWindowModifiers
        }
    }
}

// MARK: - Button Style

private struct StickyAppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(configuration.isPressed
                          ? DesignTokens.Colors.subtleText.opacity(0.18)
                          : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
