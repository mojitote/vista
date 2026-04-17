import SwiftUI
import AppKit

struct OnboardingView: View {
    @ObservedObject var store: OnboardingStore
    @State private var toastMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    checklistSection
                    Divider().padding(.vertical, 6)
                    actionsSection
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 620, height: 680)
        .overlay(alignment: .top) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.75))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.top, 56)
                    .transition(.opacity)
            }
        }
        .onAppear { store.startPolling() }
        .onDisappear { store.stopPolling() }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 28, weight: .regular))
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("欢迎使用 Vista")
                    .font(.system(size: 18, weight: .semibold))
                Text("按顺序完成下面的步骤，Vista 就能接管你的 Spaces 与窗口。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if store.isAllRequiredOK {
                Label("一切就绪", systemImage: "checkmark.seal.fill")
                    .labelStyle(.titleAndIcon)
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(20)
    }
    
    // MARK: - Checklist
    
    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("状态检查")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            statusRow(
                title: "macOS 版本",
                status: store.macOSVersion,
                detail: "yabai v7.1.16 需要 macOS 12 Monterey 及以上。"
            )
            statusRow(
                title: "SIP 部分关闭",
                status: store.sipStatus,
                detail: "yabai 注入 scripting addition 需要部分关闭 SIP。若显示「已启用」，请按下面「配置 SIP」操作。"
            )
            statusRow(
                title: "yabai 守护进程",
                status: store.daemonRunning,
                detail: "Vista 通过 Unix socket 跟 yabai 守护进程通信。"
            )
            statusRow(
                title: "scripting addition",
                status: store.scriptingAddition,
                detail: "跨 Space 切换、focus window 等核心功能依赖此组件；未加载时只能查询、无法操作。"
            )
            statusRow(
                title: "辅助功能权限",
                status: store.accessibility,
                detail: "Vista 与 yabai 都需要。注意：要给 yabai 二进制和 Vista.app 分别授权。"
            )
            statusRow(
                title: "屏幕录制权限（可选）",
                status: store.screenRecording,
                detail: "用于窗口缩略图预览，不影响基本功能。"
            )
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷操作")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            actionRow(
                title: "第 1 步：配置 SIP（仅首次安装）",
                description: "需要在恢复模式里部分关闭 SIP。点按钮在弹窗里展开完整步骤，全程 1-2 分钟。",
                buttonTitle: "查看 SIP 配置步骤",
                action: showSIPInstructions
            )
            
            actionRow(
                title: "第 2 步：配置 sudoers（让 yabai 免密加载 SA）",
                description: "这条命令只需要执行一次。点击后会把命令复制到剪贴板并自动打开 Terminal。",
                buttonTitle: "复制并打开 Terminal",
                action: installSudoers
            )
            
            actionRow(
                title: "第 3 步：加载 scripting addition",
                description: "每次重启或 Dock 重启后都需要重新执行（或配置 yabairc 自动执行）。",
                buttonTitle: "复制并打开 Terminal",
                action: loadSA
            )
            
            actionRow(
                title: "启动 / 停止 yabai 守护进程",
                description: "使用 Vista 内置的 yabai v7.1.16 二进制。",
                buttonTitle: store.daemonRunning.state == .ok ? "停止 yabai" : "启动 yabai",
                action: toggleDaemon
            )
            
            actionRow(
                title: "授予辅助功能权限",
                description: "点击跳转系统设置，把 Vista 与 yabai 的开关都打开。",
                buttonTitle: "打开系统设置",
                action: { YabaiRuntime.openSystemSettings(pane: .accessibility) }
            )
            
            actionRow(
                title: "授予屏幕录制权限（可选）",
                description: "启用窗口缩略图预览。",
                buttonTitle: "打开系统设置",
                action: { YabaiRuntime.openSystemSettings(pane: .screenRecording) }
            )
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Button("刷新状态") { store.refresh() }
            Spacer()
            Text("Vista · 内置 yabai v7.1.16 (arm64)")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Row builders
    
    @ViewBuilder
    private func statusRow(title: String, status: OnboardingStore.ItemStatus, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            statusIcon(for: status.state)
                .frame(width: 20, height: 20)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    if let msg = status.message {
                        Text("· " + msg)
                            .font(.system(size: 11))
                            .foregroundColor(colorFor(status.state))
                    }
                }
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
    
    @ViewBuilder
    private func statusIcon(for state: OnboardingStore.ItemStatus.State) -> some View {
        switch state {
        case .ok:
            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
        case .failing:
            Image(systemName: "xmark.circle.fill").foregroundColor(.red)
        case .unknown:
            ProgressView().controlSize(.small)
        }
    }
    
    private func colorFor(_ state: OnboardingStore.ItemStatus.State) -> Color {
        switch state {
        case .ok: return .green
        case .warning: return .orange
        case .failing: return .red
        case .unknown: return .secondary
        }
    }
    
    @ViewBuilder
    private func actionRow(title: String, description: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .controlSize(.small)
        }
    }
    
    // MARK: - Actions impl
    
    private func installSudoers() {
        let cmd = YabaiRuntime.sudoersInstallCommand()
        YabaiRuntime.copyToPasteboard(cmd)
        YabaiRuntime.runInTerminal(cmd)
        showToast("命令已复制并在 Terminal 中打开")
    }
    
    private func loadSA() {
        let cmd = YabaiRuntime.loadScriptingAdditionCommand()
        YabaiRuntime.copyToPasteboard(cmd)
        YabaiRuntime.runInTerminal(cmd)
        showToast("命令已复制并在 Terminal 中打开")
    }
    
    private func toggleDaemon() {
        DispatchQueue.global(qos: .userInitiated).async {
            let running = YabaiRuntime.isDaemonRunning
            let success: Bool
            if running {
                success = YabaiRuntime.stopDaemon()
            } else {
                success = YabaiRuntime.startDaemon()
            }
            DispatchQueue.main.async {
                showToast(success ? (running ? "已停止" : "已启动") : "操作失败，请查看日志")
                store.refresh()
            }
        }
    }
    
    private func showSIPInstructions() {
        let alert = NSAlert()
        alert.messageText = "配置 SIP（System Integrity Protection）"
        alert.informativeText = """
        yabai 需要部分关闭 SIP 才能注入 scripting addition。整个过程要关机进入恢复模式，
        那时候剪贴板不能用，请先把两条命令抄到手机 / 另一台设备上。
        
        要记下来的两条命令：
        
        命令 A（恢复模式终端里执行）：
          csrutil enable --without fs --without debug --without nvram
        
        命令 B（重启进入正常系统后，在普通终端里执行）：
          sudo nvram boot-args=-arm64e_preview_abi
        
        操作流程：
        1. 用手机 / 另一台设备抄下上面 A、B 两条。
        2. 关机。
        3. 按住电源键进入恢复模式（出现「正在载入启动选项」后点「选项」→「继续」）。
        4. 顶部菜单栏 实用工具 → 终端，手动输入命令 A 并回车。
        5. 从苹果菜单 → 重新启动，让系统正常启动。
        6. 登录后打开 Terminal.app，手动输入命令 B 并回车，输入管理员密码。
        7. 再重启一次，让 boot-args 生效。
        8. 回到系统后 csrutil status 会显示 "System Integrity Protection status: unknown."，这是正常的。
        
        提示：点「复制到剪贴板」把两条命令复制出来，方便现在先发到手机备份。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "复制到剪贴板")
        alert.addButton(withTitle: "知道了")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            YabaiRuntime.copyToPasteboard("""
            # 命令 A：在恢复模式终端里执行
            csrutil enable --without fs --without debug --without nvram
            
            # 命令 B：重启进入正常系统后，在普通终端里执行
            sudo nvram boot-args=-arm64e_preview_abi
            """)
            showToast("两条命令已复制到剪贴板")
        }
    }
    
    // MARK: - Toast
    
    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if toastMessage == message {
                withAnimation { toastMessage = nil }
            }
        }
    }
}
