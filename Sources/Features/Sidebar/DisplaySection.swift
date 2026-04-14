import SwiftUI

struct DisplaySection: View {
    let group: DisplayGroup
    @ObservedObject var viewModel: SidebarViewModel
    var onDismiss: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Display header
            HStack(spacing: 6) {
                Image(systemName: "display")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(group.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Spaces
            ForEach(group.spaces) { space in
                SpaceRow(
                    space: space,
                    viewModel: viewModel,
                    onDismiss: onDismiss
                )
            }
            
            Divider()
                .padding(.vertical, 4)
        }
    }
}
