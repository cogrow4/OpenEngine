import Foundation
import SwiftUI
import Combine
import AVFoundation
import WallpaperKit

@MainActor
public final class OEEngine: ObservableObject {

    // MARK: - Published state
    @Published public var settings = OESettings.load()
    @Published public var gallery: [GalleryPresentable] = []
    @Published public var selectedScope: WallpaperController.Scope = .wallpaper
    @Published public var search: String = ""
    @Published public var activeKind: MediaSource.Kind?
    @Published public var phase: Phase = .idle
    @Published public var downloadProgress: Double = 0
    @Published public var attributionSheet: OELibraryItem?

    public enum Phase: Equatable {
        case idle
        case loading
        case ready
        case error(String)
    }

    // MARK: - Internals
    public let controller = WallpaperController()
    public let store: LibraryStore
    private var manifest: LibraryManifest?

    public init() {
        // Allow injecting a different manifest URL via env for local testing.
        var store: LibraryStore
        if let raw = ProcessInfo.processInfo.environment["OPENENGINE_MANIFEST"],
           let url = URL(string: raw) {
            store = LibraryStore(manifestURL: url)
        } else {
            store = LibraryStore()
        }
        self.store = store
        Task { await refresh() }
    }

    static func makeFallbackStore() -> LibraryStore {
        // Point at the local bundled copy so the gallery still works offline.
        let doc = URL(fileURLWithPath: "/Users/Shared/OpenEngine/library/manifest.json")
        let cache = LibraryStore.defaultCacheRoot()
        try? FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        return LibraryStore(manifestURL: doc, cacheRoot: cache)
    }

    // MARK: - Manifest / gallery

    public func refresh() async {
        phase = .loading
        do {
            let m = try await store.loadManifest()
            self.manifest = m
            self.gallery = m.items.map { GalleryPresentable(from: $0) }
            phase = .ready
        } catch {
            phase = .error(String(describing: error))
        }
    }

    public var filteredGallery: [GalleryPresentable] {
        gallery
            // Hide items whose underlying preview/full URL is a placeholder
            // (the URL still parses, but the scheme is "about:" — that's our
            // sentinel for "self-host required, asset missing").
            .filter { item in
                guard let raw = self.manifest?.items.first(where: { $0.id == item.id }) else { return true }
                return raw.preview.url.scheme != "about" && raw.full.url.scheme != "about"
            }
            .filter { activeKind == nil || $0.kind == activeKind }
            .filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.author.localizedCaseInsensitiveContains(search) }
    }

    public func resolve(itemID: String) -> OELibraryItem? {
        manifest?.items.first(where: { $0.id == itemID })
    }

    // MARK: - Apply

    public func previewItem(_ item: GalleryPresentable, as scope: WallpaperController.Scope) async {
        guard let it = resolve(itemID: item.id) else { return }
        downloadProgress = 0
        do {
            let url = try await store.resolvedLocalURL(for: it) { [weak self] p in
                DispatchQueue.main.async { self?.downloadProgress = p }
            }
            downloadProgress = 1
            let source = store.mediaSource(for: it, localURL: url)
            switch scope {
            case .wallpaper: controller.setWallpaper(source)
            case .lockScreen: controller.setLockScreen(source)
            case .both: controller.setBoth(source)
            }
            persist(source: source, scope: scope)
        } catch {
            downloadProgress = 0
            phase = .error(error.localizedDescription)
        }
    }

    public func setLocalFile(_ url: URL, scope: WallpaperController.Scope) {
        let kind: MediaSource.Kind = url.pathExtension.lowercased().isVideo ? .video : .image
        let source = MediaSource(
            id: "user:\(url.path)",
            kind: kind,
            origin: .user,
            localURL: url,
            title: url.lastPathComponent,
            license: "Local file"
        )
        switch scope {
        case .wallpaper: controller.setWallpaper(source)
        case .lockScreen: controller.setLockScreen(source)
        case .both: controller.setBoth(source)
        }
        persist(source: source, scope: scope)
    }

    private func persist(source: MediaSource, scope: WallpaperController.Scope) {
        switch scope {
        case .wallpaper:
            settings.wallpaperID = source.id
            settings.lastWallpaperURL = source.localURL?.path
        case .lockScreen:
            settings.lockID = source.id
            settings.lastLockURL = source.localURL?.path
        case .both:
            settings.wallpaperID = source.id
            settings.lockID = source.id
            settings.lastWallpaperURL = source.localURL?.path
            settings.lastLockURL = source.localURL?.path
        }
        settings.save()
    }

    // MARK: - Cache management

    /// Whether a library item's full asset has been downloaded and cached locally.
    public func isCached(_ presentable: GalleryPresentable) -> Bool {
        guard let it = resolve(itemID: presentable.id) else { return false }
        return store.isCached(for: it)
    }

    /// Delete a previously downloaded asset from the local cache.
    public func deleteLocalCopy(of presentable: GalleryPresentable) {
        guard let it = resolve(itemID: presentable.id) else { return }
        try? store.deleteCachedAsset(for: it)
        objectWillChange.send()
    }


    public func restoreOnLaunch() {
        guard settings.startupBehavior == .restore else { return }
        if let path = settings.lastWallpaperURL {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                setLocalFile(url, scope: .wallpaper)
            }
        }
        if let path = settings.lastLockURL {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                setLocalFile(url, scope: .lockScreen)
            }
        }
    }
}

fileprivate extension String {
    var isVideo: Bool { ["mp4","mov","m4v","webm"].contains(self) }
}
