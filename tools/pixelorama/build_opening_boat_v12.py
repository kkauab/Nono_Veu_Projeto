"""Prepare layered native-resolution boat cels; Pixelorama exports delivery PNG.

The hull follows the same 2:1 axes as the quay. It is split at the front
gunwale so a passenger can stand inside instead of appearing pasted on top.
"""
import copy
import json
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw
import build_pixelorama_project as native

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/opening_boat_v12'
OUT = ROOT / 'assets/cinematics/rpg_v12'
SIZE = (128, 128)
PIVOT = (64, 112)
P = {
    'outline':'202e30', 'wood_black':'302e28', 'wood_dark':'493b2d',
    'wood_shadow':'604b34', 'wood':'7c603f', 'wood_warm':'927248',
    'wood_light':'ae8d58', 'wood_edge':'c7ab71', 'nail':'374044',
    'bronze':'a78b52', 'rope_dark':'6c6045', 'rope':'a69467',
    'rope_light':'cbb990', 'net':'657366', 'net_dark':'3e5652',
    'teal_dark':'2c4a4d', 'teal':'436565', 'teal_light':'709184',
    'foam_dark':'284c50', 'foam':'43686a', 'foam_light':'628884',
}
C = {name:'#'+value for name,value in P.items()}

def blank(): return Image.new('RGBA',SIZE)
def point(u,v,z=0): return (round(64+u-v),round(88+.5*u+.5*v-z))
def poly(draw,coords,color): draw.polygon(coords,fill=C[color])
def line(draw,coords,color,width=1): draw.line(coords,fill=C[color],width=width)
def project(coords,z): return [point(u,v,z) for u,v in coords]
def closed(points): return points+[points[0]]

FRONT = [(-46,0),(-36,9),(-18,14),(17,14),(36,9),(46,0)]
REAR = [(-46,0),(-36,-9),(-18,-14),(17,-14),(36,-9),(46,0)]
RIM = FRONT + list(reversed(REAR[1:-1]))
INNER = [(-41,0),(-33,6),(-17,10),(17,10),(33,6),(41,0),(33,-6),(17,-10),(-17,-10),(-33,-6)]

def hull_layers():
    layers=[blank() for _ in range(5)]
    d=ImageDraw.Draw(layers[0])
    # Rear exterior skin remains behind the passenger.
    rear_top=project(REAR,11)
    rear_low=project(REAR,1)
    poly(d,rear_low+list(reversed(rear_top)),'outline')
    poly(d,project(REAR,2)+list(reversed(project(REAR,10))),'wood_shadow')
    # A hollow dark well and individual longitudinal floor planks.
    poly(d,project(RIM,10),'outline')
    poly(d,project(INNER,8),'wood_black')
    floor=[(-35,0),(-28,5),(-14,8),(16,8),(29,4),(35,0),(28,-5),(14,-8),(-14,-8),(-28,-5)]
    poly(d,project(floor,3),'wood_shadow')
    for index,v in enumerate([-6,-2,2,6]):
        left=-30+abs(v)*.9; right=31-abs(v)*.85
        line(d,[point(left,v,3),point(right,v,3)],'wood_warm' if index%2==0 else 'wood')
        line(d,[point(left,v+1,3),point(right,v+1,3)],'wood_dark')
    for u in [-28,-14,0,14,28]:
        line(d,[point(u,-8,4),point(u,-9,8)],'wood_light')
        line(d,[point(u,8,4),point(u,10,8)],'wood_dark')
    for u,v in [(-21,-3),(-9,4),(10,0),(21,-4)]:
        line(d,[point(u,v,3),point(u+5,v,3)],'wood_light')
    # Far rail: the doubled line and infill establish timber thickness.
    far=ImageDraw.Draw(layers[1])
    line(far,project(REAR,11),'outline',4)
    line(far,project(REAR,11),'wood_light',2)
    line(far,project(REAR,12),'wood_edge')
    line(far,project([(-39,0),(-32,-6),(-17,-10),(17,-10),(32,-6),(39,0)],8),'wood_dark')
    # Two transverse seats. Each has a visible apron instead of a flat stroke.
    seats=ImageDraw.Draw(layers[2])
    for u in [-22,23]:
        top=[point(u-3,-11,9),point(u+3,-11,9),point(u+3,11,9),point(u-3,11,9)]
        apron=[top[2],top[3],(top[3][0],top[3][1]+3),(top[2][0],top[2][1]+3)]
        poly(seats,apron,'wood_dark')
        poly(seats,top,'wood_warm')
        line(seats,[top[0],top[3]],'wood_edge')
        line(seats,[top[0],top[1],top[2]],'wood_light')
        line(seats,[point(u,-10,9),point(u,10,9)],'wood_shadow')
        for v in [-9,9]: seats.point(point(u,v,10),fill=C['nail'])
    # Rope, mended net, rolled cloth and a securely stowed oar.
    gear=ImageDraw.Draw(layers[3])
    net=[point(-32,-2,9),point(-25,-7,9),point(-14,-6,8),point(-18,1,5),point(-27,5,5)]
    poly(gear,net,'net_dark')
    for u in [-30,-26,-22,-18]: line(gear,[point(u,-6,9),point(u+3,3,6)],'net')
    for v in [-4,0,3]: line(gear,[point(-30,v,8),point(-17,v-1,7)],'net')
    line(gear,closed(net),'rope_dark')
    rope_center=point(-36,1,10)
    for w,h in [(11,6),(7,4),(3,2)]:
        x,y=rope_center;gear.ellipse((x-w//2,y-h//2,x+w//2,y+h//2),outline=C['rope'])
    gear.point((rope_center[0]-3,rope_center[1]-2),fill=C['rope_light'])
    cloth=[point(29,-4,9),point(36,-2,10),point(32,4,11),point(25,3,10)]
    poly(gear,cloth,'teal_dark');line(gear,[cloth[0],cloth[1],cloth[2]],'teal')
    line(gear,[point(28,-2,11),point(32,1,11)],'teal_light')
    line(gear,[point(30,-3,11),point(28,4,11)],'rope')
    # Oar lays lengthwise in the far gunwale, clear of the standing position.
    blade=[point(-43,-8,14),point(-34,-8,14),point(-32,-5,14),point(-35,-3,14),point(-43,-5,14)]
    poly(gear,blade,'wood_dark')
    line(gear,[blade[0],blade[1],blade[2]],'wood_light')
    line(gear,[point(-34,-5,14),point(27,-9,13)],'outline',3)
    line(gear,[point(-34,-5,14),point(27,-9,13)],'wood_light')
    for u in [-7,15]:
        p=point(u,-9,14);gear.rectangle((p[0]-1,p[1]-1,p[0]+1,p[1]+2),fill=C['bronze'])
    # Tiny fastening details use stable positions, never random per-frame noise.
    finish=ImageDraw.Draw(layers[4])
    for u,v in [(-34,-8),(-17,-14),(16,-14),(34,-8)]:finish.point(point(u,v,12),fill=C['nail'])
    return layers

def front_layers():
    layers=[blank() for _ in range(5)]
    d=ImageDraw.Draw(layers[0])
    top=project(FRONT,11)
    bottom=project([(-46,0),(-35,8),(-17,12),(17,12),(35,8),(46,0)],-1)
    poly(d,top+list(reversed(bottom)),'outline')
    # Three strakes wrap around the curved hull, with staggered joints.
    for z,color in [(2,'wood_dark'),(5,'wood_shadow'),(8,'wood')]:
        upper=project(FRONT,z+2);lower=project(FRONT,z)
        poly(d,upper+list(reversed(lower)),color)
        line(d,upper,'wood_warm' if z<8 else 'wood_light')
    for u in [-32,-12,12,32]:
        v=12 if abs(u)<20 else 9
        line(d,[point(u,v,2),point(u,v,8)],'wood_dark')
        d.point(point(u,v,9),fill=C['nail'])
    rail=ImageDraw.Draw(layers[1])
    line(rail,top,'outline',4)
    line(rail,top,'wood_light',2)
    line(rail,project(FRONT,12),'wood_edge')
    line(rail,project([(-40,0),(-33,6),(-17,10),(17,10),(33,6),(40,0)],9),'wood_shadow')
    for u in [-25,0,25]:
        v=14 if u==0 else 11
        rail.point(point(u,v,12),fill=C['nail'])
    return layers

def water_layers(phase):
    layers=[blank() for _ in range(5)]
    d=ImageDraw.Draw(layers[4])
    for u0,u1,v in [(-38,-24,10),(-18,-4,15),(5,22,15),(29,39,9)]:
        shift=1 if phase==1 else 0
        a,b=point(u0,v,-3-shift),point(u1,v,-3-shift)
        line(d,[a,b],'foam_dark',3)
        line(d,[(a[0]+1,a[1]+1),(b[0]-1,b[1]+1)],'foam')
        if phase==0 and u0==-18:line(d,[(a[0]+4,a[1]+2),(a[0]+8,a[1]+4)],'foam_light')
    for u,v in [(-44,3),(43,2)]:
        x,y=point(u,v,-2)
        line(d,[(x-3,y),(x,y+1),(x+4,y+3)],'foam')
    return layers

def build():
    ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    layers=[hull_layers(),front_layers(),water_layers(0),water_layers(1)]
    names=['Fundo e tábuas','Bordas do casco','Bancos','Equipamento de pesca','Acabamentos e água']
    tags=[{'name':name,'from':index+1,'to':index+1,'color':'ae8d58ff'} for index,name in enumerate(['hull_back','hull_front','waterline_a','waterline_b'])]
    data=native.project_data(4,[1.0]*4,tags,False)
    data.update(size_x=128,size_y=128,fps=2,symmetry_points=[63.5,63.5])
    base=data['layers'][0]
    data['layers']=[dict(copy.deepcopy(base),name=name) for name in names]
    for frame in data['frames']:frame['cels']=[{'opacity':1.0,'z_index':0} for _ in names]
    data['export_profile']['lines_count']='4'
    with ZipFile(ART/'arrival_boat.pxo','w',ZIP_DEFLATED) as archive:
        archive.writestr('mimetype','application/x-pixelorama')
        archive.writestr('data.json',json.dumps(data,ensure_ascii=False))
        for index,frame in enumerate(layers):
            for number,cel in enumerate(frame):archive.writestr(f'image_data/frames/{index+1}/layer_{number+1}',cel.tobytes())
    flat=[]
    for frame in layers:
        cel=blank()
        for layer in frame:cel.alpha_composite(layer)
        flat.append(cel)
    combined=blank()
    for index in [2,0,1]:combined.alpha_composite(flat[index])
    preview=Image.new('RGBA',(512,256),'#193d45')
    for index,frame in enumerate(flat):preview.alpha_composite(frame,(128*index,0))
    preview.alpha_composite(combined,(192,128))
    preview.resize((1024,512),Image.Resampling.NEAREST).convert('RGB').save(ROOT/'qa/opening_boat_v12_contact.png')
    combined.resize((512,512),Image.Resampling.NEAREST).save(ROOT/'qa/opening_boat_v12_closeup.png')
    manifest={'version':12,'canvas':[128,128],'atlas_size':[512,128],'columns':4,'frames':4,'pivot':list(PIVOT),
      'order':['hull_back','hull_front','waterline_a','waterline_b'],'draw_order':['waterline','hull_back','passenger','hull_front'],
      'standing_anchor':[69,87],'boarding_anchor':[89,88],'mooring_anchor':[103,97],
      'standing_offset':[5,-25],'boarding_offset':[25,-24],'mooring_offset':[39,-15],
      'hull_axis':[2,1],'palette':P,'source':'art/pixelorama/opening_boat_v12/arrival_boat.pxo',
      'texture':'res://assets/cinematics/rpg_v12/arrival_boat.png','layers':names,
      'provenance':'Original native-resolution editable pixel art; final PNG exported by installed Pixelorama.'}
    (ART/'export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'source':str(ART/'arrival_boat.pxo'),'frames':4,'layers':len(names),'bounds':[f.getbbox() for f in flat]},ensure_ascii=False))

if __name__=='__main__':build()
