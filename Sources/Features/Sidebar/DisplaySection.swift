import SwiftUI

struct DisplaySection: View {
    let group: DisplayGroup
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    @State private var isDropTargeted = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display header
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 10))
                    .foregroundColor(DesignTokens.Colors.sectionHeader)
                Text(group.displayName)
                    .font(.system(size: DesignTokens.Font.sectionHeaderSize, weight: DesignTokens.Font.sectionHeaderWeight))
                    .foregroundColor(DesignTokens.Colors.sectionHeader)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            
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
    }
    
    private func handleSpaceDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, _ in
            guard let data = data as? Data,
                  let text = String(data: data, encoding: .utf8),
                  text.hasPrefix("space:"),
                  let spaceIndex = Int(text.dropFirst("space:".count)) else { return }
            
            DispatchQueue.main.async {
                viewModel.moveSpaceToDisplay(spaceIndex: spaceIndex, displayIndex: group.index)
            }
        }
        return true
    }
}
