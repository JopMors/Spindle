#!/usr/bin/env python3
"""Draws the app icon and writes Resources/AppIcon.icns.

The mark is generated rather than traced from a photograph. A rendering of a
real product would carry that product's design and trade dress into the icon,
which is the one asset a repository cannot argue is incidental. This is a plain
dial — an outer ring and a centre disc — which is generic iconography, and reads
as a record around its spindle.

Everything is drawn at 4x and downsampled, because PIL has no antialiased
drawing primitives and the ring's edges are the whole design.

    python3 Tools/make-icon.py
"""

import subprocess
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:
    sys.exit("error: Pillow is required — python3 -m pip install --user Pillow")

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / ".build" / "AppIcon.iconset"
ICNS = ROOT / "Resources" / "AppIcon.icns"
DOCS_ICON = ROOT / "docs" / "icon.png"

CANVAS = 1024
# macOS leaves the outer ring of the canvas empty; the artwork sits on a
# smaller tile so it matches the size of the stock icons beside it.
TILE = 824
# Apple's rounded-rect corner is a fixed fraction of the tile.
CORNER_RATIO = 0.2237
SUPERSAMPLE = 4

# Indigo to violet: deliberately nothing like the white-and-chrome of the
# hardware this is a nod to.
GRADIENT_TOP = (86, 84, 214)
GRADIENT_BOTTOM = (48, 40, 112)
RING_COLOUR = (247, 247, 252)
DISC_COLOUR = (247, 247, 252)

RING_OUTER_RATIO = 0.345
RING_THICKNESS_RATIO = 0.115
DISC_RATIO = 0.135


def vertical_gradient(size, top, bottom):
    """A one-pixel-wide column stretched to width, which is much faster than
    filling row by row at 4x."""
    column = Image.new("RGB", (1, size))
    draw = ImageDraw.Draw(column)
    for y in range(size):
        blend = y / max(size - 1, 1)
        draw.point(
            (0, y),
            fill=tuple(round(a + (b - a) * blend) for a, b in zip(top, bottom)),
        )
    return column.resize((size, size), Image.BICUBIC)


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=radius, fill=255
    )
    return mask


def gloss(size):
    """A soft highlight across the top, so the tile reads as a surface rather
    than a flat swatch."""
    layer = Image.new("L", (size, size), 0)
    ImageDraw.Draw(layer).ellipse(
        (-size * 0.35, -size * 0.95, size * 1.35, size * 0.42), fill=70
    )
    return layer.filter(ImageFilter.GaussianBlur(size * 0.05))


def draw_tile():
    size = TILE * SUPERSAMPLE
    tile = vertical_gradient(size, GRADIENT_TOP, GRADIENT_BOTTOM).convert("RGBA")
    tile.putalpha(rounded_mask(size, round(size * CORNER_RATIO)))

    highlight = Image.new("RGBA", (size, size), RING_COLOUR + (0,))
    highlight.putalpha(gloss(size))
    tile = Image.alpha_composite(tile, highlight)

    centre = size / 2
    outer = size * RING_OUTER_RATIO
    inner = outer - size * RING_THICKNESS_RATIO
    disc = size * DISC_RATIO

    # The ring is punched on its own layer. Cutting the hole directly into the
    # tile would take the gradient out with it and leave a transparent well.
    ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ring_draw = ImageDraw.Draw(ring)
    ring_draw.ellipse(
        (centre - outer, centre - outer, centre + outer, centre + outer),
        fill=RING_COLOUR + (255,),
    )
    ring_draw.ellipse(
        (centre - inner, centre - inner, centre + inner, centre + inner),
        fill=(0, 0, 0, 0),
    )
    ring_draw.ellipse(
        (centre - disc, centre - disc, centre + disc, centre + disc),
        fill=DISC_COLOUR + (255,),
    )
    tile = Image.alpha_composite(tile, ring)

    return tile.resize((TILE, TILE), Image.LANCZOS)


def draw_icon():
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    offset = (CANVAS - TILE) // 2
    icon.paste(draw_tile(), (offset, offset))
    return icon


def write_iconset(icon):
    if ICONSET.exists():
        subprocess.run(["rm", "-rf", str(ICONSET)], check=True)
    ICONSET.mkdir(parents=True)
    for size in (16, 32, 128, 256, 512):
        icon.resize((size, size), Image.LANCZOS).save(ICONSET / f"icon_{size}x{size}.png")
        icon.resize((size * 2, size * 2), Image.LANCZOS).save(
            ICONSET / f"icon_{size}x{size}@2x.png"
        )


def main():
    icon = draw_icon()
    write_iconset(icon)
    ICNS.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)

    DOCS_ICON.parent.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(DOCS_ICON)
    print(f"wrote {ICNS.relative_to(ROOT)} and {DOCS_ICON.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
