import Foundation
import Combine
import AppKit

/// 向导各项检查的状态机。轮询刷新（每 1.5s），也提供手动 `refresh()`。
final class OnboardingStore: ObservableObject {
    
    struct ItemStatus: Equatable {
        var state: State
        var message: String?
        
        enum State: Equatable { case ok, warning, failing, unknown }
    }
    
    @Published var macOSVersion: ItemStatus = .init(state: .unknown)
    @Published var sipStatus: ItemStatus = .init(state: .unknown)
    @Published var daemonRunning: ItemStatus = .init(state: .unknown)
    @Published var scriptingAddition: ItemStatus = .init(state: .unknown)
    @Published var accessibility: ItemStatus = .init(state: .unknown)
    @Published var screenRecording: ItemStatus = .init(state: .unknown)
    
    /// 本次 Vista 进程启动时拍下的权限快照。用来判定「用户是不是刚授完权，还没重启」。
    /// 一旦当前值与 baseline 不同且变好了 → 提示用户重启 Vista / yabai。
    private let baselineAccessibility: Bool
    private let baselineScreenRecording: Bool
    
    /// 用户在 App 运行期间授予了新权限（或撤销过），建议重启以完全生效。
    @Published var needsRelaunch: Bool = false
    
    init() {
        self.baselineAccessibility = YabaiRuntime.hasAccessibilityPermission
        self.baselineScreenRecording = YabaiRuntime.hasScreenRecordingPermission
    }
    
    /// 是否所有「硬性」条件都 ok（不含 screen recording，它是可选功能）。
    var isAllRequiredOK: Bool {
        [macOSVersion, sipStatus, daemonRunning, scriptingAddition, accessibility]
            .allSatisfy { $0.state == .ok }
    }
    
    private var timer: Timer?
    
    func startPolling() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }
    
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 同步跑一次所有检查。UI 调用方应该在 main queue。
    func refresh() {
        macOSVersion = YabaiRuntime.isMacOSVersionSupported
            ? .init(state: .ok)
            : .init(state: .failing, message: "需要 macOS 12 (Monterey) 及以上")
        
        switch YabaiRuntime.sipState {
        case .ok:
            sipStatus = .init(state: .ok)
        case .warning(let msg):
            sipStatus = .init(state: .warning, message: msg)
        case .failing(let msg):
            sipStatus = .init(state: .failing, message: msg)
        }
        
        daemonRunning = YabaiRuntime.isDaemonRunning
            ? .init(state: .ok)
            : .init(state: .failing, message: "yabai 未运行")
        
        scriptingAddition = YabaiRuntime.isScriptingAdditionLoaded
            ? .init(state: .ok)
            : .init(state: .warning, message: "未加载：跨 Space 操作将受限")
        
        let ax = YabaiRuntime.hasAccessibilityPermission
        accessibility = ax
            ? .init(state: .ok)
            : .init(state: .failing, message: "未授予")
        
        let sr = YabaiRuntime.hasScreenRecordingPermission
        screenRecording = sr
            ? .init(state: .ok)
            : .init(state: .warning, message: "未授予：窗口缩略图不可用")
        
        // 权限相比启动时发生了任何变化（包括授予和撤销）都触发重启提示。
        // 特别是授予：很多 AppKit / CG API 对权限的读取有进程级缓存，重启最稳。
        if ax != baselineAccessibility || sr != baselineScreenRecording {
            needsRelaunch = true
        }
    }
    
    /// 重启 Vista 自身。
    /// 通过 `open -n` 启动一个新实例，然后退出当前进程。
    static func relaunchApp() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]
        try? task.run()
        // 给新实例一点启动时间
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApp.terminate(nil)
        }
    }
    
    deinit {
        stopPolling()
    }
}
