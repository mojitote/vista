import SwiftUI

struct DisplaySection: View {
    let group: DisplayGroup
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var sceneStore: SceneStore
    var onDismiss: (() -> Void)?
    
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
    }
}
