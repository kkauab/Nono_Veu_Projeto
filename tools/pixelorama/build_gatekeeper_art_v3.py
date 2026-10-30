"""Art-review pilot: full-body articulated walk and two-handed spear thrust.

Local, original-project materials only. Concept textures are mapped to authored
anatomical poses; feet/head use rigid cels. No API, Senu edits or enemy redraw.
The lance enemy's load/contact/recovery sequence is the acting reference.
"""
import copy
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import build_gatekeeper_art_v2 as material

b=material.base
ROOT=b.ROOT
ART=ROOT/'art/pixelorama/porteiro_v3'
QA=ROOT/'qa/porteiro_art_v3'
CELL=(160,160)
PIVOT=(80,140)
VERSION=3
STEM='porteiro_v3'
PRESENCE_NOTES='Full-body acting pilot with the lance enemy as acting reference.'
LAYER_NAMES=['Manto posterior','Corpo articulado','Rosto humano','Chave-lança e mãos']
TEX=Image.new('RGBA',CELL)
body=material.reference_body('front')
TEX.alpha_composite(body,(80-body.width//2,140-57))


def add(a,c):return (a[0]+c[0],a[1]+c[1])
def sub(a,c):return (a[0]-c[0],a[1]-c[1])
def mul(a,n):return (a[0]*n,a[1]*n)
def rounded(a):return [round(a[0]),round(a[1])]


def triangle(out,src,dst):
    """Inverse affine sampling on the native pixel grid, no antialiasing."""
    a,c,d=dst
    determinant=(c[1]-d[1])*(a[0]-d[0])+(d[0]-c[0])*(a[1]-d[1])
    if abs(determinant)<.01:return
    x0=max(0,math.floor(min(p[0] for p in dst)))
    x1=min(159,math.ceil(max(p[0] for p in dst)))
    y0=max(0,math.floor(min(p[1] for p in dst)))
    y1=min(159,math.ceil(max(p[1] for p in dst)))
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            w0=((c[1]-d[1])*(x-d[0])+(d[0]-c[0])*(y-d[1]))/determinant
            w1=((d[1]-a[1])*(x-d[0])+(a[0]-d[0])*(y-d[1]))/determinant
            w2=1-w0-w1
            if min(w0,w1,w2)<-.01:continue
            u=round(src[0][0]*w0+src[1][0]*w1+src[2][0]*w2)
            v=round(src[0][1]*w0+src[1][1]*w1+src[2][1]*w2)
            if 0<=u<160 and 0<=v<160:
                color=TEX.getpixel((u,v))
                if color[3]:out.putpixel((x,y),color)


def quad(out,src,dst):
    for ids in [(0,1,2),(0,2,3)]:triangle(out,[src[i] for i in ids],[dst[i] for i in ids])


def bone_quad(a,c,wa,wc):
    delta=sub(c,a);length=math.hypot(*delta)
    normal=(-delta[1]/length,delta[0]/length)
    return [add(a,mul(normal,wa)),sub(a,mul(normal,wa)),sub(c,mul(normal,wc)),add(c,mul(normal,wc))]


def joint(start,end,l1,l2,bend=1):
    delta=sub(end,start);distance=math.hypot(*delta)
    distance=max(.01,min(distance,l1+l2-.01))
    axis=mul(delta,1/max(.01,math.hypot(*delta)))
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    across=math.sqrt(max(0,l1*l1-along*along))*bend
    return add(start,add(mul(axis,along),mul((-axis[1],axis[0]),across)))


def limb(out,source,target,widths):
    for i in range(2):
        quad(out,bone_quad(source[i],source[i+1],widths[i],widths[i+1]),
             bone_quad(target[i],target[i+1],widths[i],widths[i+1]))


def rigid_piece(out,polygon,delta):
    mask=Image.new('L',CELL)
    ImageDraw.Draw(mask).polygon(polygon,fill=255)
    piece=TEX.copy()
    piece.putalpha(ImageChops.multiply(piece.getchannel('A'),mask))
    out.alpha_composite(piece,(round(delta[0]),round(delta[1])))


def pose(lean=0,drop=0,near=(76,140),far=(84,137),rear=(77,104),angle=.56,hem=0,name='guard'):
    forward=(math.cos(angle),math.sin(angle))
    lead=add(rear,mul(forward,12))
    sh_near=(72+lean,95+drop)
    sh_far=(85+lean,97+drop)
    hip_near=(75+lean*.25,115+drop*.35)
    hip_far=(84+lean*.25,115+drop*.35)
    ankle_near=add(near,(0,-2))
    ankle_far=add(far,(0,-2))
    knee_near=joint(hip_near,ankle_near,12.5,13,-1)
    knee_far=joint(hip_far,ankle_far,12.5,13,-1)
    elbow_near=joint(sh_near,rear,8.5,9,1)
    elbow_far=joint(sh_far,lead,8,9,1)
    return dict(name=name,lean=lean,drop=drop,near=list(near),far=list(far),rear=rounded(rear),
                lead=rounded(lead),angle=angle,hem=hem,
                sh_near=sh_near,sh_far=sh_far,hip_near=hip_near,hip_far=hip_far,
                knee_near=knee_near,knee_far=knee_far,elbow_near=elbow_near,elbow_far=elbow_far)


def render(p):
    layers=[Image.new('RGBA',CELL) for _ in LAYER_NAMES]
    cloak,body,head,arms=layers
    ln,dp=p['lean'],p['drop']
    # A connected cloth mesh, attached to shoulder/hip and trailing behind steps.
    source=[(71,93),(76,96),(75,115),(69,132),(67,136),(69,114)]
    dest=[(71+ln,93+dp),(76+ln,96+dp),(75+ln*.25,115+dp*.35),
          (69+p['hem'],132),(67+p['hem'],136),(69+ln*.4,114+dp*.5)]
    for ids in [(0,1,2),(0,2,5),(5,2,3),(5,3,4)]:triangle(cloak,[source[i] for i in ids],[dest[i] for i in ids])
    # Rear leg and near leg are separately bent, not translated hem strips.
    for side,hip,knee,foot,src in [
        ('far',p['hip_far'],p['knee_far'],p['far'],[(84,115),(84,126),(87,137)]),
        ('near',p['hip_near'],p['knee_near'],p['near'],[(75,115),(74,126),(74,138)])]:
        ankle=add(foot,(0,-2))
        limb(body,src,[hip,knee,ankle],[3.1,2.6,1.9])
        if side=='near':
            rigid_piece(body,[(71,134),(76,134),(78,138),(77,140),(69,140),(70,138)],sub(foot,(74,140)))
        else:
            rigid_piece(body,[(83,133),(88,133),(91,136),(94,138),(91,140),(84,139)],sub(foot,(87,139)))
    # Underarm region is supplied by the same tunic texture, then limbs cross it.
    quad(body,[(72,94),(85,96),(85,116),(73,115)],
         [(72+ln,94+dp),(85+ln,96+dp),(85+ln*.25,116+dp*.35),(73+ln*.25,115+dp*.35)])
    # Torn front tunic follows pelvis/knees without resizing the whole actor.
    quad(body,[(73,110),(85,110),(87,130),(71,132)],
         [(73+ln*.5,110+dp*.6),(85+ln*.5,110+dp*.6),
          (85+(p['knee_far'][0]-84)*.3,130+dp*.2),
          (72+(p['knee_near'][0]-74)*.35,132+dp*.2)])
    # Narrow scarf and chest folds stay on the shoulders.
    quad(body,[(73,94),(85,95),(84,108),(74,106)],
         [(73+ln,94+dp),(85+ln,95+dp),(84+ln*.65,108+dp*.75),(74+ln*.65,106+dp*.75)])
    # Human face is a rigid piece of the concept. No eyes/mouth are painted on.
    rigid_piece(head,[(77,82),(84,82),(87,86),(87,93),(83,98),(77,96),(74,90)],(ln,dp))
    # Rear/far and front/near arms retain source flesh, torn sleeves and scars.
    limb(arms,[(85,98),(88,102),(92,101)],
         [p['sh_far'],p['elbow_far'],p['lead']],[2.1,1.7,1.2])
    limb(arms,[(72,96),(71,104),(72,112)],
         [p['sh_near'],p['elbow_near'],p['rear']],[2.4,1.8,1.2])
    # The weapon is threaded through both palms at a constant 12px grip span.
    material.weapon(arms,tuple(p['rear']),p['angle'],p['hem'])
    hands=ImageDraw.Draw(arms)
    for x,y in [p['rear'],p['lead']]:
        hands.line([(x-1,y),(x+1,y)],fill='#916a50')
        hands.point((x-1,y-1),fill='#ab8663')
    return layers


def poses():
    guard=pose()
    walk=[]
    near_x=[82,79,76,73,70,73,77,81]
    far_x=[78,81,85,89,91,88,84,81]
    near_lift=[0,0,0,0,0,2,4,2]
    far_lift=[0,2,4,2,0,0,0,0]
    gait_names=['contact_a','weight_a','passing_a','rise_a','contact_b','weight_b','passing_b','rise_b']
    for i in range(8):
        near=(near_x[i],round(140+.45*(near_x[i]-76)-near_lift[i]))
        far=(far_x[i],round(137+.45*(far_x[i]-84)-far_lift[i]))
        drop=[0,1,0,-1,0,1,0,-1][i]
        rear=(77+round(math.sin(i*math.tau/8)),104+drop)
        walk.append(pose(lean=[0,-1,0,1,0,-1,0,1][i],drop=drop,near=near,far=far,
                         rear=rear,angle=.56+math.sin(i*math.tau/8)*.035,
                         hem=[0,-1,-1,0,1,1,0,-1][i],name=gait_names[i]))
        walk[-1].update(support_near=near_lift[i]==0,support_far=far_lift[i]==0)
    attack=[
        pose(name='guard'),
        pose(-1,1,(77,140),(82,136),(75,101),.50,-1,'take_grip'),
        pose(-2,2,(78,140),(79,135),(71,101),.43,-1,'load_body'),
        pose(-3,2,(79,140),(76,135),(68,100),.32,-2,'hold_anticipation'),
        pose(1,2,(84,141),(73,135),(78,101),.32,-2,'accelerate'),
        pose(6,3,(89,142),(70,135),(88,104),.32,-3,'contact'),
        pose(5,3,(88,142),(71,135),(87,106),.32,-2,'follow_through'),
        pose(1,1,(82,141),(78,136),(80,105),.54,-1,'recover'),
        pose(name='settle_guard')]
    return guard,walk,attack


def previews(frames,meta):
    for name,indices in [('caminhada',range(1,9)),('estocada',range(9,18))]:
        sheet=Image.new('RGB',(len(indices)*180,330),'#142026')
        d=ImageDraw.Draw(sheet)
        gif=[]
        for col,i in enumerate(indices):
            cel=frames[i].crop((40,72,160,150))
            thumb=cel.resize((240,156),Image.Resampling.NEAREST)
            sheet.paste(thumb,(col*180-25,55),thumb)
            b.text(d,(col*180+8,230),f'{col+1:02}',18)
            b.text(d,(col*180+8,254),meta[i]['name'],14)
            stage=Image.new('RGB',(720,468),'#142026')
            im=cel.resize(stage.size,Image.Resampling.NEAREST)
            stage.paste(im,(0,0),im)
            gif.append(stage)
        sheet.save(QA/f'{name}_quadros.png')
        durations=115 if name=='caminhada' else [180,170,220,350,80,85,140,230,300]
        gif[0].save(QA/f'{name}.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,optimize=False)


def build():
    ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    guard,walk,attack=poses()
    metadata=[guard]+walk+attack
    cels=[render(p) for p in metadata]
    frames=[b.flatten(layers) for layers in cels]
    durations=[.4]+[.115]*8+[.18,.17,.22,.35,.08,.085,.14,.23,.30]
    tags=[{'name':name,'from':a,'to':z,'color':'ac844aff'} for name,a,z in
          [('idle_down_right',1,1),('walk_down_right',2,9),('thrust_down_right',10,18)]]
    # Store just the authored anatomical information, not opaque renderer state.
    plan={'version':VERSION,'review_only':True,'canvas':list(CELL),'pivot':list(PIVOT),'game_scale':1.,
          'body_height':57,'columns':8,'frames':18,'texture':f'res://assets/sprites/{STEM}.png',
          'source':f'art/pixelorama/{STEM}/{STEM}.pxo','directions_ready':['down_right'],
          'clips':{'idle':{'down_right':[0]},'walk':{'down_right':list(range(1,9))},'thrust':{'down_right':list(range(9,18))}},
          'durations':durations,'contact_frame':14,'contact_seconds':1.,'walk_stride':24.,
          'palette':b.COLORS,'reference_sha256':b.digest(b.SOURCE.read_bytes()),
          'acting_reference':'port_enemies_v12 lancer: guard, anticipation, acceleration, contact, follow_through, recovery, rest',
          'presence_notes':PRESENCE_NOTES,
          'frame_metadata':metadata,'frame_regions':[[i%8*160,i//8*160,160,160] for i in range(18)]}
    old_layers=b.LAYERS;b.LAYERS=LAYER_NAMES
    project=b.native_blob(cels,tags,durations)
    b.LAYERS=old_layers
    products={f'{STEM}.pxo':project,'export_plan.json':(json.dumps(plan,ensure_ascii=False,indent=2)+'\n').encode(),
              'texture_base.png':b.encoded(TEX)}
    products.update({f'cels/{i:02}.png':b.encoded(frame) for i,frame in enumerate(frames)})
    lock=ART/'generated_hashes.json'
    old=json.loads(lock.read_text()) if lock.exists() else {}
    for name in products:
        p=ART/name
        if p.exists() and b.digest(p.read_bytes())!=old.get(name):raise SystemExit(f'Manual edit protected: {p}')
    for name,data in products.items():
        p=ART/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
    lock.write_text(json.dumps({name:b.digest(data) for name,data in products.items()},indent=2)+'\n')
    previews(frames,metadata)
    print(json.dumps({'frames':len(frames),'source':str(ART/f'{STEM}.pxo'),'qa':str(QA)}))


if __name__=='__main__':build()
