"""Prepare the editable port texture/prop atlas; Pixelorama exports the PNG."""
import copy
import hashlib
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

import build_pixelorama_project as native

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/port_v6'
SOURCES = ART / 'sources'
CANVAS = (512, 512)
PIVOT = (256, 464)
MATERIALS = ['stone', 'sand', 'wood', 'mosaic', 'garden', 'crypt', 'grate', 'water']
PROPS = [
    ('obelisk', 'props', (20, 25, 320, 540), 400),
    ('brazier', 'props', (370, 140, 600, 540), 350),
    ('arch', 'props', (610, 25, 1000, 545), 380),
    ('stairs', 'props', (995, 95, 1448, 555), 270),
    ('stall', 'props', (0, 550, 420, 1080), 340),
    ('cargo', 'props', (420, 710, 780, 1080), 260),
    ('palm', 'props', (685, 530, 1065, 1086), 440),
    ('wall', 'props', (1035, 620, 1448, 1086), 280),
    ('warehouse', 'architecture', (0, 0, 732, 660), 410),
    ('temple', 'architecture', (730, 0, 1254, 620), 420),
    ('boat', 'architecture', (0, 650, 745, 1254), 360),
    ('lighthouse', 'architecture', (740, 585, 1254, 1254), 440),
]

def selection(image, rect, allow_near=True):
    crop = image.crop(rect).convert('RGBA')
    array = np.array(crop)
    rgb = array[:, :, :3].astype(np.int16)
    key = ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 1] > 180) & (rgb[:, :, 0] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 180) & (rgb[:, :, 2] < 85))
    active = ((array[:, :, 3] >= 24) & ~key).copy()
    height, width = active.shape
    components = []
    for sy, sx in zip(*np.nonzero(active)):
        if not active[sy, sx]:
            continue
        pending = [(int(sx), int(sy))]
        active[sy, sx] = False
        points = []
        while pending:
            x, y = pending.pop()
            points.append((x, y))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and active[ny, nx]:
                        active[ny, nx] = False
                        pending.append((nx, ny))
        xs, ys = zip(*points)
        components.append((points, (min(xs), min(ys), max(xs) + 1, max(ys) + 1)))
    if not components:
        raise RuntimeError(f'Empty prop: {rect}')
    main = max(components, key=lambda item: len(item[0]))
    mask = np.zeros((height, width), dtype=np.uint8)
    nearby = np.zeros((height, width), dtype=bool)
    for x, y in main[0]:
        nearby[y, x] = True
    # Use actual pixel proximity. A tree's wide canopy bounding box can contain
    # an unrelated amphora far from its trunk, even when the boxes intersect.
    for _ in range(20):
        before = nearby.copy()
        nearby[1:, :] |= before[:-1, :]
        nearby[:-1, :] |= before[1:, :]
        nearby[:, 1:] |= before[:, :-1]
        nearby[:, :-1] |= before[:, 1:]
    for points, bounds in components:
        keep = points is main[0] or (allow_near and len(points) >= 18 and any(nearby[y, x] for x, y in points))
        if keep:
            for x, y in points:
                mask[y, x] = 255
    alpha = Image.fromarray(mask).filter(ImageFilter.MaxFilter(3))
    crop.putalpha(ImageChops.multiply(crop.getchannel('A'), alpha))
    bounds = crop.getchannel('A').point(lambda value: 255 if value >= 16 else 0).getbbox()
    return crop.crop(bounds)

def build():
    sources = {name: Image.open(SOURCES / f'{name}.png').convert('RGBA') for name in ['materials', 'props', 'architecture']}
    frames = []
    tags = []
    for index, name in enumerate(MATERIALS):
        image = sources['materials']
        x, y = index % 4, index // 4
        rect = (round(x * image.width / 4), round(y * image.height / 2), round((x + 1) * image.width / 4), round((y + 1) * image.height / 2))
        frames.append(image.crop(rect).resize(CANVAS, Image.Resampling.LANCZOS))
        tags.append({'name': 'floor_' + name, 'from': index + 1, 'to': index + 1, 'color': 'b79a64ff'})
    entries = {}
    for name, source, rect, target_height in PROPS:
        crop = selection(sources[source], rect, allow_near=name != 'temple')
        factor = min(target_height / crop.height, 440 / crop.width)
        crop = crop.resize((max(1, round(crop.width * factor)), max(1, round(crop.height * factor))), Image.Resampling.LANCZOS)
        cel = Image.new('RGBA', CANVAS)
        cel.paste(crop, (PIVOT[0] - crop.width // 2, PIVOT[1] - crop.height))
        bounds = cel.getchannel('A').point(lambda value: 255 if value >= 16 else 0).getbbox()
        assert bounds and min(bounds[:2]) >= 0 and bounds[2] < 512 and bounds[3] < 512
        index = len(frames)
        frames.append(cel)
        tags.append({'name': 'prop_' + name, 'from': index + 1, 'to': index + 1, 'color': '6a9f95ff'})
        entries[name] = {'frame': index, 'content_size': list(crop.size), 'source': source, 'source_rect': list(rect)}
    data = native.project_data(len(frames), [1.0] * len(frames), tags, True)
    data['size_x'], data['size_y'] = CANVAS
    data['layers'][0]['name'] = 'Porto v6 — materiais e arquitetura'
    for effect in data['layers'][0]['effects']:
        effect['params']['size'] = 'Vector2(512, 512)'
    data['export_profile']['lines_count'] = '4'
    data['symmetry_points'] = [255.5, 255.5]
    path = ART / 'port_art_v6.pxo'
    with ZipFile(path, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(data, ensure_ascii=False))
        for index, frame in enumerate(frames):
            archive.writestr(f'image_data/frames/{index + 1}/layer_1', frame.tobytes())
    plan = {'version': 6, 'canvas': list(CANVAS), 'pivot': list(PIVOT), 'materials': MATERIALS, 'props': entries,
            'texture': 'res://assets/world/port_art_v6.png', 'frame_count': len(frames), 'texture_size': [2048, 2560],
            'source_hashes': {name: hashlib.sha256((SOURCES / f'{name}.png').read_bytes()).hexdigest() for name in sources}}
    (ART / 'export_plan.json').write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding='utf8')
    contact = Image.new('RGB', (1024, 1280), (15, 29, 34))
    for index, frame in enumerate(frames):
        thumb = frame.resize((256, 256), Image.Resampling.LANCZOS)
        contact.paste(thumb, ((index % 4) * 256, (index // 4) * 256), thumb)
    contact.save(ROOT / 'qa/port_art_preparation_v6.png')
    print(json.dumps({'project': str(path), 'frames': len(frames), 'props': len(entries)}, ensure_ascii=False))

if __name__ == '__main__':
    build()
