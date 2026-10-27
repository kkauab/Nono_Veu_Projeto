"""Assemble directly drawn locomotion cels into a native Pixelorama project.

Only source selection, one fixed scale per view and translation are used. No
meshes, pose deformation, squash/stretch, image rotation or frame dissolves.
Pixelorama performs the native cleanup effects and exports the delivery atlas.
"""
import hashlib
import json
import math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops

import build_pixelorama_project as v3

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'art/pixelorama/senu/motion_v5_sources'
PROJECT = ROOT / 'art/pixelorama/senu/senu_motion_v5.pxo'
PLAN = ROOT / 'art/pixelorama/senu/export_plan_motion_v5.json'
SELECTIONS = ROOT / 'art/pixelorama/senu/motion_v5_selections.json'
CANVAS = (384, 384)
PIVOT = (192, 280)
GAME_SCALE = .26
FPS = 12.0
DIRS = ['down', 'down_right', 'right', 'up_right', 'up', 'up_left', 'left', 'down_left']
BASE_DIRS = ['down', 'down_right', 'right', 'up_right', 'up']
MIRRORS = {'up_left': 'up_right', 'left': 'right', 'down_left': 'down_right'}
LENGTHS = {'walk': .44, 'run': .40, 'dodge': .32}
PREFIX = {'espada': 'sword', 'leve': 'daggers'}


def alpha_bounds(image):
    return image.getchannel('A').point(lambda a: 255 if a >= 24 else 0).getbbox()


def gap(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0)
    dy = max(a[1] - b[3], b[1] - a[3], 0)
    return math.hypot(dx, dy)


def select_cell(image, col, row):
    """Recover feet crossing a grid boundary while rejecting the next row.

    Components are scored by overlap with the intended cell. An expanded crop
    retains the whole component; tiny separated blade/hand components nearby
    are retained, rather than deleting a weapon across a one-pixel gap.
    """
    cell = [round(col * image.width / 8), round(row * image.height / 5),
            round((col + 1) * image.width / 8), round((row + 1) * image.height / 5)]
    window = [max(0, cell[0] - 20), max(0, cell[1] - 38),
              min(image.width, cell[2] + 20), min(image.height, cell[3] + 38)]
    crop = image.crop(window).convert('RGBA')
    rgba = np.asarray(crop)
    rgb = rgba[:, :, :3].astype(np.int16)
    key = ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 1] > 180) & (rgb[:, :, 0] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 180) & (rgb[:, :, 2] < 85))
    active = ((rgba[:, :, 3] >= 24) & ~key).copy()
    height, width = active.shape
    core = [cell[0] - window[0], cell[1] - window[1], cell[2] - window[0], cell[3] - window[1]]
    components = []
    for sy, sx in zip(*np.nonzero(active)):
        if not active[sy, sx]:
            continue
        pending = [(int(sx), int(sy))]
        active[sy, sx] = False
        pixels = []
        score = 0
        while pending:
            x, y = pending.pop()
            pixels.append((x, y))
            score += int(core[0] <= x < core[2] and core[1] <= y < core[3])
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and active[ny, nx]:
                        active[ny, nx] = False
                        pending.append((nx, ny))
        xs, ys = zip(*pixels)
        components.append({'pixels': pixels, 'score': score,
                           'bounds': (min(xs), min(ys), max(xs) + 1, max(ys) + 1)})
    if not components:
        raise RuntimeError(f'Empty source cell {col}/{row}')
    body = max(components, key=lambda c: (c['score'], len(c['pixels'])))
    mask = np.zeros((height, width), dtype=np.uint8)
    retained = []
    for comp in components:
        if comp is body or (len(comp['pixels']) >= 5 and gap(comp['bounds'], body['bounds']) <= 7):
            for x, y in comp['pixels']:
                mask[y, x] = 255
            retained.append({'pixels': len(comp['pixels']), 'bounds': list(comp['bounds'])})
    selection = Image.fromarray(mask).filter(ImageFilter.MaxFilter(3))
    crop.putalpha(ImageChops.multiply(crop.getchannel('A'), selection))
    bounds = alpha_bounds(crop)
    if bounds is None:
        raise RuntimeError('Selection lost its body')
    # Keep positions relative to the ideal cell, even when recovered feet lie
    # outside it. Later placement uses a common root, not each frame's bounds.
    local_bounds = [bounds[0] + window[0] - cell[0], bounds[1] + window[1] - cell[1],
                    bounds[2] + window[0] - cell[0], bounds[3] + window[1] - cell[1]]
    return {'image': crop, 'cell': cell, 'window': window, 'bounds': local_bounds,
            'retained_components': retained}


def head_x(selection):
    image = selection['image']
    bounds = alpha_bounds(image)
    rgba = np.asarray(image)
    top = bounds[1]
    end = min(rgba.shape[0], top + max(8, round((bounds[3] - bounds[1]) * .14)))
    band = rgba[top:end]
    dark = (band[:, :, 3] >= 32) & (band[:, :, 0] < 95) & (band[:, :, 1] < 85) & (band[:, :, 2] < 80)
    _, xs = np.nonzero(dark)
    center = float(np.median(xs)) if len(xs) else (bounds[0] + bounds[2]) / 2
    return center + selection['window'][0] - selection['cell'][0]


def place(selection, factor, root, mirror=False):
    image = selection['image']
    # Exactly the same scale is applied to all eight drawings and all three
    # actions for this character/view. A tucked roll remains physically small.
    size = (round(image.width * factor), round(image.height * factor))
    image = image.resize(size, Image.Resampling.NEAREST)
    window_x = selection['window'][0] - selection['cell'][0]
    window_y = selection['window'][1] - selection['cell'][1]
    origin = (round(PIVOT[0] + (window_x - root[0]) * factor),
              round(PIVOT[1] + (window_y - root[1]) * factor))
    result = Image.new('RGBA', CANVAS)
    result.paste(image, origin)
    if mirror:
        # Reflection is about the common floor root, preserving the canvas.
        result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        fixed = Image.new('RGBA', CANVAS)
        fixed.paste(result, (1, 0))
        result = fixed
    bounds = alpha_bounds(result)
    assert bounds is not None and min(bounds[:2]) > 0 and bounds[2] < 384 and bounds[3] < 384, bounds
    return result


def leg_part_mask(image, grow=1):
    """Select the articulated boot/trouser part, preserving cloak and blades."""
    rgba = np.asarray(image)
    rgb = rgba[:, :, :3].astype(np.int16)
    yy, xx = np.indices(rgba.shape[:2])
    region = (abs(xx - PIVOT[0]) <= 25) & (yy >= 239) & (yy <= 294)
    warm = (rgb[:, :, 0] > rgb[:, :, 1] + 1) & (rgb[:, :, 1] > rgb[:, :, 2])
    teal = (rgb[:, :, 1] > rgb[:, :, 0] * 1.04) & (rgb[:, :, 2] > rgb[:, :, 0] * 1.01) & (rgba[:, :, 3] >= 16)
    protect = np.asarray(Image.fromarray((teal * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))) > 0
    active = (region & warm & ~protect & (rgba[:, :, 3] >= 12)).copy()
    selected = np.zeros(active.shape, dtype=np.uint8)
    height, width = active.shape
    for sy, sx in zip(*np.nonzero(active)):
        if not active[sy, sx]:
            continue
        pending = [(int(sx), int(sy))]
        active[sy, sx] = False
        component = []
        has_boot = False
        while pending:
            x, y = pending.pop()
            component.append((x, y))
            has_boot |= y >= 254
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and active[ny, nx]:
                        active[ny, nx] = False
                        pending.append((nx, ny))
        if has_boot and len(component) >= 15:
            for x, y in component:
                selected[y, x] = 255
    selected = np.asarray(Image.fromarray(selected).filter(ImageFilter.MaxFilter(grow * 2 + 1))).copy()
    selected[~region | protect] = 0
    # Key-color fringe is outside the selected drawing part, not a boot pixel.
    key = ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 1] > 180) & (rgb[:, :, 0] < 85) & (rgb[:, :, 2] < 85))
    key |= ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 180) & (rgb[:, :, 2] < 85))
    selected[key] = 0
    return Image.fromarray(selected)


def opposite_front_step(sequence):
    """Key opposite leg parts behind the untouched body/cape/held weapons.

    The supplied/generated frontal views favor one lead boot. The first half
    contains actual bent/supporting leg drawings; the opposite half reflects
    those lower-leg parts only. Neither the character nor its torso is scaled.
    """
    output = list(sequence)
    layers = {}
    for index in range(4, 8):
        source = sequence[index - 4]
        lower = source.copy()
        lower.putalpha(ImageChops.multiply(source.getchannel('A'), leg_part_mask(source)))
        lower = lower.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        shifted = Image.new('RGBA', CANVAS)
        shifted.paste(lower, (1, 0))
        lower = shifted
        body = sequence[index].copy()
        erase = leg_part_mask(body, grow=2)
        body.putalpha(ImageChops.multiply(body.getchannel('A'), ImageChops.invert(erase)))
        composed = Image.alpha_composite(lower, body)
        output[index] = composed
        layers[id(composed)] = (lower, body)
    return output, layers


def front_comparison(before, after):
    image = Image.new('RGB', (1280, 880), (18, 30, 35))
    draw = ImageDraw.Draw(image)
    for row, variant in enumerate(PREFIX):
        for col, index in enumerate([0, 2, 4, 6]):
            for offset, data, label in [(0, before, 'ANTES'), (220, after, 'DEPOIS / partes')]:
                crop = data[variant]['walk']['down'][index].crop((158, 223, 226, 289)).resize((272, 264), Image.Resampling.NEAREST)
                # Reduce slightly only in this inspection sheet to fit two rows.
                crop.thumbnail((248, 180), Image.Resampling.NEAREST)
                pos = (col * 320 + 32, row * 440 + offset + 28)
                image.paste(crop, pos, crop)
                draw.text((col * 320 + 8, row * 440 + offset + 7), f'{variant} {label} pose {index + 1}', fill=(229, 208, 169))
    image.save(ROOT / 'qa/motion_v5_front_parts_comparison.png')


def preview(variants):
    qa = ROOT / 'qa'
    qa.mkdir(exist_ok=True)
    rows = [('espada', 'walk', 'down'), ('espada', 'walk', 'right'), ('espada', 'run', 'right'),
            ('espada', 'dodge', 'right'), ('leve', 'walk', 'down'), ('leve', 'walk', 'right'),
            ('leve', 'run', 'right'), ('leve', 'dodge', 'right')]
    contact = Image.new('RGB', (1280, 1440), (18, 30, 35))
    draw = ImageDraw.Draw(contact)
    for row, key in enumerate(rows):
        variant, action, direction = key
        draw.text((10, row * 180 + 6), f'PREPARACAO / {variant} / {action} / {direction}', fill=(229, 208, 169))
        for index, image in enumerate(variants[variant][action][direction]):
            image = image.crop((80, 96, 304, 304))
            image.thumbnail((150, 150), Image.Resampling.NEAREST)
            contact.paste(image, (index * 160, row * 180 + 24), image)
    contact.save(qa / 'motion_v5_preparation_contact.png')
    for action in ['walk', 'run', 'dodge']:
        images = []
        for index in range(8):
            target = Image.new('RGB', (960, 460), (18, 30, 35))
            draw = ImageDraw.Draw(target)
            for row, variant in enumerate(['espada', 'leve']):
                draw.text((8, row * 225 + 7), f'PREPARACAO / {variant} / {action}', fill=(229, 208, 169))
                for col, direction in enumerate(['down', 'right', 'up_right', 'up']):
                    source = variants[variant][action][direction][index].crop((72, 88, 312, 310))
                    target.paste(source, (col * 240, row * 225 + 20), source)
            images.append(target)
        images[0].save(qa / f'motion_v5_preparation_{action}.gif', save_all=True, append_images=images[1:],
                       duration=round(LENGTHS[action] / 8 * 1000), loop=0, optimize=False)


def build():
    selected = {}
    sources = {}
    for variant, prefix in PREFIX.items():
        selected[variant] = {}
        for action in ['walk', 'run', 'dodge']:
            filename = f'{prefix}_{"roll" if action == "dodge" else action}_guided.png'
            path = SOURCE / filename
            image = Image.open(path).convert('RGBA')
            sources[filename] = hashlib.sha256(path.read_bytes()).hexdigest()
            selected[variant][action] = {direction: [select_cell(image, col, row) for col in range(8)]
                                         for row, direction in enumerate(BASE_DIRS)}
    variants = {variant: {action: {} for action in LENGTHS} for variant in PREFIX}
    metadata = {'source_directory': str(SOURCE), 'canvas': list(CANVAS), 'pivot': list(PIVOT),
                'operations': ['direct connected-component source selection', 'one fixed scale per character/view',
                               'translation from common ground root', 'horizontal reflection for missing views'],
                'forbidden_operations': ['mesh deformation', 'pose_transform', 'per-frame height normalization',
                                         'squash/stretch', 'dissolve'], 'variants': {}}
    for variant in PREFIX:
        metadata['variants'][variant] = {}
        for direction in BASE_DIRS:
            walk = selected[variant]['walk'][direction]
            reference_height = float(np.median([walk[index]['bounds'][3] - walk[index]['bounds'][1] for index in [0, 4]]))
            factor = 145.0 / reference_height
            row_meta = {'scale': factor, 'scale_reference': 'walk contact drawings 1 and 5, reused in run and roll',
                        'reference_height': reference_height, 'target_reference_height': 145, 'actions': {}}
            for action in LENGTHS:
                selections = selected[variant][action][direction]
                if action == 'dodge':
                    root_x = 0.5 * (selections[0]['cell'][2] - selections[0]['cell'][0])
                    root_y = float(np.median([selections[i]['bounds'][3] - 1 for i in [0, 7]]))
                else:
                    root_x = float(np.median([head_x(s) for s in selections]))
                    root_y = float(np.median([selections[i]['bounds'][3] - 1 for i in [0, 4]]))
                correction = (variant == 'espada' and action == 'walk' and direction == 'up_right') or (
                    variant == 'espada' and action == 'dodge' and direction == 'down_right')
                variants[variant][action][direction] = [place(s, factor, (root_x, root_y), correction) for s in selections]
                row_meta['actions'][action] = {'root': [root_x, root_y], 'source_mirror_correction': correction,
                                               'frames': [{key: value for key, value in s.items() if key != 'image'} for s in selections]}
            metadata['variants'][variant][direction] = row_meta
        for direction, base in MIRRORS.items():
            for action in LENGTHS:
                frames = []
                for image in variants[variant][action][base]:
                    mirror = image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                    frame = Image.new('RGBA', CANVAS)
                    frame.paste(mirror, (1, 0))
                    frames.append(frame)
                variants[variant][action][direction] = frames
    before_front = {variant: {'walk': {'down': list(variants[variant]['walk']['down'])}} for variant in PREFIX}
    part_layers = {}
    for variant in PREFIX:
        for direction in ['down', 'up']:
            corrected, layers = opposite_front_step(variants[variant]['walk'][direction])
            variants[variant]['walk'][direction] = corrected
            part_layers.update(layers)
        metadata['variants'][variant]['frontal_half_cycle'] = {
            'directions': ['down', 'up'], 'target_frames_zero_based': [4, 5, 6, 7],
            'source_frames_zero_based': [0, 1, 2, 3], 'part': 'brown neutral trousers and boots below tunic',
            'operation': 'horizontal reflection of drawn leg part around x=192, behind preserved upper body and cape',
            'native_layer': 'Passo oposto / pernas e botas', 'torso_weapons_cape_unchanged': True,
        }
    preview(variants)
    front_comparison(before_front, variants)
    frames, durations, tags, manifest_variants = [], [], [], {}
    for variant, prefix in PREFIX.items():
        clips = {}
        for action, length in LENGTHS.items():
            directions = {}
            for direction in DIRS:
                sequence = variants[variant][action][direction]
                assert len(sequence) == 8
                indices = list(range(len(frames), len(frames) + 8))
                directions[direction] = indices
                frames.extend(sequence)
                durations.extend([FPS * length / 8] * 8)
                tags.append({'name': f'{prefix}_{action}_{direction}', 'color': '927ac7ff' if variant == 'leve' else '6db0a4ff',
                             'from': indices[0] + 1, 'to': indices[-1] + 1})
            clips[action] = {'fps': 8 / length, 'loop': action != 'dodge', 'cycle_duration': length, 'directions': directions}
        manifest_variants[variant] = {'clips': clips}
    assert len(frames) == 384 and len(tags) == 48
    native = v3.project_data(len(frames), durations, tags, True)
    body_layer = native['layers'][0]
    body_layer['name'] = 'Senu v5 — corpo, capa e armas / poses desenhadas'
    leg_layer = dict(body_layer)
    leg_layer['name'] = 'Passo oposto / pernas e botas'
    leg_layer['effects'] = []
    native['layers'] = [leg_layer, body_layer]
    native['current_layer'] = 1
    for frame in native['frames']:
        frame['cels'] = [{'opacity': 1.0, 'z_index': 0}, {'opacity': 1.0, 'z_index': 0}]
    native['export_profile']['lines_count'] = '16'
    native['symmetry_points'] = [191.5, 191.5]
    PROJECT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(PROJECT, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(native, ensure_ascii=False))
        blank = Image.new('RGBA', CANVAS).tobytes()
        for index, image in enumerate(frames):
            lower, body = part_layers.get(id(image), (None, image))
            archive.writestr(f'image_data/frames/{index + 1}/layer_1', lower.tobytes() if lower is not None else blank)
            archive.writestr(f'image_data/frames/{index + 1}/layer_2', body.tobytes())
    with ZipFile(PROJECT) as archive:
        assert archive.testzip() is None
    plan = {'version': 5, 'canvas': list(CANVAS), 'pivot': list(PIVOT), 'game_scale': GAME_SCALE,
            'texture': 'res://assets/sprites/senu_motion_v5.png', 'frame_count': len(frames), 'frame_regions': [],
            'weapon_variants': manifest_variants, 'clips': manifest_variants['espada']['clips'], 'extras': {},
            'source_hashes': sources, 'notes': [
                'Locomotion cels are direct, anatomically posed source drawings; no mesh deformation or PNG scaling animation.',
                'One fixed scale per character/view is shared across walking, running and rolling.',
                'Ground roots are shared across a sequence; lifted feet and inverted bodies are not bbox-normalized.',
                'Missing western views mirror eastern drawings; two inspected source rows have explicit facing corrections.',
                'Frontal/back walk opposite-half contacts key reflected drawn lower-leg parts behind the unchanged body, cape and weapons; native parts remain separately editable.',
                'Pixelorama native effects perform color cleanup and generate the delivery PNG/JSON.',
            ]}
    PLAN.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding='utf8')
    SELECTIONS.write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding='utf8')
    print(json.dumps({'project': str(PROJECT), 'plan': str(PLAN), 'frames': len(frames), 'tags': len(tags),
                      'texture_size': [6144, 9216], 'preparation': str(ROOT / 'qa/motion_v5_preparation_contact.png')}, ensure_ascii=False))


if __name__ == '__main__':
    build()
