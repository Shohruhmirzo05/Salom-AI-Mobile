#!/usr/bin/env python3
"""Regenerate every Android raster asset from the brand artwork.

Sources (checked in under brand/, so this project has no dependency on the
retired Flutter module):
  brand/app-icon.png              opaque 1024 square
  brand/app-icon-transparent.png  same mark, alpha background

Outputs into app/src/main/res/. Re-run after any brand refresh:
    python3 tools/generate_icons.py
"""

import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
REPO = os.path.dirname(PROJECT)
RES = os.path.join(PROJECT, "app", "src", "main", "res")

SRC_OPAQUE = os.path.join(PROJECT, "brand", "app-icon.png")
SRC_ALPHA = os.path.join(PROJECT, "brand", "app-icon-transparent.png")

# Density buckets as multipliers of mdpi.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def out(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    return path


def solid_bbox(img, alpha_threshold=200):
    """Bounding box of the opaque core of the mark, ignoring the soft outer glow."""
    alpha = img.convert("RGBA").split()[3]
    mask = alpha.point(lambda a: 255 if a >= alpha_threshold else 0)
    return mask.getbbox()


def make_adaptive_foreground(src, size=432, safe_fraction=0.66):
    """Adaptive-icon foreground: the mark scaled so its solid core lands inside the
    72/108dp safe zone, centred on a transparent 108dp canvas."""
    img = src.convert("RGBA")
    bbox = solid_bbox(img)
    core_w, core_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    core = max(core_w, core_h)

    # Scale the WHOLE artwork by the factor that puts the core at safe_fraction.
    scale = (size * safe_fraction) / core
    new_size = max(1, int(round(img.width * scale)))
    scaled = img.resize((new_size, new_size), Image.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Centre on the CORE, not on the canvas — the glow is not symmetric.
    core_cx = (bbox[0] + bbox[2]) / 2 * scale
    core_cy = (bbox[1] + bbox[3]) / 2 * scale
    canvas.paste(scaled, (int(round(size / 2 - core_cx)), int(round(size / 2 - core_cy))), scaled)
    return canvas


def make_monochrome(src, size=432, safe_fraction=0.60):
    """Android 13+ themed-icon layer: flat silhouette of the mark's solid core."""
    img = src.convert("RGBA")
    bbox = solid_bbox(img)
    core = max(bbox[2] - bbox[0], bbox[3] - bbox[1])
    scale = (size * safe_fraction) / core

    alpha = img.split()[3].point(lambda a: 255 if a >= 200 else 0)
    silhouette = Image.new("RGBA", img.size, (255, 255, 255, 255))
    silhouette.putalpha(alpha)

    new_size = max(1, int(round(img.width * scale)))
    scaled = silhouette.resize((new_size, new_size), Image.LANCZOS)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    core_cx = (bbox[0] + bbox[2]) / 2 * scale
    core_cy = (bbox[1] + bbox[3]) / 2 * scale
    canvas.paste(scaled, (int(round(size / 2 - core_cx)), int(round(size / 2 - core_cy))), scaled)
    return canvas


def round_crop(img):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, img.size[0] - 1, img.size[1] - 1), fill=255)
    result = img.convert("RGBA")
    result.putalpha(mask)
    return result


def main():
    opaque = Image.open(SRC_OPAQUE).convert("RGBA")
    alpha = Image.open(SRC_ALPHA).convert("RGBA")
    print("solid core bbox:", solid_bbox(alpha), "of", alpha.size)

    # --- Legacy launcher icons (pre-API 26) --------------------------------
    for bucket, mult in DENSITIES.items():
        px = int(round(48 * mult))
        opaque.resize((px, px), Image.LANCZOS).convert("RGB").save(
            out(os.path.join(RES, f"mipmap-{bucket}", "ic_launcher.png")))
        round_crop(opaque.resize((px, px), Image.LANCZOS)).save(
            out(os.path.join(RES, f"mipmap-{bucket}", "ic_launcher_round.png")))

    # --- Adaptive icon layers (API 26+) ------------------------------------
    fg = make_adaptive_foreground(alpha)
    mono = make_monochrome(alpha)
    for bucket, mult in DENSITIES.items():
        px = int(round(108 * mult))
        fg.resize((px, px), Image.LANCZOS).save(
            out(os.path.join(RES, f"drawable-{bucket}", "ic_launcher_foreground.png")))
        mono.resize((px, px), Image.LANCZOS).save(
            out(os.path.join(RES, f"drawable-{bucket}", "ic_launcher_monochrome.png")))

    # --- Logo used on the native offline screen -----------------------------
    # (The Android 12+ system splash uses ic_launcher_foreground instead, via
    # windowSplashScreenAnimatedIcon in themes.xml.)
    for bucket, mult in DENSITIES.items():
        px = int(round(160 * mult))
        alpha.resize((px, px), Image.LANCZOS).save(
            out(os.path.join(RES, f"drawable-{bucket}", "splash.png")))

    # --- Notification small icon -------------------------------------------
    # Android masks this to a solid shape, so it must be white-on-transparent.
    # The name is not arbitrary: the OneSignal Android SDK looks for a drawable
    # called `ic_stat_onesignal_default` and falls back to the full-colour app
    # icon (which the system renders as a white blob) when it is missing.
    for bucket, mult in DENSITIES.items():
        px = int(round(24 * mult))
        mono.resize((px, px), Image.LANCZOS).save(
            out(os.path.join(RES, f"drawable-{bucket}", "ic_stat_onesignal_default.png")))

    # --- Play Store listing icon (512x512, no alpha) ------------------------
    opaque.resize((512, 512), Image.LANCZOS).convert("RGB").save(
        out(os.path.join(PROJECT, "store", "play-icon-512.png")))

    print("done")


if __name__ == "__main__":
    main()
