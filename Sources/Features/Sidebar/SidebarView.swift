import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var sceneStore: SceneStore
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(AppConstants.appName)
                    .font(.system(size: DesignTokens.Font.titleSize, weight: DesignTokens.Font.titleWeight))
                    .foregroundColor(DesignTokens.Colors.primaryText)
                Spacer()
                Button(action: { onOpenSettings?() }) {
                    Image(systemName: "gear")
                        .font(.system(size: 13))
                        .foregroundColor(DesignTokens.Colors.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.lg)
            
            Rectangle()
                .fill(DesignTokens.Colors.separator)
                .frame(height: 1)
            
            // Content
            if !viewModel.isYabaiRunning {
                yabaiNotRunningView
            } else if viewModel.isLoading && viewModel.displayGroups.isEmpty {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.filteredDisplayGroups) { group in
                            DisplaySection(
                                group: group,
                                viewModel: viewModel,
                                spaceNameStore: spaceNameStore,
                                settingsStore: settingsStore,
                                onDismiss: onDismiss
                            )
                        }
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
                
                // Scene 区域（底部固定）
                SceneBar(sceneStore: sceneStore)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(DesignTokens.Colors.toastBackground)
                            .shadow(color: DesignTokens.Shadow.toast, radius: DesignTokens.Shadow.toastRadius)
                    )
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.2), value: viewModel.toastMessage)
            }
        }
    }
    
    private var yabaiNotRunningView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(DesignTokens.Colors.fullscreenBadge)
            Text("yabai is not running")
                .font(.headline)
            Text("Please install and start yabai to use Vista.")
                .font(.caption)
                .foregroundColor(DesignTokens.Colors.secondaryText)
                .multilineTextAlignment(.center)
            Link("Install yabai", destination: URL(string: "https://github.com/koekeishiya/yabai")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
