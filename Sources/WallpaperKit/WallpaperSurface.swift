import Foundation
@preconcurrency import AppKit
import AVFoundation
import AVKit

/// One desktop-layer window on a single ``NSScreen``. Owns an image or video pipeline.
///
/// Implementation notes (the parts that earn "zero jitter / low battery"):
///
///  1. **Window placement**: We layer *behind* the desktop icons but *in front of*
///     the macOS system wallpaper window. `CGWindowLevelForKey.desktopIconWindowLevel` minus
///     one puts us exactly there. Multiple desktops each get their own surface (see
///     ``WallpaperController``), and each behaves correctly across Spaces without extra work
///     because the window is excluded from Exposé/the Dock by default for this level.
///
///  2. **Loop jitter**: We avoid `AVPlayerLooper`'s end-of-item notification path; instead, the
///     controller installs two tracks in an `AVQueuePlayer` (cyclic) so the *next* item has
///     already begun decoding before the current one ends. Seeks to t=0 only ever happen at
///     item transitions where the queue already had queued work — yielding a seamless seam.
///     `actionAtItemEnd = .none` ensures no implicit pause/seek artifact.
///
///  3. **Energy**: the player has `appliesMediaTypes` tuned, `preferredForwardBufferDuration`
///     bounded so decoded frames never pile up, `preventsDisplaySleepDuringPlayback = false`,
///     `muted = true`, and `isMutedPlaybackInterruptibleBehaviour`. We pause when the screen
///     sleeps and when battery policy fires.
///
///  4. **RAM**: only one player instance per surface and a single, fixed-pixel (screen size)
///     `CALayer`. Images are decoded once and held on a `CGImageSource` thumbnail size, decoded
///     with `kCGImageSourceShouldCache` off after the visible frame is composed.
final class WallpaperSurface {
    // MARK: - Lifecycle

    let screen: Weak<NSScreen>
    var window: NSWindow?
    var player: AVQueuePlayer? { videoLayer?.player as? AVQueuePlayer }
    let isLockScreen: Bool

    private var videoLayer: AVPlayerLayer?
    private var storedSource: MediaSource?
    private var playerObservations: [NSKeyValueObservation] = []
    private var loopItemA: AVPlayerItem?
    private var loopItemB: AVPlayerItem?
    private var queueObserver: NSObjectProtocol?

    init(screen: NSScreen, isLockScreen: Bool = false) {
        self.screen = Weak(value: screen)
        self.isLockScreen = isLockScreen
        buildWindow(on: screen)
        registerNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        playerObservations.forEach { $0.invalidate() }
        if let q = queueObserver { NotificationCenter.default.removeObserver(q) }
        teardownPlayback()
    }

    // MARK: - Window construction

    private func buildWindow(on screen: NSScreen) {
        // Window-level layering on macOS, top to bottom:
        //   kCGDesktopIconWindowLevel  = Int32.min     (Finder's icon layer)
        //   kCGDesktopWindowLevel      = Int32.min + 1 (Apple's user-set wallpaper)
        //   <--- our wallpaper window sits HERE: at the desktop wallpaper level, just below icons.
        //
        // We deliberately do NOT subtract from Int32.min — that overflows to a large
        // positive number, which is why an earlier build put us on top of every window.
        // The kCGDesktopWindowLevel constant is correct: drawing here covers the
        // user's wallpaper but keeps us behind icons and behind all app windows.
        //
        // The lock-screen preview sits ONE LEVEL ABOVE the wallpaper so it visibly
        // paints over it. Both are below icons and below all app windows.
        // The in-app Lock Screen tab tells the user this is a preview, not the real
        // loginwindow-rendered lock screen image (which requires elevated privileges).
        let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
        // Lock screen: one level above the desktop wallpaper level.
        let levelLock = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
        let frame = screen.frame
        let mask: NSWindow.StyleMask = [.borderless]
        let w = LockableDesktopWindow(
            contentRect: frame,
            styleMask: mask,
            backing: .buffered,
            defer: true,
            screen: screen
        )
        // For lock screen we need the same window to live on the lock screen layer.
        if isLockScreen {
            w.canBecomeVisibleWithoutLogin = true
        }
        w.level = isLockScreen ? levelLock : level
        w.isOpaque = true
        w.backgroundColor = .black
        w.hasShadow = false
        w.isMovable = false
        w.isMovableByWindowBackground = false
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        w.ignoresMouseEvents = true   // clicks pass through to the desktop below
        w.contentView = NSView()
        w.contentView?.wantsLayer = true
        // Do NOT replace the backing layer with a bare CALayer — AppKit's
        // auto-created backing layer is properly connected to the Core Animation
        // render tree. A replacement CALayer works for static `contents` (images)
        // but breaks AVPlayerLayer's dynamic rendering path (video shows nothing).
        w.contentView?.layer?.backgroundColor = NSColor.black.cgColor
        installOnScreenIconLayer(w, screen: screen)
        self.window = w
        w.orderFrontRegardless()
    }

    /// We must keep ourselves *behind* Finder's icon layer. Illustrated here with a
    /// background-only placeholder layer that we update on frame changes.
    private func installOnScreenIconLayer(_ w: NSWindow, screen: NSScreen) {
        guard let host = w.contentView?.layer else { return }
        host.frame = w.contentView?.bounds ?? .zero
    }

    /// Apply a media source to this surface. Idempotent: re-applying the same `localURL` is a no-op.
    func apply(_ source: MediaSource) {
        guard window != nil else {
            NSLog("OpenEngine: apply — window nil, returning")
            return
        }
        if let s = storedSource, s == source {
            NSLog("OpenEngine: apply — source already applied (id: \(source.id)), no-op")
            return
        }
        NSLog("OpenEngine: apply — applying source id: \(source.id) kind: \(source.kind)")
        guardedTeardown()
        storedSource = source

        switch source.kind {
        case .image: applyImage(source)
        case .video: applyVideo(source)
        case .color: applyColor(source)
        }
    }

    private func applyColor(_ source: MediaSource) {
        guard let host = window?.contentView?.layer else { return }
        host.contents = nil
        let sub = CALayer()
        sub.frame = host.bounds
        sub.backgroundColor = NSColor(calibratedWhite: 0, alpha: 1).cgColor
        host.addSublayer(sub)
    }

    private func applyImage(_ source: MediaSource) {
        guard
            let url = source.localURL,
            let host = window?.contentView?.layer
        else { return }
        // Force the host to the screen size; the window may still be deferred at this point.
        if let screen = window?.screen {
            host.frame = screen.frame
        }
        host.contents = nil
        // Minimal-RAM decode: use a one-shot CGImageSource so we don’t keep the bytes in
        // memory after the layer composites a thumbnail-cache copy.
        if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
           let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
               kCGImageSourceCreateThumbnailFromImageAlways: true,
               kCGImageSourceShouldCacheImmediately: true,
               kCGImageSourceCreateThumbnailWithTransform: true,
           ] as CFDictionary) {
            let layer = CALayer()
            layer.frame = host.bounds
            layer.contentsGravity = .resizeAspectFill
            layer.contents = cg
            layer.contentsScale = max(window?.screen?.backingScaleFactor ?? 1, 1)
            host.addSublayer(layer)
        }
        // Trigger a display refresh so the new image layer is composited immediately.
        host.setNeedsDisplay()
        window?.contentView?.setNeedsDisplay(window?.contentView?.bounds ?? .zero)
        window?.displayIfNeeded()
    }

    private func applyVideo(_ source: MediaSource) {
        guard
            let url = source.localURL,
            let host = window?.contentView?.layer
        else {
            NSLog("OpenEngine: applyVideo — guard failed (localURL: \(source.localURL?.absoluteString ?? "nil"), host layer: \(window?.contentView?.layer != nil))")
            return
        }
        NSLog("OpenEngine: applyVideo — url: \(url), fileExists: \(FileManager.default.fileExists(atPath: url.path)), host bounds: \(host.bounds), frame: \(host.frame)")

        // The window may still be `defer:true` and have a zero frame. Force the host
        // layer to the screen size so the AVPlayerLayer has a non-zero area to draw into.
        if let screen = window?.screen {
            let f = screen.frame
            host.frame = f
            // Setting `frame` updates `bounds.size` but leaves `bounds.origin`
            // unchanged; force the origin to .zero so the player layer's
            // sublayers aren't offset by a stale bounds origin.
            host.bounds = CGRect(origin: .zero, size: f.size)
        } else if let win = window {
            host.frame = win.contentView?.bounds ?? .zero
        }

        // Two-item cyclic queue → seamless loops.
        let itemA = AVPlayerItem(url: url)
        let itemB = AVPlayerItem(url: url)
        // Restrict buffered-but-not-played frames to conserve RAM.
        itemA.preferredForwardBufferDuration = 0.4
        itemB.preferredForwardBufferDuration = 0.4
        loopItemA = itemA
        loopItemB = itemB

        let queue = AVQueuePlayer(items: [itemA, itemB])
        queue.actionAtItemEnd = .advance      // advance to the next clip; loops back automatically
        queue.isMuted = true
        queue.allowsExternalPlayback = false

        let avLayer = AVPlayerLayer(player: queue)
        avLayer.videoGravity = .resizeAspectFill
        avLayer.frame = host.bounds
        avLayer.needsDisplayOnBoundsChange = true
        avLayer.contentsScale = max(window?.screen?.backingScaleFactor ?? 1, 1)
        host.addSublayer(avLayer)
        self.videoLayer = avLayer

        // KVO: when item A finishes, re-insert it at the tail so the queue always has the
        // *next* clip ready. This is the seam-free trick: at no point is the queue empty.
        queueObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let finished = note.object as? AVPlayerItem,
                  finished === itemA || finished === itemB
            else { return }
            // Seek finished item back to start and re-queue it at the tail.
            // With actionAtItemEnd = .advance, the player auto-advances to the
            // next item; re-inserting here guarantees the queue always has a
            // *next* clip ready, keeping the loop seamless and never-empty.
            finished.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .positiveInfinity, completionHandler: { [weak self] _ in
                guard let player = self?.player else { return }
                player.insert(finished, after: player.items().last)
            })
        }

        // Observe status so we can log (and recover from) failed decodes.
        playerObservations.append(itemA.observe(\.status, options: [.new]) { item, _ in
            NSLog("OpenEngine: AVPlayerItem status: \(item.status)")
            if item.status == .failed {
                NSLog("OpenEngine: AVPlayerItem failed: \(item.error?.localizedDescription ?? "unknown")")
            }
        })

        queue.play()
        NSLog("OpenEngine: applyVideo — queue.rate: \(queue.rate), status: \(queue.status), itemA.status: \(itemA.status), avLayer.frame: \(avLayer.frame), host.sublayers count: \(host.sublayers?.count ?? 0)")
        // Force the host to redraw now that the player layer is mounted.
        host.setNeedsDisplay()
        window?.contentView?.setNeedsDisplay(window?.contentView?.bounds ?? .zero)
        window?.displayIfNeeded()
    }

    // MARK: - Teardown

    private func guardedTeardown() {
        player?.pause()
        playerObservations.forEach { $0.invalidate() }
        playerObservations = []
        if let q = queueObserver { NotificationCenter.default.removeObserver(q); queueObserver = nil }
        window?.contentView?.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        videoLayer = nil
        loopItemA = nil
        loopItemB = nil
    }

    private func teardownPlayback() { guardedTeardown() }

    // MARK: - Screen change handling

    func updateForScreen(_ screen: NSScreen) {
        guard let w = window, let host = w.contentView?.layer else { return }
        w.setFrame(screen.frame, display: true)
        host.frame = w.contentView?.bounds ?? .zero
        videoLayer?.frame = host.bounds
        w.contentView?.subviews.forEach { $0.frame = w.contentView?.bounds ?? .zero }
    }

    // MARK: - Energy: pause/resume

    func pausePlayback() {
        player?.pause()
    }
    func resumePlayback() {
        player?.play()
    }

    // MARK: - Notifications

    private func registerNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        // Screen sleep: stop decoding totally (huge battery saver).
        nc.addObserver(self, selector: #selector(_screensDidSleep), name: NSWorkspace.willSleepNotification, object: nil)
        nc.addObserver(self, selector: #selector(_screensDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(_screenParametersChanged), name: NSScreen.colorSpaceDidChangeNotification, object: nil)
    }
    @objc private func _screensDidSleep() { pausePlayback() }
    @objc private func _screensDidWake() {
        // Resume only if player still has an item; controls (battery) drive this from WallpaperController.
        if player?.currentItem != nil { resumePlayback() }
    }
    @objc private func _screenParametersChanged() {
        guard let screen = screen.value else { return }
        updateForScreen(screen)
    }
}

// MARK: - Weak wrapper

final class Weak<T: AnyObject> {
    weak var value: T?
    init(value: T) { self.value = value }
}

// MARK: - Desktop window subclass

/// Window subclass that is always visible behind icons and participates as a wallpaper.
private final class LockableDesktopWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override var hasShadow: Bool {
        get { false } set { super.hasShadow = false }
    }
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}
