"""Anatomical pose guide for the opposing half of the enemy gait."""
from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/pixelorama/enemies_v12/sources/gait_guide.png'
im=Image.new('RGB',(1254,1254),'#f4eddb');d=ImageDraw.Draw(im)
try:font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',17)
except OSError:font=ImageFont.load_default()
# Red=near leg; blue=far leg. The opposite contacts switch their front/back
# position while keeping the pelvis, shoulders and face pointing down-right.
legs={
1:([(164,176),(193,223),(207,279)],[(140,176),(122,216),(111,261)]),
2:([(164,179),(183,230),(199,283)],[(140,179),(136,219),(130,248)]),
3:([(164,176),(173,231),(177,281)],[(140,176),(156,217),(156,254)]),
4:([(164,172),(156,224),(161,278)],[(140,172),(179,209),(193,251)]),
5:([(164,176),(145,217),(111,261)],[(140,176),(185,223),(207,279)]),
6:([(164,179),(154,219),(130,248)],[(140,179),(176,230),(199,283)]),
7:([(164,176),(175,217),(156,254)],[(140,176),(162,231),(177,281)]),
8:([(164,172),(191,209),(193,251)],[(140,172),(146,224),(161,278)]),
}
for i in range(16):
 x=round(i%4*1254/4);y=round(i//4*1254/4)
 d.rectangle((x,y,x+313,y+313),outline='#b8b29e')
 if i not in legs:
  d.text((x+20,y+18),f'{i} KEEP ORIGINAL',fill='#555555',font=font);continue
 d.text((x+8,y+8),f'{i} '+('NEAR FORWARD' if i<5 else 'FAR FORWARD'),fill='#30383d',font=font)
 def line(points,color,width):d.line([(x+a,y+b) for a,b in points],fill=color,width=width)
 def joint(p,color,r=5):
  a,b=p;d.ellipse((x+a-r,y+b-r,x+a+r,y+b+r),fill=color)
 # Neutral torso profile matches fixed three-quarter orientation.
 d.ellipse((x+138,y+36,x+190,y+89),fill='#ba9d76',outline='#524332',width=3)
 d.polygon([(x+186,y+60),(x+198,y+66),(x+186,y+71)],fill='#524332')
 d.polygon([(x+132,y+97),(x+176,y+93),(x+183,y+166),(x+140,y+179),(x+125,y+155)],fill='#9da4a5',outline='#4a565b',width=3)
 line([(140,177),(164,177)],'#4a565b',7)
 near,far=legs[i]
 line(far,'#2679b9',14)
 for p in far:joint(p,'#12578c')
 line([far[-1],(far[-1][0]+17,far[-1][1]+2)],'#2679b9',12)
 line(near,'#bf3b32',14)
 for p in near:joint(p,'#8b201c')
 line([near[-1],(near[-1][0]+17,near[-1][1]+2)],'#bf3b32',12)
 d.text((x+8,y+294),'red near / blue far',fill='#444444',font=font)
im.save(OUT)
print(OUT)
