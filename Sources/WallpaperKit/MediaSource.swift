import Foundation

/// A content source for the desktop or lock screen.
///
/// Designed to be a value type: sources are compared by `id`, so Swift's
/// diffing and the controller's layer-swap path treat equal sources as "no change".
public struct MediaSource: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable, Hashable {
        case image
        case video
        case color  // decorative helper: solid gradient/color
    }

    public enum Origin: String, Sendable, Hashable {
        case builtin   // from the curated online library
        case user      // user-picked file on disk
        case solidColor
    }

    /// Stable identifier used for dedup, cache keys, and equality.
    public let id: String
    public let kind: Kind
    public let origin: Origin
    /// Local file URL for the currently playable/usable asset. Nil until downloaded.
    public var localURL: URL?
    /// Remote URL for the full-quality asset (or nil if purely local).
    public var remoteURL: URL?
    /// Heuristic: loop duration in seconds for videos (for tail-padding during transitions).
    public var loopDuration: Double?
    /// Display name.
    public var title: String
    public var author: String?
    public var sourceURL: String?
    public var license: String?

    public init(
        id: String,
        kind: Kind,
        origin: Origin,
        localURL: URL? = nil,
        remoteURL: URL? = nil,
        loopDuration: Double? = nil,
        title: String,
        author: String? = nil,
        sourceURL: String? = nil,
        license: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.origin = origin
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.loopDuration = loopDuration
        self.title = title
        self.author = author
        self.sourceURL = sourceURL
        self.license = license
    }

    // Hashable conformance by id only, to keep large structs cheap in dictionaries.
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    public static func == (lhs: MediaSource, rhs: MediaSource) -> Bool { lhs.id == rhs.id && lhs.localURL == rhs.localURL }
}

public extension MediaSource {
    /// Fixed `color` helper — e.g., for "no wallpaper" / solid backdrops.
    static func solidColor(_ name: String) -> MediaSource {
        MediaSource(
            id: "color:\(name)",
            kind: .color,
            origin: .solidColor,
            title: name,
            license: "n/a"
        )
    }
}
