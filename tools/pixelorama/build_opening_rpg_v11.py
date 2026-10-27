"""Original low-resolution opening art. No game props or sprites are reused.

The editable Pixelorama source contains separate anatomy/material layers.
The installed Pixelorama, not this preparation script, exports the game atlas.
"""
import copy
import json
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw, ImageFont
import build_pixelorama_project as native

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/opening_rpg_v11'
OUT = ROOT / 'assets/cinematics/rpg_v11'
SIZE = (128, 128)
P = {
 'ink':'17272e', 'edge':'263b3e', 'deep':'334a4d', 'stone_d':'435d5c',
 'stone':'5a736a','stone_l':'7f8c7a','stone_h':'a4aa8c','stone_chip':'c4c0a0',
 'water':'244750','teal_d':'27434a','teal':'365f62','teal_l':'54817a',
 'teal_h':'83a89a','wood_black':'302b26','wood_d':'49392c','wood_s':'654b33',
 'wood':'82613f','wood_l':'a48251','wood_h':'c6a66d','wood_warm':'9b7348',
 'rope_d':'765d3b','rope':'b39b6b','rope_l':'d6c292','bronze_d':'5f5037',
 'bronze':'987545','bronze_l':'c5a065','bronze_h':'e2bf7c','ivory_d':'9d9678',
 'ivory':'d5c9a0','ivory_h':'eee1b6','ochre_d':'675033','ochre':'9c773c',
 'ochre_l':'bd9751','ochre_h':'d5b56d','skin_d':'704a34','skin_s':'98633f',
 'skin':'ba8050','skin_l':'d5a06b','skin_h':'e4b780','hair':'292a25',
 'hair_l':'494231','pants_d':'303f42','pants':'485958','pants_l':'66766b',
 'fire_d':'ad6537','fire':'e8a04e','fire_l':'f6ce7b','fire_h':'fff0b4'}
C = {name: '#'+value for name,value in P.items()}
LAYERS = ['Terreno e objetos','Pernas e botas','Manto e bolsa','Túnica e braços','Rosto e lenço','Acabamentos']

def blank(): return Image.new('RGBA', SIZE)
def polygon(d, points, color): d.polygon(points, fill=C[color])
def line(d, points, color, width=1): d.line(points, fill=C[color], width=width)

def floor(wood=False):
    image=blank(); d=ImageDraw.Draw(image)
    points=[(32,112),(64,96),(95,112),(64,127)]
    polygon(d,points,'wood' if wood else 'stone')
    if wood:
        for step in range(1,6):
            x=32+step*5; y=112-step*3
            line(d,[(x,y),(x+31,y+16)],'wood_d')
            line(d,[(x+1,y),(x+31,y+15)],'wood_l')
        for x,y in [(50,108),(62,119),(73,107),(83,113)]:
            line(d,[(x,y),(x+5,y+2)],'wood_s')
        for x,y in [(45,111),(78,110),(64,121)]: d.point((x,y),fill=C['ink'])
    else:
        polygon(d,[(34,112),(49,104),(64,112),(49,120)],'stone_l')
        polygon(d,[(65,97),(94,112),(79,119),(50,104)],'stone')
        line(d,[(49,104),(79,119)],'stone_d')
        line(d,[(49,120),(79,104)],'stone_d')
        line(d,[(67,104),(73,107),(71,110)],'stone_d')
        line(d,[(43,112),(47,110)],'stone_h')
        line(d,[(72,117),(76,119)],'stone_h')
        d.point((58,119),fill=C['stone_chip'])
    line(d,[(32,112),(64,96),(95,112)],'wood_h' if wood else 'stone_h')
    line(d,[(95,112),(64,127),(32,112)],'wood_d' if wood else 'deep')
    return image

def sailor(pose):
    images=[blank() for _ in LAYERS]
    shadow=ImageDraw.Draw(images[0]); shadow.ellipse((55,109,74,114),fill=C['edge'])
    legs=ImageDraw.Draw(images[1])
    # Distinct leg silhouettes, planted/contact/crossing poses; constant body scale.
    if pose==0:
        rear=[(60,96),(64,97),(63,108),(59,110),(58,109),(59,102)]
        front=[(65,96),(69,96),(69,106),(72,110),(70,112),(65,111),(65,104)]
        boots=[[(58,107),(63,107),(63,110),(60,112),(55,112),(55,110)],[(65,107),(69,107),(73,110),(73,112),(65,112)]]
    elif pose==1:
        rear=[(60,96),(64,97),(64,102),(60,107),(57,108),(56,105),(60,101)]
        front=[(65,96),(68,96),(70,102),(71,108),(68,111),(65,110),(66,104)]
        boots=[[(55,104),(59,104),(61,108),(59,110),(55,109),(53,107)],[(67,107),(71,107),(74,110),(73,112),(66,112)]]
    else:
        rear=[(60,96),(64,96),(65,102),(64,108),(60,110),(58,109),(60,103)]
        front=[(65,96),(69,97),(68,103),(72,105),(72,108),(69,109),(65,106),(64,102)]
        boots=[[(59,107),(63,107),(64,110),(62,112),(56,112),(55,111)],[(68,104),(72,104),(75,106),(75,108),(70,109),(68,107)]]
    for points in [rear,front]: legs.polygon(points,fill=C['pants'],outline=C['ink'])
    line(legs,[(61,98),(61,103)],'pants_l')
    line(legs,[(67,98),(67,104)],'pants')
    for points in boots: polygon(legs,points,'wood_d')
    for points in boots: line(legs,points[:2],'wood_l')
    mantle=ImageDraw.Draw(images[2])
    swing=[0,-1,1][pose]
    polygon(mantle,[(59,83),(65,83),(68,90),(68+swing,100),(61+swing,103),(55+swing,100),(55,91)],'ink')
    polygon(mantle,[(59,84),(64,84),(66,91),(65+swing,100),(61+swing,101),(57+swing,99),(57,91)],'ochre_d')
    polygon(mantle,[(59,85),(61,85),(61,97),(59+swing,99),(57+swing,97)],'ochre')
    line(mantle,[(59,86),(59,94)],'ochre_l')
    polygon(mantle,[(58,94),(61,95),(61,100),(58,101),(56,99),(56,96)],'wood_d')
    line(mantle,[(57,96),(60,96)],'bronze_l')
    torso=ImageDraw.Draw(images[3])
    polygon(torso,[(61,83),(66,83),(70,86),(70,92),(68,95),(69,99),(59,99),(59,94),(57,89),(58,86)],'ink')
    polygon(torso,[(61,84),(65,84),(68,86),(68,92),(66,94),(67,97),(60,97),(61,91),(59,88)],'ochre')
    polygon(torso,[(62,84),(64,84),(65,92),(64,97),(61,96),(62,91)],'ochre_l')
    line(torso,[(66,88),(67,92),(65,95)],'ochre_d')
    polygon(torso,[(60,84),(62,83),(65,84),(64,87),(62,88)],'ivory')
    line(torso,[(60,95),(68,95)],'wood_d',2)
    torso.point((64,95),fill=C['bronze_h'])
    # Arms counter-swing with the legs. Hands are shaped, not square blocks.
    far=[[(58,86),(60,88),(58,94),(56,95),(55,93)],[(58,86),(60,88),(57,92),(55,92),(55,90)],[(58,86),(60,88),(60,94),(58,96),(56,95),(57,92)]][pose]
    near=[[(67,86),(70,87),(71,93),(69,98),(67,98),(67,95),(68,92)],[(67,86),(70,87),(71,90),(73,93),(72,96),(70,95),(68,92)],[(67,86),(70,87),(70,91),(67,94),(65,94),(64,92),(67,89)]][pose]
    polygon(torso,far,'skin_s'); polygon(torso,near,'skin')
    line(torso,near[:3],'skin_l')
    for point in far[-2:]: torso.point(point,fill=C['skin_d'])
    head=ImageDraw.Draw(images[4])
    polygon(head,[(61,75),(64,74),(67,75),(69,78),(68,81),(66,84),(62,84),(60,81),(59,78)],'ink')
    polygon(head,[(61,77),(65,76),(67,77),(67,80),(69,80),(68,82),(65,84),(62,82),(61,80)],'skin')
    polygon(head,[(61,78),(62,80),(62,82),(65,83),(63,84),(61,83),(60,80)],'skin_s')
    line(head,[(65,77),(67,78),(67,79)],'skin_l')
    head.point((66,79),fill=C['ink'])
    head.point((67,81),fill=C['skin_h'])
    line(head,[(64,82),(66,82)],'hair')
    polygon(head,[(61,75),(64,74),(67,75),(68,77),(66,77),(65,76),(62,77),(60,78)],'hair')
    line(head,[(60,77),(63,76),(67,77)],'ivory')
    line(head,[(60,78),(59,81),(57,83)],'ivory_d')
    head.point((57,84),fill=C['ivory'])
    finish=ImageDraw.Draw(images[5])
    finish.point((64,75),fill=C['hair_l'])
    finish.point((62,80),fill=C['skin_l'])
    finish.point((66,94),fill=C['bronze'])
    return images

def boat():
    image=blank();d=ImageDraw.Draw(image)
    # Open ferry hull, low seats and a single long oar; new geometry throughout.
    polygon(d,[(13,80),(35,69),(75,73),(113,86),(115,94),(103,104),(71,112),(35,103),(16,93)],'ink')
    polygon(d,[(15,80),(35,71),(74,75),(112,87),(112,94),(101,102),(70,109),(35,101),(18,92)],'wood_s')
    polygon(d,[(15,81),(35,73),(75,77),(110,88),(90,98),(69,102),(36,95),(19,87)],'wood_d')
    polygon(d,[(21,82),(36,76),(74,80),(103,89),(88,96),(69,99),(39,93)],'wood_black')
    polygon(d,[(27,82),(38,78),(74,82),(97,90),(84,94),(67,97),(40,91)],'wood')
    for a,b in [((20,88),(35,96)),((35,96),(70,105)),((70,105),(104,96)),((35,99),(69,108)),((75,107),(101,99))]: line(d,[a,b],'wood_l')
    line(d,[(17,81),(36,73),(75,77),(110,88),(90,98),(69,102),(36,95),(17,86)],'wood_h')
    line(d,[(20,82),(37,75),(74,79),(105,89)],'wood_l')
    polygon(d,[(43,79),(48,80),(41,93),(36,92)],'wood_l')
    line(d,[(43,80),(38,91)],'wood_h')
    polygon(d,[(75,83),(81,85),(72,98),(66,97)],'wood_l')
    line(d,[(77,85),(69,96)],'wood_h')
    for a,b in [((35,96),(34,101)),((53,100),(52,105)),((88,101),(89,106)),((105,91),(107,97))]: line(d,[a,b],'wood_d',2)
    # A teal rolled blanket, rope coil and tiny brass rowlock.
    polygon(d,[(90,88),(97,87),(103,90),(102,93),(95,94),(90,92)],'teal_d')
    line(d,[(92,89),(97,89),(101,91)],'teal_l')
    d.ellipse((25,81,34,86),outline=C['rope'],width=1)
    d.point((29,84),fill=C['rope_l'])
    line(d,[(20,78),(65,92)],'wood_d',3)
    line(d,[(20,77),(65,91)],'wood_h')
    polygon(d,[(12,52),(17,51),(33,63),(32,67),(28,69),(14,58)],'wood_d')
    polygon(d,[(14,53),(17,53),(31,64),(29,67),(16,57)],'wood_l')
    line(d,[(29,65),(68,94)],'wood_d',3)
    line(d,[(30,64),(69,93)],'wood_h')
    d.ellipse((61,89,66,93),outline=C['bronze_l'])
    return image

def lantern():
    image=blank();d=ImageDraw.Draw(image)
    d.ellipse((54,108,75,114),fill=C['edge'])
    polygon(d,[(55,108),(62,105),(69,106),(74,110),(66,113),(56,111)],'bronze_d')
    line(d,[(56,108),(63,107),(72,110),(65,111)],'bronze_l')
    polygon(d,[(61,96),(67,96),(68,107),(64,109),(60,107)],'teal_d')
    line(d,[(62,98),(62,106)],'teal_l')
    polygon(d,[(57,79),(60,76),(68,76),(72,80),(72,93),(68,99),(60,98),(56,94)],'ink')
    polygon(d,[(59,80),(69,80),(70,93),(66,96),(60,94)],'bronze')
    polygon(d,[(60,82),(67,81),(69,91),(66,94),(61,92)],'fire_d')
    polygon(d,[(62,90),(62,85),(64,80),(66,86),(67,91),(65,94)],'fire')
    polygon(d,[(63,88),(64,84),(65,88),(65,92),(63,92)],'fire_l')
    d.point((64,91),fill=C['fire_h'])
    line(d,[(58,80),(59,93),(62,96)],'bronze_h')
    line(d,[(69,81),(70,93),(67,97)],'bronze_d')
    polygon(d,[(57,79),(61,76),(67,76),(72,80),(68,82),(60,82)],'teal_d')
    line(d,[(59,78),(65,77),(70,79)],'bronze_l')
    d.arc((60,71,68,81),180,360,fill=C['ink'],width=2)
    d.arc((61,72,67,80),180,360,fill=C['bronze_l'],width=1)
    line(d,[(59,95),(67,98),(71,94)],'bronze_l')
    return image

def sign():
    image=blank();d=ImageDraw.Draw(image)
    d.ellipse((55,109,76,114),fill=C['edge'])
    polygon(d,[(61,85),(66,85),(66,108),(71,110),(70,112),(58,112),(57,110),(61,107)],'wood_d')
    line(d,[(62,88),(62,109)],'wood_l')
    line(d,[(65,94),(65,107)],'wood_s')
    polygon(d,[(45,74),(74,74),(84,82),(74,90),(45,90),(43,87),(43,77)],'ink')
    polygon(d,[(46,76),(73,76),(81,82),(73,88),(46,88),(45,86),(45,78)],'wood')
    polygon(d,[(48,77),(72,77),(78,82),(72,86),(48,86)],'teal_d')
    line(d,[(46,76),(73,76),(81,82)],'wood_h')
    line(d,[(46,88),(73,88)],'wood_d')
    d.ellipse((57,79,63,85),outline=C['bronze_h'])
    for a,b in [((60,77),(60,78)),((60,86),(60,87)),((55,82),(56,82)),((64,82),(66,82)),((56,78),(57,79)),((64,79),(65,78)),((56,86),(57,85)),((64,85),(65,86))]: line(d,[a,b],'bronze_l')
    line(d,[(70,80),(73,82),(70,84)],'ivory')
    for xy in [(47,78),(47,86),(73,78),(73,86)]: d.point(xy,fill=C['bronze'])
    line(d,[(59,91),(67,93),(59,95),(67,97)],'rope')
    return image

def build():
    ART.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
    layers=[]
    for item in [floor(),floor(True)]: layers.append([item]+[blank() for _ in LAYERS[1:]])
    layers.extend(sailor(i) for i in range(3))
    for item in [boat(),lantern(),sign()]: layers.append([item]+[blank() for _ in LAYERS[1:]])
    tags=[{'name':n,'from':i+1,'to':i+1,'color':'c5a065ff'} for i,n in enumerate(['stone','wood','ferryman_idle','ferryman_step_left','ferryman_step_right','ferry_boat','oil_lantern','sanctuary_sign'])]
    data=native.project_data(8,[1.0]*8,tags,False)
    data.update(size_x=128,size_y=128,fps=8,symmetry_points=[63.5,63.5])
    base=data['layers'][0]
    data['layers']=[dict(copy.deepcopy(base),name=name) for name in LAYERS]
    for frame in data['frames']: frame['cels']=[{'opacity':1.0,'z_index':0} for _ in LAYERS]
    data['export_profile']['lines_count']='4'
    with ZipFile(ART/'intro_atlas.pxo','w',ZIP_DEFLATED) as archive:
        archive.writestr('mimetype','application/x-pixelorama')
        archive.writestr('data.json',json.dumps(data,ensure_ascii=False))
        for i,frame in enumerate(layers):
            for j,cel in enumerate(frame): archive.writestr(f'image_data/frames/{i+1}/layer_{j+1}',cel.tobytes())
    frames=[]
    for frame in layers:
        flat=blank()
        for cel in frame: flat.alpha_composite(cel)
        frames.append(flat)
    for i,frame in enumerate(frames):
        assert frame.getchannel('A').getbbox(),i
        assert set(frame.getchannel('A').get_flattened_data()) <= {0,255},i
    contact=Image.new('RGBA',(512,256),'#142830')
    for i,frame in enumerate(frames): contact.alpha_composite(frame,((i%4)*128,(i//4)*128))
    preview=contact.resize((1024,512),Image.Resampling.NEAREST).convert('RGB')
    labels=['0 Pedra','1 Madeira','2 Barqueiro parado','3 Passo esquerdo','4 Passo direito','5 Barca original','6 Lamparina','7 Santuario']
    draw=ImageDraw.Draw(preview)
    for i,label in enumerate(labels): draw.text(((i%4)*256+12,(i//4)*256+10),label,fill='#d5c9a0')
    preview.save(ROOT/'qa/opening_rpg_v11_contact_2x.png')
    manifest={'canvas':[128,128],'atlas_size':[512,256],'columns':4,'frames':8,'pivot':[64,112],
      'floor_region':[32,96,64,32],'frame_order':[t['name'] for t in tags],
      'source':'art/pixelorama/opening_rpg_v11/intro_atlas.pxo','texture':'res://assets/cinematics/rpg_v11/intro_atlas.png',
      'palette':P,'layers':LAYERS,'provenance':'Original hand-placed native-resolution pixel art; layered editable Pixelorama project. Final PNG exported by installed Pixelorama.'}
    (ART/'export_plan.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
    print(json.dumps({'native':str(ART/'intro_atlas.pxo'),'frames':8,'layers':6,'palette_colors':len(P),'bounds':[frame.getbbox() for frame in frames]},ensure_ascii=False))

if __name__=='__main__':build()
