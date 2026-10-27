"""Validate native cels and optional Pixelorama exports without changing them."""
import json
import hashlib
from pathlib import Path
from zipfile import ZipFile
from PIL import Image,ImageDraw,ImageChops
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/dialogue_v14'
OUT=ROOT/'assets/ui/dialogue_v14'

def read(name):
    with ZipFile(ART/f'{name}.pxo') as archive:
        data=json.loads(archive.read('data.json'))
        frames=[]
        for index in range(36):
            cel=Image.new('RGBA',(160,192))
            for layer in range(len(data['layers'])):
                cel.alpha_composite(Image.frombytes('RGBA',(160,192),archive.read(f'image_data/frames/{index+1}/layer_{layer+1}')))
            frames.append(cel)
        return data,frames

def run():
    report={}
    faceboard=Image.new('RGBA',(1200,480),'#14252c')
    d=ImageDraw.Draw(faceboard)
    titles=['closed mouth','small mouth','open mouth','half blink','closed eyes','sad expression']
    for row,name in enumerate(['senu','fisherman']):
        data,frames=read(name)
        assert data['size_x']==160 and data['size_y']==192
        assert len(data['layers'])==6 and len(data['frames'])==36
        assert len({hashlib.sha256(i.tobytes()).hexdigest() for i in frames})==36
        assert all(set(cel.getchannel('A').get_flattened_data())<={0,255} for cel in frames)
        # Face changes are confined to the intended eye/brow/lip editing area.
        mask=Image.new('L',(160,192),255)
        r=(160-74,48,160-47,80) if name=='senu' else (40,52,69,89)
        ImageDraw.Draw(mask).rectangle((r[0],r[1],r[2]-1,r[3]-1),fill=0)
        for cel in frames:
            changed=ImageChops.difference(cel,frames[0]).convert('RGB').convert('L')
            assert ImageChops.multiply(changed,mask).getbbox() is None,(name,'identity drift outside face')
        mouth_bounds=(160-65,70,160-51,80) if name=='senu' else (48,79,65,89)
        assert len({frames[i].crop(mouth_bounds).tobytes() for i in range(3)})==3
        assert frames[0].crop(mouth_bounds).tobytes()==frames[6].crop(mouth_bounds).tobytes()
        eye_bounds=(160-74,55,160-47,66) if name=='senu' else (40,59,67,68)
        assert len({frames[i].crop(eye_bounds).tobytes() for i in [0,3,6]})==3
        assert frames[0].crop(eye_bounds).tobytes()==frames[2].crop(eye_bounds).tobytes()
        final=OUT/f'{name}.png'
        exported=False
        if final.exists():
            atlas=Image.open(final).convert('RGBA');assert atlas.size==(960,1152)
            for index,cel in enumerate(frames):
                region=atlas.crop((index%6*160,index//6*192,index%6*160+160,index//6*192+192))
                assert ImageChops.difference(region.getchannel('A'),cel.getchannel('A')).getbbox() is None,(name,index,'alpha')
                # RGB of transparent pixels is intentionally not significant.
                diff=ImageChops.difference(region,cel).convert('RGB').convert('L')
                assert ImageChops.multiply(diff,cel.getchannel('A')).getbbox() is None,(name,index,'visible pixels')
            exported=True
        report[name]={'frames':36,'layers':6,'unique_cels':36,'binary_alpha':True,
                      'face_only_changes':True,'independent_eye_mouth':True,'pixelorama_export_exact':exported}
        face=(65,38,125,98) if name=='senu' else (35,42,95,102)
        for col,index in enumerate([0,1,2,3,6,18]):
            crop=frames[index].crop(face).resize((200,200),Image.Resampling.NEAREST)
            faceboard.alpha_composite(crop,(col*200,row*240+20))
            d.text((col*200+5,row*240+222),f'{name}: {titles[col]}',fill='#eee0ba')
    (ROOT/'qa/dialogue_portraits_v14_validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    faceboard.convert('RGB').save(ROOT/'qa/dialogue_portraits_v14_face_states.png')
    print(json.dumps(report))

if __name__=='__main__':run()
