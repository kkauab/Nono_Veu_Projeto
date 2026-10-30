"""Readable studio comparison and actual map captures, with GIF tick timing."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'qa/porteiro_walk_v6'
def timing(count,fps):
    # Accumulate time in GIF's 10ms grid, rather than speeding 67ms up to 60ms.
    return [round((i+1)*100/fps)*10-round(i*100/fps)*10 for i in range(count)]
def run():
    settings=json.loads((ROOT/'resources/bosses/gatekeeper_walk.json').read_text(encoding='utf8'))
    old=[Image.open(ROOT/f'art/pixelorama/porteiro_v5/cels/{i+1:03}.png').convert('RGBA') for i in range(8)]
    new=[Image.open(ROOT/f'art/pixelorama/porteiro_walk_v6/cels/{i:03}.png').convert('RGBA') for i in range(16)]
    font=ImageFont.truetype(str(ROOT/'assets/fonts/PixelOperatorHB.ttf'),20)
    frames=[]
    for i in range(120):
        page=Image.new('RGB',(720,330),'#142026');draw=ImageDraw.Draw(page)
        draw.text((20,14),'ANTERIOR',font=font,fill='#c7b38c');draw.text((380,14),'PASSOS REFINADOS',font=font,fill='#c7b38c')
        indices=[int((i/30*39/24)%1*8),(int((i/30*settings['move_speed']/settings['stride'])%1*16)+settings['start_phase'])%16]
        for j,cel in enumerate([old[indices[0]],new[indices[1]]]):
            picture=cel.crop((40,77,156,146)).resize((348,207),Image.Resampling.NEAREST)
            page.paste(picture,(6+j*360,70),picture)
        frames.append(page)
    frames[0].save(QA/'comparacao_caminhada.gif',save_all=True,append_images=frames[1:],duration=timing(len(frames),30),loop=0,optimize=False)
    for prefix,fps,output in [('walk',30,'caminhada_no_mapa.gif'),('stop',30,'parada_no_mapa.gif')]:
        frames=[Image.open(path).convert('RGB') for path in sorted(QA.glob(prefix+'_[0-9][0-9][0-9].png'))]
        if not frames:raise SystemExit('Missing actual Godot captures: '+prefix)
        durations=timing(len(frames),fps)
        if prefix=='stop':durations[-1]+=800 # Hold the final planted guard for inspection.
        frames[0].save(QA/output,save_all=True,append_images=frames[1:],duration=durations,loop=0,optimize=False)
    print('Packaged studio comparison, real map walking and real closing steps')
if __name__=='__main__':run()
