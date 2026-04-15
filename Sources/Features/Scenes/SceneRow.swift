import SwiftUI

struct SceneRow: View {
    let scene: VistaScene
    let isActive: Bool
    let onActivate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: scene.icon)
                .font(.system(size: 14))
                .foregroundColor(isActive ? DesignTokens.Colors.activeIndicator : DesignTokens.Colors.secondaryText)
                .frame(width: 20)
            
            Text(scene.name)
                .font(.system(size: 12, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
            
            Spacer()
            
            if isActive {
                Circle()
                    .fill(DesignTokens.Colors.activeIndicator)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onActivate()
        }
        .contextMenu {
            Button("编辑") { onEdit() }
            Divider()
            Button("删除", role: .destructive) { onDelete() }
        }
    }
}
