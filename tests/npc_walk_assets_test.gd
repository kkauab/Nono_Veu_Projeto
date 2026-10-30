extends SceneTree
## Walking-only asset contract; no world or journey slot is loaded.
const WalkArt = preload("res://scripts/world/npc_walk_art.gd")
const Catalog = preload("res://scripts/world/port_life_catalog.gd")
const CELL := Vector2i(64,64)
const PIVOT := Vector2i(32,58)
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func _run() -> void:
	if not FileAccess.file_exists(WalkArt.MANIFEST) or not FileAccess.file_exists(WalkArt.TEXTURE):
		check(false, "Walking atlas and manifest exist")
		finish()
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(WalkArt.MANIFEST))
	if not parsed is Dictionary:
		check(false, "Walking manifest is valid JSON")
		finish()
		return
	var data: Dictionary = parsed
	var sheet := Image.load_from_file(WalkArt.TEXTURE)
	check(sheet != null, "Walking atlas PNG is readable")
	if sheet == null:
		finish()
		return
	check(Vector2i(data.canvas[0],data.canvas[1]) == CELL, "Walking canvas matches the unchanged resident canvas")
	check(Vector2i(data.pivot[0],data.pivot[1]) == PIVOT, "Walking feet use the unchanged physical foot pivot")
	check(int(data.columns) == 8 and int(data.frames) == 192, "Twelve appearances have eight phases with and without cargo")
	check(sheet.get_size() == Vector2i(512,1536), "Walking atlas has no missing rows or unexpected scaling")
	check(data.looks == Catalog.LOOKS, "Walking rows preserve the existing appearance indices")
	check(data.sprites.size() == Catalog.LOOKS.size(), "Walking atlas covers every current appearance")
	var zip := ZIPReader.new()
	var native_ok := zip.open(ProjectSettings.globalize_path(data.source)) == OK
	check(native_ok, "Walking source is an editable Pixelorama project")
	var native: Dictionary = JSON.parse_string(zip.read_file("data.json").get_string_from_utf8()) if native_ok else {}
	if native_ok:
		check(native.frames.size() == 192, "Pixelorama contains every exported walking cel")
		check(int(native.size_x) == 64 and int(native.size_y) == 64, "Pixelorama canvas matches the game")
	var used := {}
	for look in Catalog.LOOKS:
		if not data.sprites.has(look):
			continue
		var sprite: Dictionary = data.sprites[look]
		for action in ["walk","carry"]:
			var indices: Array = sprite.get(action,[])
			check(indices.size() == 8, "%s %s has eight timed phases" % [look,action])
			var unique := {}
			for index in indices:
				var frame := int(index)
				check(frame >= 0 and frame < 192, "%s %s index%d is inside the atlas" % [look,action,frame])
				if frame < 0 or frame >= 192:
					continue
				check(not used.has(frame), "%s %s owns a distinct cel%d" % [look,action,frame])
				used[frame] = true
				var cel := sheet.get_region(Rect2i(Vector2i(frame%8,frame/8)*CELL,CELL))
				var rect := cel.get_used_rect()
				check(rect.size.x > 8 and rect.size.y > 24, "%s %s phase%d contains a complete body" % [look,action,frame])
				check(rect.position.x > 0 and rect.end.x < CELL.x and rect.position.y > 0 and rect.end.y < CELL.y, "%s %s phase%d has safe drawing margins" % [look,action,frame])
				# Isometric far-foot depth occupies the contact shadow's -3..+2 band;
				# it need not hit the very same screen row as the near-foot contact.
				check(rect.end.y >= PIVOT.y-3 and rect.end.y <= PIVOT.y+2, "%s %s phase%d contacts the stable floor shadow" % [look,action,frame])
				var bytes := cel.get_data()
				var binary := true
				for offset in range(3,bytes.size(),4):
					if bytes[offset] != 0 and bytes[offset] != 255:
						binary = false
						break
				check(binary, "%s %s phase%d has binary alpha for crisp pixels" % [look,action,frame])
				unique[bytes.hex_encode().sha256_text()] = true
				if native_ok:
					check(zip.read_file("image_data/frames/%d/layer_1" % [frame+1]) == bytes, "%s %s phase%d exactly matches its editable source" % [look,action,frame])
			check(unique.size() == 8, "%s %s uses eight distinct complete drawings" % [look,action])
		if data.get("registrations",{}).has(look):
			var record: Dictionary = data.registrations[look]
			check(record.get("registrations",[]).size() == 16, "%s records each complete source pose" % look)
			check(float(record.get("uniform_scale",0)) > 0, "%s uses a documented single authoring scale" % look)
		else:
			check(false, "%s source registration is documented" % look)
	check(used.size() == 192, "All walking cels are used exactly once")
	if native_ok:
		zip.close()
	var originals: Dictionary = data.get("original_files",{})
	check(originals.size() >= 6, "Original nonwalking assets are recorded for preservation")
	for path in originals:
		check(FileAccess.file_exists(path) and FileAccess.get_sha256(path) == originals[path], "Nonwalking asset preserved byte-for-byte: "+path)
	# The eight contacts are selected from physical distance, with two steps per24px.
	for pair in [[0.0,0],[2.99,0],[3.0,1],[11.99,3],[12.0,4],[23.99,7],[24.0,0],[27.0,1]]:
		check(WalkArt.phase_index(pair[0]) == pair[1], "Ground distance%.2f selects phase%d" % [pair[0],pair[1]])
	WalkArt._ensure()
	check(not WalkArt.draw(null,-1,false,0.0), "Missing appearance declines drawing so the resident renderer can fall back")
	check(not WalkArt.draw(null,12,true,0.0), "Out-of-range appearance safely declines drawing")
	var texture: Texture2D = WalkArt._texture
	WalkArt._texture = null
	check(not WalkArt.draw(null,0,false,12.0), "Unavailable walking texture safely keeps the existing renderer")
	WalkArt._texture = texture
	finish()

func finish() -> void:
	print("NPC WALK ASSETS checks=%d passed=%d failures=%s" % [checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
