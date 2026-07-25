#!/usr/bin/env python3
"""Generate the Play Store graphic assets that can be produced from the brand mark.

Outputs into ../store/:
  play-icon-512.png     512x512, no alpha        (Play "App icon")
  feature-graphic.png   1024x500, no alpha       (Play "Feature graphic")

Screenshots are captured separately from a real device — see capture-screenshots.sh.
"""

import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
REPO = os.path.dirname(PROJECT)
STORE = os.path.join(PROJECT, "store")

SRC_OPAQUE = os.path.join(PROJECT, "brand", "app-icon.png")
SRC_ALPHA = os.path.join(PROJECT, "brand", "app-icon-transparent.png")

BG = (7, 10, 18)
CYAN = (70, 190, 241)
PURPLE = (168, 85, 247)


def load_font(size, bold=True):
    """Best-effort system font; falls back to PIL's bitmap font."""
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold
        else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/SFNS.ttf",
        "/Library/Fonts/Arial Bold.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def radial_glow(size, centre, radius, colour, strength=0.55):
    """Soft coloured glow, used to echo the mark's own lighting on the banner."""
    w, h = size
    layer = Image.new("RGB", size, (0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cx, cy = centre
    draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius),
                 fill=tuple(int(c * strength) for c in colour))
    return layer.filter(ImageFilter.GaussianBlur(radius * 0.55))


def feature_graphic():
    w, h = 1024, 500
    canvas = Image.new("RGB", (w, h), BG)

    # Two brand glows, mirroring the cyan/purple lighting inside the mark itself.
    canvas = Image.blend(canvas, Image.new("RGB", (w, h), BG), 0)
    for centre, colour in (((250, 260), CYAN), ((720, 200), PURPLE)):
        glow = radial_glow((w, h), centre, 260, colour)
        canvas = Image.blend(canvas, Image.blend(canvas, glow, 1.0), 0.32)

    mark = Image.open(SRC_ALPHA).convert("RGBA").resize((300, 300), Image.LANCZOS)
    canvas.paste(mark, (86, 100), mark)

    draw = ImageDraw.Draw(canvas)
    draw.text((424, 176), "Salom AI", font=load_font(76), fill=(255, 255, 255))
    draw.text((426, 274), "O‘zbekcha sun’iy intellekt", font=load_font(34, bold=False),
              fill=(190, 200, 220))

    os.makedirs(STORE, exist_ok=True)
    out = os.path.join(STORE, "feature-graphic.png")
    canvas.save(out)
    print("wrote", out)


def store_icon():
    os.makedirs(STORE, exist_ok=True)
    out = os.path.join(STORE, "play-icon-512.png")
    Image.open(SRC_OPAQUE).convert("RGB").resize((512, 512), Image.LANCZOS).save(out)
    print("wrote", out)


if __name__ == "__main__":
    store_icon()
    feature_graphic()
