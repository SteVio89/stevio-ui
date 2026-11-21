#!/usr/bin/env python3
"""Writes Media/StripMasks/000.tga ... , the masks of the minimap strip (Modules/Minimap/Strip.lua).

A rotating minimap turns its mask along with the map, so a fixed band mask
would turn too. Instead there is one mask per facing step, each with the band
turned back by that facing; Strip.lua swaps them as the character turns.

The minimap is a square (`MapSize` in Modules/Minimap/Geometry.lua) centred on
the player's arrow. Only a band is visible: `height` above the arrow and
`behind` below it, `width` wide, fading out over `fade` of each half towards
the ends. Run it again after changing strip.width, height, behind, maskFade or
maskStep in Modules/Minimap/Config.lua:

    python3 tools/strip_mask.py [width height behind fade step]
"""

import math
import shutil
import struct
import sys
from pathlib import Path

SIZE = 256


def map_size(width, height):
    """Side of the square map, so the band's corners stay inside it at any angle."""
    return math.ceil(2 * math.hypot(width / 2, height))


def clamp(value):
    return 0.0 if value < 0 else 1.0 if value > 1 else value


def mask(width, height, behind, fade, angle):
    """Alpha rows, bottom row first, of the band turned counter-clockwise by `angle` (radians)."""
    scale = SIZE / map_size(width, height)
    half = width / 2
    fade_width = fade * half
    cos, sin = math.cos(angle), math.sin(angle)
    rows = []
    for row in range(SIZE):
        # In UI units from the centre, y up.
        y = (row + 0.5 - SIZE / 2) / scale
        alphas = bytearray()
        for column in range(SIZE):
            x = (column + 0.5 - SIZE / 2) / scale
            # The pixel in the band's own frame: u along it, v up from the arrow.
            u = x * cos + y * sin
            v = -x * sin + y * cos
            # Edges antialiased over one mask pixel.
            coverage = clamp((height - v) * scale + 0.5) * clamp((v + behind) * scale + 0.5)
            if coverage > 0:
                coverage *= clamp((half - abs(u)) / fade_width) if fade_width > 0 else clamp(half - abs(u))
            alphas.append(round(255 * coverage))
        rows.append(alphas)
    return rows


def encode(rows):
    """Run-length encoded TGA (type 10), 32 bits, white with the mask in alpha, origin bottom left."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 10, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x08)
    body = bytearray()
    for alphas in rows:
        # Packets don't cross rows: runs of equal pixels, and raw packets of
        # the single ones in between, both up to 128 pixels.
        raw = bytearray()

        def flush():
            if raw:
                body.append(len(raw) - 1)
                for value in raw:
                    body.extend((255, 255, 255, value))
                raw.clear()

        index = 0
        while index < len(alphas):
            value, run = alphas[index], 1
            while index + run < len(alphas) and alphas[index + run] == value and run < 128:
                run += 1
            if run > 1:
                flush()
                body.extend((0x80 | (run - 1), 255, 255, 255, value))
            else:
                raw.append(value)
                if len(raw) == 128:
                    flush()
            index += run
        flush()
    return header + body


def main():
    width, height, behind, fade, step = (float(v) for v in (sys.argv[1:] or ["640", "88", "8", "0.25", "3"]))
    count = round(360 / step)
    out = Path(__file__).resolve().parent.parent / "Media" / "StripMasks"
    shutil.rmtree(out, ignore_errors=True)
    out.mkdir(parents=True)
    for index in range(count):
        angle = math.radians(index * 360 / count)
        (out / f"{index:03d}.tga").write_bytes(encode(mask(width, height, behind, fade, angle)))
    print(f"wrote {count} masks to {out}")


if __name__ == "__main__":
    main()
