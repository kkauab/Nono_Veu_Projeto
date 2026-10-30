"""Original deterministic bronze/chain sounds, pure local Python, no API."""
from pathlib import Path
import array,math,random,wave,hashlib,json
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/audio/sfx'
RATE=22050

def pcm(kind,seconds):
    rng=random.Random(3271)
    values=[];low=0.0
    for i in range(round(RATE*seconds)):
        t=i/RATE
        if kind=='bell':
            value=sum(weight*math.sin(math.tau*freq*t)*math.exp(-t*decay) for freq,weight,decay in [(113,.5,1.8),(231,.3,2.2),(357,.18,3.1),(493,.1,4.0),(781,.05,5.0)])
            value*=min(1,t/.006)
        else:
            low=low*.8+rng.uniform(-1,1)*.2
            envelope=max(0,1-t/seconds)**1.8
            pulse=sum(math.exp(-max(0,t-at)*75) if t>=at else 0 for at in [0,.065,.14,.23])
            value=(math.sin(math.tau*1513*t)*.3+math.sin(math.tau*2801*t)*.15+low*.5)*envelope*pulse
        values.append(value)
    peak=max(abs(v) for v in values)
    return array.array('h',[round(v/max(.01,peak)*26000) for v in values]).tobytes()

def build():
    lock=OUT/'gatekeeper_sfx_hashes.json'
    previous=json.loads(lock.read_text()) if lock.exists() else {}
    current={}
    for kind,seconds in [('bell',1.8),('chain',.45)]:
        name=f'gatekeeper_{kind}.wav';path=OUT/name
        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest()!=previous.get(name):raise SystemExit('Manual audio edit protected: '+str(path))
        with wave.open(str(path),'wb') as file:
            file.setnchannels(1);file.setsampwidth(2);file.setframerate(RATE);file.writeframes(pcm(kind,seconds))
        current[name]=hashlib.sha256(path.read_bytes()).hexdigest()
    lock.write_text(json.dumps(current,indent=2)+'\n')
    print('Original Gatekeeper sounds: bronze bell and short chain; no voice imitation.')

if __name__=='__main__':build()
