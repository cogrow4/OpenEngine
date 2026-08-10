import SwiftUI
import ImageIO
import CryptoKit

/// ThumbnailImage loads an image from a URL, downsamples it with ImageIO,
/// and caches the result on disk.
///
/// Cache: ~/Library/Caches/OpenEngine/thumbnails/<md5(url)>
///
/// Concurrency: uses a shared URLSession with `httpMaximumConnectionsPerHost = 4`
/// to throttle concurrent downloads and prevent network saturation when the
/// gallery grid has many large images (e.g. 10MB PNGs from mylinuxforwork).
struct ThumbnailImage: View {
    let url: URL
    let maxDimension: CGFloat
    let placeholderIcon: String

    @State private var image: NSImage?

    static let cacheDir: URL = {
        let c = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OpenEngine/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: c, withIntermediateDirectories: true)
        return c
    }()

    /// Throttled session limits concurrent connections per host to 4.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()

    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                    .overlay(ProgressView())
            }
        }
        .onAppear(perform: load)
        .onChange(of: url) { _, _ in
            image = nil
            load()
        }
    }

    private var cacheKey: String {
        url.absoluteString
            .data(using: .utf16, allowLossyConversion: false)!
            .md5Hash()
    }

    private var cacheURL: URL {
        Self.cacheDir.appendingPathComponent(cacheKey, isDirectory: false)
    }

    private func load() {
        Task {
            // Cache hit → instant
            if let cached = loadFromCache() {
                await MainActor.run { self.image = cached }
                return
            }

            do {
                let (data, _) = try await Self.session.data(from: url)
                guard let img = downsample(data) else {
                    await MainActor.run { self.image = nil }
                    return
                }
                saveToCache(img)
                await MainActor.run { self.image = img }
            } catch {
                await MainActor.run { self.image = nil }
            }
        }
    }

    private func loadFromCache() -> NSImage? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return NSImage(data: data)
    }

    private func saveToCache(_ image: NSImage) {
        guard let tiff = image.tiffRepresentation else { return }
        try? tiff.write(to: cacheURL, options: .atomic)
    }

    /// Downsamples image data to fit within maxDimension pixels.
    private func downsample(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension * 2),
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let cgImg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return NSImage(cgImage: cgImg, size: CGSize(width: cgImg.width, height: cgImg.height))
    }
}

fileprivate extension Data {
    func md5Hash() -> String {
        Insecure.MD5.hash(data: self).compactMap { String(format: "%02x", $0) }.joined()
    }
}
