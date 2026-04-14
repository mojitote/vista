import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
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
                        ForEach(viewModel.displayGroups) { group in
                            DisplaySection(
                                group: group,
                                viewModel: viewModel,
                                onDismiss: onDismiss
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
