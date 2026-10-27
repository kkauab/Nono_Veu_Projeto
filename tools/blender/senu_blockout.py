"""Original Senu blockout and an eight-direction orthographic idle proof.

Run inside Blender, not the system Python. This is an art pipeline experiment,
not a rig, an animation set, or final pixel art. No downloaded assets are used.
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


FRAME_WIDTH = 64
FRAME_HEIGHT = 80
PIVOT = (32, 66)
DIRECTIONS = [
    "down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"
]


def arguments():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Check Blender access without creating or rendering assets.")
    parser.add_argument("--check-scene", action="store_true", help="Construct the model and validate its camera without rendering or saving files.")
    parser.add_argument("--check-atlas", action="store_true", help="Validate an existing PNG and detect clipped frames.")
    parser.add_argument("--output-root", type=Path, default=Path(__file__).resolve().parents[2])
    return parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])


def material(name, rgb, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*rgb, 1.0)
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*rgb, 1.0)
    shader.inputs["Roughness"].default_value = 0.86
    shader.inputs["Metallic"].default_value = metallic
    return result


def mesh_object(name, vertices, faces, surface, parent=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    result = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(result)
    result.data.materials.append(surface)
    result.parent = parent
    return result


def cylinder(name, location, radius, depth, surface, parent, vertices=8, radius_top=None):
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=radius, radius2=radius if radius_top is None else radius_top,
        depth=depth, location=location,
    )
    result = bpy.context.object
    result.name = name
    result.data.materials.append(surface)
    result.parent = parent
    return result


def limb(name, a, b, radius, surface, parent):
    center = (Vector(a) + Vector(b)) * 0.5
    result = cylinder(name, center, radius, (Vector(b) - Vector(a)).length, surface, parent)
    result.rotation_euler = (Vector(b) - Vector(a)).to_track_quat("Z", "Y").to_euler()
    return result


def sphere(name, location, scale, surface, parent):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=location)
    result = bpy.context.object
    result.name = name
    result.scale = scale
    result.data.materials.append(surface)
    result.parent = parent
    return result


def make_character():
    root = bpy.data.objects.new("Senu_ORIGINAL_BLOCKOUT", None)
    bpy.context.collection.objects.link(root)
    teal = material("Capa_verde_petroleo", (0.025, 0.19, 0.18))
    light_teal = material("Tecido_luz", (0.05, 0.32, 0.27))
    shadow_teal = material("Tecido_sombra", (0.014, 0.075, 0.085))
    linen = material("Linho_escuro", (0.24, 0.20, 0.14))
    skin = material("Pele_cobre", (0.34, 0.17, 0.085))
    gold = material("Bronze_dourado", (0.65, 0.39, 0.10), 0.25)
    edge = material("Lamina_luz", (0.95, 0.72, 0.27), 0.2)
    dark = material("Couro_carvao", (0.035, 0.035, 0.035))

    for x in (-0.14, 0.14):
        sphere("Bota", (x, -0.06, 0.09), (0.11, 0.18, 0.09), dark, root)
        cylinder("Perna", (x, 0.0, 0.35), 0.085, 0.52, linen, root)
    cylinder("Tunica", (0.0, 0.0, 0.78), 0.29, 0.82, linen, root, radius_top=0.22)
    cylinder("Torso", (0.0, 0.0, 1.19), 0.25, 0.42, teal, root, radius_top=0.29)
    cylinder("Cinto", (0.0, 0.0, 0.99), 0.265, 0.075, gold, root)
    # The cape is a layered, angular surface behind Senu (local +Y).
    mesh_object("Capa", [
        (-0.30, 0.10, 1.40), (0.30, 0.10, 1.40),
        (0.39, 0.25, 0.38), (0.12, 0.31, 0.29),
        (-0.13, 0.30, 0.36), (-0.40, 0.25, 0.43),
        (0.0, 0.32, 0.94),
    ], [(0, 1, 6), (1, 2, 3, 6), (3, 4, 6), (4, 5, 0, 6)], teal, root)
    mesh_object("Capa_dobra", [(-0.07, 0.332, 1.28), (0.035, 0.339, 1.24), (0.13, 0.32, 0.36), (-0.13, 0.31, 0.41)], [(0, 1, 2, 3)], light_teal, root)
    for side in (-1, 1):
        limb("Manga", (side * 0.26, 0.0, 1.32), (side * 0.40, -0.08, 1.05), 0.105, teal, root)
        limb("Antebraco", (side * 0.40, -0.08, 1.05), (side * 0.42, -0.25, 0.93), 0.073, skin, root)
        sphere("Mao", (side * 0.42, -0.25, 0.93), (0.075, 0.08, 0.07), skin, root)
    cylinder("Pescoco", (0.0, 0.0, 1.46), 0.105, 0.19, skin, root)
    sphere("Capuz", (0.0, 0.025, 1.66), (0.215, 0.205, 0.255), shadow_teal, root)
    sphere("Rosto", (0.0, -0.135, 1.65), (0.145, 0.088, 0.185), skin, root)
    cylinder("Faixa", (0.0, 0.0, 1.77), 0.208, 0.055, gold, root, vertices=12)
    # Two minimal dark eye marks retain a readable front at the tiny resolution.
    for x in (-0.058, 0.058):
        sphere("Olho", (x, -0.218, 1.67), (0.020, 0.011, 0.013), dark, root)
    limb("Cordao", (0.0, -0.25, 1.38), (0.0, -0.268, 1.13), 0.012, gold, root)
    sphere("Talisma", (0.0, -0.279, 1.14), (0.048, 0.022, 0.067), edge, root)
    cylinder("Empunhadura", (0.43, -0.26, 0.94), 0.034, 0.20, dark, root)
    # Original khopesh-like blockout, not a traced historic or franchise weapon.
    blade = [
        (0.40, 0.99), (0.47, 0.99), (0.50, 1.25), (0.68, 1.43),
        (0.69, 1.64), (0.60, 1.78), (0.57, 1.67), (0.61, 1.57),
        (0.56, 1.47), (0.43, 1.36),
    ]
    verts = [(x, -0.285 + depth, z) for depth in (-0.023, 0.023) for x, z in blade]
    count = len(blade)
    faces = [tuple(range(count - 1, -1, -1)), tuple(range(count, count * 2))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count) for i in range(count)]
    mesh_object("Khopesh_provisorio", verts, faces, gold, root)
    mesh_object("Fio_da_lamina", [(0.47, -0.310, 1.01), (0.50, -0.310, 1.25), (0.68, -0.310, 1.43), (0.69, -0.310, 1.64), (0.60, -0.310, 1.78), (0.64, -0.310, 1.59), (0.62, -0.310, 1.46), (0.47, -0.310, 1.28)], [tuple(range(8))], edge, root)
    return root


def make_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = False
    scene.render.resolution_x = FRAME_WIDTH
    scene.render.resolution_y = FRAME_HEIGHT
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.dither_intensity = 0
    scene.view_settings.view_transform = "Standard"
    scene.world = bpy.data.worlds.new("Mundo_de_estudo")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.13, 0.17, 0.20, 1.0)
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6

    camera_data = bpy.data.cameras.new("Camera_ortografica")
    camera = bpy.data.objects.new("Camera_ortografica", camera_data)
    bpy.context.collection.objects.link(camera)
    camera.location = (6.0, -8.0, 8.0)
    camera.rotation_euler = (Vector((0.0, 0.0, 0.95)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.type = "ORTHO"
    camera_data.ortho_scale = 2.3
    scene.camera = camera
    bpy.context.view_layer.update()
    # Fit the projected world origin to a reproducible, foot-based sprite pivot.
    desired_y = 1.0 - PIVOT[1] / FRAME_HEIGHT
    baseline = world_to_camera_view(scene, camera, Vector((0.0, 0.0, 0.0))).y
    camera_data.shift_y = 0.1
    shifted = world_to_camera_view(scene, camera, Vector((0.0, 0.0, 0.0))).y
    derivative = (shifted - baseline) / 0.1
    camera_data.shift_y = (desired_y - baseline) / derivative

    light_data = bpy.data.lights.new("Luz_quente", "AREA")
    light_data.energy = 550
    light_data.shape = "DISK"
    light_data.size = 4.0
    light = bpy.data.objects.new("Luz_quente", light_data)
    bpy.context.collection.objects.link(light)
    light.location = (-3.0, -4.0, 6.0)
    light.rotation_euler = (-light.location).to_track_quat("-Z", "Y").to_euler()
    rim_data = bpy.data.lights.new("Recorte_frio", "AREA")
    rim_data.energy = 220
    rim_data.color = (0.3, 0.7, 0.8)
    rim_data.size = 3.0
    rim = bpy.data.objects.new("Recorte_frio", rim_data)
    bpy.context.collection.objects.link(rim)
    rim.location = (2.0, 3.0, 4.0)
    rim.rotation_euler = (Vector((0, 0, 1)) - rim.location).to_track_quat("-Z", "Y").to_euler()
    return scene, make_character()


def create_atlas(scene, character, output):
    atlas_width = FRAME_WIDTH * len(DIRECTIONS)
    atlas_pixels = [0.0] * (atlas_width * FRAME_HEIGHT * 4)
    with tempfile.TemporaryDirectory(prefix="nono_veu_senu_") as temporary:
        for index, direction in enumerate(DIRECTIONS):
            character.rotation_euler.z = math.atan2(6.0, 8.0) + index * math.pi / 4.0
            bpy.context.view_layer.update()
            # A file-backed frame is reliable in background mode, where the
            # transient Render Result can expose an empty pixels collection.
            scene.render.filepath = str(Path(temporary) / f"{index}.png")
            bpy.ops.render.render(write_still=True)
            result = bpy.data.images.load(scene.render.filepath, check_existing=False)
            pixels = list(result.pixels[:])
            bpy.data.images.remove(result)
            if len(pixels) != FRAME_WIDTH * FRAME_HEIGHT * 4:
                raise RuntimeError(f"Unexpected frame dimensions for {direction}")
            for y in range(FRAME_HEIGHT):
                for x in range(FRAME_WIDTH):
                    source = (y * FRAME_WIDTH + x) * 4
                    target = (y * atlas_width + index * FRAME_WIDTH + x) * 4
                    alpha = pixels[source + 3]
                    if alpha >= 0.4:
                        atlas_pixels[target:target + 4] = pixels[source:source + 3] + [1.0]
            print(f"SENU_FRAME_OK {index} {direction}")
    image = bpy.data.images.new("senu_blockout_idle_8", width=atlas_width, height=FRAME_HEIGHT, alpha=True)
    image.pixels = atlas_pixels
    image.filepath_raw = str(output)
    image.file_format = "PNG"
    image.save()
    return atlas_width


def main():
    options = arguments()
    if options.check:
        print(f"SENU_BLENDER_CHECK_OK Blender {bpy.app.version_string}; atlas={FRAME_WIDTH * 8}x{FRAME_HEIGHT}; pivot={PIVOT}")
        return
    if options.check_scene:
        scene, character = make_scene()
        pivot = world_to_camera_view(scene, scene.camera, Vector((0.0, 0.0, 0.0)))
        projected_pivot = (pivot.x * FRAME_WIDTH, (1.0 - pivot.y) * FRAME_HEIGHT)
        if abs(projected_pivot[0] - PIVOT[0]) > 0.1 or abs(projected_pivot[1] - PIVOT[1]) > 0.1:
            raise RuntimeError(f"Camera pivot mismatch: {projected_pivot}")
        print(f"SENU_SCENE_CHECK_OK objects={len(bpy.data.objects)} pivot={projected_pivot}; no render or saved files")
        return
    project = options.output_root.resolve()
    blend_path = project / "blender/personagens/senu_blockout.blend"
    sprite_path = project / "assets/sprites/senu_blockout.png"
    if options.check_atlas:
        image = bpy.data.images.load(str(sprite_path), check_existing=False)
        if tuple(image.size) != (FRAME_WIDTH * 8, FRAME_HEIGHT):
            raise RuntimeError(f"Wrong atlas dimensions: {tuple(image.size)}")
        pixels = list(image.pixels[:])
        for frame, direction in enumerate(DIRECTIONS):
            occupied = [(x, FRAME_HEIGHT - 1 - y) for y in range(FRAME_HEIGHT) for x in range(FRAME_WIDTH)
                        if pixels[(y * FRAME_WIDTH * 8 + frame * FRAME_WIDTH + x) * 4 + 3] > 0.5]
            if not occupied:
                raise RuntimeError(f"Empty frame: {direction}")
            bounds = (min(p[0] for p in occupied), min(p[1] for p in occupied), max(p[0] for p in occupied), max(p[1] for p in occupied))
            print(f"SENU_BOUNDS {direction} {bounds}")
            if bounds[0] <= 0 or bounds[1] <= 0 or bounds[2] >= FRAME_WIDTH - 1 or bounds[3] >= FRAME_HEIGHT - 1:
                raise RuntimeError(f"Frame clipped at image edge: {direction} {bounds}")
        print("SENU_ATLAS_CHECK_OK eight nonempty frames, no clipped bounds")
        return
    blend_path.parent.mkdir(parents=True, exist_ok=True)
    sprite_path.parent.mkdir(parents=True, exist_ok=True)
    scene, character = make_scene()
    character.rotation_euler.z = math.atan2(6.0, 8.0)
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    width = create_atlas(scene, character, sprite_path)
    metadata = {
        "description": "Original procedural blockout, idle proof only; not final art or an animation set.",
        "blender_version": bpy.app.version_string,
        "image": "senu_blockout.png", "width": width, "height": FRAME_HEIGHT,
        "frame_width": FRAME_WIDTH, "frame_height": FRAME_HEIGHT,
        "pivot": list(PIVOT), "directions": DIRECTIONS,
        "filter": "nearest", "suggested_game_scale": 0.5,
        "animations": {"idle": {"frames": list(range(8)), "directional": True}},
    }
    sprite_path.with_suffix(".json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"SENU_BLOCKOUT_OK {blend_path}")
    print(f"SENU_ATLAS_OK {sprite_path} {width}x{FRAME_HEIGHT}")


if __name__ == "__main__":
    main()
