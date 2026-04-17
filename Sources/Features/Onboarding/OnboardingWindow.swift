import AppKit
import SwiftUI

/// 管理向导窗口的展示。单例使用。
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    
    static let shared = OnboardingWindowController()
    
    private var window: NSWindow?
    private let store = OnboardingStore()
    
    /// 第一次展示向导的 UserDefaults key。
    private let hasShownKey = "com.vista.onboarding.hasShown"
    
    /// 用户第一次启动时自动弹出；之后需要手动从菜单栏进入。
    func showIfFirstLaunch() {
        let shown = UserDefaults.standard.bool(forKey: hasShownKey)
        if !shown {
            show()
            UserDefaults.standard.set(true, forKey: hasShownKey)
        } else if !store.runAllChecksOnce().isAllRequiredOK {
            // 即便不是首次启动，只要硬性检查没全通过也弹出，避免用户莫名其妙
            show()
        }
    }
    
    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(rootView: OnboardingView(store: store))
        let w = NSWindow(contentViewController: hosting)
        w.title = "Vista · 设置向导"
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.isReleasedWhenClosed = false
        w.center()
        w.delegate = self
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = w
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }
}

private extension OnboardingStore {
    /// 同步跑一次检查并返回自身（便于在 first-launch 决策里读值）。
    func runAllChecksOnce() -> OnboardingStore {
        refresh()
        return self
    }
}
