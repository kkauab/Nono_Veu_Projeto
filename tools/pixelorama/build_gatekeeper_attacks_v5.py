"""Nine JSON-timed attack clips; v4 presence with the v3 face preserved."""
import copy,json,math
from pathlib import Path
from PIL import Image,ImageDraw
import build_gatekeeper_art_v4 as appearance

r=appearance.rig
b=r.b
ROOT=r.ROOT
ART=ROOT/'art/pixelorama/porteiro_v5'
QA=ROOT/'qa/porteiro_attacks_v5'
DEFS=ROOT/'resources/bosses/gatekeeper_attacks.json'


def p(lean=0,drop=0,rear=(77,104),angle=.56,near=(76,140),far=(84,137),hem=0):
    return r.pose(lean,drop,near,far,rear,angle,hem)


def sequence(family):
    guard,_,thrust=r.poses()
    if family in ['charge','echo']:
        result=copy.deepcopy(thrust)
        if family=='echo':
            for i in [2,3,6]:
                old=result[i]
                result[i]=p(old['lean']-1,old['drop'],old['rear'],old['angle'],old['near'],old['far'],old['hem'])
        return result
    if family=='sweep':return [guard,p(-1,1,(76,100),-.15),p(-3,2,(73,99),-.4),p(-3,2,(72,101),-.45),p(0,2,(80,100),.15),p(4,3,(86,104),.80,(87,142),(71,135),-3),p(3,3,(84,104),1.0,(86,142),(72,135),-2),p(1,1,(79,104),.7),guard]
    if family in ['slam','sigils','ultimate']:
        big=family=='ultimate';sigil=family=='sigils'
        contact=p(8 if big else (3 if sigil else 6),5 if big else 4,
                  (85,105) if big else ((80,102) if sigil else (83,103)),
                  .80 if big else (1.02 if sigil else .85),(91,143) if big else (88,142),(68,135) if big else (70,135),-3)
        return [guard,p(-1,0,(76,100),-1.15),p(-2,1,(75,99),-1.45),
                p(-3 if big else -2,2,(75,97),-1.6),p(1,3,(78,99),-.35),
                contact,p(5,4,(83,104),.95,(87,142),(71,135),-2),p(1,2,(79,105),.7),guard]
    if family=='bell':return [guard,p(0,1,(81,104),-.8),p(1,1,(83,105),-1.3),p(1,2,(84,106),-1.45),p(2,2,(85,105),-1.45),p(1,1,(84,106),-1.45),p(0,2,(83,107),-1.38),p(0,1,(80,106),-.5),guard]
    if family=='guard':return [guard,p(-1,1,(74,100),-.4),p(-2,1,(73,99),-.45),p(-2,1,(72,100),-.3),p(2,2,(81,100),.15),p(5,3,(84,103),.85,(87,141),(72,135),-2),p(4,3,(83,104),.9,(86,141),(73,135),-2),p(1,1,(79,105),.65),guard]
    if family=='chain':return [guard,p(-1,1,(74,101),-.4),p(-2,2,(73,101),-.7),p(-2,2,(72,102),-.65),p(1,2,(82,101),.2),p(5,2,(88,105),.55,(87,141),(72,135),-2),p(3,3,(85,105),.7,(85,141),(74,136),-1),p(0,1,(79,104),.65),guard]
    raise ValueError(family)


def build():
    data=json.loads(DEFS.read_text(encoding='utf8'))
    ART.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    guard,walk,thrust=r.poses()
    meta=[guard]+walk+thrust
    durations=[.4]+[.115]*8+[.18,.17,.22,.35,.08,.085,.14,.23,.30]
    clips={'idle':{'down_right':[0]},'walk':{'down_right':list(range(1,9))},'thrust':{'down_right':list(range(9,18))}}
    contact_frames={'thrust':14}
    contact_seconds={'thrust':1.0}
    tags=[{'name':n,'from':a,'to':z,'color':'ac844aff'} for n,a,z in [('idle_down_right',1,1),('walk_down_right',2,9),('thrust_down_right',10,18)]]
    for attack_id in data['order']:
        attack=data['attacks'][attack_id]
        poses=sequence(attack['pose_family'])
        assert len(poses)==len(attack['seconds'])==9
        start=len(meta)
        for i,pose in enumerate(poses):
            pose=copy.deepcopy(pose)
            pose.update(attack=attack_id,name=data['pose_names'][i],pose=i)
            meta.append(pose)
        clips[attack_id]={'down_right':list(range(start,start+9))}
        durations.extend(attack['seconds'])
        contact_frames[attack_id]=start+attack['contact_pose']
        contact_seconds[attack_id]=sum(attack['seconds'][:attack['contact_pose']])
        tags.append({'name':attack_id+'_down_right','from':start+1,'to':start+9,'color':'ac844aff'})
    cels=[r.render(pose) for pose in meta]
    frames=[b.flatten(layers) for layers in cels]
    columns=10
    plan={'version':5,'review_only':True,'canvas':[160,160],'pivot':[80,140],'game_scale':1.,'body_height':57,
          'columns':columns,'frames':len(frames),'texture':'res://assets/sprites/porteiro_v5.png',
          'source':'art/pixelorama/porteiro_v5/porteiro_v5.pxo','directions_ready':['down_right'],
          'clips':clips,'durations':durations,'contact_frame':14,'contact_frames':contact_frames,
          'contact_seconds':contact_seconds,'walk_stride':24.,'palette':b.COLORS,'frame_metadata':meta,
          'attack_definitions':'res://resources/bosses/gatekeeper_attacks.json','attack_definitions_sha256':b.digest(DEFS.read_bytes()),
          'reference_sha256':b.digest(b.SOURCE.read_bytes()),'face_source':'art/pixelorama/porteiro_v3/porteiro_v3.pxo',
          'frame_regions':[[i%columns*160,i//columns*160,160,160] for i in range(len(frames))]}
    original_names=b.LAYERS;b.LAYERS=r.LAYER_NAMES
    native=b.native_blob(cels,tags,durations,columns)
    b.LAYERS=original_names
    products={'porteiro_v5.pxo':native,'export_plan.json':(json.dumps(plan,ensure_ascii=False,indent=2)+'\n').encode()}
    products.update({f'cels/{i:03}.png':b.encoded(frame) for i,frame in enumerate(frames)})
    lock=ART/'generated_hashes.json'
    old=json.loads(lock.read_text()) if lock.exists() else {}
    for name in products:
        path=ART/name
        if path.exists() and b.digest(path.read_bytes())!=old.get(name):raise SystemExit(f'Manual edit protected: {path}')
    for name,blob in products.items():
        path=ART/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(blob)
    lock.write_text(json.dumps({name:b.digest(blob) for name,blob in products.items()},indent=2)+'\n')
    # Individual GIFs retain the exact JSON timing; the ground effects are
    # captured separately from the actual Godot runtime, not painted into cels.
    for attack_id in data['order']:
        indices=clips[attack_id]['down_right']
        gif=[]
        for i in indices:
            board=Image.new('RGB',(600,450),'#142026')
            cel=frames[i].crop((40,55,160,145)).resize(board.size,Image.Resampling.NEAREST)
            board.paste(cel,(0,0),cel);gif.append(board)
        gif[0].save(QA/f'{attack_id}_sprites.gif',save_all=True,append_images=gif[1:],duration=[round(durations[i]*1000) for i in indices],loop=0,optimize=False)
    print(json.dumps({'frames':len(frames),'attacks':len(data['order']),'source':str(ART/'porteiro_v5.pxo')}))


if __name__=='__main__':build()
