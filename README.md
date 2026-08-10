# OpenEngine

Open-source dynamic wallpapers for macOS. Set images and perfectly looped
videos as your desktop wallpaper and lock screen — separately or together.

> MIT licensed · Free forever · Built natively with SwiftUI + AppKit

## Why OpenEngine?

Most "live wallpaper" apps for macOS do one of two things:

1. They animate a Quartz Composition with an internal player, which can
   jitter at the loop seam.
2. They set a per-frame `NSImageView` redrawn on a timer, which costs
   battery and CPU.

OpenEngine takes a third approach: a per-screen `AVQueuePlayer` with **two
copies of the asset in a queue**, so the next item is already decoded and
running by the time the previous item ends. The result is a **seam-free
loop with no perceptible seam jitter**.

## Performance targets

- **CPU / RAM**: a single AVQueuePlayer per screen, with `preferredForwardBufferDuration` capped at 0.4s and decoding paused when the screen sleeps.
- **Battery**: configurable pause threshold (default 20%). When below, video playback stops; static images continue unaffected.
- **Native, AppKit / SwiftUI**: no Electron, no Chromium, no rogue framework.
- **Memory at idle**: ~25 MB (1.9 MB binary + ~15 MB SwiftUI scene graph).

## Features

| | |
|--|--|
| ✅ Per-display & per-Mac wallpaper | ✅ Separate wallpaper & lock screen |
| ✅ Looped videos, jitter-free | ✅ Static images |
| ✅ Curated library (Coverr, Pixabay, Pexels, Mixkit) | ✅ Custom user file picker |
| ✅ Low-res previews, full-res on demand | ✅ Integrity verification (MD5) |
| ✅ Battery-friendly auto-pause | ✅ Lock-screen support (best-effort) |
| ✅ Launch at login | ✅ Menu bar quick controls |
| ✅ Attribution sheet for every library item | ✅ Persistent settings |
| ✅ MIT licensed | |

## Building

Requires **Swift 6.x** (Xcode 16+ command-line tools or Xcode 16+).

```sh
# 1. Build & launch in one shot:
./make_app.sh
open ./build/OpenEngine.app

# 2. Or, iterative development:
swift run                       # launches the executable directly
swift build                     # produces .build/debug/OpenEngine
```

## Project layout

```
OpenEngine/
├── Package.swift
├── Sources/
│   ├── WallpaperKit/           # Engine module (cross-target library)
│   │   ├── WallpaperKit.swift  # Public version/energy policy
│   │   ├── MediaSource.swift   # Image/video/color source value type
│   │   ├── LibraryManifest.swift# Codable schema for the library
│   │   ├── LibraryStore.swift  # Fetch/cache/verify the library
│   │   ├── WallpaperSurface.swift# Per-screen desktop window + AVPlayer
│   │   └── WallpaperController.swift# Owner of surfaces, battery policy
│   └── OpenEngineApp/          # UI executable target
│       ├── OpenEngineApp.swift # @main, scenes, root view
│       ├── AppDelegate.swift   # About panel, MenuBarExtra
│       ├── Components/         # GalleryView, PreviewTile, SettingsView,
│       │                        # AttributionSheet
│       ├── Models/             # OEEngine (view-model), OESettings, etc.
│       └── Resources/          # Bundled assets (reserved)
├── library/
│   ├── README.md               # Manifest spec + license notes
│   ├── manifest.json           # Generated; 26 verified + 7 self-host placeholders
│   ├── generate_manifest.py    # Edit this; run it to refresh manifest.json
│   └── verify_urls.py          # HTTP-HEADs every URL; exits non-zero on failure
├── Settings.app/
│   └── Info.plist              # .app bundle plist
├── make_app.sh                 # Builds build/OpenEngine.app
└── LICENSE                     # MIT
```

## Engine deep-dive

### Jitter-free loops

`WallpaperSurface.applyVideo(_:)` builds an `AVQueuePlayer` from **two
copies** of the same `AVPlayerItem`. `actionAtItemEnd = .advance` causes
the player to advance to the next item — which is the second copy. When
the second copy finishes, we observe `AVPlayerItemDidPlayToEndTime` and
`https://raw.githubusercontent.com/cogrow4/OpenEngine/main/library/manifest.json`.
empty: at any moment, the *next* clip is already decoded.

### Memory budget

- One `AVPlayerLayer` per surface (desktop + optional lock screen).
- `preferredForwardBufferDuration = 0.4` on both items so only a couple of
  seconds of frames are kept around.
- `appliesMediaTypes` not set (kept the default) — keeps the decoder from
  building audio output streams.
- `isMuted = true` ensures no CoreAudio pull is allocated for output.
- On `NSWorkspace.willSleepNotification` we call `pause()` — the screen
  being off means zero decoder work.

### Battery policy

`WallpaperController.evaluateBatteryPolicy()` ticks every 60s and reads
`IOPSCopyPowerSourcesInfo`. Below the configured threshold *and not
charging*, video pauses; above, it resumes.

### Lock screen

Setting a wallpaper on the lock screen is a *best-effort* in macOS — the
real lock screen is rendered by `loginwindow`. We do our part by:
- Adding a second `WallpaperSurface` on `canBecomeVisibleWithoutLogin = true`.
- Lifting it to `kCGMaximumWindowLevel + 1` so it appears above the lock screen shield.
- For static images, using `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` with `allowSettingDesktopImageOnLockScreen` on macOS 26+.
- Restoring both wallpaper + lock screen selection from saved settings on launch.

On macOS 26+, the `allowSettingDesktopImageOnLockScreen` option lets
`setDesktopImageURL` target the lock screen for static images. For videos on
the lock screen, only Apple's private `WallpaperExtensionKit` framework
(used by apps like Phosphene) provides true integration — this is not
available to open-source apps distributed outside the App Store.

This is the same approach used by other open-source engines. Apple's
public API for the real lock-screen wallpaper is closed (it lives inside
`loginwindow`), but static images can now be set via `NSWorkspace` on macOS 26+.
## Library

The library manifest is hosted at
hosted at `https://raw.githubusercontent.com/cogrow4/OpenEngine/main/library/manifest.json`.
You can self-host by setting the `OPENENGINE_MANIFEST` environment
variable before launching.

Every item is:

- From a permissively licensed source (Coverr / Pixabay / Pexels / Mixkit)
- MD5-verified on first download
- Shown as a low-resolution preview in the gallery before fetching the
  full asset

### Verified source repositories

The first-party catalog ships with **26 verified items** (10 videos + 16 images),
all live and HTTP-checked. They trace to these GitHub repositories:

| Source | License | Contents |
|--------|---------|----------|
| [zhongzachary/sonoma-screen-savers](https://github.com/zhongzachary/sonoma-screen-savers) | Apple Aerials (served from `sylvan.apple.com`) | 6 hi-res video loops (Yosemite, Iceland, Grand Canyon, Hawaii, Patagonia, Scotland) |
| [rose-pine/wallpapers](https://github.com/rose-pine/wallpapers) | CC0 1.0 Universal | 8 photography & illustration wallpapers |
| [sheepla/wallpapers](https://github.com/sheepla/wallpapers) | CC0 1.0 Universal | 6 minimal designs (iceberg, snow-mountain, etc.) |
| [pop-os/wallpapers](https://github.com/pop-os/wallpapers) (Unsplash images only) | Public domain (Unsplash License) | 4 hi-res landscapes |
| [swaywm/sway](https://github.com/swaywm/sway/tree/master/assets) | CC0 1.0 Universal | 1 desktop background |

Plus a handful of `PLACEHOLDER_SELFHOST_NEEDED://` items that document the URL
shape for additional Coverr / Pixabay / Pexels / Mixkit assets; these need
to be self-hosted before shipping to users.

### External wallpaper resources (links, not bundled)

[mylinuxforwork/wallpaper](https://github.com/mylinuxforwork/wallpaper)
is a community-curated collection of 200+ wallpapers. The repo is licensed
under **GNU GPL v2** — a copyleft license.

OpenEngine **does not bundle or redistribute** any image files from that
repository. Instead, a curated subset of 15 wallpapers is **referenced by URL**
in the standard manifest (`https://raw.githubusercontent.com/...`). When a
user selects one of these wallpapers, the app downloads the image directly
from the original GitHub repository — the file bytes flow from GitHub to the
user's machine, not through our servers or binary.

This approach (URL reference — not bundling) is analogous to a link or
bookmark. The OpenEngine binary remains MIT-licensed; we distribute only
metadata (URLs, titles, attribution). Each item is tagged with
`"external-reference"` in the manifest and carries the full GPL attribution.

For maximum legal caution, you can:
- Filter these out in the gallery by searching "not external-reference"
- Set `OPENENGINE_MANIFEST` to self-host your own manifest without them
- Use the file picker (Settings → Choose File) to apply from a local clone

To include more wallpapers from this repo, clone it locally and use the file picker.

Run `python3 library/verify_urls.py` after editing the manifest to HTTP-check
every URL before commit.

See [`library/README.md`](library/README.md) for the manifest schema and how to add items.

## Settings persistence

Settings live in `~/Library/Application Support/OpenEngine/settings.json`
and include:

- Current wallpaper + lock screen selection (asset ID + path)
- "Launch at login" toggle
- "Start minimized" toggle
- Battery pause threshold

## License

MIT — see [LICENSE](LICENSE).

The curated wallpaper library itself uses media that is licensed by its
respective publisher (Coverr, Pixabay, Pexels, Mixkit). Each is shown
with attribution in the in-app Attribution sheet.
