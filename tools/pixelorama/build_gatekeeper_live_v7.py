"""Eight authored projections, live combat and human narrative cels.

Concept materials and the preferred face are retained. The weapon and grips
are rebuilt in each projection, never obtained by mirroring the whole sprite.
The editable project is full size; the runtime export trims empty margins.
"""
import copy,json,math,io
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from PIL import Image,ImageDraw,ImageChops
import build_gatekeeper_art_v4 as appearance
import build_gatekeeper_walk_v6 as walk
r=appearance.rig;b=r.b;ROOT=r.ROOT
ART=ROOT/'art/pixelorama/porteiro_live_v7';QA=ROOT/'qa/porteiro_combate'
STEM='porteiro_live_v7';VERSION=7
WALK_PREVIEW_SPEED=30
CELL=(192,192);PIVOT=(96,144)
DIRECTIONS={'right':0,'down_right':math.pi/4,'down':math.pi/2,'down_left':math.pi*.75,'left':math.pi,'up_left':math.pi*1.25,'up':math.pi*1.5,'up_right':math.pi*1.75}
FRONT=r.TEX.copy()
BACK=Image.new('RGBA',(160,160));ref=r.material.reference_body('back');BACK.alpha_composite(ref,(80-ref.width//2,83))

def triangle(out,tex,src,dst):
    a,c,d=dst;det=(c[1]-d[1])*(a[0]-d[0])+(d[0]-c[0])*(a[1]-d[1])
    if abs(det)<.01:return
    for y in range(max(0,math.floor(min(p[1] for p in dst))),min(CELL[1]-1,math.ceil(max(p[1] for p in dst)))+1):
        for x in range(max(0,math.floor(min(p[0] for p in dst))),min(CELL[0]-1,math.ceil(max(p[0] for p in dst)))+1):
            u=((c[1]-d[1])*(x-d[0])+(d[0]-c[0])*(y-d[1]))/det
            v=((d[1]-a[1])*(x-d[0])+(a[0]-d[0])*(y-d[1]))/det;w=1-u-v
            if min(u,v,w)<-.01:continue
            sx=round(src[0][0]*u+src[1][0]*v+src[2][0]*w);sy=round(src[0][1]*u+src[1][1]*v+src[2][1]*w)
            if 0<=sx<160 and 0<=sy<160:
                color=tex.getpixel((sx,sy))
                if color[3]:out.putpixel((x,y),color)
def quad(out,tex,src,dst):
    for ids in [(0,1,2),(0,2,3)]:triangle(out,tex,[src[i] for i in ids],[dst[i] for i in ids])
def limb(out,src,dst,widths):
    d=ImageDraw.Draw(out)
    for i in range(2):
        target=r.bone_quad(dst[i],dst[i+1],widths[i],widths[i+1]);d.polygon(target,fill='#292822')
        quad(out,FRONT,r.bone_quad(src[i],src[i+1],widths[i],widths[i+1]),target)
def rigid(out,tex,polygon,delta,mirror=False):
    mask=Image.new('L',(160,160));ImageDraw.Draw(mask).polygon(polygon,fill=255)
    piece=tex.copy();piece.putalpha(ImageChops.multiply(piece.getchannel('A'),mask))
    if mirror:
        box=piece.getbbox();piece=piece.crop(box).transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        out.alpha_composite(piece,(round(delta[0]+box[0]),round(delta[1]+box[1])))
    else:out.alpha_composite(piece,(round(delta[0]),round(delta[1])))
def weapon(out,grip,angle,theta,hem=0):
    forward=(math.cos(theta)*math.cos(angle),math.sin(angle)+math.sin(theta)*.7*math.cos(angle))
    cross=(-math.sin(angle)*math.cos(theta)+math.sin(theta)*.75,math.cos(angle)-math.sin(angle)*math.sin(theta)*.7)
    def point(u,v=0):return(round(grip[0]+forward[0]*u+cross[0]*v),round(grip[1]+forward[1]*u+cross[1]*v))
    d=ImageDraw.Draw(out)
    d.line([point(-27),point(34)],fill='#211c1b',width=3);d.line([point(-27,-1),point(34,-1)],fill='#a89673');d.line([point(-27),point(34)],fill='#604336')
    for at in [-24,-13,-4,9,20,28]:
        d.line([point(at,-1),point(at,1)],fill='#8b693c');d.point(point(at,-1),fill='#c9a461')
    # Same key-halberd planes as v4, projected at native pixel density.
    head=Image.new('RGBA',(32,32));hd=ImageDraw.Draw(head)
    outline=[(16,1),(21,2),(25,5),(28,10),(29,16),(27,22),(23,27),(17,30),(12,29),(15,27),(20,23),(23,18),(24,13),(22,8),(18,5),(15,5),(12,8),(10,8),(11,4)]
    hd.polygon(outline,fill='#534027');hd.line([(16,2),(21,3),(24,6),(27,11),(28,16),(26,22),(22,26),(17,28)],fill='#ac844a',width=2)
    hd.line([(17,3),(21,4),(24,7)],fill='#dfbf7e');hd.line([(26,17),(24,22),(21,25)],fill='#c9a461')
    hd.line([(12,7),(11,23)],fill='#705335',width=3);hd.line([(11,8),(10,22)],fill='#ac844a')
    for yy in [10,15,20]:hd.rectangle((3,yy,15,yy+2),fill='#705335');hd.line([(3,yy),(15,yy)],fill='#c9a461')
    head=head.resize((15,19),Image.Resampling.NEAREST)
    for y in range(19):
        for x in range(15):
            color=head.getpixel((x,y))
            if color[3]:
                px,py=point(31+18-y,x-6)
                if 0<=px<192 and 0<=py<192:out.putpixel((px,py),color)
    for at,length in [(13,6),(26,7),(34,4)]:
        x,y=point(at,2)
        for n in range(length):d.point((x+(hem if n>length//2 else 0),y+n),fill='#8b693c' if n%2 else '#ac844a')
        x+=hem;y+=length
        d.polygon([(x-1,y-1),(x,y-2),(x+1,y),(x+2,y+2),(x-2,y+2)],fill='#705335');d.line([(x-2,y+2),(x+2,y+2)],fill='#ac844a');d.point((x,y+3),fill='#c9a461')
    return point(12)
def render(p,theta,shaped=False):
    layers=[Image.new('RGBA',CELL) for i in range(4)];cloak,body,head,hands=layers
    c,s=math.cos(theta),math.sin(theta);back=s<-.3
    tex=BACK if back else FRONT
    width=.92+.08*abs(s);side=1 if s>=-.01 else -1
    f=(c,s*.7);lean=p['lean'];drop=p['drop'];hem=p.get('hem',0)
    lx,ly=lean*f[0],lean*f[1]
    shoulder_near=(96-(10 if shaped else 8)*width*side+lx,99+drop+ly-1.0*c)
    shoulder_far=(96+(8 if shaped else 5)*width*side+lx,101+drop+ly+1.0*c)
    near_base=(96-(6 if shaped else 4)*width*side,144)
    far_base=(96+(6 if shaped else 4)*width*side,144-3*c)
    hip={};knee={};feet={}
    crouch=p.get('crouch',False)
    for name,base,height in [('near',near_base,23),('far',far_base,22)]:
        if 'feet_plane' in p:q,lift,_=p['feet_plane'][name]
        else:
            old=p[name];base_x=76 if name=='near' else 84;base_y=140 if name=='near' else 137
            q=old[0]-base_x;lift=max(0,min(4,base_y+q*.2-old[1]))
        def project(q,h):return(base[0]+f[0]*q,base[1]+f[1]*q-h)
        hip_height=12 if crouch else height-drop*.45
        hp=(lean*.25,-hip_height)
        kn=(6,-3) if crouch else r.joint(hp,(q,-lift-2),11.5,12,-1)
        hip[name]=project(hp[0],-hp[1]);knee[name]=project(kn[0],-kn[1]);feet[name]=project(q,lift)
    # Mantle stays attached to shoulders, with material from the supplied back.
    lower_y=140 if not crouch else 141
    if shaped:
        left,right=sorted([shoulder_near,shoulder_far])
        cx=96+lx*.25
        points=[(left[0]-2,left[1]-1),(right[0]+2,right[1]-1),(right[0]+2,113+drop*.3),
                (right[0]+3+hem,128),(right[0]-1+hem,134),(cx+3,131),(cx-2+hem,139),
                (left[0]-5+hem,137),(left[0]-3,121),(left[0]-1,109+drop*.5)]
        mask=Image.new('L',CELL);ImageDraw.Draw(mask).polygon(points,fill=255)
        ImageDraw.Draw(cloak).polygon(points,fill='#42231e')
        quad(cloak,BACK,[(70,94),(87,94),(88,112),(69,112)],
             [(left[0]-2,left[1]-1),(right[0]+2,right[1]-1),(right[0]+2,117),(left[0]-2,116)])
        quad(cloak,BACK,[(69,110),(88,110),(90,137),(67,137)],
             [(left[0]-2,112),(right[0]+2,114),(right[0]+3+hem,137),(left[0]-5+hem,140)])
        cloak.putalpha(ImageChops.multiply(cloak.getchannel('A'),mask))
        cd=ImageDraw.Draw(cloak)
        # Broad folds follow shoulders/waist, with staggered torn ends, never
        # a same-width red cylinder running from the neck to both feet.
        cd.line([(left[0]+2,left[1]+4),(left[0]+3,113),(left[0]-1+hem,133)],fill='#6a352a')
        cd.line([(left[0]+5,left[1]+5),(cx-3,117),(cx-5+hem,135)],fill='#281e1b')
        cd.line([(right[0]-2,right[1]+3),(right[0]-3,115),(right[0]+hem,129)],fill='#713a2d')
        cd.line([(left[0]-3+hem,132),(left[0]-3+hem,136)],fill='#9a6f4d')
    else:
        quad(cloak,BACK,[(70,93),(87,94),(91,136),(67,137)],[(shoulder_near[0]-2,shoulder_near[1]-1),(shoulder_far[0]+1,shoulder_far[1]-1),(96+7*width+hem,lower_y),(96-17*width+hem,lower_y-2)])
    order=['far','near'] if side>0 else ['near','far']
    for name in order:
        src=[(84,115),(84,126),(87,137)] if name=='far' else [(75,115),(74,126),(74,138)]
        chain=[hip[name],knee[name],r.add(feet[name],(0,-2))]
        limb(body,src,chain,[2.8,2.3,1.8])
        polygon=[(83,133),(88,133),(91,136),(94,138),(91,140),(84,139)] if name=='far' else [(71,134),(76,134),(78,138),(77,140),(69,140),(70,138)]
        anchor=(87,139) if name=='far' else (74,140)
        rigid(body,FRONT,polygon,r.sub(feet[name],anchor))
    if shaped:ImageDraw.Draw(body).polygon([shoulder_near,shoulder_far,hip['far'],hip['near']],fill='#413a2d')
    quad(body,tex,[(72,94),(85,96),(85,116),(73,115)],[shoulder_near,shoulder_far,hip['far'],hip['near']])
    if shaped:
        hl,hr=sorted([hip['near'],hip['far']]);cx=(hl[0]+hr[0])*.5
        left_panel=[(hl[0]-1,hl[1]-3),(cx-1,hl[1]-3),(cx-2,132 if not crouch else 140),(hl[0]-3,130 if not crouch else 138)]
        right_panel=[(cx+1,hr[1]-3),(hr[0]+1,hr[1]-3),(hr[0]+3,132 if not crouch else 139),(cx+2,130 if not crouch else 138)]
        bd=ImageDraw.Draw(body)
        for panel in [left_panel,right_panel]:bd.polygon(panel,fill='#6d5b43')
        quad(body,FRONT,[(73,110),(78,110),(77,132),(71,132)],left_panel)
        quad(body,FRONT,[(79,110),(85,110),(87,130),(80,130)],right_panel)
        bd.line([(hl[0]-2,hl[1]-3),(hr[0]+2,hr[1]-3)],fill='#29231d',width=3)
        bd.line([(hl[0]-2,hl[1]-4),(hr[0]+2,hr[1]-4)],fill='#99774e')
        bd.rectangle((round(cx-1),round(hl[1]-5),round(cx+1),round(hl[1]-2)),fill='#a17b47')
    else:
        quad(body,tex,[(73,110),(85,110),(87,130),(71,132)],[(hip['near'][0]-2,hip['near'][1]-4),(hip['far'][0]+1,hip['far'][1]-4),(96+7*width,136 if not crouch else 139),(96-9*width,137 if not crouch else 140)])
    # Human face pixels are not repainted; a rear view uses the concept's hair.
    polygon=[(76,82),(84,82),(87,87),(85,94),(77,94),(73,89)] if back else [(77,82),(84,82),(87,86),(87,93),(83,98),(77,96),(74,90)]
    rigid(head,tex,polygon,(16+lx,4+drop+ly),mirror=(c<-.1 and not back))
    rear=(96+c*(p['rear'][0]-80),p['rear'][1]+4+s*(p['rear'][0]-80)*.7)
    a=p['angle'];lead=(rear[0]+12*math.cos(a)*c,rear[1]+12*(math.sin(a)+math.cos(a)*s*.7))
    for shoulder,hand,src in [(shoulder_far,lead,[(85,98),(88,102),(92,101)]),(shoulder_near,rear,[(72,96),(71,104),(72,112)])]:
        elbow=r.joint(shoulder,hand,8.5,9,1 if c>=0 else -1)
        if shaped:elbow=(elbow[0]+(-1.5 if shoulder[0]<96+lx else 1.5),elbow[1])
        limb(hands,src,[shoulder,elbow,hand],[2.2,1.7,1.2])
    weapon_layer=Image.new('RGBA',CELL) if shaped else hands
    if p.get('weapon_ground',False):weapon(weapon_layer,(96-10*c,142-10*s*.7),.04,theta)
    else:weapon(weapon_layer,rear,a,theta,hem)
    d=ImageDraw.Draw(hands)
    for hand in [rear,lead]:
        x,y=map(round,hand);d.line([(x-1,y),(x+1,y)],fill='#916a50');d.point((x-1,y-1),fill='#ab8663')
    if crouch and p.get('weapon_ground',False):
        x,y=map(round,rear);d.rectangle((x+1,y+1,x+3,y+5),fill='#8b693c');d.line([(x+1,y+1),(x+1,y+5)],fill='#c9a461');d.point((x+2,y+3),fill='#49332b')
    d=ImageDraw.Draw(body)
    if not back or shaped:
        x,y=round(shoulder_near[0]),round(shoulder_near[1]+1)
        d.polygon([(x-3,y-1),(x,y-3),(x+3,y-1),(x+2,y+2),(x-2,y+3)],fill='#534027');d.line([(x-3,y-1),(x,y-3),(x+3,y-1)],fill='#ac844a')
    if shaped:
        center=(hip['near'][0]+hip['far'][0])*.5
        for dx,length,dy in [(-5,3,1),(0,5,0),(5,4,2)]:
            x=round(center+dx);y=round((hip['near'][1]+hip['far'][1])*.5+dy)
            d.line([(x,y-3),(x,y)],fill='#705335')
            d.rectangle((x-1,y,x+1,y+length),fill='#59412d')
            d.line([(x-1,y),(x-1,y+length-1)],fill='#99774e')
            d.point((x,y+1),fill='#b29462');d.point((x,y+3),fill='#332b23')
    else:
        for i in range(4):
            x=round(hip['near'][0]+i*3);y=round(hip['near'][1])
            d.line([(x,y-2),(x,y)],fill='#705335');d.rectangle((x-1,y,x+1,y+3),fill='#8b693c');d.point((x,y+1),fill='#49332b')
    empty=Image.new('RGBA',CELL)
    if shaped:
        if back:return [weapon_layer,cloak,body,head,hands]
        hands.alpha_composite(weapon_layer)
        return [empty,cloak,body,head,hands]
    return [hands,cloak,body,head,empty] if back else [empty,cloak,body,head,hands]

def flatten(layers):
    image=Image.new('RGBA',CELL)
    for layer in layers:image.alpha_composite(layer)
    return image

def narrative(drop,lean=1,ground=True):
    p=r.pose(lean,drop,rear=(81,116+drop*.4) if ground else (77,104+drop*.4),angle=.1 if ground else .56)
    p.update(crouch=drop>=9,weapon_ground=ground)
    return p
def build():
    ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    original=json.loads((ROOT/'art/pixelorama/porteiro_v5/export_plan.json').read_text())
    walk_plan=json.loads((ROOT/'art/pixelorama/porteiro_walk_v6/export_plan.json').read_text())
    attacks=json.loads((ROOT/'resources/bosses/gatekeeper_attacks.json').read_text())
    clips={};times=[];meta=[];cels=[];tags=[];settles={}
    def append(clip,direction,poses,durations):
        start=len(cels);theta=DIRECTIONS[direction]
        for p,t in zip(poses,durations):
            cels.append(render(p,theta));times.append(t);meta.append({'clip':clip,'direction':direction,'pose':p})
        sequence=list(range(start,len(cels)))
        clips.setdefault(clip,{})[direction]=sequence
        tags.append({'name':clip+'_'+direction,'from':start+1,'to':len(cels),'color':'ac844aff'})
        return sequence
    for direction in DIRECTIONS:
        idle=append('idle',direction,[r.pose(),r.pose(0,1,rear=(77,105))],[.8,.7])
        append('walk',direction,walk_plan['frame_metadata'][:16],[22/WALK_PREVIEW_SPEED/16]*16)
        settles[direction]={}
        for phase in range(16):
            parts=append('settle_'+str(phase),direction,walk_plan['frame_metadata'][16+phase*2:18+phase*2],[.06,.065])
            settles[direction][str(phase)]=[clips['walk'][direction][phase],*parts,idle[0]]
        for id in attacks['order']:
            indices=original['clips'][id]['down_right'];append(id,direction,[original['frame_metadata'][i] for i in indices],attacks['attacks'][id]['seconds'])
        append('kneel',direction,[narrative(14)],[1.0])
        append('rise',direction,[narrative(dp,1,dp>3) for dp in [14,12,9,6,3,0]],[.25,.25,.3,.3,.25,.35])
        append('despair',direction,[narrative(dp,ln,dp>0) for dp,ln in zip([0,4,10,14,14,12,8,0],[0,1,-1,2,-2,1,0,0])],[.25,.3,.4,.5,.4,.4,.35,.3])
        defeat=[narrative(dp,ln,True) for dp,ln in zip([0,6,10,14,14,14,15,16],[0,1,2,2,1,0,1,2])]
        append('defeat',direction,defeat,[.2,.25,.3,.4,.5,.5,.6,1.0]);append('dead',direction,[defeat[-1]],[1.0])
        append('hurt',direction,[r.pose(-3,1),r.pose(-2,1),r.pose()],[.06,.06,.08])
        append('stagger',direction,[r.pose(ln,dp) for ln,dp in [(-3,2),(-2,3),(-1,2),(0,1)]],[.3,.3,.3,.3])
        append('idle_exhausted',direction,[r.pose(0,2),r.pose(1,3)],[.8,.8])
        append('idle_desperate',direction,[r.pose(-1,2),r.pose(1,2),r.pose(0,3)],[.3,.4,.5])
    palette=list(b.COLORS)
    if '292822' not in palette:palette.append('292822')
    plan={'version':VERSION,'canvas':list(CELL),'pivot':list(PIVOT),'frames':len(cels),'columns':40,'directions':list(DIRECTIONS),'clips':clips,'durations':times,'frame_metadata':meta,
      'frame_regions':[[i%40*192,i//40*192,192,192] for i in range(len(cels))], 'texture':f'res://assets/sprites/{STEM}.png','walk_stride':22.,'walk_start_phase':4,'settle_sequences':settles,'settle_seconds':[.035,.06,.065,.08],
      'contact_poses':{id:attacks['attacks'][id]['contact_pose'] for id in attacks['order']},'palette':palette,'source':f'art/pixelorama/{STEM}/{STEM}.pxo','reference_sha256':b.digest(b.SOURCE.read_bytes())}
    oldcell,oldlayers=b.CELL,b.LAYERS;b.CELL=CELL;b.LAYERS=['Arma posterior','Manto','Corpo','Rosto e cabelo','Arma e maos']
    native=b.native_blob(cels,tags,times,40);b.CELL=oldcell;b.LAYERS=oldlayers
    products={STEM+'.pxo':native,'export_plan.json':(json.dumps(plan,ensure_ascii=False,indent=2)+'\n').encode()}
    # Small fixed proof set, rather than duplicating thousands of source PNGs.
    for direction in DIRECTIONS:
        for clip in ['idle','walk','register','last_name','kneel','dead']:
            seq=clips[clip][direction];index=seq[min(len(seq)-1,5 if clip in attacks['order'] else 0)]
            products[f'proof/{clip}_{direction}.png']=b.encoded(flatten(cels[index]))
    lock=ART/'generated_hashes.json';old=json.loads(lock.read_text()) if lock.exists() else {}
    for name in products:
        path=ART/name
        if path.exists() and b.digest(path.read_bytes())!=old.get(name):raise SystemExit(f'Manual edit protected: {path}')
    for name,blob in products.items():
        path=ART/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(blob)
    lock.write_text(json.dumps({name:b.digest(blob) for name,blob in products.items()},indent=2)+'\n')
    board=Image.new('RGB',(1280,640),'#142026')
    for row,clip in enumerate(['idle','register','dead']):
        for col,direction in enumerate(DIRECTIONS):
            frame=Image.open(ART/f'proof/{clip}_{direction}.png');crop=frame.crop((28,70,172,188))
            board.paste(crop,(col*160,row*210+25),crop)
            b.text(ImageDraw.Draw(board),(col*160+4,row*210+155),direction,14)
    board.save(QA/f'oito_direcoes_v{VERSION}.png')
    print(json.dumps({'frames':len(cels),'directions':8,'source':str(ART/(STEM+'.pxo'))}))
if __name__=='__main__':build()
