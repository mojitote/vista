import Cocoa

private func trackpadDebugReport(
    hypothesisId: String,
    location: String,
    msg: String,
    data: [String: Any] = [:]
) {
    // #region debug-point B:trackpad-report
    guard let url = URL(string: "http://127.0.0.1:7777/event") else { return }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body: [String: Any] = [
        "sessionId": "trackpad-trigger-chain",
        "runId": "pre-fix",
        "hypothesisId": hypothesisId,
        "location": location,
        "msg": "[DEBUG] \(msg)",
        "data": data,
        "ts": Int(Date().timeIntervalSince1970 * 1000)
    ]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request).resume()
    // #endregion
}

class TrackpadTriggerManager {
    
    var isEnabled = false
    var onTrigger: ((NSPoint, NSScreen) -> Void)?
    
    private var mouseMonitor: Any?
    private var isStarted = false
    
    private var lastTriggerTime: Date = .distantPast
    // 触发后冷却时间
    private let cooldown: TimeInterval = 0.6
    
    func start() {
        guard !isStarted else { return }
        
        // #region debug-point B:trackpad-start
        trackpadDebugReport(
            hypothesisId: "B",
            location: "TrackpadTriggerManager.start",
            msg: "right mouse monitor starting",
            data: ["isEnabled": isEnabled]
        )
        // #endregion
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            self?.handleRightMouseEvent(event)
        }
        
        isStarted = true
        // #region debug-point B:trackpad-started
        trackpadDebugReport(
            hypothesisId: "B",
            location: "TrackpadTriggerManager.start",
            msg: "right mouse monitor started",
            data: ["isEnabled": isEnabled]
        )
        // #endregion
    }
    
    func stop() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        isStarted = false
        // #region debug-point A:trackpad-stop
        trackpadDebugReport(
            hypothesisId: "A",
            location: "TrackpadTriggerManager.stop",
            msg: "right mouse monitor stopped",
            data: ["isEnabled": isEnabled]
        )
        // #endregion
    }
    
    private func handleRightMouseEvent(_ event: NSEvent) {
        guard isEnabled else { return }

        // #region debug-point C:gesture-event-received
        trackpadDebugReport(
            hypothesisId: "C",
            location: "TrackpadTriggerManager.handleRightMouseEvent",
            msg: "right mouse event received",
            data: [
                "clickCount": event.clickCount,
                "buttonNumber": event.buttonNumber,
                "locationX": event.locationInWindow.x,
                "locationY": event.locationInWindow.y
            ]
        )
        // #endregion

        if event.clickCount >= 2 {
            // #region debug-point D:tap-detected
            trackpadDebugReport(
                hypothesisId: "D",
                location: "TrackpadTriggerManager.handleRightMouseEvent",
                msg: "double secondary click detected",
                data: ["clickCount": event.clickCount]
            )
            // #endregion
            triggerIfReady()
        }
    }
    
    private func triggerIfReady() {
        let now = Date()
        
        guard now.timeIntervalSince(lastTriggerTime) > cooldown else {
            // #region debug-point D:cooldown
            trackpadDebugReport(
                hypothesisId: "D",
                location: "TrackpadTriggerManager.triggerIfReady",
                msg: "trigger ignored by cooldown"
            )
            // #endregion
            return
        }

        lastTriggerTime = now
        // #region debug-point E:double-tap-triggered
        trackpadDebugReport(
            hypothesisId: "E",
            location: "TrackpadTriggerManager.triggerIfReady",
            msg: "double secondary click triggered"
        )
        // #endregion
        
        DispatchQueue.main.async { [weak self] in
            let mouseLocation = NSEvent.mouseLocation
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return }
            // #region debug-point E:on-trigger-dispatch
            trackpadDebugReport(
                hypothesisId: "E",
                location: "TrackpadTriggerManager.triggerIfReady.dispatch",
                msg: "dispatching onTrigger",
                data: [
                    "mouseX": mouseLocation.x,
                    "mouseY": mouseLocation.y
                ]
            )
            // #endregion
            self?.onTrigger?(mouseLocation, screen)
        }
    }
    
    deinit {
        stop()
    }
}
