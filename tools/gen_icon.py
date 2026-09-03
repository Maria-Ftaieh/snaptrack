"""Generate three 1024x1024 SnapTrack app icons (light / dark / tinted).

Theme: an upward-trending line over four bars, with a small spark in the
upper-right corner. Solid rounded-square background per variant.

iOS 18 tinted variant: needs a grayscale image that iOS will tint with the
user's accent. We render foreground as bright on a dark background; the alpha
shape is what the OS uses.
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path(__file__).resolve().parent.parent / "snaptrack" / "Assets.xcassets" / "AppIcon.appiconset"


def vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size), top)
    px = img.load()
    for y in range(size):
        t = y / (size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        for x in range(size):
            px[x, y] = (r, g, b)
    return img


def solid(size: int, color: tuple[int, int, int]) -> Image.Image:
    return Image.new("RGB", (size, size), color)


def draw_icon(background: Image.Image, fg: tuple[int, int, int], spark: tuple[int, int, int]) -> Image.Image:
    """Paint chart + spark over the given background."""
    img = background.convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)

    # Four ascending bars across the lower-middle.
    base_y = 760
    bar_w = 110
    gap = 40
    heights = [180, 280, 380, 500]
    total_w = 4 * bar_w + 3 * gap
    start_x = (SIZE - total_w) // 2
    radius = 38
    for i, h in enumerate(heights):
        x0 = start_x + i * (bar_w + gap)
        y0 = base_y - h
        x1 = x0 + bar_w
        y1 = base_y
        # Slightly translucent so the line on top reads cleanly.
        alpha = 200
        d.rounded_rectangle((x0, y0, x1, y1), radius=radius, fill=(*fg, alpha))

    # Upward-trending line, hitting the top of each bar.
    line_pts = []
    for i, h in enumerate(heights):
        x0 = start_x + i * (bar_w + gap)
        line_pts.append((x0 + bar_w / 2, base_y - h))
    d.line(line_pts, fill=(*fg, 255), width=42, joint="curve")

    # Dots at each vertex.
    for (x, y) in line_pts:
        r = 32
        d.ellipse((x - r, y - r, x + r, y + r), fill=(*fg, 255))

    # Spark in the upper-right corner — 6-pointed star-ish glyph.
    cx, cy = 820, 220
    arms = 4
    inner = 26
    outer = 100
    star: list[tuple[float, float]] = []
    for k in range(arms * 2):
        ang = -math.pi / 2 + k * math.pi / arms
        r = outer if k % 2 == 0 else inner
        star.append((cx + r * math.cos(ang), cy + r * math.sin(ang)))
    d.polygon(star, fill=(*spark, 255))

    # Soft glow under the line (blurred copy).
    glow_layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_layer)
    gd.line(line_pts, fill=(*fg, 160), width=80, joint="curve")
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(28))

    img = Image.alpha_composite(img, glow_layer)
    img = Image.alpha_composite(img, overlay)
    return img.convert("RGB")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Light: warm yellow → orange background, white foreground, white spark.
    light_bg = vertical_gradient(SIZE, (255, 214, 64), (255, 122, 24))
    light = draw_icon(light_bg, fg=(255, 255, 255), spark=(255, 255, 255))
    light.save(OUT_DIR / "icon-light.png", "PNG")

    # Dark: deep indigo → near-black background, warm-yellow foreground.
    dark_bg = vertical_gradient(SIZE, (38, 18, 84), (10, 6, 32))
    dark = draw_icon(dark_bg, fg=(255, 213, 79), spark=(255, 255, 255))
    dark.save(OUT_DIR / "icon-dark.png", "PNG")

    # Tinted: dark gray background, near-white foreground (iOS recolors the
    # bright parts with the user's accent on top of system dark).
    tinted_bg = solid(SIZE, (28, 28, 30))
    tinted = draw_icon(tinted_bg, fg=(240, 240, 240), spark=(240, 240, 240))
    tinted.save(OUT_DIR / "icon-tinted.png", "PNG")

    # Update Contents.json to wire the filenames in.
    contents = """{
  "images" : [
    {
      "filename" : "icon-light.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "dark"
        }
      ],
      "filename" : "icon-dark.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "appearances" : [
        {
          "appearance" : "luminosity",
          "value" : "tinted"
        }
      ],
      "filename" : "icon-tinted.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""
    (OUT_DIR / "Contents.json").write_text(contents)
    print("Wrote:", *[p.name for p in OUT_DIR.iterdir()])


if __name__ == "__main__":
    main()
