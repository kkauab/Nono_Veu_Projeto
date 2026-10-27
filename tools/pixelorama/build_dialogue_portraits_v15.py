"""Import40 newly drawn COMPLETE portraits into editable Pixelorama cels.

This workflow does not draw or combine eye, mouth, brow or face patches. It only
selects complete cels, removes exterior key-colour fringe, registers the entire
portrait, samples the source sheet and applies a single shared native palette.
"""
import hashlib
import json
from collections import deque
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from build_port_pixel_v7 import native_project,tag

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/dialogue_v15'
OUT=ROOT/'assets/ui/dialogue_v15'
SIZE=(160,192)
EXPRESSIONS=['neutral','concerned','sad','resolute']
POSES=['rest','speech_small','speech_open','half_blink','closed_blink']
FACE_RECTS={'senu':[77,35,70,67],'fisherman':[35,35,75,70]}

def clean_complete(crop):
    arr=np.array(crop.convert('RGBA'))
    rgb=arr[:,:,:3].astype(np.int16)
    key=((rgb[:,:,0]>185)&(rgb[:,:,1]<85)&(rgb[:,:,2]<85))
    key|=((rgb[:,:,1]>185)&(rgb[:,:,0]<85)&(rgb[:,:,2]<85))
    key|=((rgb[:,:,0]>185)&(rgb[:,:,1]>180)&(rgb[:,:,2]<90))
    # A saturated pixel is removed only when connected to the outside of the
    # cutout. Interior colour islands (e.g. bronze highlights) are preserved.
    opaque=arr[:,:,3]>=128
    opening=~(opaque&~key)
    h,w=opening.shape
    exterior=np.zeros((h,w),bool)
    queue=deque()
    for x,y in [(x,0) for x in range(w)]+[(x,h-1) for x in range(w)]+[(0,y) for y in range(h)]+[(w-1,y) for y in range(h)]:
        if opening[y,x] and not exterior[y,x]:exterior[y,x]=True;queue.append((x,y))
    while queue:
        x,y=queue.popleft()
        for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]:
            nx,ny=x+dx,y+dy
            if 0<=nx<w and 0<=ny<h and opening[ny,nx] and not exterior[ny,nx]:
                exterior[ny,nx]=True;queue.append((nx,ny))
    active=opaque&(~key|~exterior)
    h,w=active.shape;seen=active.copy();best=[]
    for sy,sx in zip(*np.nonzero(seen)):
        if not seen[sy,sx]:continue
        todo=[(int(sx),int(sy))];seen[sy,sx]=False;component=[]
        while todo:
            x,y=todo.pop();component.append((x,y))
            for dx,dy in [(1,0),(-1,0),(0,1),(0,-1),(1,1),(-1,1),(1,-1),(-1,-1)]:
                nx,ny=x+dx,y+dy
                if 0<=nx<w and 0<=ny<h and seen[ny,nx]:
                    seen[ny,nx]=False;todo.append((nx,ny))
        if len(component)>len(best):best=component
    assert best,'Empty portrait selection'
    mask=np.zeros((h,w),np.uint8)
    for x,y in best:mask[y,x]=255
    arr[:,:,3]=mask
    arr[mask==0,:3]=0
    return Image.fromarray(arr)

def cell_rect(image,col,row,columns,rows):
    return (round(col*image.width/columns),round(row*image.height/rows),
            round((col+1)*image.width/columns),round((row+1)*image.height/rows))

def crown_anchor(crop):
    alpha=np.array(crop.getchannel('A'))
    ys,xs=np.nonzero(alpha)
    top=int(ys.min())
    band=(ys>=top+max(2,round(crop.height*.015)))&(ys<=top+round(crop.height*.095))
    return float(np.median(xs[band])),top

def prepare(name):
    original=Image.open(ART/f'sources/{name}_generated.png').convert('RGBA')
    revised=Image.open(ART/f'sources/{name}_half_generated.png').convert('RGBA') if name=='senu' else Image.open(ART/'sources/fisherman_half_four_generated.png').convert('RGBA')
    frames=[];records=[];target=None
    for index in range(20):
        pose,row=index%5,index//5
        is_half=pose==3
        if not is_half:
            source=original;rect=cell_rect(source,pose,row,5,4);file=f'{name}_generated.png'
        elif name=='senu':
            source=revised;rect=cell_rect(source,3,row,5,4);file='senu_half_generated.png'
        else:
            source=revised;rect=cell_rect(source,row%2,row//2,2,2);file='fisherman_half_four_generated.png'
        crop=clean_complete(source.crop(rect))
        factor=160/(source.width/(5 if not is_half or name=='senu' else 2))
        crown,top=crown_anchor(crop)
        if target is None:target=(round(crown*factor),14)
        # Registration translates the complete new drawing, never face parts.
        offset=(target[0]-round(crown*factor),target[1]-round(top*factor))
        sampled=crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.NEAREST)
        cel=Image.new('RGBA',SIZE);cel.paste(sampled,offset)
        frames.append(cel)
        records.append({'index':index,'expression':EXPRESSIONS[row],'pose':POSES[pose],
                        'source':file,'source_rect':rect,'sheet_scale':factor,'whole_cel_translation':offset})
    return frames,records

def build():
    ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    prepared={n:prepare(n) for n in ['senu','fisherman']}
    colorboard=Image.new('RGB',(800,1536))
    for row,(name,(frames,_)) in enumerate(prepared.items()):
        for i,cel in enumerate(frames):colorboard.paste(cel.convert('RGB'),(i%5*160,(row*4+i//5)*192))
    palette=colorboard.quantize(colors=128,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    manifest={'version':15,'canvas':[160,192],'atlas_size':[800,768],'columns':5,'rows':4,'frames':20,
              'expressions':EXPRESSIONS,'poses':POSES,'index':'expression*5 + pose',
              'source_type':'new complete generated portrait cels; no facial patch painting or recombination',
              'face_rects':FACE_RECTS,'textures':{},'registration':{},'native_cel_sha256':{}}
    for name,(frames,records) in prepared.items():
        mapped=[]
        for cel in frames:
            out=cel.convert('RGB').quantize(palette=palette,dither=Image.Dither.NONE).convert('RGBA')
            out.putalpha(cel.getchannel('A'));mapped.append(out)
        assert len({cel.tobytes() for cel in mapped})==20,(name,'duplicate complete drawing')
        tags=[tag(expression,r*5,r*5+4) for r,expression in enumerate(EXPRESSIONS)]
        native_project(ART/f'{name}.pxo',mapped,tags,'Retratos completos — novos sprites',5,fps=8)
        manifest['textures'][name]=f'res://assets/ui/dialogue_v15/{name}.png'
        manifest['registration'][name]=records
        manifest['native_cel_sha256'][name]=[hashlib.sha256(cel.tobytes()).hexdigest() for cel in mapped]
        board=Image.new('RGBA',(800,768),'#14252c')
        for i,cel in enumerate(mapped):board.alpha_composite(cel,(i%5*160,i//5*192))
        board.convert('RGB').save(ROOT/f'qa/dialogue_{name}_complete_v15.png')
        preview=[]
        for i in [0,1,2,1,0,3,4,3,0,2,1,0]:
            image=Image.new('RGBA',SIZE,'#14252c');image.alpha_composite(mapped[i])
            preview.append(image.resize((320,384),Image.Resampling.NEAREST).convert('RGB'))
        preview[0].save(ROOT/f'qa/dialogue_{name}_complete_v15.gif',save_all=True,append_images=preview[1:],duration=[500,180,140,200,400,70,110,70,400,160,200,650],loop=0,optimize=True)
    (ART/'export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    faces=Image.new('RGBA',(1200,480),'#14252c');d=ImageDraw.Draw(faces)
    for row,name in enumerate(['senu','fisherman']):
        with __import__('zipfile').ZipFile(ART/f'{name}.pxo') as archive:
            rect=FACE_RECTS[name];bounds=(rect[0],rect[1],rect[0]+rect[2],rect[1]+rect[3])
            for col,index in enumerate([0,1,2,3,4,10]):
                cel=Image.frombytes('RGBA',SIZE,archive.read(f'image_data/frames/{index+1}/layer_1'))
                face=cel.crop(bounds).resize((200,200),Image.Resampling.NEAREST)
                faces.alpha_composite(face,(col*200,row*240+15))
                d.text((col*200+3,row*240+220),name+' '+(POSES[index] if index<5 else 'sad'),fill='#eee0ba')
    faces.convert('RGB').save(ROOT/'qa/dialogue_new_complete_faces_v15.png')
    print(json.dumps({'projects':[str(ART/f'{n}.pxo') for n in prepared],'poses_each':20,'atlas':[800,768],'face_rects':FACE_RECTS}))

if __name__=='__main__':build()
