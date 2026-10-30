"""Boat hull only: larger native-pixel timber hull, Senu and oars preserved.
The material is keyed in hull UV coordinates for coherent detail in all 16 views.
"""
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
import json,math,hashlib,io,sys
from PIL import Image,ImageDraw
import build_senu_boat_v3 as rower
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'art/pixelorama/sea_v4'
QA=ROOT/'qa/boat_hull'
CELL=(128,96);PIVOT=(64,64);SHIFT=(16,10)
BOW=46.;STERN=28.;BEAM=14.
PAL={'ink':'#1b292b','deep':'#303c38','tar':'#293b3d','dark':'#443f31','wood':'#65543c','light':'#827052','edge':'#998360','rope':'#a1997c','bronze':'#887648'}


def noise(u,v,seed=0):
    n=(int(u)*374761393+int(v)*668265263+seed*1234567)&0xffffffff
    n=((n^(n>>13))*1274126177)&0xffffffff
    return (n^(n>>16))&255


def width(u):
    t=min(abs(u)/(BOW if u>=0 else STERN),1.)
    return BEAM*max(0.,1-t*t)**.62


def height(u):
    t=min(abs(u)/(BOW if u>=0 else STERN),1.)
    return 7.+8.*t**3.3


class Hull:
    def __init__(self,direction):
        self.theta=direction*math.tau/16;self.c=math.cos(self.theta);self.s=math.sin(self.theta)
        self.base=Image.new('RGBA',CELL);self.front=Image.new('RGBA',CELL)
        self.near=1 if self.c>=0 else -1
        self.stations=sorted(set([-STERN]+[float(u) for u in range(-27,46,2)]+[BOW]))

    def p(self,p):
        u,v,z=p
        return (PIVOT[0]+u*self.c-v*self.s,PIVOT[1]+(u*self.s+v*self.c)*.5-z)

    def depth(self,u,v):return u*self.s+v*self.c

    def line(self,im,points,color):
        ImageDraw.Draw(im).line([(round(x),round(y)) for x,y in [self.p(p) for p in points]],fill=color)

    def face(self,im,verts,material,seed=0,brightness=0):
        # Barycentric interpolation samples real hull UV coordinates, not screen
        # noise. Its wooden grain therefore turns with the vessel.
        for i in range(1,len(verts)-1):
            v=[verts[0],verts[i],verts[i+1]];p=[self.p(x) for x in v]
            xs=[q[0] for q in p];ys=[q[1] for q in p]
            den=(p[1][1]-p[2][1])*(p[0][0]-p[2][0])+(p[2][0]-p[1][0])*(p[0][1]-p[2][1])
            if abs(den)<1e-6:continue
            for y in range(max(0,math.floor(min(ys))),min(CELL[1],math.ceil(max(ys))+1)):
                for x in range(max(0,math.floor(min(xs))),min(CELL[0],math.ceil(max(xs))+1)):
                    a=((p[1][1]-p[2][1])*(x-p[2][0])+(p[2][0]-p[1][0])*(y-p[2][1]))/den
                    b=((p[2][1]-p[0][1])*(x-p[2][0])+(p[0][0]-p[2][0])*(y-p[2][1]))/den
                    c=1-a-b
                    if min(a,b,c)<-.005:continue
                    u=sum(k*q[0] for k,q in zip([a,b,c],v));vv=sum(k*q[1] for k,q in zip([a,b,c],v));z=sum(k*q[2] for k,q in zip([a,b,c],v))
                    if material=='side':
                        board=min(3,int(z/max(1,height(u))*4))
                        grain=noise(math.floor(u/3),math.floor(z*2),seed)
                        base=[(69,63,47),(85,73,52),(100,85,60),(112,96,70)][board]
                        # Broken grain runs, small weathered clusters and tar at
                        # the waterline replace the old continuous golden stripes.
                        delta=(grain%9-4)+brightness
                        if noise(math.floor(u/7),math.floor(z*4),seed+3)>225:delta-=12
                        if z<1.2:base=(41,58,58)
                        color=tuple(max(0,min(255,t+delta)) for t in base)+(255,)
                    elif material=='floor':
                        board=int((vv+BEAM)/4.0);grain=noise(math.floor(u/4),board,seed)
                        base=(75,68,49);delta=(grain%17-8)+brightness
                        if noise(math.floor(u/3),int(vv*3),seed+5)>235:delta-=13
                        color=tuple(max(0,min(255,t+delta)) for t in base)+(255,)
                    else:
                        base={'bench':(119,101,70),'rim':(113,98,72),'inside':(55,55,42)}[material]
                        delta=noise(int(u/4),int(vv/2),seed)%11-5+brightness
                        color=tuple(max(0,min(255,t+delta)) for t in base)+(255,)
                    im.putpixel((x,y),color)

    def side(self,sign):
        near=sign==self.near
        for a,b in zip(self.stations,self.stations[1:]):
            wa,wb=width(a),width(b);ha,hb=height(a),height(b)
            verts=[(a,sign*wa*.73,0),(b,sign*wb*.73,0),(b,sign*wb,hb),(a,sign*wa,ha)]
            shade=3 if sign*self.c<0 else -5
            self.face(self.base,verts,'side',27,shade)
            # Foreground surface is selected by its ground-plane depth; far
            # raised ends never paint over Senu's head.
            if near and self.depth((a+b)*.5,sign*(wa+wb)*.5)>=self.depth(3,0)-1:
                self.face(self.front,verts,'side',27,shade)
        # Thin shadow seams, staggered board joints and small fasteners.
        for fraction in [.25,.52,.77]:
            pts=[(u,sign*width(u)*(.73+.27*fraction),height(u)*fraction) for u in self.stations]
            self.line(self.base,pts,PAL['dark'])
            if near:
                pts=[p for p in pts if self.depth(p[0],p[1])>=self.depth(3,0)-1]
                if len(pts)>1:self.line(self.front,pts,PAL['dark'])
        for row in range(4):
            for u in range(-22+row%2*6,43,13):
                f0=row*.25+.03;f1=min(1.,(row+1)*.25-.02)
                pts=[(u,sign*width(u)*(.73+.27*f),height(u)*f) for f in [f0,f1]]
                self.line(self.base,pts,PAL['dark'])
                if near and self.depth(u,sign*width(u))>=self.depth(3,0)-1:self.line(self.front,pts,PAL['dark'])
                if row in [1,3]:
                    pin=self.p((u+.7,sign*width(u)*(.73+.27*f1),height(u)*f1))
                    ImageDraw.Draw(self.base).point((round(pin[0]),round(pin[1])),fill=PAL['ink'])
                    if near and self.depth(u,sign*width(u))>=self.depth(3,0)-1:ImageDraw.Draw(self.front).point((round(pin[0]),round(pin[1])),fill=PAL['ink'])
        # Gunwale top has real width and an inner dark lip.
        for a,b in zip(self.stations,self.stations[1:]):
            verts=[(a,sign*width(a),height(a)),(b,sign*width(b),height(b)),(b,sign*max(0,width(b)-1.1),height(b)+.6),(a,sign*max(0,width(a)-1.1),height(a)+.6)]
            self.face(self.base,verts,'rim',8)
            if near and self.depth((a+b)*.5,sign*(width(a)+width(b))*.5)>=self.depth(3,0)-1:self.face(self.front,verts,'rim',8)
        top=[(u,sign*width(u),height(u)+.2) for u in self.stations]
        bottom=[(u,sign*width(u)*.73,0) for u in self.stations]
        self.line(self.base,top,PAL['edge']);self.line(self.base,bottom,PAL['ink'])
        if near:
            top=[p for p in top if self.depth(p[0],p[1])>=self.depth(3,0)-1]
            bottom=[p for p in bottom if self.depth(p[0],p[1])>=self.depth(3,0)-1]
            if len(top)>1:self.line(self.front,top,PAL['edge'])
            if len(bottom)>1:self.line(self.front,bottom,PAL['ink'])

    def render(self):
        # Far hull first, then the inset floor and transverse supports.
        self.side(-self.near)
        for a,b in zip(self.stations,self.stations[1:]):
            wa=max(0,width(a)-1.7);wb=max(0,width(b)-1.7)
            self.face(self.base,[(a,-wa,2),(b,-wb,2),(b,wb,2),(a,wa,2)],'floor',18)
        for v in [-8,-4,0,4,8]:
            us=[u for u in self.stations if width(u)>abs(v)+2]
            self.line(self.base,[(u,v,2.1) for u in us],PAL['dark'])
        for u in [-17,-2,17,34]:
            w=max(0,width(u)-2)
            self.line(self.base,[(u,-w,2.2),(u,w,2.2)],PAL['ink'])
        for u in [-13,3,25]:
            w=width(u)-1.4;z=6.4 if u==3 else 5.5
            self.face(self.base,[(u-1.7,-w,z),(u+1.7,-w,z),(u+1.7,w,z),(u-1.7,w,z)],'bench',int(u)+100)
            self.line(self.base,[(u-1.7,-w,z),(u-1.7,w,z)],PAL['dark'])
        # Original v3 oar pivots remain fixed on a low rowing crossbeam.
        self.face(self.base,[(-3.2,-12,5.6),(-.8,-12,5.6),(-.8,12,5.6),(-3.2,12,5.6)],'bench',71,-5)
        for side in [-1,1]:
            q=self.p((-2,side*rower.old.half_width(-2),rower.old.gunwale(-2)+1))
            ImageDraw.Draw(self.base).rectangle((round(q[0])-1,round(q[1])-1,round(q[0])+1,round(q[1])),fill=PAL['bronze'])
            ImageDraw.Draw(self.base).point((round(q[0]),round(q[1])),fill=PAL['ink'])
        self.side(self.near)
        # Rope lashings and curved timber stems, restrained rather than gold bands.
        for u in [-23,38]:
            for offset in [0,.8]:
                points=[(u+offset,-width(u),height(u)+.6),(u+offset,width(u),height(u)+.6)]
                self.line(self.base,points,PAL['rope'])
                if self.depth(u,self.near*width(u))>=self.depth(3,0)-1:self.line(self.front,points,PAL['rope'])
        for u in [-STERN,BOW]:
            tip=[(u,0,height(u)),(u+(1 if u>0 else -1)*2,0,height(u)+2)]
            self.line(self.base,tip,PAL['dark'])
            self.line(self.base,[(p[0],p[1],p[2]+.6) for p in tip],PAL['light'])
            if self.depth(u,0)>=self.depth(3,0)-1:
                self.line(self.front,tip,PAL['dark']);self.line(self.front,[(p[0],p[1],p[2]+.6) for p in tip],PAL['light'])
        return self.base,self.front


def translate(im):
    out=Image.new('RGBA',CELL);out.alpha_composite(im,SHIFT);return out


def native(frames,layers,sprites):
    dest=OUT/'boat_v4.pxo'
    if dest.exists() and '--replace-generated' not in sys.argv:raise RuntimeError('PXO existente: use o exportador; reconstrução requer --replace-generated')
    data={'pixelorama_version':'v1.2.3-stable','pxo_version':7,'size_x':CELL[0],'size_y':CELL[1],'color_mode':5,
    'layers':[{'name':name,'type':0,'new_cels_linked':False,'visible':True,'locked':False,'blend_mode':0,'opacity':1.,'parent':-1,'effects':[]} for name,_ in layers],
    'frames':[{'cels':[{'opacity':1.,'z_index':0} for _ in layers],'duration':1.} for _ in frames],
    'tags':[{'name':name,'color':'6db0a4ff','from':value['frames'][0]+1,'to':value['frames'][-1]+1} for name,value in sprites.items()],
    'fps':8.4,'current_frame':0,'current_layer':0,'export_profile':{'orientation':'1','lines_count':'10','current_tab':'1','crop_mode':'0','resize':'100','interpolation':'0'}}
    with ZipFile(dest,'w',ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/x-pixelorama');z.writestr('data.json',json.dumps(data))
        for li,(_,images) in enumerate(layers,1):
            for i,im in enumerate(images,1):z.writestr(f'image_data/frames/{i}/layer_{li}',im.tobytes())
        b=io.BytesIO();frames[0].save(b,format='PNG');z.writestr('preview.png',b.getvalue())
    manifest={'version':4,'canvas':CELL,'pivot':PIVOT,'columns':10,'frames':160,'pixel_art':True,'game_scale':1.,'source':'res://art/pixelorama/sea_v4/boat_v4.pxo','texture':'res://assets/world/boat_v4.png','sprites':sprites,
    'hull':{'bow':BOW,'stern':STERN,'half_beam':BEAM,'wood_reference':'res://assets/world/port_pixel_v7.png'},
    'preserved':{'body':'v3 native cels unchanged at the same world coordinates','oars':'v3 oar_contacts.json and renderer unchanged','source_sha256':hashlib.sha256((ROOT/'art/pixelorama/senu/boat_v3/boat_v3.pxo').read_bytes()).hexdigest()}}
    (OUT/'boat_v4_export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')


def main():
    OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
    if (OUT/'boat_v4.pxo').exists() and '--replace-generated' not in sys.argv:raise RuntimeError('Fonte editável existente: exporte em vez de reconstruir')
    contacts={x['frame']:x for x in json.loads((ROOT/'art/pixelorama/senu/boat_v3/oar_contacts.json').read_text())}
    previous=json.loads((ROOT/'assets/world/boat_v3_manifest.json').read_text())
    frames=[];hulls=[];inner=[];bodies=[];rims=[];outer=[]
    with ZipFile(ROOT/'art/pixelorama/senu/boat_v3/boat_v3.pxo') as z:
        for direction in range(16):
            base,rim=Hull(direction).render()
            for index in range(10):
                i=direction*10+index
                body=translate(Image.frombytes('RGBA',(96,80),z.read(f'image_data/frames/{i+1}/layer_2')))
                inside=Image.new('RGBA',(96,80));outside=Image.new('RGBA',(96,80))
                if i in contacts:
                    item=contacts[i];theta=direction*math.tau/16;near=1 if math.cos(theta)>=0 else -1
                    near_index=1 if near==1 else 0
                    for geometry in item['oars']:rower.oar(inside,geometry,index==1)
                    rower.oar(outside,item['oars'][near_index],index==1,external_only=True)
                inside=translate(inside);outside=translate(outside)
                # Separate all components: no body/oar pixels can be regenerated
                # or rescaled when only the hull is edited.
                composed=base.copy()
                for im in [inside,body,rim,outside]:composed.alpha_composite(im)
                hulls.append(base.copy());inner.append(inside);bodies.append(body);rims.append(rim.copy());outer.append(outside);frames.append(composed)
    layers=[('Casco - madeira do porto',hulls),('Remos internos e distantes v3 preservados',inner),('Senu v3 preservado',bodies),('Costado próximo do casco',rims),('Remo próximo v3 preservado',outer)]
    native(frames,layers,previous['sprites'])
    # Check fixed world-space anatomy and handle pixels against the exact v3 cels.
    for i in range(160):
        assert bodies[i].crop((SHIFT[0],SHIFT[1],SHIFT[0]+96,SHIFT[1]+80)).tobytes()==Image.frombytes('RGBA',(96,80),ZipFile(ROOT/'art/pixelorama/senu/boat_v3/boat_v3.pxo').read(f'image_data/frames/{i+1}/layer_2')).tobytes()
    preview=Image.new('RGBA',(128*4,96*4),(30,44,48,255))
    for i in range(16):preview.alpha_composite(frames[i*10],((i%4)*128,(i//4)*96))
    preview.resize((preview.width*3,preview.height*3),Image.Resampling.NEAREST).save(QA/'directions.png')
    gif=[]
    for phase in range(1,9):
        image=Image.new('RGBA',(768,576),(30,44,48,255))
        for k,direction in enumerate([0,6,8,14]):image.alpha_composite(frames[direction*10+phase].resize((384,288),Image.Resampling.NEAREST),((k%2)*384,(k//2)*288))
        gif.append(image.convert('RGB'))
    gif[0].save(QA/'barco_maior.gif',save_all=True,append_images=gif[1:],duration=120,loop=0,disposal=2)
    print('HULL_V4 frames=160 directions=16 body_preserved=160 canvas=128x96 pivot=64,64')

if __name__=='__main__':main()
