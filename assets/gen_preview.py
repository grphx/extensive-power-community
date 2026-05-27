#!/usr/bin/env python3
"""
Preview generator for Extensive Power Rework (Community fork).
Same 16-bit pixel-art aesthetic as BMPI / BVD - chunky pixels, limited
palette, hard pixel border.

Concept: a darkened cityscape with a single lit substation in the
foreground throwing sparks. Communicates the mod's loop: broken
infrastructure -> player repair -> restored utilities.

Output: preview_v1.png (512x512). Nearest-neighbour scaled from a
128x128 logical canvas.
"""
from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "preview_v1.png")
LOGICAL = 128
SCALE = 4
SIZE = LOGICAL * SCALE

PAL = {
    "bg":         (12, 16, 28),     # deep night blue
    "city_dk":    (32, 38, 60),     # dark distant buildings (unpowered)
    "city_md":    (54, 60, 92),     # mid buildings
    "city_lit":   (72, 82, 116),    # buildings near the substation
    "window_off": (40, 38, 52),     # dark window
    "window_on":  (252, 224, 96),   # lit window
    "ground":     (20, 24, 36),
    "moon":       (220, 224, 236),
    "subst_body": (84, 80, 92),     # transformer housing
    "subst_dk":   (44, 44, 56),
    "subst_hl":   (132, 130, 144),
    "metal":      (160, 156, 168),  # mounting plate
    "wire":       (28, 28, 36),     # power lines
    "spark":      (252, 252, 252),
    "spark_dim":  (252, 248, 180),
    "warn":       (248, 168, 60),   # warning yellow
    "title":      (252, 196, 60),
    "title_sh":   (140, 80, 20),
    "frame":      (60, 80, 120),
    "tag":        (148, 156, 184),
}


def draw_window_block(d, x, y, lit_pattern, on_color, off_color):
    """Draw a 3x3 grid of windows where lit_pattern is a list of (col, row) lit positions."""
    for col in range(3):
        for row in range(3):
            color = on_color if (col, row) in lit_pattern else off_color
            d.point((x + col * 2, y + row * 2), fill=color)


def main():
    img = Image.new("RGB", (LOGICAL, LOGICAL), PAL["bg"])
    d = ImageDraw.Draw(img)

    # Moon high-right, dim crescent feel via two squares (3x3)
    d.rectangle([104, 14, 109, 19], fill=PAL["moon"])
    d.rectangle([106, 14, 110, 18], fill=PAL["bg"])

    # ---------------------------------------------------------------
    # Background skyline - mostly dark with scattered lit windows.
    # Buildings further from the substation are darker (more unpowered).
    # ---------------------------------------------------------------
    far_buildings = [
        # (x, y, width, height, body_color, lit_count)
        (2,  44, 16, 24, "city_dk", 0),    # totally dark
        (20, 38, 18, 30, "city_dk", 1),
        (40, 50, 12, 18, "city_dk", 0),
        (54, 42, 18, 26, "city_md", 2),
        (74, 36, 22, 32, "city_lit", 4),   # closest to substation - more lit
        (98, 48, 16, 20, "city_md", 2),
        (116, 44, 10, 24, "city_dk", 1),
    ]
    import random
    random.seed(42)
    for (bx, by, bw, bh, color_key, lit_count) in far_buildings:
        d.rectangle([bx, by, bx + bw - 1, 68], fill=PAL[color_key])
        # scatter lit windows
        slots = [(c, r) for c in range(bw // 3) for r in range(bh // 3)]
        random.shuffle(slots)
        for i, (c, r) in enumerate(slots[: max(1, lit_count)]):
            wx = bx + 2 + c * 3
            wy = by + 3 + r * 3
            if wy < 67 and wx < bx + bw - 1:
                if i < lit_count:
                    d.point((wx, wy), fill=PAL["window_on"])
                else:
                    d.point((wx, wy), fill=PAL["window_off"])

    # Ground band
    d.rectangle([0, 68, LOGICAL - 1, 88], fill=PAL["ground"])

    # ---------------------------------------------------------------
    # Substation: transformer box + mounting plate + insulators +
    # power lines exiting to the sides + sparking arc at the top.
    # ---------------------------------------------------------------
    # The mod is about substations. This is the centerpiece.
    sub_x = 50  # left edge of substation
    sub_y = 56  # top of transformer box
    sub_w = 28
    sub_h = 12

    # Mounting concrete pad (slightly wider, below the box)
    d.rectangle([sub_x - 2, 68, sub_x + sub_w + 1, 73], fill=PAL["metal"])
    d.rectangle([sub_x - 2, 73, sub_x + sub_w + 1, 73], fill=PAL["subst_dk"])

    # Transformer body
    d.rectangle([sub_x, sub_y, sub_x + sub_w - 1, sub_y + sub_h - 1],
                fill=PAL["subst_body"])
    # Top edge highlight (rim light)
    d.line([(sub_x, sub_y), (sub_x + sub_w - 1, sub_y)], fill=PAL["subst_hl"])
    # Bottom shadow
    d.line([(sub_x, sub_y + sub_h - 1), (sub_x + sub_w - 1, sub_y + sub_h - 1)],
           fill=PAL["subst_dk"])
    # Cooling fins (vertical lines on the body)
    for fin_x in range(sub_x + 3, sub_x + sub_w - 2, 3):
        d.line([(fin_x, sub_y + 2), (fin_x, sub_y + sub_h - 3)],
               fill=PAL["subst_dk"])

    # Warning sticker (small yellow square) on the side of the body
    d.rectangle([sub_x + sub_w - 6, sub_y + sub_h - 5, sub_x + sub_w - 4, sub_y + sub_h - 3],
                fill=PAL["warn"])

    # Insulators on top - three small posts
    insul_y = sub_y - 4
    for ix in [sub_x + 5, sub_x + sub_w // 2, sub_x + sub_w - 6]:
        d.rectangle([ix, insul_y, ix + 1, sub_y - 1], fill=PAL["subst_hl"])
        # cap
        d.rectangle([ix - 1, insul_y - 1, ix + 2, insul_y], fill=PAL["metal"])

    # Power lines going off to the left and right edges of the canvas
    # Arc-like (slight droop)
    left_anchor_x = sub_x + 5
    right_anchor_x = sub_x + sub_w - 6
    left_anchor_y = insul_y - 1
    right_anchor_y = insul_y - 1

    # Left line: from left insulator to the left edge, drooping
    for x_step in range(0, left_anchor_x + 1):
        # parabolic droop: max at midpoint
        t = x_step / max(1, left_anchor_x)
        droop = int(4 * (1 - t))  # higher droop on the left edge
        wire_y = left_anchor_y + droop
        if 0 <= wire_y < 78:
            d.point((x_step, wire_y), fill=PAL["wire"])

    # Right line: from right insulator to the right edge, drooping
    for x_step in range(right_anchor_x, LOGICAL):
        t = (x_step - right_anchor_x) / max(1, LOGICAL - right_anchor_x)
        droop = int(4 * t)
        wire_y = right_anchor_y + droop
        if 0 <= wire_y < 78:
            d.point((x_step, wire_y), fill=PAL["wire"])

    # Utility pole on the right edge supporting the line
    d.line([(LOGICAL - 4, right_anchor_y + 4), (LOGICAL - 4, 68)],
           fill=PAL["subst_dk"])
    d.line([(LOGICAL - 6, right_anchor_y + 3), (LOGICAL - 2, right_anchor_y + 3)],
           fill=PAL["subst_dk"])

    # ---------------------------------------------------------------
    # Sparks / arc: pixel splatter above the middle insulator.
    # Communicates "this is electrical".
    # ---------------------------------------------------------------
    spark_cx = sub_x + sub_w // 2
    spark_cy = insul_y - 4
    sparks = [
        (0, 0, "spark"),
        (-2, -1, "spark_dim"), (2, -1, "spark_dim"),
        (-1, -3, "spark"), (1, -3, "spark"),
        (-3, 0, "spark_dim"), (3, 0, "spark_dim"),
        (0, -4, "spark_dim"),
        (-4, 1, "spark_dim"), (4, 1, "spark_dim"),
    ]
    for (dx, dy, c) in sparks:
        d.point((spark_cx + dx, spark_cy + dy), fill=PAL[c])

    # ---------------------------------------------------------------
    # Pixel border + checker corners (consistent with our other mods).
    # ---------------------------------------------------------------
    d.rectangle([0, 0, LOGICAL - 1, LOGICAL - 1],
                outline=PAL["frame"], width=1)
    for cx, cy in [(0, 0), (LOGICAL - 4, 0), (0, LOGICAL - 4),
                   (LOGICAL - 4, LOGICAL - 4)]:
        for dy in range(3):
            for dx in range(3):
                if (dx + dy) % 2 == 0:
                    d.point((cx + dx, cy + dy), fill=PAL["title"])

    # ---------------------------------------------------------------
    # Upscale + text layer with crisp TTF on the upscaled canvas.
    # ---------------------------------------------------------------
    big = img.resize((SIZE, SIZE), Image.NEAREST)
    bd = ImageDraw.Draw(big)

    try:
        title_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48
        )
        sub_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 38
        )
        tag_font = ImageFont.truetype(
            "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 14
        )
    except Exception:
        title_font = ImageFont.load_default()
        sub_font = ImageFont.load_default()
        tag_font = ImageFont.load_default()

    # Title block - "EXTENSIVE POWER" on top, "REWORK" below.
    def draw_centered(text, font, top_y, color, shadow):
        bb = bd.textbbox((0, 0), text, font=font)
        w = bb[2] - bb[0]
        x = (SIZE - w) // 2
        bd.text((x + 4, top_y + 4), text, font=font, fill=shadow)
        bd.text((x, top_y), text, font=font, fill=color)

    draw_centered("EXTENSIVE POWER", title_font, 30, PAL["title"], PAL["title_sh"])
    draw_centered("REWORK", sub_font, 80, PAL["title"], PAL["title_sh"])

    # Subtle "(community fork)" tag below the REWORK line
    tag = "(COMMUNITY FORK)"
    bb = bd.textbbox((0, 0), tag, font=tag_font)
    bd.text(((SIZE - (bb[2] - bb[0])) // 2, 130), tag, font=tag_font, fill=PAL["tag"])

    # Bottom B42 tag like the other mod previews
    bb = bd.textbbox((0, 0), "PROJECT ZOMBOID B42", font=tag_font)
    bd.text(((SIZE - (bb[2] - bb[0])) // 2, SIZE - 32), "PROJECT ZOMBOID B42",
            font=tag_font, fill=PAL["tag"])

    big.save(OUT)
    print(f"wrote {OUT} ({SIZE}x{SIZE})")


if __name__ == "__main__":
    main()
