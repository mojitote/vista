import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var useCustomColor: Bool
    
    init(store: SettingsStore) {
        self.store = store
        _useCustomColor = State(initialValue: store.sidebarColorHex != nil || !store.sidebarGradientColors.isEmpty)
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
            
            Section("Todo") {
                Toggle("Show Todo Bar", isOn: $store.showTodoBar)
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
                
                Toggle("Custom Color", isOn: $useCustomColor)
                    .onChange(of: useCustomColor) { newValue in
                        if !newValue {
                            store.sidebarColorHex = nil
                            store.sidebarGradientColors = []
                            store.sidebarColorMode = .solid
                        }
                    }
                
                if useCustomColor {
                    ZenColorPickerView(
                        colorHex: Binding(
                            get: { store.sidebarColorHex ?? "#2C2C2E" },
                            set: { store.sidebarColorHex = $0 }
                        ),
                        gradientColors: $store.sidebarGradientColors,
                        opacity: $store.sidebarOpacity,
                        gradientAngle: $store.sidebarGradientAngle,
                        texture: $store.sidebarGradientTexture
                    )
                    .onChange(of: store.sidebarGradientColors) { newColors in
                        store.sidebarColorMode = newColors.isEmpty ? .solid : .gradient
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 650)
        .onReceive(store.objectWillChange.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
            store.save()
        }
    }
    
}
