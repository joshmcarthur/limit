#!/usr/bin/env python3
"""Compose the Play feature graphic from three Android drive screens.

Reads AppStore/creative-assets/raw/*.png in name order and writes
AppStore/feature-graphic.png: 1024 x 500, flattened RGB, no alpha.
Each capture is cropped to the sign, road name and speed, rounded, and set
on the charcoal ground. The cards sit inside the centre 824 x 400 area.

  python3 -I Tools/frame-feature-graphic.py

Needs ImageMagick (`magick`). Run from anywhere; paths are relative to android/.
"""
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "AppStore" / "creative-assets" / "raw"
OUT = ROOT / "AppStore" / "feature-graphic.png"

W, H = 1024, 500
GROUND = "#26262A"
HAIRLINE = "#3A3A3C"

# Crop of each 1080 x 2400 capture: x, y, width, height.
# From just above the sign to just below "km/h". Wide enough for
# "Turangi To Waiouru, SH 1".
CROP = (160, 500, 760, 1200)
PW, PH = 247, 390
GAP = 41


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def main():
    shots = sorted(RAW.glob("*.png"))
    if len(shots) != 3:
        sys.exit(f"expected 3 captures in {RAW}, found {len(shots)}")

    cx, cy, cw, ch = CROP
    radius = round(PW * 0.06)
    total = 3 * PW + 2 * GAP
    left, top = (W - total) // 2, (H - PH) // 2

    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        mask = tmp / "mask.png"
        run(
            "magick", "-size", f"{PW}x{PH}", "xc:black", "-fill", "white",
            "-draw", f"roundrectangle 0,0,{PW - 1},{PH - 1},{radius},{radius}",
            mask,
        )
        canvas = tmp / "canvas.png"
        run("magick", "-size", f"{W}x{H}", f"xc:{GROUND}", canvas)
        for i, shot in enumerate(shots):
            panel = tmp / f"panel{i}.png"
            run(
                "magick", shot, "-crop", f"{cw}x{ch}+{cx}+{cy}", "+repage",
                "-alpha", "off", "-filter", "Lanczos", "-resize", f"{PW}x{PH}!",
                mask, "-compose", "CopyOpacity", "-composite", panel,
            )
            x = left + i * (PW + GAP)
            run(
                "magick", canvas, panel, "-geometry", f"+{x}+{top}", "-composite",
                "-fill", "none", "-stroke", HAIRLINE, "-strokewidth", "2",
                "-draw",
                f"roundrectangle {x},{top},{x + PW - 1},{top + PH - 1},{radius},{radius}",
                canvas,
            )
        run(
            "magick", canvas, "-background", GROUND, "-alpha", "remove",
            "-alpha", "off", "-depth", "8", "-strip", f"PNG24:{OUT}",
        )

    print(f"wrote {OUT} ({W} x {H}); panels {PW} x {PH}, {left}px in from each side")


if __name__ == "__main__":
    main()
