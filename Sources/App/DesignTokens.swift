import SwiftUI
import AppKit

// MARK: - Zen-inspired Design Tokens for Vista

enum DesignTokens {
    
    // MARK: - Colors
    
    enum Colors {
        // Background colors (light-dark adaptive)
        static let sidebarBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.106, green: 0.106, blue: 0.106, alpha: 1.0)   // #1b1b1b
                : NSColor(red: 0.922, green: 0.922, blue: 0.922, alpha: 1.0)   // #ebebeb
        })
        
        // Hover background
        static let hoverBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.07)
                : NSColor(white: 0.0, alpha: 0.05)
        })
        
        // Active/selected background
        static let activeBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.12)
                : NSColor(white: 0.0, alpha: 0.06)
        })
        
        // Drop target background
        static let dropTargetBackground = Color.accentColor.opacity(0.12)
        
        // Section header text
        static let sectionHeader = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.4)
                : NSColor(white: 0.0, alpha: 0.4)
        })
        
        // Primary text
        static let primaryText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.9)
                : NSColor(white: 0.0, alpha: 0.85)
        })
        
        // Secondary text
        static let secondaryText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.5)
                : NSColor(white: 0.0, alpha: 0.45)
        })
        
        // Subtle text (window count, etc.)
        static let subtleText = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.3)
                : NSColor(white: 0.0, alpha: 0.3)
        })
        
        // Separator / divider
        static let separator = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.08)
                : NSColor(white: 0.0, alpha: 0.08)
        })
        
        // Active indicator bar
        static let activeIndicator = Color.accentColor
        
        // Visible dot
        static let visibleDot = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.35, green: 0.78, blue: 0.48, alpha: 1.0)
                : NSColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0)
        })
        
        // Fullscreen badge
        static let fullscreenBadge = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.7)
                : NSColor(red: 0.85, green: 0.55, blue: 0.1, alpha: 0.7)
        })
        
        // Close button hover
        static let closeButtonHover = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(white: 1.0, alpha: 0.12)
                : NSColor(white: 0.0, alpha: 0.08)
        })
        
        // Toast background
        static let toastBackground = Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.95)
                : NSColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 0.9)
        })
        
        // Scene active background
        static let sceneActiveBackground = Color.accentColor.opacity(0.1)
    }
    
    // MARK: - Border Radius (Zen: 7px base, macOS: 8px tabs)
    
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
    
    // MARK: - Animation (Zen: 0.1-0.2s)
    
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
