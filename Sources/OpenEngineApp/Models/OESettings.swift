import Foundation

public struct OESettings: Codable, Sendable {
    public enum Linkage: String, Codable, Sendable, CaseIterable {
        case separate = "Separate"
        case same = "Same"
        case lockOnly = "Lock Only"
        case wallpaperOnly = "Wallpaper Only"
    }
    public enum Startup: String, Codable, Sendable, CaseIterable {
        case none = "Do Nothing"
        case restore = "Restore Last"
    }
    public enum NavigationMode: String, Codable, Sendable {
        case visible, hidden
    }

    public var wallpaperID: String?
    public var lockID: String?
    public var lastWallpaperURL: String?
    public var lastLockURL: String?
    public var launchAtLogin: Bool = true
    public var startMinimized: Bool = true
    public var startupBehavior: Startup = .restore
    public var linkage: Linkage = .separate
    public var pauseOnBatteryBelow: Int = 20
    public var titleBarVisibility: NavigationMode = .visible

    public init() {}
    public static var `default`: OESettings { OESettings() }

    public static func load() -> OESettings {
        do {
            let data = try Data(contentsOf: OE_Storage.settings)
            return try JSONDecoder().decode(OESettings.self, from: data)
        } catch { return .default }
    }
    public func save() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        do { try enc.encode(self).write(to: OE_Storage.settings, options: .atomic) } catch {}
    }
}
