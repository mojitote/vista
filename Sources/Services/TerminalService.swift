import Foundation
import AppKit

/// 通过 AppleScript 控制 Terminal.app / iTerm2
class TerminalService {
    static let shared = TerminalService()
    
    enum TerminalApp: String {
        case terminal = "Terminal"
        case iterm = "iTerm"
    }
    
    // MARK: - 在 Terminal 中执行命令
    
    /// 在 Terminal.app 中执行命令（新建 tab 或复用当前窗口）
    @discardableResult
    func runInTerminal(_ command: String, newTab: Bool = false) -> Bool {
        let script: String
        if newTab {
            script = """
            tell application "Terminal"
                activate
                do script "\(command.escapedForAppleScript)"
            end tell
            """
        } else {
            // 在最前面的窗口执行（如果没有窗口则新建）
            script = """
            tell application "Terminal"
                activate
                if (count of windows) > 0 then
                    do script "\(command.escapedForAppleScript)" in front window
                else
                    do script "\(command.escapedForAppleScript)"
                end if
            end tell
            """
        }
        return executeAppleScript(script)
    }
    
    /// 在 iTerm2 中执行命令
    @discardableResult
    func runInITerm(_ command: String, newTab: Bool = false) -> Bool {
        let script: String
        if newTab {
            script = """
            tell application "iTerm"
                activate
                tell current window
                    create tab with default profile
                    tell current session
                        write text "\(command.escapedForAppleScript)"
                    end tell
                end tell
            end tell
            """
        } else {
            script = """
            tell application "iTerm"
                activate
                tell current window
                    tell current session
                        write text "\(command.escapedForAppleScript)"
                    end tell
                end tell
            end tell
            """
        }
        return executeAppleScript(script)
    }
    
    // MARK: - 激活应用
    
    /// 通过 AppleScript 激活指定应用
    @discardableResult
    func activateApp(_ appName: String) -> Bool {
        let script = """
        tell application "\(appName.escapedForAppleScript)"
            activate
        end tell
        """
        return executeAppleScript(script)
    }
    
    // MARK: - 在浏览器中打开 URL
    
    @discardableResult
    func openURL(_ url: String, inApp: String = "Safari") -> Bool {
        let script = """
        tell application "\(inApp.escapedForAppleScript)"
            activate
            open location "\(url.escapedForAppleScript)"
        end tell
        """
        return executeAppleScript(script)
    }
    
    // MARK: - Private
    
    private func executeAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            print("[TerminalService] AppleScript error: \(error)")
            return false
        }
        return true
    }
}

// MARK: - String Extension

private extension String {
    /// 转义 AppleScript 字符串中的特殊字符
    var escapedForAppleScript: String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
