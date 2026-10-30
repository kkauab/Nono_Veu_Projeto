extends Node2D
## Apresentação de embarque/desembarque: o corpo físico fica no plano do chão.
## O atlas contém poses articuladas do Senu real, sem armas durante a travessia.
const PATH := "res://assets/sprites/senu_boat_v2_manifest.json"
const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
static var _data: Dictionary = {}
static var _texture: Texture2D
var actor: Node2D
var state := "board"
var facing := Vector2.RIGHT
var progress := 0.0


static func sample(action: String, direction: Vector2, phase: float) -> Dictionary:
	if action not in ["board", "land"]:
		return {}
	if _texture == null:
		if not FileAccess.file_exists(PATH):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if not parsed is Dictionary:
			return {}
		_data = parsed
		_texture = load(str(_data["texture"])) as Texture2D
		if _texture == null:
			return {}
	var index := posmod(roundi(direction.angle() / (PI / 4.0)), 8)
	var clip: Dictionary = _data.get("sprites", {}).get(action + "_" + DIRECTIONS[index], {})
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return {}
	var step := mini(frames.size() - 1, int(clampf(phase, 0.0, 1.0) * frames.size()))
	var frame := int(frames[step])
	var columns := int(_data["columns"])
	var size := Vector2(float(_data["canvas"][0]), float(_data["canvas"][1]))
	return {"frame": frame, "frame_count": frames.size(), "frame_position": step,
		"texture": _texture, "size": size, "offset": -Vector2(float(_data["pivot"][0]), float(_data["pivot"][1])),
		"region": Rect2(Vector2(frame % columns, frame / columns) * size, size)}


static func draw_pose(canvas: CanvasItem, action: String, direction: Vector2, phase: float, lift: float = 0.0) -> void:
	var pose := sample(action, direction, phase)
	if pose.is_empty():
		return
	canvas.draw_texture_rect_region(pose["texture"], Rect2(pose["offset"] + Vector2(0, -roundf(lift)), pose["size"]), pose["region"])


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(_delta: float) -> void:
	if not is_instance_valid(actor):
		queue_free()
		return
	global_position = actor.global_position
	queue_redraw()


func _draw() -> void:
	# A sombra pertence ao chão; só o corpo recebe altura visual.
	var shadow := PackedVector2Array()
	for step in range(16):
		var angle := step * TAU / 16.0
		shadow.append(Vector2(cos(angle) * 9.0, sin(angle) * 3.0).round())
	draw_colored_polygon(shadow, Color(.01, .025, .03, .25))
	draw_pose(self, state, facing, progress, sin(progress * PI) * 12.0)
