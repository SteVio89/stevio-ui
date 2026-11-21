#!/usr/bin/env python3
"""Writes Media/StripMask.tga, the mask of the minimap strip (Modules/Minimap/Strip.lua).

The minimap is a square as wide as the strip, centred on the player's arrow.
Only a band is visible: `height` above the arrow and `behind` below it, fading
out towards the left and right ends. Run it again after changing these values
in Modules/Minimap/Config.lua (strip.width, strip.height, strip.behind,
strip.maskFade):

    python3 tools/strip_mask.py [width height behind fade]
"""

import struct
import sys
from pathlib import Path

SIZE = 512


def coverage(start, end, pixel):
    """How much of pixel row/column `pixel` (0..SIZE) lies within start..end."""
    return max(0.0, min(end, pixel + 1) - max(start, pixel))


def main():
    width, height, behind, fade = (float(v) for v in (sys.argv[1:] or ["640", "88", "8", "0.25"]))
    scale = SIZE / width
    centre = SIZE / 2
    top, bottom = centre - height * scale, centre + behind * scale
    fade_px = fade * centre

    pixels = bytearray()
    # TGA rows run bottom to top unless the descriptor says otherwise; it does.
    for y in range(SIZE):
        row_alpha = coverage(top, bottom, y)
        for x in range(SIZE):
            edge = min(x + 0.5, SIZE - x - 0.5)
            ramp = min(edge / fade_px, 1.0) if fade_px > 0 else 1.0
            alpha = round(255 * row_alpha * ramp)
            pixels += bytes((255, 255, 255, alpha))

    # Uncompressed true colour, 32 bits, 8 alpha bits, origin top left.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    out = Path(__file__).resolve().parent.parent / "Media" / "StripMask.tga"
    out.write_bytes(header + pixels)
    print(f"wrote {out}")


if __name__ == "__main__":
    main()
