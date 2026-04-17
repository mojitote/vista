import Foundation
import AppKit
import ApplicationServices

/// 检查/管理 vista 依赖的外部环境（yabai 二进制、守护进程、SIP、scripting addition、AX 权限）。
///
/// 设计：
/// - bundled yabai 位于 `Vista.app/Contents/Resources/yabai/bin/yabai`，只读，不会被用户删除。
/// - 通过 socket `/tmp/yabai_$USER.socket` 判断守护进程是否在运行，不依赖 `yabai --version`。
/// - 需要 sudo 的动作（load-sa、sudoers 安装）通过「复制命令到剪贴板 + 打开 Terminal」完成，
///   不在 app 里 pipe sudo 密码（Apple 沙箱/安全审计会拒绝）。
enum YabaiRuntime {
    
    // MARK: - Binary Path
    
    /// 打包在 app 内的 yabai 二进制绝对路径。
    static var bundledYabaiPath: String {
        if let res = Bundle.main.resourcePath {
            return (res as NSString).appendingPathComponent("yabai/bin/yabai")
        }
        return "/opt/homebrew/bin/yabai"
    }
    
    /// yabai daemon 监听的 Unix socket 路径（与 YabaiService 保持一致）。
    static var socketPath: String {
        let user = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
        return "/tmp/yabai_\(user).socket"
    }
    
    /// bundled yabai 二进制的 SHA-256（sudoers 里 `sha256:` 要用）。
    static func bundledYabaiSHA256() -> String? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: bundledYabaiPath)) else {
            return nil
        }
        return data.sha256()
    }
    
    // MARK: - Checks
    
    enum CheckState {
        case ok
        case warning(String)
        case failing(String)
        
        var isOK: Bool { if case .ok = self { return true } else { return false } }
    }
    
    /// yabai daemon 是否在跑（socket 文件存在即视为在跑；和 YabaiService.isYabaiRunning 一致）。
    static var isDaemonRunning: Bool {
        FileManager.default.fileExists(atPath: socketPath)
    }
    
    /// scripting addition 是否加载成功。
    /// 启发式：查询 spaces，如果其中有 native-fullscreen 标记字段被解析并得到合理结果，就视为 SA OK。
    /// 更保守的做法：直接看 /tmp/yabai-sa_$USER.socket 是否存在。
    static var isScriptingAdditionLoaded: Bool {
        let user = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
        let saSocket = "/tmp/yabai-sa_\(user).socket"
        return FileManager.default.fileExists(atPath: saSocket)
    }
    
    /// macOS Accessibility 权限。
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
    
    /// 屏幕录制权限（截图缩略图需要）。
    static var hasScreenRecordingPermission: Bool {
        CGPreflightScreenCaptureAccess()
    }
    
    /// macOS 版本是否被支持（yabai v7.1.16 要求 macOS 12+）。
    static var isMacOSVersionSupported: Bool {
        if #available(macOS 12.0, *) { return true }
        return false
    }
    
    /// SIP 状态：解析 `csrutil status`。
    /// 可能的返回：`.ok`（partially disabled）、`.warning(当前字符串)`、`.failing("enabled")`。
    static var sipState: CheckState {
        let output = runSync(path: "/usr/bin/csrutil", args: ["status"]).stdout.lowercased()
        if output.isEmpty {
            return .warning("无法获取 SIP 状态（csrutil 未执行成功）")
        }
        if output.contains("disabled") {
            return .ok
        }
        if output.contains("unknown") || output.contains("custom") || output.contains("partial") {
            return .ok
        }
        if output.contains("enabled") {
            return .failing("SIP 完全启用，yabai scripting addition 无法注入")
        }
        return .warning("SIP 状态未知：\(output.trimmingCharacters(in: .whitespacesAndNewlines))")
    }
    
    // MARK: - Actions
    
    /// 启动 bundled yabai daemon。
    /// 行为：fork 一个子进程运行 yabai，不继承父进程的 stdout/stderr，
    /// 守护进程跟 vista 解耦（vista 退出 yabai 仍在跑）。
    @discardableResult
    static func startDaemon() -> Bool {
        if isDaemonRunning { return true }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bundledYabaiPath)
        task.arguments = []
        task.environment = cleanEnvironment()
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice
        
        do {
            try task.run()
        } catch {
            NSLog("[Vista] startDaemon failed: \(error.localizedDescription)")
            return false
        }
        
        // 等 socket 出现（最多 3s）
        for _ in 0..<30 {
            if isDaemonRunning { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return isDaemonRunning
    }
    
    /// 停止所有 yabai 守护进程。
    @discardableResult
    static func stopDaemon() -> Bool {
        _ = runSync(path: "/usr/bin/killall", args: ["yabai"])
        for _ in 0..<20 {
            if !isDaemonRunning { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return !isDaemonRunning
    }
    
    /// 在 Terminal.app 里打开一个新窗口，粘贴好命令，让用户自己按回车输入 sudo 密码。
    /// - Parameter command: 要执行的 shell 命令（单行）。
    static func runInTerminal(_ command: String) {
        let escaped = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
            do script "\(escaped)"
        end tell
        """
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(nil)
    }
    
    /// 把文本复制到系统剪贴板。
    static func copyToPasteboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
    
    /// 打开系统设置的对应面板。
    static func openSystemSettings(pane: SystemSettingsPane) {
        if let url = URL(string: pane.url) {
            NSWorkspace.shared.open(url)
        }
    }
    
    enum SystemSettingsPane {
        case accessibility
        case screenRecording
        case missionControl
        
        var url: String {
            switch self {
            case .accessibility:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            case .screenRecording:
                return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
            case .missionControl:
                return "x-apple.systempreferences:com.apple.MissionControl-Settings.extension"
            }
        }
    }
    
    // MARK: - Command Snippets (for copy-to-pasteboard)
    
    /// sudoers 安装命令（让用户在 Terminal 粘贴执行）。
    static func sudoersInstallCommand() -> String {
        let path = bundledYabaiPath
        let escapedPath = path.replacingOccurrences(of: " ", with: "\\ ")
        return """
        echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 \(escapedPath) | cut -d ' ' -f 1) \(escapedPath) --load-sa" | sudo tee /private/etc/sudoers.d/vista-yabai
        """
    }
    
    /// 一次性加载 scripting addition。
    static func loadScriptingAdditionCommand() -> String {
        "sudo \(bundledYabaiPath) --load-sa"
    }
    
    // MARK: - Internals
    
    private static func cleanEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        // 避免 Xcode 环境变量泄漏影响 yabai；保留必要的 USER/HOME/PATH
        let keep: Set<String> = ["USER", "HOME", "LOGNAME", "PATH", "SHELL", "LANG", "LC_ALL", "TERM"]
        env = env.filter { keep.contains($0.key) }
        if env["PATH"] == nil {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        }
        return env
    }
    
    private struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }
    
    private static func runSync(path: String, args: [String], timeout: TimeInterval = 2.0) -> ProcessResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.environment = cleanEnvironment()
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe
        
        do {
            try task.run()
        } catch {
            return ProcessResult(stdout: "", stderr: error.localizedDescription, exitCode: -1)
        }
        
        let deadline = Date().addingTimeInterval(timeout)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning {
            task.terminate()
        }
        
        let outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
        let errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
        return ProcessResult(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: task.terminationStatus
        )
    }
}

// MARK: - SHA-256 helper

import CryptoKit

private extension Data {
    func sha256() -> String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
