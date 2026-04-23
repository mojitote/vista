import Foundation
import AppKit
import Carbon.HIToolbox

/// 把 sticky app 点击转为具体动作。两个语义清晰的入口：
/// - `focusAnyWindow`：左键。找这个 app 的任意窗口聚焦；优先源 display；都没有就直接 launch。
/// - `openNewWindow`：右键「新建」。在目标 display 上**强制**开一个新窗口。
enum AppLauncher {
    
    // MARK: - Public Entry Points
    
    /// 左键行为：找这个 app 的任意窗口聚焦。
    /// - 优先级：sourceDisplay 上的 visible 窗口 > 任意 display 上的 visible 窗口 > minimized > 任意 hasAXReference
    /// - 一个都没有 → `NSWorkspace.openApplication` 拉起来（不 force-new、不搬动 display）。
    static func focusAnyWindow(
        stickyApp: StickyApp,
        sourceDisplayIndex: Int?,
        viewModel: SidebarViewModel
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            runFocus(stickyApp: stickyApp, sourceDisplayIndex: sourceDisplayIndex, viewModel: viewModel)
        }
    }
    
    /// 右键「新建窗口」行为：在 targetDisplay 强制开一个新窗口（即使该 app 已经在别处有窗口）。
    static func openNewWindow(
        stickyApp: StickyApp,
        targetDisplayIndex: Int,
        viewModel: SidebarViewModel
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            runNewWindow(stickyApp: stickyApp, targetDisplayIndex: targetDisplayIndex, viewModel: viewModel)
        }
    }
    
    // MARK: - Focus Flow (left click)
    
    private static func runFocus(
        stickyApp: StickyApp,
        sourceDisplayIndex: Int?,
        viewModel: SidebarViewModel
    ) {
        let bundleID = stickyApp.bundleID
        let pids = runningPIDs(for: bundleID)
        let yabai = YabaiService.shared
        
        if !pids.isEmpty,
           let target = pickFocusTarget(pids: pids, preferDisplay: sourceDisplayIndex, yabai: yabai) {
            focusExistingWindow(target, yabai: yabai, viewModel: viewModel)
            return
        }
        
        // app 完全没运行（或 yabai 看不到任何窗口）→ 直接拉起，不再做后续 force-new / 搬 display。
        // 让自然产生的初始窗口落在 macOS 默认的位置即可。
        if launchApp(bundleID: bundleID) == nil {
            DispatchQueue.main.async {
                viewModel.showToast("未找到应用：\(stickyApp.displayName)")
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            viewModel.loadData()
        }
    }
    
    /// 找一个最适合 focus 的窗口。
    /// 偏好：preferDisplay 上的 visible > 其它 display 的 visible > minimized > 任意有 AX 引用。
    private static func pickFocusTarget(
        pids: [Int],
        preferDisplay: Int?,
        yabai: YabaiService
    ) -> YabaiWindow? {
        guard let windows = try? yabai.queryWindows() else { return nil }
        let owned = windows.filter { pids.contains($0.pid) && $0.hasAXReference }
        guard !owned.isEmpty else { return nil }
        
        if let prefer = preferDisplay,
           let w = owned.first(where: { $0.display == prefer && $0.isVisible && !$0.isMinimized }) {
            return w
        }
        if let w = owned.first(where: { $0.isVisible && !$0.isMinimized }) { return w }
        if let w = owned.first(where: { $0.isMinimized }) { return w }
        return owned.first
    }
    
    // MARK: - New Window Flow (right click)
    
    private static func runNewWindow(
        stickyApp: StickyApp,
        targetDisplayIndex: Int,
        viewModel: SidebarViewModel
    ) {
        let bundleID = stickyApp.bundleID
        let pids = runningPIDs(for: bundleID)
        let yabai = YabaiService.shared
        
        // ---- 1. 把焦点切到目标 display，新窗口才会落到那
        let targetSpaceIndex = focusTargetDisplaySpace(displayIndex: targetDisplayIndex, yabai: yabai)
        
        // ---- 2. 拍快照然后 launch / activate
        let beforeWindowIDs = currentWindowIDs(for: pids, yabai: yabai)
        let app = launchApp(bundleID: bundleID)
        if app == nil && pids.isEmpty {
            DispatchQueue.main.async {
                viewModel.showToast("未找到应用：\(stickyApp.displayName)")
            }
            return
        }
        
        // ---- 3. 等新窗口出现
        var newWindow = waitForNewWindow(
            originalIDs: beforeWindowIDs,
            bundleID: bundleID,
            pids: pids.isEmpty ? runningPIDs(for: bundleID) : pids,
            timeout: 1.5,
            yabai: yabai
        )
        
        // ---- 4. 没新窗口 → 模拟自定义新窗口快捷键（默认 ⌘N）
        //    右键「新建」是显式语义，无视 forceNewWindow toggle，永远尝试。
        if newWindow == nil {
            sendNewWindowKeystroke(
                keyCode: stickyApp.newWindowKeyCode ?? UInt32(kVK_ANSI_N),
                carbonModifiers: stickyApp.newWindowModifiers ?? UInt32(cmdKey)
            )
            newWindow = waitForNewWindow(
                originalIDs: beforeWindowIDs,
                bundleID: bundleID,
                pids: runningPIDs(for: bundleID),
                timeout: 1.0,
                yabai: yabai
            )
        }
        
        guard let win = newWindow else {
            DispatchQueue.main.async {
                viewModel.showToast("没能新建窗口（\(stickyApp.displayName) 可能不支持）")
                viewModel.loadData()
            }
            return
        }
        
        // ---- 5. 如果新窗口落在了别的 display，搬过去
        if win.display != targetDisplayIndex {
            try? yabai.moveWindowToDisplay(windowID: win.id, displayIndex: targetDisplayIndex)
            Thread.sleep(forTimeInterval: 0.2)
        }
        
        // ---- 6. focus
        if let updated = try? yabai.queryWindows().first(where: { $0.id == win.id }) {
            try? yabai.focusSpace(index: updated.space)
            Thread.sleep(forTimeInterval: 0.1)
            try? yabai.focusWindow(id: updated.id)
        } else {
            if let targetSpaceIndex { try? yabai.focusSpace(index: targetSpaceIndex) }
            try? yabai.focusWindow(id: win.id)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            viewModel.loadData()
        }
    }
    
    // MARK: - Helpers
    
    private static func runningPIDs(for bundleID: String) -> [Int] {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier == bundleID }
            .map { Int($0.processIdentifier) }
    }
    
    private static func focusExistingWindow(_ window: YabaiWindow, yabai: YabaiService, viewModel: SidebarViewModel) {
        try? yabai.focusSpace(index: window.space)
        Thread.sleep(forTimeInterval: 0.1)
        try? yabai.focusWindow(id: window.id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            viewModel.loadData()
        }
    }
    
    /// 让目标 display 的 active space 成为 focused space。返回该 space 的 index（用于后续 fallback focus）。
    @discardableResult
    private static func focusTargetDisplaySpace(displayIndex: Int, yabai: YabaiService) -> Int? {
        guard let displays = try? yabai.queryDisplays() else { return nil }
        guard let display = displays.first(where: { $0.index == displayIndex }) else { return nil }
        // yabai display 的 spaces 数组里，第一个就是当前可见的 active space
        guard let firstSpaceIndex = display.spaces.first else { return nil }
        try? yabai.focusSpace(index: firstSpaceIndex)
        Thread.sleep(forTimeInterval: 0.15)
        return firstSpaceIndex
    }
    
    private static func currentWindowIDs(for pids: [Int], yabai: YabaiService) -> Set<Int> {
        guard let windows = try? yabai.queryWindows() else { return [] }
        return Set(windows.filter { pids.contains($0.pid) }.map(\.id))
    }
    
    @discardableResult
    private static func launchApp(bundleID: String) -> NSRunningApplication? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let conf = NSWorkspace.OpenConfiguration()
        conf.activates = true
        conf.createsNewApplicationInstance = false
        
        let semaphore = DispatchSemaphore(value: 0)
        var resultApp: NSRunningApplication?
        NSWorkspace.shared.openApplication(at: url, configuration: conf) { app, _ in
            resultApp = app
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
        return resultApp
    }
    
    /// 轮询 yabai 直到看到新窗口（id 不在 originalIDs 中且属于目标 pids）。
    private static func waitForNewWindow(
        originalIDs: Set<Int>,
        bundleID: String,
        pids: [Int],
        timeout: TimeInterval,
        yabai: YabaiService
    ) -> YabaiWindow? {
        let deadline = Date().addingTimeInterval(timeout)
        var attemptPIDs = pids
        while Date() < deadline {
            // pid 集合可能在等待期间扩张（app 刚启动）
            let nowPIDs = runningPIDs(for: bundleID)
            if nowPIDs.count != attemptPIDs.count { attemptPIDs = nowPIDs }
            
            if let windows = try? yabai.queryWindows() {
                let new = windows.first {
                    attemptPIDs.contains($0.pid)
                        && !originalIDs.contains($0.id)
                        && $0.hasAXReference
                        && $0.isVisible
                        && !$0.isMinimized
                }
                if let new { return new }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return nil
    }
    
    /// 模拟按下指定快捷键。在当前 focused 进程上下文里发送，所以前面必须先 activate 过目标 app。
    /// - Parameters:
    ///   - keyCode: Carbon virtual key code (e.g. kVK_ANSI_N)
    ///   - carbonModifiers: Carbon modifier flags (cmdKey | shiftKey 等组合)
    private static func sendNewWindowKeystroke(keyCode: UInt32, carbonModifiers: UInt32) {
        var cgFlags: CGEventFlags = []
        if carbonModifiers & UInt32(cmdKey) != 0 { cgFlags.insert(.maskCommand) }
        if carbonModifiers & UInt32(shiftKey) != 0 { cgFlags.insert(.maskShift) }
        if carbonModifiers & UInt32(optionKey) != 0 { cgFlags.insert(.maskAlternate) }
        if carbonModifiers & UInt32(controlKey) != 0 { cgFlags.insert(.maskControl) }
        
        let src = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(keyCode)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        down?.flags = cgFlags
        up?.flags = cgFlags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.15)
    }
    
}
