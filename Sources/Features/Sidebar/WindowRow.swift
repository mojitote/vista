import SwiftUI

struct WindowRow: View {
    let window: WindowItem
    let spaceIndex: Int
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showPreview = false
    
    private var displayApp: String {
        viewModel.windowNames[window.id] ?? window.app
    }
    
    private var sceneColor: Color? {
        guard let scene = sceneStore.scene(forSpaceIndex: spaceIndex) else { return nil }
        guard let nsColor = NSColor(hex: scene.colorHex) else { return nil }
        return Color(nsColor: nsColor)
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Active indicator
            if window.hasFocus {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DesignTokens.Colors.activeIndicator)
                    .frame(width: AppConstants.activeIndicatorWidth, height: 20)
            } else {
                Color.clear
                    .frame(width: AppConstants.activeIndicatorWidth, height: 20)
            }
            
            // App icon
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: AppConstants.appIconSize, height: AppConstants.appIconSize)
            }
            
            // Window info
            VStack(alignment: .leading, spacing: 2) {
                Text(displayApp)
                    .font(.system(size: 12, weight: window.hasFocus ? .semibold : .regular))
                    .lineLimit(1)
                
                if !window.title.isEmpty {
                    Text(window.title)
                        .font(.system(size: DesignTokens.Font.captionSize))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 关闭按钮（hover 时显示）
            if isHovered {
                CloseButton {
                    viewModel.closeWindow(id: window.id)
                }
            }
            
            // 预览按钮（hover 或预览打开时显示）
            if settingsStore.previewEnabled && window.thumbnail != nil && (isHovered || showPreview) {
                Button(action: { showPreview.toggle() }) {
                    Image(systemName: showPreview ? "eye.fill" : "eye")
                        .font(.system(size: 10))
                        .foregroundColor(showPreview ? DesignTokens.Colors.activeIndicator : DesignTokens.Colors.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(isHovered ? DesignTokens.Colors.hoverBackground :
                      sceneColor?.opacity(0.08) ?? Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if !hovering {
                // 鼠标离开时不关闭预览，让用户手动关闭或点击其他地方关闭
            }
        }
        .popover(isPresented: $showPreview, arrowEdge: .trailing) {
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: settingsStore.previewMaxWidth, maxHeight: settingsStore.previewMaxWidth * 0.625)
                    .padding(6)
            }
        }
        .onTapGesture {
            viewModel.focusWindow(id: window.id, spaceIndex: spaceIndex)
        }
        .contextMenu {
            Button(action: {
                viewModel.focusWindow(id: window.id, spaceIndex: spaceIndex)
            }) {
                Label("切换到此窗口", systemImage: "arrow.right.circle")
            }
            
            Button(action: {
                renameText = viewModel.windowNames[window.id] ?? window.app
                isRenaming = true
            }) {
                Label("重命名", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.closeWindow(id: window.id)
            }) {
                Label("关闭窗口", systemImage: "xmark.circle")
            }
        }
        .popover(isPresented: $isRenaming, arrowEdge: .trailing) {
            VStack(spacing: 8) {
                Text("重命名窗口")
                    .font(.headline)
                TextField("名称", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit {
                        if renameText.isEmpty || renameText == window.app {
                            viewModel.windowNames.removeValue(forKey: window.id)
                        } else {
                            viewModel.windowNames[window.id] = renameText
                        }
                        isRenaming = false
                    }
                HStack {
                    Button("取消") {
                        isRenaming = false
                    }
                    Spacer()
                    Button("确定") {
                        if renameText.isEmpty || renameText == window.app {
                            viewModel.windowNames.removeValue(forKey: window.id)
                        } else {
                            viewModel.windowNames[window.id] = renameText
                        }
                        isRenaming = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
        }
        .onDrag {
            NSItemProvider(object: "\(window.id)" as NSString)
        }
        .opacity(window.isMinimized ? 0.5 : 1.0)
    }
}

private struct CloseButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(isHovered ? DesignTokens.Colors.closeButtonHover : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("关闭窗口")
    }
}
