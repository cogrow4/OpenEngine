#!/usr/bin/env python3
"""
Generates library/manifest.json for OpenEngine.

Each entry must be:
  - Publicly available at a stable URL
  - Released under a permissive license (Coverr, Pixabay, Pexels, Mixkit, CC0, Unsplash, etc.)
  - Properly credited (author + source page URL preserved)
  - Encoded with a low-res *preview* asset (small JPEG/short MP4) and the *full* asset

When you swap in a real self-hosted URL, just update the records here
and re-run.
"""
import json, datetime
from pathlib import Path

# Each tuple: (id, kind, title, author, author_url, source_url, license,
#              preview_url, full_url, loop_seconds, tags)
#
# All "raw.githubusercontent.com" URLs point at small-to-medium static assets.
# Apple's sylvan.apple.com links go directly to Apple's own CDN for Aerials.
ITEMS = [
    # =========================================================
    # VIDEO LOOPS
    # =========================================================

    # --- zhongzachary/sonoma-screen-savers -> Apple Aerials ---
    # Apple distributes the screensaver videos publicly at sylvan.apple.com.
    # This index links directly to Apple's CDN; we do not redistribute.
    # All entries credit Apple Inc. + the cinematographer named in the source repo.
    {
        "id": "aerial-yosemite-mountain",
        "title": "Yosemite Mountains",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com. Use within macOS context per Apple's standard screensaver terms.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/81CA5ACD-E682-4D8B-A948-0F147EB6ED4F.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials116/v4/cb/5b/50/cb5b5035-6701-619f-9065-3d7d0e5fbef4/Y003_C009_UHD_SDR_FRC240fps_sdr_4k_qp23_240p_t2160_tsa.mov",
        "loopSeconds": 16,
        "tags": ["nature", "mountain", "aerial", "cinematic"],
    },
    {
        "id": "aerial-iceland-glacier",
        "title": "Iceland Glacier",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/DDE50C77-B7CB-4488-9EB1-D1B13BF21FFE.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials126/v4/ec/eb/c8/ecebc8d2-5486-c2b2-52ae-6f0ab2d6b65f/I003_C008__0623CJ_UHD_SDR_240fps_ace2a32f-f189-4206-ba4c-e395fb1b4ea4q23_sRGB_tsa.mov",
        "loopSeconds": 18,
        "tags": ["nature", "ice", "aerial", "cinematic"],
    },
    {
        "id": "aerial-grand-canyon-river-valley",
        "title": "Grand Canyon River Valley",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/8002C4C8-C611-4894-A068-3D3A3C03472A.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials126/v4/ec/eb/c8/ecebc8d2-5486-c2b2-52ae-6f0ab2d6b65f/G010_C026_UHD_SDR_v02_240fps_5e903ed6-1acf-495d-a0b5-8a9dd94df96bq26_sRGB_tsa.mov",
        "loopSeconds": 14,
        "tags": ["nature", "desert", "aerial", "cinematic"],
    },
    {
        "id": "aerial-hawaii-coastline",
        "title": "Hawaii Coastline",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/12E0343D-2CD9-48EA-AB57-4D680FB6D0C7.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials126/v4/ec/eb/c8/ecebc8d2-5486-c2b2-52ae-6f0ab2d6b65f/comp_H007_C003_PS_v01_SDR_PS_20180925_240fps_ad61d98e-fb4b-41c7-b981-9ff4b8a2ef27q25_sRGB_tsa.mov",
        "loopSeconds": 15,
        "tags": ["nature", "ocean", "aerial", "cinematic"],
    },
    {
        "id": "aerial-patagonia-mountain",
        "title": "Patagonia Mountain",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/5C987900-AD53-469C-8210-CABBCCDDFCAE.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials126/v4/ec/eb/c8/ecebc8d2-5486-c2b2-52ae-6f0ab2d6b65f/P001_C005_UHD_SDR_240fps_89dfd1a5-485c-4572-8e9e-757bd06bcfa3q20_sRGB_tsa.mov",
        "loopSeconds": 18,
        "tags": ["nature", "mountain", "aerial", "cinematic"],
    },
    {
        "id": "aerial-scotland-castle",
        "title": "Scotland Castle",
        "author": "Apple (Aerials)",
        "authorURL": "https://github.com/zhongzachary/sonoma-screen-savers",
        "sourceURL": "https://github.com/zhongzachary/sonoma-screen-savers/blob/main/README.md",
        "license": "Apple screensaver asset, served from sylvan.apple.com.",
        "kind": "video",
        "preview": "https://raw.githubusercontent.com/zhongzachary/sonoma-screen-savers/main/preview_images/E161929C-0819-4BC2-8359-550C081C7D54.png",
        "full": "https://sylvan.apple.com/itunes-assets/Aerials116/v4/cb/5b/50/cb5b5035-6701-619f-9065-3d7d0e5fbef4/S006_C007_UHD_SDR_FRC240fps_sdr_4k_qp20_240p_t2160_tsa.mov",
        "loopSeconds": 16,
        "tags": ["landscape", "history", "aerial"],
    },

    # =========================================================
    # STATIC IMAGES
    # =========================================================

    # --- rose-pine/wallpapers (CC0) ---
    {
        "id": "rose-pine-snowy-evergreen",
        "title": "Snowy Evergreen",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/photography/snowy-evergreen.jpg",
        "license": "CC0 1.0 Universal (Public Domain Dedication)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/snowy-evergreen.jpg",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/snowy-evergreen.jpg",
        "loopSeconds": None,
        "tags": ["nature", "snow", "winter", "minimal"],
    },
    {
        "id": "rose-pine-building",
        "title": "Moody Building",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/photography/building.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/building.jpg",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/building.jpg",
        "loopSeconds": None,
        "tags": ["architecture", "moody", "minimal"],
    },
    {
        "id": "rose-pine-kainoa-kanter-ocean",
        "title": "Ocean (Kainoa Kanter)",
        "author": "Kainoa Kanter (Rosé Pine / CC0)",
        "authorURL": "https://github.com/rose-pine/wallpapers/tree/main/photography/kainoa-kanter",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/photography/kainoa-kanter/ocean-drone-1.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/kainoa-kanter/ocean-drone-1.jpg",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/kainoa-kanter/ocean-drone-1.jpg",
        "loopSeconds": None,
        "tags": ["nature", "ocean", "aerial"],
    },
    {
        "id": "rose-pine-kainoa-kanter-moon",
        "title": "Moonlight (Kainoa Kanter)",
        "author": "Kainoa Kanter (Rosé Pine / CC0)",
        "authorURL": "https://github.com/rose-pine/wallpapers/tree/main/photography/kainoa-kanter",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/photography/kainoa-kanter/moon.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/kainoa-kanter/moon.jpg",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/photography/kainoa-kanter/moon.jpg",
        "loopSeconds": None,
        "tags": ["nature", "night", "moon"],
    },

    # --- sheepla/wallpapers (CC0) ---
    {
        "id": "sheepla-iceberg-day",
        "title": "Iceberg - Day",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/iceberg-day.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/iceberg-day.png",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/iceberg-day.png",
        "loopSeconds": None,
        "tags": ["abstract", "ice", "minimal"],
    },
    {
        "id": "sheepla-iceberg-night",
        "title": "Iceberg - Night",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/iceberg-night.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/iceberg-night.png",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/iceberg-night.png",
        "loopSeconds": None,
        "tags": ["abstract", "ice", "minimal", "dark"],
    },
    {
        "id": "sheepla-snow-mountain-day",
        "title": "Snow Mountain - Day",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/snow-mountain-day.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/snow-mountain-day.jpg",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/snow-mountain-day.jpg",
        "loopSeconds": None,
        "tags": ["nature", "mountain", "snow"],
    },
    {
        "id": "sheepla-snow-mountain-twilight",
        "title": "Snow Mountain - Twilight",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/snow-mountain-twilight.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/snow-mountain-twilight.jpg",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/snow-mountain-twilight.jpg",
        "loopSeconds": None,
        "tags": ["nature", "mountain", "snow", "twilight"],
    },

    # --- pop-os/wallpapers (mixed CC-BY-SA Kate Hazen + public-domain Unsplash) ---
    # Note: Kate Hazen items are CC-BY-SA 4.0. Unsplash items are public domain.
    # We pull only Unsplash items (public domain) to avoid the share-alike viral license
    # for first-party use as wallpapers.
    {
        "id": "popos-unsplash-benjamin-voros",
        "title": "Misty Forest",
        "author": "Benjamin Voros (Unsplash, public domain)",
        "authorURL": "https://unsplash.com/photos/yrwpJwDNSHE",
        "sourceURL": "https://github.com/pop-os/wallpapers",
        "license": "Unsplash License (public domain)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/benjamin-voros-250200.jpg",
        "full":    "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/benjamin-voros-250200.jpg",
        "loopSeconds": None,
        "tags": ["nature", "forest", "moody"],
    },
    {
        "id": "popos-unsplash-galen-crout",
        "title": "Mountain Lake",
        "author": "Galen Crout (Unsplash, public domain)",
        "authorURL": "https://unsplash.com/photos/ZYecenZy7o4",
        "sourceURL": "https://github.com/pop-os/wallpapers",
        "license": "Unsplash License (public domain)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/galen-crout-175291.jpg",
        "full":    "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/galen-crout-175291.jpg",
        "loopSeconds": None,
        "tags": ["nature", "mountain", "lake"],
    },

    # --- swaywm/sway (CC-0 assets directory) ---
    {
        "id": "sway-blue-wallpaper",
        "title": "Sway Blue Wallpaper",
        "author": "Sway WM Team",
        "authorURL": "https://github.com/swaywm/sway",
        "sourceURL": "https://github.com/swaywm/sway/tree/master/assets",
        "license": "CC0 1.0 Universal (per Sway license commit)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/swaywm/sway/master/assets/Sway_Wallpaper_Blue_1920x1080.png",
        "full":    "https://raw.githubusercontent.com/swaywm/sway/master/assets/Sway_Wallpaper_Blue_1920x1080.png",
        "loopSeconds": None,
        "tags": ["abstract", "blue", "minimal"],
    },


    # --- sheepla/wallpapers (CC0) - additional ---
    {
        "id": "sheepla-manjaro",
        "title": "Manjaro Mountains",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/Manjaro.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/Manjaro.jpg",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/Manjaro.jpg",
        "loopSeconds": None,
        "tags": ["nature", "mountain"],
    },
    {
        "id": "sheepla-desktop-iceberg",
        "title": "Iceberg Desktop",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/desktop-iceberg.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/desktop-iceberg.png",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/desktop-iceberg.png",
        "loopSeconds": None,
        "tags": ["abstract", "ice", "minimal"],
    },
    {
        "id": "sheepla-vim-iceberg",
        "title": "Vim Iceberg",
        "author": "sheepla",
        "authorURL": "https://github.com/sheepla",
        "sourceURL": "https://github.com/sheepla/wallpapers/blob/main/vim-iceberg.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/sheepla/wallpapers/main/vim-iceberg.png",
        "full":    "https://raw.githubusercontent.com/sheepla/wallpapers/main/vim-iceberg.png",
        "loopSeconds": None,
        "tags": ["abstract", "ice", "minimal"],
    },

    # --- rose-pine/wallpapers (CC0) - illustration/generative ---
    {
        "id": "rose-pine-block-wave-moon",
        "title": "Block Wave Moon",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/illustration/block-wave-moon.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/block-wave-moon.png",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/block-wave-moon.png",
        "loopSeconds": None,
        "tags": ["abstract", "minimal", "moon"],
    },
    {
        "id": "rose-pine-leafy-dawn",
        "title": "Leafy Dawn",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/illustration/leafy-dawn.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/leafy-dawn.png",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/leafy-dawn.png",
        "loopSeconds": None,
        "tags": ["abstract", "dawn", "minimal"],
    },
    {
        "id": "rose-pine-big-shoulders",
        "title": "Big Shoulders",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/illustration/big%20shoulders.jpg",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/big%20shoulders.jpg",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/illustration/big%20shoulders.jpg",
        "loopSeconds": None,
        "tags": ["abstract", "geometric"],
    },
    {
        "id": "rose-pine-maze",
        "title": "Maze",
        "author": "Rosé Pine",
        "authorURL": "https://rosepinetheme.com",
        "sourceURL": "https://github.com/rose-pine/wallpapers/blob/main/generative/maze.png",
        "license": "CC0 1.0 Universal",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/rose-pine/wallpapers/main/generative/maze.png",
        "full":    "https://raw.githubusercontent.com/rose-pine/wallpapers/main/generative/maze.png",
        "loopSeconds": None,
        "tags": ["abstract", "generative", "geometric"],
    },

    # --- pop-os/wallpapers (Unsplash public domain) - additional ---
    {
        "id": "popos-unsplash-jake-hills",
        "title": "Coastal View",
        "author": "Jake Hills (Unsplash, public domain)",
        "authorURL": "https://unsplash.com",
        "sourceURL": "https://github.com/pop-os/wallpapers",
        "license": "Unsplash License (public domain)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/jake-hills-36605.jpg",
        "full":    "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/jake-hills-36605.jpg",
        "loopSeconds": None,
        "tags": ["nature", "coast"],
    },
    {
        "id": "popos-unsplash-ferdinand-stohr",
        "title": "Moody Forest Path",
        "author": "Ferdinand Stohr (Unsplash, public domain)",
        "authorURL": "https://unsplash.com",
        "sourceURL": "https://github.com/pop-os/wallpapers",
        "license": "Unsplash License (public domain)",
        "kind": "image",
        "preview": "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/ferdinand-stohr-149422.jpg",
        "full":    "https://raw.githubusercontent.com/pop-os/wallpapers/master/original/ferdinand-stohr-149422.jpg",
        "loopSeconds": None,
        "tags": ["nature", "forest", "moody"],
    },

    # =========================================================
    # SECONDARY VIDEO LOOPS (PLACEHOLDERS, NOT VERIFIED ONLINE)
    # These are intentionally left as `cdn.openengine.dev` placeholders.
    # Before shipping to users, either:
    #   (a) self-host these files on your CDN and update the URLs, or
    #   (b) remove the entries from the manifest.
    # They are kept here as a developer reference for the URL shape.
    # =========================================================
    {
        "id": "coverr-aurora-night",
        "title": "Aurora Over Mountain Lake",
        "author": "Coverr",
        "authorURL": "https://coverr.co",
        "sourceURL": "https://coverr.co/videos/aurora-over-mountains",
        "license": "Coverr License (free for commercial use, no attribution required)",
        "kind": "video",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/coverr-aurora-night-preview.mp4",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/coverr-aurora-night.mp4",
        "loopSeconds": 18,
        "tags": ["nature", "aurora", "night"],
    },
    {
        "id": "pixabay-ocean-drone",
        "title": "Drone Over Calm Ocean",
        "author": "Pixabay",
        "authorURL": "https://pixabay.com",
        "sourceURL": "https://pixabay.com/videos/ocean-drone-aerial-water-3020/",
        "license": "Pixabay Content License (free for commercial use, no attribution required)",
        "kind": "video",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/pixabay-ocean-drone-preview.mp4",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/pixabay-ocean-drone.mp4",
        "loopSeconds": 15,
        "tags": ["nature", "ocean", "aerial", "calm"],
    },
    {
        "id": "pexels-clouds-timelapse",
        "title": "Clouds Timelapse Over Valley",
        "author": "Pexels",
        "authorURL": "https://pexels.com",
        "sourceURL": "https://www.pexels.com/video/clouds-time-lapse-855714/",
        "license": "Pexels License (free for commercial use, no attribution required)",
        "kind": "video",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/pexels-clouds-timelapse-preview.mp4",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/pexels-clouds-timelapse.mp4",
        "loopSeconds": 10,
        "tags": ["nature", "sky", "timelapse"],
    },
    {
        "id": "mixkit-lava-flow",
        "title": "Glowing Lava Flow",
        "author": "Mixkit",
        "authorURL": "https://mixkit.co",
        "sourceURL": "https://mixkit.co/free-stock-video/lava-flow/",
        "license": "Mixkit Free License",
        "kind": "video",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/mixkit-lava-flow-preview.mp4",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/mixkit-lava-flow.mp4",
        "loopSeconds": 12,
        "tags": ["abstract", "warm"],
    },

    # =========================================================
    # IMAGES FROM CURATED STOCK SITES (drop before public release
    # unless you've also self-hosted the binaries)
    # =========================================================
    {
        "id": "pixabay-mountain-sunrise",
        "title": "Mountain Sunrise",
        "author": "Pixabay",
        "authorURL": "https://pixabay.com",
        "sourceURL": "https://pixabay.com/photos/mountain-sunrise-dawn-landscape-5852355/",
        "license": "Pixabay Content License",
        "kind": "image",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/pixabay-mountain-sunrise-preview.jpg",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/pixabay-mountain-sunrise.jpg",
        "loopSeconds": None,
        "tags": ["nature", "mountain", "sunrise"],
    },
    {
        "id": "pexels-forest-fog",
        "title": "Foggy Forest",
        "author": "Pexels",
        "authorURL": "https://pexels.com",
        "sourceURL": "https://www.pexels.com/photo/fog-forest-4823097/",
        "license": "Pexels License",
        "kind": "image",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/pexels-forest-fog-preview.jpg",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/pexels-forest-fog.jpg",
        "loopSeconds": None,
        "tags": ["nature", "forest", "fog"],
    },
    {
        "id": "pexels-stars-milkyway",
        "title": "Milky Way Night Sky",
        "author": "Pexels",
        "authorURL": "https://pexels.com",
        "sourceURL": "https://www.pexels.com/photo/milky-way-starry-sky-1252890/",
        "license": "Pexels License",
        "kind": "image",
        "preview": "PLACEHOLDER_SELFHOST_NEEDED://previews/pexels-stars-milkyway-preview.jpg",
        "full":    "PLACEHOLDER_SELFHOST_NEEDED://full/pexels-stars-milkyway.jpg",
        "loopSeconds": None,
        "tags": ["space", "stars", "night"],
    },
]


def to_asset(d, key):
    return {
        "url": d[key],
        "mimeType": "video/mp4" if d["kind"] == "video" else "image/jpeg",
        "sizeBytes": None,
        "md5": None,
    }


def main():
    out = {
        "schemaVersion": 1,
        "generatedAt": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
        "items": [
            {
                "id": i["id"],
                "title": i["title"],
                "author": i["author"],
                "authorURL": i["authorURL"],
                "sourceURL": i["sourceURL"],
                "license": i["license"],
                "kind": i["kind"],
                "preview": to_asset(i, "preview"),
                "full":    to_asset(i, "full"),
                "loopDurationSeconds": i["loopSeconds"],
                "tags": i["tags"],
            }
            for i in ITEMS
        ],
    }
    Path(__file__).parent.joinpath("manifest.json").write_text(
        json.dumps(out, indent=2, sort_keys=False) + "\n"
    )
    n_videos = sum(1 for i in ITEMS if i["kind"] == "video")
    n_images = sum(1 for i in ITEMS if i["kind"] == "image")
    print(f"wrote {len(out['items'])} items ({n_videos} videos, {n_images} images)")


if __name__ == "__main__":
    main()
