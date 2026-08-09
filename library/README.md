# OpenEngine Library

The OpenEngine app is binary-thin; the catalog of wallpapers & loops lives
in this `library/` folder as a JSON manifest and is fetched at runtime by the app.
You can host this folder anywhere that serves JSON / media over HTTPS.

## Format

`manifest.json` follows this shape (see [`Spec`](#spec)). The schema version is
declared at the top so the app can evolve without breaking older installs.

```
{
  "schemaVersion": 1,
  "generatedAt": "ISO-8601",
  "items": [
    {
      "id":           "stable-slug",
      "title":        "Human-readable title",
      "author":       "Author/publisher name",
      "authorURL":    "optional URL to author page",
      "sourceURL":    "permanent URL to the source page",
      "license":      "License string, e.g. 'Pixabay Content License'",
      "kind":         "image" | "video",
      "preview":      { "url": "...", "mimeType": "...", "sizeBytes": null, "md5": "..." },
      "full":         { "url": "...", "mimeType": "...", "sizeBytes": null, "md5": "..." },
      "loopDurationSeconds": 18.0,
      "tags":         ["nature", "calm"]
    },
    ...
  ]
}
```

## Verified source repositories (all live, all permissive)

Every item currently shipped in `manifest.json` traces to one of these GitHub
repositories (or to Apple’s public screensaver CDN, served at `sylvan.apple.com`).
Each was hand-verified: the raw URLs returned HTTP 200 against
`raw.githubusercontent.com` at the time this README was written.

### Images

| Repo | License | Items in manifest | Link |
|------|---------|-------------------|------|
| `rose-pine/wallpapers`            | CC0 1.0  | 8  | https://github.com/rose-pine/wallpapers |
| `sheepla/wallpapers`              | CC0 1.0  | 6  | https://github.com/sheepla/wallpapers |
| `pop-os/wallpapers` (Unsplash images only) | Public domain (Unsplash) | 4 | https://github.com/pop-os/wallpapers |
| `swaywm/sway` (`assets/`)         | CC0 1.0  | 1  | https://github.com/swaywm/sway/tree/master/assets |

Note on `pop-os/wallpapers`: that repo contains two license families.
Kate Hazen’s illustrations are CC-BY-SA 4.0 (share-alike viral); Unsplash
photos used in the repo are public-domain. We include *only* the
public-domain Unsplash entries to avoid the share-alike clause for
first-party wallpaper use.

### Videos

| Source | License | Items in manifest | Link |
|--------|---------|-------------------|------|
| Apple Aerials (via `zhongzachary/sonoma-screen-savers` index) | Apple’s screensaver terms (served from `sylvan.apple.com`) | 6 | https://github.com/zhongzachary/sonoma-screen-savers |

The Aerials are Apple’s own public screensaver catalogue (Yosemite,
Iceland, Grand Canyon, Hawaii, Patagonia, Scotland, etc.). The third-party
index repo links directly to Apple’s CDN; OpenEngine does not
redistribute the binaries.

### Placeholders (do not ship without self-hosting)

The manifest also contains a small set of `PLACEHOLDER_SELFHOST_NEEDED://`
items. These document the URL shape for Coverr / Pixabay / Pexels / Mixkit
assets but require you to download and self-host the binary before shipping
the app, since the public CDN URLs are not stable.

## Generating the manifest

```sh
cd library/
python3 generate_manifest.py   # writes manifest.json from the hard-coded records
```

The records in `generate_manifest.py` are the *verified* source of truth —
each one has a known license and was HTTP-checked. To add an item:

1. Verify the file is permissively licensed (one of the sources above).
2. Add an entry to `ITEMS` in `generate_manifest.py` with the real source URL.
3. Re-run `generate_manifest.py`.
4. (Optional) Run `python3 -c '...'` to HTTP-HEAD every URL and confirm
   none of them 404 — see the verification snippet in
   [`VERIFICATION.md`](VERIFICATION.md).

## Self-hosting (recommended)

The default `manifestURL` in the app points at
`https://raw.githubusercontent.com/cogrow4/OpenEngine/main/library/manifest.json`.
To use your own host, set the `OPENENGINE_MANIFEST` environment variable when
launching the app — `LibraryStore` honors it for dev/QA.

## Integrity

Each `full` asset can declare an `md5` field; if present, downloaded files are
verified before being moved into the on-disk cache. The `generate_manifest.py`
helper can be extended to compute MD5s at publish time (see the inline comment).

## External wallpaper resources

[mylinuxforwork/wallpaper](https://github.com/mylinuxforwork/wallpaper) is a
community-curated collection of 212 wallpapers under CC0 / GPLv2. OpenEngine
does **not** bundle these — the GPLv2 license is viral and would complicate
shipping a binary under the MIT license. Clone the repo to a local folder and
use the app's file picker (Settings -> Choose File) to apply individual wallpapers.
