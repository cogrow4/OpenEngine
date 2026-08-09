import Foundation
import ServiceManagement

/// Installs/removes a LaunchAgent that starts OpenEngine at login (background-friendly).
public final class LaunchAgentManager {
    public static let shared = LaunchAgentManager()
    private let label = "com.openengine.OpenEngine"
    private var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents", directoryHint: .isDirectory)
            .appending(path: "\(label).plist", directoryHint: .notDirectory)
    }

    public func setEnabled(_ enable: Bool) {
        do {
            if enable { try install() } else { try? uninstall() }
        } catch { /* swallow; legacy path still attempted */ }
        if #available(macOS 13.0, *) {
            let svc = SMAppService.mainApp
            if enable { try? svc.register() } else { try? svc.unregister() }
        }
    }

    public var isEnabled: Bool { FileManager.default.fileExists(atPath: url.path) }

    private func install() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let exec = CommandLine.arguments.first ?? "/Applications/OpenEngine.app/Contents/MacOS/OpenEngine"
        let dict: [String: Any] = [
            "Label": label,
            "ProgramArguments": [exec, "--launchAgent"],
            "RunAtLoad": true,
            "KeepAlive": false,
            "LaunchOnlyOnce": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }
    private func uninstall() throws {
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}
