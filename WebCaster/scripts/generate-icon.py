#!/usr/bin/env python3
"""
Generate WebCaster app icon as a 1024x1024 PNG.
Requires: pip install Pillow
Run: python3 scripts/generate-icon.py
Output: WebCaster/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png
"""

import math
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow not installed. Install with: pip install Pillow")
    sys.exit(1)

SIZE = 1024
BG_COLOR = (18, 18, 23)         # Dark background #121217
ORANGE = (255, 109, 0)          # #FF6D00
WHITE = (255, 255, 255)
DARK_SURFACE = (28, 28, 36)     # Subtle circle bg

img = Image.new("RGBA", (SIZE, SIZE), BG_COLOR)
draw = ImageDraw.Draw(img)

# Rounded rect background with subtle gradient feel
for y in range(SIZE):
    ratio = y / SIZE
    r = int(BG_COLOR[0] + (DARK_SURFACE[0] - BG_COLOR[0]) * ratio * 0.5)
    g = int(BG_COLOR[1] + (DARK_SURFACE[1] - BG_COLOR[1]) * ratio * 0.5)
    b = int(BG_COLOR[2] + (DARK_SURFACE[2] - BG_COLOR[2]) * ratio * 0.5)
    draw.line([(0, y), (SIZE, y)], fill=(r, g, b))

# Outer circle (orange ring)
cx, cy = SIZE // 2, SIZE // 2 - 30
radius = 320
draw.ellipse(
    [cx - radius, cy - radius, cx + radius, cy + radius],
    outline=ORANGE, width=24
)

# Cast/signal arcs (representing casting)
for i, r in enumerate([180, 240, 300]):
    arc_width = 20 - i * 2
    bbox = [cx - r, cy - r, cx + r, cy + r]
    draw.arc(bbox, start=225, end=315, fill=ORANGE, width=arc_width)

# Play triangle in center
tri_size = 100
tri_cx = cx + 10
tri_cy = cy
points = [
    (tri_cx - tri_size // 2, tri_cy - tri_size),
    (tri_cx - tri_size // 2, tri_cy + tri_size),
    (tri_cx + tri_size, tri_cy),
]
draw.polygon(points, fill=ORANGE)

# "WebCaster" text at bottom
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 72)
except (OSError, IOError):
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 72)
    except (OSError, IOError):
        font = ImageFont.load_default()

text = "WebCaster"
bbox = draw.textbbox((0, 0), text, font=font)
tw = bbox[2] - bbox[0]
draw.text(((SIZE - tw) // 2, SIZE - 160), text, fill=WHITE, font=font)

# Save
script_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.dirname(script_dir)
output_dir = os.path.join(project_root, "WebCaster", "Resources", "Assets.xcassets", "AppIcon.appiconset")
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "icon_1024.png")
img.save(output_path, "PNG")
print(f"App icon saved to: {output_path}")

# Update Contents.json to reference the file
import json
contents_path = os.path.join(output_dir, "Contents.json")
contents = {
    "images": [
        {
            "filename": "icon_1024.png",
            "idiom": "universal",
            "platform": "ios",
            "size": "1024x1024"
        }
    ],
    "info": {
        "author": "xcode",
        "version": 1
    }
}
with open(contents_path, "w") as f:
    json.dump(contents, f, indent=2)
print(f"Contents.json updated: {contents_path}")
