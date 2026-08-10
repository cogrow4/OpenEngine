import SwiftUI
import ImageIO

/// ThumbnailImage loads an image from a URL and downsamples it using ImageIO
/// during decode, avoiding full-resolution memory allocation for large images
/// (e.g. 2.3MB 4K wallpapers) in the gallery grid.
struct ThumbnailImage: View {
    let url: URL
    let maxDimension: CGFloat
    let placeholderIcon: String

    @State private var image: NSImage?

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
        .onAppear {
            load()
        }
        .onChange(of: url) { _, _ in
            image = nil
            load()
        }
    }

    private func load() {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let img = downsample(data)
                await MainActor.run {
                    self.image = img
                }
            } catch {
                await MainActor.run {
                    self.image = nil
                }
            }
        }
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
