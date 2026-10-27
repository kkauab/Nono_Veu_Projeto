"""Create Senu's original directional character atlas with Blender.

Run with Blender 5.x: blender --background --factory-startup --python this_file.
The model is authored here; no downloaded model, texture, rig or addon is used.
"""

import argparse
import json
import math
import sys
import tempfile
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

WIDTH, HEIGHT = 96, 112
PIVOT = (48, 94)
DIRECTIONS = ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]
POSES = ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "attack_1", "attack_2", "attack_3"]


def options():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-scene", action="store_true")
    parser.add_argument("--check-atlas", action="store_true")
    parser.add_argument("--preview", action="store_true")
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parents[2])
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def mat(name, rgb, metal=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1.0)
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = 0.85
    shader.inputs["Metallic"].default_value = metal
    return result


def empty(name, parent=None, location=(0, 0, 0)):
    result = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(result)
    result.parent = parent
    result.location = location
    return result


def mesh(name, vertices, faces, material, parent):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    result = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(result)
    result.parent = parent
    result.data.materials.append(material)
    return result


def cone(name, location, radius, depth, material, parent, top=None, vertices=10):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius, radius2=radius if top is None else top, depth=depth)
    result = bpy.context.object
    result.name = name
    result.parent = parent
    result.location = location
    result.data.materials.append(material)
    return result


def orb(name, location, scale, material, parent, segments=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, radius=1)
    result = bpy.context.object
    result.name = name
    result.parent = parent
    result.location = location
    result.scale = scale
    result.data.materials.append(material)
    return result


def box(name, location, scale, material, parent, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    result = bpy.context.object
    result.name = name
    result.parent = parent
    result.location = location
    result.scale = scale
    result.data.materials.append(material)
    if bevel:
        mod = result.modifiers.new("Worn corners", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    return result


def line(name, start, end, radius, material, parent):
    delta = Vector(end) - Vector(start)
    result = cone(name, (Vector(start) + Vector(end)) / 2, radius, delta.length, material, parent, vertices=8)
    result.rotation_euler = delta.to_track_quat("Z", "Y").to_euler()
    return result


def build_character():
    root = empty("SENU_V2_ORIGINAL")
    surfaces = {
        "skin": mat("Senu_warm_brown_skin", (.34, .17, .085)),
        "skin_light": mat("Senu_skin_light", (.43, .23, .13)),
        "hair": mat("Senu_dark_hair", (.025, .021, .018)),
        "linen": mat("Undyed_worn_linen", (.57, .51, .37)),
        "linen_light": mat("Sand_head_wrap", (.72, .64, .45)),
        "teal": mat("Petroleum_cloak", (.025, .20, .19)),
        "teal_light": mat("Raised_cloth_folds", (.055, .31, .28)),
        "teal_dark": mat("Cloak_shadows", (.014, .085, .09)),
        "bronze": mat("Worn_bronze", (.58, .34, .11), .18),
        "gold": mat("Talisman_and_trim", (.85, .58, .22), .12),
        "leather": mat("Brown_leather", (.115, .071, .041)),
        "dark": mat("Boot_and_eye_shadows", (.035, .034, .029)),
    }
    s = surfaces
    legs, arms = [], []
    for side in [-1, 1]:
        leg = empty("Left_leg_pivot" if side < 0 else "Right_leg_pivot", root, (side * .145, 0, .98))
        cone("Linen_trouser", (0, 0, -.235), .105, .47, s["linen"], leg, top=.12)
        knee = empty("Knee", leg, (0, 0, -.43))
        cone("Calf_wrap", (0, 0, -.21), .079, .43, s["linen_light"], knee, top=.091)
        for z in [-.12, -.21, -.30]:
            cone("Boot_tie", (0, 0, z), .084, .018, s["leather"], knee)
        orb("Travel_boot", (0, -.075, -.455), (.105, .175, .075), s["leather"], knee)
        orb("Sole", (0, -.075, -.49), (.11, .18, .027), s["dark"], knee)
        legs.append((leg, knee))

    cone("Split_linen_tunic", (0, 0, 1.02), .285, .73, s["linen"], root, top=.23, vertices=12)
    cone("Clothed_torso", (0, 0, 1.42), .245, .52, s["linen_light"], root, top=.30, vertices=12)
    mesh("Front_tunic_panel", [(-.23, -.13, 1.12), (.19, -.15, 1.12), (.22, -.14, .65), (.035, -.20, .54), (-.22, -.13, .65)], [(0, 1, 2, 3, 4)], s["linen_light"], root)
    mesh("Front_tunic_fold", [(-.025, -.244, 1.11), (.025, -.244, 1.11), (.07, -.206, .60), (-.05, -.21, .63)], [(0, 1, 2, 3)], s["linen"], root)
    belt = cone("Leather_belt", (0, 0, 1.10), .261, .10, s["leather"], root, vertices=12)
    box("Bronze_belt_clasp", (0, -.265, 1.10), (.10, .028, .085), s["bronze"], root)
    box("Belt_clasp_inset", (0, -.283, 1.10), (.045, .013, .040), s["teal"], root)
    pouch = box("Scribe_pouch", (.29, .035, 1.00), (.19, .17, .25), s["leather"], root, .1)
    box("Pouch_flap", (.29, -.062, 1.08), (.20, .027, .11), s["bronze"], root)
    cone("Scroll", (-.29, .045, 1.00), .058, .31, s["linen_light"], root, vertices=10)
    cone("Scroll_binding", (-.29, .045, 1.02), .061, .04, s["leather"], root)

    cape = mesh("Asymmetric_petroleum_cape", [
        (-.34, .06, 1.72), (.23, .06, 1.69), (.32, .22, 1.24), (.31, .30, .59),
        (.16, .33, .43), (-.01, .33, .52), (-.15, .34, .32), (-.30, .31, .40), (-.42, .23, .65), (-.38, .20, 1.21), (0, .31, 1.10)
    ], [(0, 1, 10), (1, 2, 10), (2, 3, 4, 10), (4, 5, 6, 10), (6, 7, 8, 10), (8, 9, 0, 10)], s["teal"], root)
    mesh("Cape_highlight_fold", [(-.24, .262, 1.53), (-.16, .32, 1.52), (-.13, .357, .36), (-.27, .33, .43)], [(0, 1, 2, 3)], s["teal_light"], root)
    mesh("Cape_shadow_fold", [(.03, .33, 1.51), (.08, .34, 1.47), (.17, .36, .47), (.05, .35, .54)], [(0, 1, 2, 3)], s["teal_dark"], root)
    mesh("Cape_worn_trim", [(-.39, .24, .64), (-.29, .32, .40), (-.15, .35, .32), (-.14, .35, .37), (-.29, .32, .45), (-.38, .24, .69)], [(0, 1, 2, 3, 4, 5)], s["bronze"], root)
    mesh("Shoulder_scarf", [(-.34, -.10, 1.72), (-.04, -.28, 1.72), (.28, -.18, 1.69), (.25, -.26, 1.51), (-.08, -.29, 1.46), (-.36, -.16, 1.55)], [(0, 1, 2, 3, 4, 5)], s["teal"], root)
    mesh("Scarf_front_fold", [(-.22, -.258, 1.66), (.15, -.258, 1.65), (.10, -.30, 1.58), (-.16, -.301, 1.56)], [(0, 1, 2, 3)], s["teal_light"], root)
    mesh("Cross_body_strap", [(-.24, -.228, 1.61), (-.19, -.247, 1.62), (.20, -.246, 1.13), (.14, -.257, 1.13)], [(0, 1, 2, 3)], s["leather"], root)

    hands = []
    for side in [-1, 1]:
        arm = empty("Left_shoulder_pivot" if side < 0 else "Right_shoulder_pivot", root, (side * .29, 0, 1.67))
        line("Linen_sleeve", (0, 0, 0), (side * .10, -.03, -.31), .112, s["linen"], arm)
        line("Forearm", (side * .10, -.03, -.31), (side * .14, -.18, -.61), .071, s["skin"], arm)
        line("Wrist_wrap", (side * .13, -.13, -.51), (side * .14, -.17, -.59), .077, s["linen_light"], arm)
        hand = empty("Left_hand_anchor" if side < 0 else "Right_hand_anchor", arm, (side * .14, -.19, -.65))
        orb("Open_weapon_hand", (0, 0, 0), (.071, .076, .080), s["skin_light"], hand)
        if side < 0:
            orb("Single_bronze_shoulder", (-.035, -.01, -.035), (.17, .14, .11), s["bronze"], arm, segments=10)
            mesh("Shoulder_engraving", [(-.14, -.11, -.01), (-.02, -.15, .03), (.065, -.10, -.02), (-.02, -.12, -.035)], [(0, 1, 2, 3)], s["gold"], arm)
        arms.append(arm)
        hands.append(hand)
    cone("Neck", (0, 0, 1.77), .10, .20, s["skin"], root)
    orb("Head", (0, -.012, 2.00), (.18, .165, .225), s["skin_light"], root)
    orb("Short_dark_hair", (0, .024, 2.13), (.199, .177, .151), s["hair"], root)
    for side in [-1, 1]:
        orb("Ear", (side * .182, -.015, 2.015), (.034, .040, .059), s["skin"], root)
        orb("Eye", (side * .058, -.169, 2.045), (.024, .013, .015), s["dark"], root)
        box("Eyebrow", (side * .06, -.170, 2.078), (.060, .020, .015), s["hair"], root)
    orb("Nose", (0, -.180, 2.005), (.032, .043, .055), s["skin_light"], root)
    box("Mouth", (0, -.168, 1.948), (.055, .017, .012), s["skin"], root)
    cone("Sand_fabric_headband", (0, .010, 2.147), .205, .064, s["linen_light"], root, vertices=12)
    mesh("Headband_tail", [(-.18, .11, 2.15), (-.10, .15, 2.15), (-.27, .26, 1.73), (-.36, .22, 1.67), (-.30, .21, 1.91)], [(0, 1, 2, 3, 4)], s["linen_light"], root)
    line("Pendant_cord_left", (-.09, -.26, 1.62), (0, -.285, 1.36), .009, s["bronze"], root)
    line("Pendant_cord_right", (.09, -.26, 1.62), (0, -.285, 1.36), .009, s["bronze"], root)
    mesh("Original_geometric_talisman", [(0, -.30, 1.45), (.052, -.30, 1.38), (0, -.30, 1.30), (-.052, -.30, 1.38)], [(0, 1, 2, 3)], s["gold"], root)
    mesh("Talisman_dark_center", [(0, -.308, 1.42), (.026, -.308, 1.38), (0, -.308, 1.34), (-.026, -.308, 1.38)], [(0, 1, 2, 3)], s["teal_dark"], root)
    return {"root": root, "legs": legs, "arms": arms, "hands": hands, "cape": cape}


def pose(character, row, direction):
    root = character["root"]
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, math.atan2(6, 8) + direction * math.pi / 4)
    for leg, knee in character["legs"]:
        leg.rotation_euler = (0, 0, 0)
        knee.rotation_euler = (0, 0, 0)
    for arm in character["arms"]:
        arm.rotation_euler = (0, 0, 0)
    character["cape"].rotation_euler.x = 0
    if 1 <= row <= 4:
        phase = (row - 1) * math.pi / 2
        swing = math.cos(phase)
        for index, (leg, knee) in enumerate(character["legs"]):
            sign = -1 if index == 0 else 1
            leg.rotation_euler.x = sign * swing * .38
            knee.rotation_euler.x = max(0, -sign * swing) * .45
            character["arms"][index].rotation_euler.x = -sign * swing * .42
        character["cape"].rotation_euler.x = .035 + abs(swing) * .025
        root.location.z = .02 if row in [2, 4] else 0
    elif row >= 5:
        attack = row - 5
        rotations = [(-.65, -.20, -.70), (-1.18, .10, .15), (-.80, .20, .92)]
        character["arms"][1].rotation_euler = rotations[attack]
        character["arms"][0].rotation_euler = (-.52, -.15, -.20)
        character["legs"][0][0].rotation_euler.x = .20
        character["legs"][1][0].rotation_euler.x = -.15
        character["cape"].rotation_euler.x = .06
    bpy.context.view_layer.update()


def make_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 12
    scene.cycles.use_denoising = False
    scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.dither_intensity = 0
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("Senu_studio")
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.15, .19, .22, 1)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .65
    camera_data = bpy.data.cameras.new("Isometric_fixed_camera")
    camera = bpy.data.objects.new("Isometric_fixed_camera", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (6, -8, 7)
    camera.rotation_euler = (Vector((0, 0, 1.1)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.65
    scene.camera = camera
    bpy.context.view_layer.update()
    baseline = world_to_camera_view(scene, camera, Vector((0, 0, 0))).y
    camera_data.shift_y = .1
    shifted = world_to_camera_view(scene, camera, Vector((0, 0, 0))).y
    camera_data.shift_y = ((1 - PIVOT[1] / HEIGHT) - baseline) / ((shifted - baseline) / .1)
    for name, location, energy, rgb, size in [
        ("Warm_key", (-3, -4, 6), 750, (1, .88, .70), 4),
        ("Cool_rim", (3, 3, 4), 250, (.45, .76, .82), 3),
        ("Soft_front", (2, -4, 3), 85, (.8, .86, 1), 3),
    ]:
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy, light_data.color, light_data.size = energy, rgb, size
        light = bpy.data.objects.new(name, light_data)
        bpy.context.collection.objects.link(light)
        light.location = location
        light.rotation_euler = (Vector((0, 0, 1.1)) - light.location).to_track_quat("-Z", "Y").to_euler()
    return scene, build_character()


def hand_pixels(scene, hand):
    p = world_to_camera_view(scene, scene.camera, hand.matrix_world.translation)
    return [round(p.x * WIDTH, 3), round((1 - p.y) * HEIGHT, 3)]


def validate_atlas(sprite):
    image = bpy.data.images.load(str(sprite), check_existing=False)
    assert tuple(image.size) == (WIDTH * 8, HEIGHT * 8), tuple(image.size)
    pixels = list(image.pixels[:])
    bounds = []
    for row in range(8):
        for direction in range(8):
            occupied = [(x, HEIGHT - 1 - y) for y in range(HEIGHT) for x in range(WIDTH)
                        if pixels[(((7 - row) * HEIGHT + y) * WIDTH * 8 + direction * WIDTH + x) * 4 + 3] > .5]
            assert occupied, (row, direction, "empty")
            bb = [min(p[0] for p in occupied), min(p[1] for p in occupied), max(p[0] for p in occupied), max(p[1] for p in occupied)]
            assert bb[0] > 0 and bb[1] > 0 and bb[2] < WIDTH - 1 and bb[3] < HEIGHT - 1, (row, direction, bb)
            bounds.append(bb)
    print("SENU_V2_ATLAS_CHECK_OK frames=64 dimensions=768x896 no_clipped_frames")
    return bounds


def main():
    args = options()
    project = args.output_root.resolve()
    sprite = project / "assets/sprites/senu_v2.png"
    if args.check_atlas:
        validate_atlas(sprite)
        return
    scene, character = make_scene()
    pose(character, 0, 0)
    p = world_to_camera_view(scene, scene.camera, Vector((0, 0, 0)))
    assert abs(p.x * WIDTH - PIVOT[0]) < .1 and abs((1 - p.y) * HEIGHT - PIVOT[1]) < .1
    if args.check_scene:
        print("SENU_V2_SCENE_OK", bpy.app.version_string, len(bpy.data.objects), "objects", "pivot", PIVOT)
        return
    sprite.parent.mkdir(parents=True, exist_ok=True)
    blend = project / "blender/personagens/senu_v2.blend"
    blend.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    if args.preview:
        scene.render.filepath = str(sprite.with_name("senu_v2_preview.png"))
        bpy.ops.render.render(write_still=True)
        print("SENU_V2_PREVIEW_OK", scene.render.filepath)
        return
    atlas_width, atlas_height = WIDTH * 8, HEIGHT * 8
    atlas_pixels = [0.0] * (atlas_width * atlas_height * 4)
    anchors = []
    with tempfile.TemporaryDirectory(prefix="senu_v2_frames_") as temporary:
        for row, pose_name in enumerate(POSES):
            for direction, direction_name in enumerate(DIRECTIONS):
                pose(character, row, direction)
                anchors.append({"right": hand_pixels(scene, character["hands"][1]), "left": hand_pixels(scene, character["hands"][0])})
                scene.render.filepath = str(Path(temporary) / f"senu_{row}_{direction}.png")
                bpy.ops.render.render(write_still=True)
                frame = bpy.data.images.load(scene.render.filepath, check_existing=False)
                pixels = list(frame.pixels[:])
                bpy.data.images.remove(frame)
                for y in range(HEIGHT):
                    for x in range(WIDTH):
                        origin = (y * WIDTH + x) * 4
                        target = (((7 - row) * HEIGHT + y) * atlas_width + direction * WIDTH + x) * 4
                        if pixels[origin + 3] >= .42:
                            atlas_pixels[target:target + 4] = pixels[origin:origin + 3] + [1.0]
                print("SENU_V2_FRAME_OK", row, direction, pose_name, direction_name, flush=True)
    image = bpy.data.images.new("Senu_v2_animation_atlas", width=atlas_width, height=atlas_height, alpha=True)
    image.pixels = atlas_pixels
    image.filepath_raw, image.file_format = str(sprite), "PNG"
    image.save()
    metadata = {"description": "Original Senu v2 body atlas, authored and rendered in Blender. Weapons are separate Godot overlays.", "version": 2, "blender": bpy.app.version_string, "frame_width": WIDTH, "frame_height": HEIGHT, "columns": 8, "rows": 8, "pivot": PIVOT, "scale": .43, "directions": DIRECTIONS, "poses": POSES, "hands": anchors, "animations": {"idle": [0], "walk": [1, 2, 3, 4], "attack": [5, 6, 7]}, "filter": "nearest"}
    sprite.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    validate_atlas(sprite)
    print("SENU_V2_COMPLETE", sprite, flush=True)


if __name__ == "__main__":
    main()
