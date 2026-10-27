"""Build one anatomically shared Senu body and separate equipment pose cells.

Pixelorama is responsible for the delivery PNG. This script only selects native
cels and metadata. No whole-character mesh/scale animation is generated.
"""
import argparse, copy, hashlib, json, math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import numpy as np
from PIL import Image,ImageDraw,ImageFilter,ImageChops
import build_motion_v5 as m
import build_motion_pose_guides as g
import build_pixelorama_project as v3
import build_attack_guides_v6 as ag
import build_senu_v4 as old

ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'art/pixelorama/senu/unified_v6_sources'
PROJECT=ROOT/'art/pixelorama/senu/senu_shared_v6.pxo'
PLAN=ROOT/'art/pixelorama/senu/export_plan_shared_v6.json'
MANIFEST=ROOT/'assets/sprites/senu_shared_v6_manifest.json'
CANVAS=(384,384); PIVOT=(192,280); SCALE=.26
DIRS=m.DIRS
HEAD={name:heading for name,heading in ag.DIRS}

def bbox(im):return m.alpha_bounds(im)

def select(im,col,row,rows=5):
    if rows==4:
        padded=Image.new('RGBA',(im.width,round(im.height*5/4)))
        padded.paste(im,(0,0));im=padded
    chosen=m.select_cell(im,col,row)
    # Weaponless art is one connected body. Keeping nearby disconnected bits
    # could accidentally retain boots/hair from the preceding poster row.
    image=chosen['image']
    chosen['image']=old.crop_selection(image,(0,0,image.width,image.height))
    b=bbox(chosen['image']);win=chosen['window'];cell=chosen['cell']
    chosen['bounds']=[b[0]+win[0]-cell[0],b[1]+win[1]-cell[1],b[2]+win[0]-cell[0],b[3]+win[1]-cell[1]]
    return chosen

def snap_hand(im,point,radius=15):
    a=np.asarray(im);x,y=point
    yy,xx=np.mgrid[0:384,0:384]
    warm=(a[:,:,3]>64)&(a[:,:,0]>a[:,:,1].astype(float)*1.17)&(a[:,:,1]>a[:,:,2].astype(float)*1.12)
    dist=(xx-x)**2+(yy-y)**2
    eligible=warm&(dist<=radius*radius)
    if not eligible.any():
        eligible=(a[:,:,3]>96)&(dist<=(radius*.55)**2)
    if not eligible.any():return [round(x,2),round(y,2)],False
    score=np.where(eligible,dist,np.inf)
    iy,ix=np.unravel_index(np.argmin(score),score.shape)
    return [float(ix),float(iy)],True

def primary_hand(original,body,selection,factor,root,corrected):
    # Object-removal differences find the original hilt, without guessing a
    # different hand position for Sword versus Daggers.
    reference=original.resize(body.size,Image.Resampling.NEAREST)
    old=np.asarray(reference);new=np.asarray(body)
    grown=np.asarray(body.getchannel('A').filter(ImageFilter.MaxFilter(9)))
    removed=((old[:,:,3]>=48)&(grown<24)).copy()
    cell=selection['cell']; window=selection['window']
    region=removed[window[1]:window[3],window[0]:window[2]]
    comps=[]
    for sy,sx in zip(*np.nonzero(region)):
        if not region[sy,sx]:continue
        pending=[(int(sx),int(sy))];region[sy,sx]=False;pts=[]
        while pending:
            x,y=pending.pop();pts.append((x+window[0]-cell[0],y+window[1]-cell[1]))
            for dy in (-1,0,1):
                for dx in (-1,0,1):
                    nx,ny=x+dx,y+dy
                    if 0<=nx<region.shape[1] and 0<=ny<region.shape[0] and region[ny,nx]:
                        region[ny,nx]=False;pending.append((nx,ny))
        if len(pts)>8:comps.append(pts)
    if comps:
        pts=max(comps,key=len)
        center=(root[0],root[1]-75/factor)
        point=min(pts,key=lambda p:(p[0]-center[0])**2+(p[1]-center[1])**2)
        x=PIVOT[0]+(point[0]-root[0])*factor
        y=PIVOT[1]+(point[1]-root[1])*factor
    else:x,y=PIVOT[0]-20,PIVOT[1]-58
    if corrected:x=384-x
    return [x,y]

def create_body():
    motions={};hands={};sources={};rowsmeta={}
    for state,file in [('walk','walk'),('run','run'),('dodge','roll')]:
        im=Image.open(SRC/f'{file}_body.png').convert('RGBA')
        original=Image.open(ROOT/f'art/pixelorama/senu/motion_v5_sources/sword_{file}_guided.png').convert('RGBA')
        sources[f'{file}_body.png']=hashlib.sha256((SRC/f'{file}_body.png').read_bytes()).hexdigest()
        motions[state]={};hands[state]={}
        for row,direction in enumerate(m.BASE_DIRS):
            sels=[select(im,i,row) for i in range(8)]
            if state=='walk':
                height=float(np.median([s['bounds'][3]-s['bounds'][1] for s in [sels[0],sels[4]]]))
                rowsmeta[direction]={'factor':145/height,'source_reference_height':height}
            factor=rowsmeta[direction]['factor']
            rootx=im.width/16 if state=='dodge' else float(np.median([m.head_x(s) for s in sels]))
            rooty=float(np.median([sels[i]['bounds'][3]-1 for i in ([0,7] if state=='dodge' else [0,4])]))
            corrected=(state=='walk' and direction=='up_right') or(state=='dodge' and direction=='down_right')
            drawings=[m.place(s,factor,(rootx,rooty),corrected) for s in sels]
            right=[]
            for s,draw in zip(sels,drawings):
                p=primary_hand(original,im,s,factor,(rootx,rooty),corrected)
                right.append(snap_hand(draw,p,20)[0])
            motions[state][direction]=drawings
            h=[];hx,hy=HEAD[direction]
            for i,draw in enumerate(drawings):
                rightp,vis=snap_hand(draw,right[i],7)
                other=right[(i+4)%8] if state!='dodge' else right[i]
                lead=0 if state=='dodge' else 10
                lift=0 if state=='dodge' else 8+10*abs(hy)
                leftp,leftvis=snap_hand(draw,(other[0]+hy*64+hx*lead,other[1]-hx*26-lift),15)
                h.append({'right':rightp,'left':leftp,'right_visible':vis,'left_visible':leftvis,
                          'hidden_during_tuck':state=='dodge' and i in [2,3,4,5]})
            hands[state][direction]=h
        for direction,base in m.MIRRORS.items():
            drawings=[]
            for draw in motions[state][base]:
                mirrored=Image.new('RGBA',CANVAS);mirrored.paste(draw.transpose(Image.Transpose.FLIP_LEFT_RIGHT),(1,0));drawings.append(mirrored)
            motions[state][direction]=drawings
            hands[state][direction]=[{**d,'right':[384-d['right'][0],d['right'][1]],'left':[384-d['left'][0],d['left'][1]]} for d in hands[state][base]]
    # The second frontal/back step reuses only the anatomically opposite drawn
    # lower-leg layer, preserving all upper-body/hand pixels.
    for direction in ['down','up']:
        motions['walk'][direction],_=m.opposite_front_step(motions['walk'][direction])
    return motions,hands,sources,rowsmeta

def attack_body(rowsmeta):
    path=SRC/'attack_body.png';im=Image.open(path).convert('RGBA')
    result={};hands={}
    for col,direction in enumerate(DIRS):
        sels=[select(im,col,row,4) for row in range(4)]
        factor=145/(sels[0]['bounds'][3]-sels[0]['bounds'][1])
        root=(float(np.median([m.head_x(s) for s in sels])),float(np.median([s['bounds'][3]-1 for s in sels])))
        result[direction]=[m.place(s,factor,root) for s in sels]
        anchors=[]
        for row,draw in enumerate(result[direction]):
            points=ag.pose(row);hx,hy=HEAD[direction];worldscale=145/2.20
            h={}
            for side,key in [('near','right'),('far','left')]:
                p=g.project(points[side]['wrist'],(hx,hy),PIVOT,worldscale)
                h[key],h[key+'_visible']=snap_hand(draw,p,21)
            h['hidden_during_tuck']=False;anchors.append(h)
        hands[direction]=anchors
    return result,hands,hashlib.sha256(path.read_bytes()).hexdigest()

def item_frame(source,anchor,factor):
    size=(max(1,round(source.width*factor)),max(1,round(source.height*factor)))
    source=source.resize(size,Image.Resampling.NEAREST)
    result=Image.new('RGBA',CANVAS)
    result.paste(source,(round(PIVOT[0]-anchor[0]*factor),round(PIVOT[1]-anchor[1]*factor)))
    return result

def build():
    motions,motionhands,sources,meta=create_body();attack,attackhands,sha=attack_body(meta);sources['attack_body.png']=sha
    frames=[];anchors=[];tags=[];durations=[];base={}
    def add(images,hands,name,seconds,loop=False):
        ids=list(range(len(frames),len(frames)+len(images)))
        frames.extend(images);anchors.extend(hands);durations.extend([12*seconds/len(images)]*len(images))
        tags.append({'name':name,'from':ids[0]+1,'to':ids[-1]+1,'color':'6db0a4ff'})
        return ids
    for state,length in [('walk',.44),('run',.4),('dodge',.32)]:
        base[state]={d:add(motions[state][d],motionhands[state][d],f'body_{state}_{d}',length) for d in DIRS}
    attackids={d:add(attack[d],attackhands[d],f'body_attack_{d}',.4) for d in DIRS}
    empty={'right':[192,220],'left':[192,220],'right_visible':False,'left_visible':False,'hidden_during_tuck':True}
    weapon_original=Image.open(ROOT/'art/pixelorama/senu/sources/weapons.png').convert('RGBA')
    kh=weapon_original.crop((92,18,362,366))
    kh_id=add([item_frame(kh,(49,291),.235)],[empty],'equipment_khopesh',1)[0]
    dagger_source=Image.open(SRC/'dagger.png').convert('RGBA')
    # Source handle center and tip are measured in the preserved original.
    dagger_id=add([item_frame(dagger_source,(dagger_source.width*.28,dagger_source.height*.52),.029)],[empty],'equipment_dagger',1)[0]
    # Golden effects from the supplied originals remain editable native cels.
    source_data=json.loads((ROOT/'tools/pixelorama/source_frames.json').read_text(encoding='utf8'))
    original_images={k:Image.open(ROOT/f'art/pixelorama/senu/sources/{k}.png').convert('RGBA') for k in v3.SOURCES}
    fx=[v3.frame_image(s,original_images) for s in source_data['extras']['slash_fx']]
    fxids=add(fx,[empty]*len(fx),'slash_fx',.3)
    variants={}
    for category in ['espada','leve']:
        clips={}
        for state in ['idle','walk','run','dodge','attack_light','attack_heavy','parry','hurt','death','power']:
            directions={}
            for d in DIRS:
                a=attackids[d];r=base['dodge'][d]
                if state in base:seq=base[state][d]
                elif state=='idle':seq=[a[3]]
                elif state=='attack_light':seq=[a[0],a[0],a[1],a[3]] if category=='espada' else [a[0],a[0],a[1],a[1],a[2],a[2],a[3],a[3]]
                elif state=='attack_heavy':seq=[a[0],a[0],a[1],a[1],a[3],a[3]] if category=='espada' else [a[0],a[1],a[1],a[2],a[3],a[3]]
                elif state=='parry':seq=[a[0],a[0],a[3],a[3]]
                elif state=='hurt':seq=[a[3],a[0],a[3]]
                elif state=='death':seq=[r[2],r[3],r[5]]
                else:seq=[a[0],a[0],a[1],a[1],a[3],a[3]]
                directions[d]=seq
            length={'idle':1,'walk':.44,'run':.4,'dodge':.32,'attack_light':.4 if category=='espada' else .29,'attack_heavy':.7,'parry':.25,'hurt':.22,'death':.5,'power':.72}[state]
            clips[state]={'fps':len(seq)/length,'loop':state in ['idle','walk','run'],'directions':directions}
            if state in ['walk','run']:clips[state]['cycle_duration']=length
        variants[category]={'clips':clips}
    native=v3.project_data(len(frames),durations,tags,True)
    native['layers'][0]['name']='Senu comum — corpo sem armas / anatomia única'
    native['export_profile']['lines_count']='16';native['symmetry_points']=[191.5,191.5]
    with ZipFile(PROJECT,'w',ZIP_DEFLATED,compresslevel=6) as z:
        z.writestr('mimetype','application/x-pixelorama');z.writestr('data.json',json.dumps(native,ensure_ascii=False))
        for i,im in enumerate(frames):
            assert bbox(im) is not None
            z.writestr(f'image_data/frames/{i+1}/layer_1',im.tobytes())
    data={'version':6,'model_id':'senu_shared_body_v6','modular_equipment':True,'canvas':list(CANVAS),'pivot':list(PIVOT),'game_scale':SCALE,
          'texture':'res://assets/sprites/senu_shared_v6.png','frame_count':len(frames),'frame_regions':[],
          'weapon_variants':variants,'clips':variants['espada']['clips'],'frame_hands':anchors,'source_hashes':sources,
          'extras':{'slash_fx':fxids},'equipment':{'espada':{'frame':kh_id,'base_angle':math.atan2(-281,199)},'leve':{'frame':dagger_id,'base_angle':0.0}},
          'anatomical_reference':meta,'notes':['One exact body is used for both weapons. Equipment sprites are separate native pose cells.',
          'Eight distinct attack directions are explicitly authored; no cardinal-to-diagonal aliases.',
          'Common anatomy preserves the original Senu proportions. Motion uses posed source drawings, not mesh/squash animation.']}
    for item in data['equipment'].values():
        b=bbox(frames[item['frame']]);r=[b[0],b[1],b[2]-b[0],b[3]-b[1]]
        item['sprite_bounds']=r;item['visible_rect']=r
    PLAN.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
    preview=Image.new('RGB',(1280,720),(18,30,35));d=ImageDraw.Draw(preview)
    for row,state in enumerate(['walk','run','dodge','attack']):
        for col,di in enumerate(DIRS):
            idx=base[state][di][0] if state!='attack' else attackids[di][1]
            crop=frames[idx].crop((112,120,272,294))
            preview.paste(crop,(col*160,row*180),crop)
            h=anchors[idx]
            for key,c in [('right',(230,190,90)),('left',(120,180,220))]:
                if h[key+'_visible']:
                    x,y=h[key];d.ellipse((col*160+x-114,row*180+y-122,col*160+x-110,row*180+y-118),fill=c)
            d.text((col*160+3,row*180+160),f'{state}/{di}',fill=(224,205,167))
    preview.save(ROOT/'qa/shared_senu_v6_body_contact.png')
    print(json.dumps({'project':str(PROJECT),'frames':len(frames),'tags':len(tags),'plan':str(PLAN)}))

def finalize():
    data=json.loads(PLAN.read_text(encoding='utf8'))
    native=json.loads((ROOT/'assets/sprites/senu_shared_v6.json').read_text(encoding='utf8'))
    with Image.open(ROOT/'assets/sprites/senu_shared_v6.png') as im:
        columns=im.width//384
        data['frame_regions']=[[i%columns*384,i//columns*384,384,384] for i in range(data['frame_count'])]
        data['texture_size']=list(im.size)
        for item in data['equipment'].values():
            x,y,w,h=data['frame_regions'][item['frame']]
            item['frame_region']=[x,y,w,h]
            b=bbox(im.crop((x,y,x+w,y+h)))
            item['sprite_bounds']=[b[0],b[1],b[2]-b[0],b[3]-b[1]]
            item['visible_rect']=item['sprite_bounds']
        for tag in native['tags']:
            for state in ['walk','run','dodge']:
                prefix=f'body_{state}_'
                if not tag['name'].startswith(prefix):continue
                direction=tag['name'][len(prefix):];hx,hy=HEAD[direction]
                ids=list(range(int(tag['from'])-1,int(tag['to'])))
                right=[data['frame_hands'][i]['right'] for i in ids]
                for n,index in enumerate(ids):
                    other=right[(n+4)%8] if state!='dodge' else right[n]
                    x,y,w,h=data['frame_regions'][index]
                    image=im.crop((x,y,x+w,y+h)).convert('RGBA')
                    lead=0 if state=='dodge' else 10
                    lift=0 if state=='dodge' else 8+10*abs(hy)
                    point,visible=snap_hand(image,(other[0]+hy*64+hx*lead,other[1]-hx*26-lift),15)
                    data['frame_hands'][index]['left']=point
                    data['frame_hands'][index]['left_visible']=visible
    data['frame_durations']=[float(f['duration'])/float(native['fps']) for f in native['frames']]
    data['exported_by']='Pixelorama '+native['pixelorama_version']+' (official CLI)'
    MANIFEST.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
    print('SHARED_SENU_V6_FINALIZED',data['frame_count'],data['texture_size'])

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--finalize',action='store_true');args=p.parse_args()
    finalize() if args.finalize else build()
