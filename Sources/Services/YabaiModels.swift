import Foundation
import AppKit

// MARK: - Frame
struct YabaiFrame: Codable, Equatable {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
}

// MARK: - Display
struct YabaiDisplay: Codable, Identifiable {
    let id: Int
    let uuid: String
    let index: Int
    let label: String
    let frame: YabaiFrame
    let spaces: [Int]
    let hasFocus: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, index, label, frame, spaces
        case hasFocus = "has-focus"
    }
}

// MARK: - Space
struct YabaiSpace: Codable, Identifiable {
    let id: Int64
    let uuid: String
    let index: Int
    let label: String
    let type: String
    let display: Int
    let windows: [Int]
    let firstWindow: Int
    let lastWindow: Int
    let hasFocus: Bool
    let isVisible: Bool
    let isNativeFullscreen: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, uuid, index, label, type, display, windows
        case firstWindow = "first-window"
        case lastWindow = "last-window"
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isNativeFullscreen = "is-native-fullscreen"
    }
}

// MARK: - Window
struct YabaiWindow: Codable, Identifiable {
    let id: Int
    let pid: Int
    let app: String
    let title: String
    let frame: YabaiFrame
    let display: Int
    let space: Int
    let hasFocus: Bool
    let isVisible: Bool
    let isMinimized: Bool
    let isHidden: Bool
    let isFloating: Bool
    let isSticky: Bool
    /// yabai 是否能通过 AX 引用操控此窗口。false 表示这是个「幽灵/僵尸窗口」
    /// （常见于 Firefox/Zen/Electron 后台维持的不可见窗口），无法 focus/close/move。
    let hasAXReference: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, pid, app, title, frame, display, space
        case hasFocus = "has-focus"
        case isVisible = "is-visible"
        case isMinimized = "is-minimized"
        case isHidden = "is-hidden"
        case isFloating = "is-floating"
        case isSticky = "is-sticky"
        case hasAXReference = "has-ax-reference"
    }
}
