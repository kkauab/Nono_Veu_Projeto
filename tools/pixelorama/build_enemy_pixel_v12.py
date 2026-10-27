"""Prepare64 separately drawn enemy poses; installed Pixelorama exports PNG.

Each archetype has ONE sampling scale for all16 cels. Foot registration only
translates cels. No squash, sprite rotation, per-pose scaling or interpolated
image morphing is used to imitate gait.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
import build_port_pixel_v7 as native

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/enemies_v12'
NAMES=['guard','runner','lancer','keeper']
HEIGHTS=[44,40,46,46]
CELL=128
PIVOT=(64,112)
POSES=['idle']+[f'walk_{i+1}' for i in range(8)]+['anticipation','acceleration','contact','follow_through','recovery','hurt','rest']
native.PALETTE += ['3b3542','5a4a56','826b73','734f39','aa7750']

def cleaned_selection(image, rect):
    crop=image.crop(rect).convert('RGBA')
    arr=np.array(crop)
    rgb=arr[:,:,:3].astype(np.int16)
    key=((rgb[:,:,0]>180)&(rgb[:,:,1]<85)&(rgb[:,:,2]<85))
    key|=((rgb[:,:,1]>180)&(rgb[:,:,0]<85)&(rgb[:,:,2]<85))
    key|=((rgb[:,:,0]>180)&(rgb[:,:,1]>180)&(rgb[:,:,2]<85))
    active=((arr[:,:,3]>=96)&~key).copy()
    height,width=active.shape
    parts=[]
    for sy,sx in zip(*np.nonzero(active)):
        if not active[sy,sx]:continue
        todo=[(int(sx),int(sy))];active[sy,sx]=False;points=[]
        while todo:
            x,y=todo.pop();points.append((x,y))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    nx,ny=x+dx,y+dy
                    if 0<=nx<width and 0<=ny<height and active[ny,nx]:
                        active[ny,nx]=False;todo.append((nx,ny))
        parts.append(points)
    main=max(parts,key=len)
    mask=np.zeros((height,width),np.uint8)
    for x,y in main:mask[y,x]=255
    arr[:,:,3]=mask
    return Image.fromarray(arr)

def build():
    ART.mkdir(parents=True,exist_ok=True)
    frames=[];tags=[];profiles={};registration={}
    for row,(name,target) in enumerate(zip(NAMES,HEIGHTS)):
        image=Image.open(ART/f'sources/{name}_generated.png').convert('RGBA')
        opposite=Image.open(ART/f'sources/{name}_opposite.png').convert('RGBA')
        assert opposite.size==image.size,(name,opposite.size,image.size)
        crops=[];anchors=[]
        for pose in range(16):
            col,line=pose%4,pose//4
            x0=round(col*image.width/4);y0=round(line*image.height/4)
            x1=round((col+1)*image.width/4);y1=round((line+1)*image.height/4)
            # Margin keeps the guard's extended blade crossing a grid gutter.
            rect=(x0-64,y0-12,x1+64,y1+12)
            crop=cleaned_selection(opposite if 5<=pose<=8 else image,rect)
            alpha=np.array(crop.getchannel('A'))
            foot_mask=alpha.copy()
            foot_mask[:round((y1-y0)*.60)+12,:]=0
            foot_mask[:,:64+40]=0;foot_mask[:,64+280:]=0
            ys,xs=np.nonzero(foot_mask)
            floor=int(ys.max())+1
            # Registered to a stable anatomical centre rather than the sword.
            anchors.append((64+(image.width/4)*.5,floor))
            crops.append(crop)
        idle=np.array(crops[0].getchannel('A'))
        head=idle[:100,64+75:64+220]
        head_top=int(np.nonzero(head)[0].min())
        source_height=anchors[0][1]-head_top
        factor=target/source_height
        profiles[name]={'row':row,'body_height':target,'source_scale':factor,'source_body_height':source_height}
        registration[name]=[]
        for pose,(crop,anchor) in enumerate(zip(crops,anchors)):
            width,height=round(crop.width*factor),round(crop.height*factor)
            small=native.palette_image(crop.resize((width,height),Image.Resampling.NEAREST))
            cel=Image.new('RGBA',(CELL,CELL))
            offset=(PIVOT[0]-round(anchor[0]*factor),PIVOT[1]-round(anchor[1]*factor))
            cel.paste(small,offset)
            bounds=cel.getchannel('A').getbbox()
            assert bounds and min(bounds[:2])>0 and bounds[2]<CELL and bounds[3]<CELL,(name,pose,bounds)
            frames.append(cel)
            registration[name].append({'pose':POSES[pose],'anchor':anchor,'bounds':bounds})
        tags.extend([native.tag(f'{name}_idle',row*16),native.tag(f'{name}_walk',row*16+1,row*16+8),native.tag(f'{name}_attack',row*16+9,row*16+13),native.tag(f'{name}_hurt',row*16+14),native.tag(f'{name}_rest',row*16+15)])
    native.native_project(ART/'port_enemies_v12.pxo',frames,tags,'Sentinelas — ciclo completo',16,fps=10)
    plan={'version':12,'texture':'res://assets/sprites/port_enemies_v12.png','canvas':[CELL,CELL],
          'atlas_size':[2048,512],'columns':16,'rows':4,'frames':64,'pivot':list(PIVOT),
          'profiles':profiles,'poses':POSES,'registration':registration,'palette':native.PALETTE,
          'source':'art/pixelorama/enemies_v12/port_enemies_v12.pxo',
          'provenance':'Four newly drawn16-pose sheets generated with the built-in image tool; opposite steps5–8 revised using a knee/ankle pose guide. One anatomical scale per archetype. PNG exported by installed Pixelorama.'}
    (ART/'export_plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2),encoding='utf8')
    # The contact sheet uses cropped128px cels at4x without any interpolation.
    contact=Image.new('RGBA',(16*80,4*120),'#14252c');draw=ImageDraw.Draw(contact)
    for i,cel in enumerate(frames):
        thumb=cel.crop((24,48,104,128))
        contact.alpha_composite(thumb,((i%16)*80,(i//16)*120+24))
        draw.text(((i%16)*80+4,(i//16)*120+6),f'{i//16}:{i%16}',fill='#eee0ba')
    contact.convert('RGB').save(ROOT/'qa/enemy_v12_contact.png')
    for animation,indices in [('walk',list(range(1,9))),('attack',[0,9,10,11,12,13,15,0])]:
        gif=[]
        for pose in indices:
            film=Image.new('RGBA',(4*160,210),'#14252c');d=ImageDraw.Draw(film)
            for row,name in enumerate(NAMES):
                cel=frames[row*16+pose]
                thumb=cel.crop((24,48,104,128)).resize((160,160),Image.Resampling.NEAREST)
                film.alpha_composite(thumb,(row*160,30))
                d.text((row*160+5,8),name,fill='#eee0ba')
                d.line([(row*160+10,158),(row*160+150,158)],fill='#31494b')
            gif.append(film.convert('RGB'))
        gif[0].save(ROOT/f'qa/enemy_v12_{animation}_preparation.gif',save_all=True,append_images=gif[1:],duration=110 if animation=='walk' else [350,180,85,90,110,170,220,350],loop=0,optimize=True)
    print(json.dumps({'project':str(ART/'port_enemies_v12.pxo'),'profiles':profiles,'frames':64},ensure_ascii=False))

if __name__=='__main__':build()
