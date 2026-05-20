import Foundation

/// 简单的语音指令意图解析器（MVP demo，后续替换为 LLM）
class SimpleIntentParser {
    
    enum Intent {
        case focusApp(name: String)
        case focusSpace(index: Int)
        case runCommand(command: String)
        case moveWindow(direction: String)       // "left", "right"
        case closeWindow
        case fullscreen
        case openURL(url: String)
        case unknown(raw: String)
    }
    
    /// App 名称别名映射（中文/简写 → 实际 app 名）
    private static let appAliases: [String: String] = [
        // 终端
        "终端": "Terminal",
        "terminal": "Terminal",
        "iterm": "iTerm",
        // 编辑器
        "编辑器": "Visual Studio Code",
        "vscode": "Visual Studio Code",
        "vs code": "Visual Studio Code",
        "code": "Visual Studio Code",
        "xcode": "Xcode",
        // 浏览器
        "浏览器": "Safari",
        "safari": "Safari",
        "chrome": "Google Chrome",
        "谷歌": "Google Chrome",
        "firefox": "Firefox",
        // 通讯
        "飞书": "Feishu",
        "lark": "Feishu",
        "微信": "WeChat",
        "wechat": "WeChat",
        "slack": "Slack",
        // 其他
        "finder": "Finder",
        "访达": "Finder",
        "音乐": "Music",
        "笔记": "Notes",
        "备忘录": "Notes",
    ]
    
    /// 解析文本指令为 Intent
    func parse(_ text: String) -> Intent {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespaces)
        
        // 1. 切换桌面/Space
        if let spaceIndex = parseSpaceFocus(normalized) {
            return .focusSpace(index: spaceIndex)
        }
        
        // 2. 执行终端命令
        if let command = parseRunCommand(normalized) {
            return .runCommand(command: command)
        }
        
        // 3. 关闭窗口
        if isCloseWindow(normalized) {
            return .closeWindow
        }
        
        // 4. 全屏
        if isFullscreen(normalized) {
            return .fullscreen
        }
        
        // 5. 移动窗口
        if let direction = parseMoveWindow(normalized) {
            return .moveWindow(direction: direction)
        }
        
        // 6. 打开 URL
        if let url = parseURL(normalized) {
            return .openURL(url: url)
        }
        
        // 7. 切换到应用（最后兜底，因为匹配范围最广）
        if let appName = parseAppFocus(normalized) {
            return .focusApp(name: appName)
        }
        
        return .unknown(raw: text)
    }
    
    // MARK: - Private Parsers
    
    private func parseSpaceFocus(_ text: String) -> Int? {
        // "切到桌面3" / "去第三个桌面" / "space 2"
        let patterns = [
            "桌面(\\d+)", "第(\\d+)个桌面", "space\\s*(\\d+)",
            "第([一二三四五六七八九十]+)个桌面"
        ]
        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let matched = String(text[match])
                if let num = matched.extractNumber() {
                    return num
                }
            }
        }
        return nil
    }
    
    private func parseRunCommand(_ text: String) -> String? {
        // "运行 npm start" / "执行 git status" / "在终端跑 ls"
        let patterns = [
            "(?:运行|执行|跑|run)\\s+(.+)",
            "(?:在终端|terminal)\\s*(?:运行|执行|跑|run)?\\s*(.+)",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                return String(text[range])
            }
        }
        return nil
    }
    
    private func isCloseWindow(_ text: String) -> Bool {
        let keywords = ["关掉", "关闭", "close", "关了"]
        return keywords.contains(where: { text.contains($0) }) &&
               (text.contains("窗口") || text.contains("window") || text.contains("这个"))
    }
    
    private func isFullscreen(_ text: String) -> Bool {
        let keywords = ["全屏", "fullscreen", "退出全屏", "exit fullscreen"]
        return keywords.contains(where: { text.contains($0) })
    }
    
    private func parseMoveWindow(_ text: String) -> String? {
        if text.contains("左") || text.contains("left") { return "left" }
        if text.contains("右") || text.contains("right") { return "right" }
        return nil
    }
    
    private func parseURL(_ text: String) -> String? {
        // "打开 localhost:3000" / "open https://..."
        let patterns = [
            "(?:打开|open)\\s+(https?://\\S+)",
            "(?:打开|open)\\s+(localhost\\S*)",
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                var url = String(text[range])
                if !url.hasPrefix("http") { url = "http://\(url)" }
                return url
            }
        }
        return nil
    }
    
    private func parseAppFocus(_ text: String) -> String? {
        // "切到终端" / "去 vscode" / "打开 chrome"
        let prefixes = ["切到", "切换到", "去", "打开", "switch to", "go to", "open"]
        
        var target = text
        for prefix in prefixes {
            if target.hasPrefix(prefix) {
                target = String(target.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        // 在别名表中查找
        let lowered = target.lowercased()
        if let appName = Self.appAliases[lowered] {
            return appName
        }
        
        // 模糊匹配：检查别名表中是否有 key 被包含在 target 中
        for (alias, appName) in Self.appAliases {
            if lowered.contains(alias) {
                return appName
            }
        }
        
        // 如果 target 不为空，当作 app 名原样返回
        if !target.isEmpty {
            return target
        }
        
        return nil
    }
}

// MARK: - String Helper

private extension String {
    /// 从字符串中提取数字
    func extractNumber() -> Int? {
        // 阿拉伯数字
        if let match = self.range(of: "\\d+", options: .regularExpression) {
            return Int(self[match])
        }
        // 中文数字
        let chineseMap: [Character: Int] = [
            "一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
            "六": 6, "七": 7, "八": 8, "九": 9, "十": 10
        ]
        for char in self {
            if let num = chineseMap[char] { return num }
        }
        return nil
    }
}
