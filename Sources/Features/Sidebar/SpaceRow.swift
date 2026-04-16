import SwiftUI

struct SpaceRow: View {
    let space: SpaceItem
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    @State private var isDropTargeted = false
    @State private var isRenaming = false
    @State private var renameText = ""
    
    /// 该 Space 归属的 Scene
    private var belongingScene: VistaScene? {
        sceneStore.scene(forSpaceUUID: space.uuid)
    }
    
    /// 该 Space 归属的 Scene 主题颜色
    private var sceneColor: Color? {
        guard let scene = belongingScene else { return nil }
        guard let nsColor = NSColor(hex: scene.colorHex) else { return nil }
        return Color(nsColor: nsColor)
    }
    
    /// 是否应该显示 Space 标题行
    private var shouldShowHeader: Bool {
        return true
    }
    
    /// 全屏 Space 折叠为单行（不显示 header，窗口直接平铺）
    private var isFullscreenCollapsed: Bool {
        false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isFullscreenCollapsed {
                // 全屏 Space：不显示标题，窗口直接作为单行
                ForEach(space.windows) { window in
                    WindowRow(
                        window: window,
                        spaceIndex: space.index,
                        viewModel: viewModel,
                        settingsStore: settingsStore,
                        sceneStore: sceneStore,
                        onDismiss: onDismiss,
                        isFullscreen: true
                    )
                }
            } else {
                // 普通 Space
                if shouldShowHeader {
                    spaceHeader
                } else {
                    // 无标题：用细分隔线分隔
                    Rectangle()
                        .fill(DesignTokens.Colors.separator)
                        .frame(height: 0.5)
                        .padding(.horizontal, DesignTokens.Spacing.lg)
                        .padding(.vertical, 2)
                }
                
                // 窗口列表（无标题时默认展开）
                if space.isExpanded || !shouldShowHeader {
                    ForEach(space.windows) { window in
                        WindowRow(
                            window: window,
                            spaceIndex: space.index,
                            viewModel: viewModel,
                            settingsStore: settingsStore,
                            sceneStore: sceneStore,
                            onDismiss: onDismiss,
                            isFullscreen: space.isNativeFullscreen
                        )
                    }
                }
            }
        }
        // 整个 Space 区域的背景（hover / drop / scene 底色）
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(isDropTargeted ? DesignTokens.Colors.dropTargetBackground :
                      isHovered ? (sceneColor?.opacity(0.15) ?? DesignTokens.Colors.hoverBackground) :
                      sceneColor?.opacity(0.08) ?? Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            // #region debug-point B:space-hover
            let ts = CFAbsoluteTimeGetCurrent()
            DebugReport.send(hypothesisId: "B", location: "SpaceRow.onHover", msg: "[DEBUG] hover=\(hovering) space=\(space.index)", data: ["ts": ts, "hovering": hovering, "spaceIndex": space.index])
            // #endregion
            isHovered = hovering
        }
        .contextMenu {
            Button(action: {
                viewModel.focusSpace(index: space.index)
            }) {
                Label("切换到此 Space", systemImage: "arrow.right.circle")
            }
            
            Button(action: {
                renameText = spaceNameStore.name(forSpaceIndex: space.index) ?? space.displayName
                isRenaming = true
            }) {
                Label("重命名", systemImage: "pencil")
            }
            
            Divider()
            
            // 归属 Scene 子菜单
            Menu {
                // "无归属"选项
                Button(action: {
                    removeSpaceFromCurrentScene()
                }) {
                    HStack {
                        Label("无", systemImage: "square.dashed")
                        if belongingScene == nil {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
                
                ForEach(sceneStore.scenes) { scene in
                    let isCurrent = belongingScene?.id == scene.id
                    Button(action: {
                        assignSpaceToScene(scene)
                    }) {
                        HStack {
                            Label(scene.name, systemImage: scene.icon)
                            if isCurrent {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("归属 Scene", systemImage: "folder.badge.gearshape")
            }
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.destroySpace(index: space.index)
            }) {
                Label("关闭 Space", systemImage: "xmark.circle")
            }
        }
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
        .onDrag {
            NSItemProvider(object: "space:\(space.uuid)" as NSString)
        }
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.async {
                    NSApp.windows.first(where: { $0.isVisible && $0 is SidebarPanel })?.makeKey()
                }
            }
        }
    }
    
    @ViewBuilder
    private var spaceHeader: some View {
        HStack(spacing: 6) {
            // Active indicator
            if space.hasFocus {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(sceneColor ?? DesignTokens.Colors.activeIndicator)
                    .frame(width: AppConstants.activeIndicatorWidth, height: 16)
            } else {
                Color.clear
                    .frame(width: AppConstants.activeIndicatorWidth, height: 16)
            }
            
            if isRenaming {
                TextField("名称", text: $renameText, onCommit: {
                    spaceNameStore.setName(renameText.isEmpty ? nil : renameText, forSpaceIndex: space.index)
                    isRenaming = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .onExitCommand { isRenaming = false }
            } else if let scene = belongingScene {
                Image(systemName: scene.icon)
                    .font(.system(size: 10))
                    .foregroundColor(sceneColor ?? DesignTokens.Colors.secondaryText)
                Text(scene.name)
                    .font(.system(size: 11, weight: space.hasFocus ? .semibold : .medium))
                    .foregroundColor(sceneColor ?? (space.hasFocus ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText))
                    .lineLimit(1)
            } else if let customName = spaceNameStore.name(forSpaceIndex: space.index) {
                Text(customName)
                    .font(.system(size: 11, weight: space.hasFocus ? .semibold : .medium))
                    .foregroundColor(space.hasFocus ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText)
                    .lineLimit(1)
            } else {
                Image(systemName: "square.dashed")
                    .font(.system(size: 9))
                    .foregroundColor(DesignTokens.Colors.subtleText)
                Text(space.displayName)
                    .font(.system(size: 11, weight: space.hasFocus ? .medium : .regular))
                    .foregroundColor(space.hasFocus ? DesignTokens.Colors.secondaryText : DesignTokens.Colors.subtleText)
                    .lineLimit(1)
            }
            
            if space.isVisible {
                Circle()
                    .fill(DesignTokens.Colors.visibleDot)
                    .frame(width: 5, height: 5)
            }
            
            if space.isNativeFullscreen {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 8))
                    .foregroundColor(DesignTokens.Colors.fullscreenBadge)
                    .help("全屏模式")
            }
            
            Spacer()
            
            Text("\(space.windows.count)")
                .font(.system(size: DesignTokens.Font.badgeSize))
                .foregroundColor(DesignTokens.Colors.subtleText)
            
            Image(systemName: space.isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 9))
                .foregroundColor(DesignTokens.Colors.subtleText)
                .frame(width: 12)
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            viewModel.focusSpace(index: space.index, warpMouse: true)
        }
        .onTapGesture(count: 1) {
            viewModel.toggleSpaceExpanded(spaceId: space.id)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let text = String(data: data, encoding: .utf8) else { return }
            
            DispatchQueue.main.async {
                if text.hasPrefix("space:") {
                    let spaceUUID = String(text.dropFirst("space:".count))
                    // 通过 UUID 查找 space index
                    guard let sourceSpace = viewModel.displayGroups.flatMap(\.spaces).first(where: { $0.uuid == spaceUUID }) else { return }
                    // 找到当前 drop 目标所在 display
                    if let displayIndex = viewModel.displayGroups.first(where: { $0.spaces.contains(where: { $0.index == space.index }) })?.index {
                        viewModel.moveSpaceToDisplay(spaceIndex: sourceSpace.index, displayIndex: displayIndex)
                    }
                } else if let windowID = Int(text) {
                    viewModel.moveWindowToSpace(windowID: windowID, spaceIndex: space.index)
                }
            }
        }
        return true
    }
    
    /// 将此 Space 分配到指定 Scene（先从旧 Scene 移除）
    private func assignSpaceToScene(_ targetScene: VistaScene) {
        // 先从当前归属的 Scene 中移除
        if let current = belongingScene, current.id != targetScene.id {
            var updated = current
            updated.spaceUUIDs.removeAll { $0 == space.uuid }
            sceneStore.updateScene(updated)
        }
        // 添加到目标 Scene
        var target = targetScene
        if !target.spaceUUIDs.contains(space.uuid) {
            target.spaceUUIDs.append(space.uuid)
        }
        sceneStore.updateScene(target)
    }
    
    /// 从当前归属的 Scene 中移除此 Space
    private func removeSpaceFromCurrentScene() {
        guard var scene = belongingScene else { return }
        scene.spaceUUIDs.removeAll { $0 == space.uuid }
        sceneStore.updateScene(scene)
    }
}
