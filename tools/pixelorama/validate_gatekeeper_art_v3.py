"""Pixel/source and anatomy contracts for the corrected acting pilot."""
from pathlib import Path
from zipfile import ZipFile
from PIL import Image
import hashlib,json,math,argparse

ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--version',type=int,choices=[3,4],default=4)
VERSION=parser.parse_args().version
STEM=f'porteiro_v{VERSION}'
ART=ROOT/f'art/pixelorama/{STEM}'
QA=ROOT/f'qa/porteiro_art_v{VERSION}'


def run():
    results=[]
    def check(value,label):
        results.append({'ok':bool(value),'message':label})
        if not value: print('FAIL',label)
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    runtime=json.loads((ROOT/f'assets/sprites/{STEM}_manifest.json').read_text(encoding='utf8'))
    check(plan==runtime,'Runtime has the complete export plan')
    check(plan['reference_sha256']==hashlib.sha256((ROOT/'docs/concept_art/porteiro_sem_nome/concept_02.png').read_bytes()).hexdigest(),'Original concept is preserved')
    atlas=Image.open(ROOT/f'assets/sprites/{STEM}.png').convert('RGBA')
    palette={tuple(bytes.fromhex(c)) for c in plan['palette']}
    head_cels=[]
    frames=[]
    with ZipFile(ART/f'{STEM}.pxo') as z:
        data=json.loads(z.read('data.json'))
        check(len(data['layers'])==4 and data['pxo_version']==7,'Editable four-layer Pixelorama project')
        check(len(data['frames'])==18,'All full-body review cels are present')
        for i in range(18):
            cel=Image.new('RGBA',(160,160))
            layers=[]
            for layer in range(4):
                im=Image.frombytes('RGBA',(160,160),z.read(f'image_data/frames/{i+1}/layer_{layer+1}'))
                layers.append(im);cel.alpha_composite(im)
            frames.append(cel)
            x,y,w,h=plan['frame_regions'][i]
            check(atlas.crop((x,y,x+w,y+h)).tobytes()==cel.tobytes(),f'Cel{i}: exported pixels match the editable source')
            rgba=cel.tobytes()
            check(set(rgba[3::4])<={0,255},f'Cel{i}: binary alpha')
            check(all(tuple(rgba[p:p+3]) in palette for p in range(0,len(rgba),4) if rgba[p+3]),f'Cel{i}: stable material palette')
            bounds=cel.getbbox()
            check(bounds and bounds[0]>1 and bounds[1]>1 and bounds[2]<159 and bounds[3]<159,f'Cel{i}: no clipped blade, foot or hair')
            info=plan['frame_metadata'][i]
            head_cels.append(layers[2].crop((60+info['lean'],75+info['drop'],100+info['lean'],105+info['drop'])))
            rear,lead=info['rear'],info['lead']
            check(abs(math.dist(rear,lead)-12)<1.0,f'Cel{i}: two-handed grip spacing is constant')
            check(all(layers[3].getpixel(tuple(hand))[3]==255 for hand in [rear,lead]),f'Cel{i}: both hands physically touch the shaft')
            for name in ['near','far']:
                fx,fy=info[name]
                sole=cel.crop((fx-3,fy-3,fx+4,fy+1))
                check(sole.getbbox() is not None,f'Cel{i}: {name} foot has actual sole pixels')
    for i,head in enumerate(head_cels):check(head.tobytes()==head_cels[0].tobytes(),f'Cel{i}: original human face stays the same size and pixels')
    if VERSION==4:
        with ZipFile(ART/'porteiro_v4.pxo') as latest, ZipFile(ROOT/'art/pixelorama/porteiro_v3/porteiro_v3.pxo') as previous:
            for i in range(18):
                path=f'image_data/frames/{i+1}/layer_3'
                check(latest.read(path)==previous.read(path),f'Cel{i}: player-preferred v3 face restored pixel-for-pixel')
    check(len({f.tobytes() for f in frames[1:9]})==8,'Eight genuinely distinct walking poses')
    check(len({f.tobytes() for f in frames[9:18]})>=8,'Thrust changes the complete body before returning to guard')
    for i,info in enumerate(plan['frame_metadata'][1:9]):
        check(info['support_near'] or info['support_far'],f'Walk{i}: at least one supporting foot at every phase')
    # A planted sole cancels the actor's world travel during the support half.
    planted=[]
    for i,info in enumerate(plan['frame_metadata'][1:6]):planted.append(info['near'][0]+i*3)
    check(max(planted)-min(planted)<=1,'Near support foot stays planted while actor travels forward')
    attack=plan['frame_metadata'][9:18]
    check(attack[3]['rear'][0]<attack[0]['rear'][0]-6,'Hands draw the spear backwards during body loading')
    check(attack[5]['sh_near'][0]>attack[3]['sh_near'][0]+6,'Shoulders move with the thrust, rather than weapon-only rotation')
    check(attack[5]['near'][0]>attack[3]['near'][0]+6,'Front leg carries the lunge')
    check(abs(sum(plan['durations'][9:14])-plan['contact_seconds'])<.00001,'Contact marker is after the full grip/load/acceleration sequence')
    report={'checks':len(results),'passed':sum(r['ok'] for r in results),'failures':sum(not r['ok'] for r in results),'scope':'art review only, not boss combat','details':results}
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print('GATEKEEPER',STEM,'PIXELS',report['passed'],'/',report['checks'],'failures=',report['failures'])
    raise SystemExit(1 if report['failures'] else 0)


if __name__=='__main__':run()
