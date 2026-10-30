"""Editable direction projects keep Pixelorama loading/export bounded."""
import copy,json,hashlib,io,sys
from pathlib import Path
from zipfile import ZipFile,ZIP_DEFLATED
ROOT=Path(__file__).resolve().parents[2]
VERSION=int(sys.argv[1]) if len(sys.argv)>1 else 7
assert VERSION in [7,8,9]
STEM=f'porteiro_live_v{VERSION}';ART=ROOT/'art/pixelorama'/STEM
def run():
    plan=json.loads((ART/'export_plan.json').read_text())
    lock=ART/'direction_hashes.json';old=json.loads(lock.read_text()) if lock.exists() else {};products={}
    with ZipFile(ART/(STEM+'.pxo')) as source:
        master=json.loads(source.read('data.json'))
        for direction in plan['directions']:
            indices=[i for i,meta in enumerate(plan['frame_metadata']) if meta['direction']==direction]
            start=indices[0];end=indices[-1]+1
            data=copy.deepcopy(master);data['frames']=data['frames'][start:end];data['current_frame']=0
            data['export_profile']['lines_count']='14'
            data['tags']=[dict(tag,**{'from':tag['from']-start,'to':tag['to']-start}) for tag in master['tags'] if tag['from']>=start+1 and tag['to']<=end]
            blob=io.BytesIO()
            with ZipFile(blob,'w',ZIP_DEFLATED) as target:
                target.writestr('mimetype','application/x-pixelorama');target.writestr('data.json',json.dumps(data,ensure_ascii=False))
                for local,index in enumerate(indices):
                    for layer in range(len(data['layers'])):target.writestr(f'image_data/frames/{local+1}/layer_{layer+1}',source.read(f'image_data/frames/{index+1}/layer_{layer+1}'))
            products['directions/'+direction+'.pxo']=blob.getvalue()
    digest=lambda blob:hashlib.sha256(blob).hexdigest()
    for name,blob in products.items():
        file=ART/name
        if file.exists() and digest(file.read_bytes())!=old.get(name):raise SystemExit('Manual direction edit protected: '+str(file))
        file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(blob)
    lock.write_text(json.dumps({name:digest(blob) for name,blob in products.items()},indent=2)+'\n')
    print('Prepared eight editable direction projects')
if __name__=='__main__':run()
