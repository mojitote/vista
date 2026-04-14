import Cocoa
import SwiftUI

class SidebarPanel: NSPanel {
    
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private var localMouseMonitor: Any?
    private var localClickMonitor: Any?
    private var dismissTimer: DispatchSourceTimer?
    private var isAnimating = false
    var onDismiss: (() -> Void)?
    
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        
        // Setup visual effect view for vibrancy
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        
        contentView = visualEffect
    }
    
    func setSwiftUIContent<Content: View>(_ content: Content) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        guard let visualEffect = contentView as? NSVisualEffectView else { return }
        visualEffect.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffect.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
        ])
    }
    
    // MARK: - Show/Hide with Animation
    
    func show(on screen: NSScreen, width: CGFloat = AppConstants.defaultSidebarWidth) {
        guard !isAnimating else { return }
        
        let visibleFrame = screen.visibleFrame
        let targetFrame = NSRect(
            x: visibleFrame.minX,
            y: visibleFrame.minY,
            width: width,
            height: visibleFrame.height
        )
        
        // Start offscreen to the left
        let startFrame = NSRect(
            x: visibleFrame.minX - width,
            y: visibleFrame.minY,
            width: width,
            height: visibleFrame.height
        )
        
        setFrame(startFrame, display: false)
        orderFrontRegardless()
        
        // Animate slide in
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AppConstants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.startMouseMonitoring()
        })
    }
    
    func dismiss() {
        guard !isAnimating, isVisible else { return }
        
        stopMouseMonitoring()
        cancelDismissTimer()
        
        let currentFrame = frame
        let targetFrame = NSRect(
            x: currentFrame.minX - currentFrame.width,
            y: currentFrame.minY,
            width: currentFrame.width,
            height: currentFrame.height
        )
        
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AppConstants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().setFrame(targetFrame, display: true)
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.orderOut(nil)
            self?.onDismiss?()
        })
    }
    
    // MARK: - Mouse Monitoring
    
    private func startMouseMonitoring() {
        // Monitor mouse moved to detect when mouse leaves sidebar
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(event)
        }
        
        // Monitor clicks outside the sidebar
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleClickOutside(event)
        }
        
        // Local monitor for events within our own panel
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseMoved(event)
            return event
        }
        
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            // Don't dismiss on clicks inside the panel
            return event
        }
    }
    
    private func stopMouseMonitoring() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
        if let monitor = localMouseMonitor {
            NSEvent.removeMonitor(monitor)
            localMouseMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        
        if frame.contains(mouseLocation) {
            // Mouse is inside sidebar, cancel any pending dismiss
            cancelDismissTimer()
        } else {
            // Mouse left sidebar, start dismiss timer
            scheduleDismiss()
        }
    }
    
    private func handleClickOutside(_ event: NSEvent) {
        let mouseLocation = NSEvent.mouseLocation
        if !frame.contains(mouseLocation) {
            dismiss()
        }
    }
    
    // MARK: - Dismiss Timer
    
    private func scheduleDismiss() {
        guard dismissTimer == nil else { return }
        
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + AppConstants.mouseOutDelay)
        timer.setEventHandler { [weak self] in
            self?.dismiss()
        }
        timer.resume()
        dismissTimer = timer
    }
    
    private func cancelDismissTimer() {
        dismissTimer?.cancel()
        dismissTimer = nil
    }
    
    deinit {
        stopMouseMonitoring()
        cancelDismissTimer()
    }
}
