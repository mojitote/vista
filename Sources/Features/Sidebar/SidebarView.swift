import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var sceneStore: SceneStore
    @ObservedObject var spaceNameStore: SpaceNameStore
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(AppConstants.appName)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { onOpenSettings?() }) {
                    Image(systemName: "gear")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
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
                                onDismiss: onDismiss
                            )
                        }
                    }
                    .padding(.vertical, 8)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.75))
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
                .foregroundColor(.orange)
            Text("yabai is not running")
                .font(.headline)
            Text("Please install and start yabai to use Vista.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Link("Install yabai", destination: URL(string: "https://github.com/koekeishiya/yabai")!)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
