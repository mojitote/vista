import SwiftUI

struct WindowRow: View {
    let window: WindowItem
    let spaceIndex: Int
    @ObservedObject var viewModel: SidebarViewModel
    var onDismiss: (() -> Void)?
    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""
    
    private var displayApp: String {
        viewModel.windowNames[window.id] ?? window.app
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Active indicator
            if window.hasFocus {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
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
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
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
            
            // Thumbnail
            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: CGFloat(AppConstants.largeThumbnailWidth), maxHeight: CGFloat(AppConstants.largeThumbnailHeight))
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 12)
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
                .foregroundColor(isHovered ? .white : .secondary)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(isHovered ? Color.red : Color.primary.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("关闭窗口")
    }
}
