"""Package actual 30 fps Godot combat captures; no rendered effects are added."""
from pathlib import Path
import json
import re
import sys
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
QA = Path(sys.argv[1]).resolve() if len(sys.argv)>1 else ROOT / 'qa/porteiro_combate'
DATA = json.loads((ROOT / 'resources/bosses/gatekeeper_attacks.json').read_text(encoding='utf8'))
COMBAT = json.loads((ROOT / 'resources/bosses/gatekeeper_combat.json').read_text(encoding='utf8'))

def run():
    font = ImageFont.truetype('C:/Windows/Fonts/georgia.ttf', 15)
    sheet = Image.new('RGB', (960, 3*270), '#142026')
    draw = ImageDraw.Draw(sheet)
    montage = []
    montage_times = []
    for i, key in enumerate(DATA['order']):
        paths = sorted(p for p in QA.glob(key + '_*.png')
                       if re.fullmatch(re.escape(key) + r'_\d{3}\.png', p.name))
        if not paths:
            raise SystemExit('Missing actual Godot capture: ' + key)
        frames = [Image.open(p).convert('RGB') for p in paths]
        times = [40 if n % 3 == 1 else 30 for n in range(len(frames))]
        frames[0].save(QA / f'{key}_combate.gif', save_all=True,
                       append_images=frames[1:], duration=times, loop=0, optimize=False)
        for frame in frames:
            page = Image.new('RGB', (640, 486), '#142026')
            page.paste(frame, (0, 36))
            ImageDraw.Draw(page).text((12, 9), f'{i+1}. ' + DATA['attacks'][key]['name'], font=font, fill='#dfc38c')
            montage.append(page)
        montage_times.extend(times)
        # The contact occurs at exactly this JSON time in the captured live actor.
        attack = DATA['attacks'][key]
        contact = sum(attack['seconds'][:attack['contact_pose']])
        rate = COMBAT['phase_two_speed'] if attack['phase'] == 2 else 1.0
        at = min(len(frames)-1, round(contact/rate*30)+3)
        picture = frames[at].resize((320, 225), Image.Resampling.NEAREST)
        x, y = i % 3*320, i // 3*270
        sheet.paste(picture, (x, y+35))
        draw.text((x+8, y+8), f'{i+1}. ' + attack['name'], font=font, fill='#dfc38c')
    sheet.save(QA / 'nove_golpes_no_jogo.png')
    montage[0].save(QA / 'nove_golpes_no_jogo.gif', save_all=True,
                    append_images=montage[1:], duration=montage_times, loop=0, optimize=False)
    walk = [Image.open(p).convert('RGB') for p in sorted(QA.glob('walk_[0-9][0-9][0-9].png'))]
    if walk:
        walk[0].save(QA / 'caminhada_no_jogo.gif', save_all=True, append_images=walk[1:],
                     duration=[40 if n % 3 == 1 else 30 for n in range(len(walk))], loop=0, optimize=False)
    for direction in ['up_left','up','up_right']:
        walk = [Image.open(p).convert('RGB') for p in sorted(QA.glob('walk_'+direction+'_[0-9][0-9][0-9].png'))]
        # The opening 1.2 s are the real post-intro recovery. This short rear
        # review begins once he turns and walks, keeping the captured 30 fps.
        walk = walk[36:]
        if walk:
            walk[0].save(QA / ('costas_'+direction+'.gif'), save_all=True, append_images=walk[1:],
                         duration=[40 if n % 3 == 1 else 30 for n in range(len(walk))], loop=0, optimize=False)
    print('Packaged nine actual combat clips and contact sheet.')

if __name__ == '__main__':
    run()
