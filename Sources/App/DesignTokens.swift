import SwiftUI
import AppKit

// MARK: - Zen-inspired Design Tokens for Vista

enum DesignTokens {
    
    // MARK: - Colors
    
    enum Colors {
        
        // ── Surface (背景层) ──
        
        /// 侧边栏主背景 — 对应 zen: --zen-main-browser-background
        static let sidebarBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1.0)   // #1b1b1b
                : NSColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1.0)   // #ebebeb
        })
        
        /// 悬停背景 — 对应 zen: --zen-colors-hover-bg
        static let hoverBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.07)
                : NSColor(white: 0.0, alpha: 0.05)
        })
        
        /// 选中/激活背景 — 对应 zen: --zen-colors-secondary
        static let activeBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.12)
                : NSColor(white: 0.0, alpha: 0.06)
        })
        
        /// 微弱背景（替代 Color.primary.opacity(0.05)）
        static let subtleBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.05)
                : NSColor(white: 0.0, alpha: 0.05)
        })
        
        /// 拖放目标背景
        static let dropTargetBackground = Color.accentColor.opacity(0.12)
        
        /// Scene 激活态背景
        static let sceneActiveBackground = Color.accentColor.opacity(0.1)
        
        // ── Text (文字层) ──
        
        /// 主文字 — 对应 zen: --zen-colors-primary-foreground
        static let primaryText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.9)
                : NSColor(white: 0.0, alpha: 0.85)
        })
        
        /// 次要文字 — 替代所有 .secondary 用法
        static let secondaryText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.5)
                : NSColor(white: 0.0, alpha: 0.45)
        })
        
        /// 微弱文字（窗口计数等）
        static let subtleText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.3)
                : NSColor(white: 0.0, alpha: 0.3)
        })
        
        /// 分区标题
        static let sectionHeader = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.4)
                : NSColor(white: 0.0, alpha: 0.4)
        })
        
        /// 深色表面上的固定白色文字（toast 等恒深色背景）
        static let onDarkSurface = Color.white
        
        // ── Semantic / Status (语义状态) ──
        
        /// 成功 — 自适应绿色
        static let success = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.35, green: 0.78, blue: 0.48, alpha: 1.0)
                : NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0)
        })
        
        /// 警告 — 自适应橙色
        static let warning = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1.0)
                : NSColor(red: 0.85, green: 0.55, blue: 0.1, alpha: 1.0)
        })
        
        /// 错误 — 自适应红色
        static let error = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.95, green: 0.35, blue: 0.35, alpha: 1.0)
                : NSColor(red: 0.82, green: 0.2, blue: 0.2, alpha: 1.0)
        })
        
        /// 链接/信息 — 自适应蓝色
        static let link = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
                : NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1.0)
        })
        
        /// 链接淡底背景
        static let linkBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.15)
                : NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 0.12)
        })
        
        // ── Component (组件专用) ──
        
        /// 分隔线
        static let separator = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.08)
        })
        
        /// 激活指示条 — 系统强调色
        static let activeIndicator = Color.accentColor
        
        /// 可见性指示点 — 绿色
        static let visibleDot = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.35, green: 0.78, blue: 0.48, alpha: 1.0)
                : NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0)
        })
        
        /// 全屏标记 — 橙色
        static let fullscreenBadge = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.7)
                : NSColor(red: 0.85, green: 0.55, blue: 0.1, alpha: 0.7)
        })
        
        /// 关闭按钮悬停
        static let closeButtonHover = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.12)
                : NSColor(white: 0.0, alpha: 0.08)
        })
        
        /// Toast 背景
        static let toastBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.95)
                : NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.9)
        })
    }
    
    // MARK: - Gradient Presets (参考 Zen Browser theme-picker)
    
    enum GradientPresets {
        
        /// 单个预设渐变
        struct Preset: Identifiable {
            let id = UUID()
            let name: String
            let colors: [String]  // hex 颜色数组
            let angle: Double     // 渐变角度（度）
        }
        
        /// 浅色系 — 参考 Zen 第 1/2 页
        static let light: [Preset] = [
            Preset(name: "Cream",    colors: ["#f4efdf"],                     angle: -45),
            Preset(name: "Rose",     colors: ["#f0b8cd"],                     angle: -45),
            Preset(name: "Lavender", colors: ["#e9c3e3"],                     angle: -45),
            Preset(name: "Coral",    colors: ["#da7682"],                     angle: -45),
            Preset(name: "Peach",    colors: ["#eb8570"],                     angle: -45),
            Preset(name: "Gold",     colors: ["#dcce7f"],                     angle: -45),
            Preset(name: "Mint",     colors: ["#5becad"],                     angle: -45),
            Preset(name: "Slate",    colors: ["#919bb5"],                     angle: -45),
            // 浅色三色渐变
            Preset(name: "Meadow",   colors: ["#f5edd6", "#ddf3d8", "#f3d8e1"], angle: -45),
            Preset(name: "Blossom",  colors: ["#f3bede", "#f7deba", "#dfC3ee"], angle: -45),
            Preset(name: "Orchid",   colors: ["#e5b3e4", "#ecacb2", "#c3b9df"], angle: -45),
            Preset(name: "Sunset",   colors: ["#eb7a9f", "#efef76", "#d285e0"], angle: -45),
        ]
        
        /// 深色系 — 参考 Zen 第 3/4 页
        static let dark: [Preset] = [
            Preset(name: "Dusk",     colors: ["#5d566a"],                     angle: -45),
            Preset(name: "Mauve",    colors: ["#997096"],                     angle: -45),
            Preset(name: "Wine",     colors: ["#956066"],                     angle: -45),
            Preset(name: "Sienna",   colors: ["#9c6645"],                     angle: -45),
            Preset(name: "Forest",   colors: ["#517b6c"],                     angle: -45),
            Preset(name: "Ocean",    colors: ["#576e75"],                     angle: -45),
            Preset(name: "Cocoa",    colors: ["#836d5f"],                     angle: -45),
            Preset(name: "Pine",     colors: ["#447464"],                     angle: -45),
            // 深色三色渐变
            Preset(name: "Nebula",   colors: ["#171122", "#250e23", "#121621"], angle: -45),
            Preset(name: "Berry",    colors: ["#804c7c", "#8d3f42", "#575874"], angle: -45),
            Preset(name: "Ember",    colors: ["#7a3840", "#7e7934", "#6f446e"], angle: -45),
            Preset(name: "Canopy",   colors: ["#2d6c55", "#345565", "#347623"], angle: -45),
        ]
        
        /// 黑白灰阶 — 参考 Zen 第 5 页
        static let neutral: [Preset] = [
            Preset(name: "White",    colors: ["#e0e0e0"], angle: -45),
            Preset(name: "Silver",   colors: ["#c0c0c0"], angle: -45),
            Preset(name: "Gray",     colors: ["#a0a0a0"], angle: -45),
            Preset(name: "Pewter",   colors: ["#808080"], angle: -45),
            Preset(name: "Graphite", colors: ["#606060"], angle: -45),
            Preset(name: "Charcoal", colors: ["#404040"], angle: -45),
            Preset(name: "Onyx",     colors: ["#202020"], angle: -45),
            Preset(name: "Black",    colors: ["#000000"], angle: -45),
        ]
        
        static let all: [Preset] = light + dark + neutral
    }
    
    // MARK: - Border Radius
    
    enum Radius {
        static let small: CGFloat = 5      // buttons, close button
        static let medium: CGFloat = 8     // rows, cards
        static let large: CGFloat = 10     // panels, toast
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
    }
    
    // MARK: - Font
    
    enum Font {
        static let titleSize: CGFloat = 13
        static let titleWeight: SwiftUI.Font.Weight = .semibold
        
        static let bodySize: CGFloat = 12
        static let bodyWeight: SwiftUI.Font.Weight = .regular
        
        static let captionSize: CGFloat = 10
        
        static let sectionHeaderSize: CGFloat = 10
        static let sectionHeaderWeight: SwiftUI.Font.Weight = .semibold
        
        static let badgeSize: CGFloat = 9
    }
    
    // MARK: - Animation
    
    enum Anim {
        static let fast = SwiftUI.Animation.easeInOut(duration: 0.12)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.2)
    }
    
    // MARK: - Shadow
    
    enum Shadow {
        static let toast = SwiftUI.Color.black.opacity(0.25)
        static let toastRadius: CGFloat = 12
    }
}
