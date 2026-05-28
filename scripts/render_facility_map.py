#!/usr/bin/env python3
"""Render an annotated facility map using PZ's in-game worldmap.png as the
backdrop. Reads the user's PZ install for the source PNG, downscales it,
overlays the 6 EPR facility markers, and writes a JPEG to docs/.

Usage:
    python3 scripts/render_facility_map.py

Requires:
    - Pillow
    - PZ installed at PZ_INSTALL below (or set the env var)
"""
import os
import sys
from PIL import Image, ImageDraw, ImageFont

PZ_INSTALL = os.environ.get(
    "PZ_INSTALL",
    "/mnt/g/SteamLibrary/steamapps/common/ProjectZomboid",
)
SRC = os.path.join(PZ_INSTALL, "media/maps/Muldraugh, KY/worldmap.png")
OUT = os.path.join(os.path.dirname(__file__), "..", "docs", "facilities-real-map.jpg")

# World tile extents (from worldmap.xml: 66 x 53 cells, 300 tiles/cell)
WORLD_W = 66 * 300
WORLD_H = 53 * 300

TARGET_W = 1800  # output width in px; height scaled to match aspect

FACILITIES = [
    # (id, display_name, world_x, world_y, type, is_prereq)
    ("louisville_plant",            "Louisville Power Plant",       12120,  1617, "power",  True),
    ("louisville_south_substation", "Louisville South Substation",  14732,  4083, "power",  False),
    ("muldraugh_substation",        "Muldraugh Substation",         10389, 10060, "power",  False),
    ("riverside_relay",             "Riverside Relay",               4832,  6279, "power",  False),
    ("irvington_substation",        "Irvington Substation",          2210, 13914, "power",  False),
    ("rosewood_water",              "Rosewood Water Treatment",      8044, 15360, "water",  False),
]

COLORS = {
    "power_prereq": (255, 123, 58),
    "power":        (245, 197, 66),
    "water":        ( 74, 168, 255),
}


def font(size, bold=False):
    name = "DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"
    try:
        return ImageFont.truetype(f"/usr/share/fonts/truetype/dejavu/{name}", size)
    except Exception:
        return ImageFont.load_default()


def main():
    if not os.path.isfile(SRC):
        sys.exit(f"PZ worldmap not found: {SRC}\nSet PZ_INSTALL env var to your install path.")

    img = Image.open(SRC).convert("RGBA")
    src_w, src_h = img.size
    target_h = int(src_h * TARGET_W / src_w)
    img = img.resize((TARGET_W, target_h), Image.LANCZOS)
    # dim the backdrop so labels pop
    img = Image.alpha_composite(img, Image.new("RGBA", img.size, (0, 0, 0, 60)))
    draw = ImageDraw.Draw(img)

    f_lbl    = font(18, bold=True)
    f_coord  = font(13)
    f_title  = font(28, bold=True)
    f_legend = font(15, bold=True)

    def world_to_px(wx, wy):
        return wx * TARGET_W / WORLD_W, wy * target_h / WORLD_H

    draw.rectangle([0, 0, TARGET_W, 50], fill=(20, 24, 36, 230))
    draw.text((20, 12), "EPR Community - Facility Map (PZ B42 vanilla worldmap)",
              fill=(232, 234, 240), font=f_title)

    R = 12
    for fid, name, wx, wy, ftype, prereq in FACILITIES:
        px, py = world_to_px(wx, wy)
        col = COLORS["power_prereq"] if prereq else COLORS[ftype]
        draw.ellipse([px-R-3, py-R-3, px+R+3, py+R+3], fill=(255, 255, 255, 255))
        draw.ellipse([px-R, py-R, px+R, py+R], fill=col + (255,))
        draw.ellipse([px-3, py-3, px+3, py+3], fill=(20, 24, 36, 255))

        # right-side label by default, flip if too close to the edge
        tx = px + R + 8
        text_bbox = draw.textbbox((0, 0), name, font=f_lbl)
        text_w = text_bbox[2] - text_bbox[0]
        if tx + text_w > TARGET_W - 10:
            tx = px - R - 8 - text_w

        coord_str = f"{wx}, {wy}"
        cb = draw.textbbox((0, 0), coord_str, font=f_coord)
        coord_w = cb[2] - cb[0]
        pad = 5
        box_w = max(text_w, coord_w) + pad * 2
        box_h = 42
        bx0, by0 = tx - pad, py - box_h // 2
        bx1, by1 = bx0 + box_w, by0 + box_h
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=5, fill=(20, 24, 36, 220))
        draw.text((tx, py - 16), name, fill=(232, 234, 240, 255), font=f_lbl)
        draw.text((tx, py + 4), coord_str, fill=(138, 146, 165, 255), font=f_coord)

    # legend (bottom-left)
    lx, ly = 20, target_h - 130
    draw.rounded_rectangle([lx, ly, lx + 280, ly + 110], radius=8, fill=(20, 24, 36, 230))
    draw.text((lx + 10, ly + 8), "Legend", fill=(232, 234, 240, 255), font=f_lbl)
    for i, (lbl, col) in enumerate([
        ("Power plant (prereq)", COLORS["power_prereq"]),
        ("Power substation",     COLORS["power"]),
        ("Water treatment",      COLORS["water"]),
    ]):
        cx, cy = lx + 25, ly + 45 + i * 22
        draw.ellipse([cx-9, cy-9, cx+9, cy+9], fill=(255, 255, 255, 255))
        draw.ellipse([cx-7, cy-7, cx+7, cy+7], fill=col + (255,))
        draw.text((cx + 14, cy - 8), lbl, fill=(232, 234, 240, 255), font=f_legend)

    img.convert("RGB").save(OUT, "JPEG", quality=85, optimize=True)
    print(f"wrote: {OUT}  ({os.path.getsize(OUT) / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
