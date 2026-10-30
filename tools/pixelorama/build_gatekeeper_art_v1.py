"""Local concept-derived pixel cels for the first Gatekeeper art review.

No network/models. Reference silhouettes are traced once at a fixed scale;
limbs, hands, cape hems and key-spear are authored at native pixel resolution.
Pixelorama owns the final atlas export. Manual changes are protected by hashes.
Run with the project's Pillow-capable Python, using -B.
"""
import copy
import hashlib
import io
import json
import math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
import build_pixelorama_project as pxo

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / 'art/pixelorama/porteiro_v1'
QA = ROOT / 'qa/porteiro_art_v1'
CELL = (160, 160)
PIVOT = (80, 140)
HEIGHT = 57
VERSION = 1
STEM = 'porteiro_v1'
LAYERS = ['Manto', 'Corpo e roupas', 'Rosto e cabelo', 'Chave-lança e mãos']
COLORS = ['171b1c','252825','343a35','4b5147',
          '211c1b','322723','49332b','604336','785542','916a50','ab8663','c7a77b',
          '2b191a','402021','57282a','713330','884534','9a5941',
          '39332c','514635','6d5c44','8a785a','a89673','c7b38c','dfcba3',
          '382e20','534027','705335','8b693c','ac844a','c9a461','dfbf7e']
PAL = ['#' + c for c in COLORS]
SOURCE = ROOT / 'docs/concept_art/porteiro_sem_nome/concept_02.png'
TRACES = {
    'front': [(382,57),(416,52),(442,61),(460,84),(473,115),(477,146),
              (463,167),(461,190),(481,219),(508,240),(531,253),(559,256),
              (580,249),(594,263),(593,282),(579,295),(553,295),(537,293),
              (526,330),(516,369),(530,401),(521,449),(513,509),(528,566),
              (512,603),(530,647),(512,681),(510,710),(527,741),(534,768),
              (510,780),(478,774),(457,770),(438,757),(413,743),(398,744),
              (391,773),(370,784),(341,790),(308,791),(280,784),(288,767),
              (300,750),(302,721),(276,744),(250,751),(246,722),(257,690),
              (251,670),(266,634),(247,640),(253,603),(261,571),(250,551),
              (256,517),(250,503),(260,463),(253,437),(264,397),(274,357),
              (276,305),(281,265),(287,228),(290,192),(301,161),(323,148),
              (346,139),(359,124),(362,95)],
    'side': [(1072,348),(1088,345),(1104,352),(1111,363),(1105,378),
             (1094,389),(1098,406),(1103,426),(1108,448),(1114,469),
             (1123,488),(1133,496),(1138,509),(1128,514),(1120,503),
             (1111,495),(1114,528),(1110,555),(1109,583),(1112,609),
             (1117,633),(1119,661),(1126,672),(1110,682),(1095,681),
             (1082,676),(1065,681),(1048,680),(1037,674),(1046,667),
             (1047,640),(1030,651),(1033,621),(1028,599),(1036,570),
             (1032,546),(1038,518),(1037,496),(1044,470),(1043,444),
             (1039,422),(1046,403),(1047,386),(1057,369)],
    'back': [(932,341),(948,341),(960,352),(966,369),(972,379),
             (997,389),(1006,414),(1005,449),(1013,487),(1008,520),
             (1014,550),(1017,582),(1008,607),(1013,635),(1003,658),
             (1008,675),(989,684),(974,682),(967,670),(954,672),
             (948,681),(927,684),(903,679),(887,677),(895,662),
             (895,637),(881,645),(888,611),(879,595),(887,572),
             (880,549),(887,524),(884,500),(888,473),(889,451),
             (885,431),(895,416),(898,394),(914,384),(925,371),
             (924,354)]
}


def digest(blob): return hashlib.sha256(blob).hexdigest()


def encoded(im):
    buffer = io.BytesIO()
    im.save(buffer, format='PNG')
    return buffer.getvalue()


def quantize(im):
    pal = Image.new('P', (1, 1))
    rgb = [int(c[i:i+2], 16) for c in COLORS for i in (0, 2, 4)]
    pal.putpalette(rgb + rgb[:3] * (256 - len(COLORS)))
    alpha = im.getchannel('A').point(lambda a: 255 if a >= 110 else 0)
    result = im.convert('RGB').quantize(palette=pal, dither=Image.Dither.NONE).convert('RGBA')
    result.putalpha(alpha)
    return result


def reference_body(name):
    source = Image.open(SOURCE).convert('RGBA')
    mask = Image.new('L', source.size)
    ImageDraw.Draw(mask).polygon(TRACES[name], fill=255)
    source.putalpha(mask)
    bounds = mask.getbbox()
    source = source.crop(bounds)
    # Only this preparation step samples the source. Animation never scales it.
    reduced = source.resize((round(source.width * HEIGHT / source.height), HEIGHT), Image.Resampling.LANCZOS)
    body = quantize(ImageEnhance.Brightness(reduced).enhance(1.18))
    # Native retouch: at 57px the eyes/nose/beard must survive source reduction.
    # These coordinates are relative to the fixed world-pixel registration.
    canvas=blank()
    ox,oy=PIVOT[0]-body.width//2,PIVOT[1]-HEIGHT
    canvas.alpha_composite(body,(ox,oy))
    d=ImageDraw.Draw(canvas)
    if name=='front':
        d.polygon([(80,87),(83,87),(85,89),(84,92),(82,94),(79,92),(79,89)],fill='#916a50')
        stroke(d,[(83,88),(84,90),(83,91)],'#c7a77b')
        stroke(d,[(79,89),(81,89)],'#322723')
        d.point((83,89),'#322723')
        d.point((81,91),'#ab8663')
        stroke(d,[(80,92),(82,93),(83,92)],'#49332b')
        stroke(d,[(78,85),(81,84),(84,85),(85,88)],'#252825',2)
        stroke(d,[(78,86),(77,90),(78,95)],'#322723',2)
        d.point((79,86),'#6d5c44')
    elif name=='side':
        d.polygon([(82,87),(84,88),(84,89),(86,90),(84,91),(84,93),(82,93),(81,90)],fill='#916a50')
        stroke(d,[(84,90),(85,90)],'#c7a77b')
        d.point((83,89),'#211c1b')
        stroke(d,[(83,92),(84,92)],'#49332b')
        stroke(d,[(80,85),(82,85),(83,86)],'#252825',2)
        stroke(d,[(80,86),(79,90),(80,95)],'#322723',2)
        d.point((80,87),'#6d5c44')
    return canvas.crop((ox,oy,ox+body.width,oy+HEIGHT))


def blank(): return Image.new('RGBA', CELL)


def shift_piece(dest, src, bounds, offset):
    piece = src.crop(bounds)
    dest.alpha_composite(piece, (bounds[0] + offset[0], bounds[1] + offset[1]))


def stroke(d, points, fill, width=1):
    d.line(points, fill=fill, width=width)


def limb(d, points, width, dark, light):
    # Rounded joints and directional edge light; no whole-character rotation.
    stroke(d, points, dark, width + 2)
    for x, y in points[1:-1]:
        r = (width + 1) // 2
        d.ellipse((x-r, y-r, x+r, y+r), fill=dark)
    stroke(d, points, light, width)
    stroke(d, [(x-1, y) for x, y in points], '#604336', 1)


def weapon(image, grip, angle, sway=0):
    """Physical key-halberd, always in the same hand, all pixels native."""
    d = ImageDraw.Draw(image)
    direction = (math.cos(angle), math.sin(angle))
    normal = (-direction[1], direction[0])
    def point(u, v=0): return (round(grip[0] + direction[0]*u + normal[0]*v), round(grip[1] + direction[1]*u + normal[1]*v))
    def path(values, color, width=1): stroke(d, [point(*v) for v in values], color, width)
    path([(-27, 0),(33, 0)], '#171b1c', 3)
    path([(-27, 0),(33, 0)], '#6d5c44')
    path([(-26, -1),(31, -1)], '#a89673')
    for at in (-24,-8,9,19): path([(at,-1),(at,1)], '#c9a461')
    # Crescent blade with hollow key head. The dark interior is transparent.
    outline = [(24,-1),(25,-5),(28,-7),(33,-8),(37,-6),(40,-3),
               (40,1),(38,4),(34,6),(31,6),(34,3),(36,0),(35,-3),
               (32,-5),(29,-4),(28,-1)]
    d.polygon([point(u,v) for u,v in outline], fill='#171b1c')
    path([(25,-3),(28,-6),(33,-7),(37,-5),(39,-2),(39,1),(37,4),(34,5)], '#ac844a')
    path([(29,-6),(33,-6),(36,-4)], '#dfbf7e')
    path([(24,0),(34,0)], '#c9a461', 2)
    for at in (25,28,31): path([(at,0),(at,4)], '#ac844a')
    # Bell strings hang towards gravity, independently of spear orientation.
    for at, length in ((17,5),(27,4)):
        x,y=point(at,2)
        stroke(d, [(x,y),(x+sway,y+length)], '#705335')
        bx,by=x+sway,y+length
        d.rectangle((bx-1,by,bx+1,by+1), fill='#ac844a')
        d.point((bx-1,by),'#dfbf7e')
        d.point((bx,by+2),'#534027')
    # Two bands at the palm make contact unambiguous.
    d.rectangle((grip[0]-1,grip[1]-1,grip[0]+1,grip[1]+1),fill='#916a50')
    d.point((grip[0]-1,grip[1]-1),'#c7a77b')


def still(name):
    body = reference_body(name)
    x = PIVOT[0] - body.width // 2
    y = PIVOT[1] - HEIGHT
    layers=[blank() for _ in LAYERS]
    layers[1].alpha_composite(body,(x,y))
    if name == 'side':
        weapon(layers[3],(94,113),-math.pi/2)
    elif name == 'front':
        weapon(layers[3],(91,105),-math.pi/2)
    else:
        weapon(layers[0],(90,113),-math.pi/2)
    return layers, {'body_bounds':[x,y,x+body.width,y+HEIGHT]}


def side_pose(kind, index):
    base=reference_body('side')
    # This same face/torso is retained in every cel. Gait changes anatomy below
    # the hem and reauthors the arm; moving the cape is secondary motion only.
    src=blank()
    src.alpha_composite(base,(PIVOT[0]-base.width//2,PIVOT[1]-HEIGHT))
    layers=[blank() for _ in LAYERS]
    step=[-4,-3,0,3,4,3,0,-3][index] if kind=='walk' else 0
    lift=[0,0,1,2,0,0,1,2][index] if kind=='walk' else 0
    lean=0 if kind=='walk' else [0,-1,-2,3,2,0][index]
    body_drop=[0,1,0,0,0,1,0,0][index] if kind=='walk' else [0,1,1,2,1,0][index]
    # Cape forms stay attached at the shoulders. Tail folds swing 1-2px.
    tail=round(math.sin(index*math.tau/8)) if kind=='walk' else [0,-1,-2,-3,-1,1][index]
    shift_piece(layers[0],src,(69,95,79,132),(lean,body_drop))
    shift_piece(layers[0],src,(69,132,79,139),(tail+lean,0))
    shift_piece(layers[1],src,(77,95,87,126),(lean,body_drop))
    shift_piece(layers[2],src,(73,83,88,96),(lean,body_drop))
    d=ImageDraw.Draw(layers[1])
    # Legs under the robe: opposite foot contacts, raised toe in passing cels.
    if kind=='walk':
        far=(79-step,139-(lift if step<0 else 0))
        near=(81+step,140-(lift if step>0 else 0))
    else:
        far=(75,139)
        near=(85,140)
    limb(d,[(78+lean,123+body_drop),(far[0]+1,131),(far[0],far[1]-2)],2,'#211c1b','#514635')
    limb(d,[(82+lean,124+body_drop),(near[0]-1,132),(near[0],near[1]-2)],2,'#211c1b','#6d5c44')
    for foot,color in ((far,'#604336'),(near,'#916a50')):
        d.line([(foot[0]-1,foot[1]),(foot[0]+3,foot[1])],fill='#211c1b',width=2)
        d.line([(foot[0],foot[1]-1),(foot[0]+2,foot[1]-1)],fill=color)
    # Skirt panels over thighs, retaining texture from the traced reference.
    shift_piece(layers[1],src,(77,121,86,133),(lean,body_drop))
    d=ImageDraw.Draw(layers[1])
    for x,z,col in [(78,126,'#514635'),(81,128,'#a89673'),(84,125,'#705335')]:
        stroke(d,[(x+lean,z+body_drop),(x+lean+tail,z+7)],col)
    # Freshly authored flesh arm and weapon grip in each combat cel.
    shoulder=(83+lean,99+body_drop)
    if kind=='walk':
        grip=(95+lean,113+body_drop)
        elbow=(88+lean,107+body_drop)
        angle=-math.pi/2 + math.sin(index*math.tau/8)*.025
    else:
        grip=[(95,113),(93,110),(91,106),(108,105),(106,108),(95,113)][index]
        elbow=[(89,106),(86,104),(85,102),(96,103),(95,106),(89,106)][index]
        angle=[-math.pi/2,-.95,-.40,.04,.15,-math.pi/2][index]
    limb(d,[shoulder,elbow,grip],2,'#322723','#916a50')
    for x,y in [elbow, (elbow[0]+1,elbow[1]+3)]: d.point((x,y),'#49332b')
    # Worn shoulder bronze, not a full armored breastplate.
    stroke(d,[(81+lean,99+body_drop),(83+lean,98+body_drop),(85+lean,100+body_drop)],'#ac844a')
    # Belt plates, string and small bells remain on the same belt positions.
    for x in (79,83):
        d.rectangle((x+lean,117+body_drop,x+lean+1,120+body_drop),fill='#8b693c')
        d.point((x+lean,118+body_drop),'#c9a461')
    weapon(layers[3],grip,angle,tail)
    return layers, {'feet':[list(far),list(near)],'grip':list(grip),
                    'tip_angle':angle,'body_lean':lean,'body_drop':body_drop}


def flatten(layers):
    out=blank()
    for layer in layers: out.alpha_composite(layer)
    return out


def native_blob(cels,tags,durations,columns=8):
    data=pxo.project_data(len(cels),[s*10 for s in durations],tags,False)
    data.update(size_x=CELL[0],size_y=CELL[1],fps=10.,current_layer=1)
    template=data['layers'][0]
    data['layers']=[]
    for name in LAYERS:
        layer=copy.deepcopy(template)
        layer['name']=name
        data['layers'].append(layer)
    for frame in data['frames']:
        frame['cels']=[{'opacity':1.,'z_index':0} for _ in LAYERS]
    data['export_profile']['lines_count']=str(columns)
    data['symmetry_points']=[79.5,79.5]
    buffer=io.BytesIO()
    with ZipFile(buffer,'w',ZIP_DEFLATED) as z:
        z.writestr('mimetype','application/x-pixelorama')
        z.writestr('data.json',json.dumps(data,ensure_ascii=False))
        for i,layers in enumerate(cels):
            for j,im in enumerate(layers): z.writestr(f'image_data/frames/{i+1}/layer_{j+1}',im.tobytes())
    return buffer.getvalue()


def text(d,at,value,size=16,color='#c7b38c'):
    font=ImageFont.truetype(str(ROOT/'assets/fonts/PixelOperatorHB.ttf'),size)
    d.text(at,value,font=font,fill=color)


def previews(frames):
    board=Image.new('RGB',(1120,700),'#101b20')
    d=ImageDraw.Draw(board)
    text(d,(28,19),'O PORTEIRO SEM NOME',32)
    text(d,(28,58),'Etapa 2 / primeira prova de arte / conceitos do jogador / producao local',18,'#8a9b98')
    labels=['Frente','Perfil / direcao-piloto','Costas']
    for i in range(3):
        anchor=(190+i*350,430)
        d.line((anchor[0]-100,anchor[1],anchor[0]+100,anchor[1]),fill='#3c4a4b')
        # One source pixel = four screen pixels. No smoothing.
        crop=frames[i].crop((40,45,130,145)).resize((360,400),Image.Resampling.NEAREST)
        board.paste(crop,(anchor[0]-160,anchor[1]-380),crop)
        text(d,(anchor[0]-60,453),labels[i],18)
        tiny=frames[i].crop((40,45,130,145))
        board.paste(tiny,(anchor[0]-40,492),tiny)
    text(d,(28,620),'Acima: ampliacao 4x  |  abaixo: pixels nativos  |  corpo: 57 px',18)
    text(d,(28,649),'Estudo para avaliacao. Ainda sem oito direcoes, combate ou troca na partida.',18,'#8a9b98')
    board.save(QA/'vistas.png')
    for name,indices in [('caminhada',range(3,11)),('perfuracao',range(11,17))]:
        count=len(indices)
        sheet=Image.new('RGB',(count*190,300),'#101b20')
        sd=ImageDraw.Draw(sheet)
        sequence=[]
        for col,idx in enumerate(indices):
            # The timeline uses 2x to keep every native weapon pixel in view.
            im=frames[idx].crop((50,65,145,145)).resize((190,160),Image.Resampling.NEAREST)
            sheet.paste(im,(col*190,54),im)
            text(sd,(col*190+12,230),f'{col+1:02} / {name}',16)
            stage=Image.new('RGB',(570,480),'#101b20')
            scaled=frames[idx].crop((50,65,145,145)).resize((570,480),Image.Resampling.NEAREST)
            stage.paste(scaled,(0,0),scaled)
            sequence.append(stage)
        sheet.save(QA/f'{name}_quadros.png')
        timing=110 if name=='caminhada' else [220,330,150,90,170,330]
        sequence[0].save(QA/f'{name}.gif',save_all=True,append_images=sequence[1:],duration=timing,loop=0,optimize=False)


def build():
    ART.mkdir(parents=True,exist_ok=True)
    QA.mkdir(parents=True,exist_ok=True)
    cels=[]; metadata=[]
    for name in ('front','side','back'):
        layers,info=still(name)
        cels.append(layers); metadata.append({'clip':'idle','direction':name,**info})
    for kind,count in (('walk',8),('thrust',6)):
        for i in range(count):
            layers,info=side_pose(kind,i)
            cels.append(layers); metadata.append({'clip':kind,'direction':'right','pose':i,**info})
    frames=[flatten(layers) for layers in cels]
    durations=[.4,.4,.4]+[.11]*8+[.22,.33,.15,.09,.17,.33]
    tags=[{'name':n,'from':a,'to':b,'color':'ac844aff'} for n,a,b in
          [('idle_front',1,1),('idle_right',2,2),('idle_back',3,3),('walk_right',4,11),('thrust_right',12,17)]]
    manifest={'version':VERSION,'review_only':True,'canvas':list(CELL),'pivot':list(PIVOT),'game_scale':1.,
              'body_height':HEIGHT,'columns':8,'frames':17,'texture':f'res://assets/sprites/{STEM}.png',
              'source':f'art/pixelorama/{STEM}/{STEM}.pxo','directions_ready':['front','right','back'],
              'clips':{'idle':{'front':[0],'right':[1],'back':[2]},'walk':{'right':list(range(3,11))},'thrust':{'right':list(range(11,17))}},
              'durations':durations,'contact_frame':14,'contact_seconds':.70,'walk_stride':24.,'palette':COLORS,
              'reference_sha256':digest(SOURCE.read_bytes()),'frame_metadata':metadata,
              'frame_regions':[[i%8*160,i//8*160,160,160] for i in range(17)]}
    products={f'{STEM}.pxo':native_blob(cels,tags,durations),
              'export_plan.json':(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n').encode(),
              'trace_guides.json':(json.dumps(TRACES,indent=2)+'\n').encode()}
    products.update({f'cels/{i:02}.png':encoded(im) for i,im in enumerate(frames)})
    lock=ART/'generated_hashes.json'
    old=json.loads(lock.read_text()) if lock.exists() else {}
    for name in products:
        dest=ART/name
        if dest.exists() and digest(dest.read_bytes())!=old.get(name):
            raise SystemExit(f'Manual or untracked edit protected: {dest}. Copy to a new version before rebuilding.')
    for name,blob in products.items():
        dest=ART/name
        dest.parent.mkdir(parents=True,exist_ok=True)
        dest.write_bytes(blob)
    lock.write_text(json.dumps({name:digest(blob) for name,blob in products.items()},indent=2)+'\n')
    previews(frames)
    print(json.dumps({'frames':len(frames),'project':str(ART/f'{STEM}.pxo'),'qa':str(QA)}))


if __name__=='__main__': build()
