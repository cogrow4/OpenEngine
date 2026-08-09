import SwiftUI
import UniformTypeIdentifiers
import WallpaperKit

public struct SettingsView: View {
    @EnvironmentObject var engine: OEEngine
    @State private var launchAgentInstalled = false
    @State private var importing: ImportTarget? = nil

    enum ImportTarget: Identifiable {
        case wallpaper, lockScreen
        var id: Int { self == .wallpaper ? 0 : 1 }
    }

    public init() {}

    public var body: some View {
        Form {
            Section {
                Picker("Behavior", selection: $engine.settings.linkage) {
                    ForEach(OESettings.Linkage.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Toggle("Launch OpenEngine at login", isOn: $engine.settings.launchAtLogin)
                    .onChange(of: engine.settings.launchAtLogin) { _, v in updateLaunchAgent(enable: v) }
                Toggle("Start minimized to menu bar", isOn: $engine.settings.startMinimized)
                Picker("On startup", selection: $engine.settings.startupBehavior) {
                    ForEach(OESettings.Startup.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            } header: { Text("General") }

            Section {
                HStack {
                    Text("Wallpaper").foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                    Text(engine.settings.wallpaperID ?? "None selected").lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Choose File") { importing = .wallpaper }
                }
                HStack {
                    Text("Lock screen").foregroundStyle(.secondary).frame(width: 100, alignment: .leading)
                    Text(engine.settings.lockID ?? "None selected").lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Choose File") { importing = .lockScreen }
                }
                Button("Restore last selection now") { engine.restoreOnLaunch() }
            } header: { Text("Current background") }

            Section {
                HStack {
                    Text("Pause video below")
                    Stepper(value: $engine.settings.pauseOnBatteryBelow, in: 0...100, step: 5) {
                        Text("\(engine.settings.pauseOnBatteryBelow)% battery")
                    }
                }
            } header: { Text("Battery") }

            Section {
                LabeledContent("Manifest URL") {
                    Text(engine.store.manifestURL.absoluteString)
                        .foregroundStyle(.secondary).truncationMode(.middle).textSelection(.enabled)
                }
                LabeledContent("Cache location") {
                    Text(engine.store.cacheRoot.path)
                        .foregroundStyle(.secondary).truncationMode(.middle).textSelection(.enabled)
                }
            } header: { Text("Library") }

            Section {
                LabeledContent("Version", value: "\(WallpaperKit.version)")
                LabeledContent("License", value: "MIT")
                LabeledContent("Source", value: "github.com/cogrow4/OpenEngine")
            } header: { Text("About") }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .fileImporter(isPresented: Binding(
            get: { importing != nil }, set: { if !$0 { importing = nil } }),
            allowedContentTypes: [.jpeg, .png, .mpeg4Movie, .quickTimeMovie, .image, .audiovisualContent]
        ) { result in
            switch result {
            case .success(let url):
                guard url.startAccessingSecurityScopedResource() else { return }
                defer { url.stopAccessingSecurityScopedResource() }
                if let t = importing {
                    engine.setLocalFile(url, scope: t == .wallpaper ? .wallpaper : .lockScreen)
                }
            case .failure: break
            }
        }
        .padding()
    }

    private func updateLaunchAgent(enable: Bool) {
        LaunchAgentManager.shared.setEnabled(enable)
        launchAgentInstalled = enable
        engine.settings.save()
    }
}
