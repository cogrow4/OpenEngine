import Foundation
import SwiftUI
import WallpaperKit

/// A single item in the gallery (built on top of the Library type).
public struct GalleryPresentable: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let author: String
    public let sourceURL: String
    public let license: String
    public let kind: MediaSource.Kind
    public let previewURL: URL
    public let loopLength: Double?
    public var tags: [String]
    public init(from item: OELibraryItem) {
        self.id = item.id
        self.title = item.title
        self.author = item.author
        self.sourceURL = item.sourceURL
        self.license = item.license
        self.kind = item.mediaKind
        self.previewURL = item.preview.url
        self.loopLength = item.loopDurationSeconds
        self.tags = item.tags
    }
}
