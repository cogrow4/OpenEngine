import SwiftUI
import ImageIO
import CryptoKit
/// caching the result on disk so subsequent loads are instant.
///
/// This avoids (1) re-downloading full-resolution images (e.g. 2.3MB 4K
/// wallpapers) and (2) full-resolution decode in memory. The cache key is
/// an MD5 of the source URL; cache files live under ~/Library/Caches/OpenEngine/thumbnails/.
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
            // 1. Try disk cache first
            if let cached = loadFromCache() {
                await MainActor.run { self.image = cached }
                return
            }
            // 2. Download and downsample
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let img = downsample(data)
                if let img {
                    saveToCache(img)
                    await MainActor.run { self.image = img }
                }
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
