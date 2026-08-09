import Foundation

/// A single curated library entry, as described by the online manifest.
public struct OELibraryItem: Codable, Identifiable, Hashable, Sendable {
    public struct AssetFile: Codable, Hashable, Sendable {
        public let url: URL
        public let mimeType: String
        public let sizeBytes: Int64?
        public let md5: String?
        public init(url: URL, mimeType: String, sizeBytes: Int64? = nil, md5: String? = nil) {
            self.url = url; self.mimeType = mimeType; self.sizeBytes = sizeBytes; self.md5 = md5
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            mimeType = try c.decodeIfPresent(String.self, forKey: .mimeType) ?? "application/octet-stream"
            sizeBytes = try c.decodeIfPresent(Int64.self, forKey: .sizeBytes)
            md5 = try c.decodeIfPresent(String.self, forKey: .md5)
            // Decode the URL string leniently: placeholder strings like
            // "PLACEHOLDER_SELFHOST_NEEDED://coverr-aurora-night" are kept
            // verbatim (URL(string:) returns nil for them) by falling back to
            // a non-failing sentinel URL the download code can detect.
            let raw = try c.decode(String.self, forKey: .url)
            if let parsed = URL(string: raw) {
                self.url = parsed
            } else {
                // Sentinel URL: scheme is non-routable so URLSession refuses it.
                self.url = URL(string: "about:invalid?\(raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "invalid")")!
            }
        }
        private enum CodingKeys: String, CodingKey { case url, mimeType, sizeBytes, md5 }
        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(url, forKey: .url)
            try c.encode(mimeType, forKey: .mimeType)
            try c.encode(sizeBytes, forKey: .sizeBytes)
            try c.encode(md5, forKey: .md5)
        }
    }

    public let id: String
    public let title: String
    public let author: String
    public let authorURL: String?
    public let sourceURL: String
    public let license: String
    public let kind: String       // "video" | "image"
    public let preview: AssetFile
    public let full: AssetFile
    public let loopDurationSeconds: Double?
    public let tags: [String]

    public var mediaKind: MediaSource.Kind { kind == "video" ? .video : .image }

    public init(id: String, title: String, author: String, authorURL: String?, sourceURL: String,
                license: String, kind: String, preview: AssetFile, full: AssetFile,
                loopDurationSeconds: Double?, tags: [String]) {
        self.id = id; self.title = title; self.author = author; self.authorURL = authorURL
        self.sourceURL = sourceURL; self.license = license; self.kind = kind
        self.preview = preview; self.full = full
        self.loopDurationSeconds = loopDurationSeconds; self.tags = tags
    }
}

/// A collection of curated items grouped for browsing.
public struct LibraryManifest: Codable, Sendable {
    public let schemaVersion: Int
    public let generatedAt: Date
    public let items: [OELibraryItem]

    public static let currentSchemaVersion = 1

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, generatedAt, items
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        // generatedAt: accept ISO-8601 ("2025-01-01T00:00:00Z"), Unix epoch seconds,
        // Unix epoch milliseconds, or an empty string. Default to .distantPast on missing.
        if let s = try? c.decodeIfPresent(String.self, forKey: .generatedAt),
           let date = Self.parseDate(s) {
            generatedAt = date
        } else if let d = try? c.decodeIfPresent(Double.self, forKey: .generatedAt) {
            generatedAt = Date(timeIntervalSince1970: d)
        } else {
            generatedAt = .distantPast
        }
        items = try c.decodeIfPresent([OELibraryItem].self, forKey: .items) ?? []
    }
    public init(schemaVersion: Int = currentSchemaVersion, generatedAt: Date = .init(), items: [OELibraryItem]) {
        self.schemaVersion = schemaVersion; self.generatedAt = generatedAt; self.items = items
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(generatedAt, forKey: .generatedAt)
        try c.encode(items, forKey: .items)
    }

    /// Parses an ISO-8601 timestamp in either fractional-second or whole-second form.
    /// Empty strings yield `nil` so the fallback path can pick a default.
    public static func parseDate(_ s: String) -> Date? {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFractional.date(from: trimmed) { return d }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: trimmed)
    }
}
