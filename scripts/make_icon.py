#!/usr/bin/env python3
"""Génère app/UsageForecast.icns : jauge d'usage orange autour de l'étincelle de la barre de menu,
et les icônes de l'application mobile (mobile/pwa/icons) à partir du même dessin.
Dépendance : Pillow. Usage : python3 scripts/make_icon.py [--pwa-only]"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SIZE = 2048  # dessin en 2x puis réduit : bords lisses
ACCENT = (232, 133, 95)
TRACK = (255, 255, 255, 36)
SPARK = [(8, 1), (9, 6), (13, 3), (10, 7), (15, 8), (10, 9), (13, 13), (9, 10),
         (8, 15), (7, 10), (3, 13), (6, 9), (1, 8), (6, 7), (3, 3), (7, 6)]


def background(full_bleed: bool = False) -> Image.Image:
    gradient = Image.new("RGBA", (SIZE, SIZE))
    pixels = gradient.load()
    for y in range(SIZE):
        shade = int(44 - 28 * y / SIZE)
        for x in range(SIZE):
            pixels[x, y] = (shade, shade, shade + 3, 255)
    if full_bleed:   # icône « maskable » ou Apple : le système découpe lui-même la forme, le fond va jusqu'aux bords
        return gradient
    mask = Image.new("L", (SIZE, SIZE), 0)
    margin = int(SIZE * 0.05)
    ImageDraw.Draw(mask).rounded_rectangle(
        (margin, margin, SIZE - margin, SIZE - margin), radius=int(SIZE * 0.225), fill=255)
    gradient.putalpha(mask)
    return gradient


def arc_with_round_caps(draw: ImageDraw.ImageDraw, box, start, end, width, color):
    draw.arc(box, start, end, fill=color, width=width)
    center = SIZE / 2
    radius = (box[2] - box[0]) / 2 - width / 2
    for angle in (start, end):
        x = center + radius * math.cos(math.radians(angle))
        y = center + radius * math.sin(math.radians(angle))
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=color)


def draw_icon(full_bleed: bool = False, art_scale: float = 1.0) -> Image.Image:
    icon = background(full_bleed)
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    ring_width = int(SIZE * 0.075)
    pad = int(SIZE * 0.215)
    box = (pad, pad, SIZE - pad, SIZE - pad)
    sweep_start, sweep_total = 135, 270
    arc_with_round_caps(draw, box, sweep_start, sweep_start + sweep_total, ring_width, TRACK)
    arc_with_round_caps(draw, box, sweep_start, sweep_start + sweep_total * 0.65, ring_width, ACCENT + (255,))

    scale = SIZE * 0.024
    points = [(SIZE / 2 + (x - 8) * scale, SIZE / 2 + (y - 8) * scale) for x, y in SPARK]
    draw.polygon(points, fill=ACCENT + (255,))

    if art_scale != 1.0:   # zone de sécurité des icônes maskable : le dessin reste dans le cercle central
        side = int(SIZE * art_scale)
        small = layer.resize((side, side), Image.LANCZOS)
        layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        layer.paste(small, ((SIZE - side) // 2, (SIZE - side) // 2))
    icon.alpha_composite(layer)
    return icon


def write_icns(image: Image.Image, destination: Path) -> None:
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "icon.iconset"
        iconset.mkdir()
        for base in (16, 32, 128, 256, 512):
            for factor in (1, 2):
                pixels = base * factor
                name = f"icon_{base}x{base}{'@2x' if factor == 2 else ''}.png"
                image.resize((pixels, pixels), Image.LANCZOS).save(iconset / name)
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(destination)], check=True)


def write_svg(destination: Path) -> None:
    """Version vectorielle de l'icône (même géométrie que draw_icon, en unités d'un viewBox de 512)."""
    unit = 512 / SIZE
    pad = SIZE * 0.215
    width = SIZE * 0.075
    radius = ((SIZE - 2 * pad) / 2 - width / 2) * unit
    center = 256

    def point(angle: float) -> str:
        return f"{center + radius * math.cos(math.radians(angle)):.2f} {center + radius * math.sin(math.radians(angle)):.2f}"

    def arc(start: float, sweep: float, color: str) -> str:
        large = 1 if sweep > 180 else 0
        return (f'<path d="M{point(start)}A{radius:.2f} {radius:.2f} 0 {large} 1 {point(start + sweep)}" fill="none" '
                f'stroke="{color}" stroke-width="{width * unit:.2f}" stroke-linecap="round"/>')

    scale = 512 * 0.024
    spark = " ".join(f"{center + (x - 8) * scale:.1f},{center + (y - 8) * scale:.1f}" for x, y in SPARK)
    accent = "#%02x%02x%02x" % ACCENT
    destination.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
        '<defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2c2c2f"/><stop offset="1" stop-color="#101013"/></linearGradient></defs>'
        f'<rect x="{512 * 0.05:.1f}" y="{512 * 0.05:.1f}" width="{512 * 0.9:.1f}" height="{512 * 0.9:.1f}" rx="{512 * 0.225:.1f}" fill="url(#g)"/>'
        + arc(135, 270, "rgba(255,255,255,0.14)") + arc(135, 270 * 0.65, accent)
        + f'<polygon points="{spark}" fill="{accent}"/></svg>\n', encoding="utf-8")


def write_pwa_icons(directory: Path) -> None:
    """Icônes de l'application mobile : classique (192, 512), maskable plein cadre (512), Apple (180, sans transparence), SVG."""
    directory.mkdir(parents=True, exist_ok=True)
    classic = draw_icon()
    classic.resize((512, 512), Image.LANCZOS).save(directory / "icon-512.png")
    classic.resize((192, 192), Image.LANCZOS).save(directory / "icon-192.png")
    draw_icon(full_bleed=True, art_scale=0.74).resize((512, 512), Image.LANCZOS).save(directory / "icon-maskable-512.png")
    draw_icon(full_bleed=True, art_scale=0.9).convert("RGB").resize((180, 180), Image.LANCZOS).save(directory / "apple-touch-icon.png")
    write_svg(directory / "icon.svg")


if __name__ == "__main__":
    pwa_only = "--pwa-only" in sys.argv
    if not pwa_only:
        final = draw_icon()
        write_icns(final, ROOT / "app" / "UsageForecast.icns")
        print("OK : app/UsageForecast.icns")
    write_pwa_icons(ROOT / "mobile" / "pwa" / "icons")
    print("OK : mobile/pwa/icons")
