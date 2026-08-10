import SwiftUI
import AVKit
import WallpaperKit

// PreviewTile: a small looped preview tile.
//
// Battery note: a hover starts a single, muted AVQueuePlayer with AVPlayerLooper
// and bounded buffer; the player is freed when the cell disappears.
public struct PreviewTile: View {
    public let presentable: GalleryPresentable
    public let isCurrent: Bool
    @Environment(\.displayScale) var displayScale

    public init(presentable: GalleryPresentable, isCurrent: Bool = false) {
        self.presentable = presentable
        self.isCurrent = isCurrent
    }

    @State private var loadState: LoadState = .preview
    @State private var asset: AVAsset?

    enum LoadState { case preview, video }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            content
            overlay
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white, Color.accentColor)
                    .padding(4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: OE_Theme.R.thumb, style: .continuous))
        .compositingGroup()
        .continuosSlopeShadow()
        .frame(maxWidth: .infinity, alignment: .top)
        .aspectRatio(16.0/9.0, contentMode: .fit)
        .onHover { hovering in
            if hovering && loadState == .preview && presentable.kind == .video {
                let isVideoPreview = ["mp4", "mov", "m4v"].contains(presentable.previewURL.pathExtension.lowercased())
                if isVideoPreview {
                    loadState = .video
                    asset = AVURLAsset(url: presentable.previewURL) as AVAsset
                }
                // If the preview URL is an image (e.g. a PNG thumbnail), keep loadState = .preview
                // — the ThumbnailImage in `content` already renders it correctly.
            }
        }
    }

    @ViewBuilder
    var content: some View {
        switch presentable.kind {
        case .image:
            ThumbnailImage(url: presentable.previewURL, maxDimension: 360, placeholderIcon: "photo")
        case .video:
            if let a = asset {
                LoopingVideoPlayer(asset: a).ignoresSafeArea()
            } else {
                ThumbnailImage(url: presentable.previewURL, maxDimension: 360, placeholderIcon: "film")
            }
        default:
            Rectangle().fill(.quaternary)
        }
    }

    var overlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer()
            HStack(spacing: OE_Theme.Sp.xs) {
                if presentable.kind == .video {
                    let dur = presentable.loopLength.map { "\(Int($0))s" } ?? "video"
                    Label(dur, systemImage: "play.square.fill")
                        .labelStyle(.iconOnly).font(.caption)
                        .padding(OE_Theme.Sp.xs)
                        .background(.ultraThinMaterial, in: Capsule())
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentable.title).font(.headline).lineLimit(1).foregroundStyle(.primary)
                    Text(presentable.author).font(.caption2).lineLimit(1).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(OE_Theme.Sp.s)
            .background(.ultraThinMaterial)
        }
        .padding(OE_Theme.Sp.s)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension View {
    @ViewBuilder func continuosSlopeShadow() -> some View {
        self
            .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: OE_Theme.R.thumb, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            )
    }
}

// Lightweight looping AVPlayer for previews. Uses AVPlayerLooper for
// seamless, self-sustaining loops (no manual re-queue observer needed).
struct LoopingVideoPlayer: NSViewRepresentable {
    let asset: AVAsset

    func makeNSView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.player = makePlayer()
        return v
    }
    func updateNSView(_ nsView: PlayerView, context: Context) {
        nsView.player?.pause()
        nsView.player = makePlayer()
    }
    private func makePlayer() -> AVQueuePlayer {
        let item = AVPlayerItem(asset: asset)
        let p = AVQueuePlayer()
        // AVPlayerLooper automatically re-inserts the item at end-of-playback,
        // ensuring seamless looping without a retained notification observer.
        // A manual two-item queue without re-queueing goes black once both items finish.
        let _ = AVPlayerLooper(player: p, templateItem: item)
        p.isMuted = true
        p.play()
        return p
    }
}

final class PlayerView: NSView {
    var player: AVQueuePlayer? { didSet { (layer as? AVPlayerLayer)?.player = player } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }
    override func layout() {
        super.layout()
        (layer as? AVPlayerLayer)?.frame = bounds
    }
    override func makeBackingLayer() -> CALayer {
        let l = AVPlayerLayer()
        l.videoGravity = .resizeAspectFill
        return l
    }
}
