"""Verify actual editable pixels, restored face, and runtime JSON contacts."""
import hashlib,json,math,wave
from pathlib import Path
from zipfile import ZipFile
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/porteiro_v5'
QA=ROOT/'qa/porteiro_attacks_v5'

def run():
    results=[]
    def check(value,label):
        results.append({'ok':bool(value),'message':label})
        if not value:print('FAIL',label)
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    runtime=json.loads((ROOT/'assets/sprites/porteiro_v5_manifest.json').read_text(encoding='utf8'))
    definitions=ROOT/'resources/bosses/gatekeeper_attacks.json'
    attacks=json.loads(definitions.read_text(encoding='utf8'))
    check(plan==runtime,'Runtime manifest equals editable export plan')
    # Combat tuning may change damage/cooldowns without regenerating immutable
    # art studies. Verify the animation contract itself, not the whole JSON hash.
    authored={key:{'seconds':[plan['durations'][i] for i in plan['clips'][key]['down_right']],
                   'contact_pose':plan['clips'][key]['down_right'].index(plan['contact_frames'][key])} for key in attacks['order']}
    current={key:{field:attacks['attacks'][key][field] for field in ['seconds','contact_pose']} for key in attacks['order']}
    check(authored==current,'Preserved art timeline/contact agrees with the current JSON independently of combat tuning')
    check(plan['reference_sha256']==hashlib.sha256((ROOT/'docs/concept_art/porteiro_sem_nome/concept_02.png').read_bytes()).hexdigest(),'Concept art unchanged')
    atlas=Image.open(ROOT/'assets/sprites/porteiro_v5.png').convert('RGBA')
    palette={tuple(bytes.fromhex(c)) for c in plan['palette']}
    frames=[]
    with ZipFile(ROOT/'art/pixelorama/porteiro_v3/porteiro_v3.pxo') as previous:
        head=Image.frombytes('RGBA',(160,160),previous.read('image_data/frames/1/layer_3')).crop((60,75,100,105))
    with ZipFile(ART/'porteiro_v5.pxo') as source:
        project=json.loads(source.read('data.json'))
        check(len(project['layers'])==4 and len(project['frames'])==99,'99 editable cels in four layers')
        for i,info in enumerate(plan['frame_metadata']):
            layers=[Image.frombytes('RGBA',(160,160),source.read(f'image_data/frames/{i+1}/layer_{n+1}')) for n in range(4)]
            cel=Image.new('RGBA',(160,160))
            for layer in layers:cel.alpha_composite(layer)
            frames.append(cel)
            x,y,w,h=plan['frame_regions'][i]
            check(atlas.crop((x,y,x+w,y+h)).tobytes()==cel.tobytes(),f'{i}: exported pixels match native source')
            check(Image.open(ART/f'cels/{i:03}.png').convert('RGBA').tobytes()==cel.tobytes(),f'{i}: individual cel matches native source')
            rgba=cel.tobytes()
            check(set(rgba[3::4])<={0,255},f'{i}: crisp alpha')
            check(all(tuple(rgba[p:p+3]) in palette for p in range(0,len(rgba),4) if rgba[p+3]),f'{i}: stable palette')
            bounds=cel.getbbox()
            check(bounds and bounds[0]>1 and bounds[1]>1 and bounds[2]<159 and bounds[3]<159,f'{i}: no clipped weapon or feet')
            check(layers[2].crop((60+info['lean'],75+info['drop'],100+info['lean'],105+info['drop'])).tobytes()==head.tobytes(),f'{i}: preferred v3 face preserved')
            check(abs(math.dist(info['rear'],info['lead'])-12)<1,f'{i}: constant two-handed grip')
            check(all(layers[3].getpixel(tuple(hand))[3]==255 for hand in [info['rear'],info['lead']]),f'{i}: hands touch shaft')
        signatures=[]
        for key in attacks['order']:
            attack=attacks['attacks'][key]
            sequence=plan['clips'][key]['down_right']
            check(len(sequence)==9 and len(set(sequence))==9,key+': own nine-cel timeline')
            check([plan['durations'][i] for i in sequence]==attack['seconds'],key+': exact JSON timings')
            check(plan['contact_frames'][key]==sequence[attack['contact_pose']],key+': exact contact cel')
            check(abs(plan['contact_seconds'][key]-sum(attack['seconds'][:attack['contact_pose']]))<1e-6,key+': contact after preparation')
            check(all(abs(float(project['frames'][i]['duration'])/project['fps']-plan['durations'][i])<1e-6 for i in sequence),key+': native Pixelorama playback agrees')
            check(len({frames[i].tobytes() for i in sequence})>=7,key+': full body changes across the sequence')
            signatures.append(tuple(hashlib.sha256(frames[i].tobytes()).hexdigest() for i in sequence))
        check(len(set(signatures))==9,'Each attack has a distinct visual sequence')
    for name in ['bell','chain']:
        with wave.open(str(ROOT/f'assets/audio/sfx/gatekeeper_{name}.wav'),'rb') as sound:
            check(sound.getnchannels()==1 and sound.getsampwidth()==2 and sound.getnframes()>sound.getframerate()*.3,name+': original WAV is valid')
    report={'checks':len(results),'passed':sum(r['ok'] for r in results),'failures':sum(not r['ok'] for r in results),'scope':'one-direction art/contact study, not completed boss encounter','details':results}
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('GATEKEEPER V5 ASSETS',report['passed'],'/',report['checks'])
    raise SystemExit(bool(report['failures']))

if __name__=='__main__':run()
