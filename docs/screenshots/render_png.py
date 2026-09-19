#!/usr/bin/env python3
"""Render as400-signon ANSI dumps to VT-style PNGs (phosphor green on black)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# Palette — Linux VT green phosphor feel
BG = (0, 0, 0)
GREEN = (51, 255, 51)          # bright phosphor
GREEN_DIM = (0, 170, 0)        # normal green (approx ANSI 32)
BAR_FG = (0, 0, 0)             # black on green bar
BAR_BG = (0, 170, 0)           # green background
RED = (255, 68, 68)            # error only
COLS = 80
ROWS = 24
CELL_W = 12
CELL_H = 24
PAD = 16

FONT_CANDIDATES = [
    "/usr/share/fonts/truetype/sand-box/google/VT323/VT323-Regular.ttf",
    "/usr/share/fonts/truetype/sand-box/google/IBM Plex Mono/IBMPlexMono-Regular.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if Path(path).is_file():
            return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


# Strip CSI / OSC; keep text. Track simple SGR for spans.
CSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]|\x1b\].*?\x07|\x1b.")


def parse_ansi(data: str) -> list[list[tuple[str, str]]]:
    """Return rows of (char, style) where style in {bar, green, red, reset}."""
    # Normalize: drop clear/home/cursor hide
    data = data.replace("\x1b[2J", "").replace("\x1b[H", "")
    data = re.sub(r"\x1b\[\?25[lh]", "", data)

    rows: list[list[tuple[str, str]]] = []
    row: list[tuple[str, str]] = []
    style = "green"
    i = 0
    while i < len(data):
        if data[i] == "\x1b" and i + 1 < len(data) and data[i + 1] == "[":
            m = re.match(r"\x1b\[([0-9;]*)([A-Za-z])", data[i:])
            if not m:
                i += 1
                continue
            params, cmd = m.group(1), m.group(2)
            i += m.end()
            if cmd == "m":
                parts = [int(p) if p else 0 for p in params.split(";")] if params else [0]
                if parts == [0] or parts == [0, 0]:
                    style = "green"
                elif 42 in parts and (30 in parts or True):
                    # 0;30;42 black on green
                    if 30 in parts and 42 in parts:
                        style = "bar"
                    elif 42 in parts:
                        style = "bar"
                elif 31 in parts:
                    style = "red"
                elif 32 in parts or 1 in parts:
                    style = "green"
                else:
                    style = "green"
            continue
        ch = data[i]
        i += 1
        if ch == "\n":
            rows.append(row)
            row = []
            continue
        if ch == "\r":
            continue
        row.append((ch, style))
    if row:
        rows.append(row)
    return rows


def render(rows: list[list[tuple[str, str]]], out: Path, title: str) -> None:
    font = load_font(22)
    # Measure a sample cell
    bbox = font.getbbox("M")
    cw = max(CELL_W, bbox[2] - bbox[0] + 1)
    ch = max(CELL_H, bbox[3] - bbox[1] + 4)

    width = PAD * 2 + COLS * cw
    height = PAD * 2 + ROWS * ch
    img = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(img)

    # Subtle scanline tint
    for y in range(0, height, 2):
        draw.line([(0, y), (width, y)], fill=(0, 12, 0))

    for r, row in enumerate(rows[:ROWS]):
        # pad/truncate to COLS for bar backgrounds
        cells = row[:COLS] + [(" ", "green")] * max(0, COLS - len(row))
        # If any bar style on this row, paint full bar bg first
        if any(s == "bar" for _, s in cells):
            y0 = PAD + r * ch
            draw.rectangle([PAD, y0, PAD + COLS * cw, y0 + ch - 1], fill=BAR_BG)

        x = PAD
        y = PAD + r * ch
        for char, style in cells[:COLS]:
            if style == "bar":
                fill = BAR_FG
            elif style == "red":
                fill = RED
            else:
                fill = GREEN
            draw.text((x, y - 2), char, font=font, fill=fill)
            x += cw

    # Outer phosphor bezel hint
    draw.rectangle([2, 2, width - 3, height - 3], outline=(0, 80, 0))

    img.save(out, "PNG", optimize=True)
    print(f"wrote {out} ({img.size[0]}x{img.size[1]}) — {title}")


def main() -> None:
    here = Path(__file__).resolve().parent
    for name, title in [
        ("signon-ready", "Sign On — ready"),
        ("signon-error", "Sign On — bad password"),
    ]:
        ansi = (here / f"{name}.ansi").read_bytes().decode("utf-8", errors="replace")
        rows = parse_ansi(ansi)
        render(rows, here / f"{name}.png", title)


if __name__ == "__main__":
    main()
