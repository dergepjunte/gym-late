#!/usr/bin/env python3
"""Generate the GymLate app icon: layered Liquid Glass dumbbell on warm gold.

Layers (back → front):
  1. Gold vertical gradient background
  2. Soft radial ambient top-left highlight
  3. Frosted glass slab behind the dumbbell (blurred white pane, low alpha)
  4. Drop shadow under dumbbell
  5. Dumbbell body: steel/cream gradient masked by silhouette
  6. Inner bottom rim emboss (dark edge for depth)
  7. Broad gloss sweep (diffuse light from above)
  8. Crisp specular streaks on plates (glass-on-glass refraction)
  9. Top edge-light: thin bright rim across upper edge of dumbbell
 10. Subtle bottom refraction tint (warm reflection from below)

Renders at 2048px, downsamples to the output sizes with LANCZOS.

Usage: python3 Scripts/generate_app_icon.py
"""

from PIL import Image, ImageDraw, ImageFilter
import os, math

S = 2048
BASE = os.path.join(os.path.dirname(__file__), "..")


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def vertical_gradient(size, stops):
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
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    cx, cy = size / 2, size / 2

    bar_h   = 0.052 * size
    inner_w = 0.062 * size
    inner_h = 0.26  * size
    inner_x = 0.205 * size
    outer_w = 0.048 * size
    outer_h = 0.185 * size
    outer_x = 0.325 * size

    d.rounded_rectangle([cx - 0.40 * size, cy - bar_h, cx + 0.40 * size, cy + bar_h],
                        radius=bar_h, fill=255)
    for sx in (-1, 1):
        x = cx + sx * inner_x
        d.rounded_rectangle([x - inner_w, cy - inner_h, x + inner_w, cy + inner_h],
                            radius=inner_w * 0.9, fill=255)
        x = cx + sx * outer_x
        d.rounded_rectangle([x - outer_w, cy - outer_h, x + outer_w, cy + outer_h],
                            radius=outer_w * 0.9, fill=255)
    return mask


def main():
    cx, cy = S / 2, S / 2

    # ── Layer 1: Background — deeper so the glass pane pops ─────────────────
    icon = vertical_gradient(S, [
        (0.00, "#fcd34d"),   # bright gold at top
        (0.35, "#f59e0b"),   # amber
        (0.65, "#b45309"),   # burnt amber
        (1.00, "#78350f"),   # very deep brown-gold at bottom
    ])

    # ── Layer 2: Radial ambient top-left highlight ────────────────────────────
    amb = Image.new("L", (S, S), 0)
    ad = ImageDraw.Draw(amb)
    ad.ellipse([-S * 0.45, -S * 0.50, S * 0.80, S * 0.55], fill=80)
    amb = amb.filter(ImageFilter.GaussianBlur(S * 0.11))
    icon.paste(Image.new("RGB", (S, S), (255, 248, 220)), (0, 0), amb)

    sil = dumbbell_silhouette(S)

    # ── Layer 3: Frosted glass pane (the "Liquid Glass" panel) ──────────────
    # Main frosted body — visible white/cream slab
    pane_mask = Image.new("L", (S, S), 0)
    pd = ImageDraw.Draw(pane_mask)
    pw, ph = S * 0.78, S * 0.58
    px0, py0 = cx - pw / 2, cy - ph / 2
    pd.rounded_rectangle([px0, py0, px0 + pw, py0 + ph], radius=S * 0.09, fill=255)
    pane_blur = pane_mask.filter(ImageFilter.GaussianBlur(S * 0.014))
    # Cream-warm fill for the frosted glass body
    pane_color = vertical_gradient(S, [(0.0, "#fffdf5"), (0.5, "#fef3c7"), (1.0, "#fde68a")])
    icon.paste(pane_color, (0, 0), pane_blur.point(lambda v: int(v * 0.38)))

    # Glass panel edge-light: thin bright rim around the pane (Liquid Glass border)
    pane_edge = Image.new("L", (S, S), 0)
    ped = ImageDraw.Draw(pane_edge)
    ped.rounded_rectangle([px0, py0, px0 + pw, py0 + ph], radius=S * 0.09, fill=255)
    pane_inner = Image.new("L", (S, S), 0)
    pid = ImageDraw.Draw(pane_inner)
    pid.rounded_rectangle([px0 + S * 0.012, py0 + S * 0.012,
                           px0 + pw - S * 0.012, py0 + ph - S * 0.012],
                          radius=S * 0.08, fill=255)
    pane_rim = Image.composite(pane_edge, Image.new("L", (S, S), 0), pane_edge)
    pane_rim.paste(Image.new("L", (S, S), 0), (0, 0), pane_inner)
    pane_rim = pane_rim.filter(ImageFilter.GaussianBlur(S * 0.004))
    icon.paste(Image.new("RGB", (S, S), (255, 252, 235)), (0, 0),
               pane_rim.point(lambda v: int(v * 0.92)))

    # Top-half sheen: horizontal bright gradient on upper pane (classic glass look)
    sheen = Image.new("L", (S, S), 0)
    sheen.paste(pane_mask, (0, 0))
    # Only upper half
    sheen_grad = Image.new("L", (S, S), 0)
    for row_y in range(S):
        t = row_y / S
        val = max(0, int(255 * (1 - t * 3.5)))  # bright at top, fades by ~28%
        sheen_grad.paste(val, (0, row_y, S, row_y + 1))
    sheen = Image.composite(sheen_grad, Image.new("L", (S, S), 0), sheen)
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0),
               sheen.point(lambda v: int(v * 0.28)))

    # ── Layer 4: Drop shadow under dumbbell ──────────────────────────────────
    shadow = Image.new("L", (S, S), 0)
    shadow.paste(sil.point(lambda v: int(v * 0.45)), (0, int(S * 0.048)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(S * 0.022))
    icon.paste(Image.new("RGB", (S, S), (50, 22, 0)), (0, 0), shadow)

    # ── Layer 5: Dumbbell body (steel/cream gradient) ─────────────────────────
    body = vertical_gradient(S, [
        (0.00, "#ffffff"),
        (0.30, "#f8f4ef"),
        (0.58, "#dedad6"),
        (0.80, "#c8c4c0"),
        (1.00, "#a0988e"),
    ])
    icon.paste(body, (0, 0), sil)

    # ── Layer 6: Inner bottom rim emboss ─────────────────────────────────────
    # Subtract upward-shifted sil from sil to get bottom-edge band
    rim = Image.new("L", (S, S), 0)
    rim.paste(sil, (0, -int(S * 0.013)))
    rim = Image.composite(Image.new("L", (S, S), 0), sil, rim)
    rim = rim.filter(ImageFilter.GaussianBlur(S * 0.005))
    icon.paste(Image.new("RGB", (S, S), (80, 50, 10)), (0, 0),
               rim.point(lambda v: int(v * 0.60)))

    # ── Layer 7: Broad gloss sweep (diffuse top-to-centre light) ─────────────
    gloss = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(gloss)
    gd.ellipse([S * 0.05, S * 0.28, S * 0.95, S * 0.54], fill=130)
    gloss = gloss.filter(ImageFilter.GaussianBlur(S * 0.018))
    gloss = Image.composite(gloss, Image.new("L", (S, S), 0), sil)
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), gloss)

    # ── Layer 8: Crisp specular streaks on plates ─────────────────────────────
    spec = Image.new("L", (S, S), 0)
    sd = ImageDraw.Draw(spec)
    for sx in (-1, 1):
        x = cx + sx * 0.205 * S
        # Primary inner-plate streak
        sd.ellipse([x - 0.026 * S, cy - 0.22 * S,
                    x + 0.026 * S, cy - 0.05 * S], fill=200)
        # Secondary outer-plate streak (slightly dimmer)
        x2 = cx + sx * 0.325 * S
        sd.ellipse([x2 - 0.018 * S, cy - 0.15 * S,
                    x2 + 0.018 * S, cy - 0.04 * S], fill=140)
    spec = spec.filter(ImageFilter.GaussianBlur(S * 0.009))
    spec = Image.composite(spec, Image.new("L", (S, S), 0), sil)
    icon.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0), spec)

    # ── Layer 9: Top edge-light (thin bright rim on upper dumbbell edge) ──────
    edgelight = Image.new("L", (S, S), 0)
    shifted_down = Image.new("L", (S, S), 0)
    shifted_down.paste(sil, (0, int(S * 0.008)))
    edgelight = Image.composite(sil, Image.new("L", (S, S), 0), Image.composite(
        Image.new("L", (S, S), 0), sil, shifted_down))
    edgelight = edgelight.filter(ImageFilter.GaussianBlur(S * 0.003))
    icon.paste(Image.new("RGB", (S, S), (255, 252, 240)), (0, 0),
               edgelight.point(lambda v: int(v * 0.85)))

    # ── Layer 10: Bottom refraction (warm amber tint on lower dumbbell edge) ──
    refract = Image.new("L", (S, S), 0)
    shifted_up = Image.new("L", (S, S), 0)
    shifted_up.paste(sil, (0, -int(S * 0.008)))
    refract = Image.composite(sil, Image.new("L", (S, S), 0), Image.composite(
        Image.new("L", (S, S), 0), sil, shifted_up))
    refract = refract.filter(ImageFilter.GaussianBlur(S * 0.003))
    icon.paste(Image.new("RGB", (S, S), (245, 180, 80)), (0, 0),
               refract.point(lambda v: int(v * 0.55)))

    # ── Outputs ───────────────────────────────────────────────────────────────
    icon_1024 = icon.resize((1024, 1024), Image.LANCZOS)

    ios_path = os.path.join(BASE, "GymLate", "Assets.xcassets",
                            "AppIcon.appiconset", "icon-1024.png")
    icon_1024.save(os.path.abspath(ios_path), "PNG")
    print(f"wrote {os.path.abspath(ios_path)}")

    web_dir = os.path.join(BASE, "..", "web-icons")
    os.makedirs(web_dir, exist_ok=True)

    for (size, name) in [(192, "icon-192.png"), (512, "icon-512.png"),
                          (180, "apple-touch-icon-180.png")]:
        p = os.path.join(web_dir, name)
        icon.resize((size, size), Image.LANCZOS).save(os.path.abspath(p), "PNG")
        print(f"wrote {os.path.abspath(p)}")


if __name__ == "__main__":
    main()
