"""Select the user's actual cut poses into a small native Pixelorama project.

Every source drawing uses the same scale; raised weapons never resize the body.
The delivery PNG is exported by Pixelorama, not by this preparation utility.
"""
import argparse, copy, json, math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw
import build_pixelorama_project as original

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/pixelorama/senu'
CANVAS = (256, 256)
PIVOT = (128, 200)
FACTOR = 1.22
DIRECTIONS = ['down', 'down_right', 'right', 'up_right', 'up', 'up_left', 'left', 'down_left']


def selected(spec, images):
    spec = copy.deepcopy(spec)
    spec['scale'] = FACTOR * .26
    # Selection is prepared in the established 384 canvas, then the empty
    # surrounding border is cropped. The anchor and anatomical scale are fixed.
    im = original.frame_image(spec, images)
    return im.crop((64, 80, 320, 336))


def light_specs(direction, source):
    if direction == 'up_right':
        # The supplied NE windup crops through its blade. Mirror the complete
        # NW pose instead, keeping the entire authored arm and cutting edge.
        mirrored = light_specs('up_left', source)
        for spec in mirrored:
            spec['flip_h'] = not spec.get('flip_h',False)
        return mirrored
    specs = copy.deepcopy(source['clips']['attack_light']['directions'][direction])
    base = {'down_right':'down_left','right':'down_left','left':'down_left',
            'up':'up_left'}.get(direction,direction)
    # Explicit selections exclude a neighboring blade that touches a frame's
    # source boundary in the supplied irregular sheet.
    if base == 'up_right':
        specs[0]['erase_rects']=[[0,92,5,26]]
        specs[2]['erase_rects']=[[0,105,6,29]]
        specs[3]['erase_rects']=[[0,95,10,23]]
    elif base == 'up_left':
        specs[2]['erase_rects']=[[0,70,11,58]]
        # The poster stores contact before the raised-arm anticipation.
        specs[1],specs[2]=specs[2],specs[1]
    return specs


def build():
    source = json.loads((ROOT / 'tools/pixelorama/source_frames.json').read_text(encoding='utf8'))
    images = {k: Image.open(OUT / 'sources' / (k+'.png')).convert('RGBA') for k in original.SOURCES}
    frames, tags, clips = [], [], {}
    for state in ['attack_light']:
        clips[state] = {}
        for direction in DIRECTIONS:
            specs = light_specs(direction, source) if state == 'attack_light' else source['clips'][state]['directions'][direction]
            ids = list(range(len(frames), len(frames)+len(specs)))
            frames.extend(selected(spec, images) for spec in specs)
            tags.append({'name':state+'_'+direction, 'from':ids[0]+1,'to':ids[-1]+1,'color':'d5b878ff'})
            clips[state][direction] = ids
    # The heavy cut holds the anticipation longer, then reuses the same clean
    # anatomical sweep. The irregular heavy poster overlaps neighboring bodies.
    clips['attack_heavy'] = copy.deepcopy(clips['attack_light'])
    for direction in DIRECTIONS:
        ids=clips['attack_heavy'][direction]
        tags.append({'name':'attack_heavy_'+direction,'from':ids[0]+1,'to':ids[-1]+1,'color':'b99762ff'})
    native = original.project_data(len(frames), [1.0]*len(frames), tags, True)
    native['size_x'], native['size_y'] = CANVAS
    native['layers'][0]['name'] = 'Khopesh — cortes reais fornecidos / escala fixa'
    for effect in native['layers'][0]['effects']:
        effect['params']['size'] = 'Vector2(256, 256)'
    native['export_profile']['lines_count']='8'
    native['symmetry_points']=[127.5,127.5]
    with ZipFile(OUT/'senu_sword_v7.pxo','w',ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('mimetype','application/x-pixelorama')
        z.writestr('data.json',json.dumps(native,ensure_ascii=False))
        for i,im in enumerate(frames): z.writestr(f'image_data/frames/{i+1}/layer_1',im.tobytes())
    notes = copy.deepcopy(source['clips']['attack_light']['direction_aliases'])
    notes['up_right']={'source_direction':'up_left','flip_h':True,
                       'reason':'The complete NW blade is mirrored; the supplied NE windup crosses its crop boundary.'}
    plan={'version':7,'canvas':list(CANVAS),'pivot':list(PIVOT),'game_scale':.26,
          'texture':'res://assets/sprites/senu_sword_v7.png','clips':clips,'frame_count':len(frames),
          'embedded_equipment':True,'source':'Supplied combat.png; no generated anatomy or whole-body deformation.',
          'direction_notes':notes}
    (OUT/'export_plan_sword_v7.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
    sheet=Image.new('RGB',(1280,970),(17,28,34));d=ImageDraw.Draw(sheet)
    for col,di in enumerate(DIRECTIONS):
        for row,index in enumerate(clips['attack_light'][di]):
            im=frames[index]
            sheet.paste(im,(col*160-48,row*155-45),im)
            d.text((col*160+8,row*155+135),di+' '+str(row),fill=(225,205,170))
    sheet.save(ROOT/'qa/sword_v7_preparation.png')
    print('SWORD_V7_PROJECT',len(frames),'frames')


def finalize():
    plan=json.loads((OUT/'export_plan_sword_v7.json').read_text(encoding='utf8'))
    native=json.loads((ROOT/'assets/sprites/senu_sword_v7.json').read_text(encoding='utf8'))
    with Image.open(ROOT/'assets/sprites/senu_sword_v7.png') as im:
        cols=im.width//256
        plan['frame_regions']=[[i%cols*256,i//cols*256,256,256] for i in range(plan['frame_count'])]
        assert len(native['frames'])==plan['frame_count']
        plan['texture_size']=list(im.size)
    plan['exported_by']='Pixelorama '+native['pixelorama_version']+' (official CLI)'
    (ROOT/'assets/sprites/senu_sword_v7_manifest.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
    print('SWORD_V7_FINALIZED',plan['texture_size'])

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--finalize',action='store_true');a=p.parse_args()
    finalize() if a.finalize else build()
