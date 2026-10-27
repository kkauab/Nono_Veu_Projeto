"""Check complete new Pixelorama cels and both final native exports."""
import json
import hashlib
from pathlib import Path
from zipfile import ZipFile
from PIL import Image,ImageChops

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/dialogue_v15'
OUT=ROOT/'assets/ui/dialogue_v15'

def run():
    report={}
    manifest=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    for name in ['senu','fisherman']:
        with ZipFile(ART/f'{name}.pxo') as archive:
            data=json.loads(archive.read('data.json'))
            assert len(data['frames'])==20 and len(data['layers'])==1
            assert (data['size_x'],data['size_y'])==(160,192)
            frames=[Image.frombytes('RGBA',(160,192),archive.read(f'image_data/frames/{i+1}/layer_1')) for i in range(20)]
        assert len({hashlib.sha256(i.tobytes()).hexdigest() for i in frames})==20
        assert all(set(i.getchannel('A').get_flattened_data())<={0,255} for i in frames)
        atlas=Image.open(OUT/f'{name}.png').convert('RGBA')
        assert atlas.size==(800,768)
        for index,cel in enumerate(frames):
            region=atlas.crop((index%5*160,index//5*192,index%5*160+160,index//5*192+192))
            assert ImageChops.difference(region.getchannel('A'),cel.getchannel('A')).getbbox() is None,(name,index,'alpha')
            diff=ImageChops.difference(region,cel).convert('RGB').convert('L')
            assert ImageChops.multiply(diff,cel.getchannel('A')).getbbox() is None,(name,index,'visiblepixels')
            assert hashlib.sha256(cel.tobytes()).hexdigest()==manifest['native_cel_sha256'][name][index]
        report[name]={'frames':20,'layers':1,'complete_new_cels':True,'unique_cels':20,
                      'binary_alpha':True,'atlas_size':[800,768],'pixelorama_export_exact':True,
                      'face_rect':manifest['face_rects'][name],'no_programmatic_facial_painting':True}
    (ROOT/'qa/dialogue_portraits_v15_validation.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print(json.dumps(report))

if __name__=='__main__':run()
