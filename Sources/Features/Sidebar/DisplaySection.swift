import SwiftUI

/// 迷你显示屏布局图，展示所有显示屏的相对位置，当前高亮
struct MiniDisplayMap: View {
    let allGroups: [DisplayGroup]
    let currentUUID: String
    
    private let mapWidth: CGFloat = 40
    private let mapHeight: CGFloat = 24
    
    var body: some View {
        Canvas { context, size in
            guard !allGroups.isEmpty else { return }
            
            // 计算所有显示屏的 bounding box
            var minX = CGFloat.infinity, minY = CGFloat.infinity
            var maxX = -CGFloat.infinity, maxY = -CGFloat.infinity
            for g in allGroups {
                minX = min(minX, g.frame.x)
                minY = min(minY, g.frame.y)
                maxX = max(maxX, g.frame.x + g.frame.w)
                maxY = max(maxY, g.frame.y + g.frame.h)
            }
            
            let totalW = maxX - minX
            let totalH = maxY - minY
            guard totalW > 0, totalH > 0 else { return }
            
            // 等比缩放，留 1pt padding
            let pad: CGFloat = 1
            let availW = size.width - pad * 2
            let availH = size.height - pad * 2
            let scale = min(availW / totalW, availH / totalH)
            
            // 居中偏移
            let scaledW = totalW * scale
            let scaledH = totalH * scale
            let offX = pad + (availW - scaledW) / 2
            let offY = pad + (availH - scaledH) / 2
            
            for g in allGroups {
                let x = offX + (g.frame.x - minX) * scale
                let y = offY + (g.frame.y - minY) * scale
                let w = g.frame.w * scale
                let h = g.frame.h * scale
                let rect = CGRect(x: x, y: y, width: w, height: h)
                let path = RoundedRectangle(cornerRadius: 1).path(in: rect)
                
                if g.uuid == currentUUID {
                    context.fill(path, with: .color(DesignTokens.Colors.sectionHeader.opacity(0.8)))
                } else {
                    context.fill(path, with: .color(DesignTokens.Colors.subtleText.opacity(0.3)))
                }
                context.stroke(path, with: .color(DesignTokens.Colors.subtleText.opacity(0.5)), lineWidth: 0.5)
            }
        }
        .frame(width: mapWidth, height: mapHeight)
    }
}

struct DisplaySection: View {
    let group: DisplayGroup
    let allGroups: [DisplayGroup]
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    @State private var isDropTargeted = false
    @State private var isRenaming = false
    @State private var renameText = ""
    
    private var effectiveDisplayName: String {
        spaceNameStore.displayName(forUUID: group.uuid) ?? group.displayName
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display header
            HStack(spacing: 6) {
                MiniDisplayMap(allGroups: allGroups, currentUUID: group.uuid)
                if isRenaming {
                    TextField("名称", text: $renameText, onCommit: {
                        spaceNameStore.setDisplayName(renameText.isEmpty ? nil : renameText, forUUID: group.uuid)
                        isRenaming = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: DesignTokens.Font.sectionHeaderSize, weight: DesignTokens.Font.sectionHeaderWeight))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(effectiveDisplayName)
                        .font(.system(size: DesignTokens.Font.sectionHeaderSize, weight: DesignTokens.Font.sectionHeaderWeight))
                        .foregroundColor(DesignTokens.Colors.sectionHeader)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Spacer()
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            .contentShape(Rectangle())
            .contextMenu {
                Button(action: {
                    renameText = spaceNameStore.displayName(forUUID: group.uuid) ?? group.displayName
                    isRenaming = true
                }) {
                    Label("重命名", systemImage: "pencil")
                }
                
                Divider()
                
                Text("分辨率: \(group.resolution)")
                Text("位置: \(group.position)")
                Text("UUID: \(group.uuid.prefix(8))...")
            }
            
            // Spaces
            ForEach(group.spaces) { space in
                SpaceRow(
                    space: space,
                    viewModel: viewModel,
                    spaceNameStore: spaceNameStore,
                    settingsStore: settingsStore,
                    sceneStore: sceneStore,
                    onDismiss: onDismiss
                )
            }
            
            Rectangle()
                .fill(DesignTokens.Colors.separator)
                .frame(height: 1)
                .padding(.vertical, 4)
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
                .fill(isDropTargeted ? DesignTokens.Colors.dropTargetBackground : Color.clear)
        )
        .onDrop(of: [.text], isTargeted: $isDropTargeted) { providers in
            handleSpaceDrop(providers: providers)
        }
        .onChange(of: isRenaming) { renaming in
            if renaming {
                DispatchQueue.main.async {
                    NSApp.windows.first(where: { $0.isVisible && $0 is SidebarPanel })?.makeKey()
                }
            }
        }
    }
    
    private func handleSpaceDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let text = String(data: data, encoding: .utf8),
                  text.hasPrefix("space:") else { return }
            
            let spaceUUID = String(text.dropFirst("space:".count))
            guard let sourceSpace = viewModel.displayGroups.flatMap(\.spaces).first(where: { $0.uuid == spaceUUID }) else { return }
            
            DispatchQueue.main.async {
                viewModel.moveSpaceToDisplay(spaceIndex: sourceSpace.index, displayIndex: group.index)
            }
        }
        return true
    }
}
