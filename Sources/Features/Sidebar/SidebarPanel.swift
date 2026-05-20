import Cocoa
import SwiftUI

class SidebarPanel: NSPanel {
    
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private var localMouseMonitor: Any?
    private var dismissTimer: DispatchSourceTimer?
    private var suppressTimer: DispatchSourceTimer?
    private var isAnimating = false
    private var colorOverlayView: NSView?
    var onDismiss: (() -> Void)?
    /// 打开设置窗口等场景下暂停自动消失。调用者负责复位。
    var isDismissSuspended = false {
        didSet {
            if isDismissSuspended { cancelDismissTimer() }
        }
    }
    
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
            let overlay = ensureOverlayView(in: visualEffect)
            overlay.layer?.sublayers?.removeAll(where: { $0 is CAGradientLayer })
            let clamped = max(0, min(1, CGFloat(opacity)))
            overlay.layer?.backgroundColor = color.withAlphaComponent(clamped).cgColor
            overlay.isHidden = false
        } else {
            colorOverlayView?.isHidden = true
        }
    }
    
    /// 在 vibrancy 之上叠加渐变覆盖层（Zen 风格多层渐变系统）
    /// - 1 色：纯色覆盖
    /// - 2 色：双向线性渐变叠加（Zen: 两个反向 linear-gradient）
    /// - 3 色：线性 + 两个径向渐变叠加（Zen: linear-gradient + 2x radial-gradient）
    func updateSidebarGradient(colors: [NSColor], angle: Double, opacity: Double) {
        guard let visualEffect = contentView as? NSVisualEffectView else { return }
        
        guard !colors.isEmpty else {
            colorOverlayView?.isHidden = true
            return
        }
        
        let overlay = ensureOverlayView(in: visualEffect)
        overlay.layer?.backgroundColor = NSColor.clear.cgColor
        overlay.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        
        let clamped = max(0, min(1, CGFloat(opacity)))
        
        if colors.count == 1 {
            overlay.layer?.backgroundColor = colors[0].withAlphaComponent(clamped).cgColor
        } else if colors.count == 2 {
            // Zen: linear-gradient(-45deg, color[1] 0%, transparent 100%),
            //      linear-gradient(135deg, color[0] 0%, transparent 100%)
            let rotation = angle
            
            let layer1 = CAGradientLayer()
            layer1.frame = overlay.bounds
            layer1.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer1.colors = [colors[0].withAlphaComponent(clamped).cgColor, NSColor.clear.cgColor]
            let rad1 = (rotation + 180 + 90) * .pi / 180.0
            layer1.startPoint = CGPoint(x: 0.5 - cos(rad1) * 0.5, y: 0.5 + sin(rad1) * 0.5)
            layer1.endPoint   = CGPoint(x: 0.5 + cos(rad1) * 0.5, y: 0.5 - sin(rad1) * 0.5)
            overlay.layer?.addSublayer(layer1)
            
            let layer2 = CAGradientLayer()
            layer2.frame = overlay.bounds
            layer2.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            layer2.colors = [colors[1].withAlphaComponent(clamped).cgColor, NSColor.clear.cgColor]
            let rad2 = (rotation + 90) * .pi / 180.0
            layer2.startPoint = CGPoint(x: 0.5 - cos(rad2) * 0.5, y: 0.5 + sin(rad2) * 0.5)
            layer2.endPoint   = CGPoint(x: 0.5 + cos(rad2) * 0.5, y: 0.5 - sin(rad2) * 0.5)
            overlay.layer?.addSublayer(layer2)
        } else if colors.count >= 3 {
            // Zen CSS:
            //   linear-gradient(-5deg, color3 10%, transparent 80%),
            //   radial-gradient(circle at 95% 0%, color2 0%, transparent 75%),
            //   radial-gradient(circle at 0% 0%, color1 10%, transparent 70%)
            // 渲染顺序：底→顶
            
            // 底层: radial at top-left (color1)
            let radial1 = RadialGradientLayer()
            radial1.frame = overlay.bounds
            radial1.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            radial1.gradientColor = colors[0].withAlphaComponent(clamped)
            radial1.centerRatio = CGPoint(x: 0.0, y: 0.0)  // top-left (Core Graphics: y=0 is bottom)
            radial1.radiusRatio = 0.7
            radial1.innerStop = 0.1
            radial1.setNeedsDisplay()
            overlay.layer?.addSublayer(radial1)
            
            // 中层: radial at top-right (color2)
            let radial2 = RadialGradientLayer()
            radial2.frame = overlay.bounds
            radial2.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            radial2.gradientColor = colors[1].withAlphaComponent(clamped)
            radial2.centerRatio = CGPoint(x: 0.95, y: 0.0)  // top-right
            radial2.radiusRatio = 0.75
            radial2.innerStop = 0.0
            radial2.setNeedsDisplay()
            overlay.layer?.addSublayer(radial2)
            
            // 顶层: linear gradient (color3)
            let linearLayer = CAGradientLayer()
            linearLayer.frame = overlay.bounds
            linearLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            linearLayer.colors = [colors[2].withAlphaComponent(clamped).cgColor, NSColor.clear.cgColor]
            linearLayer.locations = [0.1, 0.8]
            let rad = (-5.0 + 90) * .pi / 180.0
            linearLayer.startPoint = CGPoint(x: 0.5 - cos(rad) * 0.5, y: 0.5 + sin(rad) * 0.5)
            linearLayer.endPoint   = CGPoint(x: 0.5 + cos(rad) * 0.5, y: 0.5 - sin(rad) * 0.5)
            overlay.layer?.addSublayer(linearLayer)
        }
        
        overlay.isHidden = false
    }
    
    private func ensureOverlayView(in visualEffect: NSVisualEffectView) -> GradientOverlayView {
        if let existing = colorOverlayView as? GradientOverlayView { return existing }
        let overlay = GradientOverlayView()
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
        return overlay
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
    
    /// 是否应该跳过自动消失：菜单 / popover / sheet 正在显示、或上层显式暂停了（如设置窗口打开）
    ///
    /// 加入 Popover 判断后，点击 todo 行的「日期选择」/「时间段」弹层时，即便鼠标
    /// 移出了 sidebar 本体也不会触发自动收起。
    private var shouldSkipDismiss: Bool {
        if isDismissSuspended { return true }
        return NSApp.windows.contains(where: { window in
            guard window != self, window.isVisible else { return false }
            let name = window.className
            return name.contains("Menu")
                || name.contains("Popover")
                || window.isSheet
                || (window is NSPanel && window.styleMask.contains(.utilityWindow))
        })
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
    
    /// 临时暂停自动消失（用于 Scene 切换等导致面板缩放的场景）
    func suppressDismissTemporarily(for duration: TimeInterval = 0.6) {
        isDismissSuspended = true
        cancelDismissTimer()

        suppressTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.isDismissSuspended = false
            self.suppressTimer = nil
        }
        timer.resume()
        suppressTimer = timer
    }

    deinit {
        stopMouseMonitoring()
        cancelDismissTimer()
        suppressTimer?.cancel()
    }
}

// MARK: - Gradient Overlay View (子图层随 layout 自适应)

/// 确保子 CALayer（特别是 RadialGradientLayer）在 overlay view resize 时同步更新 frame
private class GradientOverlayView: NSView {
    override func layout() {
        super.layout()
        // 同步所有子图层的 frame 到当前 bounds
        layer?.sublayers?.forEach { sublayer in
            sublayer.frame = bounds
        }
    }
}

// MARK: - Custom Core Graphics Radial Gradient Layer (无伪影)

/// 使用 Core Graphics 手动绘制径向渐变，避免 CAGradientLayer.radial 的边缘伪影
private class RadialGradientLayer: CALayer {
    var gradientColor: NSColor = .white
    /// 圆心位置（0~1 比例，相对于 bounds）。注意 CALayer 坐标系 y=0 在底部
    var centerRatio: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// 半径占对角线长度的比例
    var radiusRatio: CGFloat = 0.7
    /// 内圈起始不透明位置（0~1），innerStop 以内为纯色
    var innerStop: CGFloat = 0.0
    
    override init() {
        super.init()
        needsDisplayOnBoundsChange = true  // bounds 变化时自动重绘
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? RadialGradientLayer {
            gradientColor = other.gradientColor
            centerRatio = other.centerRatio
            radiusRatio = other.radiusRatio
            innerStop = other.innerStop
        }
        needsDisplayOnBoundsChange = true
        contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        needsDisplayOnBoundsChange = true
    }
    
    override func draw(in ctx: CGContext) {
        let w = bounds.width
        let h = bounds.height
        guard w > 0 && h > 0 else { return }
        
        // CALayer 坐标系：y=0 在底部。CSS 的 "0% 0%" 是左上角
        // 所以 CSS "circle at 0% 0%" (左上) → CG centerRatio (0, 1)
        // CSS "circle at 95% 0%" (右上) → CG centerRatio (0.95, 1)
        let center = CGPoint(x: w * centerRatio.x, y: h * (1.0 - centerRatio.y))
        let diagonal = sqrt(w * w + h * h)
        let radius = diagonal * radiusRatio
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return }
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        gradientColor.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        let components: [CGFloat] = [
            r, g, b, a,     // inner color (full)
            r, g, b, a,     // inner stop position
            r, g, b, 0.0,   // outer (transparent)
        ]
        let locations: [CGFloat] = [0.0, innerStop, 1.0]
        
        guard let gradient = CGGradient(colorSpace: colorSpace, colorComponents: components, locations: locations, count: 3) else { return }
        
        ctx.drawRadialGradient(
            gradient,
            startCenter: center, startRadius: 0,
            endCenter: center, endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }
}
