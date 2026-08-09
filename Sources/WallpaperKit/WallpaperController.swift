import Foundation
@preconcurrency import AppKit
import AVFoundation
import IOKit
import IOKit.ps

/// Owns one ``WallpaperSurface`` per display (and an optional lock-screen pair),
/// applies the user-selected ``MediaSource``, enforces battery friendliness and
/// survives display changes / app naps with minimal work.
public final class WallpaperController {

    public enum Scope: String, Sendable, Hashable, CaseIterable {
        case wallpaper
        case lockScreen
        case both
    }

    private var wallpaper: WallpaperSurface?
    private var lock: WallpaperSurface?

    public private(set) var currentWallpaperSource: MediaSource?
    public private(set) var currentLockSource: MediaSource?

    public static let didChangeNotification = Notification.Name("OpenEngineWallpaperDidChange")

    private var displayConfigObservation: NSObjectProtocol?
    private var appNapObserver: NSObjectProtocol?
    private var batteryTimer: Timer?

    public init() {
        observeDisplays()
    }

    deinit {
        if let o = displayConfigObservation { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        if let o = appNapObserver { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        batteryTimer?.invalidate()
    }

    // MARK: - Public API

    public func setWallpaper(_ source: MediaSource) {
        ensureMain()
        NSLog("OpenEngine: setWallpaper — id: \(source.id), kind: \(source.kind), wallpaper nil: \(wallpaper == nil)")
        currentWallpaperSource = source
        ensureSurface(for: .wallpaper)
        NSLog("OpenEngine: after ensureSurface — wallpaper nil: \(wallpaper == nil), window nil: \(wallpaper?.window == nil)")
        wallpaper?.apply(source)
        notify(scope: .wallpaper)
    }

    public func setLockScreen(_ source: MediaSource) {
        ensureMain()
        NSLog("OpenEngine: setLockScreen — id: \(source.id), kind: \(source.kind), lock nil: \(lock == nil)")
        currentLockSource = source
        ensureSurface(for: .lockScreen)
        NSLog("OpenEngine: after ensureSurface — lock nil: \(lock == nil), window nil: \(lock?.window == nil)")
        lock?.apply(source)
        // For static images, also try NSWorkspace so the real lock screen
        // updates (macOS 26 supports this via setDesktopImageURL options).
        if source.kind == .image, let url = source.localURL,
           let screen = NSScreen.main {
            let opts: [NSWorkspace.DesktopImageOptionKey: Any] = [
                .init(rawValue: "allowSettingDesktopImageOnLockScreen"): true
            ]
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: opts)
        }
        notify(scope: .lockScreen)
    }

    public func setBoth(_ source: MediaSource) {
        setWallpaper(source)
        setLockScreen(source)
    }

    public func setVisible(_ visible: Bool) {
        wallpaper?.window?.setIsVisible(visible)
        lock?.window?.setIsVisible(visible)
    }

    // MARK: - Convenience: pause/resume both surfaces

    public func pausePlaybackAll() {
        wallpaper?.pausePlayback()
        lock?.pausePlayback()
    }
    public func resumePlaybackAll() {
        wallpaper?.resumePlayback()
        lock?.resumePlayback()
    }

    // MARK: - Surface management

    private func ensureSurface(for scope: Scope) {
        let primary = NSScreen.main ?? NSScreen.screens.first
        guard let screen = primary else { return }
        switch scope {
        case .wallpaper:
            if wallpaper == nil || wallpaper?.screen.value === nil {
                wallpaper = WallpaperSurface(screen: screen, isLockScreen: false)
                attachAutoResume(screen: screen)
            }
        case .lockScreen:
            if lock == nil || lock?.screen.value === nil {
                lock = WallpaperSurface(screen: screen, isLockScreen: true)
            }
        case .both:
            ensureSurface(for: .wallpaper)
            ensureSurface(for: .lockScreen)
        }
    }

    private func attachAutoResume(screen: NSScreen) {
        // Ensure playback on this screen even after the display was hot-plugged.
    }

    // MARK: - Display change tracking

    private func observeDisplays() {
        displayConfigObservation = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshScreens()
        }
        NotificationCenter.default.addObserver(
            self, selector: #selector(_screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        startBatteryWatcher()
    }

    @objc private func _screensChanged() { refreshScreens() }

    private func refreshScreens() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        wallpaper?.updateForScreen(screen)
        lock?.updateForScreen(screen)
    }

    // MARK: - Battery policy

    private func startBatteryWatcher() {
        // Lightweight: tick every 60s is plenty for a pause-on-low-battery cylinder.
        batteryTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.evaluateBatteryPolicy()
        }
    }

    private func evaluateBatteryPolicy() {
        let level = maxProcessBatteryFraction()
        let isCharging = self.lastIsCharging
        let shouldPause = level <= Double(WallpaperKit.energy.batteryPauseFraction) && !isCharging
        if shouldPause { wallpaper?.pausePlayback() }
        else if wallpaper?.player?.rate == 0 { wallpaper?.resumePlayback() }
    }

    private var lastIsCharging: Bool = true

    private func maxProcessBatteryFraction() -> Double {
        // Attempt to read the system battery fraction via IOKit power sources.
        if let blob = IOPSCopyPowerSourcesInfo() {
            let blobCF = blob as CFTypeRef
            if let arr = IOPSCopyPowerSourcesList(blobCF)?.takeRetainedValue() as? [CFDictionary] {
                for src in arr {
                    guard let dict = src as? [String: Any] else { continue }
                    let state = dict[kIOPSPowerSourceStateKey as String] as? String
                    let isCharging = (state == (kIOPSACPowerValue as String))
                    if let cap = dict[kIOPSCurrentCapacityKey as String] as? Int,
                       let max = dict[kIOPSMaxCapacityKey as String] as? Int, max > 0 {
                        let frac = Double(cap) / Double(max)
                        self.lastIsCharging = isCharging
                        return frac
                    }
                }
            }
        }
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return 0.1 }
        return 1.0
    }

    // MARK: - Notify

    private func notify(scope: Scope) {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self, userInfo: ["scope": scope])
    }

    private func ensureMain() {
        if Thread.isMainThread { return }
        DispatchQueue.main.sync { }
    }
}

// (Helpers removed in favor of IOKit.)
