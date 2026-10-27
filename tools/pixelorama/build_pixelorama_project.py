"""Prepare native Pixelorama v1.2.3 projects from the supplied sprite sheets.

PNG delivery is produced by Pixelorama itself, never by this preparation script.
The originals remain unchanged. ColorReplace layers are processed by Pixelorama.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED

from PIL import Image, ImageDraw, ImageFilter, ImageChops

ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / 'art/pixelorama/senu/sources'
PROJECT = ROOT / 'art/pixelorama/senu/senu_v3.pxo'
MANIFEST = ROOT / 'assets/sprites/senu_v3_manifest.json'
SOURCES = {
    'movement': Path('C:/Users/KAU~1/AppData/Local/Temp/codex-clipboard-f1382a54-2fac-4dfd-9fa1-a3aa5cea5a77.png'),
    'combat': Path('C:/Users/KAU~1/AppData/Local/Temp/codex-clipboard-b7a5c5a0-0ca1-4ec2-8f56-fe6a1847571d.png'),
    'reactions': Path('C:/Users/KAU~1/AppData/Local/Temp/codex-clipboard-270c6315-7642-4be2-b955-c144a7e9cd8b.png'),
    'weapons': Path('C:/Users/KAU~1/AppData/Local/Temp/codex-clipboard-ad62e2d9-877b-4193-a55d-c3a68bc33227.png'),
}
CANVAS = (384, 384)
PIVOT = (192, 280)
GAME_SCALE = .26


def effects():
    result = [{'name': 'Limpar fundo preto quase transparente',
               'shader_path': 'res://src/Shaders/ColorReplace.gdshader', 'enabled': True,
               'params': {'old_color': 'Color(0, 0, 0, 0.015)', 'new_color': 'Color(0, 0, 0, 0)',
                          'tolerance': '0.03', 'has_pattern': 'false', 'size': f'Vector2({CANVAS[0]}, {CANVAS[1]})'},
               'animated_params': '{}'}]
    for label, rgb in [('vermelho', (1, 0, 0)), ('verde', (0, 1, 0)), ('amarelo', (1, 1, 0))]:
        for alpha in [.2, .5, .85]:
            result.append({
                'name': f'Limpar halo {label} {alpha}',
                'shader_path': 'res://src/Shaders/ColorReplace.gdshader',
                'enabled': True,
                'params': {
                    'old_color': f'Color({rgb[0]}, {rgb[1]}, {rgb[2]}, {alpha})',
                    'new_color': 'Color(0, 0, 0, 0)',
                    'tolerance': '0.18', 'has_pattern': 'false',
                    'size': f'Vector2({CANVAS[0]}, {CANVAS[1]})',
                },
                'animated_params': '{}',
            })
    return result


def copy_sources():
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    result = {}
    for key, original in SOURCES.items():
        destination = SOURCE_DIR / (key + '.png')
        if not destination.exists():
            shutil.copyfile(original, destination)
        original_hash = hashlib.sha256(original.read_bytes()).hexdigest() if original.exists() else None
        saved_hash = hashlib.sha256(destination.read_bytes()).hexdigest()
        if original_hash is not None and original_hash != saved_hash:
            raise RuntimeError(f'The preserved source differs: {key}')
        result[key] = saved_hash
    return result


def frame_image(spec, images):
    x, y, w, h = spec['rect']
    source = images[spec['source']]
    if not (0 <= x < x + w <= source.width and 0 <= y < y + h <= source.height):
        raise RuntimeError(f'Invalid source region: {spec}')
    region = source.crop((x, y, x + w, y + h))
    if spec.get('erase_rects'):
        # Explicit extraction selection for connected residue in irregular sheets.
        # Coordinates refer to the unscaled, unmirrored source crop.
        alpha = region.getchannel('A')
        eraser = ImageDraw.Draw(alpha)
        for ex, ey, ew, eh in spec['erase_rects']:
            if not (0 <= ex < ex + ew <= w and 0 <= ey < ey + eh <= h):
                raise RuntimeError(f'Invalid exclusion rectangle: {spec}')
            eraser.rectangle((ex, ey, ex + ew - 1, ey + eh - 1), fill=0)
        region.putalpha(alpha)
    if spec.get('isolate_body', False):
        # Selection preparation: retain the principal connected drawing and its
        # one-pixel antialias boundary. Original source PNGs remain untouched.
        # Saturated key-color fringe is excluded only from connectivity here;
        # the native Pixelorama ColorReplace effects perform color cleanup.
        pixels = list(region.get_flattened_data() if hasattr(region, 'get_flattened_data') else region.getdata())
        active = bytearray(w * h)
        for i, (r, g, b, a) in enumerate(pixels):
            chroma = (r > 180 and g < 85 and b < 85) or (g > 180 and r < 85 and b < 85) or (r > 180 and g > 180 and b < 85)
            active[i] = a >= 16 and not chroma
        components = []
        for start in range(w * h):
            if not active[start]:
                continue
            active[start] = 0
            pending = [start]
            component = []
            while pending:
                current = pending.pop()
                component.append(current)
                cx, cy = current % w, current // w
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h:
                            adjacent = ny * w + nx
                            if active[adjacent]:
                                active[adjacent] = 0
                                pending.append(adjacent)
            components.append(component)
        if not components:
            raise RuntimeError(f'Empty character selection: {spec}')
        largest = max(components, key=len)
        selection = bytearray(w * h)
        for pixel in largest:
            selection[pixel] = 255
        mask = Image.frombytes('L', (w, h), bytes(selection)).filter(ImageFilter.MaxFilter(3))
        region.putalpha(ImageChops.multiply(region.getchannel('A'), mask))
    factor = float(spec['scale']) / GAME_SCALE
    size = (max(1, round(w * factor)), max(1, round(h * factor)))
    region = region.resize(size, Image.Resampling.NEAREST)
    px, py = spec['pivot'][0] * factor, spec['pivot'][1] * factor
    if spec.get('flip_h', False):
        region = region.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        px = size[0] - 1 - px
    offset = (round(PIVOT[0] - px), round(PIVOT[1] - py))
    bounds = region.getchannel('A').point(lambda alpha: 255 if alpha >= 16 else 0).getbbox()
    if bounds is not None:
        placed = (bounds[0] + offset[0], bounds[1] + offset[1], bounds[2] + offset[0], bounds[3] + offset[1])
        if min(placed[0], placed[1]) < 0 or placed[2] > CANVAS[0] or placed[3] > CANVAS[1]:
            raise RuntimeError(f'Output canvas would cut a source frame: {placed} / {spec}')
    canvas = Image.new('RGBA', CANVAS, (0, 0, 0, 0))
    # Direct paste preserves source RGBA, avoiding an extra alpha multiplication.
    canvas.paste(region, offset)
    return canvas


def project_data(count, durations, tags, with_effects):
    return {
        'pixelorama_version': 'v1.2.3-stable', 'pxo_version': 7,
        'size_x': CANVAS[0], 'size_y': CANVAS[1], 'color_mode': 5,
        'layers': [{'name': 'Senu - sprites fornecidos', 'type': 0, 'new_cels_linked': False,
                    'visible': True, 'locked': False, 'blend_mode': 0, 'opacity': 1.0,
                    'parent': -1, 'effects': effects() if with_effects else []}],
        'frames': [{'cels': [{'opacity': 1.0, 'z_index': 0}], 'duration': durations[i]} for i in range(count)],
        'tags': tags, 'fps': 12.0, 'current_frame': 0, 'current_layer': 0,
        'export_profile': {'orientation': '1', 'lines_count': '8', 'current_tab': '1',
                           'crop_mode': '0', 'resize': '100', 'interpolation': '0'},
    }


def write_project(path, specs, durations, tags, images, with_effects=True, diagnostic=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr('mimetype', 'application/x-pixelorama')
        archive.writestr('data.json', json.dumps(project_data(len(specs), durations, tags, with_effects), ensure_ascii=False))
        for index, spec in enumerate(specs):
            canvas = frame_image(spec, images)
            if diagnostic:
                draw = ImageDraw.Draw(canvas)
                for n, color in enumerate([(255, 0, 0, 255), (0, 255, 0, 255), (255, 255, 0, 255), (50, 110, 105, 255), (174, 127, 69, 255)]):
                    draw.rectangle((8 + n * 24, 340, 23 + n * 24, 355), fill=color)
            archive.writestr(f'image_data/frames/{index + 1}/layer_1', canvas.tobytes())
    with ZipFile(path) as archive:
        assert archive.testzip() is None
        assert len(archive.read('image_data/frames/1/layer_1')) == CANVAS[0] * CANVAS[1] * 4


def build(probe=False):
    source_hashes = copy_sources()
    data = json.loads((ROOT / 'tools/pixelorama/source_frames.json').read_text(encoding='utf-8'))
    images = {key: Image.open(SOURCE_DIR / (key + '.png')).convert('RGBA') for key in SOURCES}
    if probe:
        spec = data['clips']['idle']['directions']['up'][0]
        path = ROOT / 'qa/pixelorama_probe.pxo'
        write_project(path, [spec], [1.0], [{'name': 'probe', 'color': '6db0a4ff', 'from': 1, 'to': 1}], images, diagnostic=True)
        print(json.dumps({'probe': str(path)}, ensure_ascii=False))
        return
    specs, durations, tags = [], [], []
    clips, extras, sequences = {}, {}, {}
    for name, definition in data['clips'].items():
        directions = {}
        for direction in data['directions_order']:
            frames = definition['directions'][direction]
            identity = json.dumps([frames, definition['fps'] if len(frames) > 1 else 0], sort_keys=True)
            if identity in sequences:
                indices = sequences[identity]
            else:
                indices = list(range(len(specs), len(specs) + len(frames)))
                sequences[identity] = indices
                specs.extend(frames)
                durations.extend([12.0 / definition['fps']] * len(frames))
            directions[direction] = indices
            tags.append({'name': name + '_' + direction, 'color': '6db0a4ff', 'from': indices[0] + 1, 'to': indices[-1] + 1})
        clips[name] = {'fps': definition['fps'], 'loop': definition['loop'], 'directions': directions}
    for name, frames in data.get('extras', {}).items():
        indices = list(range(len(specs), len(specs) + len(frames)))
        specs.extend(frames)
        durations.extend([1.0] * len(frames))
        extras[name] = indices
        tags.append({'name': name, 'color': 'ba995dff', 'from': indices[0] + 1, 'to': indices[-1] + 1})
    write_project(PROJECT, specs, durations, tags, images)
    manifest = {
        'version': 3, 'canvas': list(CANVAS), 'pivot': list(PIVOT), 'game_scale': GAME_SCALE,
        'texture': 'res://assets/sprites/senu_v3.png', 'clips': clips, 'extras': extras,
        'source_hashes': source_hashes, 'frame_count': len(specs),
        'frame_regions': [], 'provenance': 'Native Pixelorama 1.2.3 project; delivery texture must be exported by Pixelorama.',
        'notes': data['notes'],
    }
    # The runtime manifest is published only after a real Pixelorama export.
    (ROOT / 'art/pixelorama/senu/export_plan.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({'project': str(PROJECT), 'frames': len(specs), 'tags': len(tags), 'canvas': CANVAS}, ensure_ascii=False))


def finalize():
    native = json.loads((ROOT / 'assets/sprites/senu_v3.json').read_text(encoding='utf-8'))
    manifest = json.loads((ROOT / 'art/pixelorama/senu/export_plan.json').read_text(encoding='utf-8'))
    frames = native['frames']
    frames = list(frames.values()) if isinstance(frames, dict) else frames
    with Image.open(ROOT / 'assets/sprites/senu_v3.png') as texture:
        assert texture.mode == 'RGBA'
        columns = texture.width // CANVAS[0]
        rows = texture.height // CANVAS[1]
        orientation = int(native['export_profile']['orientation'])
        for index, item in enumerate(frames):
            # Pixelorama JSON is its native project serialization, not Aseprite JSON.
            if orientation == 1:
                x, y = (index % columns) * CANVAS[0], (index // columns) * CANVAS[1]
            else:
                x, y = (index // rows) * CANVAS[0], (index % rows) * CANVAS[1]
            manifest['frame_regions'].append([x, y, CANVAS[0], CANVAS[1]])
        assert len(manifest['frame_regions']) == manifest['frame_count'], (len(frames), manifest['frame_count'])
        for x, y, w, h in manifest['frame_regions']:
            assert w == CANVAS[0] and h == CANVAS[1]
            assert 0 <= x < x + w <= texture.width and 0 <= y < y + h <= texture.height
            assert texture.crop((x, y, x + w, y + h)).getchannel('A').getbbox() is not None
        manifest['texture_size'] = list(texture.size)
    manifest['exported_by'] = 'Pixelorama v1.2.3-stable (official CLI)'
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    # Preserve the complete metadata serialized by the installed Pixelorama itself.
    with ZipFile(PROJECT) as archive:
        preserved = {name: archive.read(name) for name in archive.namelist() if name != 'data.json'}
    with ZipFile(PROJECT, 'w', ZIP_DEFLATED, compresslevel=6) as archive:
        archive.writestr('data.json', json.dumps(native, ensure_ascii=False))
        for name, contents in preserved.items():
            archive.writestr(name, contents)
    print(json.dumps({'runtime_manifest': str(MANIFEST), 'frames': len(frames), 'texture_size': manifest['texture_size']}, ensure_ascii=False))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--probe', action='store_true')
    parser.add_argument('--finalize', action='store_true')
    args = parser.parse_args()
    finalize() if args.finalize else build(args.probe)
