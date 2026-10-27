"""Prepare sixteen fixed-scale enemy cels; Pixelorama performs the PNG export.

The original generated sheet is preserved. Each archetype uses one anatomical
scale across idle, two actual footstep poses and its strike. No frame is resized
at runtime to simulate animation.
"""
import json
import shutil
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from build_port_art_v6 import selection
import build_port_pixel_v7 as port

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/enemies_v8'
SOURCE = ROOT / 'art/pixelorama/enemies_v7/source_sheet.png'
NAMES = ['guard', 'runner', 'lancer', 'keeper']
HEIGHTS = [62, 59, 65, 65]
CELL, PIVOT = 160, (80, 140)


def build():
    ART.mkdir(parents=True, exist_ok=True)
    destination = ART / 'source_sheet.png'
    if not destination.exists():
        shutil.copyfile(SOURCE, destination)
    source = Image.open(destination).convert('RGBA')
    # The source rows aren't equal: the lancer's helmet starts above row three.
    rows = [(0, 320), (315, 615), (590, 920), (900, source.height)]
    frames, tags, profiles = [], [], {}
    extra = ['3b3542', '5a4a56', '826b73']
    port.PALETTE = port.PALETTE + extra
    for row, name in enumerate(NAMES):
        crops = []
        for col in range(4):
            x0 = max(0, round(col * source.width / 4) - 18)
            x1 = min(source.width, round((col + 1) * source.width / 4) + 18)
            crop = selection(source, (x0, rows[row][0], x1, rows[row][1]), allow_near=False)
            # Two generated step poses face the opposite way; orient the
            # anatomical sequence consistently before authoring the native cels.
            if (row, col) in [(1, 1), (3, 2)]:
                crop = crop.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            crops.append(crop)
        factor = HEIGHTS[row] / crops[0].height
        profiles[name] = {'row': row, 'height': HEIGHTS[row], 'source_scale': factor}
        for col, crop in enumerate(crops):
            # Foot contact, rather than the whole weapon bounding box, anchors
            # the root; an outstretched spear mustn't move the body sideways.
            alpha = np.array(crop.getchannel('A'))
            ys, xs = np.nonzero(alpha >= 96)
            bottom = int(ys.max()) + 1
            foot_x = float(np.median(xs[ys >= bottom - max(8, round(crop.height * .055))]))
            size = (max(1, round(crop.width * factor)), max(1, round(crop.height * factor)))
            small = port.palette_image(crop.resize(size, Image.Resampling.NEAREST))
            cel = Image.new('RGBA', (CELL, CELL))
            offset = (PIVOT[0] - round(foot_x * factor), PIVOT[1] - round(bottom * factor))
            cel.paste(small, offset)
            bounds = cel.getchannel('A').getbbox()
            assert bounds and bounds[0] >= 0 and bounds[1] >= 0 and bounds[2] < CELL and bounds[3] <= PIVOT[1] + 1
            frames.append(cel)
        tags.append(port.tag(name + '_poses', row * 4, row * 4 + 3))
    port.native_project(ART / 'port_enemies_v8.pxo', frames, tags, 'Sentinelas — pixels 1:1', 4, fps=8)
    plan = {'version': 8, 'texture': 'res://assets/sprites/port_enemies_v8.png',
            'canvas': [CELL, CELL], 'pivot': list(PIVOT), 'columns': 4,
            'profiles': profiles, 'poses': ['idle', 'left_step', 'right_step', 'strike'],
            'palette': port.PALETTE, 'source': 'art/pixelorama/enemies_v7/source_sheet.png'}
    (ART / 'export_plan.json').write_text(json.dumps(plan, indent=2), encoding='utf8')
    contact = Image.new('RGBA', (CELL*4, CELL*4), '#14252c')
    for index, frame in enumerate(frames):
        contact.alpha_composite(frame, ((index % 4) * CELL, (index // 4) * CELL))
    contact.resize((1024, 1024), Image.Resampling.NEAREST).convert('RGB').save(ROOT / 'qa/enemy_pixel_v8_preparation.png')
    print(json.dumps({'project': str(ART / 'port_enemies_v8.pxo'), 'frames': len(frames), 'profiles': profiles}, ensure_ascii=False))


if __name__ == '__main__':
    build()
