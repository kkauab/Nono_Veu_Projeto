"""Author native expression, eye and mouth cels for the dialogue portraits.

Senu keeps his existing raster identity. The new fisherman was generated with
the same portrait as style reference. Everything outside the face and feature
regions remains pixel-identical across all36 poses. Pixelorama exports PNG.
"""
import copy
import json
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
from PIL import Image,ImageDraw,ImageChops
import build_pixelorama_project as native

ROOT=Path(__file__).resolve().parents[2]
ART=ROOT/'art/pixelorama/dialogue_v14'
OUT=ROOT/'assets/ui/dialogue_v14'
SIZE=(160,192)
EXPRS=['neutral','concerned','sad','resolute']
LAYERS=['Busto e vestes','Sobrancelhas e expressão','Olho próximo','Olho distante','Boca','Lenço']

def blank():return Image.new('RGBA',SIZE)
def sample(im,x,y):return im.getpixel((x,y))
def patch(im,rect):
    out=blank();out.paste(im.crop(rect),(rect[0],rect[1]));return out
def clear_mask(im,rects):
    mask=Image.new('L',SIZE);d=ImageDraw.Draw(mask)
    for r in rects:d.rectangle((r[0],r[1],r[2]-1,r[3]-1),fill=255)
    result=im.copy();result.putalpha(ImageChops.subtract(im.getchannel('A'),mask));return result

def eyebrows(im,name,expression):
    rects=([(58,48,73,55),(47,52,56,58)] if name=='senu' else [(51,52,69,59),(40,52,50,59)])
    out=blank()
    for rect in rects:out.alpha_composite(patch(im,rect))
    if expression==0:return out,rects
    d=ImageDraw.Draw(out)
    if name=='senu':
        skin=sample(im,57,59);shade=sample(im,73,56);ink=sample(im,64,50)
        d.polygon([(59,50),(64,49),(70,50),(71,54),(64,54),(59,53)],fill=skin)
        d.polygon([(48,53),(53,53),(55,56),(48,56)],fill=sample(im,54,58))
        near={1:[(60,51),(63,50),(66,51),(70,53)],2:[(60,50),(63,50),(66,52),(70,54)],3:[(60,54),(64,52),(68,51),(71,51)]}[expression]
        far={1:[(48,55),(51,54),(54,55)],2:[(48,55),(51,54),(54,56)],3:[(48,56),(51,54),(54,54)]}[expression]
        d.line(near,fill=ink,width=2);d.line(far,fill=ink,width=1)
        if expression==2:d.point((60,49),fill=shade)
    else:
        ink=sample(im,59,55);skin=sample(im,57,52);darkskin=sample(im,53,55)
        d.polygon([(52,54),(57,54),(61,54),(65,55),(67,57),(65,59),(59,58),(54,58),(52,56)],fill=skin)
        d.polygon([(41,54),(45,53),(48,54),(49,58),(43,58)],fill=darkskin)
        near={1:[(53,54),(56,53),(60,54),(65,56)],2:[(53,54),(56,53),(60,55),(65,57)],3:[(53,58),(57,56),(61,55),(66,55)]}[expression]
        far={1:[(41,56),(44,54),(47,55)],2:[(41,56),(44,54),(47,56)],3:[(41,57),(44,55),(48,55)]}[expression]
        d.line(near,fill=ink,width=2);d.line(far,fill=ink,width=1)
    return out,rects

def eyes(im,name,eye,expression):
    rects=([(58,55,74,64),(47,58,57,66)] if name=='senu' else [(51,59,67,68),(40,59,50,65)])
    near=patch(im,rects[0]);far=patch(im,rects[1])
    d=ImageDraw.Draw(near);f=ImageDraw.Draw(far)
    if eye==0:
        # Keep the original iris/sclera proportions in every open-eye face.
        # Eyebrows carry most expression; a one-pixel lid adds sadness/focus.
        if name=='senu':
            ink=sample(im,62,56)
            if expression==2:d.line([(63,56),(66,56),(69,56)],fill=ink)
            if expression==3:d.line([(60,56),(63,57)],fill=ink)
        else:
            ink=sample(im,57,60)
            if expression==2:d.line([(61,60),(63,61)],fill=ink)
            if expression==3:d.line([(55,60),(58,61)],fill=ink)
        return near,far,rects
    def spans(canvas,rows,colors):
        # Only the original aperture is repainted. The surrounding eye socket,
        # canthi, cheek planes and their texture remain the original drawing.
        for y,x0,x1,tone in rows:
            color=colors[tone]
            for x in range(x0,x1+1):
                # Carry tiny native skin variations into the curved lid.
                grain=(sum(im.getpixel((x,min(191,y+7)))[:3])%5)-2
                canvas.point((x,y),fill=tuple(max(0,min(255,v+grain)) for v in color[:3])+(255,))
    if name=='senu':
        ramp=[sample(im,63,60),sample(im,61,60),sample(im,62,62),sample(im,68,62)]
        crease=sample(im,69,57);edge=sample(im,62,58)
        if eye==1:
            spans(d,[(56,62,68,0),(57,62,68,1)],ramp)
            # Iris and sclera are the original lower rows, never a new white strip.
            d.line([(61,57),(63,58),(66,58),(69,56)],fill=crease)
            d.point((63,58),fill=sample(im,63,58))
            d.point((64,59),fill=sample(im,64,59))
            d.point((65,59),fill=sample(im,65,59))
            spans(f,[(59,50,53,0)],ramp)
            f.line([(50,60),(52,60),(53,59)],fill=sample(im,50,59))
        else:
            spans(d,[(56,62,68,0),(57,61,69,1),(58,61,68,2),(59,62,67,3),(60,64,66,1)],ramp)
            d.line([(62,56),(65,56),(68,55)],fill=sample(im,68,60))
            d.line([(60,57),(62,59),(65,60),(68,59),(70,57)],fill=crease)
            d.point((62,59),fill=edge)
            d.point((66,61),fill=sample(im,68,62))
            spans(f,[(59,50,53,0),(60,50,53,1),(61,50,52,2)],ramp)
            f.line([(49,60),(51,62),(53,61),(54,60)],fill=sample(im,50,59))
    else:
        ramp=[sample(im,56,60),sample(im,57,65),sample(im,55,63),sample(im,61,66)]
        crease=sample(im,57,63);edge=sample(im,58,63)
        if eye==1:
            spans(d,[(60,57,64,0),(61,57,64,1)],ramp)
            d.line([(55,61),(58,62),(61,62),(64,60)],fill=crease)
            # The small pupil remains connected to its lower sclera pixels.
            d.point((60,62),fill=sample(im,60,62))
            d.point((61,62),fill=sample(im,61,62))
            d.point((62,62),fill=sample(im,62,62))
            spans(f,[(60,43,46,0)],ramp)
            f.line([(42,61),(44,62),(47,61)],fill=sample(im,44,61))
        else:
            spans(d,[(60,57,64,0),(61,56,64,1),(62,56,63,2),(63,57,62,3)],ramp)
            d.line([(57,60),(60,60),(63,59)],fill=sample(im,59,64))
            d.line([(55,61),(57,63),(60,64),(63,63),(65,61)],fill=crease)
            d.point((57,63),fill=edge)
            d.point((61,65),fill=sample(im,61,66))
            spans(f,[(60,43,47,0),(61,43,47,1),(62,44,46,2)],ramp)
            f.line([(42,61),(44,63),(47,62),(48,61)],fill=sample(im,44,61))
    return near,far,rects

def mouth(im,name,mouth,expression):
    rect=(51,70,65,80) if name=='senu' else (48,79,65,89)
    out=patch(im,rect)
    if mouth==0 and expression!=2:return out,rect
    d=ImageDraw.Draw(out)
    if name=='senu':
        if mouth==0:
            # Only the old lip's central pixels move; cheek/chin remain intact.
            for x in range(54,61):d.point((x,72),fill=sample(im,x,70))
            d.line([(53,74),(56,73),(59,73),(62,74)],fill=sample(im,56,72))
        elif mouth==1:
            # Small rounded vowel: the original upper lip is still the rim.
            d.line([(54,73),(59,73)],fill=(94,44,28,255))
            d.line([(55,74),(59,74)],fill=(63,30,26,255))
            d.line([(56,75),(58,75)],fill=(125,61,38,255))
            d.point((55,74),fill=(113,52,29,255))
            d.line([(56,76),(59,76)],fill=sample(im,58,76))
        else:
            d.line([(54,73),(60,73)],fill=(91,42,28,255))
            d.line([(54,74),(60,74)],fill=(53,27,25,255))
            d.line([(55,75),(59,75)],fill=(68,31,27,255))
            d.line([(56,76),(59,76)],fill=(133,64,42,255))
            d.point((58,73),fill=(204,170,128,255))
            d.point((59,73),fill=(226,196,152,255))
            d.line([(56,77),(59,77)],fill=(159,80,41,255))
            d.point((60,75),fill=sample(im,61,74))
    else:
        # Beard and moustache are never washed over with a skin rectangle.
        if mouth==0:
            d.point((50,83),fill=sample(im,52,82))
            d.point((59,84),fill=sample(im,57,82))
        elif mouth==1:
            d.line([(51,82),(57,82)],fill=(81,39,25,255))
            d.line([(52,83),(56,83)],fill=(49,25,22,255))
            d.line([(53,84),(55,84)],fill=(125,63,36,255))
            d.point((51,82),fill=sample(im,50,81))
        else:
            d.line([(52,81),(57,81)],fill=(85,40,25,255))
            d.line([(51,82),(58,82)],fill=(43,23,21,255))
            d.line([(52,83),(58,83)],fill=(49,24,22,255))
            d.line([(53,84),(57,84)],fill=(91,40,28,255))
            d.line([(54,85),(56,85)],fill=(131,65,40,255))
            d.point((52,82),fill=(194,164,127,255))
            d.point((53,82),fill=(219,188,146,255))
            d.point((58,84),fill=sample(im,57,84))
    return out,rect

def project(name,im):
    frames=[];flats=[]
    ribbon_rect=(96,63,160,117) if name=='senu' else (104,69,160,124)
    ribbon=patch(im,ribbon_rect)
    for expression in range(4):
        brows,browrects=eyebrows(im,name,expression)
        for eye in range(3):
            near,far,eyerects=eyes(im,name,eye,expression)
            for lip in range(3):
                lips,mouthrect=mouth(im,name,lip,expression)
                body=clear_mask(im,browrects+eyerects+[mouthrect,ribbon_rect])
                layers=[body,brows,near,far,lips,ribbon]
                if name=='senu':layers=[cel.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for cel in layers]
                flat=blank()
                for cel in layers:flat.alpha_composite(cel)
                frames.append(layers);flats.append(flat)
    tags=[]
    for ex,expression in enumerate(EXPRS):
        tags.append({'name':expression,'from':ex*9+1,'to':ex*9+9,'color':'bba271ff'})
    data=native.project_data(36,[1.0]*36,tags,False)
    data.update(size_x=160,size_y=192,fps=12,symmetry_points=[79.5,95.5])
    base=copy.deepcopy(data['layers'][0])
    data['layers']=[dict(copy.deepcopy(base),name=layer) for layer in LAYERS]
    for frame in data['frames']:frame['cels']=[{'opacity':1.0,'z_index':0} for _ in LAYERS]
    data['export_profile']['lines_count']='6'
    with ZipFile(ART/f'{name}.pxo','w',ZIP_DEFLATED) as archive:
        archive.writestr('mimetype','application/x-pixelorama')
        archive.writestr('data.json',json.dumps(data,ensure_ascii=False))
        for i,frame in enumerate(frames):
            for j,cel in enumerate(frame):archive.writestr(f'image_data/frames/{i+1}/layer_{j+1}',cel.tobytes())
    board=Image.new('RGBA',(640,192),'#14252c')
    for index in range(4):board.alpha_composite(flats[index*9],(index*160,0))
    board.resize((1280,384),Image.Resampling.NEAREST).convert('RGB').save(ROOT/f'qa/dialogue_{name}_expressions_v14.png')
    speaking=[]
    for eye,lip in [(0,0),(0,1),(0,2),(0,1),(0,0),(1,1),(2,2),(1,1),(0,2),(0,0)]:
        frame=Image.new('RGBA',SIZE,'#14252c');frame.alpha_composite(flats[eye*3+lip])
        speaking.append(frame.resize((320,384),Image.Resampling.NEAREST).convert('RGB'))
    speaking[0].save(ROOT/f'qa/dialogue_{name}_speaking_v14.gif',save_all=True,append_images=speaking[1:],duration=[300,110,130,100,150,70,90,70,150,350],loop=0,optimize=True)
    return flats

def build():
    ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    source=ART/'sources'
    senu=Image.open(source/'senu_base_original.png').convert('RGBA')
    fisher=Image.open(source/'fisherman_base.png').convert('RGBA')
    allflats={name:project(name,image) for name,image in [('senu',senu),('fisherman',fisher)]}
    manifest={'version':14,'canvas':[160,192],'atlas_size':[960,1152],'columns':6,'rows':6,
              'frames':36,'expressions':EXPRS,'eye_states':['open','half','closed'],
              'mouth_states':['closed','small','open'],'index':'expression*9 + eye*3 + mouth',
              'layers':LAYERS,'textures':{name:f'res://assets/ui/dialogue_v14/{name}.png' for name in allflats},
              'directions':{'senu':'right','fisherman':'left'},
              'provenance':'Existing native Senu portrait, mirrored toward dialogue centre; new fisherman generated with built-in image tool. Eye, brow and mouth pixels authored at native resolution in six editable Pixelorama layers. Final PNG exported by installed Pixelorama.'}
    (ART/'export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    for name,flats in allflats.items():
        assert len({im.tobytes() for im in flats})==36,(name,'duplicated pose')
        # Every region outside facial features is invariant across all36 cels.
        regions=[(0,115,160,192),(0,0,160,30)]
        for r in regions:assert len({im.crop(r).tobytes() for im in flats})==1,(name,r)
    print(json.dumps({'projects':[str(ART/f'{n}.pxo') for n in allflats],'frames_each':36,'layers':6,'dimensions':[960,1152]}))

if __name__=='__main__':build()
