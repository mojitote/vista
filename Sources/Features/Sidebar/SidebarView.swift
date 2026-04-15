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
    
    /// 激活 Scene 的主题色（低透明度），用于整个面板背景
    private var panelBackgroundColor: Color {
        guard let scene = sceneStore.activeScene,
              let nsColor = NSColor(hex: scene.colorHex) else {
            return Color.clear
        }
        return Color(nsColor: nsColor).opacity(0.05)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            contentBody
        }
        .background(panelBackgroundColor)
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
                                    sceneStore: sceneStore,
                                    onDismiss: onDismiss
                                )
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                    
                    SceneBar(sceneStore: sceneStore, onOpenSettings: onOpenSettings)
                }
            case .popup:
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.filteredDisplayGroups) { group in
                                DisplaySection(
                                    group: group,
                                    viewModel: viewModel,
                                    spaceNameStore: spaceNameStore,
                                    settingsStore: settingsStore,
                                    sceneStore: sceneStore,
                                    onDismiss: onDismiss
                                )
                            }
                        }
                        .padding(.vertical, DesignTokens.Spacing.md)
                    }
                    .frame(maxHeight: presentationStore.popupContentMaxHeight)
                    
                    SceneBar(sceneStore: sceneStore, onOpenSettings: onOpenSettings)
                }
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
