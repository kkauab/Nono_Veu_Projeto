from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/dialogue_v14/sources'
ART.mkdir(parents=True,exist_ok=True)
senu=Image.open(ROOT/'assets/ui/senu_portrait_v7.png').convert('RGBA')
senu.save(ART/'senu_base_original.png')
fisher=Image.open(ART/'fisherman_generated.png').convert('RGBA').resize((160,192),Image.Resampling.NEAREST)
fisher.putalpha(fisher.getchannel('A').point(lambda a:255 if a>=96 else 0))
# A single shared adaptive palette keeps the native eye and mouth edits crisp.
fisher.save(ART/'fisherman_base.png')
for name,image in [('senu',senu),('fisherman',fisher)]:
    crop=image.crop((20,30,110,110)).resize((900,800),Image.Resampling.NEAREST)
    background=Image.new('RGBA',crop.size,'#14252c');background.alpha_composite(crop)
    draw=ImageDraw.Draw(background)
    for x in range(0,90,5):
        draw.line([(x*10,0),(x*10,800)],fill='#60b4a140')
        draw.text((x*10+2,3),str(x+20),fill='#f2efe2')
    for y in range(0,80,5):
        draw.line([(0,y*10),(900,y*10)],fill='#60b4a140')
        draw.text((2,y*10+3),str(y+30),fill='#f2efe2')
    background.convert('RGB').save(ROOT/f'qa/{name}_face_landmarks_v14.png')
print('Native references and facial landmark boards ready')
