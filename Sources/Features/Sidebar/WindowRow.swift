import SwiftUI

struct WindowRow: View {
    let window: WindowItem
    let spaceIndex: Int
    @ObservedObject var viewModel: SidebarViewModel
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // App icon
            if let icon = window.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: AppConstants.appIconSize, height: AppConstants.appIconSize)
            } else {
                Image(systemName: "app")
                    .frame(width: AppConstants.appIconSize, height: AppConstants.appIconSize)
            }
            
            // Window title
            VStack(alignment: .leading, spacing: 1) {
                Text(window.app)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if !window.title.isEmpty {
                    Text(window.title)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Thumbnail
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: AppConstants.thumbnailWidth, height: AppConstants.thumbnailHeight)
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.leading, 16)  // Extra indent for windows under space
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            viewModel.focusWindow(id: window.id, spaceIndex: spaceIndex)
            onDismiss?()
        }
    }
}
