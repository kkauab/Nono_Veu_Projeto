"""Prepare Senu v4's editable Pixelorama timeline, not its delivery PNG.

The supplied sword art and the generated dagger poses remain unchanged. Region
keyframes make continuous gait cycles; Pixelorama performs native color cleanup
and the real export. No frame dissolves or optical-flow ghosts are used.
"""
import hashlib
import json
import math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

import numpy as np
from PIL import Image, ImageDraw, ImageChops, ImageFilter

import build_pixelorama_project as v3

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / 'art/pixelorama/senu/sources'
PROJECT = ROOT / 'art/pixelorama/senu/senu_v4.pxo'
PLAN = ROOT / 'art/pixelorama/senu/export_plan_v4.json'
SELECTIONS = ROOT / 'art/pixelorama/senu/v4_pose_selections.json'
CANVAS = (384, 384)
PIVOT = (192, 280)
FPS = 12.0
DIRECTIONS = ['down', 'down_right', 'right', 'up_right', 'up', 'up_left', 'left', 'down_left']
HEADINGS = {'down': (0, 1), 'down_right': (.707, .707), 'right': (1, 0),
            'up_right': (.707, -.707), 'up': (0, -1), 'up_left': (-.707, -.707),
            'left': (-1, 0), 'down_left': (-.707, .707)}
STATES = ['idle', 'walk', 'attack_light', 'attack_heavy', 'dodge', 'parry', 'hurt', 'death', 'power']


def alpha_bounds(image):
    return image.getchannel('A').point(lambda a: 255 if a >= 24 else 0).getbbox()


def crop_selection(image, rect):
    """Select a single connected pose from a nonuniform source cell."""
    crop = image.crop(tuple(rect)).convert('RGBA')
    pixels = np.array(crop)
    rgb = pixels[:, :, :3].astype(np.int16)
    chroma = ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] < 85) & (rgb[:, :, 2] < 85))
    chroma |= ((rgb[:, :, 1] > 180) & (rgb[:, :, 0] < 85) & (rgb[:, :, 2] < 85))
    chroma |= ((rgb[:, :, 0] > 180) & (rgb[:, :, 1] > 180) & (rgb[:, :, 2] < 85))
    active = (pixels[:, :, 3] >= 24) & ~chroma
    height, width = active.shape
    pending = []
    components = []
    for y, x in zip(*np.nonzero(active)):
        if not active[y, x]:
            continue
        active[y, x] = False
        pending.append((int(x), int(y)))
        component = []
        while pending:
            cx, cy = pending.pop()
            component.append((cx, cy))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < width and 0 <= ny < height and active[ny, nx]:
                        active[ny, nx] = False
                        pending.append((nx, ny))
        components.append(component)
    if not components:
        raise RuntimeError(f'Empty generated pose: {rect}')
    mask = Image.new('L', crop.size, 0)
    mask_data = np.zeros((height, width), dtype=np.uint8)
    for x, y in max(components, key=len):
        mask_data[y, x] = 255
    mask = Image.fromarray(mask_data).filter(ImageFilter.MaxFilter(3))
    crop.putalpha(ImageChops.multiply(crop.getchannel('A'), mask))
    return crop


def foot_center(image, bounds):
    """Use soles rather than blades/cape bounds to establish the common pivot."""
    a = np.array(image.getchannel('A'))
    bottom = bounds[3]
    section = a[max(bounds[1], bottom - 15):bottom]
    ys, xs = np.nonzero(section >= 32)
    return float(xs.mean()) if len(xs) else (bounds[0] + bounds[2]) * .5


def normalize_pose(crop, factor=None, height=150, mirror=False):
    bounds = alpha_bounds(crop)
    if bounds is None:
        raise RuntimeError('Pose selection is empty')
    if factor is None:
        factor = height / (bounds[3] - bounds[1])
    px = foot_center(crop, bounds)
    py = bounds[3] - 1
    size = (round(crop.width * factor), round(crop.height * factor))
    result = crop.resize(size, Image.Resampling.NEAREST)
    px, py = px * factor, py * factor
    if mirror:
        result = result.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        px = result.width - 1 - px
    canvas = Image.new('RGBA', CANVAS)
    canvas.paste(result, (round(PIVOT[0] - px), round(PIVOT[1] - py)))
    return canvas


def inverse_field(x, y, phase, direction, mode='walk', strength=1.0):
    """Continuous inverse mesh, with separate support/swing leg displacement.

    Movement below the tunic is split on the two legs. The support leg follows
    the floor while the opposite boot lifts; arms counter-swing and the cape
    follows with a phase delay. The head retains its original proportions.
    """
    x0, floor = PIVOT
    dx0 = x - x0
    hx, hy = HEADINGS[direction]
    foot_weight = min(1.0, max(0.0, (y - 241.0) / 37.0))
    # Smooth split avoids a seam through the tunic/boot boundary.
    side = math.tanh(dx0 / 7.0)
    leg_wave = math.sin(phase) * side
    hip_weight = min(1.0, max(0.0, (y - 228.0) / 42.0))
    foot_lift = max(0.0, leg_wave) * foot_weight
    upper = min(1.0, max(0.0, (floor - y) / 95.0))
    body_bob = -1.25 * (1.0 - math.cos(phase * 2.0))
    arm_weight = max(0.0, 1.0 - abs(y - 218.0) / 31.0) * min(1.0, abs(dx0) / 32.0)
    cape_weight = max(0.0, 1.0 - abs(y - 230.0) / 52.0) * min(1.0, max(0.0, abs(dx0) - 14.0) / 35.0)
    if mode == 'idle':
        # Four slightly asymmetric keys prevent a two-frame breathing flip.
        move_x = .65 * math.sin(phase) * upper + .7 * math.sin(phase - .9) * cape_weight
        move_y = -.7 * math.sin(phase) * upper - .25 * math.cos(phase) * arm_weight
    else:
        # Walking forward/back shifts the feet vertically; profile stride is
        # horizontal. Opposing leg waves prevent a whole-body wobble.
        move_x = (hx * 8.0 * leg_wave + side * .8 * math.sin(phase)) * hip_weight
        move_y = hy * 4.0 * leg_wave * hip_weight - 4.2 * foot_lift
        move_x += -.9 * math.sin(phase) * upper
        move_y += body_bob * (1.0 - foot_weight)
        move_x += -2.3 * math.sin(phase) * side * arm_weight
        move_y += 1.7 * math.sin(phase) * side * arm_weight
        move_x += 2.1 * math.sin(phase - .8) * cape_weight
        move_y += .8 * math.cos(phase - .8) * cape_weight
    return x - strength * move_x, y - strength * move_y


def mesh_frame(image, phase, direction, mode='walk', strength=1.0):
    mesh = []
    step = 12
    for y in range(0, CANVAS[1], step):
        for x in range(0, CANVAS[0], step):
            right, bottom = min(CANVAS[0], x + step), min(CANVAS[1], y + step)
            points = [(x, y), (x, bottom), (right, bottom), (right, y)]
            quad = tuple(value for px, py in points for value in inverse_field(px, py, phase, direction, mode, strength))
            mesh.append(((x, y, right, bottom), quad))
    return image.transform(CANVAS, Image.Transform.MESH, mesh, Image.Resampling.NEAREST)


def pose_transform(image, lean=0.0, compress=1.0, lift=0.0, shift=0.0):
    """A keyed, anchored action deformation with a fixed floor reference."""
    # inverse of x' = x + lean*(floor-y) + shift,
    # y' = floor + (y-floor)*compress + lift.
    a = 1.0
    b = lean / compress
    c = -shift - lean * (PIVOT[1] + lift) / compress
    d = 0.0
    e = 1.0 / compress
    f = PIVOT[1] - (PIVOT[1] + lift) / compress
    return image.transform(CANVAS, Image.Transform.AFFINE, (a, b, c, d, e, f), Image.Resampling.NEAREST)


def fall_pose(image, progress, direction):
    """Collapse to the ground without reusing the old Blender body."""
    bbox = alpha_bounds(image)
    crop = image.crop(bbox)
    angle = (74 if HEADINGS[direction][0] <= 0 else -74) * progress
    crop = crop.rotate(angle, Image.Resampling.NEAREST, expand=True)
    scale_y = 1.0 - .58 * progress
    crop = crop.resize((crop.width, max(1, round(crop.height * scale_y))), Image.Resampling.NEAREST)
    canvas = Image.new('RGBA', CANVAS)
    canvas.paste(crop, (PIVOT[0] - crop.width // 2, PIVOT[1] - crop.height + 2))
    return canvas


def dagger_poses():
    directions_image = Image.open(SOURCES / 'daggers_directions_v4.png').convert('RGBA')
    combat_image = Image.open(SOURCES / 'daggers_combat_v4.png').convert('RGBA')
    # The generated visual directions are inspected rather than assumed from
    # prompt order. The absent northeast base uses the northwest reflection.
    cells = {'down': (0, 0, False), 'down_left': (1, 0, False), 'left': (2, 0, False),
             'up_left': (3, 0, False), 'up': (0, 1, False), 'right': (2, 1, False),
             'down_right': (3, 1, False), 'up_right': (3, 0, True)}
    selections = {'directions': {}, 'combat': {}, 'notes': [
        'Generated reference orientation was visually inspected; northeast base is reflected northwest.',
        'Action views use four real diagonal key-pose rows; cardinal actions choose the nearest row.',
        'Cels are source selections and keyed mesh deformation, not optical-flow or dissolve frames.',
    ]}
    base = {}
    for name, (col, row, mirror) in cells.items():
        rect = [col * 384, row * 512, (col + 1) * 384, (row + 1) * 512]
        crop = crop_selection(directions_image, rect)
        base[name] = normalize_pose(crop, mirror=mirror)
        selections['directions'][name] = {'rect': rect, 'mirror': mirror, 'body_height': 150}
    combat = {}
    for name, row in [('down_left', 0), ('down_right', 1), ('up_left', 2), ('up_right', 3)]:
        crops = []
        rectangles = []
        for col in range(4):
            rect = [round(col * combat_image.width / 4), round(row * combat_image.height / 4),
                    round((col + 1) * combat_image.width / 4), round((row + 1) * combat_image.height / 4)]
            crops.append(crop_selection(combat_image, rect))
            rectangles.append(rect)
        # Recovery is the standing scale reference; anticipation stays crouched.
        standing_bounds = alpha_bounds(crops[3])
        factor = 150.0 / (standing_bounds[3] - standing_bounds[1])
        combat[name] = [normalize_pose(crop, factor=factor) for crop in crops]
        selections['combat'][name] = {'rectangles': rectangles, 'scale': factor}
    for cardinal, diagonal in [('down', 'down_left'), ('left', 'down_left'), ('up', 'up_left'), ('right', 'down_right')]:
        combat[cardinal] = combat[diagonal]
    SELECTIONS.write_text(json.dumps(selections, ensure_ascii=False, indent=2), encoding='utf-8')
    return base, combat


def dagger_actions(base, keys, direction):
    hx, hy = HEADINGS[direction]
    side = 1.0 if hx >= 0 else -1.0
    # Eight drawings support two contacts (indices2/5), so the second hit is
    # visually distinct rather than restarting the same long-sword sequence.
    light = [pose_transform(keys[0], -side * .018, .98), keys[0], keys[1],
             pose_transform(keys[1], side * .025, .99, 0, side * 1.5),
             pose_transform(keys[2], -side * .025, .99, 0, -side * 1.5), keys[2],
             pose_transform(keys[3], side * .01, .99), keys[3]]
    heavy = [pose_transform(keys[0], -side * .035, .95), keys[0],
             pose_transform(keys[1], side * .04, .97), keys[1], keys[2], keys[3]]
    dodge = [pose_transform(base, side * lean, comp, lift, side * shift)
             for lean, comp, lift, shift in [(-.03, .96, 0, 0), (.09, .88, -1, 1), (.16, .79, -3, 2),
                                            (.17, .80, -3, 2), (.08, .9, -1, 1), (0, 1, 0, 0)]]
    guard = [pose_transform(base, side * lean, comp, lift)
             for lean, comp, lift in [(0, 1, 0), (-.025, .96, 0), (-.03, .95, -1), (0, 1, 0)]]
    hurt = [pose_transform(base, -side * .07, .95, 0), pose_transform(base, -side * .035, .98, 0), base]
    death = [fall_pose(base, progress, direction) for progress in [.2, .64, 1.0]]
    power = [pose_transform(base, side * lean, comp, lift, side * shift)
             for lean, comp, lift, shift in [(-.02, .94, 0, 0), (.14, .83, -4, 2), (.24, .73, -7, 4),
                                            (.22, .76, -7, 4), (.1, .89, -3, 2), (0, 1, 0, 0)]]
    return {'attack_light': light, 'attack_heavy': heavy, 'dodge': dodge, 'parry': guard,
            'hurt': hurt, 'death': death, 'power': power}


def frames_hash(frames, durations):
    digest = hashlib.sha256(json.dumps(durations).encode())
    for frame in frames:
        digest.update(frame.tobytes())
    return digest.hexdigest()


def preview(variants, extras):
    output = ROOT / 'qa'
    output.mkdir(exist_ok=True)
    # Only inspection media. Delivery PNG must still be exported by Pixelorama.
    contact = Image.new('RGB', (1440, 920), (19, 31, 36))
    draw = ImageDraw.Draw(contact)
    rows = [('espada', 'walk', 'down'), ('espada', 'walk', 'right'),
            ('leve', 'walk', 'down'), ('leve', 'walk', 'right'),
            ('leve', 'attack_light', 'down_left'), ('leve', 'attack_light', 'up_right')]
    for y, (variant, state, direction) in enumerate(rows):
        frames = variants[variant][state][direction]
        draw.text((8, y * 150 + 8), f'{variant} / {state} / {direction}', fill=(224, 205, 167))
        for x, image in enumerate(frames):
            crop = image.crop((96, 112, 288, 300))
            crop.thumbnail((112, 118), Image.Resampling.NEAREST)
            contact.paste(crop, (x * 118, y * 150 + 24), crop)
    contact.save(output / 'senu_v4_preparation_contact.png')
    animated = []
    for index in range(12):
        canvas = Image.new('RGB', (760, 440), (19, 31, 36))
        draw = ImageDraw.Draw(canvas)
        for y, variant in enumerate(['espada', 'leve']):
            draw.text((8, y * 210 + 8), variant + ' / 12 walk keys', fill=(224, 205, 167))
            for x, direction in enumerate(['down', 'down_left', 'right', 'up']):
                image = variants[variant]['walk'][direction][index].crop((96, 112, 288, 300))
                canvas.paste(image, (x * 190, y * 210 + 20), image)
        animated.append(canvas)
    animated[0].save(output / 'senu_v4_preparation_walk.gif', save_all=True, append_images=animated[1:], duration=55, loop=0)


def build():
    data = json.loads((ROOT / 'tools/pixelorama/source_frames.json').read_text(encoding='utf-8'))
    originals = {name: Image.open(SOURCES / (name + '.png')).convert('RGBA') for name in v3.SOURCES}
    dagger_base, dagger_combat = dagger_poses()
    variants = {'espada': {state: {} for state in STATES}, 'leve': {state: {} for state in STATES}}
    for direction in DIRECTIONS:
        sword_base = v3.frame_image(data['clips']['idle']['directions'][direction][0], originals)
        for variant, base in [('espada', sword_base), ('leve', dagger_base[direction])]:
            variants[variant]['idle'][direction] = [mesh_frame(base, n * math.tau / 4, direction, 'idle') for n in range(4)]
            variants[variant]['walk'][direction] = [mesh_frame(base, n * math.tau / 12, direction) for n in range(12)]
        for state in STATES[2:]:
            variants['espada'][state][direction] = [v3.frame_image(spec, originals) for spec in data['clips'][state]['directions'][direction]]
        for state, frames in dagger_actions(dagger_base[direction], dagger_combat[direction], direction).items():
            variants['leve'][state][direction] = frames
    extras = {'slash_fx': [v3.frame_image(spec, originals) for spec in data['extras']['slash_fx']]}
    preview(variants, extras)
    frames, durations, tags = [], [], []
    known_sequences = {}
    manifests = {}
    state_lengths = {'idle': 1.5, 'walk': .66, 'attack_light': .29, 'attack_heavy': .5,
                     'dodge': .2, 'parry': .25, 'hurt': .22, 'death': .5, 'power': .28}
    for variant, prefix in [('espada', 'sword'), ('leve', 'daggers')]:
        clips = {}
        for state in STATES:
            directions = {}
            for direction in DIRECTIONS:
                images = variants[variant][state][direction]
                length = state_lengths[state]
                if variant == 'espada' and state not in ['idle', 'walk']:
                    definition = data['clips'][state]
                    scalar_duration = FPS / definition['fps']
                else:
                    scalar_duration = FPS * length / len(images)
                frame_durations = [scalar_duration] * len(images)
                identity = frames_hash(images, frame_durations)
                if identity in known_sequences:
                    indices = known_sequences[identity]
                else:
                    indices = list(range(len(frames), len(frames) + len(images)))
                    known_sequences[identity] = indices
                    frames.extend(images)
                    durations.extend(frame_durations)
                directions[direction] = indices
                tags.append({'name': f'{prefix}_{state}_{direction}', 'color': '927ac7ff' if variant == 'leve' else '6db0a4ff', 'from': indices[0] + 1, 'to': indices[-1] + 1})
            clips[state] = {'fps': len(images) / state_lengths[state], 'loop': state in ['idle', 'walk'], 'directions': directions}
            if state == 'walk':
                clips[state]['cycle_duration'] = .66
        manifests[variant] = {'clips': clips}
    extra_indices = {}
    for name, images in extras.items():
        indices = list(range(len(frames), len(frames) + len(images)))
        frames.extend(images)
        durations.extend([1.0] * len(images))
        extra_indices[name] = indices
        tags.append({'name': name, 'color': 'ba995dff', 'from': indices[0] + 1, 'to': indices[-1] + 1})
    columns = 16 if len(frames) <= 672 else 24
    rows = math.ceil(len(frames) / columns)
    assert max(columns * 384, rows * 384) <= 16384
    for variant in variants:
        for direction in DIRECTIONS:
            hashes = {hashlib.sha256(frame.tobytes()).digest() for frame in variants[variant]['walk'][direction]}
            assert len(hashes) == 12, f'Walk lacks distinct intermediate keys: {variant}/{direction}'
    native = v3.project_data(len(frames), durations, tags, True)
    native['layers'][0]['name'] = 'Senu v4 — Khopesh + Adagas / quadros de movimento'
    native['export_profile']['lines_count'] = str(columns)
    native['symmetry_points'] = [191.5, 191.5]
    PROJECT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(PROJECT, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(native, ensure_ascii=False))
        for index, image in enumerate(frames):
            assert alpha_bounds(image) is not None
            archive.writestr(f'image_data/frames/{index + 1}/layer_1', image.tobytes())
    source_hashes = {name: hashlib.sha256((SOURCES / name).read_bytes()).hexdigest()
                     for name in ['movement.png', 'combat.png', 'reactions.png', 'weapons.png',
                                  'daggers_directions_v4.png', 'daggers_combat_v4.png']}
    manifest = {'version': 4, 'canvas': list(CANVAS), 'pivot': list(PIVOT), 'game_scale': .26,
                'texture': 'res://assets/sprites/senu_v4.png', 'weapon_variants': manifests,
                'clips': manifests['espada']['clips'], 'frame_count': len(frames), 'frame_regions': [],
                'extras': extra_indices, 'source_hashes': source_hashes,
                'notes': ['Twelve keyed region-deformation walk drawings in every direction for both weapons; no frame dissolves.',
                          'New dagger direction/action art generated with ImageGen using the supplied Senu identity; originals preserved.',
                          'Dagger cardinal actions adapt the nearest diagonal source; northeast base mirrors northwest.',
                          'Sword action poses preserve the curated original drawings; finite-state playback is smoothed separately.',
                          'Pixelorama applies native layer cleanup and produces the actual delivery PNG/JSON.']}
    PLAN.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'project': str(PROJECT), 'plan': str(PLAN), 'frames': len(frames), 'tags': len(tags),
                      'columns': columns, 'rows': rows, 'texture_size': [columns * 384, rows * 384],
                      'walk_unique': '2 weapons × 8 directions × 12 distinct keys'}, ensure_ascii=False))


if __name__ == '__main__':
    build()
