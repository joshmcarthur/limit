#!/usr/bin/env python3
"""Frame the raw App Store screenshots with a caption.

Reads the caption table in AppStore/listing.md and the raw captures in
AppStore/screenshots/6.9-inch, and writes two sets of flattened RGB PNGs:

  AppStore/screenshots/6.9-inch-framed/portrait/   1320 x 2868
  AppStore/screenshots/6.9-inch-framed/landscape/  2868 x 1320

Needs ImageMagick (`magick`), `rsvg-convert` and fontTools (`pip install fonttools`).
Captions are drawn from Helvetica Neue Bold outlines, so they render the same everywhere.
"""
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTCollection

ROOT = Path(__file__).resolve().parent.parent
LISTING = ROOT / "AppStore" / "listing.md"
RAW = ROOT / "AppStore" / "screenshots" / "6.9-inch"
OUT = ROOT / "AppStore" / "screenshots" / "6.9-inch-framed"

GROUND = "#26262A"
HAIRLINE = "#3A3A3C"
INK = "#FFFFFF"
FONT_FILE = "/System/Library/Fonts/HelveticaNeue.ttc"
FONT_NAME = "HelveticaNeue-Bold"

# The landscape capture is wide, so it only goes in the landscape set.
LANDSCAPE_ONLY = {"04-landscape-dark.png"}


def captions():
    """(file, caption) rows from the table under '## Screenshots', in order."""
    rows = []
    for line in LISTING.read_text().splitlines():
        m = re.match(r"\|\s*\d+\s*\|\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*$", line)
        if m:
            rows.append((m.group(1), m.group(2)))
    if not rows:
        sys.exit("no caption rows found in listing.md")
    return rows


class Font:
    def __init__(self):
        coll = TTCollection(FONT_FILE)
        self.font = next(f for f in coll.fonts if f["name"].getDebugName(6) == FONT_NAME)
        self.glyphs = self.font.getGlyphSet()
        self.cmap = self.font.getBestCmap()
        self.hmtx = self.font["hmtx"]
        self.upm = self.font["head"].unitsPerEm
        self.cap = self.font["OS/2"].sCapHeight

    def width(self, text, size):
        return sum(self.hmtx[self.cmap[ord(c)]][0] for c in text) * size / self.upm

    def greedy(self, text, size, max_width):
        lines, line = [], ""
        for word in text.split():
            trial = f"{line} {word}".strip()
            if line and self.width(trial, size) > max_width:
                lines.append(line)
                line = word
            else:
                line = trial
        lines.append(line)
        return lines

    def balanced(self, text, size, max_width):
        """Wrap to the fewest lines, then to the narrowest width that keeps that count."""
        want = len(self.greedy(text, size, max_width))
        lo, hi = 1.0, max_width
        while hi - lo > 1:
            mid = (lo + hi) / 2
            if len(self.greedy(text, size, mid)) <= want:
                hi = mid
            else:
                lo = mid
        return self.greedy(text, size, hi)

    def wrap(self, text, size, max_width):
        """Each sentence starts its own line; a long sentence wraps evenly."""
        lines = []
        for sentence in re.split(r"(?<=\.)\s+", text):
            lines += self.balanced(sentence, size, max_width)
        return lines

    def fit(self, text, sizes, max_width, max_lines):
        """The largest size whose wrapped caption fits in max_lines."""
        for size in sizes:
            lines = self.wrap(text, size, max_width)
            if len(lines) <= max_lines:
                return size, lines
        sys.exit(f"caption does not fit in {max_lines} lines: {text}")

    def path(self, text, size, x, baseline):
        s = size / self.upm
        parts = []
        for c in text:
            g = self.cmap[ord(c)]
            pen = SVGPathPen(self.glyphs, ntos=lambda v: f"{v:.2f}")
            self.glyphs[g].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline)))
            parts.append(pen.getCommands())
            x += self.hmtx[g][0] * s
        return " ".join(parts)


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def caption_layer(font, text, sizes, max_lines, box, align, path):
    """Render the caption into a transparent PNG the size of the canvas.

    box is (x, y, w, h); the wrapped text is centred vertically in it.
    """
    bx, by, bw, bh = box
    size, lines = font.fit(text, sizes, bw, max_lines)
    lead = size * 1.18
    block = lead * (len(lines) - 1) + font.cap * size / font.upm
    top = by + (bh - block) / 2 + font.cap * size / font.upm
    d = []
    for i, line in enumerate(lines):
        w = font.width(line, size)
        x = bx + (bw - w) / 2 if align == "center" else bx
        d.append(font.path(line, size, x, top + i * lead))
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS[0]}" height="{CANVAS[1]}">'
        f'<path fill="{INK}" d="{" ".join(d)}"/></svg>'
    )
    svg_path = path.with_suffix(".svg")
    svg_path.write_text(svg)
    run("rsvg-convert", "-w", CANVAS[0], "-h", CANVAS[1], svg_path, "-o", path)


def place_screen(src, size, pos, out_in, tmp):
    """Scale src to size, round its corners and hairline it onto out_in."""
    w, h = size
    r = round(min(w, h) * 0.12)
    mask, shot = tmp / "mask.png", tmp / "shot.png"
    run("magick", "-size", f"{w}x{h}", "xc:black", "-fill", "white",
        "-draw", f"roundrectangle 0,0,{w-1},{h-1},{r},{r}", mask)
    run("magick", src, "-resize", f"{w}x{h}!", "-alpha", "off", mask,
        "-compose", "CopyOpacity", "-composite", shot)
    x, y = pos
    run("magick", out_in, shot, "-geometry", f"+{x}+{y}", "-composite",
        "-fill", "none", "-stroke", HAIRLINE, "-strokewidth", "3",
        "-draw", f"roundrectangle {x},{y},{x+w-1},{y+h-1},{r},{r}", out_in)


def finish(path):
    run("magick", path, "-background", GROUND, "-alpha", "remove", "-alpha", "off",
        "-depth", "8", "-strip", f"PNG24:{path}")


def frame(font, src, text, out, landscape_canvas, src_is_landscape, tmp):
    global CANVAS
    CANVAS = (2868, 1320) if landscape_canvas else (1320, 2868)
    run("magick", "-size", f"{CANVAS[0]}x{CANVAS[1]}", f"xc:{GROUND}", out)
    layer = tmp / "caption.png"

    if not landscape_canvas:
        sw = 1071
        sh = round(sw * 2868 / 1320)
        caption_layer(font, text, (96, 88, 80, 72), 2, (90, 90, 1140, 310), "center", layer)
        place_screen(src, (sw, sh), ((1320 - sw) // 2, 2868 - sh - 100), out, tmp)
    elif src_is_landscape:
        sh = 1020
        sw = round(sh * 2868 / 1320)
        caption_layer(font, text, (88, 80, 72), 1, (150, 50, 2568, 180), "center", layer)
        place_screen(src, (sw, sh), ((2868 - sw) // 2, 1320 - sh - 60), out, tmp)
    else:
        sh = 1160
        sw = round(sh * 1320 / 2868)
        caption_layer(font, text, (132, 120, 108), 4, (220, 160, 1400, 1000), "left", layer)
        place_screen(src, (sw, sh), (2868 - sw - 220, 80), out, tmp)

    run("magick", out, layer, "-composite", out)
    finish(out)


def main():
    font = Font()
    rows = captions()
    for sub in ("portrait", "landscape"):
        (OUT / sub).mkdir(parents=True, exist_ok=True)
        for old in (OUT / sub).glob("*.png"):
            old.unlink()
    with tempfile.TemporaryDirectory() as t:
        tmp = Path(t)
        n_portrait = 0
        for i, (name, text) in enumerate(rows, 1):
            src = RAW / name
            is_land = name in LANDSCAPE_ONLY
            stem = name.split("-", 1)[1]
            frame(font, src, text, OUT / "landscape" / f"{i:02d}-{stem}", True, is_land, tmp)
            if not is_land:
                n_portrait += 1
                frame(font, src, text, OUT / "portrait" / f"{n_portrait:02d}-{stem}", False, False, tmp)
    print(f"wrote {n_portrait} portrait and {len(rows)} landscape slides to {OUT}")


CANVAS = (1320, 2868)

if __name__ == "__main__":
    main()
