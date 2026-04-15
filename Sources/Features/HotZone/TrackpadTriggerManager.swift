import Cocoa

class TrackpadTriggerManager {
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isEnabled = false
    var onTrigger: ((NSPoint, NSScreen) -> Void)?
    
    private var lastTriggerTime: Date = .distantPast
    private var touchCount: Int = 0
    private var touchStartTime: Date = .distantPast
    
    func start() {
        // 请求辅助功能权限（仅弹窗提示，不阻塞）
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
        ] as CFDictionary)
        
        if !trusted {
            NSLog("[TrackpadTrigger] Accessibility permission not yet granted")
        }
        
        // 不管权限状态都尝试创建 event tap
        // 如果没权限会返回 nil，此时静默失败
        // 用户授权后需要重启 app 才能生效
        let eventMask: CGEventMask = (1 << 29)  // NSEvent.EventType.gesture rawValue = 29
        
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<TrackpadTriggerManager>.fromOpaque(refcon).takeUnretainedValue()
                manager.handleCGEvent(event)
                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("[TrackpadTrigger] Failed to create event tap - need Accessibility permission")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[TrackpadTrigger] Event tap started")
    }
    
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
        }
        eventTap = nil
        runLoopSource = nil
    }
    
    private func handleCGEvent(_ event: CGEvent) {
        guard isEnabled else { return }
        
        // 尝试读取私有字段：touchCount (field 135)
        // 如果不可用，值会是 0
        let touches = event.getIntegerValueField(CGEventField(rawValue: 135)!)
        let phase = event.getIntegerValueField(CGEventField(rawValue: 132)!)
        
        // 调试输出
        if touches > 0 {
            NSLog("[TrackpadTrigger] touches=\(touches) phase=\(phase)")
        }
        
        // 方案 A: 私有字段可用 — 三指 tap (phase 1=began)
        if touches == 3 && phase == 1 {
            triggerIfReady()
            return
        }
        
        // 方案 B: 如果私有字段不可用(touches=0)，尝试用 NSEvent 解析
        if touches == 0 {
            if let nsEvent = NSEvent(cgEvent: event) {
                // magnification 手势 beginPhase 时检查触摸数
                let allTouches = nsEvent.allTouches()
                if allTouches.count == 3 {
                    let began = allTouches.filter { $0.phase == .began }
                    if began.count >= 1 {
                        NSLog("[TrackpadTrigger] NSEvent 3-finger touch detected")
                        triggerIfReady()
                    }
                }
            }
        }
    }
    
    private func triggerIfReady() {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > 0.5 else { return }
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
