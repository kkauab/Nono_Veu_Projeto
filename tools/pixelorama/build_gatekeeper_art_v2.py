"""Second review: retain the concept's actual anatomy and textured bronze.

V1 face/weapon simplification was rejected by the player. This version samples
the original human face with no synthetic eyes/mouth or enlarged face polygon.
The crescent/key head is traced from the supplied concept, not a drawn glyph.
"""
import math
from PIL import Image, ImageDraw, ImageEnhance
import build_gatekeeper_art_v1 as base

base.VERSION=2
base.STEM='porteiro_v2'
base.ART=base.ROOT/'art/pixelorama/porteiro_v2'
base.QA=base.ROOT/'qa/porteiro_art_v2'

# Additional sampled ramps retain worn fabric and facial shadow. V1's 32-color
# cap erased anatomy; Senu's existing raster also retains material variation.
ref=Image.open(base.SOURCE).convert('RGB')
sample=ref.crop((1028,345,1138,682)).resize((110,337)).quantize(colors=64,dither=Image.Dither.NONE).convert('RGB')
rgb_bytes=sample.tobytes()
sampled=sorted({tuple(rgb_bytes[i:i+3]) for i in range(0,len(rgb_bytes),3)})
base.COLORS += ['%02x%02x%02x'%c for c in sampled if '%02x%02x%02x'%c not in base.COLORS]


def reference_body(name):
    source=Image.open(base.SOURCE).convert('RGBA')
    mask=Image.new('L',source.size)
    ImageDraw.Draw(mask).polygon(base.TRACES[name],fill=255)
    source.putalpha(mask)
    source=source.crop(mask.getbbox())
    small=source.resize((round(source.width*base.HEIGHT/source.height),base.HEIGHT),Image.Resampling.LANCZOS)
    # No face paint, no head enlargement and no independent head/body scaling.
    return base.quantize(ImageEnhance.Brightness(small).enhance(1.10))


def key_head():
    source=Image.open(base.SOURCE).convert('RGBA')
    mask=Image.new('L',source.size)
    d=ImageDraw.Draw(mask)
    d.polygon([(607,6),(628,0),(650,4),(674,23),(688,47),(696,74),
               (691,105),(675,135),(649,155),(632,160),(630,150),
               (648,136),(660,115),(668,91),(667,66),(659,46),
               (646,32),(629,26),(613,27)],fill=255)
    d.polygon([(602,22),(614,24),(604,154),(592,152)],fill=255)
    for points in [[(573,44),(633,48),(632,58),(571,54)],
                   [(571,64),(631,68),(630,78),(569,74)],
                   [(569,85),(628,88),(627,99),(567,95)]]:
        d.polygon(points,fill=255)
    source.putalpha(mask)
    # 13x17: blade has material volume and the actual crescent/key silhouette.
    source=source.crop((567,0,697,170)).resize((13,17),Image.Resampling.LANCZOS)
    return base.quantize(ImageEnhance.Brightness(source).enhance(1.2))


HEAD=key_head()


def weapon(image,grip,angle,sway=0):
    d=ImageDraw.Draw(image)
    direction=(math.cos(angle),math.sin(angle))
    normal=(-direction[1],direction[0])
    def point(u,v=0): return (round(grip[0]+direction[0]*u+normal[0]*v),round(grip[1]+direction[1]*u+normal[1]*v))
    d.line([point(-27),point(31)],fill='#322723',width=3)
    d.line([point(-27,-1),point(31,-1)],fill='#8a785a')
    d.line([point(-26),point(30)],fill='#514635')
    for at in (-24,-8,10,21,27):
        d.line([point(at,-1),point(at,1)],fill='#ac844a')
        d.point(point(at,-1),fill='#c9a461')
    # Texture mapped rigidly to the weapon; no palette-free smoothed rotations.
    for y in range(17):
        for x in range(13):
            color=HEAD.getpixel((x,y))
            if color[3]:
                px,py=point(30+(16-y),x-5)
                if 0<=px<160 and 0<=py<160: image.putpixel((px,py),color)
    for at,length in ((17,5),(27,4)):
        x,y=point(at,2)
        d.line([(x,y),(x+sway,y+length)],fill='#705335')
        x+=sway;y+=length
        d.polygon([(x,y-1),(x-1,y),(x-2,y+2),(x+1,y+2),(x+1,y)],fill='#705335')
        d.line([(x-1,y),(x-1,y+1)],fill='#ac844a')
        d.point((x,y+2),fill='#c9a461')
    # Small hand follows the same grip, rather than covering the shaft in a box.
    d.line([(grip[0]-1,grip[1]),(grip[0]+1,grip[1])],fill='#916a50')
    d.point((grip[0]-1,grip[1]-1),fill='#ab8663')


base.reference_body=reference_body
base.weapon=weapon


if __name__=='__main__': base.build()
