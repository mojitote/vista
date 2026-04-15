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
                
                Toggle("Show Thumbnails", isOn: $store.showThumbnails)
            }
            
            Section("Hot Zone") {
                Toggle("Enable Hot Zone", isOn: $store.hotZoneEnabled)
                
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
            }
            
            Section("Sidebar Appearance") {
                Toggle("Custom Background Color", isOn: $useCustomColor)
                    .onChange(of: useCustomColor) { newValue in
                        if newValue {
                            let nsColor = NSColor(selectedColor)
                            store.sidebarColorHex = nsColor.hexString
                        } else {
                            store.sidebarColorHex = nil
                        }
                    }
                
                if useCustomColor {
                    ColorPicker("Background Color", selection: $selectedColor, supportsOpacity: false)
                        .onChange(of: selectedColor) { newValue in
                            let nsColor = NSColor(newValue)
                            store.sidebarColorHex = nsColor.hexString
                        }
                    
                    HStack {
                        Text("Opacity")
                        Slider(value: $store.sidebarOpacity, in: 0.3...1.0, step: 0.05)
                        Text("\(Int(store.sidebarOpacity * 100))%")
                            .monospacedDigit()
                            .frame(width: 40)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 450)
        .onReceive(store.objectWillChange.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
            store.save()
        }
    }
}
