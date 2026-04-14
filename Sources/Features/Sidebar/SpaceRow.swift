import SwiftUI

struct SpaceRow: View {
    let space: SpaceItem
    @ObservedObject var viewModel: SidebarViewModel
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Space header
            HStack(spacing: 0) {
                // Active indicator
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(space.hasFocus ? Color.accentColor : Color.clear)
                    .frame(width: AppConstants.activeIndicatorWidth, height: 20)
                    .padding(.trailing, 8)
                
                // Space name
                Text(space.displayName)
                    .font(.system(size: 13, weight: space.hasFocus ? .semibold : .regular))
                    .foregroundColor(space.hasFocus ? .primary : .secondary)
                
                Spacer()
                
                // Expand/collapse button
                if !space.windows.isEmpty {
                    Image(systemName: space.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .onTapGesture {
                            viewModel.toggleSpaceExpanded(spaceId: space.id)
                        }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(backgroundColor)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                viewModel.focusSpace(index: space.index)
                onDismiss?()
            }
            
            // Windows list
            if space.isExpanded {
                if space.windows.isEmpty {
                    Text("No windows")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 32)
                        .padding(.vertical, 4)
                } else {
                    ForEach(space.windows) { window in
                        WindowRow(
                            window: window,
                            spaceIndex: space.index,
                            viewModel: viewModel,
                            onDismiss: onDismiss
                        )
                    }
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if space.hasFocus {
            return Color.accentColor.opacity(0.1)
        } else if isHovered {
            return Color.primary.opacity(0.05)
        }
        return Color.clear
    }
}
