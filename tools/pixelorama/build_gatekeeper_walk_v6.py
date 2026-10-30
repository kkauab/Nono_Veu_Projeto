"""Grounded walk revision only. Never rebuild or overwrite v5 attack cels.

Foot support is authored in a forward/height plane, projected into the same
isometric view. This avoids solving bent knees in distorted screen space.
"""
import copy,json,math
from zipfile import ZipFile
from PIL import Image,ImageDraw
import build_gatekeeper_art_v4 as appearance
r=appearance.rig
b=r.b
ROOT=r.ROOT
ART=ROOT/'art/pixelorama/porteiro_walk_v6'
QA=ROOT/'qa/porteiro_walk_v6'
SOURCE=ROOT/'resources/bosses/gatekeeper_walk.json'
SETTINGS=json.loads(SOURCE.read_text(encoding='utf8'))
AXIS=SETTINGS['ground_axis']

def project(base,q,height):
    return (base[0]+AXIS[0]*q,base[1]+AXIS[1]*q-height)

def foot_phase(phase):
    stance=SETTINGS['stance_fraction']
    length=SETTINGS['stride']*stance
    if phase<=stance:
        return length*.5-SETTINGS['stride']*phase,0.0,True
    t=(phase-stance)/(1-stance)
    return length*(-.5+t*t*(3-2*t)),SETTINGS['foot_lift']*math.sin(math.pi*t)**1.5,False

def legs(p,values):
    p['feet_plane']=copy.deepcopy(values)
    for side,base,height in [('near',(76,140),23),('far',(84,137),22)]:
        q,lift,support=values[side]
        pelvis_q=.55
        hip_height=height-p['drop']*.45
        knee=r.joint((pelvis_q,-hip_height),(q,-lift-2),11.5,12,-1)
        p['hip_'+side]=project(base,pelvis_q,hip_height)
        p['knee_'+side]=project(base,knee[0],-knee[1])
        p[side]=r.rounded(project(base,q,lift))
        p['support_'+side]=support
    return p

def walking_poses():
    result=[]
    for i,info in enumerate(SETTINGS['poses']):
        # One-pixel weight compression, steady head/shaft, delayed cloth hem.
        p=r.pose(1,info['drop'],rear=(78,104+info['drop']),angle=.56,hem=info['hem'],name=info['name'])
        values={'near':foot_phase(i/16),'far':foot_phase(((i+8)%16)/16)}
        legs(p,values)
        p.update(walk_phase=i,root_distance=i*SETTINGS['stride']/16)
        result.append(p)
    return result

def render(p):
    layers=r.render(p)
    lower=Image.new('RGBA',r.CELL)
    d=ImageDraw.Draw(lower)
    for side,src in [('far',[(84,115),(84,126),(87,137)]),('near',[(75,115),(74,126),(74,138)])]:
        foot=p[side]
        chain=[p['hip_'+side],p['knee_'+side],r.add(foot,(0,-2))]
        # Opaque cloth/leg backing prevents holes from the concept texture
        # flickering between bent poses. The actual source pixels sit on top.
        for i in range(2):
            d.polygon(r.bone_quad(chain[i],chain[i+1],2.7-i*.4,2.3-i*.5),fill='#292822')
        r.limb(lower,src,chain,[2.8,2.3,1.8])
        if side=='near':
            r.rigid_piece(lower,[(71,134),(76,134),(78,138),(77,140),(69,140),(70,138)],r.sub(foot,(74,140)))
        else:
            r.rigid_piece(lower,[(83,133),(88,133),(91,136),(94,138),(91,140),(84,139)],r.sub(foot,(87,139)))
    # Split the hanging tunic from the legs: the belt stays fixed and only
    # the lower folds follow the knees, rather than stretching the entire robe.
    ln,dp=p['lean'],p['drop']
    r.quad(lower,[(73,110),(85,110),(87,130),(71,132)],
        [(73+ln*.5,110+dp*.6),(85+ln*.5,110+dp*.6),
         (86+(p['knee_far'][0]-84)*.18,130+dp*.15),
         (72+(p['knee_near'][0]-74)*.18,132+dp*.15)])
    lower.alpha_composite(layers[1].crop((0,0,160,120)),(0,0))
    layers[1]=lower
    return layers

def build():
    ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    meta=walking_poses()
    cels=[render(p) for p in meta]
    settle={}
    for phase,start in enumerate(meta[:16]):
        first='far' if start['support_near'] else 'near'
        second='near' if first=='far' else 'far'
        original=copy.deepcopy(start['feet_plane'])
        intermediate=[]
        for stage in [0,1]:
            p=r.pose(1 if stage==0 else 0,0,rear=(78 if stage==0 else 77,104),angle=.56,hem=0,name=f'settle_{phase}_{stage}')
            values=copy.deepcopy(original)
            if stage==0:
                values[first]=[original[first][0]*.45,1.0,False]
            else:
                values[first]=[0.0,0.0,True]
                values[second]=[original[second][0]*.45,1.0,False]
            legs(p,values)
            p.update(settle_from=phase,settle_stage=stage)
            intermediate.append(len(cels));meta.append(p);cels.append(render(p))
        settle[str(phase)]=[phase,*intermediate,48]
    # End on the exact existing guard pixels, including the preferred face.
    with ZipFile(ROOT/'art/pixelorama/porteiro_v5/porteiro_v5.pxo') as previous:
        guard=[Image.frombytes('RGBA',r.CELL,previous.read(f'image_data/frames/1/layer_{layer+1}')) for layer in range(4)]
    cels.append(guard);meta.append(r.pose())
    frames=[b.flatten(cel) for cel in cels]
    durations=[SETTINGS['stride']/SETTINGS['move_speed']/16]*16+[.06,.065]*16+[.08]
    tags=[{'name':'walk_down_right','from':1,'to':16,'color':'ac844aff'}, {'name':'guard','from':49,'to':49,'color':'ac844aff'}]
    for phase in range(16):tags.append({'name':f'settle_{phase:02}','from':17+phase*2,'to':18+phase*2,'color':'ac844aff'})
    for color in ['292822']:
        if color not in b.COLORS:b.COLORS.append(color)
    plan={'version':6,'review_only':True,'canvas':[160,160],'pivot':[80,140],'frames':49,'columns':7,
        'texture':'res://assets/sprites/porteiro_walk_v6.png','source':'art/pixelorama/porteiro_walk_v6/porteiro_walk_v6.pxo',
        'clips':{'walk':{'down_right':list(range(16))}},'walk_stride':SETTINGS['stride'],'walk_start_phase':SETTINGS['start_phase'],
        'move_speed':SETTINGS['move_speed'],'settle_sequences':settle,'settle_seconds':SETTINGS['settle_seconds'],
        'durations':durations,'frame_regions':[[i%7*160,i//7*160,160,160] for i in range(49)],'frame_metadata':meta,
        'palette':b.COLORS,'settings_sha256':b.digest(SOURCE.read_bytes()),'settings':'res://resources/bosses/gatekeeper_walk.json',
        'previous_attacks_sha256':b.digest((ROOT/'art/pixelorama/porteiro_v5/porteiro_v5.pxo').read_bytes())}
    previous_names=b.LAYERS;b.LAYERS=r.LAYER_NAMES
    native=b.native_blob(cels,tags,durations,7);b.LAYERS=previous_names
    products={'porteiro_walk_v6.pxo':native,'export_plan.json':(json.dumps(plan,ensure_ascii=False,indent=2)+'\n').encode()}
    products.update({f'cels/{i:03}.png':b.encoded(frame) for i,frame in enumerate(frames)})
    lock=ART/'generated_hashes.json'
    old=json.loads(lock.read_text()) if lock.exists() else {}
    for name in products:
        path=ART/name
        if path.exists() and b.digest(path.read_bytes())!=old.get(name):raise SystemExit(f'Manual edit protected: {path}')
    for name,blob in products.items():
        path=ART/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(blob)
    lock.write_text(json.dumps({name:b.digest(blob) for name,blob in products.items()},indent=2)+'\n')
    # Comparable native-pixel studio proof, before/after at the same height.
    previous=[Image.open(ROOT/f'art/pixelorama/porteiro_v5/cels/{i+1:03}.png').convert('RGBA') for i in range(8)]
    gif=[]
    for i in range(60):
        stage=Image.new('RGB',(720,350),'#142026');draw=ImageDraw.Draw(stage)
        b.text(draw,(24,12),'ANTERIOR',18);b.text(draw,(384,12),'PASSOS REFINADOS',18)
        old_index=int((i/15*39/24)%1*8)
        new_index=(int((i/15*SETTINGS['move_speed']/SETTINGS['stride'])%1*16)+SETTINGS['start_phase'])%16
        for j,frame in enumerate([previous[old_index],frames[new_index]]):
            crop=frame.crop((46,77,141,146)).resize((285,207),Image.Resampling.NEAREST)
            stage.paste(crop,(25+j*360,65),crop)
        gif.append(stage)
    gif[0].save(QA/'comparacao_caminhada.gif',save_all=True,append_images=gif[1:],duration=[60 if i%3==1 else 70 for i in range(60)],loop=0,optimize=False)
    sheet=Image.new('RGB',(800,480),'#142026')
    for i,frame in enumerate(frames[:16]):
        im=frame.crop((56,80,120,144)).resize((128,128),Image.Resampling.NEAREST)
        sheet.paste(im,(i%8*100-5,i//8*210+40),im)
        b.text(ImageDraw.Draw(sheet),(i%8*100+6,i//8*210+172),str(i+1),16)
    sheet.save(QA/'ciclo_16_poses.png')
    print(json.dumps({'frames':49,'walk_frames':16,'settles':16,'source':str(ART/'porteiro_walk_v6.pxo')}))

if __name__=='__main__':build()
