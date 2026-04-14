import Cocoa
import HotKey
import Carbon

class HotKeysManager {
    
    private var sidebarHotKey: HotKey?
    var onToggleSidebar: (() -> Void)?
    
    func updateSidebarHotKey(keyCombo: KeyCombo?) {
        sidebarHotKey = nil
        
        guard let keyCombo = keyCombo else { return }
        
        let hotKey = HotKey(keyCombo: keyCombo)
        hotKey.keyDownHandler = { [weak self] in
            self?.onToggleSidebar?()
        }
        sidebarHotKey = hotKey
    }
    
    func clearAll() {
        sidebarHotKey = nil
    }
    
    deinit {
        clearAll()
    }
}
