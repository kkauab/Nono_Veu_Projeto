"""Trim the actual Pixelorama export into a compact runtime atlas."""
from pathlib import Path
from PIL import Image
import json,sys,hashlib,copy
ROOT=Path(__file__).resolve().parents[2]
VERSION=int(sys.argv[2]) if len(sys.argv)>2 else 7
assert VERSION in [7,8,9]
STEM=f'porteiro_live_v{VERSION}';ART=ROOT/'art/pixelorama'/STEM
def sha(blob):return hashlib.sha256(blob).hexdigest()
def run():
    input_path=Path(sys.argv[1]);raw_by_direction={}
    raw=None
    if input_path.suffix=='.json':
        for direction,path in json.loads(input_path.read_text(encoding='utf-8-sig')).items():raw_by_direction[direction]=Image.open(path).convert('RGBA')
    else:raw=Image.open(input_path).convert('RGBA')
    plan=json.loads((ART/'export_plan.json').read_text(encoding='utf8'))
    tiles=[]
    counts={}
    for index,region in enumerate(plan['frame_regions']):
        if raw_by_direction:
            direction=plan['frame_metadata'][index]['direction'];local=counts.get(direction,0);counts[direction]=local+1
            x,y,w,h=local%14*192,local//14*192,192,192;frame=raw_by_direction[direction].crop((x,y,x+w,y+h))
        else:
            x,y,w,h=region;frame=raw.crop((x,y,x+w,y+h))
        box=frame.getbbox()
        if box is None:raise SystemExit('Empty live cel '+str(index))
        tiles.append((index,box,frame.crop(box)))
    width=2048;x=2;y=2;row_height=0;placements={}
    for index,box,tile in sorted(tiles,key=lambda value:(-value[2].height,-value[2].width,value[0])):
        if x+tile.width+2>width:x=2;y+=row_height+2;row_height=0
        placements[index]=(x,y);x+=tile.width+2;row_height=max(row_height,tile.height)
    height=((y+row_height+33)//32)*32
    atlas=Image.new('RGBA',(width,height))
    regions=[None]*len(tiles);offsets=[None]*len(tiles)
    for index,box,tile in tiles:
        x,y=placements[index];atlas.alpha_composite(tile,(x,y));regions[index]=[x,y,tile.width,tile.height]
        offsets[index]=[box[0]-plan['pivot'][0],box[1]-plan['pivot'][1]]
    runtime=copy.deepcopy(plan)
    del runtime['frame_metadata']
    runtime['frame_regions']=regions;runtime['frame_offsets']=offsets;runtime['trimmed']=True
    runtime['source_project_sha256']=sha((ART/(STEM+'.pxo')).read_bytes())
    target=ROOT/'assets/sprites'/(STEM+'.png');manifest=ROOT/'assets/sprites'/(STEM+'_manifest.json')
    lock=ART/'exported_hashes.json';previous=json.loads(lock.read_text()) if lock.exists() else {}
    for file in [target,manifest]:
        if file.exists() and sha(file.read_bytes())!=previous.get(file.name):raise SystemExit('Manual export edit protected: '+str(file))
    atlas.save(target);manifest.write_text(json.dumps(runtime,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    lock.write_text(json.dumps({file.name:sha(file.read_bytes()) for file in [target,manifest]},indent=2)+'\n')
    print(json.dumps({'frames':len(tiles),'atlas':[width,height],'megapixels':round(width*height/1e6,2)}))
if __name__=='__main__':run()
