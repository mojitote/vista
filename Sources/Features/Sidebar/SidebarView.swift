import SwiftUI

enum SidebarPresentationMode {
    case fullHeight
    case popup
}

final class SidebarPresentationStore: ObservableObject {
    @Published var mode: SidebarPresentationMode = .fullHeight
    @Published var popupContentMaxHeight: CGFloat = 320
}

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    @ObservedObject var sceneStore: SceneStore
    @ObservedObject var spaceNameStore: SpaceNameStore
    @ObservedObject var settingsStore: SettingsStore
    @ObservedObject var presentationStore: SidebarPresentationStore
    var onDismiss: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Rectangle()
                .fill(DesignTokens.Colors.separator)
                .frame(height: 1)
            
            contentBody
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: presentationStore.mode == .fullHeight ? .infinity : nil,
            alignment: .topLeading
        )
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

    private var titleBar: some View {
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
    }
    
    @ViewBuilder
    private var contentBody: some View {
        if !viewModel.isYabaiRunning {
            if presentationStore.mode == .popup {
                yabaiNotRunningView
                    .frame(maxWidth: .infinity)
            } else {
                yabaiNotRunningView
            }
        } else if viewModel.isLoading && viewModel.displayGroups.isEmpty {
            if presentationStore.mode == .popup {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            switch presentationStore.mode {
            case .fullHeight:
                VStack(spacing: 0) {
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
                    
                    SceneBar(sceneStore: sceneStore)
                }
            case .popup:
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
                        
                        SceneBar(sceneStore: sceneStore)
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                }
                .frame(maxHeight: presentationStore.popupContentMaxHeight)
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
