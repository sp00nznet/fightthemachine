#!/usr/bin/env python3
"""Draw app.ico: a red crosshair on a dark tile, from geometry.

Uses asset-forge's pipelines/ui_icons.py for the shapes, rasteriser and ICO
writer (github.com/sp00nznet/asset-forge). Geometry, not a generated image,
because the taskbar shows the 16-32px entries and a painted 1024px image turns
to mush there. Below 20px it switches to a heavier drawing with fewer parts.

    py make_icon.py [--forge F:/projects/tools/asset-forge] [--out app.ico]
"""

import argparse
import os
import sys

TILE = (0x16, 0x18, 0x1D, 255)
RED = (0xC8, 0x1E, 0x1E, 255)      # DOOM's status-bar red
TICK = (0xEC, 0xE6, 0xD8, 255)


def crosshair(ui, size):
    small = size < 20
    ring_r, ring_w = (0.36, 0.13) if small else (0.33, 0.075)
    tick_w = 0.13 if small else 0.07
    gap = 0.16 if small else 0.13      # ticks stop short of the centre dot
    half = tick_w / 2
    shapes = [
        (ui.rounded_rect(0.02, 0.02, 0.98, 0.98, 0.2), TILE),
        (ui.circle(0.5, 0.5, ring_r), RED),
        (ui.circle(0.5, 0.5, ring_r - ring_w), TILE),
    ]
    for a, b in ((0.10, 0.5 - gap), (0.5 + gap, 0.90)):
        shapes.append((ui.rect(a, 0.5 - half, b, 0.5 + half), TICK))
        shapes.append((ui.rect(0.5 - half, a, 0.5 + half, b), TICK))
    shapes.append((ui.circle(0.5, 0.5, 0.075 if small else 0.05), RED))
    return shapes


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--forge", default=os.environ.get("ASSET_FORGE", "F:/projects/tools/asset-forge"))
    ap.add_argument("--out", default=os.path.join(here, "app.ico"))
    ap.add_argument("--png", help="also write the 256px image here, for a look")
    args = ap.parse_args()

    sys.path.insert(0, os.path.join(args.forge, "pipelines"))
    import ui_icons as ui

    images = []
    for size in ui.ICO_SIZES:
        rgba = ui.render(crosshair(ui, size), size)
        images.append((size, ui.png(size, rgba) if size >= 256 else ui.dib(size, rgba)))
        if args.png and size == 256:
            with open(args.png, "wb") as f:
                f.write(ui.png(size, rgba))
    with open(args.out, "wb") as f:
        f.write(ui.ico(images))
    print("%s: %d sizes" % (args.out, len(images)))


if __name__ == "__main__":
    main()
