"""Build editable v3 NPC projects from complete ImageGen pose sheets.

The supplied PNGs remain untouched. Only registration, one uniform downsample per
character, binary alpha and the existing interiors palette are applied. Runtime
uses native pixels (scale 1). Delivery PNG/JSON must be exported by Pixelorama.

Usage: python -B tools/pixelorama/build_npcs_v3.py [--only NAME ...] [--force]
Optional sources/registrations.json accepts per-character grid, rects (x,y,w,h),
source_pivots and scale. Explicit registrations are useful for irregular sheets;
no frame receives an independent scale and disconnected accessories are retained.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
from datetime import datetime
from pathlib import Path
from statistics import median
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/pixelorama/npcs_v3'
SOURCES = OUT / 'sources'
QA = ROOT / 'qa/npcs_v3'
LOOKS = ['estivador', 'carregador', 'peixeira', 'mercador', 'marinheiro',
         'remador', 'escriba', 'peregrina', 'velho', 'aguadeira', 'padeira', 'caravaneiro']
POSES = ['idle', 'walk_1', 'walk_2', 'walk_3', 'walk_4', 'talk', 'carry_idle',
         'carry_1', 'carry_2', 'carry_3', 'carry_4', 'bend', 'breathe', 'blink',
         'carry_breathe', 'carry_blink']
ANKHET_POSES = ['rest', 'breathe', 'blink', 'gesture']
CELL = (64, 64)
PIVOT = (32, 58)
ANKHET_CELL = (128, 144)
ANKHET_PIVOT = (64, 112)
SEQUENCE = [0]*12 + [1]*6 + [0]*12 + [2] + [0]*6 + [3]*4 + [0]*7


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')


def palette():
    data = json.loads((ROOT / 'assets/world/interiors_v4_manifest.json').read_text(encoding='utf-8'))
    return [tuple(bytes.fromhex(color.lstrip('#')[:6])) for color in data['palette']]


def quantize(image, colors):
    """Map only visible pixels to the world palette, without error diffusion."""
    rgb = Image.new('P', (1, 1))
    entries = list(colors) + [colors[0]]*(256-len(colors))
    rgb.putpalette([channel for color in entries for channel in color])
    result = image.convert('RGB').quantize(palette=rgb, dither=Image.Dither.NONE).convert('RGBA')
    result.putalpha(image.getchannel('A').point(lambda a: 255 if a >= 128 else 0))
    # Clear hidden RGB too, so round trips and asset hashes remain deterministic.
    clean = Image.new('RGBA', image.size)
    clean.paste(result, (0, 0), result.getchannel('A'))
    return clean


def transparent_cut(projection, expected, radius):
    """Choose a real transparent gutter near a regular-grid division."""
    start, end = max(1, round(expected-radius)), min(len(projection)-1, round(expected+radius))
    candidates = [index for index in range(start, end) if projection[index] == 0]
    if not candidates:
        raise ValueError(f'No transparent gutter near {expected}; provide explicit source rects')
    nearest = min(candidates, key=lambda index: abs(index-expected))
    left = right = nearest
    while left > start and projection[left-1] == 0:
        left -= 1
    while right+1 < end and projection[right+1] == 0:
        right += 1
    return (left+right)//2


def crop_cells(image, count, settings):
    columns, rows = settings.get('grid', [4, 4] if count == 16 else [4, 1])
    if columns*rows != count:
        raise ValueError(f'Grid {columns}x{rows} does not contain {count} poses')
    rectangles = settings.get('rects')
    if rectangles is None:
        # Complete authored gestures may extend beyond the mathematical quarter.
        # Segment at actual transparent gutters, independently in each row; this
        # keeps detached props and avoids a clipped hand/partial next character.
        alpha = image.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        row_projection = alpha.getprojection()[1]
        ys = [0] + [transparent_cut(row_projection, index*image.height/rows,
                                   image.height/rows*.3) for index in range(1, rows)] + [image.height]
        rectangles = []
        for row in range(rows):
            projection = alpha.crop((0, ys[row], image.width, ys[row+1])).getprojection()[0]
            xs = [0] + [transparent_cut(projection, index*image.width/columns,
                                       image.width/columns*.3) for index in range(1, columns)] + [image.width]
            for column in range(columns):
                rectangles.append([xs[column], ys[row], xs[column+1]-xs[column], ys[row+1]-ys[row]])
    if len(rectangles) != count:
        raise ValueError('Each pose needs exactly one source rectangle')
    result = []
    for index, (x, y, width, height) in enumerate(rectangles):
        if width <= 0 or height <= 0 or x < 0 or y < 0 or x+width > image.width or y+height > image.height:
            raise ValueError(f'Invalid source rectangle {index}: {rectangles[index]}')
        cel = image.crop((x, y, x+width, y+height))
        binary = cel.getchannel('A').point(lambda a: 255 if a >= 128 else 0)
        cel.putalpha(binary)
        bbox = binary.getbbox()
        if bbox is None:
            raise ValueError(f'Empty source pose {index}; check grid and alpha')
        if bbox[0] == 0 or bbox[1] == 0 or bbox[2] == width or bbox[3] == height:
            raise ValueError(f'Pose {index} touches its source cell border; set explicit rects')
        result.append((cel, bbox, [x, y, width, height]))
    return result


def foot_pivot(cel, bbox):
    """Bottom footprint center, unaffected by a raised hand or an overhead load."""
    left, top, right, bottom = bbox
    alpha = cel.getchannel('A')
    band = max(1, round((bottom-top)*0.055))
    foot = alpha.crop((left, bottom-band, right, bottom)).getbbox()
    return ((left+(foot[0]+foot[2])/2) if foot else (left+right)/2, bottom)


def fixed_lower_pixels(frames, pivot, names):
    """Keep the lower legs/hem planted in rest, preventing ankle seams.

    This is a direct reuse of the authored idle lower region, never a warp. The
    upper body, face and load retain each complete source pose.
    """
    boundary = pivot[1]-18
    pairs = [(0, 12), (0, 13), (6, 14), (6, 15)] if len(frames) == 16 else [(0, 1), (0, 2), (0, 3)]
    registrations = []
    for source, destination in pairs:
        region = frames[source].crop((0, boundary, frames[source].width, frames[source].height))
        frames[destination].paste(region, (0, boundary))
        registrations.append({'pose': names[destination], 'from': names[source], 'rows': [boundary, frames[source].height]})
    return registrations


def register(name, colors, settings):
    path = SOURCES / f'{name}.png'
    image = Image.open(path).convert('RGBA')
    if image.getchannel('A').getextrema()[0] >= 128:
        raise ValueError(f'{name}: source has no true transparent background')
    names = POSES if name != 'ankhet' else ANKHET_POSES
    cell, pivot = (CELL, PIVOT) if name != 'ankhet' else (ANKHET_CELL, ANKHET_PIVOT)
    cels = crop_cells(image, len(names), settings)
    body_height = cels[0][1][3]-cels[0][1][1]
    max_width = max(bounds[2]-bounds[0] for _, bounds, _ in cels)
    max_height = max(bounds[3]-bounds[1] for _, bounds, _ in cels)
    # 44 px matches named NPCs; carrying objects may reach 50 px.
    # Larger transparent cels accommodate gestures without scaling runtime art.
    scale = min(44/body_height, (62 if name != 'ankhet' else 48)/max_width,
                50/max_height)
    scale = float(settings.get('scale', scale))
    if scale <= 0:
        raise ValueError(f'{name}: scale must be positive')
    frames, registrations = [], []
    for index, (cel, bounds, rectangle) in enumerate(cels):
        explicit = settings.get('source_pivots')
        source_pivot = explicit[index] if explicit else foot_pivot(cel, bounds)
        # Affine sampling uses the exact same scalar for every cel, irrespective
        # of crop size. The final placement is a whole-pixel translation.
        offset = (round(pivot[0]-source_pivot[0]*scale), round(pivot[1]-source_pivot[1]*scale))
        transform = (1/scale, 0, -offset[0]/scale, 0, 1/scale, -offset[1]/scale)
        frame = cel.transform(cell, Image.Transform.AFFINE, transform, resample=Image.Resampling.NEAREST)
        frame = quantize(frame, colors)
        actual = frame.getchannel('A').getbbox()
        if actual is None:
            raise ValueError(f'{name}/{names[index]} is empty after registration')
        projected = (bounds[0]*scale+offset[0], bounds[1]*scale+offset[1],
                     bounds[2]*scale+offset[0], bounds[3]*scale+offset[1])
        if projected[0] < -0.5 or projected[1] < -0.5 or projected[2] > cell[0]+0.5 or projected[3] > cell[1]+0.5:
            raise ValueError(f'{name}/{names[index]} would be clipped: {projected}; adjust scale/pivots')
        frames.append(frame)
        registrations.append({'pose': names[index], 'source_rect': rectangle,
                              'source_bounds': list(bounds), 'source_pivot': list(source_pivot),
                              'scale': scale, 'translation': list(offset), 'bounds': list(actual)})
    soles = fixed_lower_pixels(frames, pivot, names)
    record = {'source': str(path.relative_to(ROOT)).replace('\\', '/'),
              'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'source_size': list(image.size),
              'uniform_scale': scale, 'idle_body_height': body_height,
              'target_idle_height': round(body_height*scale), 'registrations': registrations,
              'planted_lower_pixels': soles}
    return frames, record


def pxo(path, frames, cell, tags, columns, label):
    data = {'pixelorama_version': 'v1.2.3-stable', 'pxo_version': 7,
            'size_x': cell[0], 'size_y': cell[1], 'color_mode': 5,
            'layers': [{'name': label, 'type': 0, 'new_cels_linked': False,
                        'visible': True, 'locked': False, 'blend_mode': 0,
                        'opacity': 1.0, 'parent': -1, 'effects': []}],
            'frames': [{'cels': [{'opacity': 1.0, 'z_index': 0}], 'duration': 1.0} for _ in frames],
            'tags': tags, 'fps': 8.0, 'current_frame': 0, 'current_layer': 0,
            'export_profile': {'orientation': '1', 'lines_count': str(columns), 'current_tab': '1',
                               'crop_mode': '0', 'resize': '100', 'interpolation': '0'}}
    buffer = io.BytesIO()
    frames[0].save(buffer, format='PNG')
    with ZipFile(path, 'w', ZIP_DEFLATED) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(data, ensure_ascii=False))
        archive.writestr('preview.png', buffer.getvalue())
        for index, frame in enumerate(frames):
            archive.writestr(f'image_data/frames/{index+1}/layer_1', frame.tobytes())
    with ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise RuntimeError(f'Corrupt native project: {path}')


def preview(all_frames, ankhet):
    QA.mkdir(parents=True, exist_ok=True)
    board = Image.new('RGBA', (len(POSES)*CELL[0], len(LOOKS)*CELL[1]), '#20383d')
    for row, name in enumerate(LOOKS):
        for index, frame in enumerate(all_frames[name]):
            board.alpha_composite(frame, (index*CELL[0], row*CELL[1]))
    board.resize((board.width*3, board.height*3), Image.Resampling.NEAREST).convert('RGB').save(QA/'residents_poses.png')
    idle_board = Image.new('RGBA', (7*64, 2*72), '#20383d')
    characters = [(name, frames, PIVOT) for name, frames in all_frames.items()] + [('ankhet', ankhet, ANKHET_PIVOT)]
    animation = []
    for phase in range(48):
        scene = idle_board.copy()
        for index, (name, frames, pivot) in enumerate(characters):
            sequence = SEQUENCE if name == 'ankhet' else ([0]*12+[12]*6+[0]*12+[13]+[0]*6+[5]*4+[0]*7)
            frame = frames[sequence[(phase+index*3)%len(sequence)]]
            x, y = (index%7)*64+32-pivot[0], (index//7)*72+62-pivot[1]
            scene.alpha_composite(frame, (x, y))
        animation.append(scene.resize((scene.width*3, scene.height*3), Image.Resampling.NEAREST).convert('RGB'))
    animation[0].save(QA/'residents_idle.png')
    animation[0].save(QA/'residents_idle.gif', save_all=True, append_images=animation[1:], duration=125, loop=0, disposal=2)
    old_sheet = Image.open(ROOT/'assets/world/townsfolk_v2.png').convert('RGBA')
    compare = Image.new('RGBA', (100+4*128, 28+12*80), '#20383d')
    draw = ImageDraw.Draw(compare)
    for column, pose in enumerate([0, 2, 5, 6]):
        draw.text((100+column*128, 5), POSES[pose]+'   v2 / v3', fill='#eee0ba')
    for row, name in enumerate(LOOKS):
        ground = 28+row*80+62
        draw.text((4, ground-30), name, fill='#eee0ba')
        for column, pose in enumerate([0, 2, 5, 6]):
            origin = 100+column*128
            draw.line((origin, ground, origin+127, ground), fill='#526765')
            old = old_sheet.crop((pose*32, row*52, (pose+1)*32, (row+1)*52))
            compare.alpha_composite(old, (origin+32-16, ground-49))
            compare.alpha_composite(all_frames[name][pose], (origin+96-PIVOT[0], ground-PIVOT[1]))
    compare.resize((compare.width*3, compare.height*3), Image.Resampling.NEAREST).convert('RGB').save(QA/'old_vs_new.png')



def update_character(name):
    """Replace only the authorized remador cels; preserve every other ZIP entry."""
    if name != 'remador':
        raise ValueError('This limited update only supports remador')
    native_path = OUT/'townsfolk_v3.pxo'
    plan_path = OUT/'townsfolk_v3_export_plan.json'
    before_native = native_path.read_bytes()
    ankhet_before = (OUT/'ankhet_v3.pxo').read_bytes()
    before_plan = plan_path.read_bytes()
    digest = lambda value: hashlib.sha256(value).hexdigest()
    plan = json.loads(before_plan)
    if plan.get('looks') != LOOKS or plan.get('canvas') != list(CELL) or plan.get('pivot') != list(PIVOT):
        raise ValueError('Unexpected existing atlas contract; refusing limited update')
    indices = plan['sprites'][name]['frames']
    expected = list(range(LOOKS.index(name)*16, (LOOKS.index(name)+1)*16))
    if indices != expected:
        raise ValueError('Unexpected remador frame mapping; refusing limited update')
    with ZipFile(io.BytesIO(before_native)) as archive:
        infos = archive.infolist()
        original = {item.filename: archive.read(item.filename) for item in infos}
    native = json.loads(original['data.json'])
    if len(native.get('layers', [])) != 1 or native['layers'][0].get('type') != 0:
        raise ValueError('Existing project has unexpected layers; all manual layers must be preserved')
    if len(native.get('frames', [])) != 192 or any(len(frame.get('cels', [])) != 1 for frame in native['frames']):
        raise ValueError('Existing project has unexpected cels; refusing limited update')
    settings_path = SOURCES/'registrations.json'
    settings = json.loads(settings_path.read_text(encoding='utf-8')) if settings_path.exists() else {}
    frames, record = register(name, palette(), settings.get(name, {}))
    replacement = {f'image_data/frames/{index+1}/layer_1': frame.tobytes() for index, frame in zip(indices, frames)}
    if any(key not in original for key in replacement):
        raise ValueError('Authorized cel entries are absent from existing project')
    # Snapshot exact original native+plan bytes before any mutation, retaining
    # edits in all other appearances as well as the previous remador.
    snapshot = QA/'updates'/('remador_'+datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    snapshot.mkdir(parents=True, exist_ok=False)
    (snapshot/native_path.name).write_bytes(before_native)
    (snapshot/plan_path.name).write_bytes(before_plan)
    if digest((snapshot/native_path.name).read_bytes()) != digest(before_native) or digest((snapshot/plan_path.name).read_bytes()) != digest(before_plan):
        raise RuntimeError('Backup verification failed; existing project untouched')
    temp_native = OUT/'townsfolk_v3.update.pxo'
    temp_plan = OUT/'townsfolk_v3.update.json'
    if temp_native.exists() or temp_plan.exists():
        raise FileExistsError('Previous update temporary files exist; inspect them before retrying')
    with ZipFile(temp_native, 'w') as archive:
        for item in infos:
            # Preserve native metadata/layer settings/tags and all unselected raw
            # cels exactly. ZipInfo also retains their compression/attributes.
            archive.writestr(item, replacement.get(item.filename, original[item.filename]))
    with ZipFile(temp_native) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('Updated project failed ZIP validation; original untouched')
        changed = {}
        untouched = {}
        for key, value in original.items():
            actual = archive.read(key)
            if key in replacement:
                if actual != replacement[key]:
                    raise RuntimeError(f'Updated cel differs: {key}')
                changed[key] = {'before': digest(value), 'after': digest(actual)}
            else:
                if actual != value:
                    raise RuntimeError(f'Unselected project entry changed: {key}')
                untouched[key] = digest(actual)
        all_frames = {look: [Image.frombytes('RGBA', CELL, archive.read(f'image_data/frames/{index+1}/layer_1'))
                             for index in plan['sprites'][look]['frames']] for look in LOOKS}
    untouched_cels = {key: value for key, value in untouched.items() if key.startswith('image_data/frames/')}
    if len(untouched_cels) != 176:
        raise RuntimeError('Expected exactly 176 untouched resident cels; original untouched')
    plan['registrations'][name] = record
    plan['source_hashes'][name] = record['sha256']
    write_json(temp_plan, plan)
    # Concurrent edits after the snapshot stop the operation rather than losing
    # anyone's work. The verified temporary files and backup remain reviewable.
    if native_path.read_bytes() != before_native or plan_path.read_bytes() != before_plan:
        raise RuntimeError('Native project or plan changed concurrently; update not applied')
    temp_native.replace(native_path)
    temp_plan.replace(plan_path)
    if (OUT/'ankhet_v3.pxo').read_bytes() != ankhet_before:
        raise RuntimeError('Ankhet changed concurrently; inspect before export')
    report = {'character': name, 'snapshot': str(snapshot.relative_to(ROOT)),
              'before_native_sha256': digest(before_native), 'after_native_sha256': digest(native_path.read_bytes()),
              'changed_cels': changed, 'untouched_entries_sha256': untouched,
              'source_sha256': record['sha256'], 'untouched_cels': len(untouched_cels),
              'ankhet_project_sha256': digest(ankhet_before), 'ankhet_project_written': False}
    write_json(snapshot/'verification.json', report)
    probe = Image.new('RGBA', (16*CELL[0], CELL[1]), '#20383d')
    for index, frame in enumerate(frames):
        probe.alpha_composite(frame, (index*CELL[0], 0))
    probe.resize((probe.width*4, probe.height*4), Image.Resampling.NEAREST).convert('RGB').save(QA/'remador_probe.png')
    # Refresh QA from the preserved native cels, never by regenerating others.
    with ZipFile(OUT/'ankhet_v3.pxo') as archive:
        ankhet = [Image.frombytes('RGBA', ANKHET_CELL, archive.read(f'image_data/frames/{index+1}/layer_1')) for index in range(4)]
    preview(all_frames, ankhet)
    print(json.dumps({'updated': name, 'cels': len(changed), 'untouched_entries': len(untouched),
                      'snapshot': str(snapshot), 'native': str(native_path)}, ensure_ascii=False))


def build(args):
    OUT.mkdir(parents=True, exist_ok=True)
    settings_path = SOURCES/'registrations.json'
    settings = json.loads(settings_path.read_text(encoding='utf-8')) if settings_path.exists() else {}
    colors = palette()
    requested = args.only or LOOKS+['ankhet']
    unknown = set(requested)-set(LOOKS+['ankhet'])
    if unknown:
        raise ValueError(f'Unknown characters: {sorted(unknown)}')
    missing = [str(SOURCES/f'{name}.png') for name in requested if not (SOURCES/f'{name}.png').is_file()]
    if missing:
        raise FileNotFoundError('Missing source sheets:\n'+'\n'.join(missing))
    # Partial invocations produce QA probes, never incomplete production atlases.
    all_frames, records = {}, {}
    for name in requested:
        frames, record = register(name, colors, settings.get(name, {}))
        all_frames[name], records[name] = frames, record
        probe = Image.new('RGBA', (len(frames)*frames[0].width, frames[0].height), '#20383d')
        for index, frame in enumerate(frames):
            probe.alpha_composite(frame, (index*frame.width, 0))
        QA.mkdir(parents=True, exist_ok=True)
        probe.resize((probe.width*4, probe.height*4), Image.Resampling.NEAREST).convert('RGB').save(QA/f'{name}_probe.png')
    if set(requested) != set(LOOKS+['ankhet']):
        write_json(QA/'registration_probe.json', records)
        print(json.dumps({'probes': requested, 'output': str(QA)}, ensure_ascii=False))
        return
    outputs = [OUT/'townsfolk_v3.pxo', OUT/'ankhet_v3.pxo']
    if not args.force and any(path.exists() for path in outputs):
        raise FileExistsError('v3 native projects already exist. Export preserves manual edits; --force explicitly rebuilds v3 only.')
    common = {'version': 3, 'pixel_art': True, 'runtime_scale': 1,
              'palette': [''.join(f'{part:02x}' for part in color) for color in colors],
              'provenance': 'ImageGen complete authored poses; registered at one uniform scale per character; Pixelorama exports delivery.',
              'source_hashes': {name: record['sha256'] for name, record in records.items()}}
    frames = [frame for name in LOOKS for frame in all_frames[name]]
    sprites = {name: {'frames': list(range(row*16, (row+1)*16)), 'authored_poses': POSES} for row, name in enumerate(LOOKS)}
    plan = dict(common, canvas=list(CELL), cell=list(CELL), pivot=list(PIVOT), columns=16,
                frames=len(frames), looks=LOOKS, poses=POSES, sprites=sprites,
                texture='res://assets/world/townsfolk_v3.png', source='res://art/pixelorama/npcs_v3/townsfolk_v3.pxo',
                registrations={name: records[name] for name in LOOKS})
    tags = [{'name': name, 'color': '609087ff', 'from': row*16+1, 'to': (row+1)*16} for row, name in enumerate(LOOKS)]
    pxo(outputs[0], frames, CELL, tags, 16, 'Moradores v3 · poses completas')
    write_json(OUT/'townsfolk_v3_export_plan.json', plan)
    ankhet = all_frames['ankhet']
    ankhet_plan = dict(common, canvas=list(ANKHET_CELL), pivot=list(ANKHET_PIVOT), columns=4,
                       frames=4, texture='res://assets/world/ankhet_v3.png', source='res://art/pixelorama/npcs_v3/ankhet_v3.pxo',
                       sprites={'ankhet': {'frames': [0,1,2,3], 'authored_poses': ANKHET_POSES, 'fps': 8, 'sequence': SEQUENCE}},
                       registrations={'ankhet': records['ankhet']})
    pxo(outputs[1], ankhet, ANKHET_CELL, [{'name': 'ankhet', 'color': '609087ff', 'from': 1, 'to': 4}], 4, 'Ankhet v3 · poses completas')
    write_json(OUT/'ankhet_v3_export_plan.json', ankhet_plan)
    preview({name: all_frames[name] for name in LOOKS}, ankhet)
    print(json.dumps({'native': [str(path) for path in outputs], 'frames': 196, 'looks': 13, 'qa': str(QA)}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument('--only', nargs='+', help='Prepare registration probes for selected source sheets')
    selection.add_argument('--update', choices=['remador'], help='Replace only remador cels after snapshot; preserve every other native entry')
    parser.add_argument('--force', action='store_true', help='Explicitly rebuild v3 projects; preserves v1/v2/v4 files')
    arguments = parser.parse_args()
    if arguments.update:
        if arguments.force:
            parser.error('--update cannot be combined with --force')
        update_character(arguments.update)
    else:
        build(arguments)
