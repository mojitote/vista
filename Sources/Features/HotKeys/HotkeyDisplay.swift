import AppKit

/// 快捷键显示相关辅助：Carbon keyCode → 可读字符串、modifier → Unicode 符号。
enum HotkeyDisplay {
    
    private static let keyMap: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
        46: "M", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\", 43: ",", 44: "/", 47: ".",
        48: "Tab", 49: "Space", 50: "`", 51: "Del", 53: "Esc",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15",
        118: "F4", 120: "F2", 122: "F1",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        36: "↩", 76: "⌤"
    ]
    
    static func keyName(_ keyCode: UInt32) -> String {
        keyMap[keyCode] ?? "Key\(keyCode)"
    }
    
    static func string(keyCode: UInt32, modifiers: UInt32) -> String {
        let mods = NSEvent.ModifierFlags(carbonFlags: modifiers)
        var parts: [String] = []
        if mods.contains(.control) { parts.append("⌃") }
        if mods.contains(.option) { parts.append("⌥") }
        if mods.contains(.shift) { parts.append("⇧") }
        if mods.contains(.command) { parts.append("⌘") }
        parts.append(keyName(keyCode))
        return parts.joined()
    }
}
