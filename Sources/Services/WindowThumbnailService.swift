import Cocoa
import CoreGraphics

class WindowThumbnailService {
    
    static let shared = WindowThumbnailService()
    
    /// 按需截取单个窗口的预览图
    func captureThumbnail(windowID: CGWindowID, size: NSSize = NSSize(width: 480, height: 300)) -> NSImage? {
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
        
        let aspectRatio = originalSize.width / originalSize.height
        let targetRatio = size.width / size.height
        
        var drawSize: NSSize
        if aspectRatio > targetRatio {
            drawSize = NSSize(width: size.width, height: size.width / aspectRatio)
        } else {
            drawSize = NSSize(width: size.height * aspectRatio, height: size.height)
        }
        
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
}
