import Cocoa

class TrackpadTriggerManager {
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    var isEnabled = false
    var onTrigger: ((NSPoint, NSScreen) -> Void)?
    
    private var lastTriggerTime: Date = .distantPast
    private var isStarted = false
    
    func start() {
        guard !isStarted else { return }
        
        // 不弹权限提示，静默检查
        let trusted = AXIsProcessTrustedWithOptions(nil)
        
        if !trusted {
            // 弹权限提示
            AXIsProcessTrustedWithOptions([
                kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true
            ] as CFDictionary)
            NSLog("[TrackpadTrigger] Accessibility permission not granted, start failed")
            return
        }
        
        let eventMask: CGEventMask = (1 << 29)  // gesture events
        
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
            NSLog("[TrackpadTrigger] Failed to create event tap")
            return
        }
        
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isStarted = true
        NSLog("[TrackpadTrigger] Event tap started successfully")
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
        isStarted = false
    }
    
    private func handleCGEvent(_ event: CGEvent) {
        guard isEnabled else { return }
        
        let touches = event.getIntegerValueField(CGEventField(rawValue: 135)!)
        let phase = event.getIntegerValueField(CGEventField(rawValue: 132)!)
        
        // 方案 A: 私有字段可用
        if touches == 3 && phase == 1 {
            triggerIfReady()
            return
        }
        
        // 方案 B: NSEvent fallback
        if touches == 0 {
            if let nsEvent = NSEvent(cgEvent: event) {
                let allTouches = nsEvent.allTouches()
                if allTouches.count == 3 {
                    let began = allTouches.filter { $0.phase == .began }
                    if began.count >= 1 {
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
