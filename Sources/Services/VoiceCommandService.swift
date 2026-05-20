import Foundation

/// VoiceCommandService — 语音指令执行引擎 (MVP Demo)
/// 将文本指令解析为意图，然后通过 yabai + AppleScript 执行
class VoiceCommandService {
    static let shared = VoiceCommandService()
    
    private let yabai = YabaiService.shared
    private let terminal = TerminalService.shared
    private let parser = SimpleIntentParser()
    
    /// 执行结果
    struct CommandResult {
        let success: Bool
        let message: String   // TTS 要播报的内容
    }
    
    // MARK: - 主入口
    
    /// 处理一条文本指令（语音转文字后调用此方法）
    func execute(_ text: String) -> CommandResult {
        let intent = parser.parse(text)
        
        switch intent {
        case .focusApp(let name):
            return handleFocusApp(name)
        case .focusSpace(let index):
            return handleFocusSpace(index)
        case .runCommand(let command):
            return handleRunCommand(command)
        case .moveWindow(let direction):
            return handleMoveWindow(direction)
        case .closeWindow:
            return handleCloseWindow()
        case .fullscreen:
            return handleFullscreen()
        case .openURL(let url):
            return handleOpenURL(url)
        case .unknown(let raw):
            return CommandResult(success: false, message: "没理解：\(raw)")
        }
    }
    
    // MARK: - 意图处理器
    
    private func handleFocusApp(_ appName: String) -> CommandResult {
        // 策略：先通过 yabai 查找窗口并 focus（精确切换 Space + 窗口）
        //       如果找不到，用 AppleScript activate 启动/激活该 app
        do {
            let windows = try yabai.queryWindows()
            
            // 模糊匹配 app 名称
            let matched = windows.filter { window in
                window.app.localizedCaseInsensitiveContains(appName) ||
                appName.localizedCaseInsensitiveContains(window.app)
            }
            
            if let target = bestWindow(from: matched) {
                // 先切到目标窗口所在的 Space
                try yabai.focusSpace(index: target.space)
                // 再 focus 窗口
                try yabai.focusWindow(id: target.id)
                return CommandResult(success: true, message: "切到\(target.app)了")
            } else {
                // yabai 找不到，尝试用 AppleScript 启动
                let activated = terminal.activateApp(appName)
                if activated {
                    return CommandResult(success: true, message: "打开\(appName)了")
                } else {
                    return CommandResult(success: false, message: "找不到\(appName)")
                }
            }
        } catch {
            // yabai 不可用时 fallback 到 AppleScript
            let activated = terminal.activateApp(appName)
            return CommandResult(
                success: activated,
                message: activated ? "切到\(appName)了" : "操作失败"
            )
        }
    }
    
    private func handleFocusSpace(_ index: Int) -> CommandResult {
        do {
            try yabai.focusSpace(index: index)
            return CommandResult(success: true, message: "切到桌面\(index)了")
        } catch {
            return CommandResult(success: false, message: "切桌面失败")
        }
    }
    
    private func handleRunCommand(_ command: String) -> CommandResult {
        // 先切到终端，再执行命令
        _ = handleFocusApp("Terminal")
        
        // 稍等一下让窗口切换完成
        Thread.sleep(forTimeInterval: 0.3)
        
        let success = terminal.runInTerminal(command)
        return CommandResult(
            success: success,
            message: success ? "执行了\(command)" : "执行失败"
        )
    }
    
    private func handleMoveWindow(_ direction: String) -> CommandResult {
        do {
            let windows = try yabai.queryWindows()
            let displays = try yabai.queryDisplays()
            
            guard let focused = windows.first(where: { $0.hasFocus }) else {
                return CommandResult(success: false, message: "没有聚焦的窗口")
            }
            
            guard displays.count > 1 else {
                return CommandResult(success: false, message: "只有一个显示器")
            }
            
            // 简单逻辑：左=display 1，右=display 2
            let targetDisplay = direction == "left" ? 1 : 2
            try yabai.moveWindowToDisplay(windowID: focused.id, displayIndex: targetDisplay)
            return CommandResult(success: true, message: "移到\(direction == "left" ? "左" : "右")屏了")
        } catch {
            return CommandResult(success: false, message: "移动失败")
        }
    }
    
    private func handleCloseWindow() -> CommandResult {
        do {
            let windows = try yabai.queryWindows()
            guard let focused = windows.first(where: { $0.hasFocus }) else {
                return CommandResult(success: false, message: "没有聚焦的窗口")
            }
            try yabai.closeWindow(id: focused.id)
            return CommandResult(success: true, message: "关掉了")
        } catch {
            return CommandResult(success: false, message: "关闭失败")
        }
    }
    
    private func handleFullscreen() -> CommandResult {
        do {
            let windows = try yabai.queryWindows()
            guard let focused = windows.first(where: { $0.hasFocus }) else {
                return CommandResult(success: false, message: "没有聚焦的窗口")
            }
            try yabai.toggleNativeFullscreen(windowID: focused.id)
            return CommandResult(success: true, message: "切换全屏了")
        } catch {
            return CommandResult(success: false, message: "全屏切换失败")
        }
    }
    
    private func handleOpenURL(_ url: String) -> CommandResult {
        let success = terminal.openURL(url)
        return CommandResult(
            success: success,
            message: success ? "打开了" : "打开失败"
        )
    }
    
    // MARK: - Helpers
    
    /// 从匹配的窗口中选择最佳目标：优先可见 > 非最小化 > 任意
    private func bestWindow(from windows: [YabaiWindow]) -> YabaiWindow? {
        // 优先选已聚焦的（不太可能，但排除）
        // 然后选可见的
        if let visible = windows.first(where: { $0.isVisible && !$0.isMinimized && !$0.isHidden }) {
            return visible
        }
        // 然后选非最小化的
        if let nonMin = windows.first(where: { !$0.isMinimized && !$0.isHidden }) {
            return nonMin
        }
        // 兜底
        return windows.first
    }
}
