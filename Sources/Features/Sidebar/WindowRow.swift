import SwiftUI

struct WindowRow: View {
    let window: WindowItem
    let spaceIndex: Int
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    var isFullscreen: Bool = false
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showPreview = false
    @State private var previewImage: NSImage?
    
    private var displayApp: String {
        viewModel.windowNames[window.id] ?? window.app
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
            
            if isFullscreen {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Colors.fullscreenBadge)
            }
            
            // Window info
            VStack(alignment: .leading, spacing: 2) {
                if isRenaming {
                    TextField("名称", text: $renameText, onCommit: {
                        if renameText.isEmpty || renameText == window.app {
                            viewModel.windowNames.removeValue(forKey: window.id)
                        } else {
                            viewModel.windowNames[window.id] = renameText
                        }
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .regular))
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(displayApp)
                        .font(.system(size: 12, weight: window.hasFocus ? .semibold : .regular))
                        .lineLimit(1)
                }
                
                if !window.title.isEmpty && !isRenaming {
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
            if settingsStore.previewEnabled && (isHovered || showPreview) {
                Button(action: {
                    if !showPreview {
                        previewImage = WindowThumbnailService.shared.captureThumbnail(
                            windowID: CGWindowID(window.id),
                            size: NSSize(width: settingsStore.previewMaxWidth, height: settingsStore.previewMaxWidth * 0.625)
                        )
                    }
                    showPreview.toggle()
                }) {
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
                .fill(isHovered ? DesignTokens.Colors.hoverBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .popover(isPresented: $showPreview, arrowEdge: .trailing) {
            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: settingsStore.previewMaxWidth, maxHeight: settingsStore.previewMaxWidth * 0.625)
                    .padding(6)
            } else {
                Text("无法截取预览")
                    .font(.caption)
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .padding(12)
            }
        }
        .onTapGesture(count: 2) {
            viewModel.focusWindow(id: window.id, spaceIndex: spaceIndex, warpMouse: true)
        }
        .onTapGesture(count: 1) {
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
            
            Button(action: addToStickyBar) {
                Label("加入当前 Scene 快捷栏", systemImage: "pin")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.closeWindow(id: window.id)
            }) {
                Label("关闭窗口", systemImage: "xmark.circle")
            }
        }
        .onDrag {
            if isFullscreen {
                // 全屏窗口以 space 为单位拖拽，用 uuid 标识
                let spaceUUID = viewModel.displayGroups.flatMap(\.spaces).first(where: { $0.index == spaceIndex })?.uuid ?? ""
                return NSItemProvider(object: "space:\(spaceUUID)" as NSString)
            } else {
                return NSItemProvider(object: "\(window.id)" as NSString)
            }
        }
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.async {
                    NSApp.windows.first(where: { $0.isVisible && $0 is SidebarPanel })?.makeKey()
                }
            }
        }
        .opacity(window.isMinimized ? 0.5 : 1.0)
        .padding(.horizontal, DesignTokens.Spacing.md)
    }
    
    private func addToStickyBar() {
        guard let app = NSRunningApplication(processIdentifier: pid_t(window.pid)),
              let bundleID = app.bundleIdentifier else {
            viewModel.showToast("无法获取 \(window.app) 的 bundle ID")
            return
        }
        let displayName = app.localizedName ?? window.app
        sceneStore.addStickyAppToCurrent(bundleID: bundleID, displayName: displayName)
        viewModel.showToast("已加入快捷栏：\(displayName)")
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
            withAnimation(DesignTokens.Anim.fast) {
                isHovered = hovering
            }
        }
        .help("关闭窗口")
    }
}
