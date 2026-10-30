extends SceneTree
## New NPC asset contract only. Does not instantiate the world or read a save.
const LOOKS := ["estivador", "carregador", "peixeira", "mercador", "marinheiro", "remador", "escriba", "peregrina", "velho", "aguadeira", "padeira", "caravaneiro"]
const POSES := ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "talk", "carry_idle", "carry_1", "carry_2", "carry_3", "carry_4", "bend", "breathe", "blink", "carry_breathe", "carry_blink"]
const People = preload("res://scripts/world/townsfolk.gd")
const NpcArt = preload("res://scripts/world/npc_art.gd")
const Catalog = preload("res://scripts/world/port_life_catalog.gd")
var checks := 0
var failures: Array[String] = []
var _idle_hashes := {}

func _init() -> void:
	check(Array(Catalog.LOOKS) == LOOKS, "NPC appearance order retains catalog indices")
	validate_sheet("townsfolk_v3", LOOKS, POSES, Vector2i(64, 64), Vector2i(32, 58), 16)
	validate_sheet("ankhet_v3", ["ankhet"], ["rest", "breathe", "blink", "gesture"], Vector2i(128, 144), Vector2i(64, 112), 4)
	validate_runtime_poses()
	print("NPC SPRITES V3 checks=%d passed=%d failures=%s" % [checks, checks-failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func digest(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func rectangle(values: Array) -> Rect2i:
	return Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))

func region(sheet: Image, index: int, cell: Vector2i, columns: int) -> Image:
	return sheet.get_region(Rect2i(Vector2i(index % columns, index / columns) * cell, cell))

func validate_sheet(name: String, looks: Array, poses: Array, cell: Vector2i, pivot: Vector2i, columns: int) -> void:
	var prefix := "res://assets/world/" + name
	if not FileAccess.file_exists(prefix + "_manifest.json"):
		check(false, "%s manifest exists" % name)
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + "_manifest.json"))
	var sheet := Image.load_from_file(prefix + ".png")
	if sheet == null:
		check(false, "%s texture exists" % name)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	check(Vector2i(data.canvas[0], data.canvas[1]) == cell, "%s preserves native cell" % name)
	check(Vector2i(data.pivot[0], data.pivot[1]) == pivot, "%s preserves physical foot pivot" % name)
	check(int(data.columns) == columns, "%s exported columns match drawing contract" % name)
	check(int(data.frames) == looks.size() * poses.size(), "%s complete frame count" % name)
	check(sheet.get_size() == Vector2i(columns * cell.x, looks.size() * cell.y), "%s exported atlas dimensions" % name)
	check(int(data.get("runtime_scale", 0)) == 1, "%s uses native pixels at runtime" % name)
	check(data.get("pixel_art", false), "%s declares pixel art" % name)
	if name == "townsfolk_v3":
		check(data.looks == looks and data.poses == poses, "Resident indices and authored pose order remain compatible")
		check(People.SHEET == data.texture, "Residents draw the delivered v3 atlas")
		check(People.CELL == Vector2(cell) and People.PIVOT == Vector2(pivot), "Runtime crops and places v3 cels with the manifest contract")
		check(Array(People.POSES) == poses, "Runtime pose indices match authored names")
	else:
		check(NpcArt.TEXTURE == data.texture and NpcArt.MANIFEST == prefix + "_manifest.json", "Island draws Ankhet v3 with its own manifest")
	var palette := {}
	for color in data.palette:
		palette[Color(color).to_rgba32()] = true
	check(palette.size() == 33, "%s retains world palette" % name)
	var archive := ZIPReader.new()
	var archive_ok := archive.open(ProjectSettings.globalize_path(data.source)) == OK
	check(archive_ok, "%s editable Pixelorama project exists" % name)
	if not archive_ok: return
	var native: Dictionary = JSON.parse_string(archive.read_file("data.json").get_string_from_utf8())
	check(int(native.size_x) == cell.x and int(native.size_y) == cell.y, "%s native canvas matches atlas" % name)
	check(native.frames.size() == int(data.frames), "%s native project contains all authored cels" % name)
	var old_sheet := Image.load_from_file("res://assets/world/" + ("townsfolk_v2" if name == "townsfolk_v3" else "ankhet_v2") + ".png")
	if old_sheet != null: old_sheet.convert(Image.FORMAT_RGBA8)
	for row in range(looks.size()):
		var look: String = looks[row]
		var sprite: Dictionary = data.sprites[look]
		check(sprite.authored_poses == poses, "%s authored poses are complete" % look)
		check(sprite.frames.size() == poses.size(), "%s maps every authored pose" % look)
		var record: Dictionary = data.registrations[look]
		check(float(record.uniform_scale) > 0.0, "%s has one positive source scale" % look)
		check(record.registrations.size() == poses.size(), "%s keeps a registration per cel" % look)
		var source_path: String = "res://" + str(record.source)
		check(FileAccess.file_exists(source_path), "%s preserved source exists" % look)
		if FileAccess.file_exists(source_path):
			check(digest(FileAccess.get_file_as_bytes(source_path)) == record.sha256, "%s preserved source hash" % look)
		var unique := {}
		var frames: Array[Image] = []
		for pose in range(poses.size()):
			var index := int(sprite.frames[pose])
			check(index == row * poses.size() + pose, "%s/%s retains runtime index" % [look, poses[pose]])
			var frame := region(sheet, index, cell, columns)
			frames.append(frame)
			var bytes := frame.get_data()
			var frame_hash := digest(bytes)
			unique[frame_hash] = true
			check(digest(archive.read_file("image_data/frames/%d/layer_1" % (index+1))) == frame_hash, "%s/%s matches editable native cel" % [look, poses[pose]])
			var registration: Dictionary = record.registrations[pose]
			check(is_equal_approx(float(registration.scale), float(record.uniform_scale)), "%s/%s uses character's uniform scale" % [look, poses[pose]])
			var source_rect := rectangle(registration.source_rect)
			var source_size := Vector2i(record.source_size[0], record.source_size[1])
			check(Rect2i(Vector2i.ZERO, source_size).encloses(source_rect), "%s/%s source crop stays inside sheet" % [look, poses[pose]])
			var bounds: Array = registration.source_bounds
			var scale: float = registration.scale
			var offset: Array = registration.translation
			check(float(bounds[0])*scale + offset[0] >= -.5 and float(bounds[1])*scale + offset[1] >= -.5 and float(bounds[2])*scale + offset[0] <= cell.x+.5 and float(bounds[3])*scale + offset[1] <= cell.y+.5, "%s/%s complete pose fits canvas" % [look, poses[pose]])
			var binary := true
			var allowed := true
			var colors := {}
			for pixel in range(0, bytes.size(), 4):
				if bytes[pixel+3] not in [0,255]: binary = false
				if bytes[pixel+3] == 255:
					var rgba := (int(bytes[pixel]) << 24) | (int(bytes[pixel+1]) << 16) | (int(bytes[pixel+2]) << 8) | 255
					if not palette.has(rgba): allowed = false
					colors[rgba] = true
			check(binary, "%s/%s binary alpha" % [look, poses[pose]])
			check(allowed, "%s/%s world palette only" % [look, poses[pose]])
			check(colors.size() >= 8, "%s/%s retains material and face color clusters" % [look, poses[pose]])
			var used := frame.get_used_rect()
			check(used.size.x > 5 and used.size.y > 20, "%s/%s visible complete character" % [look, poses[pose]])
			check(used.end.y <= pivot.y+1, "%s/%s stays on the floor" % [look, poses[pose]])
		check(unique.size() >= 5 if looks.size() > 1 else unique.size() >= 3, "%s has distinct authored silhouettes" % look)
		var idle_hash := digest(frames[0].get_data())
		check(not _idle_hashes.has(idle_hash), "%s has its own appearance" % look)
		_idle_hashes[idle_hash] = true
		if old_sheet != null:
			var old := region(old_sheet, row * (16 if name == "townsfolk_v3" else 4), Vector2i(32,52) if name == "townsfolk_v3" else cell, columns)
			# Compare drawing pixels at the same foot origin, so larger transparent
			# margins alone cannot satisfy the art replacement check.
			var old_canvas := Image.create_empty(cell.x, cell.y, false, Image.FORMAT_RGBA8)
			var old_pivot := Vector2i(16,49) if name == "townsfolk_v3" else pivot
			old_canvas.blit_rect(old, Rect2i(Vector2i.ZERO, old.get_size()), pivot-old_pivot)
			check(idle_hash != digest(old_canvas.get_data()), "%s replaces simplified art beyond canvas margins" % look)
		var pairs := [[0,12], [0,13], [6,14], [6,15]] if looks.size() > 1 else [[0,1], [0,2], [0,3]]
		for pair in pairs:
			var foot_rect := Rect2i(0, pivot.y-18, cell.x, cell.y-pivot.y+18)
			check(frames[pair[0]].get_region(foot_rect).get_data() == frames[pair[1]].get_region(foot_rect).get_data(), "%s/%s resting lower legs and hem stay planted" % [look, poses[pair[1]]])
	archive.close()


func validate_runtime_poses() -> void:
	# Isolated nodes: exercise the real selection routine without world/save IO.
	for row in range(LOOKS.size()):
		var person := People.new()
		person.look = row
		person.kind = "vendor"
		person.position = Vector2(20, 30)
		for direction in [-1.0, 1.0]:
			person.facing = direction
			person.carrying = false
			person.time = 1.3 - row * .37
			check(person.pose() == 12, "%s breathes facing %s" % [LOOKS[row], direction])
			person.time = 4.75 - row * .37
			check(person.pose() == 13, "%s blinks facing %s" % [LOOKS[row], direction])
			person.carrying = true
			check(person.pose() == 15, "%s blinks without losing load facing %s" % [LOOKS[row], direction])
			person.time = 1.3 - row * .37
			check(person.pose() == 14, "%s breathes while carrying facing %s" % [LOOKS[row], direction])
			person.kind = "townsfolk"
			person._acting = false
			for step in range(4):
				person._walking = true
				person._walk_distance = (step+.25)*6.0
				person.carrying = false
				check(person.pose() == 1+step, "%s selects authored walk %d facing %s" % [LOOKS[row], step+1, direction])
				person.carrying = true
				check(person.pose() == 7+step, "%s selects authored loaded walk %d facing %s" % [LOOKS[row], step+1, direction])
			person._walking = false
			person.kind = "vendor"
		person.carrying = false
		person.time = .1
		person.gesture(.8)
		check(person.pose() == 5, "%s selects the complete talk gesture" % LOOKS[row])
		check(person.position == Vector2(20,30), "%s animation leaves physical foot position unchanged" % LOOKS[row])
		person.free()
