extends RefCounted
## Pixelorama v7: cada pixel de cenário corresponde a um pixel do mundo.

static var _materials: Texture2D
static var _entries: Dictionary = {}
static var _loaded := false
static var _water_material: ShaderMaterial
const CELL := 192
const COLUMNS := 4
const THEMES := ["stone", "sand", "wood", "mosaic", "garden", "crypt", "aqueduct", "arena"]

static func _ensure() -> void:
	if _loaded: return
	var path := "res://assets/world/port_pixel_v7_manifest.json"
	if not ResourceLoader.exists("res://assets/world/port_pixel_v7.png") or not FileAccess.file_exists(path): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary: return
	_materials = load("res://assets/world/port_pixel_v7.png") as Texture2D
	_entries = data.get("props", {})
	_loaded = _materials != null

static func draw_tile(canvas: CanvasItem, center: Vector2, theme: String, tile: Vector2i) -> bool:
	_ensure()
	if _materials == null: return false
	var theme_index := maxi(0, THEMES.find(theme))
	var variant := posmod(tile.x * 73 + tile.y * 193, 4)
	var index := theme_index * 4 + variant
	var region := Rect2(Vector2(index % COLUMNS, index / COLUMNS) * CELL + Vector2(64, 80), Vector2(64, 32))
	canvas.draw_texture_rect_region(_materials, Rect2(center + Vector2(-32, -16), Vector2(64, 32)), region)
	return true

static func _entry(kind: String) -> Dictionary:
	_ensure()
	var name := str({"pillar": "obelisk", "statue": "obelisk", "torch": "brazier", "crate": "cargo", "warehouse": "warehouse", "arch": "arch", "stall": "stall", "palm": "palm", "wall": "wall", "boat": "boat", "stairs": "stairs", "temple": "temple", "lighthouse": "lighthouse"}.get(kind, ""))
	return _entries.get(name, {})

static func prop_extent(kind: String) -> Vector2:
	var entry := _entry(kind)
	if entry.is_empty(): return Vector2.ZERO
	var size: Array = entry["content_size"]
	return Vector2(float(size[0]), float(size[1]))

static func draw_prop(canvas: CanvasItem, kind: String, _variant: int = 0) -> bool:
	var entry := _entry(kind)
	if entry.is_empty() or _materials == null: return false
	var index := int(entry["frame"])
	var region := Rect2((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL)
	canvas.draw_texture_rect_region(_materials, Rect2(-96, -176, CELL, CELL), region)
	if kind == "torch":
		var clock := float(canvas.get("_time"))
		var fire := Vector2(0, -float(entry["content_size"][1]) + 12)
		var flicker := roundf(sin(clock * 11.7) * 2)
		canvas.draw_rect(Rect2(fire + Vector2(-3, -7 + flicker), Vector2(6, 9 - flicker)), Color("e69d4a"))
		canvas.draw_rect(Rect2(fire + Vector2(-1, -5), Vector2(3, 7)), Color("f5cc76"))
	return true

static func draw_water(canvas: CanvasItem, rect: Rect2, _clock: float) -> bool:
	_ensure()
	if _materials == null: return false
	if _water_material == null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = load("res://assets/shaders/harbor_pixel_water.gdshader") as Shader
	canvas.material = _water_material
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), _materials)
	return true
