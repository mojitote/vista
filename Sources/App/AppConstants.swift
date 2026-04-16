import Foundation

enum AppConstants {
    static let defaultSidebarWidth: CGFloat = 280
    static let minSidebarWidth: CGFloat = 200
    static let maxSidebarWidth: CGFloat = 400
    static let popupMinHeight: CGFloat = 160
    static let popupHeaderHeight: CGFloat = 53
    static let popupSectionTopBottomPadding: CGFloat = 16
    static let popupDisplayHeaderHeight: CGFloat = 28
    static let popupSpaceRowHeight: CGFloat = 28
    static let popupWindowRowHeight: CGFloat = 28
    static let popupSectionDividerHeight: CGFloat = 9
    static let popupSceneHeaderHeight: CGFloat = 34
    static let popupSceneRowHeight: CGFloat = 24
    static let popupEmptySceneHeight: CGFloat = 28
    static let hotZoneDelay: TimeInterval = 0.2  // 200ms
    static let hotZoneWidth: CGFloat = 2  // 默认热区宽度（像素）
    static let pollingInterval: TimeInterval = 3.0  // 3s
    static let animationDuration: TimeInterval = 0.15  // 150ms
    static let mouseOutDelay: TimeInterval = 0.3  // 300ms
    static let commandTimeout: TimeInterval = 2.0  // 2s
    static let appIconSize: CGFloat = 16
    static let activeIndicatorWidth: CGFloat = 3
    static let appName = "Vista"
    static let settingsDirectoryName = "Vista"
    static let settingsFileName = "settings.json"
}
