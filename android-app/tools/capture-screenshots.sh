#!/usr/bin/env bash
#
# Capture Play-Store-compliant phone screenshots from a connected device/emulator.
#
#   ./tools/capture-screenshots.sh 01-chat
#
# Play requires: PNG/JPEG, 320–3840 px per side, aspect ratio at most 2:1.
# Modern phones (and the Pixel emulator at 1344x2992 = 2.23:1) are TALLER than
# 2:1, so a raw screencap is rejected. This crops the bottom to exactly 2:1.
#
# Take these from a signed-in device so the listing shows the real product
# surfaces (chat, presentations, Ilovalar) rather than the login screen.
set -euo pipefail

NAME="${1:-shot}"
OUT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/store/screenshots"
mkdir -p "$OUT_DIR"

ADB="${ADB:-$HOME/Library/Android/sdk/platform-tools/adb}"
RAW="$OUT_DIR/.$NAME.raw.png"
OUT="$OUT_DIR/$NAME.png"

"$ADB" exec-out screencap -p > "$RAW"

python3 - "$RAW" "$OUT" <<'PY'
import sys
from PIL import Image

raw, out = sys.argv[1], sys.argv[2]
img = Image.open(raw).convert("RGB")
w, h = img.size

max_h = w * 2                      # Play's hard limit: aspect ratio <= 2:1
if h > max_h:
    img = img.crop((0, 0, w, max_h))

# Also respect the 3840px cap on the long edge.
if img.height > 3840:
    scale = 3840 / img.height
    img = img.resize((int(img.width * scale), 3840), Image.LANCZOS)

img.save(out)
print(f"{out}  {img.size[0]}x{img.size[1]}  ratio {img.size[1]/img.size[0]:.2f}:1")
PY

rm -f "$RAW"
