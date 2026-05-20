import Foundation
import AppKit

/// vista-cmd — Vista 桌面操控 CLI 工具
/// 用法:
///   vista-cmd focus <app>          切换到指定应用
///   vista-cmd space <index>        切换到指定桌面
///   vista-cmd run <command>        在终端执行命令
///   vista-cmd close                关闭当前窗口
///   vista-cmd move <left|right>    移动窗口到左/右屏
///   vista-cmd fullscreen           切换全屏
///   vista-cmd open <url>           打开 URL
///   vista-cmd list-windows         列出所有窗口 (JSON)
///   vista-cmd list-spaces          列出所有桌面 (JSON)
///   vista-cmd exec <自然语言>       自然语言执行（走 SimpleIntentParser）

enum VistaCMD {
    static func run() {
        let args = Array(CommandLine.arguments.dropFirst())
        
        guard !args.isEmpty else {
            printUsage()
            exit(1)
        }
        
        let command = args[0].lowercased()
        let params = Array(args.dropFirst())
        
        let result: VoiceCommandService.CommandResult
        
        switch command {
        case "focus":
            guard let app = params.first else {
                printError("用法: vista-cmd focus <app_name>")
                exit(1)
            }
            let appName = params.joined(separator: " ")
            result = VoiceCommandService.shared.execute("切到\(appName)")
            
        case "space":
            guard let indexStr = params.first, let index = Int(indexStr) else {
                printError("用法: vista-cmd space <index>")
                exit(1)
            }
            result = VoiceCommandService.shared.execute("切到桌面\(index)")
            
        case "run":
            guard !params.isEmpty else {
                printError("用法: vista-cmd run <command>")
                exit(1)
            }
            let cmd = params.joined(separator: " ")
            result = VoiceCommandService.shared.execute("运行 \(cmd)")
            
        case "close":
            result = VoiceCommandService.shared.execute("关掉这个窗口")
            
        case "move":
            guard let direction = params.first, ["left", "right"].contains(direction) else {
                printError("用法: vista-cmd move <left|right>")
                exit(1)
            }
            result = VoiceCommandService.shared.execute("移到\(direction == "left" ? "左" : "右")屏")
            
        case "fullscreen":
            result = VoiceCommandService.shared.execute("全屏")
            
        case "open":
            guard let url = params.first else {
                printError("用法: vista-cmd open <url>")
                exit(1)
            }
            result = VoiceCommandService.shared.execute("打开 \(url)")
            
        case "list-windows":
            listWindows()
            exit(0)
            
        case "list-spaces":
            listSpaces()
            exit(0)
            
        case "exec":
            // 自然语言模式：直接传给 VoiceCommandService
            guard !params.isEmpty else {
                printError("用法: vista-cmd exec <自然语言指令>")
                exit(1)
            }
            let text = params.joined(separator: " ")
            result = VoiceCommandService.shared.execute(text)
            
        case "help", "--help", "-h":
            printUsage()
            exit(0)
            
        default:
            // 兜底：当作自然语言指令
            let text = args.joined(separator: " ")
            result = VoiceCommandService.shared.execute(text)
        }
        
        // 输出结果 JSON
        let output: [String: Any] = [
            "success": result.success,
            "message": result.message
        ]
        if let json = try? JSONSerialization.data(withJSONObject: output),
           let str = String(data: json, encoding: .utf8) {
            print(str)
        }
        
        exit(result.success ? 0 : 1)
    }
    
    // MARK: - List Commands
    
    static func listWindows() {
        do {
            let windows = try YabaiService.shared.queryWindows()
            let simplified = windows.map { w in
                [
                    "id": w.id,
                    "app": w.app,
                    "title": w.title,
                    "space": w.space,
                    "display": w.display,
                    "focused": w.hasFocus,
                    "visible": w.isVisible,
                    "minimized": w.isMinimized
                ] as [String: Any]
            }
            if let json = try? JSONSerialization.data(withJSONObject: simplified, options: .prettyPrinted),
               let str = String(data: json, encoding: .utf8) {
                print(str)
            }
        } catch {
            printError("Failed to query windows: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    static func listSpaces() {
        do {
            let spaces = try YabaiService.shared.querySpaces()
            let simplified = spaces.map { s in
                [
                    "index": s.index,
                    "display": s.display,
                    "windows": s.windows,
                    "focused": s.hasFocus,
                    "visible": s.isVisible,
                    "fullscreen": s.isNativeFullscreen
                ] as [String: Any]
            }
            if let json = try? JSONSerialization.data(withJSONObject: simplified, options: .prettyPrinted),
               let str = String(data: json, encoding: .utf8) {
                print(str)
            }
        } catch {
            printError("Failed to query spaces: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    // MARK: - Helpers
    
    static func printUsage() {
        let usage = """
        vista-cmd — Vista 桌面操控 CLI
        
        用法:
          vista-cmd focus <app>          切换到指定应用
          vista-cmd space <index>        切换到指定桌面
          vista-cmd run <command>        在终端执行命令
          vista-cmd close                关闭当前窗口
          vista-cmd move <left|right>    移动窗口到左/右屏
          vista-cmd fullscreen           切换全屏
          vista-cmd open <url>           打开 URL
          vista-cmd list-windows         列出所有窗口 (JSON)
          vista-cmd list-spaces          列出所有桌面 (JSON)
          vista-cmd exec <自然语言>       自然语言执行
        
        示例:
          vista-cmd focus Terminal
          vista-cmd space 3
          vista-cmd run "npm start"
          vista-cmd exec "把 Chrome 移到左屏"
          vista-cmd list-windows
        """
        print(usage)
    }
    
    static func printError(_ message: String) {
        fputs("error: \(message)\n", stderr)
    }
}

// Entry point
VistaCMD.run()
