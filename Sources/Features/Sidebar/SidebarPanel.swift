import Cocoa
import SwiftUI

class SidebarPanel: NSPanel {
    
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private var localMouseMonitor: Any?
    private var localClickMonitor: Any?
    private var dismissTimer: DispatchSourceTimer?
    private var isAnimating = false
    private var colorOverlayView: NSView?
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
    
    // MARK: - Sidebar Color
    
    func updateSidebarColor(color: NSColor?, opacity: Double) {
        guard let visualEffect = contentView as? NSVisualEffectView else { return }
        
        if let color = color {
            // 自定义颜色模式：禁用毛玻璃，使用纯色叠加
            visualEffect.material = .sidebar
            visualEffect.state = .active
            
            if colorOverlayView == nil {
                let overlay = NSView()
                overlay.wantsLayer = true
                overlay.translatesAutoresizingMaskIntoConstraints = false
                visualEffect.addSubview(overlay, positioned: .below, relativeTo: visualEffect.subviews.first)
                NSLayoutConstraint.activate([
                    overlay.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                    overlay.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
                    overlay.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                    overlay.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
                ])
                colorOverlayView = overlay
            }
            colorOverlayView?.layer?.backgroundColor = color.withAlphaComponent(CGFloat(opacity)).cgColor
            colorOverlayView?.isHidden = false
        } else {
            // 默认毛玻璃模式
            colorOverlayView?.isHidden = true
            visualEffect.material = .sidebar
            visualEffect.state = .active
        }
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
        
        alphaValue = 0
        setFrame(startFrame, display: false)
        orderFrontRegardless()
        
        // Animate slide in + fade in
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = AppConstants.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 1
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
            self.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.orderOut(nil)
            self?.alphaValue = 1  // 重置透明度，下次 show 时正常显示
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
