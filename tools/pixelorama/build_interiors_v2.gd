extends SceneTree
## Packs newly authored imagegen poses into editable Pixelorama cels. No face
## patches, skeleton warping or runtime sprite scaling drives the animation.
const DIR := "res://art/pixelorama/interiors_v2"
const CELL := Vector2i(128, 144)
const PIVOT := Vector2i(64, 112)
const COLS := 8
const Palette = preload("res://tools/pixelorama/build_interiors_v1.gd")
const PEOPLE := ["hori", "sabu", "merit", "nakht", "adiam", "tarek"]
const PROPS := ["bed", "table", "shelf_a", "shelf_b", "counter", "trade_chest", "furnace", "anvil", "rack", "cords", "easel", "tub", "saddle", "amphora", "chest_closed", "chest_open"]
const SIZES := [Vector2i(64, 40), Vector2i(52, 32), Vector2i(60, 58), Vector2i(60, 58), Vector2i(100, 48), Vector2i(72, 36), Vector2i(96, 77), Vector2i(34, 35), Vector2i(56, 54), Vector2i(56, 55), Vector2i(38, 45), Vector2i(38, 29), Vector2i(38, 38), Vector2i(19, 32), Vector2i(32, 24), Vector2i(32, 34)]
var frames: Array[Image] = []
var sprites := {}
var palette: Array[Color] = []
var cached := {}

func _init() -> void:
	for hex in Palette.PAL.values(): palette.append(Color(hex))
	var zip := ZIPReader.new()
	assert(zip.open(ProjectSettings.globalize_path("res://art/pixelorama/interiors_v1/interiors_v1.pxo")) == OK)
	var data: Dictionary = JSON.parse_string(zip.read_file("data.json").get_string_from_utf8())
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/interiors_v1_manifest.json"))["sprites"]
	# Keep only the two pieces that were not redesigned; no obsolete NPC cels.
	for name in ["barrel", "coal"]:
		sprites[name] = original[name].duplicate(true)
		sprites[name]["frames"] = []
		for index in original[name]["frames"]:
			sprites[name]["frames"].append(frames.size())
			frames.append(Image.create_from_data(CELL.x, CELL.y, false, Image.FORMAT_RGBA8, zip.read_file("image_data/frames/%d/layer_1" % (int(index) + 1))))
	zip.close()
	_build_people()
	_build_props()
	_save()
	print("INTERIORS_V2 frames=", frames.size(), " sprites=", sprites.size())
	quit()

func _clean(image: Image, key: bool) -> void:
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a < .6 or (key and minf(c.r, c.b) > .35 and c.r > c.g * 1.7 and c.b > c.g * 1.7):
				image.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				c.a = 1
				image.set_pixel(x, y, c)

func _color(c: Color) -> Color:
	var key := c.to_rgba32()
	if cached.has(key): return cached[key]
	var distance := INF
	var chosen := palette[0]
	for candidate in palette:
		var d := pow(c.r - candidate.r, 2) + pow(c.g - candidate.g, 2) + pow(c.b - candidate.b, 2)
		if d < distance:
			distance = d
			chosen = candidate
	cached[key] = chosen
	return chosen

func _cel(piece: Image, size: Vector2i) -> Image:
	piece.resize(size.x, size.y, Image.INTERPOLATE_NEAREST)
	for y in range(piece.get_height()):
		for x in range(piece.get_width()):
			var c := piece.get_pixel(x, y)
			if c.a > 0: piece.set_pixel(x, y, _color(c))
			else: piece.set_pixel(x, y, Color(0, 0, 0, 0))
	var result := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
	result.blit_rect(piece, Rect2i(Vector2i.ZERO, size), PIVOT + Vector2i(-size.x / 2, -size.y + 1))
	return result

## Locate complete isolated silhouettes instead of assuming a generated grid
## cannot drift. This preserves hair, feet, ropes and the forge chimney.
func _regions(source: Image, rows: int) -> Dictionary:
	var pixels := source.get_data()
	var width := source.get_width()
	var height := source.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var regions := {}
	for start in range(width * height):
		if visited[start] or pixels[start * 4 + 3] == 0: continue
		var queue := PackedInt32Array([start])
		visited[start] = 1
		var cursor := 0
		var min_x := width
		var min_y := height
		var max_x := 0
		var max_y := 0
		while cursor < queue.size():
			var index := queue[cursor]
			cursor += 1
			var x: int = index % width
			var y: int = index / width
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var nx := x + ox
					var ny := y + oy
					if nx < 0 or nx >= width or ny < 0 or ny >= height: continue
					var neighbor := ny * width + nx
					if not visited[neighbor] and pixels[neighbor * 4 + 3] > 0:
						visited[neighbor] = 1
						queue.append(neighbor)
		if queue.size() < 300: continue
		var rect := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
		var center := Vector2(rect.get_center())
		var slot := Vector2i(clampi(int(center.x * 4 / width), 0, 3), clampi(int(center.y * rows / height), 0, rows - 1))
		regions[slot] = (regions[slot] as Rect2i).merge(rect) if regions.has(slot) else rect
	assert(regions.size() == rows * 4, "Generated atlas must contain every isolated silhouette")
	return regions

func _build_people() -> void:
	var source := Image.load_from_file(DIR + "/sources/npcs_key.png")
	assert(source != null)
	_clean(source, true)
	var regions := _regions(source, 6)
	for row in range(6):
		var pieces: Array[Image] = []
		var tallest := 1
		for col in range(4):
			var rect: Rect2i = regions[Vector2i(col, row)]
			assert(rect.size.x > 20 and rect.size.y > 60)
			pieces.append(source.get_region(rect))
			tallest = maxi(tallest, rect.size.y)
		var indices := []
		for piece in pieces:
			var size := Vector2i(roundi(piece.get_width() * 44.0 / tallest), roundi(piece.get_height() * 44.0 / tallest))
			indices.append(frames.size())
			frames.append(_cel(piece, size))
		var sequence := []
		for pair in [[0, 14], [1, 6], [0, 15], [2, 1], [0, 6], [3, 4], [0, 2]]:
			for unused in range(pair[1]): sequence.append(pair[0])
		sprites[PEOPLE[row]] = {"frames": indices, "sequence": sequence, "fps": 8, "authored_poses": ["rest", "breathe", "blink", "gesture"]}

func _build_props() -> void:
	var source := Image.load_from_file(DIR + "/sources/furniture.png")
	assert(source != null)
	_clean(source, false)
	var regions := _regions(source, 4)
	for i in range(PROPS.size()):
		var piece := source.get_region(regions[Vector2i(i % 4, i / 4)])
		sprites[PROPS[i]] = {"frames": [frames.size()]}
		frames.append(_cel(piece, SIZES[i]))
		if PROPS[i] == "furnace":
			var base := frames[-1]
			for step in [1, 2]:
				var cel := base.duplicate() as Image
				for y in range(80, 107):
					for x in range(28, 63):
						var c := cel.get_pixel(x, y)
						if c.a > 0 and c.r > .65 and c.g > .2 and c.b < .5 and (x + y + step) % 3 == 0:
							cel.set_pixel(x, y, Color(Palette.PAL["flame" if step == 1 else "glow"]))
				sprites["furnace"]["frames"].append(frames.size())
				frames.append(cel)
			sprites["furnace"]["sequence"] = [0, 1, 2, 1]
			sprites["furnace"]["fps"] = 8

func _save() -> void:
	var descriptors := []
	for cel in frames: descriptors.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tags := []
	for id in sprites:
		var ids: Array = sprites[id]["frames"]
		tags.append({"name": id, "color": "609087ff", "from": int(ids[0]) + 1, "to": int(ids[-1]) + 1})
	var data := {"pixelorama_version": "v1.2.3-stable", "pxo_version": 7, "size_x": CELL.x, "size_y": CELL.y, "color_mode": 5, "layers": [{"name": "NPCs e interiores redesenhados", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}], "frames": descriptors, "tags": tags, "fps": 8.0, "current_frame": 3, "current_layer": 0, "export_profile": {"orientation": "1", "lines_count": str(COLS), "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}}
	var zip := ZIPPacker.new()
	assert(zip.open(ProjectSettings.globalize_path(DIR + "/interiors_v2.pxo")) == OK)
	_zip(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for i in range(frames.size()): _zip(zip, "image_data/frames/%d/layer_1" % (i + 1), frames[i].get_data())
	_zip(zip, "preview.png", frames[3].save_png_to_buffer())
	zip.close()
	var plan := {"version": 2, "canvas": [CELL.x, CELL.y], "pivot": [PIVOT.x, PIVOT.y], "columns": COLS, "frames": frames.size(), "pixel_art": true, "palette": Palette.PAL.values(), "source": DIR + "/interiors_v2.pxo", "texture": "res://assets/world/interiors_v2.png", "sprites": sprites}
	FileAccess.open(DIR + "/export_plan.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	FileAccess.open("res://assets/world/interiors_v2_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	var sheet := Image.create_empty(CELL.x * COLS, CELL.y * ceili(frames.size() / float(COLS)), false, Image.FORMAT_RGBA8)
	for i in range(frames.size()): sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, CELL), Vector2i(i % COLS, i / COLS) * CELL)
	sheet.save_png("res://assets/world/interiors_v2.png")
	var preview := sheet.duplicate() as Image
	preview.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	preview.save_png("res://qa/interiors_v2_preview.png")

func _zip(zip: ZIPPacker, path: String, data: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(data)
	zip.close_file()
