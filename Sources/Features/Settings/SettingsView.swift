import SwiftUI
import Combine
import AppKit

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var useCustomColor: Bool
    @State private var selectedColor: Color
    
    init(store: SettingsStore) {
        self.store = store
        _useCustomColor = State(initialValue: store.sidebarColorHex != nil)
        if let hex = store.sidebarColorHex, let nsColor = NSColor(hex: hex) {
            _selectedColor = State(initialValue: Color(nsColor: nsColor))
        } else {
            _selectedColor = State(initialValue: Color(.sRGB, red: 0.15, green: 0.15, blue: 0.18))
        }
    }
    
    var body: some View {
        Form {
            Section("Sidebar") {
                HStack {
                    Text("Width")
                    Slider(value: $store.sidebarWidth,
                           in: AppConstants.minSidebarWidth...AppConstants.maxSidebarWidth,
                           step: 10)
                    Text("\(Int(store.sidebarWidth))px")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
            
            Section("Preview") {
                Toggle("Enable Preview", isOn: $store.previewEnabled)
                
                if store.previewEnabled {
                    HStack {
                        Text("Preview Size")
                        Slider(value: $store.previewMaxWidth, in: 240...800, step: 40)
                        Text("\(Int(store.previewMaxWidth))px")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
            }
            
            Section("Trigger Mode") {
                Picker("Sidebar Trigger", selection: $store.triggerMode) {
                    Text("Hot Zone + Shortcut").tag(SidebarTriggerMode.hotZoneAndHotKey)
                    Text("Two-Finger Double-Tap (at cursor)").tag(SidebarTriggerMode.threeFingerTap)
                }
                .pickerStyle(.radioGroup)
                
                if store.triggerMode == .threeFingerTap {
                    HStack {
                        Text("Double-Tap Delay")
                        Slider(value: $store.doubleTapDelay, in: 0.10...0.50, step: 0.02)
                        Text("\(Int(store.doubleTapDelay * 1000))ms")
                            .monospacedDigit()
                            .frame(width: 50)
                    }
                }
            }
            
            Section("Hot Zone") {
                Toggle("Enable Hot Zone", isOn: $store.hotZoneEnabled)
                    .disabled(store.triggerMode != .hotZoneAndHotKey)
                
                HStack {
                    Text("Trigger Delay")
                    Slider(value: $store.hotZoneDelay, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(store.hotZoneDelay * 1000))ms")
                        .monospacedDigit()
                        .frame(width: 50)
                }
                
                HStack {
                    Text("Hot Zone Width")
                    Slider(value: $store.hotZoneWidth, in: 1...10, step: 1)
                    Text("\(Int(store.hotZoneWidth))px")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            }
            
            Section("General") {
                Toggle("Launch at Login", isOn: $store.launchAtLogin)
                
                Picker("Drop onto Fullscreen Space", selection: $store.fullscreenDropAction) {
                    Text("Show Toast").tag(FullscreenDropAction.toast)
                    Text("Exit Fullscreen & Move").tag(FullscreenDropAction.exitAndMove)
                }
                
                Picker("Scene Activation: Display Without Scene Space", selection: $store.sceneDisplayFallback) {
                    Text("Stay Put").tag(SceneDisplayFallback.stayPut)
                    Text("Switch to First Non-Fullscreen").tag(SceneDisplayFallback.firstNonFullscreen)
                }
            }
            
            Section("Sidebar Appearance") {
                Picker("Blur Style", selection: $store.sidebarBlurMaterial) {
                    ForEach(SidebarBlurMaterial.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle("Custom Tint Color", isOn: $useCustomColor)
                    .onChange(of: useCustomColor) { newValue in
                        if newValue {
                            let nsColor = NSColor(selectedColor)
                            store.sidebarColorHex = nsColor.hexString
                        } else {
                            store.sidebarColorHex = nil
                        }
                    }
                
                if useCustomColor {
                    ColorPicker("Tint Color", selection: $selectedColor, supportsOpacity: false)
                        .onChange(of: selectedColor) { newValue in
                            let nsColor = NSColor(newValue)
                            store.sidebarColorHex = nsColor.hexString
                        }
                }
                
                HStack {
                    Text("Tint Opacity")
                    Slider(value: $store.sidebarOpacity, in: 0.0...1.0, step: 0.05)
                    Text("\(Int(store.sidebarOpacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 40)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 600)
        .onReceive(store.objectWillChange.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
            store.save()
        }
    }
}
