"""Prepare new anatomical cutting cels; PNG delivery is exported by Pixelorama."""
import argparse
import copy
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import numpy as np
from PIL import Image, ImageDraw
import build_pixelorama_project as native
from build_port_art_v6 import selection

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/senu'
SOURCE = ART / 'sword_v8_sources/cuts_guided.png'
NATIVE = ART / 'senu_sword_v8.pxo'
PLAN = ART / 'export_plan_sword_v8.json'
CANVAS = (288, 288)
PIVOT = (144, 248)
ROWS = ['down', 'down_right', 'right', 'up_right', 'up']
ORDER = ['down', 'down_right', 'right', 'up_right', 'up', 'up_left', 'left', 'down_left']
MIRRORS = {'up_left': 'up_right', 'left': 'right', 'down_left': 'down_right'}

def build():
    source = Image.open(SOURCE).convert('RGBA')
    corrected_front = Image.open(ART/'sword_v8_sources/cuts_front_corrected.png').convert('RGBA')
    crops = {}
    for row, name in enumerate(ROWS):
        cells = []
        for col in range(6):
            # Only the south acceleration/contact/follow-through were edited.
            # Keep the guard, full raised blade and ALL other views untouched.
            selected_source = corrected_front if row == 0 and col in [2,3,4] else source
            rect = (round(col*selected_source.width/6), round(row*selected_source.height/5),
                    round((col+1)*selected_source.width/6), round((row+1)*selected_source.height/5))
            cells.append(selection(selected_source, rect, allow_near=False))
        crops[name] = cells
    frames, clips, tags, anatomy = [], {}, [], {}
    for name in ORDER:
        origin = MIRRORS.get(name, name)
        cells = crops[origin]
        # Calibrate the resting anatomy once per direction, never per phase.
        factor = 145.0 / cells[0].height
        anatomy[name] = {'source': origin, 'factor': factor, 'idle_height': cells[0].height,
                         'mirrored': name in MIRRORS}
        start = len(frames)
        clips[name] = []
        for col, crop in enumerate(cells):
            alpha = np.asarray(crop.getchannel('A'))
            ys, xs = np.nonzero(alpha >= 96)
            bottom = int(ys.max()) + 1
            foot_x = float(np.median(xs[ys >= bottom - max(7, round(crop.height*.045))]))
            small = crop.resize((round(crop.width*factor), round(crop.height*factor)), Image.Resampling.NEAREST)
            cel = Image.new('RGBA', CANVAS)
            at = (PIVOT[0]-round(foot_x*factor), PIVOT[1]-round(bottom*factor))
            cel.paste(small, at)
            if name in MIRRORS:
                # Mirror around the exact foot pivot rather than the canvas edge.
                cel = cel.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
                cel = Image.fromarray(np.roll(np.asarray(cel), 1, axis=1))
            bounds = cel.getchannel('A').point(lambda a: 255 if a>=96 else 0).getbbox()
            assert bounds and min(bounds[:2]) > 0 and bounds[2]<CANVAS[0] and bounds[3]<=PIVOT[1]+1, (name,col,bounds,at,small.size)
            clips[name].append(len(frames))
            frames.append(cel)
        tags.append({'name':'cut_'+name,'from':start+1,'to':len(frames),'color':'d5b878ff'})
    data = native.project_data(len(frames), [1.0]*len(frames), tags, True)
    data['size_x'], data['size_y'] = CANVAS
    data['layers'][0]['name'] = 'Khopesh — 6 poses, anatomia e apoio fixos'
    for effect in data['layers'][0]['effects']:
        effect['params']['size'] = 'Vector2(288, 288)'
    data['export_profile']['lines_count'] = '8'
    data['symmetry_points'] = [143.5,143.5]
    with ZipFile(NATIVE,'w',ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/x-pixelorama')
        z.writestr('data.json',json.dumps(data,ensure_ascii=False))
        for i, frame in enumerate(frames): z.writestr(f'image_data/frames/{i+1}/layer_1',frame.tobytes())
    plan = {'version':8,'canvas':list(CANVAS),'pivot':list(PIVOT),'game_scale':.26,
            'texture':'res://assets/sprites/senu_sword_v8.png','frame_count':len(frames),
            'clips':{'attack_light':clips,'attack_heavy':copy.deepcopy(clips)},
            'phases':['guard','coil','accelerate','contact','follow_through','recover'],
            'impact':{'attack_light':.12,'attack_heavy':.24,'power':.15},
            'anatomical_reference':anatomy,'source':'art/pixelorama/senu/sword_v8_sources/cuts_guided.png',
            'provenance':'ImageGen guided by the actual shared body and a 30-pose anatomical diagram; final PNG exported in Pixelorama.'}
    PLAN.write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
    contact = Image.new('RGBA',(CANVAS[0]*8,CANVAS[1]*6),'#14252c')
    for col,name in enumerate(ORDER):
        for row,index in enumerate(clips[name]): contact.alpha_composite(frames[index],(col*CANVAS[0],row*CANVAS[1]))
    contact.resize((1536,1152),Image.Resampling.NEAREST).convert('RGB').save(ROOT/'qa/sword_v8_preparation.png')
    print('SWORD_V8_NATIVE',len(frames),'cels',anatomy)

def finalize():
    plan = json.loads(PLAN.read_text(encoding='utf8'))
    data = json.loads((ROOT/'assets/sprites/senu_sword_v8.json').read_text(encoding='utf8'))
    image = Image.open(ROOT/'assets/sprites/senu_sword_v8.png')
    columns = image.width//CANVAS[0]
    assert len(data['frames'])==plan['frame_count']
    plan['frame_regions']=[[i%columns*CANVAS[0],i//columns*CANVAS[1],CANVAS[0],CANVAS[1]] for i in range(plan['frame_count'])]
    plan['texture_size']=list(image.size)
    plan['exported_by']='Pixelorama '+data['pixelorama_version']+' (official CLI)'
    (ROOT/'assets/sprites/senu_sword_v8_manifest.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
    print('SWORD_V8_EXPORTED',image.size)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--finalize',action='store_true');args=p.parse_args()
    finalize() if args.finalize else build()
