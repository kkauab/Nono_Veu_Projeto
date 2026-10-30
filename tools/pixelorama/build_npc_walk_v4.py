"""Walking-only authored eight-phase cycles; never rewrites the approved v3 art.
Build once after ImageGen sources: python -B tools/pixelorama/build_npc_walk_v4.py
Probe selected sheets: --probe LOOK [LOOK ...]. Existing native edits are protected.
"""
import argparse
import hashlib
import io
import json
import math
from pathlib import Path
from statistics import median
from zipfile import ZipFile
from PIL import Image, ImageDraw
import build_npcs_v3 as native

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/npc_walk_v4'
QA=ROOT/'qa/npc_walk_v4'
LOOKS=native.LOOKS
CELL=(64,64)
PIVOT=(32,58)
PHASES=['contact_a','down_a','passing_a','up_a','contact_b','down_b','passing_b','up_b']
ORIGINALS=['assets/world/townsfolk_v3.png','assets/world/townsfolk_v3.json','assets/world/townsfolk_v3_manifest.json',
'art/pixelorama/npcs_v3/townsfolk_v3.pxo','assets/world/ankhet_v3.png','assets/world/ankhet_v3_manifest.json',
'art/pixelorama/npcs_v3/ankhet_v3.pxo','assets/world/interiors_v4.png','assets/world/interiors_v4_manifest.json',
'art/pixelorama/interiors_v4/interiors_v4.pxo']

def digest(value):return hashlib.sha256(value).hexdigest()
def write_json(path,value):path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf8')

def reference_frames():
    with ZipFile(ROOT/'art/pixelorama/npcs_v3/townsfolk_v3.pxo') as z:
        return {name:[Image.frombytes('RGBA',CELL,z.read(f'image_data/frames/{row*16+i+1}/layer_1')) for i in range(16)] for row,name in enumerate(LOOKS)}

def head_anchor(image,bounds,band):
    # The crown/face is independent from which foot currently supports weight.
    x0,y0,x1,y1=bounds
    mask=image.getchannel('A')
    xs=[]
    for y in range(y0,min(y1,y0+band)):
        for x in range(x0,x1):
            if mask.getpixel((x,y))>=128:xs.append(x+.5)
    return (median(xs),y0)

def complete_cells(image,columns=4,rows=4,indices=None):
    # Segment connected complete silhouettes rather than assuming every generated
    # row shares the exact same gutter. Tiny detached guide/key artifacts cannot
    # turn into a neighboring hand or an opaque background in a cropped cel.
    w,h=image.size
    active=bytearray(1 if a>=128 else 0 for a in image.getchannel('A').tobytes())
    bodies={}
    for start in range(w*h):
        if not active[start]:continue
        active[start]=0;todo=[start];cursor=0;left=w;top=h;right=bottom=0
        while cursor<len(todo):
            at=todo[cursor];cursor+=1;x=at%w;y=at//w
            left=min(left,x);right=max(right,x);top=min(top,y);bottom=max(bottom,y)
            for nxt in (at-1 if x else -1,at+1 if x+1<w else -1,at-w if y else -1,at+w if y+1<h else -1):
                if nxt>=0 and active[nxt]:active[nxt]=0;todo.append(nxt)
        if len(todo)<500:continue
        slot=(min(columns-1,int((left+right)/2*columns/w)),min(rows-1,int((top+bottom)/2*rows/h)))
        if slot not in bodies or len(todo)>len(bodies[slot][0]):bodies[slot]=(todo,(left,top,right+1,bottom+1))
    result=[]
    for i in (indices or list(range(16))):
        slot=(i%columns,i//columns)
        if slot not in bodies:raise ValueError(f'Missing complete walking silhouette {i}')
        pixels,bounds=bodies[slot];x0,y0,x1,y1=bounds
        if x0==0 or y0==0 or x1==w or y1==h:raise ValueError(f'Source walking pose {i} touches canvas edge')
        rect=(max(0,x0-2),max(0,y0-2),min(w,x1+2),min(h,y1+2))
        x,y,ex,ey=rect;cel=image.crop(rect);mask=Image.new('L',cel.size);raw=bytearray(cel.width*cel.height)
        for at in pixels:raw[(at//w-y)*cel.width+(at%w-x)]=255
        mask.frombytes(bytes(raw));cel.putalpha(mask)
        result.append((cel,(x0-x,y0-y,x1-x,y1-y),[x,y,ex-x,ey-y]))
    return result

def prepare(name,ref):
    path=ART/'sources'/f'{name}.png'
    image=Image.open(path).convert('RGBA')
    if image.getchannel('A').getextrema()[0]>=128:raise ValueError(f'{name}: no transparent background')
    settings_path=ART/'sources'/f'{name}.source.json'
    settings=json.loads(settings_path.read_text(encoding='utf-8-sig')) if settings_path.exists() else {}
    columns,rows=settings.get('grid',[4,4])
    cells=complete_cells(image,columns,rows,settings.get('indices'))
    standing=median(cells[i][1][3]-cells[i][1][1] for i in [0,4,8,12])
    target=ref[0].getbbox();height=target[3]-target[1]
    scale=height/standing
    colors=native.palette()
    frames=[];records=[]
    for i,(cel,bounds,rect) in enumerate(cells):
        # Uniform scale, head anchor and a controlled one-pixel rise. Do not
        # recenter the torso on a different supporting foot every other step.
        old=ref[0 if i<8 else 6];old_bounds=old.getbbox()
        old_anchor=head_anchor(old,old_bounds,8)
        anchor=head_anchor(cel,bounds,max(2,round(8/scale)))
        bob=[0,0,-1,-1,0,0,-1,-1][i%8]
        offset=(round(old_anchor[0]-anchor[0]*scale),round(old_anchor[1]+bob-anchor[1]*scale))
        frame=cel.transform(CELL,Image.Transform.AFFINE,(1/scale,0,-offset[0]/scale,0,1/scale,-offset[1]/scale),resample=Image.Resampling.NEAREST)
        frame=native.quantize(frame,colors)
        projected=[bounds[0]*scale+offset[0],bounds[1]*scale+offset[1],bounds[2]*scale+offset[0],bounds[3]*scale+offset[1]]
        if min(projected[:2])<-.5 or projected[2]>64.5 or projected[3]>64.5:raise ValueError(f'{name}/{i}: full pose clipped {projected}')
        frames.append(frame)
        records.append({'phase':PHASES[i%8],'mode':'walk' if i<8 else 'carry','source_rect':rect,'source_bounds':list(bounds),'source_head_anchor':list(anchor),'target_head_anchor':list(old_anchor),'bob':bob,'translation':list(offset),'scale':scale,'bounds':list(frame.getbbox()),'projected_bounds':projected})
    # The complete authored carrying poses keep hands/load physically joined.
    # Register one baseline per whole mode; never freeze a cargo block on new legs.
    for mode in range(2):
        offset_mode=mode*8
        floor_shift=round(PIVOT[1]-median(frames[offset_mode+i].getbbox()[3] for i in [0,1,4,5]))
        for phase in range(8):
            i=offset_mode+phase
            shifted=Image.new('RGBA',CELL)
            shifted.paste(frames[i],(0,floor_shift))
            frames[i]=shifted
            records[i]['cycle_baseline_shift']=floor_shift
            records[i]['upper_body']='complete authored pose, including hands and load'
            records[i]['bounds']=list(shifted.getbbox())
    record={'source':str(path.relative_to(ROOT)).replace('\\','/'),'sha256':digest(path.read_bytes()),'source_size':list(image.size),
    'uniform_scale':scale,'registration':'crown alignment; supporting foot never recenters torso','registrations':records}
    return frames,record

def previews(all_frames,old):
    QA.mkdir(parents=True,exist_ok=True)
    for name,frames in all_frames.items():
        board=Image.new('RGBA',(64*8,64*2),'#20383d')
        for i,frame in enumerate(frames):board.alpha_composite(frame,(i%8*64,i//8*64))
        board.resize((board.width*3,board.height*3),Image.Resampling.NEAREST).convert('RGB').save(QA/f'{name}_walk.png')
        loop=[]
        for tick in range(24):
            i=tick%8
            im=Image.new('RGBA',(64*4,88),'#20383d')
            labels=ImageDraw.Draw(im)
            for column,label in enumerate(['antes','agora','antes carga','agora carga']):labels.text((column*64+2,2),label,fill='#dbcfaa')
            for col,frame in enumerate([old[name][1+(tick//3)%4],frames[i],old[name][7+(tick//3)%4],frames[8+i]]):im.alpha_composite(frame,(col*64,16))
            loop.append(im.resize((im.width*4,im.height*4),Image.Resampling.NEAREST).convert('RGB'))
        loop[0].save(QA/f'{name}_comparison.gif',save_all=True,append_images=loop[1:],duration=100,loop=0,disposal=2)
    if len(all_frames)==len(LOOKS):
        loop=[]
        for tick in range(24):
            i=tick%8
            im=Image.new('RGBA',(64*6,84*4),'#20383d');d=ImageDraw.Draw(im)
            for j,name in enumerate(LOOKS):
                for mode in range(2):
                    row=j//6*2+mode;col=j%6
                    im.alpha_composite(all_frames[name][i+mode*8],(col*64,row*84))
                    d.text((col*64+2,row*84+65),name[:10],fill='#dbcfaa')
            loop.append(im.resize((im.width*3,im.height*3),Image.Resampling.NEAREST).convert('RGB'))
        loop[0].save(QA/'walk_all.gif',save_all=True,append_images=loop[1:],duration=100,loop=0,disposal=2)
        loop[0].save(QA/'walk_all.png')

def build(args):
    ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    old=reference_frames();selected=args.probe or LOOKS
    frames={};records={}
    for name in selected:
        frames[name],records[name]=prepare(name,old[name])
    previews(frames,old)
    if args.probe:
        write_json(QA/'probe_registration.json',records)
        print(json.dumps({'probes':selected}));return
    output=ART/'npc_walk_v4.pxo'
    if output.exists():raise FileExistsError('Walking project exists; export it to preserve manual edits. Rebuild into a new version.')
    original_hashes={'res://'+path:digest((ROOT/path).read_bytes()) for path in ORIGINALS}
    packed=[im for name in LOOKS for im in frames[name]]
    tags=[{'name':name+'_'+mode,'color':'609087ff','from':row*16+offset+1,'to':row*16+offset+8} for row,name in enumerate(LOOKS) for mode,offset in [('walk',0),('carry',8)]]
    native.pxo(output,packed,CELL,tags,8,'Passadas v4 · oito fases completas')
    plan={'version':4,'pixel_art':True,'runtime_scale':1,'canvas':list(CELL),'pivot':list(PIVOT),'columns':8,'frames':192,'phases':PHASES,'cycle_distance':24,'looks':LOOKS,
    'texture':'res://assets/world/npc_walk_v4.png','source':'res://art/pixelorama/npc_walk_v4/npc_walk_v4.pxo',
    'palette':[''.join(f'{c:02x}' for c in color) for color in native.palette()],
    'sprites':{name:{'walk':list(range(row*16,row*16+8)),'carry':list(range(row*16+8,row*16+16))} for row,name in enumerate(LOOKS)},
    'registrations':records,'original_files':original_hashes,'native_cel_sha256':[digest(im.tobytes()) for im in packed]}
    write_json(ART/'npc_walk_v4_export_plan.json',plan)
    for path,expected in original_hashes.items():
        assert digest((ROOT/path.removeprefix('res://')).read_bytes())==expected,path
    print(json.dumps({'native':str(output),'frames':192,'cycle_frames':8,'preserved_files':len(original_hashes)}))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--probe',nargs='+',choices=LOOKS)
    build(parser.parse_args())
