#!/usr/bin/env python3
"""docimg.py: the one-pager's pictures from tools/shots.sh's screenshots.
Crops the 256x192 picture out of each 320x240 frame, scales it up with
whole pixels (crisp in print) and writes docs/img/NAME.png."""
import sys
from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'build/shots'
DST = 'docs/img'
PICKS = {               # docs name: screenshot (deterministic: fixed seeds)
    'title': 'title', 'play': 'play19', 'map': 'map34',
    'boss1': 'boss0_16', 'boss2': 'boss1_20', 'boss3': 'boss2_22',
    'boss4': 'boss3_20', 'finale': 'fin6',
}
for name, shot in PICKS.items():
    im = Image.open(f'{SRC}/{shot}.ppm').convert('RGB').crop((32, 24, 288, 216))
    if name == 'map':   # a debug build's "LOAD n" tally (not in a release)
        im.paste(im.getpixel((2, 100)), (0, 182, 256, 192))
    im.resize((768, 576), Image.NEAREST).save(f'{DST}/{name}.png', optimize=True)
# the title's logo (cropped to its letters, its stars dropped: orange or
# one row tall) and
# its cast, on their own
t = Image.open(f'{SRC}/title.ppm').convert('RGB').crop((32, 24, 288, 216))
bg = t.getpixel((0, 0))
logo = Image.new('RGB', (208, 34), bg)    # (one row's margin under it:
logo.paste(t.crop((24, 9, 232, 42)))     # row 42 has a star under the A)
px = logo.load(); h = logo.height
star = [(x, y) for y in range(h) for x in range(logo.width) if px[x, y] != bg and (
        (px[x, y][0] > 200 and px[x, y][2] < 120) or    # orange: never the logo's
        ((y == 0 or px[x, y - 1] == bg) and (y == h - 1 or px[x, y + 1] == bg)))]  # one row tall
for p in star:
    px[p] = bg
logo.resize((832, 136), Image.NEAREST).save(f'{DST}/logo.png', optimize=True)
for i, y in enumerate((70, 90, 110)):
    t.crop((68, y - 6, 92, y + 10)).resize((96, 64), Image.NEAREST).save(f'{DST}/cast{i+1}.png', optimize=True)
