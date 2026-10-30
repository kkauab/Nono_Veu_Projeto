extends "res://tools/pixelorama/build_townsfolk_v1.gd"
## Completes the existing residents, preserving every v1 cel byte for byte.
## New rest poses are painted with the same pixel components, never scaled.
const DIR_V2 := "res://art/pixelorama/npcs_v2"
const NEW_POSES := ["breathe", "blink", "carry_breathe", "carry_blink"]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR_V2))
	var original := Image.load_from_file(OUT)
	assert(original != null)
	var poses := Array(POSES) + NEW_POSES
	var frames: Array[Image] = []
	var sprites := {}
	var looks := []
	for row in range(LOOKS.size()):
		_look = LOOKS[row]
		looks.append(_look["id"])
		var indices := []
		for column in range(poses.size()):
			if column < POSES.size():
				_img = original.get_region(Rect2i(Vector2i(column * CELL.x, row * CELL.y), CELL))
			else:
				_img = Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
				_rest_pose(column >= 14, column % 2 == 1)
				_shade()
				_outline()
			indices.append(frames.size())
			frames.append(_img)
		sprites[_look["id"]] = {"frames": indices, "authored_poses": poses}
	var plan := {"version": 2, "cell": [CELL.x, CELL.y], "canvas": [CELL.x, CELL.y], "pivot": [PIVOT.x, PIVOT.y], "columns": poses.size(), "frames": frames.size(), "looks": looks, "poses": poses, "texture": "res://assets/world/townsfolk_v2.png", "source": DIR_V2 + "/townsfolk_v2.pxo", "sprites": sprites}
	_write_native(frames, sprites, poses.size(), plan)
	print("TOWNSFOLK_V2 looks=%d poses=%d frames=%d" % [looks.size(), poses.size(), frames.size()])
	quit()

func _rest_pose(carrying: bool, blink: bool) -> void:
	var pose := "carry_idle" if carrying else "idle"
	var step: Array = STEPS["idle"]
	var stoop: int = _look.get("stoop", 0)
	var hip := Vector2(0, -17)
	# Inhale opens the chest by one pixel; head, soles and load stay anchored.
	var shoulder := Vector2(stoop, -29 + stoop - (0 if blink else 1))
	var head := Vector2(1 + 2 * stoop, -35 + stoop)
	var skin: String = _look["skin"]
	var far_foot := Vector2(-1, 0)
	var near_foot := Vector2(1, 0)
	_leg(hip + Vector2(-1, 0), far_foot, _darker(skin))
	_arm_far(pose, shoulder, step, carrying, _darker(skin))
	_body(pose, hip, shoulder, near_foot, far_foot)
	_head(head, pose)
	if blink:
		# Painted closed lid with a crease; opaque face silhouette is unchanged.
		_px(roundi(head.x) + 2, roundi(head.y) - 1, _darker(skin))
		_px(roundi(head.x) + 3, roundi(head.y) - 1, _darker(skin))
	if carrying: _load_behind(Vector2(stoop, -29 + stoop), head)
	_leg_near(hip, near_foot, skin)
	_arm_near(pose, shoulder, step, carrying, skin)
	if carrying: _load_front(Vector2(stoop, -29 + stoop), head)
	elif _look["load"] == "scroll": _scroll(Vector2(stoop, -29 + stoop))

func _write_native(frames: Array[Image], sprites: Dictionary, columns: int, plan: Dictionary) -> void:
	var descriptors := []
	var tags := []
	for frame in frames: descriptors.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	for id in sprites:
		var ids: Array = sprites[id]["frames"]
		tags.append({"name": id, "color": "609087ff", "from": int(ids[0]) + 1, "to": int(ids[-1]) + 1})
	var data := {"pixelorama_version": "v1.2.3-stable", "pxo_version": 7, "size_x": CELL.x, "size_y": CELL.y, "color_mode": 5, "layers": [{"name": "Moradores: poses completas", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}], "frames": descriptors, "tags": tags, "fps": 8.0, "current_frame": 0, "current_layer": 0, "export_profile": {"orientation": "1", "lines_count": str(columns), "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}}
	var zip := ZIPPacker.new()
	assert(zip.open(ProjectSettings.globalize_path(plan["source"])) == OK)
	_zip(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for i in range(frames.size()): _zip(zip, "image_data/frames/%d/layer_1" % (i + 1), frames[i].get_data())
	_zip(zip, "preview.png", frames[0].save_png_to_buffer())
	zip.close()
	FileAccess.open(DIR_V2 + "/townsfolk_v2_export_plan.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	FileAccess.open("res://assets/world/townsfolk_v2_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))

func _zip(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()
