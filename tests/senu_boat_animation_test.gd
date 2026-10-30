extends SceneTree

## Atlas and selection contract only: no world or player save is loaded.
## Run after exporting the v2 Pixelorama sources.
const View = preload("res://scripts/actors/senu_boat_view.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")
const Boat = preload("res://scripts/world/sea_boat.gd")
const DIRECTIONS := {
	"down": Vector2.DOWN, "down_right": Vector2(1, 1),
	"right": Vector2.RIGHT, "up_right": Vector2(1, -1),
	"up": Vector2.UP, "up_left": Vector2(-1, -1),
	"left": Vector2.LEFT, "down_left": Vector2(-1, 1),
}
var checks := 0
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var hull := _manifest("res://assets/world/boat_v4_manifest.json")
	var transfer := _manifest("res://assets/sprites/senu_boat_v2_manifest.json")
	if hull.is_empty() or transfer.is_empty():
		_finish()
		return
	_check(_pair(hull, "canvas") == Vector2(128, 96) and _pair(hull, "pivot") == Vector2(64, 64), "Boat uses a larger padded canvas with the same world-space water pivot")
	_check(_pair(transfer, "canvas") == Vector2(96, 96) and _pair(transfer, "pivot") == Vector2(48, 76), "Transfer keeps a fixed foot pivot and unscaled pixel canvas")
	var hull_image := (load(str(hull.get("texture", ""))) as Texture2D).get_image()
	var transfer_image := (load(str(transfer.get("texture", ""))) as Texture2D).get_image()
	_check(hull_image != null and not hull_image.is_empty(), "Boat texture loads")
	_check(transfer_image != null and not transfer_image.is_empty(), "Transfer texture loads")
	if hull_image == null or transfer_image == null:
		_finish()
		return
	for direction in range(16):
		var name := "boat_%02d" % direction
		var sprite: Dictionary = hull.get("sprites", {}).get(name, {})
		var frames: Array = sprite.get("frames", [])
		_check(frames.size() == 10 and SeaArt.frame_count("boat_v4", name) == 10, "%s has idle, eight strokes, and empty hull" % name)
		if frames.size() != 10:
			continue
		var unique := {}
		var body_unique := {}
		for index in range(frames.size()):
			var cel := _cel(hull_image, hull, int(frames[index]))
			_check(_safe_cel(cel), "%s frame %d has visible pixels and transparent margins" % [name, index])
			if index > 0 and index <= 8:
				unique[hash(cel.get_data())] = true
				body_unique[hash(cel.get_region(Rect2i(50, 26, 28, 29)).get_data())] = true
		_check(unique.size() == 8, "%s has eight distinct rowing poses" % name)
		_check(body_unique.size() >= 4, "%s articulates the rower's body across the stroke, beyond the moving oar blades" % name)
		_check(_cel(hull_image, hull, int(frames[0])).get_data() != _cel(hull_image, hull, int(frames[9])).get_data(), "%s idle includes Senu while the moored hull is empty" % name)
	for state in ["board", "land"]:
		var selected_directions := {}
		for name in DIRECTIONS:
			var clip := "%s_%s" % [state, name]
			var frames: Array = transfer.get("sprites", {}).get(clip, {}).get("frames", [])
			_check(frames.size() == 6, "%s has six authored transition poses" % clip)
			if frames.size() != 6:
				continue
			var unique := {}
			var selections := {}
			var previous := -1
			for index in range(6):
				var cel := _cel(transfer_image, transfer, int(frames[index]))
				_check(_safe_cel(cel), "%s frame %d stays inside the canvas" % [clip, index])
				unique[hash(cel.get_data())] = true
				var pose: Dictionary = View.sample(state, DIRECTIONS[name], (index + .25) / 6.0)
				_check(not pose.is_empty(), "%s phase %d selects an exported pose" % [clip, index])
				if pose.is_empty():
					continue
				_check(int(pose.get("frame_count", 0)) == 6, "%s exposes its complete sequence" % clip)
				_check(pose.get("size") == Vector2(96, 96) and pose.get("offset") == Vector2(-48, -76), "%s phase %d preserves fixed body scale and pivot" % [clip, index])
				selections[int(pose.get("frame", -1))] = true
				previous = int(pose.get("frame", -1))
			_check(unique.size() == 6 and selections.size() == 6, "%s displays six different sprites without skipping a phase" % clip)
			var first: Dictionary = View.sample(state, DIRECTIONS[name], 0.0)
			var last: Dictionary = View.sample(state, DIRECTIONS[name], 1.0)
			var held: Dictionary = View.sample(state, DIRECTIONS[name], 3.0)
			var clamped: Dictionary = View.sample(state, DIRECTIONS[name], -1.0)
			_check(first.get("frame") == clamped.get("frame"), "%s clamps before the start" % clip)
			_check(last.get("frame") == held.get("frame") and last.get("frame") == previous, "%s holds the last frame instead of looping" % clip)
			selected_directions[clip] = first.get("frame")
		_check(selected_directions.size() == 8 and selected_directions.values().all(func(value): return selected_directions.values().count(value) == 1), "%s covers eight different facing clips" % state)
	_check(View.sample("unsupported", Vector2.DOWN, .5).is_empty(), "Unsupported transition state has no accidental animation")
	if "--preview" in OS.get_cmdline_user_args():
		_preview(hull_image, hull, transfer_image, transfer)
	_finish()


func _manifest(path: String) -> Dictionary:
	_check(FileAccess.file_exists(path), "Manifest exists: " + path)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(parsed is Dictionary, "Manifest parses: " + path)
	return parsed if parsed is Dictionary else {}


func _cel(image: Image, manifest: Dictionary, index: int) -> Image:
	var cell := Vector2i(int(manifest["canvas"][0]), int(manifest["canvas"][1]))
	var columns := int(manifest["columns"])
	return image.get_region(Rect2i(Vector2i(index % columns, index / columns) * cell, cell))


func _safe_cel(image: Image) -> bool:
	var used := image.get_used_rect()
	return used.has_area() and used.position.x > 0 and used.position.y > 0 and used.end.x < image.get_width() and used.end.y < image.get_height()


func _preview(hull_image: Image, hull: Dictionary, transfer_image: Image, transfer: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/boat_senu"))
	var image := Image.create_empty(128 * 10, 96 * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("203b40"))
	for row in range(4):
		var frames: Array = hull["sprites"]["boat_%02d" % (row * 4)]["frames"]
		for column in range(10):
			image.blend_rect(_cel(hull_image, hull, int(frames[column])), Rect2i(0, 0, 128, 96), Vector2i(column * 128, row * 96))
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("res://qa/boat_senu/rowing_qa.png")
	var transfers := Image.create_empty(96 * 6, 96 * 4, false, Image.FORMAT_RGBA8)
	transfers.fill(Color("203b40"))
	var row := 0
	for state in ["board", "land"]:
		for direction in ["down_right", "up_left"]:
			var frames: Array = transfer["sprites"]["%s_%s" % [state, direction]]["frames"]
			for column in range(6):
				transfers.blend_rect(_cel(transfer_image, transfer, int(frames[column])), Rect2i(0, 0, 96, 96), Vector2i(column * 96, row * 96))
			row += 1
	transfers.resize(transfers.get_width() * 2, transfers.get_height() * 2, Image.INTERPOLATE_NEAREST)
	transfers.save_png("res://qa/boat_senu/transfers_qa.png")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL " + label)


func _finish() -> void:
	print("SENU BOAT ANIMATION RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _pair(manifest: Dictionary, key: String) -> Vector2:
	var values: Array = manifest.get(key, [0, 0])
	return Vector2(float(values[0]), float(values[1]))
