"""Integrate fully drawn seated Senu keyframes; preserve v1/v2 and generated source.
Requires Pillow. Export the PXO via export_senu_boat_v3.ps1 after manual editing.
"""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import hashlib,json,math,io
from PIL import Image,ImageDraw,ImageOps
import build_senu_boat_v2 as old
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/pixelorama/senu/boat_v3'
SRC=OUT/'sources/rowing_generated.png'
QA=ROOT/'qa/boat_senu_v3'
DIRS=['right','down_right','down','down_left','left','up_left','up','up_right']
BASE=['down','down_right','right','up_right','up']
# Reviewed source-space closed-fist/handle anchors. Hidden rear grips are explicit.
GRIPS=json.loads((OUT/'oar_grips.json').read_text(encoding='utf8'))['grips']
HIP=[(96,156),(103,352),(106,548),(104,740),(100,931)]
SCALE=.17

def components(im):
    w,h=im.size;a=bytearray(1 if v>100 else 0 for v in im.getchannel('A').tobytes());items=[]
    for i in range(w*h):
        if not a[i]:continue
        todo=[i];a[i]=0;pts=[]
        while todo:
            k=todo.pop();pts.append(k);x=k%w;y=k//w
            for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if 0<=nx<w and 0<=ny<h and a[ny*w+nx]:a[ny*w+nx]=0;todo.append(ny*w+nx)
        if len(pts)>800:items.append((min(p%w for p in pts),min(p//w for p in pts),max(p%w for p in pts)+1,max(p//w for p in pts)+1))
    items.sort(key=lambda b:(round(b[1]/195),b[0]));assert len(items)==40,len(items)
    return items

def source_poses():
    im=Image.open(SRC).convert('RGBA');assert im.size==(1536,1024)
    boxes=components(im);views={};meta=[]
    for row,name in enumerate(BASE):
        poses=[]
        for phase in range(8):
            b=boxes[row*8+phase];crop=im.crop(b)
            crop.putalpha(crop.getchannel('A').point(lambda a:255 if a>100 else 0))
            # One shared sampling scale: never normalize each pose's height.
            small=crop.resize((round(crop.width*SCALE),round(crop.height*SCALE)),Image.Resampling.NEAREST)
            hip=(HIP[row][0]+phase*192,HIP[row][1])
            px=round((hip[0]-b[0])*SCALE);py=round((hip[1]-b[1])*SCALE)
            body=Image.new('RGBA',(96,80));body.alpha_composite(small,(48-px,47-py))
            hands=[]
            for x,y in GRIPS[row][phase]:
                # Same crop, effective NN scale, and destination origin as body.
                hx=48-px+round((x-b[0]+.5)*small.width/crop.width-.5)
                hy=47-py+round((y-b[1]+.5)*small.height/crop.height-.5)
                if name!='up':
                    candidates=[]
                    for sy in range(hy-1,hy+2):
                        for sx in range(hx-1,hx+2):
                            r,g,bl,a=body.getpixel((sx,sy))
                            if a>128 and r>g*1.10 and g>bl*1.05:
                                candidates.append(((sx-hx)**2+(sy-hy)**2,sx,sy))
                    if candidates:
                        _,hx,hy=min(candidates)
                hands.append((hx,hy))
            poses.append((body,hands))
            meta.append({'view':name,'phase':phase,'crop':b,'pelvis':hip,'grips':GRIPS[row][phase]})
        views[name]=poses
    for left,right in [('left','right'),('down_left','down_right'),('up_left','up_right')]:
        views[left]=[(ImageOps.mirror(im),[(95-x,y) for x,y in hands]) for im,hands in views[right]]
    (OUT/'selection.json').write_text(json.dumps({'scale':SCALE,'frames':meta},indent=2)+'\n')
    return views

def oar_geometry(hand,lock,recovery):
    # One rigid straight shaft through the grip and the oarlock. The pose's
    # actual hand height sets the angle; do not bend the shaft to lift the tip.
    dx=lock[0]-hand[0];dy=lock[1]-hand[1]
    length=math.hypot(dx,dy*2)
    if length<.5:
        dx=lock[0]-48;dy=(lock[1]-48)*.5
        length=max(.5,math.hypot(dx,dy*2))
    factor=22/length
    tip=(lock[0]+dx*factor,lock[1]+dy*factor)
    root=(lock[0]+dx*factor*.77,lock[1]+dy*factor*.77)
    # Short wooden butt remains behind the closed fist.
    unit=max(.5,math.hypot(dx,dy))
    butt=(hand[0]-dx/unit*1.5,hand[1]-dy/unit*1.5)
    return {'hand':hand,'lock':lock,'tip':tip,'root':root,'butt':butt,'recovery':recovery}


def oar(layer,geometry,splash,external_only=False):
    d=ImageDraw.Draw(layer)
    hand,lock,tip,root,butt=[geometry[k] for k in ['hand','lock','tip','root','butt']]
    start=lock if external_only else butt
    old.line(d,[start,tip],'#26312b',2)
    old.line(d,[start,tip],'#92734a')
    vx,vy=tip[0]-root[0],tip[1]-root[1];m=max(1,math.hypot(vx,vy));ax,ay=-vy/m*1.2,vx/m*1.2
    d.polygon([(round(x),round(y)) for x,y in [(root[0]+ax,root[1]+ay),(tip[0]+ax,tip[1]+ay),(tip[0]-ax,tip[1]-ay),(root[0]-ax,root[1]-ay)]],fill='#a28654' if geometry['recovery']>.2 else '#3e7373')
    if splash:
        for x,y in [(-2,-2),(2,-2),(-1,-4),(1,-3)]:d.point((round(tip[0]+x),round(tip[1]+y)),fill='#dbcfaa')


def write_project(frames,layers,sprites):
    dest=OUT/'boat_v3.pxo'
    if dest.exists() and '--replace-generated' not in __import__('sys').argv:raise RuntimeError('Use o exportador para preservar edições manuais; reconstrução exige --replace-generated')
    if dest.exists() and '--oars-only' in __import__('sys').argv:
        with ZipFile(dest) as previous:
            for index,im in enumerate(layers[1][1],1):
                assert previous.read(f'image_data/frames/{index}/layer_2')==im.tobytes(),f'Corpo alterado no quadro {index}; ajuste apenas os remos no PXO editado'
    data={'pixelorama_version':'v1.2.3-stable','pxo_version':7,'size_x':96,'size_y':80,'color_mode':5,
    'layers':[{'name':n,'type':0,'new_cels_linked':False,'visible':True,'locked':False,'blend_mode':0,'opacity':1.,'parent':-1,'effects':[]} for n,_ in layers],
    'frames':[{'cels':[{'opacity':1.,'z_index':0} for _ in layers],'duration':1.} for _ in frames],
    'tags':[{'name':n,'color':'6db0a4ff','from':s['frames'][0]+1,'to':s['frames'][-1]+1} for n,s in sprites.items()],
    'fps':8.4,'current_frame':0,'current_layer':1,'export_profile':{'orientation':'1','lines_count':'10','current_tab':'1','crop_mode':'0','resize':'100','interpolation':'0'}}
    with ZipFile(dest,'w',ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/x-pixelorama');z.writestr('data.json',json.dumps(data))
        for li,(_,images) in enumerate(layers,1):
            for i,im in enumerate(images,1):z.writestr(f'image_data/frames/{i}/layer_{li}',im.tobytes())
        b=io.BytesIO();frames[0].save(b,format='PNG');z.writestr('preview.png',b.getvalue())
    manifest={'version':3,'canvas':[96,80],'pivot':[48,54],'columns':10,'frames':160,'pixel_art':True,
    'source':'res://art/pixelorama/senu/boat_v3/boat_v3.pxo','texture':'res://assets/world/boat_v3.png','sprites':sprites,
    'provenance':{'generated_sha256':hashlib.sha256(SRC.read_bytes()).hexdigest(),'identity_reference':'sources/senu_identity_reference.png','prompt':'sources/PROMPT.md'},
    'body':'fully drawn seated poses, not line arms over standing torso','game_scale':1.}
    (OUT/'boat_v3_export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def main():
    if (OUT/'boat_v3.pxo').exists() and '--replace-generated' not in __import__('sys').argv:
        raise RuntimeError('Fonte existente: use o exportador; reconstrução intencional exige --replace-generated')
    QA.mkdir(parents=True,exist_ok=True);views=source_poses()
    with ZipFile(ROOT/'art/pixelorama/sea_v1/boat_v1.pxo') as z:
        empty=[Image.frombytes('RGBA',(96,80),z.read(f'image_data/frames/{i*10+10}/layer_1')) for i in range(16)]
    frames=[];backs=[];bodies=[];fronts=[];sprites={};contacts=[]
    for direction in range(16):
        theta=direction*math.tau/16;near=1 if math.cos(theta)>=0 else -1
        us=[-25+50*i/24 for i in range(25)]
        foreground=[u for u in us if u*math.sin(theta)+near*old.half_width(u)*math.cos(theta)>=3*math.sin(theta)-1]
        shape=[old.hull_point(theta,u,near*old.half_width(u),old.gunwale(u)) for u in foreground]
        shape += [old.hull_point(theta,u,near*old.half_width(u)*.8,0) for u in reversed(foreground)]
        mask=Image.new('L',(96,80));ImageDraw.Draw(mask).polygon([(round(x),round(y)) for x,y in shape],fill=255)
        rim=Image.new('RGBA',(96,80));rim.paste(empty[direction],(0,0),mask)
        name=DIRS[((direction+9)//2)%8];first=len(frames)
        for index in range(10):
            back=empty[direction].copy();body=Image.new('RGBA',(96,80));front=Image.new('RGBA',(96,80))
            if index!=9:
                phase=2 if index==0 else index-1
                source,hands=views[name][phase]
                seat=old.hull_point(theta,3,0,7)
                off=(round(seat[0]-48),round(seat[1]-47))
                body.alpha_composite(source,off);hands=[(x+off[0],y+off[1]) for x,y in hands]
                # Feet and hanging cloth sit inside the hull, never in the water.
                # Only the lower body is clipped; do not shrink the character.
                hull_alpha=empty[direction].getchannel('A')
                hip_y=47+off[1]
                for x in range(96):
                    ys=[y for y in range(80) if hull_alpha.getpixel((x,y))>0]
                    floor=max(ys)-1 if ys else hip_y
                    for y in range(max(hip_y,floor),80):
                        body.putpixel((x,y),(0,0,0,0))
                locks=[old.hull_point(theta,-2,side*old.half_width(-2),old.gunwale(-2)+1) for side in [-1,1]]
                # Anatomical order is stable through the full cycle; do not
                # swap hands based on closest distance in every frame.
                if name in ['left','down_left','up_left','up']:hands.reverse()
                recovery=[0,0,0,0,.5,2,2.5,1][phase]
                far_index=0 if near==1 else 1;near_index=1-far_index
                geometry=[oar_geometry(hands[i],locks[i],recovery) for i in range(2)]
                # Both inner handles sit behind the fists, bracers and cape.
                # The near outer shaft alone crosses above the near hull rim.
                for i in [far_index,near_index]:oar(back,geometry[i],index==1)
                front.alpha_composite(rim)
                oar(front,geometry[near_index],index==1,external_only=True)
                contacts.append({'frame':len(frames),'view':name,'phase':phase,'occluded':name=='up','oars':geometry})
            composed=Image.alpha_composite(Image.alpha_composite(back,body),front)
            frames.append(composed);backs.append(back);bodies.append(body);fronts.append(front)
        sprites[f'boat_{direction:02d}']={'frames':list(range(first,first+10)),'fps':8.4,'sequence':list(range(1,9)),'loop':True}
    (OUT/'oar_contacts.json').write_text(json.dumps(contacts,indent=2)+'\n')
    write_project(frames,[('Casco v1 e remo distante',backs),('Senu sentado - roupa e anatomia desenhadas',bodies),('Borda e remo próximo',fronts)],sprites)
    for title,images,cell,cols in [('bodies',[views[n][j][0] for n in BASE for j in range(8)],(96,80),8),('rowing',[frames[i*10+j] for i in [0,2,4,6,8,10,12,14] for j in range(9)],(96,80),9)]:
        sheet=Image.new('RGBA',(cell[0]*cols,cell[1]*math.ceil(len(images)/cols)),(30,44,48,255))
        for i,im in enumerate(images):sheet.alpha_composite(im,((i%cols)*cell[0],(i//cols)*cell[1]))
        sheet.resize((sheet.width*3,sheet.height*3),Image.Resampling.NEAREST).save(QA/(title+'.png'))
    gif=[]
    for phase in range(1,9):
        out=Image.new('RGBA',(576,480),(30,44,48,255))
        for i,direction in enumerate([0,6,8,14]):out.alpha_composite(frames[direction*10+phase].resize((288,240),Image.Resampling.NEAREST),((i%2)*288,(i//2)*240))
        gif.append(out.convert('RGB'))
    gif[0].save(QA/'senu_remando_v3.gif',save_all=True,append_images=gif[1:],duration=120,loop=0,disposal=2)
    print('SENU_BOAT_V3 frames=160; artist seated source=40; shared scale=.17; old sources preserved')
if __name__=='__main__':main()
