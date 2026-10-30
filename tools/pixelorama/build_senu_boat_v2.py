"""Senu no barco v2: recortes do corpo real v6, poses em pixels e fontes PXO.

O casco vem do barco vazio v1 preservado. Não redesenha nem regenera esse original.
PNG final deve ser exportado pelo Pixelorama; --preview gera somente pranchas QA.
"""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import argparse, hashlib, json, math
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/pixelorama/senu/boat_v2'
QA = ROOT / 'qa/boat_senu'
DIRS = ['right','down_right','down','down_left','left','up_left','up','up_right']
BODY = ROOT / 'assets/sprites/senu_shared_v6.png'
BODY_META = ROOT / 'assets/sprites/senu_shared_v6_manifest.json'
HULL = ROOT / 'art/pixelorama/sea_v1/boat_v1.pxo'
INK = '#18262b'
SKIN = '#bd895c'
SKIN_LIGHT = '#d9ac76'
WOOD = '#846443'
GOLD = '#a27d50'


def save_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf8')


def body_views():
    data = json.loads(BODY_META.read_text(encoding='utf8'))
    atlas = Image.open(BODY).convert('RGBA')
    views = {}
    for name in DIRS:
        r = data['frame_regions'][data['clips']['idle']['directions'][name][0]]
        im = atlas.crop((r[0],r[1],r[0]+r[2],r[1]+r[3]))
        # Same .26 world scale, sampled once at the destination's native pixels.
        im = im.resize((100,100), Image.Resampling.NEAREST)
        im.putalpha(im.getchannel('A').point(lambda a: 255 if a >= 96 else 0))
        views[name] = im
    return views


def line(draw, points, color, width=1):
    draw.line([(round(x),round(y)) for x,y in points], fill=color, width=width)


def local_frame(view, lean=0, crouch=0, tuck=0, reach=0):
    """Torso/legs have separate fixed-size segments; never squeeze a whole sprite."""
    im = Image.new('RGBA',(96,96))
    # World feet at (48,76), waist at y59, source feet y73.
    # Source hem and legs are articulated beneath the unscaled upper body.
    waist = 55
    for side, x0, x1 in [(-1,32,50),(1,50,69)]:
        leg = view.crop((x0,waist,x1,74))
        angle = side*tuck + (reach if side > 0 else -reach*.3)
        rotated = leg.rotate(angle, Image.Resampling.NEAREST, expand=True, center=(leg.width/2,0))
        im.alpha_composite(rotated,(round(x0-2+(leg.width-rotated.width)/2),round(58-crouch)))
    upper = view.crop((25,25,75,56))
    im.alpha_composite(upper,(23+round(lean),28+round(crouch)))
    return im


def seated(view, theta, lean, recovery):
    """Articulate the real torso about the seated hip; no standing arms survive.

    Each pixel row moves around the hip. Head, scarf and cape keep their authored
    outlines; hands/forearms are separate drawn joints linked to the oar grips.
    """
    im = Image.new('RGBA',(96,80))
    hip=hull_point(theta,3,0,7.5)
    def shift(y):
        # Head/scarf translate as one rigid segment. The shoulder-to-hip strip
        # bends beneath it; inverse-height coverage avoids gaps between rows.
        weight=max(0,min(.65,(55-y)/11*.65))
        return (-lean*math.cos(theta)*weight,
                -lean*math.sin(theta)*.5*weight-recovery*weight)
    for y in range(30,64):
        dx,dy=shift(y)
        _,nextdy=shift(y+1)
        py0=round(hip[1]+y-55+dy)
        py1=round(hip[1]+y+1-55+nextdy)
        for x in range(29,72):
            color=view.getpixel((x,y))
            if not color[3]:continue
            r,g,b,a=color
            cape=b>r*1.05 and g>r*1.02
            if 44<=y<=54 and (x<47 or x>54) and not cape:
                continue
            px=round(hip[0]+x-50+dx)
            for py in range(py0,max(py0+1,py1)):
                if 0<=px<96 and 0<=py<80:im.putpixel((px,py),color)
    return im


def arm(im,shoulder,hand,theta,side,recovery):
    """Bent upper arm + forearm with skin highlight and bronze wrist cuff."""
    d=ImageDraw.Draw(im)
    # The elbow folds outward/upward as the handle reaches the ribs, then
    # lowers on extension. Its motion is independent of the torso's lean.
    elbow=((shoulder[0]+hand[0])*.5-side*math.sin(theta)*(2.5+recovery),
           (shoulder[1]+hand[1])*.5+1.5-recovery*1.4)
    line(d,[shoulder,elbow,hand],INK,3)
    line(d,[shoulder,elbow,hand],'#875735',2)
    line(d,[(shoulder[0]-.5,shoulder[1]-.5),(elbow[0]-.5,elbow[1]-.5),(hand[0],hand[1])],SKIN,2)
    line(d,[(elbow[0],elbow[1]-1),hand],SKIN_LIGHT,1)
    cuff=(elbow[0]*.25+hand[0]*.75,elbow[1]*.25+hand[1]*.75)
    d.point((round(cuff[0]),round(cuff[1])),fill='#c39e65')
    # Closed grip wraps over the shaft, rather than hovering beside it.
    d.rectangle((round(hand[0])-1,round(hand[1])-1,round(hand[0])+1,round(hand[1])),fill=SKIN)
    d.point((round(hand[0]),round(hand[1])-1),fill=SKIN_LIGHT)


def hull_point(theta,u,v,z=0):
    return (48+u*math.cos(theta)-v*math.sin(theta),54+(u*math.sin(theta)+v*math.cos(theta))*.5-z)


def half_width(u):
    return 8.5 * max(0,1-min(abs(u)/25,1)**2)**.55


def gunwale(u):
    return 5+8*min(abs(u)/25,1)**3.2


def oar(im,theta,side,angle,blade,splash):
    d = ImageDraw.Draw(im)
    du,dv = math.sin(math.radians(angle)),side*math.cos(math.radians(angle))
    v,z = side*half_width(-2),gunwale(-2)+1
    hand = hull_point(theta,-2-du*7,v-dv*7,z+3.5)
    root = hull_point(theta,-2+du*17,v+dv*17,z+(blade-z)*.78)
    tip = hull_point(theta,-2+du*22,v+dv*22,blade)
    line(d,[hand,root],INK,3);line(d,[hand,root],WOOD)
    dx,dy = tip[0]-root[0],tip[1]-root[1]
    mag=max(math.hypot(dx,dy),1)
    ax,ay=-dy/mag*1.5,dx/mag*1.5
    d.polygon([(round(x),round(y)) for x,y in [(root[0]+ax,root[1]+ay),(tip[0]+ax,tip[1]+ay),(tip[0]-ax,tip[1]-ay),(root[0]-ax,root[1]-ay)]],fill=GOLD if blade>=0 else '#3e7373')
    if splash:
        for x,y in [(-3,-1),(3,-1),(-2,-3),(2,-3),(0,-4)]:
            d.point((round(tip[0]+x),round(tip[1]+y)),fill='#eee0ba')
    return hand


def row_pose(index):
    if index == 0:
        return (0,1.5,0,False)
    t=(index-1)/8
    if t<.5:
        u=t/.5
        return (38+(-30-38)*u,-.5,6-11*u,index==1)
    u=(t-.5)/.5
    return (-30+(38+30)*u,.5+4*math.sin(u*math.pi),-5+11*u,False)


def native_project(name,frames,sprites,canvas,pivot,columns,layers=None):
    path=OUT/(name+'.pxo')
    if path.exists() and '--replace-generated' not in __import__('sys').argv:
        raise RuntimeError(f'{path} já existe. Exporte o PXO para preservar edições. Para reconstrução explícita use --replace-generated.')
    if layers is None: layers=[('Poses de Senu',frames)]
    metadata={
      'pixelorama_version':'v1.2.3-stable','pxo_version':7,'size_x':canvas[0],'size_y':canvas[1],'color_mode':5,
      'layers':[{'name':label,'type':0,'new_cels_linked':False,'visible':True,'locked':False,'blend_mode':0,'opacity':1.,'parent':-1,'effects':[]} for label,_ in layers],
      'frames':[{'cels':[{'opacity':1.,'z_index':0} for _ in layers],'duration':1.} for _ in frames],
      'tags':[{'name':key,'color':'6db0a4ff','from':v['frames'][0]+1,'to':v['frames'][-1]+1} for key,v in sprites.items()],
      'fps':8.,'current_frame':0,'current_layer':0,
      'export_profile':{'orientation':'1','lines_count':str(columns),'current_tab':'1','crop_mode':'0','resize':'100','interpolation':'0'}}
    with ZipFile(path,'w',ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/x-pixelorama')
        z.writestr('data.json',json.dumps(metadata))
        for li,(_,cels) in enumerate(layers,1):
            for i,im in enumerate(cels,1):z.writestr(f'image_data/frames/{i}/layer_{li}',im.tobytes())
        import io
        buf=io.BytesIO();frames[0].save(buf,format='PNG');z.writestr('preview.png',buf.getvalue())
    manifest={'version':2,'pixel_art':True,'canvas':canvas,'pivot':pivot,'columns':columns,'frames':len(frames),'game_scale':1.,
      'source':f'res://art/pixelorama/senu/boat_v2/{name}.pxo',
      'texture':f'res://assets/{"world" if name=="boat_v2" else "sprites"}/{name}.png','sprites':sprites,
      'provenance':{'body_sha256':hashlib.sha256(BODY.read_bytes()).hexdigest(),'hull_pxo_sha256':hashlib.sha256(HULL.read_bytes()).hexdigest()},
      'playback':'distance-independent row phase; transfer clips clamp to final pose'}
    save_json(OUT/(name+'_export_plan.json'),manifest)


def boat(views):
    with ZipFile(HULL) as z:
        data=json.loads(z.read('data.json'))
        originals=[Image.frombytes('RGBA',(96,80),z.read(f'image_data/frames/{i+1}/layer_1')) for i in range(len(data['frames']))]
    frames=[];backs=[];bodies=[];fronts=[];sprites={}
    for direction in range(16):
        theta=direction*math.tau/16
        name=f'boat_{direction:02d}';first=len(frames)
        empty=originals[direction*10+9]
        near=1 if math.cos(theta)>=0 else -1
        # Copy just the near hull surface from the preserved empty native cel.
        us=[-25+50*i/24 for i in range(25)]
        shape=[hull_point(theta,u,near*half_width(u),gunwale(u)) for u in us]
        shape += [hull_point(theta,u,near*half_width(u)*.8,0) for u in reversed(us)]
        mask=Image.new('L',(96,80));ImageDraw.Draw(mask).polygon([(round(x),round(y)) for x,y in shape],fill=255)
        rim=Image.new('RGBA',(96,80));rim.paste(empty,(0,0),mask)
        view=views[DIRS[((direction+8+1)//2)%8]]
        for fi in range(10):
            back=empty.copy();body=Image.new('RGBA',(96,80));front=Image.new('RGBA',(96,80))
            if fi!=9:
                angle,blade,lean,splash=row_pose(fi)
                far=-near
                oar(back,theta,far,angle,blade,splash)
                recovery=max(0.0,blade-.5)*.25
                body=seated(view,theta,lean,recovery)
                # Knees bend toward the stern and stay at the bench as the
                # upper body swings through the stroke. Cloth retains v6 hues.
                cloth=ImageDraw.Draw(body)
                for side in [-1,1]:
                    hip=hull_point(theta,3,side*2,6)
                    knee=hull_point(theta,-3+abs(lean)*.15,side*2.5,6.5)
                    line(cloth,[hip,knee],INK,4)
                    line(cloth,[hip,knee],'#c5b68b',3)
                    line(cloth,[(hip[0],hip[1]-1),(knee[0],knee[1]-1)],'#e1cf9b')
                # Far arm is part of the body layer. Front arm goes above the
                # near rim and the shaft; its hand is therefore always visible.
                for side in [far,near]:
                    du=math.sin(math.radians(angle));dv=side*math.cos(math.radians(angle))
                    hand=hull_point(theta,-2-du*7,side*half_width(-2)-dv*7,gunwale(-2)+3.5)
                    shoulder=hull_point(theta,3-lean*.65,side*3.5,18+recovery*.6)
                    if side==far:arm(body,shoulder,hand,theta,side,recovery)
                front.alpha_composite(rim)
                oar(front,theta,near,angle,blade,splash)
                side=near
                hand=hull_point(theta,-2-math.sin(math.radians(angle))*7,side*half_width(-2)-side*math.cos(math.radians(angle))*7,gunwale(-2)+3.5)
                shoulder=hull_point(theta,3-lean*.65,side*3.5,18+recovery*.6)
                arm(front,shoulder,hand,theta,side,recovery)
            composed=Image.alpha_composite(Image.alpha_composite(back,body),front)
            frames.append(composed);backs.append(back);bodies.append(body);fronts.append(front)
        sprites[name]={'frames':list(range(first,first+10)),'fps':8.4,'sequence':list(range(1,9)),'loop':True,
          'poses':['repouso','pegada','puxada 1','puxada 2','puxada 3','saída','retorno 1','retorno 2','retorno 3','vazio']}
    native_project('boat_v2',frames,sprites,[96,80],[48,54],10,
      [('Casco v1 preservado e remo distante',backs),('Senu real v6 - sentado e braços',bodies),('Borda próxima e remo próximo',fronts)])
    return frames


def transfers(views):
    frames=[];sprites={}
    for state in ['board','land']:
        for name in DIRS:
            first=len(frames);view=views[name]
            poses=([(0,1,0,0),(1,3,8,0),(1,1,26,-8),(0,0,18,14),(-1,3,8,0),(0,5,18,0)] if state=='board'
              else [(0,5,18,0),(1,3,10,0),(1,1,22,-10),(0,0,18,15),(-1,2,5,0),(0,0,0,0)])
            for args in poses:frames.append(local_frame(view,*args))
            sprites[state+'_'+name]={'frames':list(range(first,first+6)),'fps':12.5,'sequence':list(range(6)),'loop':False,
              'poses':['apoio','preparação','impulso','travessia','contato','assentar' if state=='board' else 'de pé']}
    native_project('senu_boat_v2',frames,sprites,[96,96],[48,76],8)
    return frames


def preview(name,frames,cell,columns,labels=None):
    sheet=Image.new('RGBA',(cell[0]*columns,cell[1]*math.ceil(len(frames)/columns)),(26,44,49,255))
    for i,im in enumerate(frames):sheet.alpha_composite(im,((i%columns)*cell[0],(i//columns)*cell[1]))
    sheet.resize((sheet.width*3,sheet.height*3),Image.Resampling.NEAREST).save(QA/(name+'.png'))


def main():
    OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    views=body_views();bf=boat(views);tf=transfers(views)
    preview('rowing', [bf[i*10+j] for i in [0,2,4,6,8,10,12,14] for j in range(9)],(96,80),9)
    preview('transfers',tf,(96,96),6)
    for d in [2,6,10,14]:
        seq=[bf[d*10+j] for j in [1,2,3,4,5,6,7,8]]
        bg=[]
        for im in seq:
            frame=Image.new('RGBA',im.size,(26,44,49,255));frame.alpha_composite(im);bg.append(frame.resize((384,320),Image.Resampling.NEAREST).convert('RGB'))
        bg[0].save(QA/f'rowing_{d:02d}.gif',save_all=True,append_images=bg[1:],duration=120,loop=0,disposal=2)
    print('BOAT_V2 native cels=160 layers=3; TRANSFER native cels=96; originals preserved')

if __name__=='__main__':main()
