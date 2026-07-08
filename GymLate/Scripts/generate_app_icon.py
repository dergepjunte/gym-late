#!/usr/bin/env python3
"""Generate the GymLate app icon: a 3D-styled embossed dumbbell on a warm
yellow/gold gradient, with depth shadow, gloss highlights and a glassy finish.

Renders at 2048px and downsamples to the 1024px asset with LANCZOS for crisp
anti-aliasing. Output is opaque RGB (iOS requires no alpha) and un-rounded
(iOS masks the corners itself).

Usage: python3 Scripts/generate_app_icon.py
"""

from PIL import Image, ImageDraw, ImageFilter
import os

S = 2048  # working canvas size
OUT = os.path.join(os.path.dirname(__file__), "..",
                   "GymLate", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vertical_gradient(size, stops):
    """stops: list of (position 0..1, hex color)."""
    img = Image.new("RGB", (1, size))
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        for (p0, c0), (p1, c1) in zip(stops, stops[1:]):
            if p0 <= t <= p1:
                f = (t - p0) / (p1 - p0) if p1 > p0 else 0
                a, b = hex_rgb(c0), hex_rgb(c1)
                px[0, y] = tuple(round(a[i] + (b[i] - a[i]) * f) for i in range(3))
                break
    return img.resize((size, size))


def dumbbell_silhouette(size):
    """White-on-transparent mask of a classic dumbbell: horizontal bar,
    tall inner plates, shorter outer plates."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    cx, cy = size / 2, size / 2

    bar_h = 0.052 * size           # bar half-height
    inner_w = 0.062 * size         # inner plate half-width
    inner_h = 0.26 * size          # inner plate half-height
    inner_x = 0.205 * size         # inner plate center offset
    outer_w = 0.048 * size
    outer_h = 0.185 * size
    outer_x = 0.325 * size

    # bar (spans slightly past the outer plates for the handle stubs)
    d.rounded_rectangle([cx - 0.40 * size, cy - bar_h, cx + 0.40 * size, cy + bar_h],
                        radius=bar_h, fill=255)
    for sx in (-1, 1):
        # inner plates
        x = cx + sx * inner_x
        d.rounded_rectangle([x - inner_w, cy - inner_h, x + inner_w, cy + inner_h],
                            radius=inner_w * 0.9, fill=255)
        # outer plates
        x = cx + sx * outer_x
        d.rounded_rectangle([x - outer_w, cy - outer_h, x + outer_w, cy + outer_h],
                            radius=outer_w * 0.9, fill=255)
    return mask


def main():
    # 1. Background: warm gold gradient + radial highlight top-left
    icon = vertical_gradient(S, [(0.0, "#fde68a"), (0.55, "#f59e0b"), (1.0, "#b45309")])

    highlight = Image.new("L", (S, S), 0)
    hd = ImageDraw.Draw(highlight)
    hd.ellipse([-S * 0.35, -S * 0.45, S * 0.75, S * 0.55], fill=70)
    highlight = highlight.filter(ImageFilter.GaussianBlur(S * 0.09))
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), highlight)

    sil = dumbbell_silhouette(S)

    # 2. Depth shadow under the dumbbell
    shadow = Image.new("L", (S, S), 0)
    shadow.paste(sil.point(lambda v: int(v * 0.38)), (0, int(S * 0.045)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.02))
    icon.paste(Image.new("RGB", (S, S), (40, 18, 0)), (0, 0), shadow)

    # 3. Dumbbell body: steel/cream vertical gradient, masked by silhouette
    body = vertical_gradient(S, [(0.0, "#fffbeb"), (0.42, "#efeae2"),
                                 (0.62, "#d6d3d1"), (1.0, "#a8a29e")])
    icon.paste(body, (0, 0), sil)

    # 4a. Inner bottom rim (embossed edge): darken the lowest band inside the shape
    rim = Image.new("L", (S, S), 0)
    rim.paste(sil, (0, -int(S * 0.012)))
    rim = Image.composite(Image.new("L", (S, S), 0), sil, rim)  # sil minus shifted sil
    rim = rim.filter(ImageFilter.GaussianBlur(S * 0.004))
    icon.paste(Image.new("RGB", (S, S), (90, 60, 20)), (0, 0), rim.point(lambda v: int(v * 0.55)))

    # 4b. Gloss: blurred white sweep across the upper third, masked to the shape
    gloss = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gloss)
    gd.ellipse([S * 0.08, S * 0.30, S * 0.92, S * 0.50], fill=115)
    gloss = gloss.filter(ImageFilter.GaussianBlur(S * 0.015))
    gloss = Image.composite(gloss, Image.new("L", (S, S), 0), sil)
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), gloss)

    # 4c. Specular streaks on the plates for the glassy finish
    spec = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(spec)
    for sx in (-1, 1):
        x = S / 2 + sx * 0.205 * S
        sd.ellipse([x - 0.028 * S, S / 2 - 0.22 * S,
                    x + 0.028 * S, S / 2 - 0.06 * S], fill=170)
    spec = spec.filter(ImageFilter.GaussianBlur(S * 0.010))
    spec = Image.composite(spec, Image.new("L", (S, S), 0), sil)
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), spec)

    # 5. Downsample and save opaque
    icon = icon.resize((1024, 1024), Image.LANCZOS)
    icon.save(os.path.abspath(OUT), "PNG")
    print(f"wrote {os.path.abspath(OUT)}")


if __name__ == "__main__":
    main()
