#!/usr/bin/env python3
"""Compose the App Store header / search results image from the three drive-screen captures.

Reads AppStore/creative-assets/raw/*.png (in name order, from Tools/creative-asset-capture.sh) and writes
AppStore/creative-assets/signs-16x9.png: one universal 16:9 image, 5244 x 2950, flattened RGB with no alpha.
Each capture is cropped to the sign, road name and speed, rounded, and set on the charcoal ground, so the
three read left to right as one trip.

  python3 -I Tools/frame-creative-asset.py [--preview DIR]

--preview DIR also writes a centred 21:9 crop and a centred 3:2 crop of the result into DIR, to check what
the product page header and the search results placement keep. Needs ImageMagick (`magick`).
"""
import argparse
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "AppStore" / "creative-assets" / "raw"
OUT = ROOT / "AppStore" / "creative-assets" / "signs-16x9.png"

W, H = 5244, 2950
GROUND = "#26262A"
HAIRLINE = "#3A3A3C"

# Crop of each 1320 x 2868 capture: x, y, width, height. From the top of the sign to below "km/h".
CROP = (150, 767, 1020, 1420)
SCALE = 1.1
GAP = 180


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--preview", type=Path)
    args = parser.parse_args()

    shots = sorted(RAW.glob("*.png"))
    if len(shots) != 3:
        sys.exit(f"expected 3 captures in {RAW}, found {len(shots)}")

    cx, cy, cw, ch = CROP
    pw, ph = round(cw * SCALE), round(ch * SCALE)
    radius = round(pw * 0.06)
    total = 3 * pw + 2 * GAP
    left, top = (W - total) // 2, (H - ph) // 2

    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        mask = tmp / "mask.png"
        run("magick", "-size", f"{pw}x{ph}", "xc:black", "-fill", "white",
            "-draw", f"roundrectangle 0,0,{pw-1},{ph-1},{radius},{radius}", mask)
        canvas = tmp / "canvas.png"
        run("magick", "-size", f"{W}x{H}", f"xc:{GROUND}", canvas)
        for i, shot in enumerate(shots):
            panel = tmp / f"panel{i}.png"
            run("magick", shot, "-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage", "-alpha", "off",
                "-filter", "Lanczos", "-resize", f"{pw}x{ph}!", mask, "-compose", "CopyOpacity", "-composite", panel)
            x = left + i * (pw + GAP)
            run("magick", canvas, panel, "-geometry", f"+{x}+{top}", "-composite",
                "-fill", "none", "-stroke", HAIRLINE, "-strokewidth", "3",
                "-draw", f"roundrectangle {x},{top},{x+pw-1},{top+ph-1},{radius},{radius}", canvas)
        run("magick", canvas, "-background", GROUND, "-alpha", "remove", "-alpha", "off",
            "-depth", "8", "-strip", f"PNG24:{OUT}")

    print(f"wrote {OUT} ({W} x {H}); panels {pw} x {ph} at {SCALE}x, {left}px in from each side")

    if args.preview:
        args.preview.mkdir(parents=True, exist_ok=True)
        h219 = round(W * 9 / 21)
        w32 = round(H * 3 / 2)
        run("magick", OUT, "-gravity", "center", "-crop", f"{W}x{h219}+0+0", "+repage", args.preview / "crop-21x9.png")
        run("magick", OUT, "-gravity", "center", "-crop", f"{w32}x{H}+0+0", "+repage", args.preview / "crop-3x2.png")
        print(f"wrote previews: 21:9 = {W} x {h219}, 3:2 = {w32} x {H}")


if __name__ == "__main__":
    main()
