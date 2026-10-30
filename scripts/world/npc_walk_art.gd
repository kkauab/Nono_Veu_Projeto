extends RefCounted
## Walking-only sibling atlas; rest, speech, work and quests keep their v3 art.
const TEXTURE := "res://assets/world/npc_walk_v4.png"
const MANIFEST := "res://assets/world/npc_walk_v4_manifest.json"
const STRIDE := 24.0
const PHASES := 8
static var _texture: Texture2D
static var _data: Dictionary = {}
static var _loaded := false

static func phase_index(distance: float) -> int:
	return int(floor(fposmod(distance, STRIDE) * PHASES / STRIDE)) % PHASES

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not ResourceLoader.exists(TEXTURE) or not FileAccess.file_exists(MANIFEST): return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not parsed is Dictionary: return
	_data = parsed
	_texture = load(TEXTURE) as Texture2D

static func draw(canvas: CanvasItem, look: int, carrying: bool, distance: float) -> bool:
	_ensure()
	if _texture == null or look < 0 or look >= _data.get("looks", []).size(): return false
	var name: String = _data.looks[look]
	var cycle: Array = _data.sprites[name]["carry" if carrying else "walk"]
	if cycle.size() != PHASES: return false
	var index := int(cycle[phase_index(distance)])
	var cell := Vector2(_data.canvas[0], _data.canvas[1])
	var pivot := Vector2(_data.pivot[0], _data.pivot[1])
	var columns := int(_data.columns)
	canvas.draw_texture_rect_region(_texture, Rect2(-pivot, cell), Rect2(Vector2(index % columns, index / columns) * cell, cell))
	return true
