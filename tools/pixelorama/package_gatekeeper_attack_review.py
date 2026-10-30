"""Package captured Godot frames, without synthesizing gameplay effects."""
from pathlib import Path
import json,re
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
QA=ROOT/'qa/porteiro_attacks_v5'
DATA=json.loads((ROOT/'resources/bosses/gatekeeper_attacks.json').read_text(encoding='utf8'))

def run():
    sheet=Image.new('RGB',(960,3*270),'#142026')
    draw=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',15)
    selected={'charge':30,'sweep':28,'register':36,'bell':50,'warning':48,'echo_charge':52,'names':58,'chains':36,'last_name':54}
    montage=[];montage_times=[]
    for i,key in enumerate(DATA['order']):
        paths=sorted(p for p in QA.glob(key+'_*.png') if re.fullmatch(re.escape(key)+r'_\d{3}\.png',p.name))
        if not paths:raise SystemExit('Missing actual Godot frames: '+key)
        frames=[Image.open(p).convert('RGB') for p in paths]
        # GIF time uses 10ms ticks: 70/60/70 preserves the recorded 15fps.
        times=[60 if n%3==1 else 70 for n in range(len(frames))]
        frames[0].save(QA/f'{key}_arena.gif',save_all=True,append_images=frames[1:],duration=times,loop=0,optimize=False)
        for frame in frames:
            page=Image.new('RGB',(640,456),'#142026')
            page.paste(frame,(0,36))
            ImageDraw.Draw(page).text((12,9),f'{i+1}. '+DATA['attacks'][key]['name'],font=font,fill='#dfc38c')
            montage.append(page)
        montage_times.extend(times)
        picture=Image.open(QA/f'{key}_{selected[key]:03}.png').convert('RGB')
        # Nearest-neighbor thumbnail of the actual capture; no repainted effects.
        picture=picture.resize((320,210),Image.Resampling.NEAREST)
        x=i%3*320;y=i//3*270
        sheet.paste(picture,(x,y+35))
        draw.text((x+8,y+8),f'{i+1}. '+DATA['attacks'][key]['name'],font=font,fill='#dfc38c')
        draw.text((x+8,y+245),'FASE '+str(DATA['attacks'][key]['phase']),font=font,fill='#a6a090')
    sheet.save(QA/'nove_golpes_arena.png')
    montage[0].save(QA/'nove_golpes_arena.gif',save_all=True,append_images=montage[1:],duration=montage_times,loop=0,optimize=False)
    walk=[Image.open(p).convert('RGB') for p in sorted(QA.glob('walk_[0-9][0-9][0-9].png'))]
    if walk:walk[0].save(QA/'caminhada_no_mapa.gif',save_all=True,append_images=walk[1:],duration=[60 if n%3==1 else 70 for n in range(len(walk))],loop=0,optimize=False)
    print('Packaged nine GIFs from actual Godot frames and one contact sheet')

if __name__=='__main__':run()
