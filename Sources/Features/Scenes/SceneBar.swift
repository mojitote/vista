import SwiftUI

struct SceneBar: View {
    @ObservedObject var sceneStore: SceneStore
    @State private var showEditor = false
    @State private var editingScene: VistaScene?
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            // 标题栏
            HStack {
                Text("Scenes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                // "全部"按钮 — 取消 Scene 过滤
                if sceneStore.activeSceneID != nil {
                    Button(action: {
                        sceneStore.activateScene(id: nil)
                    }) {
                        Text("All")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // 添加按钮
                Button(action: {
                    editingScene = nil
                    showEditor = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DesignTokens.Spacing.xl)
            .padding(.vertical, DesignTokens.Spacing.md)
            
            // Scene 列表
            if sceneStore.scenes.isEmpty {
                Text("无场景")
                    .font(.system(size: 11))
                    .foregroundColor(DesignTokens.Colors.subtleText)
                    .padding(.vertical, 8)
            } else {
                ForEach(sceneStore.scenes) { scene in
                    SceneRow(
                        scene: scene,
                        isActive: sceneStore.activeSceneID == scene.id,
                        onActivate: {
                            if sceneStore.activeSceneID == scene.id {
                                sceneStore.activateScene(id: nil)
                            } else {
                                sceneStore.activateScene(id: scene.id)
                            }
                        },
                        onEdit: {
                            editingScene = scene
                            showEditor = true
                        },
                        onDelete: {
                            sceneStore.deleteScene(id: scene.id)
                        }
                    )
                }
            }
        }
        .padding(.bottom, 8)
        .sheet(isPresented: $showEditor) {
            SceneEditorView(
                sceneStore: sceneStore,
                editingScene: editingScene
            )
        }
    }
}
