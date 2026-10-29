extends SceneTree
## Correct the native furniture cels against the same 2:1 grid as Layout.iso.
## Every source column keeps its height and colors; only its integer ground
## position changes. NPC poses are copied byte-for-byte, not transformed.
const DIR := "res://art/pixelorama/interiors_v4"
const SOURCE := "res://art/pixelorama/interiors_v3"
const CELL := Vector2i(128, 144)
const PIVOT := Vector2i(64, 112)
const COLS := 8
## Left contact, right contact and the shared front corner, in cel-pivot pixels.
## These are geometric face edges, not the noisy bottom of individual columns.
const FACES := {
	"counter": [Vector2(-38, -22), Vector2(38, -7), Vector2(23, 0)],
	"shelf_a": [Vector2(-29, -14), Vector2(29, -6), Vector2(20, 0)],
	"shelf_b": [Vector2(-29, -13), Vector2(29, -6), Vector2(14, 0)],
	"furnace": [Vector2(-43, -20), Vector2(43, -16), Vector2(9, 0)],
	"rack": [Vector2(-28, -16), Vector2(27, -5), Vector2(17, 0)],
	"cords": [Vector2(-28, -15), Vector2(27, -5), Vector2(17, 0)],
	"trade_chest": [Vector2(-23, -12), Vector2(22, -7), Vector2(8, 0)],
	"bed": [Vector2(-27, -7), Vector2(27, -12), Vector2(-8, 0)],
	"chest_closed": [Vector2(-16, -8), Vector2(15, -5), Vector2(6, 0)],
	"chest_open": [Vector2(-16, -8), Vector2(15, -5), Vector2(6, 0)]
}
## Round objects and separate feet need no face shear. Center their real
## contact plane; never force curved edges or gaps between legs into a box.
const CONTACTS := {
	"amphora": [Vector2(-6, -4), Vector2(5, -4), Vector2(7, -2), Vector2(4, 0), Vector2(-4, 0), Vector2(-7, -2)],
	"table": [Vector2(-18, -8), Vector2(0, -15), Vector2(17, -8), Vector2(0, 0)],
	"anvil": [Vector2(-16, -6), Vector2(-3, -12), Vector2(10, -6), Vector2(9, -2), Vector2(-3, 0), Vector2(-13, -2)],
	"tub": [Vector2(-17, -6), Vector2(-11, -12), Vector2(11, -12), Vector2(17, -6), Vector2(12, -1), Vector2(-12, -1)],
	"easel": [Vector2(-15, -8), Vector2(8, -17), Vector2(16, -9), Vector2(6, 0), Vector2(2, 0)],
	"saddle": [Vector2(-18, -8), Vector2(1, -18), Vector2(17, -8), Vector2(-6, 0)],
	"barrel": [Vector2(-7, -3), Vector2(0, -7), Vector2(7, -3), Vector2(0, 0)],
	"coal": [Vector2(-13, -1), Vector2(0, -8), Vector2(13, -1), Vector2(0, 0)]
}

func _init() -> void:
	var source := ZIPReader.new()
	assert(source.open(ProjectSettings.globalize_path(SOURCE + "/interiors_v3.pxo")) == OK)
	var data: Dictionary = JSON.parse_string(source.read_file("data.json").get_string_from_utf8())
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE + "/export_plan.json"))
	var frames: Array[Image] = []
	for index in range(int(plan["frames"])):
		frames.append(Image.create_from_data(CELL.x, CELL.y, false, Image.FORMAT_RGBA8, source.read_file("image_data/frames/%d/layer_1" % (index + 1))))
	source.close()
	for name in plan["sprites"]:
		var entry: Dictionary = plan["sprites"][name]
		var base := PackedVector2Array()
		var offset := Vector2.ZERO
		if FACES.has(name):
			var face: Array = FACES[name]
			var left: Vector2 = face[0]
			var right: Vector2 = face[1]
			var front: Vector2 = face[2]
			var l := Vector2(left.x, -.5 * (front.x - left.x))
			var r := Vector2(right.x, -.5 * (right.x - front.x))
			var f := Vector2(front.x, 0)
			var back := l + r - f
			offset = -((back + f) * .5)
			base = PackedVector2Array([back + offset, r + offset, f + offset, l + offset])
		elif CONTACTS.has(name):
			base = PackedVector2Array(CONTACTS[name])
			var center := Vector2.ZERO
			for point in base: center += point
			offset = -(center / base.size()).round()
			for i in range(base.size()): base[i] += offset
		if base.is_empty(): continue
		entry["ground_base"] = []
		for point in base: entry["ground_base"].append([point.x, point.y])
		entry["ground_centered"] = true
		if FACES.has(name): entry["ground_projection"] = "2:1"
		for index in entry["frames"]:
			frames[int(index)] = _project(frames[int(index)], FACES.get(name, []), offset)
		var bounds := frames[int(entry["frames"][0])].get_used_rect()
		entry["painted_columns"] = [bounds.position.x - PIVOT.x, bounds.end.x - PIVOT.x]
	plan["version"] = 4
	plan["source"] = DIR + "/interiors_v4.pxo"
	plan["texture"] = "res://assets/world/interiors_v4.png"
	data["layers"][0]["name"] = "Moveis na malha 2:1 e NPCs preservados"
	data["current_frame"] = int(plan["sprites"]["counter"]["frames"][0])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var zip := ZIPPacker.new()
	assert(zip.open(ProjectSettings.globalize_path(DIR + "/interiors_v4.pxo")) == OK)
	_zip(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for index in range(frames.size()): _zip(zip, "image_data/frames/%d/layer_1" % (index + 1), frames[index].get_data())
	_zip(zip, "preview.png", frames[int(data["current_frame"])].save_png_to_buffer())
	zip.close()
	FileAccess.open(DIR + "/export_plan.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	print("INTERIORS_V4: corrected native cels, metadata and ground anchors; frames=", frames.size())
	quit()

func _project(source: Image, face: Array, offset: Vector2) -> Image:
	var result := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	for x in range(CELL.x):
		var shift := offset.y
		if not face.is_empty():
			var local_x := float(x - PIVOT.x)
			var left: Vector2 = face[0]
			var right: Vector2 = face[1]
			var front: Vector2 = face[2]
			var actual := 0.0
			if local_x <= front.x:
				actual = lerpf(left.y, front.y, (local_x - left.x) / (front.x - left.x))
			else:
				actual = lerpf(front.y, right.y, (local_x - front.x) / (right.x - front.x))
			shift += -.5 * absf(local_x - front.x) - actual
		for y in range(CELL.y):
			var color := source.get_pixel(x, y)
			if color.a8 == 0: continue
			var target := Vector2i(x + roundi(offset.x), y + roundi(shift))
			assert(Rect2i(Vector2i.ZERO, CELL).has_point(target), "Projection cannot clip the furniture")
			result.set_pixelv(target, color)
	return result

func _zip(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()
