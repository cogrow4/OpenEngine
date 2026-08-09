import Foundation

public enum OE_Storage {
    public static let appGroup = "com.openengine.OpenEngine"
    public static let bundleID = "com.openengine.OpenEngine"

    public static var libraryDir: URL {
        let app = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = app.appending(path: "OpenEngine", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    public static var settings: URL { libraryDir.appending(path: "settings.json") }
    public static var wallpaperStore: URL { libraryDir.appending(path: "wallpapers", directoryHint: .isDirectory) }
}
