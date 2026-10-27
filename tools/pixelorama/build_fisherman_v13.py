"""Prepare fixed-scale fisherman cels for a real Pixelorama export.

The retained generated sheet is a style-guided source. All eight poses use one
anatomical scale; explicit waist/ground anchors avoid weapon/bag centering drift.
"""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import build_port_pixel_v7 as native

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/fisherman_v13'
OUT = ROOT / 'assets/cinematics/rpg_v12'
CELL, PIVOT = 128, (64, 112)
NAMES = ['idle', 'left_contact', 'left_pass', 'right_contact',
         'right_pass', 'talk', 'listen', 'farewell']
# (waist x, ground y) in each 384x512 source cell, selected on anatomy.
ANCHORS = [(228,464),(229,464),(206,464),(219,464),
           (235,434),(213,434),(202,434),(189,434)]
SCALE = 40 / 392

def build():
    ART.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    image = Image.open(ART/'sources/fisherman_guided.png').convert('RGBA')
    assert image.size == (1536,1024)
    # One shared, deterministic material palette, compatible with the port.
    native.PALETTE += ['563b2e','80533a','a7754e','c49969','d8b58a','8f8977']
    frames=[]
    for index, anchor in enumerate(ANCHORS):
        x,y = index%4*384,index//4*512
        crop=image.crop((x,y,x+384,y+512))
        crop.putalpha(crop.getchannel('A').point(lambda a:255 if a>=160 else 0))
        small=native.palette_image(crop.resize((round(384*SCALE),round(512*SCALE)),Image.Resampling.NEAREST))
        cel=Image.new('RGBA',(CELL,CELL))
        cel.paste(small,(PIVOT[0]-round(anchor[0]*SCALE),PIVOT[1]-round(anchor[1]*SCALE)))
        assert cel.getbbox(),index
        frames.append(cel)
    tags=[native.tag(name,i) for i,name in enumerate(NAMES)]
    native.native_project(ART/'fisherman.pxo',frames,tags,'Pescador — roupa, rosto e rede',4,fps=8)
    plan={'texture':'res://assets/cinematics/rpg_v12/fisherman.png','canvas':[128,128],
          'pivot':list(PIVOT),'columns':4,'frames':8,'body_height':40,'source_scale':SCALE,
          'anchors':ANCHORS,'poses':NAMES,'source':'art/pixelorama/fisherman_v13/sources/fisherman_guided.png',
          'native':'art/pixelorama/fisherman_v13/fisherman.pxo','palette':native.PALETTE}
    (ART/'export_plan.json').write_text(json.dumps(plan,indent=2,ensure_ascii=False),encoding='utf8')
    board=Image.new('RGBA',(512,256),'#14252c')
    for i,cel in enumerate(frames):board.alpha_composite(cel,(i%4*128,i//4*128))
    board.resize((1536,768),Image.Resampling.NEAREST).convert('RGB').save(ROOT/'qa/fisherman_v13_contact.png')
    print(json.dumps({'frames':8,'scale':SCALE,'bounds':[f.getbbox() for f in frames]}))

if __name__=='__main__':build()
