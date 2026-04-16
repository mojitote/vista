import Foundation

// #region debug-point utility
/// 轻量级调试日志上报工具，将事件发送到 Debug Server
enum DebugReport {
    private static let serverURL = URL(string: "http://127.0.0.1:7778/event")!
    private static let sessionId = "hover-delay"
    private static let session = URLSession(configuration: {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        return config
    }())
    
    static func send(hypothesisId: String, location: String, msg: String, data: [String: Any] = [:]) {
        let payload: [String: Any] = [
            "sessionId": sessionId,
            "runId": "pre",
            "hypothesisId": hypothesisId,
            "location": location,
            "msg": msg,
            "data": data,
            "ts": Int(Date().timeIntervalSince1970 * 1000)
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: serverURL)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        session.dataTask(with: request) { _, _, _ in }.resume()
    }
}
// #endregion
