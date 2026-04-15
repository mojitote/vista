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
    
    var body: some View {
        VStack(spacing: 0) {
            // Space header
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
                
                // Scene icon + 名称 或 未归类图标 + Space 编号
                if let scene = belongingScene {
                    Image(systemName: scene.icon)
                        .font(.system(size: 11))
                        .foregroundColor(sceneColor ?? DesignTokens.Colors.secondaryText)
                    Text(scene.name)
                        .font(.system(size: 12, weight: space.hasFocus ? .semibold : .medium))
                        .foregroundColor(sceneColor ?? (space.hasFocus ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText))
                        .lineLimit(1)
                } else {
                    Image(systemName: "square.dashed")
                        .font(.system(size: 11))
                        .foregroundColor(DesignTokens.Colors.subtleText)
                    Text(spaceNameStore.name(forSpaceIndex: space.index) ?? space.displayName)
                        .font(.system(size: 12, weight: space.hasFocus ? .semibold : .medium))
                        .foregroundColor(space.hasFocus ? DesignTokens.Colors.primaryText : DesignTokens.Colors.secondaryText)
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
            .onTapGesture {
                viewModel.toggleSpaceExpanded(spaceId: space.id)
            }
            
            // Windows list
            if space.isExpanded {
                ForEach(space.windows) { window in
                    WindowRow(
                        window: window,
                        spaceIndex: space.index,
                        viewModel: viewModel,
                        settingsStore: settingsStore,
                        sceneStore: sceneStore,
                        onDismiss: onDismiss
                    )
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
            NSItemProvider(object: "space:\(space.index)" as NSString)
        }
        .popover(isPresented: $isRenaming, arrowEdge: .trailing) {
            VStack(spacing: 8) {
                Text("重命名 Space")
                    .font(.headline)
                TextField("名称", text: $renameText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit {
                        spaceNameStore.setName(renameText, forSpaceIndex: space.index)
                        isRenaming = false
                    }
                HStack {
                    Button("取消") {
                        isRenaming = false
                    }
                    Spacer()
                    Button("确定") {
                        spaceNameStore.setName(renameText, forSpaceIndex: space.index)
                        isRenaming = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(12)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let text = String(data: data, encoding: .utf8),
                  let windowID = Int(text) else { return }
            
            DispatchQueue.main.async {
                viewModel.moveWindowToSpace(windowID: windowID, spaceIndex: space.index)
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
