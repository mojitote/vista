import Foundation
import ServiceManagement

/// 用 SMAppService 管理 "开机启动" 注册状态，仅在 macOS 13+ 可用。
enum LaunchAtLoginService {
    
    /// 用户意图的启动状态与系统实际状态不一致时，同步系统状态。
    /// 启动时调用一次：避免用户设置里勾选了但被系统撤销（比如移动过 app 路径）后无感知。
    static func syncIfNeeded(enabled: Bool) {
        let current = isRegistered
        if enabled && !current {
            register()
        } else if !enabled && current {
            unregister()
        }
    }
    
    static func setEnabled(_ enabled: Bool) {
        if enabled {
            register()
        } else {
            unregister()
        }
    }
    
    static var isRegistered: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    private static func register() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            NSLog("[Vista] Failed to register launch-at-login: \(error.localizedDescription)")
        }
    }
    
    private static func unregister() {
        do {
            try SMAppService.mainApp.unregister()
        } catch {
            NSLog("[Vista] Failed to unregister launch-at-login: \(error.localizedDescription)")
        }
    }
}
