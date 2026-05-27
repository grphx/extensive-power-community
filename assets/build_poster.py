#!/usr/bin/env python3
"""
Build poster.png for Extensive Power Rework (Community fork).

Takes the upstream EPR_B42 Workshop preview verbatim and adds a small
"(Community Fork)" line below the existing "Extensive Power Rework"
text, preserving the original visual identity.
"""
from PIL import Image, ImageDraw, ImageFont
import os

HERE = os.path.dirname(__file__)
SRC  = os.path.join(HERE, "source", "upstream_preview.jpg")
OUT  = os.path.join(HERE, "poster.png")

# Workshop preview size (matches BVD and BMPI conventions).
TARGET = 512

# Amber to match the existing title/text in the upstream preview.
AMBER       = (255, 204, 0)
AMBER_SHADOW = (140, 80, 0)


def main():
    src = Image.open(SRC).convert("RGB")
    # Nearest-neighbour upscale of the upstream image to a 512-wide strip,
    # then add a black bottom band for our suffix so the original is never
    # painted over. Final canvas is square (TARGET x TARGET).
    upscale_h = 512  # keep upstream upscaled to full 512 wide x 512 tall
    upstream = src.resize((TARGET, upscale_h), Image.NEAREST)

    # Black band height. The output stays TARGET x TARGET to match Workshop
    # expectations, so we shrink the upstream slice and reserve the bottom
    # ~64 px for the new line.
    BAND_H = 64
    upstream = upstream.resize((TARGET, TARGET - BAND_H), Image.NEAREST)

    canvas = Image.new("RGB", (TARGET, TARGET), (0, 0, 0))
    canvas.paste(upstream, (0, 0))
    d = ImageDraw.Draw(canvas)

    try:
        font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30
        )
    except Exception:
        font = ImageFont.load_default()

    text = "(Community Fork)"
    bb = d.textbbox((0, 0), text, font=font)
    tw = bb[2] - bb[0]
    th = bb[3] - bb[1]

    # Centre the suffix in the bottom band.
    x = (TARGET - tw) // 2
    y = TARGET - BAND_H + (BAND_H - th) // 2 - 4   # eyeballed visual centre

    d.text((x + 3, y + 3), text, font=font, fill=AMBER_SHADOW)
    d.text((x,     y    ), text, font=font, fill=AMBER)

    canvas.save(OUT)
    print(f"wrote {OUT} ({TARGET}x{TARGET})")


if __name__ == "__main__":
    main()
