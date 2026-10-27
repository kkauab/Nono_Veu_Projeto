"""Add hand-placed blink pixels and six separate ribbon cels to the native portrait.

No face rescaling, warping, new facial design, or whole-image bob is used.
Pixelorama exports the final execution PNG from the editable project.
"""
import json
from pathlib import Path
from zipfile import ZipFile
from PIL import Image, ImageDraw, ImageChops
from build_port_pixel_v7 import native_project, tag

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/menu_v8'

def blink(image, closed):
    result = image.copy()
    if not closed:
        return result
    d = ImageDraw.Draw(result)
    skin = image.getpixel((55, 62))
    shadow = image.getpixel((63, 61))
    ink = image.getpixel((62, 56))
    # Only the eye sockets change, preserving eyebrows and all other face pixels.
    d.polygon([(60,56),(64,55),(68,55),(71,57),(68,60),(64,61),(60,59)], fill=skin)
    d.polygon([(50,59),(53,59),(54,61),(51,63),(49,62)], fill=skin)
    if closed == 1:
        d.line([(61,57),(64,57),(67,57),(69,56)], fill=ink)
        d.line([(64,58),(67,58),(68,57)], fill=shadow)
        d.point((66,58), fill=image.getpixel((66,58)))
        d.line([(50,60),(52,60)], fill=ink)
    else:
        d.line([(61,57),(64,59),(67,58),(70,56)], fill=shadow)
        d.line([(62,58),(65,59),(68,57)], fill=ink)
        d.line([(50,60),(52,61),(53,60)], fill=ink)
    return result

def build():
    ART.mkdir(parents=True, exist_ok=True)
    source = ROOT / 'art/pixelorama/port_v7/senu_portrait_v7.pxo'
    with ZipFile(source) as archive:
        data = json.loads(archive.read('data.json'))
        image = Image.frombytes('RGBA', (data['size_x'], data['size_y']), archive.read('image_data/frames/1/layer_1'))
    mask = Image.new('L', image.size)
    ImageDraw.Draw(mask).polygon([(96,66),(159,95),(159,115),(133,111),(106,92),(96,82)], fill=255)
    mask = ImageChops.multiply(mask, image.getchannel('A'))
    ribbon = image.copy()
    ribbon.putalpha(mask)
    base = image.copy()
    base.putalpha(ImageChops.subtract(image.getchannel('A'), mask))
    faces = [blink(base, closed) for closed in [0,1,2,2,1,0]]
    offsets = [(0,0),(0,-1),(1,-1),(1,0),(0,1),(-1,0)]
    ribbons = []
    for dx,dy in offsets:
        cel = Image.new('RGBA', image.size)
        cel.alpha_composite(ribbon, (dx,dy))
        ribbons.append(cel)
    frames = faces + ribbons
    native_project(ART / 'senu_menu_idle_v8.pxo', frames,
        [tag('portrait_blink',0,5),tag('ribbon_wind',6,11)], 'Senu — olhos e faixa em pixels', 4, 12)
    manifest = {'canvas':[160,192], 'columns':4, 'frames':12,
        'texture':'res://assets/ui/senu_menu_idle_v8.png', 'blink':[0,1,2,3,4,5], 'wind':[6,7,8,9,10,11],
        'blink_period_seconds':5.2, 'blink_duration_seconds':.30, 'wind_fps':5,
        'source':'art/pixelorama/port_v7/senu_portrait_v7.pxo',
        'provenance':'Pixelorama native portrait source; eye pixels and separated ribbon cels; final PNG must be exported by installed Pixelorama.'}
    (ART / 'export_plan.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
    contact = Image.new('RGBA',(160*6,192*2),'#12252c')
    for i in range(6):
        contact.alpha_composite(faces[i],(i*160,0))
        contact.alpha_composite(ribbons[i],(i*160,192))
    contact.convert('RGB').save(ROOT/'qa/menu_idle_v8_preparation.png')
    print('Native menu portrait ready: 12 cels, separate blink and ribbon clips')

if __name__ == '__main__': build()
