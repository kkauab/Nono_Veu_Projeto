"""Presence pass at the same anatomical scale: face, mantle and ceremonial bronze.

Uses only the player's concepts and native-pixel material/volume work. V3 acting
and ground registration stay intact; no runtime scale increase or paid API.
"""
from PIL import Image,ImageDraw
import math
import build_gatekeeper_art_v3 as rig

b=rig.b
rig.VERSION=4
rig.STEM='porteiro_v4'
rig.ART=rig.ROOT/'art/pixelorama/porteiro_v4'
rig.QA=rig.ROOT/'qa/porteiro_art_v4'
rig.PRESENCE_NOTES='Same 57px body and original v3 human face restored at player request; broader worn mantle, solid chipped ceremonial key-halberd and attached bronze nameplates. Art review only.'
SOURCE=Image.open(b.SOURCE).convert('RGBA')

# Retain subtle skin/cloth ramps instead of inventing a flat, enlarged face.
for bounds,count in [((923,54,1071,276),48),((879,341,1018,684),24)]:
    palette=SOURCE.crop(bounds).convert('RGB').quantize(colors=count,dither=Image.Dither.NONE).convert('RGB').tobytes()
    for color in sorted({tuple(palette[i:i+3]) for i in range(0,len(palette),3)}):
        value='%02x%02x%02x'%color
        if value not in b.COLORS:b.COLORS.append(value)
assert len(b.COLORS)<=256


# Keep rig.TEX and the head layer inherited from v3 byte-for-byte. The player
# preferred that face; this presence pass changes cloak and bronze only.

CLOAK=Image.new('RGBA',rig.CELL)
cloth=rig.material.reference_body('back')
CLOAK.alpha_composite(cloth,(80-cloth.width//2,83))


def ceremonial_weapon(image,grip,angle,sway=0):
    d=ImageDraw.Draw(image)
    axis=(math.cos(angle),math.sin(angle));normal=(-axis[1],axis[0])
    def point(u,v=0):return (round(grip[0]+axis[0]*u+normal[0]*v),round(grip[1]+axis[1]*u+normal[1]*v))
    d.line([point(-27),point(34)],fill='#211c1b',width=3)
    d.line([point(-27,-1),point(34,-1)],fill='#a89673')
    d.line([point(-27),point(34)],fill='#604336')
    for at in (-24,-13,-4,9,20,28):
        d.line([point(at,-1),point(at,1)],fill='#8b693c')
        d.point(point(at,-1),fill='#c9a461')
    # Broad, solid bronze planes, worn edges and key teeth. The form reads as
    # a physical head rather than a thin gold glyph over the floor.
    head=Image.new('RGBA',(32,32))
    hd=ImageDraw.Draw(head)
    outline=[(16,1),(21,2),(25,5),(28,10),(29,16),(27,22),(23,27),
             (17,30),(12,29),(15,27),(20,23),(23,18),(24,13),(22,8),
             (18,5),(15,5),(12,8),(10,8),(11,4)]
    hd.polygon(outline,fill='#534027')
    hd.line([(16,2),(21,3),(24,6),(27,11),(28,16),(26,22),(22,26),(17,28)],fill='#ac844a',width=2)
    hd.line([(17,3),(21,4),(24,7)],fill='#dfbf7e')
    hd.line([(26,17),(24,22),(21,25)],fill='#c9a461')
    hd.line([(12,7),(11,23)],fill='#705335',width=3)
    hd.line([(11,8),(10,22)],fill='#ac844a')
    for yy in (10,15,20):
        hd.rectangle((3,yy,15,yy+2),fill='#705335')
        hd.line([(3,yy),(15,yy)],fill='#c9a461')
        hd.point((14,yy+1),fill='#dfbf7e')
    # Compact native head, one source texel per world pixel, with a non-square
    # crescent silhouette. Deliberate 2px bronze thickness survives the map.
    head=head.resize((15,19),Image.Resampling.NEAREST)
    for y in range(19):
        for x in range(15):
            color=head.getpixel((x,y))
            if color[3]:
                px,py=point(31+(18-y),x-6)
                if 0<=px<160 and 0<=py<160:image.putpixel((px,py),color)
    # Short chains hang in gravity; attached bells have separate lip/clapper.
    for at,length in ((13,6),(26,7),(34,4)):
        x,y=point(at,2)
        for n in range(length):d.point((x+(sway if n>length//2 else 0),y+n),fill='#8b693c' if n%2 else '#ac844a')
        x+=sway;y+=length
        d.polygon([(x-1,y-1),(x,y-2),(x+1,y),(x+2,y+2),(x-2,y+2)],fill='#705335')
        d.line([(x-1,y),(x-1,y+1)],fill='#c9a461')
        d.line([(x-2,y+2),(x+2,y+2)],fill='#ac844a')
        d.point((x,y+3),fill='#c9a461')
    d.line([(grip[0]-1,grip[1]),(grip[0]+1,grip[1])],fill='#916a50')


old_render=rig.render
rig.material.weapon=ceremonial_weapon


def render(p):
    layers=old_render(p)
    lean,drop,hem=p['lean'],p['drop'],p['hem']
    # New mantle silhouette is attached to shoulders/pelvis; only the free hem
    # trails. It remains behind bare human arms and the weapon.
    cloak=Image.new('RGBA',rig.CELL)
    old=rig.TEX;rig.TEX=CLOAK
    rig.quad(cloak,[(72,93),(84,94),(86,112),(70,112)],
        [(71+lean,93+drop),(84+lean,94+drop),(79+lean*.3,113+drop*.5),(66+lean*.4,112+drop*.5)])
    rig.quad(cloak,[(70,110),(86,110),(91,136),(68,137)],
        [(66+lean*.4,112+drop*.5),(79+lean*.3,113+drop*.5),(78+hem,136),(63+hem,134)])
    rig.TEX=old
    layers[0]=cloak
    # Incomplete bronze on one shoulder, and four individually hung nameplates.
    d=ImageDraw.Draw(layers[1])
    x,y=round(72+lean),round(96+drop)
    d.polygon([(x-3,y-1),(x,y-3),(x+3,y-1),(x+2,y+2),(x-2,y+3)],fill='#534027')
    d.line([(x-3,y-1),(x,y-3),(x+3,y-1)],fill='#ac844a')
    d.point((x-1,y-2),fill='#c9a461')
    for index,(dx,dy) in enumerate([(-2,0),(2,1),(5,-1),(8,0)]):
        bx=round(75+lean*.35+dx)
        by=round(115+drop*.4+dy)
        d.line([(bx,by-2),(bx,by)],fill='#705335')
        d.rectangle((bx-1,by,bx+1,by+3),fill='#8b693c')
        d.line([(bx-1,by),(bx-1,by+2)],fill='#c9a461')
        d.point((bx,by+1),fill='#49332b')
        if index%2:d.point((bx+1,by+2),fill='#534027')
    return layers


rig.render=render


if __name__=='__main__':rig.build()
