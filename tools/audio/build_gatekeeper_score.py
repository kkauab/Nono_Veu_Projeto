"""Original local encounter beds and wet-stone/breath placeholders, no API."""
from pathlib import Path
import array,math,random,wave,hashlib,json
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'assets/audio';RATE=22050
def sound(kind,seconds):
    rng=random.Random(619);values=[];noise=0
    for i in range(round(seconds*RATE)):
        t=i/RATE;noise=noise*.91+rng.uniform(-1,1)*.09
        if kind in ['duty','despair']:
            chord=int(t/4)%4;frequency=[65.406,77.782,58.270,65.406][chord]
            blend=(t%4)/4;envelope=math.sin(math.pi*blend)**.4
            value=envelope*sum(weight*math.sin(math.tau*frequency*ratio*t) for ratio,weight in [(1,.32),(1.5,.13),(2,.10),(2.3784,.065)])
            onset=t%4;value+=.12*math.sin(math.tau*frequency*4*t)*math.exp(-onset*1.8)
            if kind=='despair':
                beat=t%.5;value+=.28*math.sin(math.tau*(48*beat+8*(1-math.exp(-beat*22))))*math.exp(-beat*14)
                value+=noise*.22*math.exp(-beat*30)
            edge=min(1,t/.12,(seconds-t)/.12);value*=edge
        elif kind=='step':
            value=(math.sin(math.tau*72*t)*.6*math.exp(-t*30)+noise*.8*math.exp(-t*18))*min(1,t/.003)
        else:
            env=math.sin(math.pi*t/seconds)**1.3
            value=noise*env+math.sin(math.tau*91*t)*.035*env
        values.append(value)
    peak=max(abs(v) for v in values);amplitude=19000 if kind in ['duty','despair'] else 14000
    return array.array('h',[round(v/max(.001,peak)*amplitude) for v in values]).tobytes()
def run():
    lock=OUT/'gatekeeper_original_hashes.json';old=json.loads(lock.read_text()) if lock.exists() else {};products={}
    for kind,seconds,path in [('duty',16,'music/gatekeeper_duty.wav'),('despair',16,'music/gatekeeper_despair.wav'),('step',.28,'sfx/gatekeeper_step.wav'),('breath',.85,'sfx/gatekeeper_breath.wav')]:
        file=OUT/path
        if file.exists() and hashlib.sha256(file.read_bytes()).hexdigest()!=old.get(path):raise SystemExit('Manual audio edit protected: '+str(file))
        file.parent.mkdir(parents=True,exist_ok=True)
        with wave.open(str(file),'wb') as stream:stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(RATE);stream.writeframes(sound(kind,seconds))
        products[path]=hashlib.sha256(file.read_bytes()).hexdigest()
    lock.write_text(json.dumps(products,indent=2)+'\n');print('Four original local encounter sounds prepared')
if __name__=='__main__':run()
