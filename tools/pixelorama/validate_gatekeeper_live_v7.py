"""Validate every compact exported cel against the five editable native layers."""
from pathlib import Path
from zipfile import ZipFile
from PIL import Image
import json,hashlib,sys
ROOT=Path(__file__).resolve().parents[2]
VERSION=int(sys.argv[1]) if len(sys.argv)>1 else 7
assert VERSION in [7,8,9]
STEM=f'porteiro_live_v{VERSION}';ART=ROOT/'art/pixelorama'/STEM;QA=ROOT/'qa/porteiro_combate'
def run():
    results=[]
    def check(ok,label):
        results.append({'ok':bool(ok),'message':label})
        if not ok:print('FAIL',label)
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    live=json.loads((ROOT/'assets/sprites'/(STEM+'_manifest.json')).read_text(encoding='utf8'))
    atlas=Image.open(ROOT/'assets/sprites'/(STEM+'.png')).convert('RGBA')
    check(live['source_project_sha256']==hashlib.sha256((ART/(STEM+'.pxo')).read_bytes()).hexdigest(),'Runtime came from the current native project')
    check(plan['reference_sha256']==hashlib.sha256((ROOT/'docs/concept_art/porteiro_sem_nome/concept_02.png').read_bytes()).hexdigest(),'Original concept preserved')
    with ZipFile(ROOT/'art/pixelorama/porteiro_v3/porteiro_v3.pxo') as original:
        face=Image.frombytes('RGBA',(160,160),original.read('image_data/frames/1/layer_3'))
        face=face.crop(face.getbbox())
    with ZipFile(ART/(STEM+'.pxo')) as source:
        data=json.loads(source.read('data.json'))
        check(len(data['layers'])==5 and len(data['frames'])==1336,'All eight direction sets are editable in five depth layers')
        for i,meta in enumerate(plan['frame_metadata']):
            layers=[Image.frombytes('RGBA',(192,192),source.read(f'image_data/frames/{i+1}/layer_{j+1}')) for j in range(5)]
            native=Image.new('RGBA',(192,192))
            for layer in layers:native.alpha_composite(layer)
            x,y,w,h=live['frame_regions'][i];offset=live['frame_offsets'][i]
            runtime=Image.new('RGBA',(192,192));runtime.alpha_composite(atlas.crop((x,y,x+w,y+h)),(offset[0]+96,offset[1]+144))
            check(native.tobytes()==runtime.tobytes(),f'{i}: Pixelorama export/trim retains every native pixel and the foot pivot')
            check(set(native.getchannel('A').tobytes())<={0,255},f'{i}: crisp alpha')
            bounds=native.getbbox()
            check(bounds and bounds[0]>0 and bounds[1]>0 and bounds[2]<192 and bounds[3]<192,f'{i}: weapon, hair and feet are not clipped')
            head=layers[3];head=head.crop(head.getbbox())
            direction=meta['direction']
            if direction in ['right','down_right','down','down_left','left']:
                expected=face.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if direction in ['left','down_left'] else face
                check(head.tobytes()==expected.tobytes() and head.size==expected.size,f'{i}: preferred human face retained without repainting')
    attacks=json.loads((ROOT/'resources/bosses/gatekeeper_attacks.json').read_text(encoding='utf8'))
    for direction in live['directions']:
        for name in ['idle','walk','kneel','rise','despair','defeat','dead','hurt','stagger',*attacks['order']]:
            check(bool(live['clips'].get(name,{}).get(direction,[])),direction+': own '+name+' cels')
        for id in attacks['order']:
            indices=live['clips'][id][direction]
            check([live['durations'][i] for i in indices]==attacks['attacks'][id]['seconds'],direction+': '+id+' contact clock matches JSON')
    report={'checks':len(results),'passed':sum(r['ok'] for r in results),'failures':sum(not r['ok'] for r in results),'atlas':atlas.size,'frames':live['frames'],'details':results}
    (QA/f'art_validation_v{VERSION}.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('GATEKEEPER LIVE ART',report['passed'],'/',report['checks'],'atlas=',atlas.size)
    raise SystemExit(bool(report['failures']))
if __name__=='__main__':run()
