import Cocoa

private func hotZoneDebugReport(
    hypothesisId: String,
    location: String,
    msg: String,
    data: [String: Any] = [:]
) {
    // #region debug-point A:hotzone-report
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

class HotZoneManager {
    
    private var mouseMonitor: Any?
    private var edgeTimer: DispatchSourceTimer?
    private var isInHotZone = false
    
    var isEnabled = true
    var delay: TimeInterval = AppConstants.hotZoneDelay
    var hotZoneWidth: CGFloat = AppConstants.hotZoneWidth
    var onTrigger: ((NSScreen) -> Void)?
    
    func start() {
        guard mouseMonitor == nil else { return }
        // #region debug-point A:hotzone-start
        hotZoneDebugReport(
            hypothesisId: "A",
            location: "HotZoneManager.start",
            msg: "hot zone monitor started",
            data: ["isEnabled": isEnabled, "width": hotZoneWidth, "delay": delay]
        )
        // #endregion
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    func stop() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        cancelTimer()
        // #region debug-point A:hotzone-stop
        hotZoneDebugReport(
            hypothesisId: "A",
            location: "HotZoneManager.stop",
            msg: "hot zone monitor stopped",
            data: ["isEnabled": isEnabled]
        )
        // #endregion
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        guard isEnabled else { return }
        
        let mouseLocation = NSEvent.mouseLocation
        
        // Find the screen the mouse is on
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else {
            leaveHotZone()
            return
        }
        
        // Check if mouse is at the left edge of the screen
        let isAtLeftEdge = mouseLocation.x <= screen.frame.minX + hotZoneWidth
        
        if isAtLeftEdge {
            if !isInHotZone {
                enterHotZone(screen: screen)
            }
        } else {
            if isInHotZone {
                leaveHotZone()
            }
        }
    }
    
    private func enterHotZone(screen: NSScreen) {
        isInHotZone = true
        // #region debug-point A:hotzone-enter
        hotZoneDebugReport(
            hypothesisId: "A",
            location: "HotZoneManager.enterHotZone",
            msg: "entered hot zone",
            data: [
                "isEnabled": isEnabled,
                "screenMinX": screen.frame.minX,
                "mouseX": NSEvent.mouseLocation.x
            ]
        )
        // #endregion
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            // #region debug-point A:hotzone-fire
            hotZoneDebugReport(
                hypothesisId: "A",
                location: "HotZoneManager.enterHotZone.timer",
                msg: "hot zone fired",
                data: ["screenMinX": screen.frame.minX]
            )
            // #endregion
            self?.onTrigger?(screen)
            self?.isInHotZone = false
            self?.edgeTimer = nil
        }
        timer.resume()
        edgeTimer = timer
    }
    
    private func leaveHotZone() {
        isInHotZone = false
        cancelTimer()
    }
    
    private func cancelTimer() {
        edgeTimer?.cancel()
        edgeTimer = nil
    }
    
    deinit {
        stop()
    }
}
