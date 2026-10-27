"""Build editable low-resolution Pixelorama art, exported by Pixelorama itself.

One source pixel equals one world pixel for the props and 64x32 terrain.
Generated sources are preserved; the native projects contain the working cels.
"""
import copy
import json
import math
import random
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

import numpy as np
from PIL import Image, ImageDraw
import build_pixelorama_project as native
from build_port_art_v6 import selection

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/port_v7'
SOURCES = ART / 'sources'
CELL = 192
PIVOT = (96, 176)
PALETTE = ['14252c', '1e343a', '2b4449', '3c5659', '526765', '6d7b70',
           '8c9380', 'b4b298', 'dbcfaa', 'eee0ba', '343b38', '4b5553',
           '646b60', '81816e', 'a09a7e', 'bdad89', '332e28', '4b3b2d',
           '674d34', '846443', 'a27d50', 'c39e65', 'e0bd7e', '1f444b',
           '2c5b61', '3e7373', '609087', '5a623e', '7d8051', 'a49e66',
           'be733a', 'e69d4a', 'f5cc76']
THEMES = ['stone', 'sand', 'wood', 'mosaic', 'garden', 'crypt', 'aqueduct', 'arena']
RAMPS = {'stone': ['4b5553', '535e5b', '657069'], 'sand': ['81785e', '8b8267', 'a1997a'],
         'wood': ['5d4834', '6a5138', '866441'], 'mosaic': ['56635e', '606d66', '7b8576'],
         'garden': ['4c6050', '576b55', '738269'], 'crypt': ['424f55', '4c5960', '657078'],
         'aqueduct': ['4b6360', '56716a', '718c7c'], 'arena': ['655c51', '726858', '8f826b']}
PROP_NAMES = ['obelisk', 'brazier', 'arch', 'stairs', 'stall', 'cargo', 'palm', 'wall',
              'warehouse', 'temple', 'boat', 'lighthouse']
HEIGHTS = [68, 53, 84, 60, 68, 36, 98, 52, 116, 105, 110, 132]

def rgb(value):
    return tuple(int(value[i:i+2], 16) for i in (0, 2, 4))

def palette_image(image):
    """Explicit shared flat ramps; binary alpha, no random/diffusion dithering."""
    palette = Image.new('P', (1, 1))
    values = [v for color in PALETTE for v in rgb(color)]
    palette.putpalette(values + [0] * (768 - len(values)))
    alpha = image.getchannel('A').point(lambda a: 255 if a >= 96 else 0)
    out = image.convert('RGB').quantize(palette=palette, dither=Image.Dither.NONE).convert('RGBA')
    out.putalpha(alpha)
    return out

def floor_cel(theme, variant):
    tile = Image.new('RGBA', (64, 32))
    d = ImageDraw.Draw(tile)
    ramp = RAMPS[theme]
    diamond = [(0, 15), (31, 0), (63, 15), (32, 31)]
    d.polygon(diamond, fill='#' + ramp[variant % 2])
    # Four broad slabs, with a quiet seam. Pixels follow the 2:1 grid.
    seam = '#35463f' if theme not in ['crypt', 'wood'] else '#303f43' if theme == 'crypt' else '#3c3229'
    if theme == 'wood':
        for step in range(1, 5):
            x, y = round(step * 32 / 5), round(15 - step * 15 / 5)
            d.line([(x, y), (x + 31, y + 16)], fill=seam)
            d.line([(x + 1, y), (x + 31, y + 15)], fill='#' + ramp[2])
        d.line([(20 + variant * 2, 18), (28 + variant * 2, 22)], fill='#' + ramp[2])
        for x, y in [(13, 14), (48, 18)]:
            d.point((x, y), '#252f2f')
    else:
        d.line([(16, 8), (47, 24)], fill=seam)
        if variant % 2 == 0:
            d.line([(16, 23), (47, 8)], fill=seam)
        else:
            d.line([(31, 1), (32, 15), (47, 23)], fill=seam)
        if variant == 2:
            d.line([(39, 11), (35, 13), (38, 15), (34, 17)], fill=seam)
        rng = random.Random(THEMES.index(theme) * 13 + variant)
        for _ in range(6):
            x, y = rng.randrange(8, 55), rng.randrange(5, 27)
            if tile.getpixel((x, y))[3]:
                d.line([(x, y), (x + 1, y)], fill='#' + ramp[2])
        if theme in ['mosaic', 'arena'] and variant == 0:
            d.polygon([(29, 13), (32, 12), (35, 14), (32, 16)], fill='#a49e66')
        if theme == 'garden':
            d.line([(17, 8), (19, 9), (21, 8), (23, 9)], fill='#7d8051')
        if theme == 'aqueduct':
            d.line([(17, 8), (32, 16), (46, 9)], fill='#609087')
    # Continuous rim, avoiding noisy gold trim on every floor slab.
    d.line([(0, 15), (31, 0), (63, 15)], fill='#' + ramp[2])
    d.line([(63, 15), (32, 31), (0, 15)], fill=seam)
    # Any decorative stroke outside the diamond must remain transparent.
    mask = Image.new('L', tile.size)
    ImageDraw.Draw(mask).polygon(diamond, fill=255)
    tile.putalpha(mask)
    frame = Image.new('RGBA', (CELL, CELL))
    frame.paste(tile, (64, 80))
    return frame

def water_cel(frame_index):
    image = Image.new('RGBA', (128, 128), '#16343d')
    d = ImageDraw.Draw(image)
    # The same current moves through eight genuinely different cel drawings.
    for band in range(11):
        y = band * 13 - 8
        points = []
        for x in range(-8, 145, 4):
            rise = round(math.sin((x + band * 9 + frame_index * 2) * .065) * 3)
            points.append((x, y + rise))
        d.line(points, fill='#1c4148', width=4 if band % 2 else 2)
    rng = random.Random(781)
    for i in range(42):
        x = (rng.randrange(128) + frame_index) % 128
        y = rng.randrange(128)
        length = rng.randrange(3, 13)
        lift = round(math.sin(frame_index * math.tau / 8 + i) * 1.5)
        color = ['#28535b', '#28535b', '#386b6d', '#587e79'][i % 4]
        d.line([(x, y + lift), (x + length, y + lift)], fill=color)
        if i % 5 == 0:
            d.line([(x + 2, y + lift + 1), (x + length - 1, y + lift + 1)], fill='#28535b')
    frame = Image.new('RGBA', (CELL, CELL))
    frame.paste(image, (32, 32))
    return frame

def native_project(path, frames, tags, name, columns, fps=8):
    width, height = frames[0].size
    data = native.project_data(len(frames), [1.] * len(frames), tags, True)
    data['size_x'], data['size_y'] = width, height
    data['fps'] = fps
    data['layers'][0]['name'] = name
    data['layers'][0]['effects'] = []
    data['export_profile']['lines_count'] = str(columns)
    data['symmetry_points'] = [(width - 1) / 2, (height - 1) / 2]
    with ZipFile(path, 'w', ZIP_DEFLATED) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(data, ensure_ascii=False))
        for i, frame in enumerate(frames):
            archive.writestr(f'image_data/frames/{i+1}/layer_1', frame.tobytes())

def tag(name, start, end=None):
    return {'name': name, 'from': start + 1, 'to': (start if end is None else end) + 1, 'color': '609087ff'}

def build():
    SOURCES.mkdir(parents=True, exist_ok=True)
    frames, tags = [], []
    for theme in THEMES:
        start = len(frames)
        frames.extend(floor_cel(theme, i) for i in range(4))
        tags.append(tag('floor_' + theme, start, start + 3))
    source = Image.open(SOURCES / 'props_pixel.png').convert('RGBA')
    props = {}
    for i, name in enumerate(PROP_NAMES):
        x, y = i % 4, i // 4
        rect = (round(x * source.width / 4), round(y * source.height / 3),
                round((x+1) * source.width / 4), round((y+1) * source.height / 3))
        crop = selection(source, rect, allow_near=False)
        factor = min(HEIGHTS[i] / crop.height, 168 / crop.width)
        # Logical pixels are authored before native export. No per-frame resize in game.
        crop = palette_image(crop.resize((round(crop.width * factor), round(crop.height * factor)), Image.Resampling.NEAREST))
        cel = Image.new('RGBA', (CELL, CELL))
        cel.paste(crop, (PIVOT[0] - crop.width // 2, PIVOT[1] - crop.height))
        props[name] = {'frame': len(frames), 'content_size': list(crop.size)}
        tags.append(tag('prop_' + name, len(frames)))
        frames.append(cel)
    water_start = len(frames)
    frames.extend(water_cel(i) for i in range(8))
    tags.append(tag('water_current', water_start, len(frames)-1))
    native_project(ART / 'port_pixel_v7.pxo', frames, tags, 'Porto — pixels 1:1', 4)
    manifest = {'version': 7, 'pixel_art': True, 'canvas': [CELL, CELL], 'pivot': list(PIVOT),
                'columns': 4, 'texture': 'res://assets/world/port_pixel_v7.png',
                'floor_themes': THEMES, 'floor_region': [64, 80, 64, 32], 'props': props,
                'water': {'first_frame': water_start, 'frames': 8, 'fps': 8, 'region': [32, 32, 128, 128]}}
    (ART / 'export_plan.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
    contact = Image.new('RGBA', (CELL*4, CELL*13), '#14252c')
    for i, frame in enumerate(frames):
        contact.alpha_composite(frame, ((i % 4)*CELL, (i // 4)*CELL))
    contact.convert('RGB').save(ROOT / 'qa/port_pixel_v7_preparation.png')
    # Two separate editable projects: the cover isn't forced into a sprite atlas.
    for source_name, filename, size in [('title_pixel', 'port_title_v7', (640, 360)),
                                       ('portrait_pixel', 'senu_portrait_v7', (160, 192))]:
        image = Image.open(SOURCES / (source_name + '.png')).convert('RGBA')
        image = image.resize(size, Image.Resampling.NEAREST)
        if source_name == 'portrait_pixel':
            alpha = image.getchannel('A').point(lambda a: 255 if a >= 96 else 0)
            image.putalpha(alpha)
        native_project(ART / (filename + '.pxo'), [image], [tag(filename, 0)], filename, 1)
    print(json.dumps({'frames': len(frames), 'props': len(props), 'canvas': CELL,
                      'project': str(ART / 'port_pixel_v7.pxo')}, ensure_ascii=False))

if __name__ == '__main__':
    build()
