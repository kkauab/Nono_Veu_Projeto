"""Rear-view drapery/hair pass; preserve all five V8 front/side views exactly."""
import sys,math
from PIL import Image,ImageDraw,ImageChops,ImageFont
import build_gatekeeper_live_v8 as previous

base=previous.base
old_render=previous.render

def rear_mantle(p,theta):
    c,s=math.cos(theta),math.sin(theta)
    width=.92+.08*abs(s);lean=p['lean'];drop=p['drop']
    lx,ly=lean*c,lean*s*.7
    cx=96+lx*.35;top=99+drop+ly
    left=(96-8*width+lx,101+drop+ly+c)
    right=(96+10*width+lx,99+drop+ly-c)
    waist=119+drop*.35
    hem=p.get('hem',0)
    # Free cloth follows weight with a small lag, while neck/shoulders stay fixed.
    sway=math.sin(p.get('walk_phase',0)*math.tau/16)*.7 if 'walk_phase' in p else 0
    hem+=sway
    points=[(cx-2,top-1),(right[0]+1,right[1]+1),(right[0]+1,top+9),
            (cx+6,waist),(cx+10+hem,131),(cx+3+hem,133),(cx,127),
            (cx-4+hem,137),(cx-14+hem,138),(cx-10,waist+3),
            (left[0]-2,top+9),(left[0]-1,left[1]+1)]
    mask=Image.new('L',base.CELL);ImageDraw.Draw(mask).polygon(points,fill=255)
    cloth=Image.new('RGBA',base.CELL);d=ImageDraw.Draw(cloth)
    d.polygon(points,fill='#402021')
    base.quad(cloth,base.BACK,[(70,94),(87,94),(87,113),(70,113)],
              [(left[0]-1,left[1]+1),(right[0]+1,right[1]+1),(cx+6,waist),(cx-8,waist)])
    base.quad(cloth,base.BACK,[(69,111),(88,111),(91,137),(67,137)],
              [(cx-8,waist-2),(cx+6,waist-2),(cx+10+hem,136),(cx-14+hem,140)])
    cloth.putalpha(ImageChops.multiply(cloth.getchannel('A'),mask))
    d=ImageDraw.Draw(cloth)
    # Broken collar and diagonal shoulder folds describe a rounded, stooped
    # human back. The upper cloak is not a rectangular red shirt over a cape.
    d.line([(left[0],left[1]+2),(cx-3,top+5),(cx+3,top+4),(right[0],right[1]+2)],fill='#281e1b',width=2)
    d.line([(left[0]+1,left[1]+2),(cx-3,top+4),(cx+1,top+3)],fill='#785542')
    d.line([(cx-3,top+8),(cx-6,waist-2),(cx-9+hem,134)],fill='#2b191a',width=2)
    d.line([(cx-2,top+9),(cx-5,waist-1),(cx-8+hem,132)],fill='#713330')
    d.line([(right[0]-3,right[1]+7),(cx+3,waist-1),(cx+7+hem,129)],fill='#57282a')
    d.line([(cx+1,waist+1),(cx+3,127)],fill='#281e1b')
    d.line([(cx-12+hem,132),(cx-12+hem,136)],fill='#8a785a')
    # Frayed openings are transparent, with beige lining at a few torn edges.
    for x,y in [(cx-8+hem,136),(cx-4+hem,134),(cx+7+hem,130)]:
        d.line([(x,y-1),(x,y+1)],fill='#a89673')
    # Keep every newly drawn accent within the original cloth silhouette.
    cloth.putalpha(ImageChops.multiply(cloth.getchannel('A'),mask))
    return cloth,mask,(left,right,cx,top,lx,ly)

def rear_hair(p,theta,pose_info):
    left,right,cx,top,lx,ly=pose_info
    c=math.cos(theta)
    x=round(96+lx+c*.6);y=round(87+p['drop']+ly)
    head=Image.new('RGBA',base.CELL);d=ImageDraw.Draw(head)
    # A rounded skull, hanging hair and a small nape replace the pointed hood
    # inherited from the reduced concept. No changes to the preferred V3 face.
    d.polygon([(x-4,y+2),(x-2,y),(x+1,y),(x+4,y+2),(x+5,y+5),
               (x+4,y+9),(x+3,y+12),(x+2,y+14),(x,y+12),(x-3,y+13),
               (x-5,y+11),(x-6,y+7),(x-5,y+4)],fill='#211c1b')
    d.line([(x-4,y+5),(x-5,y+8),(x-4,y+12)],fill='#322723',width=2)
    d.line([(x+1,y+2),(x+3,y+4),(x+3,y+6)],fill='#49332b')
    d.line([(x+3,y+9),(x+2,y+11),(x+3,y+13)],fill='#322723')
    d.line([(x-2,y+2),(x-3,y+4)],fill='#343a35')
    d.line([(x-3,y+6),(x-4,y+8)],fill='#4b5147')
    d.point((x,y+1),fill='#49332b')
    d.point((x-3,y+11),fill='#4b5147')
    if abs(c)>.3:
        ear=x+(-4 if c<0 else 4)
        d.line([(ear,y+8),(ear,y+10)],fill='#785542')
        d.point((ear,y+8),fill='#ab8663')
    d.line([(x,y+12),(x+1,y+13)],fill='#604336')
    return head

def render(p,theta):
    layers=old_render(p,theta)
    if math.sin(theta)>=-.3:return layers
    cloth,mask,info=rear_mantle(p,theta)
    # The cape covers the back and belt rather than living behind a red torso.
    # Arms remain a distinct foreground layer, preserving every weapon grip.
    body=layers[2].copy()
    body.putalpha(ImageChops.multiply(body.getchannel('A'),ImageChops.invert(mask)))
    layers[1]=cloth;layers[2]=body;layers[3]=rear_hair(p,theta,info)
    return layers

base.render=render
base.VERSION=9;base.STEM='porteiro_live_v9';base.WALK_PREVIEW_SPEED=46
base.ART=base.ROOT/'art/pixelorama/porteiro_live_v9'
base.QA=base.ROOT/'qa/porteiro_refino_v9'

def proof():
    base.QA.mkdir(parents=True,exist_ok=True)
    board=Image.new('RGB',(960,520),'#142026');d=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',17)
    for col,direction in enumerate(['down_right','up_left','up','up_right']):
        for row,old in enumerate([True,False]):
            layers=old_render(base.r.pose(),base.DIRECTIONS[direction]) if old else render(base.r.pose(),base.DIRECTIONS[direction])
            frame=base.flatten(layers).crop((65,80,130,148))
            page=frame.resize((195,204),Image.Resampling.NEAREST)
            board.paste(page,(col*240+20,row*260+38),page)
            d.text((col*240+15,row*260+10),('V8' if old else 'V9')+' · '+direction,font=font,fill='#dfc38c')
    board.save(base.QA/'comparacao_costas.png')
    print('Rear-view proof only; V8 sources untouched.')

if __name__=='__main__':
    if '--proof-only' in sys.argv:proof()
    else:base.build()
