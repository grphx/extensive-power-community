#!/usr/bin/env python3
"""
Animated poster.gif for Extensive Power Rework (Community fork).

Takes the same base composition as poster.png (upscaled upstream image
in the top portion + "(Community Fork)" tag at the bottom) and adds a
subtle lightning-flicker animation to the bolt.

Animation principle: the bolt is bright yellow on near-black. A
periodic "flash" frame overbrightens the yellow pixels and adds a halo
in the bolt's bounding box, then settles back to baseline. Most frames
are baseline; the flash is brief, like a real arc.

Output: poster.gif (512x512). Loop is short and the colour palette is
quantised hard to keep the file under Steam's ~1 MB preview cap.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import os

HERE   = os.path.dirname(__file__)
SRC    = os.path.join(HERE, "source", "upstream_preview.jpg")
OUT    = os.path.join(HERE, "poster.gif")

TARGET = 512
BAND_H = 64
FPS    = 12
LOOP_FRAMES = 24    # 2 seconds at 12 fps

AMBER       = (255, 204, 0)
AMBER_SHADE = (140, 80, 0)


def make_base():
    """Return the static base image (everything that doesn't animate)."""
    src = Image.open(SRC).convert("RGB")
    upstream = src.resize((TARGET, TARGET - BAND_H), Image.NEAREST)
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
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    x = (TARGET - tw) // 2
    y = TARGET - BAND_H + (BAND_H - th) // 2 - 4
    d.text((x + 3, y + 3), text, font=font, fill=AMBER_SHADE)
    d.text((x,     y    ), text, font=font, fill=AMBER)
    return canvas


def is_bolt_pixel(rgb):
    """Heuristic: the upstream bolt and 'EPR - B42' title are bold yellow.
    We flicker the BOLT only; the title is in roughly the top quarter and
    is excluded by region in build_flash_overlay rather than colour."""
    r, g, b = rgb
    return r > 200 and g > 150 and b < 100


def build_flash_overlay(base):
    """Build a near-white version of the yellow pixels in the bolt region,
    blurred to a soft halo. Returned at full image size with alpha = 0 in
    non-bolt areas so it can be composited with variable opacity."""
    # Bolt region: roughly centred vertically in the upper half (above the
    # "Extensive Power" text). The upstream's bolt sits between y=120-280 at
    # 512 scale; widen for safety.
    bolt_x0, bolt_y0 = 150, 100
    bolt_x1, bolt_y1 = 360, 300

    # Build an RGBA image where bolt-yellow becomes white, else transparent.
    flash = Image.new("RGBA", (TARGET, TARGET), (0, 0, 0, 0))
    px = base.load()
    flash_px = flash.load()
    for y in range(bolt_y0, bolt_y1):
        for x in range(bolt_x0, bolt_x1):
            if is_bolt_pixel(px[x, y]):
                flash_px[x, y] = (255, 255, 220, 255)

    # Blur to a soft halo so the flash reads as light, not a hard recolour.
    flash = flash.filter(ImageFilter.GaussianBlur(radius=4))
    return flash


def main():
    base = make_base()
    flash_overlay = build_flash_overlay(base)

    # Flash intensity per frame. Mostly low (subtle pulse) with two bright
    # spikes per loop, like an arc that re-ignites. Bumped intensities so
    # the brightness shift survives palette quantisation.
    intensities = []
    for i in range(LOOP_FRAMES):
        if i in (4, 5):                     # first flash - bright
            intensities.append(1.5)
        elif i == 6:                        # decay
            intensities.append(0.8)
        elif i == 7:
            intensities.append(0.4)
        elif i in (15, 16):                 # second flash - bright
            intensities.append(1.3)
        elif i == 17:
            intensities.append(0.7)
        elif i == 18:
            intensities.append(0.35)
        else:
            # near-zero ambient
            intensities.append(0.05)

    frames = []
    for inten in intensities:
        layer = flash_overlay.copy()
        # Scale alpha by intensity, clamping to 255
        alpha = layer.split()[-1].point(lambda v: min(255, int(v * inten)))
        layer.putalpha(alpha)
        frame = base.copy().convert("RGBA")
        frame.alpha_composite(layer)
        # Quantize with more colours + Floyd-Steinberg dither so the bright
        # flash frames keep their highlight after palette reduction.
        frame = frame.convert("RGB").quantize(
            colors=64, method=Image.Quantize.MEDIANCUT,
            dither=Image.Dither.FLOYDSTEINBERG,
        )
        frames.append(frame)

    duration = int(1000 / FPS)
    frames[0].save(
        OUT,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        optimize=True,
        disposal=2,
    )
    print(f"wrote {OUT}  size={os.path.getsize(OUT) / 1024:.0f} KB  frames={LOOP_FRAMES}")


if __name__ == "__main__":
    main()
