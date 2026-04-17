import Cocoa
import SwiftUI

class SidebarPanel: NSPanel {
    
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private var localMouseMonitor: Any?
    private var dismissTimer: DispatchSourceTimer?
    private var isAnimating = false
    private var colorOverlayView: NSView?
    var onDismiss: (() -> Void)?
    /// 打开设置窗口等场景下暂停自动消失。调用者负责复位。
    var isDismissSuspended = false
    
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
        // 默认用 .sidebar —— frosted 效果最明显、饱和度拉高。material 之后由用户设置覆盖。
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .sidebar
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
        visualEffect.wantsLayer = true
        
        contentView = visualEffect
    }
    
    override var canBecomeKey: Bool { true }
    
    // MARK: - Sidebar Color / Material
    
    func updateBlurMaterial(_ material: NSVisualEffectView.Material) {
        guard let visualEffect = contentView as? NSVisualEffectView else { return }
        visualEffect.material = material
        visualEffect.state = .active
        visualEffect.blendingMode = .behindWindow
    }
    
    /// 在 vibrancy 之上叠加用户 tint（可选）
    /// - color: tint 颜色，nil 表示不叠加
    /// - opacity: tint 覆盖强度 0..1（直接作为 alpha 使用，不再做 0.55 倍缩放）
    func updateSidebarColor(color: NSColor?, opacity: Double) {
        guard let visualEffect = contentView as? NSVisualEffectView else { return }
        
        if let color = color {
            if colorOverlayView == nil {
                let overlay = NSView()
                overlay.wantsLayer = true
                overlay.translatesAutoresizingMaskIntoConstraints = false
                // 放在 hostingView 下面，保证 SwiftUI 内容在最上层
                visualEffect.addSubview(overlay, positioned: .below, relativeTo: visualEffect.subviews.first)
                NSLayoutConstraint.activate([
                    overlay.topAnchor.constraint(equalTo: visualEffect.topAnchor),
                    overlay.bottomAnchor.constraint(equalTo: visualEffect.bottomAnchor),
                    overlay.leadingAnchor.constraint(equalTo: visualEffect.leadingAnchor),
                    overlay.trailingAnchor.constraint(equalTo: visualEffect.trailingAnchor),
                ])
                colorOverlayView = overlay
            }
            let clamped = max(0, min(1, CGFloat(opacity)))
            colorOverlayView?.layer?.backgroundColor = color.withAlphaComponent(clamped).cgColor
            colorOverlayView?.isHidden = false
        } else {
            colorOverlayView?.isHidden = true
        }
    }
    
    func setSwiftUIContent<Content: View>(_ content: Content) {
        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        // 关键：NSHostingView 在 macOS 14+ 偶发带系统不透明底色，显式清掉以免覆盖 vibrancy。
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        
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
    
    func showAtPosition(
        on screen: NSScreen,
        mousePosition: NSPoint,
        width: CGFloat = AppConstants.defaultSidebarWidth,
        height: CGFloat
    ) {
        guard !isAnimating else { return }
        
        let targetFrame = popupFrame(
            on: screen,
            mousePosition: mousePosition,
            width: width,
            height: height
        )
        let startWidth = max(width * 0.94, width - 16)
        let startHeight = max(height * 0.92, height - 24)
        let startFrame = NSRect(
            x: targetFrame.minX,
            y: targetFrame.maxY - startHeight,
            width: startWidth,
            height: startHeight
        )
        
        alphaValue = 0
        setFrame(startFrame, display: false)
        orderFrontRegardless()
        
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
            self.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            self?.isAnimating = false
            self?.startMouseMonitoring()
        })
    }
    
    func resizePopup(on screen: NSScreen, mousePosition: NSPoint, width: CGFloat, height: CGFloat) {
        let targetFrame = popupFrame(
            on: screen,
            mousePosition: mousePosition,
            width: width,
            height: height
        )
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
        }
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
    }
    
    /// 是否应该跳过自动消失：菜单 / sheet 正在显示、或上层显式暂停了（如设置窗口打开）
    private var shouldSkipDismiss: Bool {
        if isDismissSuspended { return true }
        return NSApp.windows.contains(where: { $0.isVisible && $0 != self && ($0.className.contains("Menu") || $0.isSheet) })
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        if shouldSkipDismiss {
            cancelDismissTimer()
            return
        }
        
        let mouseLocation = NSEvent.mouseLocation
        if frame.contains(mouseLocation) {
            cancelDismissTimer()
        } else {
            scheduleDismiss()
        }
    }
    
    private func handleClickOutside(_ event: NSEvent) {
        if shouldSkipDismiss { return }
        
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
    
    private func popupFrame(on screen: NSScreen, mousePosition: NSPoint, width: CGFloat, height: CGFloat) -> NSRect {
        let visibleFrame = screen.visibleFrame
        let clampedWidth = min(width, visibleFrame.width)
        let maxHeight = max(AppConstants.popupMinHeight, mousePosition.y - visibleFrame.minY)
        let clampedHeight = min(height, maxHeight)
        let x = min(max(mousePosition.x, visibleFrame.minX), visibleFrame.maxX - clampedWidth)
        let topY = min(max(mousePosition.y, visibleFrame.minY + clampedHeight), visibleFrame.maxY)
        let y = max(visibleFrame.minY, topY - clampedHeight)
        return NSRect(x: x, y: y, width: clampedWidth, height: clampedHeight)
    }
    
    deinit {
        stopMouseMonitoring()
        cancelDismissTimer()
    }
}
