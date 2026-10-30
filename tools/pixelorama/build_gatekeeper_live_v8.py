"""Human silhouette: shoulders/waist, split tunic, visible arms and feet."""
import sys
from PIL import Image,ImageDraw,ImageFont
import build_gatekeeper_live_v7 as base

original_render=base.render
def render(p,theta):return original_render(p,theta,True)

base.render=render
base.VERSION=8;base.STEM='porteiro_live_v8'
base.ART=base.ROOT/'art/pixelorama/porteiro_live_v8'
base.QA=base.ROOT/'qa/porteiro_silhueta_v8'
for value in ['42231e','6a352a','281e1b','713a2d','9a6f4d','413a2d','6d5b43','29231d','99774e','a17b47','59412d','b29462','332b23']:
    if value not in base.b.COLORS:base.b.COLORS.append(value)
assert len(base.b.COLORS)<=256

def proof():
    base.QA.mkdir(parents=True,exist_ok=True)
    board=Image.new('RGB',(960,520),'#142026');d=ImageDraw.Draw(board)
    font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',17)
    for col,direction in enumerate(['down_right','up_left','up','left']):
        theta=base.DIRECTIONS[direction]
        for row,old in enumerate([True,False]):
            layers=original_render(base.r.pose(),theta) if old else render(base.r.pose(),theta)
            frame=base.flatten(layers).crop((65,80,130,148))
            page=frame.resize((195,204),Image.Resampling.NEAREST)
            board.paste(page,(col*240+20,row*260+38),page)
            d.text((col*240+15,row*260+10),('Anterior' if old else 'Revisado')+' · '+direction,font=font,fill='#dfc38c')
    board.save(base.QA/'comparacao_silhueta.png')
    print('Proof only; original V7 native/export preserved.')

if __name__=='__main__':
    if '--proof-only' in sys.argv:proof()
    else:base.build()
