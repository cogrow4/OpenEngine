import Foundation
import CryptoKit

public enum LibraryError: Error, LocalizedError {
    case offline
    case unwritableStore
    case checksumMismatch
    case decode(URLError)
    case manifestMissing

    public var errorDescription: String? {
        switch self {
        case .offline: return "Could not reach the OpenEngine library. Check your internet connection."
        case .unwritableStore: return "Could not write to the OpenEngine cache directory."
        case .checksumMismatch: return "Downloaded asset failed integrity verification. Try again."
        case .decode(let err): return "Library content could not be parsed: \(err.localizedDescription)"
        case .manifestMissing: return "Library manifest is empty."
        }
    }
}

/// Loads the curated library and downloads/verifies assets lazily with persistent caching.
///
/// Design notes
/// -----------
/// - *Manifest* is fetched from a small JSON file hosted alongside the GitHub repo
///   (`library/manifest.json`). This keeps the app binary thin and lets the catalog grow
///   without app updates.
/// - *Previews* are tiny (<= 300px) JPEG/MP4-moov-first clips fetched eagerly into the gallery.
/// - *Full assets* are downloaded only when the user selects "Set as…" and are checksum-verified.
/// - *Cache* lives under `~/Library/Caches/OpenEngine/assets/<id>.ext`.
public final class LibraryStore: @unchecked Sendable {

    public let manifestURL: URL
    public let cacheRoot: URL

    public init(manifestURL: URL? = nil,
                cacheRoot: URL = LibraryStore.defaultCacheRoot()) {
        // Resolution order for the manifest URL:
        //  1. explicit argument (e.g. tests)
        //  2. OPENENGINE_MANIFEST env var (lets `launch.sh` override)
        //  3. bundled manifest.json in the app's Resources (offline default)
        //  4. the public GitHub raw URL (network default for development)
        if let manifestURL {
            self.manifestURL = manifestURL
        } else if let raw = ProcessInfo.processInfo.environment["OPENENGINE_MANIFEST"],
                  let url = URL(string: raw) {
            self.manifestURL = url
        } else if let bundled = Bundle.main.url(forResource: "manifest", withExtension: "json") {
            self.manifestURL = bundled
        } else if let bundled = Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "Resources") {
            self.manifestURL = bundled
        } else {
            self.manifestURL = LibraryStore.publicDefaultManifestURL
        }
        self.cacheRoot = cacheRoot
        try? FileManager.default.createDirectory(at: cacheRoot, withIntermediateDirectories: true)
    }

    public static var publicDefaultManifestURL: URL {
        URL(string: "https://raw.githubusercontent.com/OpenEngine/OpenEngine/main/library/manifest.json")!
    }
    public static func defaultCacheRoot() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return caches.appending(path: "OpenEngine/assets", directoryHint: .isDirectory)
    }

    // MARK: - Public

    /// Fetch (and rehydrate-cached) the current manifest.
    public func loadManifest() async throws -> LibraryManifest {
        let cacheURL = cacheRoot.appending(path: "manifest.json", directoryHint: .notDirectory)
        if let data = try? Data(contentsOf: cacheURL),
           let manifest = try? JSONDecoder().decode(LibraryManifest.self, from: data) {
            refreshManifestInBackground(cacheURL: cacheURL)
            return manifest
        } else {
            let manifest = try await fetchManifest()
            try? writeCache(manifest, at: cacheURL)
            return manifest
        }
    }

    private func refreshManifestInBackground(cacheURL: URL) {
        Task { [weak self] in
            guard let self else { return }
            do {
                let manifest = try await self.fetchManifest()
                try self.writeCache(manifest, at: cacheURL)
            } catch {}
        }
    }

    private func fetchManifest() async throws -> LibraryManifest {
        do {
            let (data, response) = try await URLSession.shared.data(from: manifestURL)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw LibraryError.offline
            }
            return try JSONDecoder().decode(LibraryManifest.self, from: data)
        } catch let err as LibraryError {
            throw err
        } catch let err as URLError {
            throw LibraryError.decode(err)
        } catch let err as DecodingError {
            throw LibraryError.decode(URLError(.cannotDecodeContentData, userInfo: [NSLocalizedDescriptionKey: String(describing: err)]))
        } catch {
            throw LibraryError.offline
        }
    }

    private func writeCache(_ manifest: LibraryManifest, at cacheURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        do { try data.write(to: cacheURL, options: .atomic) }
        catch { throw LibraryError.unwritableStore }
    }

    /// Lazily download/verify/cache the full asset for `item`.
    /// `progress` (optional) is called on the main thread with a value in [0,1].
    public func resolvedLocalURL(for item: OELibraryItem, progress: ((Double) -> Void)? = nil) async throws -> URL {
        // Placeholder entries (added by the manifest author to document URL shape)
        // use a non-routable scheme so URLSession refuses them cleanly.
        if isPlaceholder(item.full.url) || isPlaceholder(item.preview.url) {
            throw LibraryError.manifestMissing
        }
        if let cached = try? filesystemPath(for: item), FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }
        let dest = try filesystemPath(for: item)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

        // Single session, single task, with progress observation.
        let waiter = DownloadWaiter(progress: progress)
        let session = URLSession(configuration: .default, delegate: waiter, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let task = session.downloadTask(with: item.full.url)
        waiter.task = task
        task.resume()

        // Await completion
        let result = await waiter.completion
        switch result {
        case .success(let tmp):
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: tmp, to: dest)
            if let expected = item.full.md5 {
                let actual = try md5(of: dest)
                if !actual.lowercased().elementsEqual(expected.lowercased()) {
                    try? FileManager.default.removeItem(at: dest)
                    throw LibraryError.checksumMismatch
                }
            }
            return dest
        case .failure(let err):
            throw err
        case .none:
            throw LibraryError.offline
        }
    }

    /// Build a ``MediaSource`` for an item given a resolved local URL.
    public func mediaSource(for item: OELibraryItem, localURL: URL) -> MediaSource {
        MediaSource(
            id: item.id,
            kind: item.mediaKind,
            origin: .builtin,
            localURL: localURL,
            remoteURL: item.full.url,
            loopDuration: item.loopDurationSeconds,
            title: item.title,
            author: item.author,
            sourceURL: item.sourceURL,
            license: item.license
        )
    }

    /// Preview URL for a low-res gallery thumbnail.
    public func previewURL(for item: OELibraryItem) -> URL { item.preview.url }
    public func fullURL(for item: OELibraryItem) -> URL { item.full.url }

    /// Check whether the full asset for `item` is cached locally.
    public func isCached(for item: OELibraryItem) -> Bool {
        guard let path = try? filesystemPath(for: item) else { return false }
        return FileManager.default.fileExists(atPath: path.path)
    }

    /// Delete the cached full asset for `item`. No-op (does not throw) if not cached.
    public func deleteCachedAsset(for item: OELibraryItem) throws {
        let path = try filesystemPath(for: item)
        try FileManager.default.removeItem(at: path)
    }

    // MARK: - Private

    private func filesystemPath(for item: OELibraryItem) throws -> URL {
        let ext = item.full.url.pathExtension.nilIfEmpty ?? inferExtension(for: item)
        let filename = "\(item.id).\(ext)"
        return cacheRoot.appending(path: filename, directoryHint: .notDirectory)
    }

    private func inferExtension(for item: OELibraryItem) -> String {
        switch item.full.mimeType {
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "image/jpeg", "image/jpg": return "jpg"
        case "image/png": return "png"
        case "image/webp": return "webp"
        default: return item.kind == "video" ? "mp4" : "jpg"
        }
    }

    private func md5(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = Insecure.MD5()
        while autoreleasepool(invoking: { () -> Bool in
            guard let data = try? handle.read(upToCount: 1 << 20), !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    fileprivate func isPlaceholder(_ url: URL) -> Bool {
        // URLSession refuses about: URLs; we use that to detect placeholders.
        url.scheme == "about"
    }
}


// MARK: - Download waiter (delegate + progress)

/// URLSession delegate that bridges download progress and completion into Swift async.
final class DownloadWaiter: NSObject, URLSessionDownloadDelegate {
    let progress: ((Double) -> Void)?
    weak var task: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Result<URL, Error>?, Never>?
    private let lock = NSLock()

    init(progress: ((Double) -> Void)?) {
        self.progress = progress
    }

    /// Awaits the underlying download to finish.
    /// Resumes with the local file URL on success, or the error on failure.
    var completion: Result<URL, Error>? {
        get async {
            await withCheckedContinuation { (c: CheckedContinuation<Result?, Never>) in
                lock.lock()
                if let r = self.done { lock.unlock(); c.resume(returning: r); return }
                self.continuation = c
                lock.unlock()
            }
        }
    }

    private var done: Result<URL, Error>?

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let frac = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progress?(min(max(frac, 0), 1))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Move the file to a stable temp path because `location` is deleted when this delegate
        // method returns.
        let tmp = FileManager.default.temporaryDirectory
            .appending(path: "oe-\(UUID().uuidString)", directoryHint: .notDirectory)
        do {
            try FileManager.default.moveItem(at: location, to: tmp)
            finish(.success(tmp))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ r: Result<URL, Error>) {
        lock.lock()
        let cont = self.continuation
        self.continuation = nil
        self.done = r
        lock.unlock()
        cont?.resume(returning: r)
    }
}


fileprivate extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
