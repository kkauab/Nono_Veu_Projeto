extends RefCounted
## Six authored cutting phases in five real views plus mirrored left views.
## The wrist, blade and body stay connected; the compact atlas loads once.

const PATH := "res://assets/sprites/senu_sword_v8_manifest.json"
static var _loaded := false
static var _texture: Texture2D
static var _data: Dictionary = {}

static func _ensure() -> bool:
	if _loaded:
		return _texture != null
	_loaded = true
	if not FileAccess.file_exists(PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not parsed is Dictionary:
		return false
	var path := str(parsed.get("texture", ""))
	if not path.begins_with("res://assets/sprites/") or path.contains("..") or not ResourceLoader.exists(path):
		return false
	_data = parsed
	_texture = load(path) as Texture2D
	return _texture != null

static func sample(frame: Dictionary, duration: float) -> Dictionary:
	if frame.get("weapon") != "espada" or frame.get("state") not in ["attack_light", "attack_heavy", "power"] or not _ensure():
		return frame
	var state := "attack_light" if frame["state"] == "attack_light" else "attack_heavy"
	var clips: Dictionary = _data.get("clips", {})
	var directions: Dictionary = clips.get(state, {})
	var sequence: Array = directions.get(frame["direction"], [])
	if sequence.size() != 6:
		return frame
	var elapsed := float(frame.get("elapsed", 0)) + .00001
	var impact := .12 if state == "attack_light" else (.15 if frame["state"] == "power" else .24)
	var contact := 3
	var position := 0
	if elapsed >= impact + .15:
		position = 5
	elif elapsed >= impact + .055:
		position = 4
	elif elapsed >= impact:
		position = contact
	elif elapsed >= impact * .60:
		position = 2
	elif elapsed >= minf(.035, impact * .22):
		position = 1
	# The final cel is a genuine return to guard, not the contact held still.
	if elapsed >= maxf(impact + .15, duration - .035): position = 5
	var index := int(sequence[position])
	var regions: Array = _data.get("frame_regions", [])
	if index < 0 or index >= regions.size():
		return frame
	var r: Array = regions[index]
	var pivot: Array = _data["pivot"]
	var canvas: Array = _data["canvas"]
	var scale := float(_data["game_scale"])
	var result := frame.duplicate()
	result["frame"] = index
	result["region"] = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	result["offset"] = -Vector2(float(pivot[0]), float(pivot[1])) * scale
	result["size"] = Vector2(float(canvas[0]), float(canvas[1])) * scale
	result["texture"] = _texture
	result["texture_path"] = _texture.resource_path
	result["frame_position"] = position
	result["frame_count"] = sequence.size()
	result["modular_equipment"] = false
	result["embedded_equipment"] = true
	result["body_model_id"] = "senu_guided_cut_v8"
	result["impact_time"] = impact
	result["cut_pose"] = ["preparação", "antecipação", "aceleração", "contato", "continuação", "recuperação"][position]
	return result
