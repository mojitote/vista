import Cocoa

class HotZoneManager {
    
    private var mouseMonitor: Any?
    private var edgeTimer: DispatchSourceTimer?
    private var isInHotZone = false
    
    var isEnabled = true
    var delay: TimeInterval = AppConstants.hotZoneDelay
    var hotZoneWidth: CGFloat = AppConstants.hotZoneWidth
    var onTrigger: ((NSScreen) -> Void)?
    
    func start() {
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
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
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
