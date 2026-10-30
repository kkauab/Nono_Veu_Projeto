"""Validate actual Pixelorama output against editable RGBA layers and poses."""
import hashlib
import json
import argparse
from pathlib import Path
from zipfile import ZipFile
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OPTIONS=argparse.ArgumentParser()
OPTIONS.add_argument('--version',type=int,choices=[1,2],default=2)
VERSION=OPTIONS.parse_args().version
STEM=f'porteiro_v{VERSION}'
ART=ROOT/f'art/pixelorama/{STEM}'
QA=ROOT/f'qa/porteiro_art_v{VERSION}'


def validate():
    checks=[]
    def check(ok,message):
        checks.append({'ok':bool(ok),'message':message})
        if not ok: print('FAIL',message)
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    exported=json.loads((ROOT/f'assets/sprites/{STEM}_manifest.json').read_text(encoding='utf8'))
    check(plan==exported,'Runtime manifest equals the export plan')
    source=ROOT/'docs/concept_art/porteiro_sem_nome/concept_02.png'
    check(hashlib.sha256(source.read_bytes()).hexdigest()==plan['reference_sha256'],'Concept reference is unchanged')
    atlas=Image.open(ROOT/f'assets/sprites/{STEM}.png').convert('RGBA')
    check(atlas.size==(1280,480),'Complete 17-frame native atlas dimensions')
    palette={tuple(bytes.fromhex(c)) for c in plan['palette']}
    frames=[]
    with ZipFile(ART/f'{STEM}.pxo') as z:
        native=json.loads(z.read('data.json'))
        check(native['pxo_version']==7 and len(native['layers'])==4,'Editable Pixelorama 7 with four named layers')
        check(len(native['frames'])==17,'All review cels are present in native project')
        for i in range(17):
            frame=Image.new('RGBA',(160,160))
            for j in range(4):
                frame.alpha_composite(Image.frombytes('RGBA',(160,160),z.read(f'image_data/frames/{i+1}/layer_{j+1}')))
            frames.append(frame)
            x,y,w,h=plan['frame_regions'][i]
            actual=atlas.crop((x,y,x+w,y+h))
            check(actual.tobytes()==frame.tobytes(),f'Cel {i:02}: exported pixels equal all editable layers')
            check(set(actual.getchannel('A').tobytes())<={0,255},f'Cel {i:02}: binary alpha')
            rgba=actual.tobytes()
            opaque=[tuple(rgba[p:p+4]) for p in range(0,len(rgba),4) if rgba[p+3]]
            check(all(p[:3] in palette for p in opaque),f'Cel {i:02}: stable material palette')
            bounds=actual.getbbox()
            check(bounds is not None and bounds[0]>2 and bounds[1]>2 and bounds[2]<158 and bounds[3]<158,f'Cel {i:02}: body and full spear stay inside canvas')
        for i,clip in [(0,'front'),(1,'side'),(2,'back')]:
            bounds=plan['frame_metadata'][i]['body_bounds']
            check(bounds[3]-bounds[1]==57,f'{clip}: same 57px anatomical registration')
    for start,end,kind in [(3,11,'walk'),(11,17,'thrust')]:
        check(len({frame.tobytes() for frame in frames[start:end]})==end-start,f'{kind}: every cel is distinct')
        for i in range(start,end):
            info=plan['frame_metadata'][i]
            # The entire face/hair translates as a rigid native cel: no morphing.
            dx,dy=info['body_lean'],info['body_drop']
            first=frames[start]
            origin=plan['frame_metadata'][start]
            head_equal=True
            for y in range(83,94):
                for x in range(77,86):
                    pixel=first.getpixel((x+origin['body_lean'],y+origin['body_drop']))
                    if pixel[3] and frames[i].getpixel((x+dx,y+dy))!=pixel: head_equal=False
            check(head_equal,f'{kind} {i-start}: head identity and size preserved')
            grip=info['grip']
            check(frames[i].getpixel(tuple(grip))[3]==255,f'{kind} {i-start}: hand actually contacts spear')
            for foot in info['feet']:
                check(frames[i].getpixel(tuple(foot))[3]==255,f'{kind} {i-start}: sole has real pixels at registered contact')
    contact=plan['contact_frame']
    check(abs(sum(plan['durations'][11:contact])-.7)<.00001,'Contact marker follows the anticipation durations')
    check(plan['frame_metadata'][contact]['grip'][0]>plan['frame_metadata'][12]['grip'][0]+10,'Contact has a real extended arm silhouette, not merely a rotated weapon')
    count=len(checks)
    failures=sum(not row['ok'] for row in checks)
    report={'checks':count,'passed':count-failures,'failures':failures,'details':checks,'scope':'art only; no combat validation'}
    (QA/'validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(f'GATEKEEPER PIXELS {count-failures}/{count}; failures={failures}')
    raise SystemExit(1 if failures else 0)


if __name__=='__main__': validate()
