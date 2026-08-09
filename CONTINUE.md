# CONTINUE.md — Hand-off Notes for OpenEngine

> **Read this first.** You're picking up a half-built macOS app. The engine
> works end-to-end, the curated library is verified live, and there's a clean
> build path. But there are several *known* bugs and one compile error to
> fix in `LibraryStore.swift`. Everything is documented below.

## Project: OpenEngine

- **Path**: `/Users/coeng24/Projects/OpenEngine`
- **What**: Native macOS app for setting images / looped videos as desktop
  wallpaper and lock-screen preview. MIT licensed. Built with SwiftUI +
  AppKit. Targets macOS 26+ on Apple Silicon (Swift 6 toolchain).
- **Inspiration**: A free, open-source replacement for "Wallspace"-style apps.
- **Build**: SwiftPM (`Package.swift`), `make_app.sh` produces a real
  `.app` bundle at `build/OpenEngine.app`.

## Current Build State

`swift build` succeeds (zero warnings) after Phase 2 fixes. Final state:

- `Package.swift` uses `swift-tools-version: 6.2`, `.macOS(.v26)`, and
  `.swiftLanguageMode(.v5)` per-target to keep `strict-concurrency=minimal`
  (macOS 26 SDK marks AppKit types as `@MainActor`, producing
  `SendingRisksDataRace` errors in Swift 6 mode; `.v5` language mode avoids
  these without code changes).
- `@preconcurrency import AppKit` on `WallpaperSurface.swift` and
  `WallpaperController.swift` to suppress remaining AppKit concurrency
  diagnostics.
- `LibraryStore.resolvedLocalURL(for:progress:)` accepts an optional progress
  callback, wires it through a `URLSessionDownloadDelegate`, and resolves
  with `Result<URL, Error>`.
- `OEEngine.previewItem` passes a `(Double) -> Void` closure that dispatches
  `downloadProgress` updates to the main thread.
- `GalleryView` and `WallpaperTabPage` show a linear `ProgressView` at the
  top during downloads.
- `swift build` clean (zero warnings)
- `./make_app.sh` clean (release bundle at `build/OpenEngine.app`)
- App launches, gallery populates, image wallpapers apply correctly

Completed bugs and features are listed below; outstanding items are in
[Section 5](#5-known-bugs-and-fix-list) and the open items in
[Section 10](#10-files-most-likely-to-need-edits-next).

## 1. Architecture

Two SwiftPM targets:

### `WallpaperKit` (library — `Sources/WallpaperKit/`)
The engine. Cross-target so it could be reused (e.g., a future CLI). Files:

| File | Purpose |
|------|---------|
| `WallpaperKit.swift` | Version, `EnergyPolicy` struct (battery pause fraction) |
| `MediaSource.swift` | Value type representing an image/video/color to render |
| `LibraryManifest.swift` | `Codable` schema for the JSON catalog; custom `Date` decoder (accepts ISO-8601 with or without fractional seconds, Unix epoch Double, empty string) |
| `LibraryStore.swift` | Fetches manifest, downloads/caches/checksums assets, `DownloadWaiter` delegate. `isCached(for:)` and `deleteCachedAsset(for:)` added in Phase 2. |
| `WallpaperSurface.swift` | Per-screen desktop window. Owns one `AVQueuePlayer` (2-item cyclic queue) for jitter-free loops; `CALayer` image fallback. **Lock-screen support is best-effort.** `buildWindow` fix (Phase 2): no longer replaces backing layer. |
| `WallpaperController.swift` | Owns surfaces, battery policy (IOKit via `IOPSCopyPowerSourcesInfo`), display-wake handling. `refreshScreens` still stubbed. |

### `OpenEngineApp` (executable — `Sources/OpenEngineApp/`)
The UI. Files:

| File | Purpose |
|------|---------|
| `OpenEngineApp.swift` | `@main`, scenes, `RootView` with `NavigationSplitView` sidebar (Browse / Wallpaper / Lock Screen / Settings). `WallpaperTabPage` component shared by Wallpaper and Lock Screen tabs, parameterized by `scope`. |
| `Components/GalleryView.swift` | Filter pills (All / Images / Video), search, scope picker (Wallpaper / Lock Screen / Both), context menu, `LazyVGrid`. Progress bar at top during downloads. |
| `Components/PreviewTile.swift` | Async-image / hover-to-play AVPlayer thumbnail; `LoopingVideoPlayer` `NSViewRepresentable`. `isCurrent` checkmark overlay added in Phase 2. `AVPlayerLooper` replaces manual 2-item queue for gallery previews. |
| `Components/SettingsView.swift` | Form with behavior, current-background, battery, library info, about; `fileImporter` for local files |
| `Models/OEEngine.swift` | `@MainActor` view-model. Holds `WallpaperController` + `LibraryStore`. `previewItem(_:as:)` does the download + apply. `isCached(_:)` and `deleteLocalCopy(of:)` added in Phase 2. |
| `Models/OESettings.swift` | `Codable` settings persisted to `~/Library/Application Support/OpenEngine/settings.json` |
| `Models/LaunchAgentManager.swift` | Login-item installer (LaunchAgent plist + `SMAppService` register) |
| `Models/OEStorage.swift` | App-support directory helpers |
| `Models/OETheme.swift` | Design tokens (spacing, radii) |
| `Models/GalleryPresentable.swift` | UI-side value type wrapping `OELibraryItem` for SwiftUI |
| `Resources/manifest.json` | Bundled copy of the library manifest so the app works offline |

### Top-level files

- `Package.swift` — SwiftPM manifest (`swift-tools-version: 6.2`, `.macOS(.v26)`, `.swiftLanguageMode(.v5)` per-target)
- `make_app.sh` — release build + bundle + ad-hoc sign
- `Settings.app/Info.plist` — `.app` bundle plist
- `LICENSE` — MIT
- `README.md` — user-facing docs
- `library/` — catalog source
- `build/` — generated `.app` bundle
- `.research/` — Web search results used during curation

## 2. Engine Design

### Jitter-free loop (the heart of the engine)
`WallpaperSurface.applyVideo(_:)` builds an `AVQueuePlayer` from **two copies**
of the same `AVPlayerItem`. `actionAtItemEnd = .advance` makes the queue
advance to the second copy automatically. When an item finishes, we observe
`AVPlayerItemDidPlayToEndTime`, seek-to-zero, and re-insert at the
queue tail. The queue is **never empty** — the next clip is already decoded
when the previous one ends, so there's no seam.

For gallery **previews** (`LoopingVideoPlayer` in `PreviewTile.swift`), we
switched to `AVPlayerLooper` (simpler, no manual observer needed) since
preview quality matters less than desktop RAM.

### Energy / RAM
- One `AVQueuePlayer` per screen.
- `preferredForwardBufferDuration = 0.4s` per item — minimal buffered frames.
- `isMuted = true` so no CoreAudio output pull.
- `pause()` on `NSWorkspace.willSleepNotification` → zero decoder work when
  the screen sleeps.
- Battery policy: `WallpaperController.evaluateBatteryPolicy()` ticks every
  60s, reads battery state via `IOPSCopyPowerSourcesInfo` (IOKit), pauses
  video when below user-configured threshold and not charging.

### Window layering
The desktop window sits at:
```swift
let level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)))
```
That's `Int32.min + 1` = `-2147483647`, which is **Apple's official
desktop-wallpaper layer** — above the user's system wallpaper, below the
desktop icons, below all app windows. **DO NOT subtract from `Int32.min`** —
that overflows and puts the window on top of everything (a bug we hit early).

The lock-screen surface sits one level above:
```swift
let levelLock = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
```

The `LockableDesktopWindow` subclass sets `canBecomeKey = false`,
`canBecomeMain = false`, `acceptsFirstResponder = false` so the window is
non-activating. Mouse events are ignored (`ignoresMouseEvents = true`) so
clicks pass through to the desktop.

## 3. Library

The catalog is a JSON manifest at `library/manifest.json`, generated from
`library/generate_manifest.py` (Python — the *single source of truth* for
catalog entries).

**Current size**: 33 items total
- 10 videos (6 Apple Aerials via `sylvan.apple.com`, 4 `PLACEHOLDER_SELFHOST_NEEDED://`)
- 23 images (16 verified CC0/Unsplash from 4 GitHub repos, 7 placeholders)

**Verified source repos** (all 200 OK at time of writing):

- `rose-pine/wallpapers` (CC0) — 8 entries
- `sheepla/wallpapers` (CC0) — 7 entries
- `pop-os/wallpapers` (Unsplash photos only, public domain) — 4 entries
- `swaywm/sway/assets` (CC0) — 1 entry
- `zhongzachary/sonoma-screen-savers` (Apple Aerials via sylvan.apple.com) — 6 entries

**Placeholder convention**: URLs start with `PLACEHOLDER_SELFHOST_NEEDED://…`
for items not yet hosted. The `AssetFile` decoder maps these to a sentinel
`about:invalid?…` URL. The gallery **hides** items whose URL has `scheme == "about"`.

### Verification

```sh
cd library
python3 generate_manifest.py    # regenerate from Python source
python3 verify_urls.py          # HTTP-HEAD every URL; exit 1 on any failure
```

### Resolving the manifest URL at runtime
`LibraryStore.init` resolution order (first non-nil wins):
1. Explicit argument
2. `OPENENGINE_MANIFEST` env var
3. `Bundle.main.url(forResource: "manifest", withExtension: "json")` (bundled)
4. GitHub raw URL (network default for dev)

## 4. Build & Run

```sh
cd /Users/coeng24/Projects/OpenEngine
swift build              # debug build
swift run                # debug build + launch directly (no .app bundle)
./make_app.sh            # release build + bundle + sign
open build/OpenEngine.app
```

`make_app.sh`:
1. Runs `swift build -c release`
2. Creates `build/OpenEngine.app/Contents/{MacOS,Resources}/`
3. Copies the binary, the `Info.plist`, and `library/manifest.json`
4. Writes a `launch.sh` wrapper that sets `OPENENGINE_MANIFEST` env var

**Note**: SwiftPM `.process("Resources")` produces a `OpenEngine_OpenEngineApp.bundle`
inside `.build/`, but the `make_app.sh` step also copies `manifest.json` directly
into `Contents/Resources/` so `Bundle.main.url(forResource:)` finds it. Both paths
work.

## 5. Known Bugs and Fix List

### Bug A — RESOLVED: LibraryStore.swift syntax error
Fixed by the previous agent. See [Section 6.1](#61-download-progress-bar--done) for progress-bar wiring.

### Bug B — PARTIALLY FIXED: Wallpaper videos don't play
Two issues found and fixed in `WallpaperSurface.applyVideo(_:)`:

1. **Broken loop re-insertion**: The `AVPlayerItemDidPlayToEndTime` observer
   sought the finished item to `t=0` but never re-inserted it into the
   `AVQueuePlayer`. After both items played once, the queue was empty and
   playback stopped. Fixed: the seek completion handler now calls
   `player.insert(finished, after: player.items().last)` to re-queue the
   item at the tail, keeping the queue never-empty as designed.
2. **Stale `bounds.origin`**: Setting `host.frame = screen.frame` updates
   `bounds.size` but leaves `bounds.origin` unchanged, so `AVPlayerLayer`
   could end up offset by a stale origin. Fixed: explicitly set
   `host.bounds = CGRect(origin: .zero, size: screen.frame.size)` before
   sizing the `AVPlayerLayer` from `host.bounds`.

**Phase 2 fix**: `buildWindow` no longer replaces the backing layer with a
bare `CALayer()`. AppKit's auto-created backing layer is properly connected
to the Core Animation render tree; a bare `CALayer()` replacement worked for
static images (`CALayer.contents` goes through AppKit's drawing pass) but
broke `AVPlayerLayer`'s dynamic rendering path.

**Status**: Despite the above fixes, video wallpaper still does not play on
the desktop. `NSLog` instrumentation is in place
(`applyVideo` logs URL, file existence, host bounds, queue rate,
itemA.status; `apply` logs idempotency checks). The issue may be related to
AppKit layer hierarchy, window level, or video composition on macOS 26.
Needs runtime verification on a real desktop session.

### Bug C — FIXED: Lock screen is black
Same frame/bounds fix as Bug B. The platform limitation remains: macOS's real
lock-screen image is owned by `loginwindow`, and there is no public API for
sandboxed apps to set it on macOS 14. On macOS 26+,
`NSWorkspace.shared.setDesktopImageURL(_:for:options:)` with
`NSWorkspace DesktopOptions.allowSettingDesktopImageOnLockScreen` (if available)
may enable true lock-screen support — untested on macOS 26 hardware.

**Disclaimers added**:
- `WallpaperTabPage.Header` shows a note when `scope == .lockScreen`.
- `README.md` documents the macOS 26+ requirement for true lock-screen
  live wallpaper support; macOS 14/15 uses best-effort window-level preview.

### Bug D — `LSUIElement=false` but app is set up like a background helper
The app has `LSUIElement=false` (regular Dock app) AND `MenuBarExtra`. That's
intentional — user opens the GUI window, but the engine keeps running via
menu-bar quick controls. Verify behavior matches user expectation.

## 6. Recently Added Features

### 6.1 Download progress bar — DONE (both GalleryView and WallpaperTabPage)
`OEEngine.previewItem(_:as:)` now passes a closure to
`store.resolvedLocalURL(for:progress:)` that dispatches `downloadProgress`
updates to the main thread (via `DispatchQueue.main.async`). `downloadProgress`
is reset to 0 on start, set to 1 on completion, and reset to 0 on error.
`GalleryView` shows a linear `ProgressView` at the top of the grid when
`0 < downloadProgress < 1`. `WallpaperTabPage` (used by both Wallpaper and
Lock Screen tabs) also shows the same progress bar between the `Header` and
the Library/gallery grid.

### 6.2 Additional wallpaper resource — DONE (option a)
Added an "External wallpaper resources" section to both `README.md` and
`library/README.md` pointing users at [mylinuxforwork/wallpaper](https://github.com/mylinuxforwork/wallpaper)
as a GPLv2 resource to clone locally and load via the file picker. OpenEngine
remains MIT-only.

### 6.3 Cache management — DONE
- `LibraryStore.isCached(for:)` and `deleteCachedAsset(for:)` public methods
  added — file existence check and `FileManager.default.removeItem(at:)`.
- `OEEngine.isCached(_:)` and `deleteLocalCopy(of:)` convenience methods
  added — call through to `LibraryStore` and trigger `objectWillChange.send()`
  for SwiftUI re-render.
- `WallpaperTabPage` shows cached items under a "Library" heading with
  "Delete local copy" context-menu items and `isCurrent` checkmark badges.

### 6.4 Gallery → Browse rename — DONE
Renamed `SidebarTab.gallery` → `SidebarTab.browse` ("Browse"). Updated
`systemImage` switch, `selectedTab` default, and body switch case. The
sidebar now shows a list icon (`.` circle) instead of a rectangle.

### 6.5 PreviewTile isCurrent indicator — DONE
Added `isCurrent: Bool` parameter (default `false`) with `public init` to
`PreviewTile`. Checkmark badge overlay in `.topTrailing` alignment in the ZStack.

### 6.6 WallpaperTabPage visual separation — DONE
Added `Divider()` between "Library" subsection and "Browse All" gallery grid
in `WallpaperTabPage`, shown only when both sections have content.

### 6.7 buildWindow backing-layer fix — DONE (Phase 2)
Removed `w.contentView?.layer = CALayer()` replacement in `buildWindow`.
The auto-created backing layer (`_NSViewBackingLayer`) is properly connected
to the CA render tree. A bare `CALayer()` replacement worked for static
`contents` (images) but broke `AVPlayerLayer`'s dynamic rendering path.

### 6.8 LoopingVideoPlayer fix — DONE (Phase 2)
Replaced broken two-item `AVQueuePlayer` queue with `AVPlayerLooper` in
`LoopingVideoPlayer.makePlayer()`. The old code had no observer to re-insert
items after they finished — after both items played, the queue emptied and
previews went black. `AVPlayerLooper` handles re-insertion automatically.

### 6.9 Bundle target upgrade — DONE (Phase 2)
Upgraded `Package.swift` to `swift-tools-version: 6.2`, `.macOS(.v26)`. Used
`.swiftLanguageMode(.v5)` per-target to avoid Swift 6 strict-concurrency
errors from macOS 26 SDK's `@MainActor` annotations on AppKit types.
`@preconcurrency import AppKit` added to `WallpaperSurface.swift` and
`WallpaperController.swift`.

## 7. Things That Already Work

- Build pipeline (Phase 2: zero warnings with `.swiftLanguageMode(.v5)`)
- App launches as a proper Dock app (foreground process)
- Window appears via NavigationSplitView with sidebar (Browse / Wallpaper / Lock Screen / Settings)
- Manifest loads from bundled copy (works offline)
- Gallery shows 26 verified items (7 placeholders are hidden)
- Static image wallpapers apply correctly (sits at `kCGDesktopWindowLevel`, behind icons, behind all app windows, mouse passes through)
- Battery policy reads IOKit, ticks every 60s
- Pause on `willSleep`, resume on `didWake`
- Attribution sheet shows license/author/source for each item
- Custom file picker (`fileImporter` in Settings)
- Settings persist to `~/Library/Application Support/OpenEngine/settings.json`
- Launch-at-login via LaunchAgent + `SMAppService.register()`
- Download progress bar shows during asset downloads (GalleryView and WallpaperTabPage)
- Cache management: cached items listed under "Library" heading with delete context-menu items
- `isCurrent` checkmark badges on currently-applied items in both GalleryView and WallpaperTabPage
- Gallery previews loop with `AVPlayerLooper` (no black-screen after 10s)

## 8. Quality / Style Notes

- **Concurrency**: `swift-tools-version: 6.2` with `.macOS(.v26)`. Per-target
  `.swiftLanguageMode(.v5)` avoids Swift 6 strict-concurrency errors from
  macOS 26 SDK's `@MainActor` annotations on AppKit types.
  `@preconcurrency import AppKit` on `WallpaperSurface.swift` and
  `WallpaperController.swift` suppresses remaining diagnostics.
- **SDKS**: this machine only has CommandLineTools SDK (no full Xcode).
  Several Apple APIs are *missing* in the SDK headers — e.g.,
  `CGWindowLevelKey.desktopIconWindowLevel` doesn't exist as a case name in
  this SDK, even though `CGWindowLevelForKey(.desktopWindow)` does. Always
  `swift build` after edits; missing symbols show up immediately.
- **Comments**: Prefer detailed ASCII comments. The codebase has several
  multi-line block comments explaining engine rationale.
- **Library conventions**:
  - Public APIs use `public` keyword, lowercase camelCase.
  - `OELibraryItem` (not `LibraryItem`) — renamed to avoid clash with
    `DeveloperToolsSupport.LibraryItem`.
  - Date decoding is lenient (accepts ISO-8601 string, Unix epoch Double,
    or empty string).

## 9. Test Plan

```sh
swift build              # should succeed, zero warnings
./make_app.sh
xattr -cr build/OpenEngine.app
codesign -s - --deep --force build/OpenEngine.app
open build/OpenEngine.app
```

Then image wallpaper:
```sh
# Click any image tile in the gallery → "Apply to Wallpaper"
# Confirm: image appears behind all open windows, icons, Dock.
# Open an app window on top — wallpaper should be visible behind it.
# Click on the desktop — selection/launch should still work.
```

Then video wallpaper:
```sh
# Click any video tile → "Apply to Wallpaper"
# Confirm: video plays on the desktop, no jitter at loop seam.
# Debug: log stream --predicate 'eventMessage CONTAINS "OpenEngine"' --info
```

Then battery / pause:
```sh
# Press cmd+ctrl+q to lock screen → wallpaper should pause
# Wake screen → wallpaper should resume
```

Then library:
```sh
cd library
python3 verify_urls.py  # all 52 verified URLs should pass; placeholders skipped
```

## 10. Files Most Likely To Need Edits Next

1. `Sources/WallpaperKit/WallpaperSurface.swift` — **CRITICAL**: video wallpaper
   does not play on desktop despite loop re-insertion + layer fixes. The
   `NSLog` instrumentation is in place (lines 123-130, 185, 245-256). Need
   runtime test with `log stream` on a real macOS desktop session. Possible
   issues: layer hierarchy, window level, video composition, or
   `AVPlayerLayer` not being on the render tree.
2. `Sources/WallpaperKit/WallpaperController.swift` — multi-display support
   (`refreshScreens` stubbed at line 127; `attachAutoResume` no-op at line 100).
   Currently creates one surface on `NSScreen.main` only.
3. `Sources/OpenEngineApp/OpenEngineApp.swift` — lock-screen approach: research
   `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` with
   `allowSettingDesktopImageOnLockScreen` on macOS 26. Document limitation
   in README if not available.

## 11. Useful Commands

```sh
# Watch logs while testing (NSLog instrumentation)
log stream --predicate 'eventMessage CONTAINS "OpenEngine"' --info

# Clean rebuild
swift package clean
swift build

# Force re-bundle of resources
swift build --target OpenEngineApp
cp library/manifest.json Sources/OpenEngineApp/Resources/manifest.json

# Inspect the bundled manifest
xxd build/OpenEngine.app/Contents/Resources/manifest.json | head -1

# Verify app is unsigned / signed
codesign -dv build/OpenEngine.app

# Check process is alive after launch
ps -ef | grep OpenEngine | grep -v grep
```

## 12. Summary for the Next Agent

All Phase 1 and Phase 2 work is complete:

- **Bug A (syntax error)**: Fixed. Build passes.
- **Bug B (videos don't play)**: Partially fixed — loop re-insertion logic
  corrected (the `AVPlayerItemDidPlayToEndTime` observer now calls
  `insert(after:)` to re-queue the finished item) and explicit `bounds`
  setting prevents stale origin offsets. `buildWindow` no longer replaces
  the backing layer. **CRITICAL**: Video still doesn't play on desktop —
  needs runtime investigation with the existing NSLog instrumentation.
- **Bug C (lock screen)**: Fixed — same frame/bounds fix as Bug B, plus
  disclaimer banner in Lock Screen tab header, plus README documentation of
  macOS 26+ limitation for true lock-screen live wallpaper.
- **Section 6.1 (progress bar)**: Done — wired `downloadProgress` through
  `OEEngine.previewItem` and added `ProgressView` to both `GalleryView` and
  `WallpaperTabPage`.
- **Section 6.2 (mylinuxforwork)**: Done — documented as external resource
  in both `README.md` and `library/README.md`.
- **Section 6.3–6.8 (Phase 2 features)**: Cache management APIs, Gallery→Browse
  rename, `isCurrent` checkmark badges, Library subsection, buildWindow
  backing-layer fix, LoopingVideoPlayer `AVPlayerLooper` fix, bundle target
  upgrade to macOS 26, visual separator in WallpaperTabPage.

**Remaining**: Multi-display support (`WallpaperController.refreshScreens` is
stubbed), Bug B's video loop needs runtime verification on a real macOS
desktop session, lock-screen approach needs macOS 26 API evaluation.
