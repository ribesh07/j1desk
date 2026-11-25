"""Draws the Tickets logo (same as the web favicon src/app/icon.svg) as app icons.

Logo, in favicon units relative to its centre (12,12):
  three bars (2 units thick, round ends): y=-3.5 x -5..5, y=0 x -5..2, y=3.5 x -5..-1
  green dot: centre (4.5, 3.5), radius 2
"""
import sys
from PIL import Image, ImageDraw

BG = (13, 17, 23, 255)        # #0d1117  GitHub dark background
FG = (240, 246, 252, 255)     # #f0f6fc
GREEN = (63, 185, 80, 255)    # #3fb950
CONTENT_RADIUS = 7.7          # how far the logo reaches from its centre (favicon units)
SS = 4                        # supersampling for smooth edges

def draw_logo(size, radius_frac, background, bar_color, dot_color):
    W = size * SS
    img = Image.new("RGBA", (W, W), background)
    d = ImageDraw.Draw(img)
    u = radius_frac * W / CONTENT_RADIUS          # pixels per favicon unit
    cx = cy = W / 2
    # nudge so the visual weight (bars + dot) is centred
    cx -= 0.25 * u   # logo spans x -6..6.5, y -4.5..5.5 → move to the true centre
    cy -= 0.5 * u
    for y, x1, x2 in [(-3.5, -5, 5), (0, -5, 2), (3.5, -5, -1)]:
        d.rounded_rectangle(
            [cx + (x1 - 1) * u, cy + (y - 1) * u, cx + (x2 + 1) * u, cy + (y + 1) * u],
            radius=u, fill=bar_color)
    d.ellipse([cx + 2.5 * u, cy + 1.5 * u, cx + 6.5 * u, cy + 5.5 * u], fill=dot_color)
    return img.resize((size, size), Image.LANCZOS)

out = sys.argv[1]
# 1. Full icon (Play Store, iOS, legacy Android): opaque dark square
draw_logo(1024, 0.30, BG, FG, GREEN).convert("RGB").save(f"{out}/assets/icon/icon.png")
# 2. Adaptive icon foreground: transparent, logo inside the 66% safe zone
draw_logo(1024, 0.24, (0, 0, 0, 0), FG, GREEN).save(f"{out}/assets/icon/foreground.png")
# 3. Monochrome (Android 13+ themed icons): single colour on transparent
draw_logo(1024, 0.24, (0, 0, 0, 0), (255, 255, 255, 255), (255, 255, 255, 255)).save(f"{out}/assets/icon/monochrome.png")
# 4. Play Store listing icon: 512x512, 32-bit PNG
draw_logo(512, 0.30, BG, FG, GREEN).save(f"{out}/store/playstore-icon-512.png")
print("ok")
# 5. Status-bar notification icon: white on transparent, 24dp in every density
for folder, px in [("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)]:
    import os
    path = f"{out}/android/app/src/main/res/drawable-{folder}"
    os.makedirs(path, exist_ok=True)
    draw_logo(px, 0.42, (0, 0, 0, 0), (255, 255, 255, 255), (255, 255, 255, 255)).save(f"{path}/ic_notification.png")
