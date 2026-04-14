import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    
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
            }
            
            Section("General") {
                Toggle("Launch at Login", isOn: $store.launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 300)
        .onReceive(store.objectWillChange.debounce(for: .milliseconds(500), scheduler: RunLoop.main)) { _ in
            store.save()
        }
    }
}
