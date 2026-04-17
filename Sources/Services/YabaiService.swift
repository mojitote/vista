import Foundation

enum YabaiError: Error, LocalizedError {
    case socketNotFound
    case connectionFailed
    case timeout
    case commandFailed(String)
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .socketNotFound:
            return "yabai socket not found. Is yabai running?"
        case .connectionFailed:
            return "Failed to connect to yabai socket"
        case .timeout:
            return "yabai command timed out"
        case .commandFailed(let message):
            return "yabai command failed: \(message)"
        case .decodingFailed:
            return "Failed to decode yabai response"
        }
    }
}

class YabaiService {
    static let shared = YabaiService()
    
    private var socketPath: String {
        let user = ProcessInfo.processInfo.environment["USER"] ?? "unknown"
        return "/tmp/yabai_\(user).socket"
    }
    
    // MARK: - Low-level Socket Communication
    
    private func sendMessage(args: [String]) throws -> Data {
        // Build message body: each arg null-terminated, plus trailing null
        var body = Data()
        for arg in args {
            body.append(contentsOf: arg.utf8)
            body.append(0) // null terminator
        }
        body.append(0) // extra trailing null
        
        // Build full message: 4-byte little-endian int length + body
        var length = Int32(body.count)
        let lengthData = Data(bytes: &length, count: 4)
        
        // Create socket
        let sockfd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard sockfd >= 0 else {
            throw YabaiError.connectionFailed
        }
        defer { close(sockfd) }
        
        // Set timeout
        var timeout = timeval(tv_sec: Int(AppConstants.commandTimeout), tv_usec: 0)
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        // Connect
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        
        let path = socketPath
        guard FileManager.default.fileExists(atPath: path) else {
            throw YabaiError.socketNotFound
        }
        
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            path.withCString { cstr in
                _ = strcpy(UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: CChar.self), cstr)
            }
        }
        
        let connectResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                connect(sockfd, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        
        guard connectResult == 0 else {
            throw YabaiError.connectionFailed
        }
        
        // Send message
        let fullMessage = lengthData + body
        let sent = fullMessage.withUnsafeBytes { bufPtr in
            send(sockfd, bufPtr.baseAddress!, fullMessage.count, 0)
        }
        guard sent == fullMessage.count else {
            throw YabaiError.connectionFailed
        }
        
        // Signal end of writing
        shutdown(sockfd, SHUT_WR)
        
        // Read response
        var responseData = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let bytesRead = read(sockfd, &buffer, buffer.count)
            if bytesRead <= 0 { break }
            responseData.append(contentsOf: buffer[0..<bytesRead])
        }
        
        // Check for failure (first byte = 0x07)
        if let firstByte = responseData.first, firstByte == 0x07 {
            let errorMessage = String(data: responseData.dropFirst(), encoding: .utf8) ?? "Unknown error"
            throw YabaiError.commandFailed(errorMessage)
        }
        
        return responseData
    }
    
    // MARK: - Query Methods
    
    func queryDisplays() throws -> [YabaiDisplay] {
        let data = try sendMessage(args: ["query", "--displays"])
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([YabaiDisplay].self, from: data)
        } catch {
            throw YabaiError.decodingFailed
        }
    }
    
    func querySpaces() throws -> [YabaiSpace] {
        let data = try sendMessage(args: ["query", "--spaces"])
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([YabaiSpace].self, from: data)
        } catch {
            throw YabaiError.decodingFailed
        }
    }
    
    func queryWindows() throws -> [YabaiWindow] {
        let data = try sendMessage(args: ["query", "--windows"])
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([YabaiWindow].self, from: data)
        } catch {
            throw YabaiError.decodingFailed
        }
    }
    
    // MARK: - Action Methods
    
    func focusSpace(index: Int) throws {
        _ = try sendMessage(args: ["space", "--focus", "\(index)"])
    }
    
    func focusWindow(id: Int) throws {
        // 先尝试取消最小化（对非最小化窗口无害）
        _ = try? sendMessage(args: ["window", "\(id)", "--deminimize", "\(id)"])
        _ = try sendMessage(args: ["window", "--focus", "\(id)"])
    }
    
    func moveWindowToSpace(windowID: Int, spaceIndex: Int) throws {
        _ = try sendMessage(args: ["window", "\(windowID)", "--space", "\(spaceIndex)"])
    }
    
    func closeWindow(id: Int) throws {
        _ = try sendMessage(args: ["window", "\(id)", "--close"])
    }
    
    func destroySpace(index: Int) throws {
        _ = try sendMessage(args: ["space", "\(index)", "--destroy"])
    }
    
    func moveSpaceToDisplay(spaceIndex: Int, displayIndex: Int) throws {
        _ = try sendMessage(args: ["space", "\(spaceIndex)", "--display", "\(displayIndex)"])
    }
    
    func toggleNativeFullscreen(windowID: Int) throws {
        _ = try sendMessage(args: ["window", "\(windowID)", "--toggle", "native-fullscreen"])
    }
    
    // MARK: - Convenience
    
    /// 取消目标 Space 的原生全屏（若 Space 内有全屏窗口，则 toggle 其全屏）。
    /// 返回 true 表示发出了 toggle，false 表示没找到可操作窗口。
    @discardableResult
    func exitNativeFullscreen(onSpaceIndex spaceIndex: Int) throws -> Bool {
        let windows = try queryWindows()
        // yabai 在全屏 Space 里通常只有一个窗口，这里宽松地 toggle 第一个匹配
        guard let fullscreenWindow = windows.first(where: { $0.space == spaceIndex }) else {
            return false
        }
        try toggleNativeFullscreen(windowID: fullscreenWindow.id)
        return true
    }
    
    // MARK: - Connection Check
    
    var isYabaiRunning: Bool {
        return FileManager.default.fileExists(atPath: socketPath)
    }
}
