"""Exact, shared anatomical guides for eight-direction modular weapon poses."""
from pathlib import Path
import json, math
from PIL import Image,ImageDraw
import build_motion_pose_guides as g

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/pixelorama/senu/unified_v6_sources'
DIRS=[('down',(0,1)),('down_right',(.7071,.7071)),('right',(1,0)),('up_right',(.7071,-.7071)),('up',(0,-1)),('up_left',(-.7071,-.7071)),('left',(-1,0)),('down_left',(-.7071,.7071))]

def pose(row):
    p=g.walk_pose(0)
    for side,x in [('near',-.16),('far',.16)]:
        p[side]['hip']=(x,0,1.0)
        p[side]['ankle']=(x,.12 if side=='near' else -.16,.11)
        p[side]['knee']=g.ik(p[side]['hip'],p[side]['ankle'])
        p[side]['foot_angle']=0
        p[side]['shoulder']=(x*1.8,0,1.64)
    # No body-size deformation: shoulder/hip heights remain fixed.
    wrists=[((-.32,-.12,1.30),(.32,-.08,1.30)),
            ((-.28,.67,1.43),(.32,.02,1.29)),
            ((-.32,.01,1.30),(.28,.67,1.43)),
            ((-.31,.15,1.24),(.31,.12,1.24))][row]
    for side,w in zip(['near','far'],wrists):
        p[side]['wrist']=w
        shoulder=p[side]['shoulder']
        p[side]['elbow']=tuple((shoulder[i]+w[i])*.5 for i in range(3))
    p['pelvis']=(0,0,1.0);p['neck']=(0,0,1.78);p['head']=(0,-.015,2.01)
    return p

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    im=Image.new('RGB',(2560,1280),(246,245,238));d=ImageDraw.Draw(im)
    keys={}
    for row in range(4):
        for col,(name,heading) in enumerate(DIRS):
            root=(col*320+160,row*320+278)
            points=pose(row)
            g.draw_pose(d,points,heading,root,86)
            keys[f'{row}_{name}']={side:list(g.project(points[side]['wrist'],heading,(160,278),86)) for side in ['near','far']}
    im.save(OUT/'attack_guide.png')
    (OUT/'attack_guide_keys.json').write_text(json.dumps({'grid':[8,4],'cell':[320,320],'root':[160,278],'hand_keys':keys,'direction_order':[n for n,h in DIRS]},indent=2),encoding='utf8')
    print('ATTACK_GUIDE_V6_OK')

if __name__=='__main__':main()
