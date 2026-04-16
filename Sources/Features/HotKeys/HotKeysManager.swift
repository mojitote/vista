import Cocoa
import HotKey
import Carbon

class HotKeysManager {
    
    private var sidebarHotKey: HotKey?
    private var sceneHotKeys: [UUID: HotKey] = [:]
    var onToggleSidebar: (() -> Void)?
    var onGotoScene: ((VistaScene) -> Void)?
    
    func updateSidebarHotKey(keyCombo: KeyCombo?) {
        sidebarHotKey = nil
        
        guard let keyCombo = keyCombo else { return }
        
        let hotKey = HotKey(keyCombo: keyCombo)
        hotKey.keyDownHandler = { [weak self] in
            self?.onToggleSidebar?()
        }
        sidebarHotKey = hotKey
    }
    
    func updateSceneHotKeys(scenes: [VistaScene]) {
        sceneHotKeys.removeAll()
        
        for scene in scenes {
            guard let keyCode = scene.hotkeyKeyCode,
                  let modifiers = scene.hotkeyModifiers else { continue }
            
            guard let key = Key(carbonKeyCode: keyCode) else { continue }
            let mods = NSEvent.ModifierFlags(carbonFlags: modifiers)
            let keyCombo = KeyCombo(key: key, modifiers: mods)
            let hotKey = HotKey(keyCombo: keyCombo)
            let capturedScene = scene
            hotKey.keyDownHandler = { [weak self] in
                self?.onGotoScene?(capturedScene)
            }
            sceneHotKeys[scene.id] = hotKey
        }
    }
    
    func clearAll() {
        sidebarHotKey = nil
        sceneHotKeys.removeAll()
    }
    
    deinit {
        clearAll()
    }
}
