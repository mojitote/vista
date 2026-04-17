import Cocoa

class TrackpadTriggerManager {
    
    var isEnabled = false
    var onTrigger: ((NSPoint, NSScreen) -> Void)?
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isStarted = false
    
    private var lastTriggerTime: Date = .distantPast
    
    // 第一击暂存
    private var pendingFirstClick: CGEvent?
    private var pendingFirstClickUp: CGEvent?  // 配对的 rightMouseUp
    private var pendingFirstClickTime: CFAbsoluteTime = 0
    private var pendingFirstClickLocation: NSPoint = .zero
    private var releaseTimer: DispatchSourceTimer?
    
    // 参数
    private let cooldown: TimeInterval = 0.6
    private let doubleTapWindow: TimeInterval = 0.3   // 两次右键间最大间隔
    private let maxDistance: CGFloat = 50              // 两次右键间最大位移
    
    private var releaseDelay: TimeInterval {
        SettingsStore.shared.doubleTapDelay
    }
    
    func start() {
        guard !isStarted else { return }
        
        // 检查辅助功能权限
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        guard trusted else {
            NSLog("[TrackpadTrigger] Accessibility not trusted, cannot create event tap")
            return
        }
        
        // 拦截 rightMouseDown 和 rightMouseUp
        let eventMask: CGEventMask = (1 << CGEventType.rightMouseDown.rawValue) | (1 << CGEventType.rightMouseUp.rawValue)
        
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,  // 可拦截，不是 listenOnly
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<TrackpadTriggerManager>.fromOpaque(refcon).takeUnretainedValue()
                return manager.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            NSLog("[TrackpadTrigger] Failed to create CGEvent tap - check accessibility permissions")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        
        isStarted = true
    }
    
    func stop() {
        cancelReleaseTimer()
        releasePendingClick()
        
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isStarted = false
    }
    
    // MARK: - CGEvent 回调
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 如果 tap 被系统禁用了（超时），重新启用
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }
        
        // 不在启用状态时，直接放行
        guard isEnabled else {
            return Unmanaged.passRetained(event)
        }
        
        // rightMouseUp：如果有暂存的 down，也暂存 up（保持配对）；否则放行
        if type == .rightMouseUp {
            if pendingFirstClick != nil {
                pendingFirstClickUp = event.copy()
                return nil  // 吞掉，等补发时一起发
            }
            return Unmanaged.passRetained(event)
        }
        
        guard type == .rightMouseDown else {
            return Unmanaged.passRetained(event)
        }
        
        let mouseLocation = NSEvent.mouseLocation
        let now = CFAbsoluteTimeGetCurrent()
        
        // 有暂存的第一击？检查是否构成双击
        if pendingFirstClick != nil {
            let interval = now - pendingFirstClickTime
            let distance = hypot(mouseLocation.x - pendingFirstClickLocation.x,
                                 mouseLocation.y - pendingFirstClickLocation.y)
            
            if interval <= doubleTapWindow && distance <= maxDistance {
                // 双击成功！吞掉两下，触发 Vista
                cancelReleaseTimer()
                pendingFirstClick = nil
                pendingFirstClickUp = nil
                
                triggerVista()
                return nil  // 吞掉第二击
            } else {
                // 不构成双击，先把第一击补发出去
                releasePendingClick()
                cancelReleaseTimer()
            }
        }
        
        // 暂存当前这一击作为"第一击"
        pendingFirstClick = event.copy()
        pendingFirstClickTime = now
        pendingFirstClickLocation = mouseLocation
        
        // 启动超时定时器：如果第二击没来，就把第一击补发
        startReleaseTimer()
        
        // 暂时吞掉第一击（等待第二击或超时补发）
        return nil
    }
    
    // MARK: - 超时补发
    
    private func startReleaseTimer() {
        cancelReleaseTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + releaseDelay)
        timer.setEventHandler { [weak self] in
            self?.releasePendingClick()
        }
        timer.resume()
        releaseTimer = timer
    }
    
    private func cancelReleaseTimer() {
        releaseTimer?.cancel()
        releaseTimer = nil
    }
    
    private func releasePendingClick() {
        guard let downEvent = pendingFirstClick else { return }
        let upEvent = pendingFirstClickUp
        pendingFirstClick = nil
        pendingFirstClickUp = nil
        // 禁用 tap → 补发 down + up → 延迟重新启用，避免补发事件被自己拦截
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        downEvent.post(tap: .cgSessionEventTap)
        upEvent?.post(tap: .cgSessionEventTap)
        // 延迟重新启用 tap，给补发事件足够的时间通过管线
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self, let tap = self.eventTap, self.isStarted else { return }
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }
    
    // MARK: - 触发 Vista
    
    private func triggerVista() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > cooldown else { return }
        lastTriggerTime = now
        
        DispatchQueue.main.async { [weak self] in
            let mouseLocation = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }
            self?.onTrigger?(mouseLocation, screen)
        }
    }
    
    deinit {
        stop()
    }
}
