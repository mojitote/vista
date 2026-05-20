import SwiftUI
import AppKit

// MARK: - Color Harmony

enum ColorHarmony: String, CaseIterable, Identifiable {
    case single = "单色"
    case complementary = "互补"
    case analogous = "近似"
    case triadic = "三角"
    case splitComplementary = "分裂互补"
    
    var id: String { rawValue }
    
    var angleOffsets: [Double] {
        switch self {
        case .single: return []
        case .complementary: return [180]
        case .analogous: return [50, 310]
        case .triadic: return [120, 240]
        case .splitComplementary: return [150, 210]
        }
    }
    
    var dotCount: Int { angleOffsets.count + 1 }
    
    /// SF Symbol for the toggle button
    var iconName: String {
        switch self {
        case .single: return "circle"
        case .complementary: return "circle.grid.2x1"
        case .analogous: return "circle.grid.3x3"
        case .triadic: return "triangle"
        case .splitComplementary: return "arrow.triangle.branch"
        }
    }
    
    var next: ColorHarmony {
        let all = ColorHarmony.allCases
        let idx = all.firstIndex(of: self)!
        return all[(idx + 1) % all.count]
    }
}

// MARK: - Dot Model

struct WheelDot: Identifiable {
    let id: Int
    var position: CGPoint
    var colorHex: String
    var isPrimary: Bool { id == 0 }
}

// MARK: - Preset Data (matching Zen's 5 pages)

struct ThemePreset: Identifiable {
    let id = UUID()
    let colors: [String]     // hex colors for the dots
    let position: CGPoint    // primary dot position in 360x360 space
    let lightness: Int
    let numDots: Int
    let algo: String
}

private let zenPresetPages: [[ThemePreset]] = [
    // Page 1: Light single dots
    [
        ThemePreset(colors: ["#f4efdf"], position: CGPoint(x: 240, y: 240), lightness: 90, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#f0b8cd"], position: CGPoint(x: 233, y: 157), lightness: 80, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#e9c3e3"], position: CGPoint(x: 236, y: 111), lightness: 80, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#da7682"], position: CGPoint(x: 234, y: 173), lightness: 70, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#eb8570"], position: CGPoint(x: 220, y: 187), lightness: 70, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#dcce7f"], position: CGPoint(x: 225, y: 237), lightness: 60, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#5becad"], position: CGPoint(x: 147, y: 195), lightness: 60, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#919bb5"], position: CGPoint(x: 81, y: 84), lightness: 50, numDots: 1, algo: "float"),
    ],
    // Page 2: Light 3-dot analogous
    [
        ThemePreset(colors: ["#f5edd6", "#ddf3d8", "#f3d8e1"], position: CGPoint(x: 240, y: 240), lightness: 90, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#f3bede", "#f7deba", "#dfc3ee"], position: CGPoint(x: 233, y: 157), lightness: 85, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#e5b3e4", "#ecacb2", "#c5b9df"], position: CGPoint(x: 236, y: 111), lightness: 80, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#eb7a9f", "#efef76", "#d285e0"], position: CGPoint(x: 234, y: 173), lightness: 70, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#f2737b", "#aff273", "#e67de8"], position: CGPoint(x: 220, y: 187), lightness: 70, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#ddcd55", "#61d45e", "#d75b7c"], position: CGPoint(x: 225, y: 237), lightness: 60, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#4be7d2", "#54afde", "#3ef470"], position: CGPoint(x: 147, y: 195), lightness: 60, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#7a849e", "#8975a4", "#74a2a4"], position: CGPoint(x: 81, y: 84), lightness: 55, numDots: 3, algo: "analogous"),
    ],
    // Page 3: Dark single dots
    [
        ThemePreset(colors: ["#5d566a"], position: CGPoint(x: 171, y: 72), lightness: 10, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#997096"], position: CGPoint(x: 265, y: 79), lightness: 40, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#956066"], position: CGPoint(x: 301, y: 176), lightness: 35, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#9c6645"], position: CGPoint(x: 237, y: 210), lightness: 30, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#517b6c"], position: CGPoint(x: 91, y: 228), lightness: 30, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#576e75"], position: CGPoint(x: 67, y: 159), lightness: 25, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#836d5f"], position: CGPoint(x: 314, y: 235), lightness: 20, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#447464"], position: CGPoint(x: 118, y: 215), lightness: 20, numDots: 1, algo: "float"),
    ],
    // Page 4: Dark 3-dot analogous
    [
        ThemePreset(colors: ["#171122", "#250e23", "#121621"], position: CGPoint(x: 171, y: 72), lightness: 10, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#804c7c", "#8d3f42", "#615874"], position: CGPoint(x: 265, y: 79), lightness: 40, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#7a3840", "#7e7934", "#6f446e"], position: CGPoint(x: 301, y: 176), lightness: 35, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#834116", "#408019", "#7a1f5b"], position: CGPoint(x: 237, y: 210), lightness: 30, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#2d6c55", "#345565", "#347623"], position: CGPoint(x: 91, y: 228), lightness: 30, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#2d4a53", "#2e3251", "#265a41"], position: CGPoint(x: 67, y: 159), lightness: 25, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#402f26", "#374026", "#3b2b34"], position: CGPoint(x: 314, y: 235), lightness: 20, numDots: 3, algo: "analogous"),
        ThemePreset(colors: ["#16503d", "#1a3c4c", "#1b570f"], position: CGPoint(x: 118, y: 215), lightness: 20, numDots: 3, algo: "analogous"),
    ],
    // Page 5: Black to white
    [
        ThemePreset(colors: ["#e0e0e0"], position: CGPoint(x: 340, y: 180), lightness: 90, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#c0c0c0"], position: CGPoint(x: 315, y: 180), lightness: 75, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#a0a0a0"], position: CGPoint(x: 292, y: 180), lightness: 63, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#808080"], position: CGPoint(x: 270, y: 180), lightness: 50, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#606060"], position: CGPoint(x: 247, y: 180), lightness: 38, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#404040"], position: CGPoint(x: 225, y: 180), lightness: 25, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#202020"], position: CGPoint(x: 202, y: 180), lightness: 13, numDots: 1, algo: "float"),
        ThemePreset(colors: ["#000000"], position: CGPoint(x: 180, y: 180), lightness: 0, numDots: 1, algo: "float"),
    ],
]

// MARK: - ZenColorPickerView

struct ZenColorPickerView: View {
    @Binding var colorHex: String
    @Binding var gradientColors: [String]
    @Binding var opacity: Double
    @Binding var gradientAngle: Double
    @Binding var texture: Double  // 噪波纹理强度 0~1
    
    @State private var dots: [WheelDot] = []
    @State private var draggingDotID: Int? = nil
    @State private var harmony: ColorHarmony = .single
    @State private var padSize: CGFloat = 0
    @State private var padCenter: CGPoint = .zero
    @State private var currentPage: Int = 0
    @State private var initialized = false
    
    private let padHeight: CGFloat = 280
    private let zenPadRefSize: CGFloat = 360  // Zen's reference coordinate space
    
    var body: some View {
        VStack(spacing: 10) {
            // Dot pad area
            dotPadArea
            
            // Preset swatches with paging
            presetPager
            
            // Opacity slider (wave style)
            opacitySlider
        }
    }
    
    // MARK: - Dot Pad Area (square with dot grid background)
    
    private var dotPadArea: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = padHeight
            let center = CGPoint(x: width / 2, y: height / 2)
            
            ZStack {
                // Dot grid background
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: NSColor(white: 0.5, alpha: 0.08)))
                    .overlay(
                        DotGridPattern()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    )
                
                // Connecting lines between dots
                if dots.count > 1 {
                    Canvas { ctx, _ in
                        var path = Path()
                        for (i, dot) in dots.enumerated() {
                            if i == 0 { path.move(to: dot.position) }
                            else { path.addLine(to: dot.position) }
                        }
                        if dots.count > 2 { path.closeSubpath() }
                        ctx.stroke(path, with: .color(.white.opacity(0.2)), lineWidth: 1)
                    }
                    .allowsHitTesting(false)
                }
                
                // Dots
                ForEach(dots) { dot in
                    let isDragging = draggingDotID == dot.id
                    let size: CGFloat = dot.isPrimary ? 38 : 24
                    let border: CGFloat = dot.isPrimary ? 6 : 3
                    let scale: CGFloat = isDragging ? 1.15 : 1.0
                    
                    Circle()
                        .fill(Color(hex: dot.colorHex))
                        .frame(width: size - border * 2, height: size - border * 2)
                        .padding(border)
                        .overlay(
                            Circle().strokeBorder(Color.white, lineWidth: border)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .scaleEffect(scale)
                        .position(dot.position)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: dot.position)
                        .animation(.easeOut(duration: 0.1), value: isDragging)
                }
                
                // Bottom action buttons (+, -, algo toggle)
                HStack(spacing: 6) {
                    // Add dot
                    Button(action: addDot) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.primaryText.opacity(0.7))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .disabled(dots.count >= 3)
                    .opacity(dots.count >= 3 ? 0.3 : 1)
                    
                    // Remove dot
                    Button(action: removeDot) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.primaryText.opacity(0.7))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .disabled(dots.count <= 1)
                    .opacity(dots.count <= 1 ? 0.3 : 1)
                    
                    // Toggle algorithm
                    Button(action: toggleAlgorithm) {
                        Image(systemName: harmony.iconName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignTokens.Colors.primaryText.opacity(0.7))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .help(harmony.rawValue)
                }
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let clampedPos = clampToRect(value.location, width: width, height: height, padding: 16)
                        handleDrag(at: clampedPos, center: center, size: CGSize(width: width, height: height))
                    }
                    .onEnded { _ in draggingDotID = nil }
            )
            .onAppear {
                padSize = width
                padCenter = center
                if !initialized {
                    initialized = true
                    initializeDots(center: center, size: CGSize(width: width, height: height))
                }
            }
            .onChange(of: geo.size) { newSize in
                let w = newSize.width
                let c = CGPoint(x: w / 2, y: padHeight / 2)
                padSize = w
                padCenter = c
                repositionDots(center: c, size: CGSize(width: w, height: padHeight))
            }
        }
        .frame(height: padHeight)
    }
    
    // MARK: - Preset Pager
    
    private var presetPager: some View {
        HStack(spacing: 4) {
            // Left arrow
            Button(action: { withAnimation { currentPage = max(0, currentPage - 1) } }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(currentPage == 0)
            .opacity(currentPage == 0 ? 0.3 : 1)
            
            // Swatches for current page
            HStack(spacing: 6) {
                if currentPage < zenPresetPages.count {
                    ForEach(Array(zenPresetPages[currentPage].enumerated()), id: \.offset) { _, preset in
                        let isSelected = isPresetMatch(preset)
                        
                        Circle()
                            .fill(presetSwatchFill(preset))
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2.5)
                            )
                            .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                            .scaleEffect(isSelected ? 1.05 : 1.0)
                            .onTapGesture { applyPreset(preset) }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            // Right arrow
            Button(action: { withAnimation { currentPage = min(zenPresetPages.count - 1, currentPage + 1) } }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignTokens.Colors.secondaryText)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(currentPage >= zenPresetPages.count - 1)
            .opacity(currentPage >= zenPresetPages.count - 1 ? 0.3 : 1)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Opacity Slider (wave decoration)
    
    private var opacitySlider: some View {
        HStack(spacing: 10) {
            // Wave slider for opacity
            ZenWaveSlider(value: $opacity)
                .frame(height: 32)
            
            // Texture rotary knob
            TextureRotaryKnob(value: $texture)
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Drag Handling
    
    private func handleDrag(at point: CGPoint, center: CGPoint, size: CGSize) {
        if draggingDotID == nil {
            let nearest = dots.min(by: { dist($0.position, point) < dist($1.position, point) })
            if let nearest = nearest, dist(nearest.position, point) < 35 {
                draggingDotID = nearest.id
            } else {
                draggingDotID = 0
            }
        }
        
        guard let dragID = draggingDotID, let idx = dots.firstIndex(where: { $0.id == dragID }) else { return }
        
        dots[idx].position = point
        dots[idx].colorHex = colorFromPosition(point, center: center, size: size)
        
        if dots[idx].isPrimary {
            colorHex = dots[idx].colorHex
            recalculateSecondaryDots(center: center, size: size)
        }
        
        syncOutput()
    }
    
    // MARK: - Dot Actions
    
    private func addDot() {
        guard dots.count < 3 else { return }
        // Switch to next harmony that has more dots
        let targetCount = dots.count + 1
        if let h = ColorHarmony.allCases.first(where: { $0.dotCount == targetCount }) {
            harmony = h
        }
        recalculateSecondaryDots(center: padCenter, size: CGSize(width: padSize, height: padHeight))
        syncOutput()
    }
    
    private func removeDot() {
        guard dots.count > 1 else { return }
        dots.removeLast()
        // Switch to harmony matching new count
        let count = dots.count
        if let h = ColorHarmony.allCases.first(where: { $0.dotCount == count }) {
            harmony = h
        } else {
            harmony = .single
        }
        syncOutput()
    }
    
    private func toggleAlgorithm() {
        harmony = harmony.next
        recalculateSecondaryDots(center: padCenter, size: CGSize(width: padSize, height: padHeight))
        syncOutput()
    }
    
    // MARK: - Preset Application
    
    private func applyPreset(_ preset: ThemePreset) {
        let colors = preset.colors
        colorHex = colors.first ?? "#5E9EFF"
        gradientColors = colors.count > 1 ? colors : []
        gradientAngle = -45
        
        if colors.count == 1 { harmony = .single }
        else if colors.count == 2 { harmony = .complementary }
        else { harmony = .analogous }
        
        // Build dots from preset colors and scale positions from Zen's 360-space to our pad
        let scaleX = padSize / zenPadRefSize
        let scaleY = padHeight / zenPadRefSize
        
        if colors.count == 1 {
            let pos = CGPoint(x: preset.position.x * scaleX, y: preset.position.y * scaleY)
            let clamped = clampToRect(pos, width: padSize, height: padHeight, padding: 16)
            dots = [WheelDot(id: 0, position: clamped, colorHex: colors[0])]
        } else {
            // Place primary at preset position, compute others via harmony
            let primaryPos = CGPoint(x: preset.position.x * scaleX, y: preset.position.y * scaleY)
            let clamped = clampToRect(primaryPos, width: padSize, height: padHeight, padding: 16)
            dots = [WheelDot(id: 0, position: clamped, colorHex: colors[0])]
            
            // Place secondary dots at positions that produce the given colors
            for (i, hex) in colors.dropFirst().enumerated() {
                let pos = positionFromColor(hex, center: padCenter, size: CGSize(width: padSize, height: padHeight))
                dots.append(WheelDot(id: i + 1, position: pos, colorHex: hex))
            }
        }
        
        syncOutput()
    }
    
    private func isPresetMatch(_ preset: ThemePreset) -> Bool {
        if preset.colors.count == 1 {
            return gradientColors.isEmpty && colorHex == preset.colors.first
        }
        return gradientColors == preset.colors
    }
    
    private func presetSwatchFill(_ preset: ThemePreset) -> AnyShapeStyle {
        let nsColors = preset.colors.compactMap { NSColor(hex: $0) }
        if nsColors.count <= 1 {
            return AnyShapeStyle(Color(nsColor: nsColors.first ?? .gray))
        }
        if nsColors.count == 3 {
            // Zen renders 3-dot presets as radial gradients overlay
            // Simplify to a 3-stop linear gradient
            return AnyShapeStyle(
                AngularGradient(
                    colors: nsColors.map { Color(nsColor: $0) } + [Color(nsColor: nsColors[0])],
                    center: .center
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(colors: nsColors.map { Color(nsColor: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
    
    // MARK: - Dot Initialization & Repositioning
    
    private func initializeDots(center: CGPoint, size: CGSize) {
        if gradientColors.count > 1 {
            dots = gradientColors.enumerated().map { i, hex in
                let pos = positionFromColor(hex, center: center, size: size)
                return WheelDot(id: i, position: pos, colorHex: hex)
            }
            switch gradientColors.count {
            case 2: harmony = .complementary
            case 3: harmony = .analogous
            default: harmony = .single
            }
        } else {
            let pos = positionFromColor(colorHex, center: center, size: size)
            dots = [WheelDot(id: 0, position: pos, colorHex: colorHex)]
            harmony = .single
        }
    }
    
    private func repositionDots(center: CGPoint, size: CGSize) {
        for i in dots.indices {
            dots[i].position = positionFromColor(dots[i].colorHex, center: center, size: size)
        }
    }
    
    private func recalculateSecondaryDots(center: CGPoint, size: CGSize) {
        guard let primary = dots.first(where: { $0.isPrimary }) else { return }
        let offsets = harmony.angleOffsets
        
        var newDots = [primary]
        
        let dx = primary.position.x - center.x
        let dy = primary.position.y - center.y
        let maxR = min(size.width, size.height) / 2 - 16
        let dist = min(sqrt(dx * dx + dy * dy), maxR)
        var baseAngle = atan2(dy, dx) * 180 / .pi
        if baseAngle < 0 { baseAngle += 360 }
        
        for (i, offset) in offsets.enumerated() {
            let newAngle = (baseAngle + offset).truncatingRemainder(dividingBy: 360)
            let rad = newAngle * .pi / 180
            let pos = CGPoint(x: center.x + dist * cos(rad), y: center.y + dist * sin(rad))
            let clamped = clampToRect(pos, width: size.width, height: size.height, padding: 16)
            let hex = colorFromPosition(clamped, center: center, size: size)
            newDots.append(WheelDot(id: i + 1, position: clamped, colorHex: hex))
        }
        
        dots = newDots
    }
    
    private func syncOutput() {
        if dots.count <= 1 {
            colorHex = dots.first?.colorHex ?? colorHex
            gradientColors = []
        } else {
            colorHex = dots.first?.colorHex ?? colorHex
            gradientColors = dots.map { $0.colorHex }
        }
    }
    
    // MARK: - Color ↔ Position (same math as Zen, adapted for rectangular pad)
    
    private func colorFromPosition(_ pos: CGPoint, center: CGPoint, size: CGSize) -> String {
        let dx = pos.x - center.x
        let dy = pos.y - center.y
        let maxRadius = min(size.width, size.height) / 2
        let distance = sqrt(dx * dx + dy * dy)
        
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }
        
        let normalizedDistance = min(distance / maxRadius, 1.0)
        let hue = angle / 360.0
        let saturation = 0.85 + normalizedDistance * 0.15
        let lightness = 0.15 + (1.0 - normalizedDistance) * 0.7
        let brightness = hslToBrightness(s: saturation, l: lightness)
        
        let nsColor = NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        return nsColor.hexString
    }
    
    private func positionFromColor(_ hex: String, center: CGPoint, size: CGSize) -> CGPoint {
        guard let nsColor = NSColor(hex: hex)?.usingColorSpace(.sRGB) else { return center }
        let h = nsColor.hueComponent
        let s = nsColor.saturationComponent
        let b = nsColor.brightnessComponent
        let lightness = b * (2.0 - s) / 2.0
        let normalizedDistance = max(0, min(1, 1.0 - (lightness - 0.15) / 0.7))
        let maxRadius = min(size.width, size.height) / 2
        let angle = h * 2 * .pi
        return CGPoint(
            x: center.x + maxRadius * normalizedDistance * cos(angle),
            y: center.y + maxRadius * normalizedDistance * sin(angle)
        )
    }
    
    private func hslToBrightness(s: Double, l: Double) -> Double {
        min(1, max(0, l + s * min(l, 1 - l)))
    }
    
    private func clampToRect(_ point: CGPoint, width: CGFloat, height: CGFloat, padding: CGFloat) -> CGPoint {
        CGPoint(
            x: max(padding, min(width - padding, point.x)),
            y: max(padding, min(height - padding, point.y))
        )
    }
    
    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y))
    }
}

// MARK: - Dot Grid Pattern Background

private struct DotGridPattern: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 6
            let dotRadius: CGFloat = 0.7
            let color = Color(nsColor: NSColor(white: 0.5, alpha: 0.15))
            
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(color))
                    x += spacing
                }
                y += spacing
            }
        }
    }
}

// MARK: - Wave Opacity Slider (Zen-style)

struct ZenWaveSlider: View {
    @Binding var value: Double
    
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            
            ZStack {
                // Wave path decoration
                WavePath(amplitude: 6, frequency: 12, width: width)
                    .stroke(Color(nsColor: NSColor(white: 0.5, alpha: 0.35)), lineWidth: 5)
                    .frame(height: height)
                
                // Active portion of wave
                WavePath(amplitude: 6, frequency: 12, width: width * CGFloat(value))
                    .stroke(Color(nsColor: NSColor(white: 0.4, alpha: 0.7)), lineWidth: 5)
                    .frame(height: height)
                
                // Thumb
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(nsColor: .labelColor))
                    .frame(width: 10, height: 24)
                    .position(x: width * CGFloat(value), y: height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        value = max(0, min(1, Double(drag.location.x / width)))
                    }
            )
        }
    }
}

private struct WavePath: Shape {
    let amplitude: CGFloat
    let frequency: CGFloat
    let width: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let step: CGFloat = 1
        
        path.move(to: CGPoint(x: 0, y: midY))
        var x: CGFloat = 0
        while x <= min(width, rect.width) {
            let y = midY + amplitude * sin(x / rect.width * frequency * .pi * 2)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        
        return path
    }
}

// MARK: - ZenSliderBar (kept for backward compat if needed)

struct ZenSliderBar: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var trackColors: [Color] = [.gray.opacity(0.3), .white]
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: trackColors, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                    .frame(width: 16, height: 16)
                    .offset(x: (geo.size.width - 16) * (value - range.lowerBound) / (range.upperBound - range.lowerBound))
            }
            .frame(height: 16)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let fraction = max(0, min(drag.location.x / geo.size.width, 1))
                        value = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
                    }
            )
        }
        .frame(height: 16)
    }
}

// MARK: - Texture Rotary Knob

struct TextureRotaryKnob: View {
    @Binding var value: Double  // 0...1
    
    @State private var isDragging = false
    private let notchCount = 16
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let outerR = size / 2
            let innerR = outerR * 0.55
            
            ZStack {
                // Outer ring with notch dots
                ForEach(0..<notchCount, id: \.self) { i in
                    let angle = Double(i) / Double(notchCount) * 2 * .pi - .pi / 2
                    let dotR = outerR * 0.88
                    let isActive = Double(i) / Double(notchCount) <= value
                    Circle()
                        .fill(isActive ? Color(nsColor: .labelColor).opacity(0.6) : Color(nsColor: .labelColor).opacity(0.15))
                        .frame(width: 4, height: 4)
                        .position(
                            x: center.x + dotR * cos(angle),
                            y: center.y + dotR * sin(angle)
                        )
                }
                
                // Inner knob circle
                Circle()
                    .fill(Color(nsColor: NSColor(white: 0.75, alpha: 1.0)))
                    .frame(width: innerR * 2, height: innerR * 2)
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .position(center)
                
                // Indicator line on the knob
                let indicatorAngle = value * 2 * .pi - .pi / 2
                let lineStart = CGPoint(x: center.x + innerR * 0.3 * cos(indicatorAngle),
                                        y: center.y + innerR * 0.3 * sin(indicatorAngle))
                let lineEnd = CGPoint(x: center.x + innerR * 0.8 * cos(indicatorAngle),
                                      y: center.y + innerR * 0.8 * sin(indicatorAngle))
                
                Path { path in
                    path.move(to: lineStart)
                    path.addLine(to: lineEnd)
                }
                .stroke(Color(nsColor: .labelColor).opacity(0.5), lineWidth: 2)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        isDragging = true
                        let dx = drag.location.x - center.x
                        let dy = drag.location.y - center.y
                        var angle = atan2(dy, dx) + .pi / 2
                        if angle < 0 { angle += 2 * .pi }
                        value = max(0, min(1, angle / (2 * .pi)))
                    }
                    .onEnded { _ in isDragging = false }
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Color Helper

private extension Color {
    init(hex: String) {
        if let nsColor = NSColor(hex: hex) {
            self.init(nsColor: nsColor)
        } else {
            self.init(.sRGB, red: 0.37, green: 0.62, blue: 1.0, opacity: 1.0)
        }
    }
}
