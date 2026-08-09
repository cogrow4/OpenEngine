import Foundation
import AppKit
import AVFoundation

/// WallpaperKit — minimal, efficient, jitter-free dynamic wallpaper engine for macOS.
///
/// Core goals:
///   • Zero perceptible jitter at the loop seam (use AVQueuePlayer double-buffer + actionAtItemEnd alternative)
///   • Minimal RAM: a single video pipeline per screen, small buffers, no caching beyond one decoded frame queue
///   • Minimal battery: paused when on battery thresholds exceeded, throttled to display refresh, no logging
///
/// Public entry points:
///   - ``WallpaperSurface`` — manages one desktop window per `NSScreen`
///   - ``WallpaperController`` — owns surfaces, applies a ``MediaSource``
///   - ``MediaSource`` — image or looped-video asset reference (local or downloaded)
public enum WallpaperKit {
    /// Current engine version. Bumped on wire/manifest format changes.
    public static let version = "1.0.0"

    /// Throttling policy for battery friendliness.
    public struct EnergyPolicy: Sendable {
        /// When battery at/below this fraction and not charging, pause video playback.
        public var batteryPauseFraction: Double = 0.15
        /// Pause playback while the app is backgrounded by App Nap.
        public var respectAppNap: Bool = true
        public init() {}
    }

    public static let energy: EnergyPolicy = .init()
}
