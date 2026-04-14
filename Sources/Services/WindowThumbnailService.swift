import Cocoa
import CoreGraphics

class WindowThumbnailService {
    
    static let shared = WindowThumbnailService()
    
    /// Capture a thumbnail of a specific window
    /// - Parameters:
    ///   - windowID: The CGWindowID of the window to capture
    ///   - size: Target size for the thumbnail (default 96x64)
    /// - Returns: NSImage thumbnail, or nil if capture failed (e.g., minimized window)
    func captureThumbnail(windowID: CGWindowID, size: NSSize = NSSize(width: AppConstants.largeThumbnailWidth, height: AppConstants.largeThumbnailHeight)) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else {
            return nil
        }
        
        let originalSize = NSSize(width: cgImage.width, height: cgImage.height)
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        
        // Calculate aspect-fit size
        let aspectRatio = originalSize.width / originalSize.height
        let targetRatio = size.width / size.height
        
        var drawSize: NSSize
        if aspectRatio > targetRatio {
            drawSize = NSSize(width: size.width, height: size.width / aspectRatio)
        } else {
            drawSize = NSSize(width: size.height * aspectRatio, height: size.height)
        }
        
        // Create scaled image
        let image = NSImage(size: size)
        image.lockFocus()
        
        let drawRect = NSRect(
            x: (size.width - drawSize.width) / 2,
            y: (size.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        
        let nsImage = NSImage(cgImage: cgImage, size: originalSize)
        nsImage.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
        
        image.unlockFocus()
        return image
    }
    
    /// Capture thumbnails for multiple windows at once
    /// - Parameter windowIDs: Array of window IDs to capture
    /// - Returns: Dictionary mapping window ID to its thumbnail
    func captureAll(windowIDs: [CGWindowID]) -> [CGWindowID: NSImage] {
        var result: [CGWindowID: NSImage] = [:]
        for id in windowIDs {
            if let thumbnail = captureThumbnail(windowID: id) {
                result[id] = thumbnail
            }
        }
        return result
    }
}
