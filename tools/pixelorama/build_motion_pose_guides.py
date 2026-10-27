"""Anatomical pose diagrams for drawing motion frames, never delivery sprites.

The light and dark gray legs keep their identity across the entire cycle. Each ankle
has an independent stance/swing path; knees are solved as two rigid segments.
These images are guides for an artist/ImageGen, not warped character PNGs.
"""
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'art/pixelorama/senu/motion_v5_guides'
CELL = 384
SCALE = 102.0
BASE = (192, 330)
LABELS = ['CONTACT LEFT', 'DOWN LEFT', 'PASS RIGHT', 'UP RIGHT',
          'CONTACT RIGHT', 'DOWN RIGHT', 'PASS LEFT', 'UP LEFT']
COLORS = {'near': (174, 171, 166), 'far': (89, 89, 89),
          'torso': (148, 148, 148), 'head': (190, 190, 190),
          'line': (43, 43, 43), 'joint': (245, 245, 245)}
DIRECTIONS = [('down', (0, 1)), ('down_right', (.7071, .7071)),
              ('right', (1, 0)), ('up_right', (.7071, -.7071)),
              ('up', (0, -1))]


def font(size):
    for path in ['C:/Windows/Fonts/arial.ttf', 'C:/Windows/Fonts/calibri.ttf']:
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def ik(hip, ankle, length=.555, bend_forward=1):
    """Equal rigid femur/tibia in the sagittal plane, knee bending forward."""
    x, hy, hz = hip
    _, ay, az = ankle
    dy, dz = ay - hy, az - hz
    distance = math.hypot(dy, dz)
    if distance > 2 * length + 1e-6:
        raise ValueError(('Leg overextended', distance, hip, ankle))
    height = math.sqrt(max(0, length * length - distance * distance / 4))
    ny, nz = -dz / max(.0001, distance), dy / max(.0001, distance)
    return (x, (hy + ay) / 2 + bend_forward * ny * height,
            (hz + az) / 2 + bend_forward * nz * height)


def walk_pose(index):
    phase = index / 8
    bob = [-.01, -.055, 0, .035][index % 4]
    hips = 1.03 + bob
    points = {}
    for name, lateral, offset in [('near', -.14, 0), ('far', .14, .5)]:
        t = (phase + offset) % 1
        if t < .5:
            # Heel strike -> supporting leg -> toe-off; foot recedes under hip.
            y = .40 - 1.6 * t
            z = .09
            foot_angle = [0, 0, 5, 22][int(t * 8 + .0001)]
        else:
            # The other boot swings through with actual vertical clearance.
            u = (t - .5) * 2
            y = -.40 + .80 * u
            z = .09 + .26 * math.sin(math.pi * u)
            foot_angle = -12 * math.sin(math.pi * u)
        if t < .5:
            # Keep the low end of the rigid boot on the floor while its heel
            # rises; do not let an angled boot penetrate the guide's floor.
            z = .11 + max(0, .20 * math.sin(math.radians(foot_angle)))
        hip = (lateral, 0, hips)
        ankle = (lateral, y, z)
        knee = ik(hip, ankle)
        shoulder = (lateral * 1.8, 0, hips + .64)
        wrist = (lateral * 2.2, -y * .78, hips + .12)
        elbow = ik(shoulder, wrist, .35, bend_forward=-1)
        points[name] = {'hip': hip, 'knee': knee, 'ankle': ankle,
                        'shoulder': shoulder, 'elbow': elbow, 'wrist': wrist,
                        'foot_angle': foot_angle, 'support': t < .5}
    points['pelvis'] = (0, 0, hips)
    points['neck'] = (0, 0, hips + .78)
    points['head'] = (0, -.015, hips + 1.01)
    return points


def run_pose(index):
    # Running has a short support interval and an explicit aerial swing.
    points = {}
    phase = index / 8
    body_bob = [-.01, -.08, .015, .10][index % 4]
    hips = 1.04 + body_bob
    for name, lateral, offset in [('near', -.14, 0), ('far', .14, .5)]:
        k = int(((phase + offset) % 1) * 8 + .0001)
        foot_y = [.48, .12, -.35, -.48, -.39, -.16, .18, .44][k]
        foot_z = [.10, .09, .14, .48, .69, .67, .45, .28][k]
        foot_angle = [0, 10, 25, 45, 60, 20, -10, -8][k]
        if k in [0, 1, 2]:
            foot_z = .11 + max(0, .20 * math.sin(math.radians(foot_angle)))
        hip = (lateral, 0, hips)
        ankle = (lateral, foot_y, foot_z)
        knee = ik(hip, ankle, .58)
        shoulder = (lateral * 1.8, .17, hips + .60)
        wrist = (lateral * 2.1, -.8 * foot_y + .15, hips + .34)
        elbow = ik(shoulder, wrist, .36, bend_forward=-1)
        points[name] = {'hip': hip, 'knee': knee, 'ankle': ankle,
                        'shoulder': shoulder, 'elbow': elbow, 'wrist': wrist,
                        'foot_angle': foot_angle,
                        'support': k in [0, 1, 2]}
    points['pelvis'] = (0, 0, hips)
    points['neck'] = (0, .22, hips + .75)
    points['head'] = (0, .27, hips + .97)
    return points


def roll_pose(index):
    """A joint-articulated shoulder roll: inversion is not image rotation."""
    # Sagittal landmark keys: pelvis, shoulder, head, knee, ankle, elbow, hand.
    # Each tuple is (forward distance, height above the floor).
    keys = [
        ((0, .95), (.09, 1.48), (.15, 1.84), (.22, .55), (-.10, .09), (.26, 1.18), (.30, .86)),
        ((-.08, .61), (.23, 1.03), (.39, 1.31), (.35, .38), (-.03, .09), (.48, .67), (.59, .23)),
        ((-.04, .73), (.42, .53), (.60, .33), (.27, .55), (.06, .30), (.52, .26), (.74, .08)),
        ((.07, 1.02), (.16, .43), (.31, .17), (.45, .86), (.66, .58), (.40, .39), (.55, .22)),
        ((.22, .90), (-.18, .41), (-.43, .26), (.18, 1.15), (-.12, 1.39), (-.32, .63), (-.17, .92)),
        ((.25, .60), (-.22, .50), (-.48, .69), (.45, .45), (.55, .09), (-.39, .47), (-.37, .18)),
        ((0, .55), (.15, 1.01), (.18, 1.36), (.32, .36), (.12, .09), (.39, .76), (.47, .33)),
        ((0, .97), (.03, 1.54), (.05, 1.91), (.17, .53), (.08, .09), (.24, 1.19), (.28, .91)),
    ]
    pelvis, shoulder, head, knee, ankle, elbow, hand = keys[index]
    points = {}
    for name, lateral, delta in [('near', -.14, 0), ('far', .14, -.12)]:
        def point(p, dy=0, dz=0):
            return (lateral, p[0] + dy, p[1] + dz)
        points[name] = {'hip': point(pelvis), 'shoulder': point(shoulder),
                        'knee': point(knee, delta, .02 if name == 'far' else 0),
                        'ankle': point(ankle, delta, .02 if name == 'far' else 0),
                        'elbow': point(elbow, delta), 'wrist': point(hand, delta),
                        'foot_angle': [0, 0, 25, 50, -50, -10, 0, 0][index],
                        'support': index in [0, 1, 6, 7]}
    points['pelvis'] = (0, *pelvis)
    points['neck'] = (0, *shoulder)
    points['head'] = (0, *head)
    return points


def project(point, heading, origin=BASE, scale=SCALE):
    x, y, z = point
    hx, hy = heading
    return (origin[0] + scale * (hy * x + hx * y),
            origin[1] + scale * (.40 * (-hx * x + hy * y) - z))


def circle(draw, center, radius, fill, outline=None, width=1):
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill, outline, width)


def capsule(draw, a, b, width, fill):
    draw.line((a, b), fill=COLORS['line'], width=width + 4)
    circle(draw, a, (width + 4) / 2, COLORS['line'])
    circle(draw, b, (width + 4) / 2, COLORS['line'])
    draw.line((a, b), fill=fill, width=width)
    circle(draw, a, width / 2, fill)
    circle(draw, b, width / 2, fill)


def draw_pose(draw, points, heading, origin=BASE, scale=SCALE):
    p = lambda point: project(point, heading, origin, scale)
    # All poses use identical segment lengths, never a bbox-normalized scale.
    for name in ['far', 'near']:
        leg = points[name]
        color = COLORS[name]
        capsule(draw, p(leg['hip']), p(leg['knee']), 19, color)
        capsule(draw, p(leg['knee']), p(leg['ankle']), 15, color)
        ankle = leg['ankle']
        angle = math.radians(leg['foot_angle'])
        heel = (ankle[0], ankle[1] - .09 * math.cos(angle), ankle[2] + .09 * math.sin(angle) - .045)
        toe = (ankle[0], ankle[1] + .20 * math.cos(angle), ankle[2] - .20 * math.sin(angle) - .045)
        capsule(draw, p(heel), p(toe), 13, color)
        circle(draw, p(leg['knee']), 5, COLORS['joint'], COLORS['line'])
    # Torso side depth stays visible in profile and the widths remain constant.
    hip = points['pelvis']
    neck = points['neck']
    torso_vertices = [(-.25, neck[1] - .12, neck[2] - .04),
                      (.25, neck[1] - .12, neck[2] - .04),
                      (.19, hip[1] - .12, hip[2]),
                      (-.19, hip[1] - .12, hip[2])]
    side_vertices = [(0, neck[1] - .18, neck[2]), (0, neck[1] + .18, neck[2]),
                     (0, hip[1] + .16, hip[2]), (0, hip[1] - .16, hip[2])]
    draw.polygon([p(v) for v in torso_vertices], fill=COLORS['torso'], outline=COLORS['line'], width=3)
    draw.polygon([p(v) for v in side_vertices], fill=COLORS['torso'], outline=COLORS['line'], width=3)
    for name in ['far', 'near']:
        arm = points[name]
        color = tuple(int(c * .78) for c in COLORS[name])
        capsule(draw, p(arm['shoulder']), p(arm['elbow']), 13, color)
        capsule(draw, p(arm['elbow']), p(arm['wrist']), 11, color)
        circle(draw, p(arm['elbow']), 4, COLORS['joint'], COLORS['line'])
    head = points['head']
    center = p(head)
    circle(draw, center, 20, COLORS['head'], COLORS['line'], 3)
    # The face rotates with the neck/head axis during a roll. Keeping its nose
    # pointing right while the torso inverts would ask the artist to break it.
    neck = points['neck']
    up_y, up_z = head[1] - neck[1], head[2] - neck[2]
    axis_length = max(.001, math.hypot(up_y, up_z))
    nose = p((head[0], head[1] + .22 * up_z / axis_length,
              head[2] - .22 * up_y / axis_length))
    circle(draw, nose, 4, COLORS['line'])
    # Root marker is fixed on the floor, not aligned to a raised boot per frame.
    x, y = origin
    draw.line((x - 7, y, x + 7, y), fill=(161, 163, 163), width=1)
    draw.line((x, y - 4, x, y + 4), fill=(161, 163, 163), width=1)


def make_profile(action, builder):
    image = Image.new('RGB', (CELL * 4, CELL * 2), (246, 245, 238))
    draw = ImageDraw.Draw(image)
    poses = []
    for index in range(8):
        ox, oy = (index % 4) * CELL, (index // 4) * CELL
        draw.text((ox + 14, oy + 10), f'{index + 1}  {LABELS[index] if action != "roll" else ["PREPARE", "CROUCH", "SHOULDER", "INVERT", "FEET OVERHEAD", "UNFURL", "LAND", "RECOVER"][index]}', font=font(17), fill=(37, 45, 52))
        draw.line((ox + 28, oy + 330, ox + CELL - 28, oy + 330), fill=(211, 212, 208), width=1)
        points = builder(index)
        draw_pose(draw, points, (1, 0), (ox + BASE[0], oy + BASE[1]))
        poses.append(points)
    path = OUT / f'{action}_profile_8.png'
    image.save(path)
    return path, poses


def make_directions(action, builder):
    width, height = 2560, 1600
    cellw, cellh = width // 8, height // 5
    image = Image.new('RGB', (width, height), (246, 245, 238))
    draw = ImageDraw.Draw(image)
    for row, (direction, heading) in enumerate(DIRECTIONS):
        for index in range(8):
            origin = (index * cellw + cellw / 2, row * cellh + 278)
            draw_pose(draw, builder(index), heading, origin, 86)
    path = OUT / f'{action}_directions_40.png'
    image.save(path)
    return path


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {'kind': 'anatomical drawing guides, not final sprites', 'profile_grid': [4, 2],
                'profile_cell': [384, 384], 'profile_root': list(BASE),
                'direction_grid': [8, 5], 'direction_order': [v[0] for v in DIRECTIONS],
                'near_leg': 'light neutral gray, keeps anatomical identity throughout cycle',
                'far_leg': 'dark neutral gray, keeps anatomical identity throughout cycle', 'actions': {}}
    for action, builder in [('walk', walk_pose), ('run', run_pose), ('roll', roll_pose)]:
        path, poses = make_profile(action, builder)
        multi = make_directions(action, builder)
        manifest['actions'][action] = {'profile': str(path), 'directions': str(multi), 'joint_keys': poses}
    (OUT / 'guide_joint_keys.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')
    print(json.dumps({action: {key: value for key, value in entry.items() if key != 'joint_keys'}
                      for action, entry in manifest['actions'].items()}, ensure_ascii=False))


if __name__ == '__main__':
    main()
