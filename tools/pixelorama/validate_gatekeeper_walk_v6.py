"""Actual pixel/source validation plus projected foot-support kinematics."""
import json,hashlib,math
from pathlib import Path
from zipfile import ZipFile
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/porteiro_walk_v6'
QA=ROOT/'qa/porteiro_walk_v6'
def run():
    results=[]
    def check(ok,label):
        results.append({'ok':bool(ok),'message':label})
        if not ok:print('FAIL',label)
    settings=json.loads((ROOT/'resources/bosses/gatekeeper_walk.json').read_text(encoding='utf8'))
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    check(plan==json.loads((ROOT/'assets/sprites/porteiro_walk_v6_manifest.json').read_text(encoding='utf8')),'Export and runtime manifests agree')
    check(plan['settings_sha256']==hashlib.sha256((ROOT/'resources/bosses/gatekeeper_walk.json').read_bytes()).hexdigest(),'Current JSON authored the walk')
    check(plan['previous_attacks_sha256']==hashlib.sha256((ROOT/'art/pixelorama/porteiro_v5/porteiro_v5.pxo').read_bytes()).hexdigest(),'All original attack cels are preserved')
    palette={tuple(bytes.fromhex(c)) for c in plan['palette']}
    atlas=Image.open(ROOT/'assets/sprites/porteiro_walk_v6.png').convert('RGBA')
    with ZipFile(ROOT/'art/pixelorama/porteiro_v5/porteiro_v5.pxo') as previous:
        original=[Image.frombytes('RGBA',(160,160),previous.read(f'image_data/frames/1/layer_{i+1}')) for i in range(4)]
        face=original[2].crop((60,75,100,105))
    frames=[]
    with ZipFile(ART/'porteiro_walk_v6.pxo') as source:
        project=json.loads(source.read('data.json'))
        check(len(project['layers'])==4 and len(project['frames'])==49,'49 editable cels, including phase-specific closing steps')
        for i,meta in enumerate(plan['frame_metadata']):
            layers=[Image.frombytes('RGBA',(160,160),source.read(f'image_data/frames/{i+1}/layer_{j+1}')) for j in range(4)]
            cel=Image.new('RGBA',(160,160))
            for layer in layers:cel.alpha_composite(layer)
            frames.append(cel)
            x,y,w,h=plan['frame_regions'][i]
            check(cel.tobytes()==atlas.crop((x,y,x+w,y+h)).tobytes(),f'{i}: actual Pixelorama export equals native source')
            rgba=cel.tobytes()
            check(set(rgba[3::4])<={0,255},f'{i}: crisp native alpha')
            check(all(tuple(rgba[p:p+3]) in palette for p in range(0,len(rgba),4) if rgba[p+3]),f'{i}: consistent palette')
            bounds=cel.getbbox()
            check(bounds and bounds[0]>1 and bounds[1]>1 and bounds[2]<159 and bounds[3]<159,f'{i}: no clipping')
            check(layers[2].crop((60+meta['lean'],75+meta['drop'],100+meta['lean'],105+meta['drop'])).tobytes()==face.tobytes(),f'{i}: preferred face retains exact pixels')
            check(abs(math.dist(meta['rear'],meta['lead'])-12)<1 and all(layers[3].getpixel(tuple(p))[3] for p in [meta['rear'],meta['lead']]),f'{i}: hands stay on the steady shaft')
            if i<48:
                check(meta['support_near'] or meta['support_far'],f'{i}: at least one supporting foot')
                for side in ['near','far']:
                    check(0<=meta['feet_plane'][side][1]<=2,f'{i}: {side} foot stays low')
        for j in range(4):check(source.read(f'image_data/frames/49/layer_{j+1}')==original[j].tobytes(),f'Final layer{j}: exact original guard restored')
    check(len({cel.tobytes() for cel in frames[:16]})==16,'Sixteen distinct full-body walk cels')
    for side,start,end in [('near',0,9),('far',8,17)]:
        world=[]
        for i in range(start,end):
            meta=plan['frame_metadata'][i%16]
            root=i*settings['stride']/16
            world.append([meta[side][n]+root*settings['ground_axis'][n] for n in range(2)])
        check(all(max(p[n] for p in world)-min(p[n] for p in world)<=1.01 for n in range(2)),side+': stance sole stays planted as root moves forward')
    for phase in range(16):
        seq=plan['settle_sequences'][str(phase)]
        check(seq[0]==phase and seq[-1]==48,f'{phase}: closing steps start on the current cel and end on guard')
    report={'checks':len(results),'passed':sum(r['ok'] for r in results),'failures':sum(not r['ok'] for r in results),'scope':'art review of one authored direction, not a complete boss','details':results}
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('GATEKEEPER WALK V6',report['passed'],'/',report['checks'])
    raise SystemExit(bool(report['failures']))
if __name__=='__main__':run()
