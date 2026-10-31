extends RefCounted
## Pixelorama v7: cada pixel de cenário corresponde a um pixel do mundo.

static var _materials: Texture2D
static var _entries: Dictionary = {}
static var _loaded := false
static var _water_material: ShaderMaterial
static var _ground_lines: Dictionary = {}
static var _art_bottoms: Dictionary = {}
static var _footprints: Dictionary = {}
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

## A run of columns of a prop frame, at the same pivot as draw_prop. `from` and
## `to` count from the center of the cell.
static func draw_prop_columns(canvas: CanvasItem, kind: String, from: int, to: int) -> bool:
	var entry := _entry(kind)
	if entry.is_empty() or _materials == null: return false
	var index := int(entry["frame"])
	var cell := Vector2((index % COLUMNS) * CELL, (index / COLUMNS) * CELL)
	canvas.draw_texture_rect_region(_materials, Rect2(from, -176, to - from, CELL), Rect2(cell + Vector2(from + 96, 0), Vector2(to - from, CELL)))
	return true

## Where each column of a prop frame meets the floor nearest the camera, indexed
## from the left edge of the cell (NAN where the column is empty). Overhangs such
## as lintels, awnings and banners take the line between the columns that do
## touch the floor, so an actor under an arch keeps its place.
static func ground_line(kind: String) -> PackedFloat32Array:
	return _measured(kind, _ground_lines)

## Lowest painted pixel of each column of a prop frame, same indexing.
static func art_bottom(kind: String) -> PackedFloat32Array:
	return _measured(kind, _art_bottoms)

## Ground-plane silhouette of a prop frame, in the same space as draw_prop. The
## pivot is the front corner of the base, so the base lies behind it. Built from
## the floor-touching columns around the lowest pixel (a palm's trunk, not its
## leaves) and closed by the hidden back corner: left + right - front.
static func footprint(kind: String) -> PackedVector2Array:
	var bottom := art_bottom(kind)
	if bottom.is_empty(): return PackedVector2Array()
	var frame := int(_entry(kind)["frame"])
	# Packed arrays are shared: callers scale their own copy, never the cached one.
	if _footprints.has(frame): return _footprints[frame].duplicate()
	var lowest := -1
	for x in range(CELL):
		if _touches_floor(bottom, x) and (lowest < 0 or bottom[x] > bottom[lowest]): lowest = x
	var first := lowest
	var last := lowest
	while first > 0 and _touches_floor(bottom, first - 1): first -= 1
	while last < CELL - 1 and _touches_floor(bottom, last + 1): last += 1
	var contour := PackedVector2Array()
	var front := Vector2(0, -INF)
	for x in range(first, last + 1):
		# Bottom edge of the lowest pixel of each column.
		var point := Vector2(x - 95.5, bottom[x] + 1)
		contour.append(point)
		if point.y > front.y: front = point
	contour.append(contour[0] + contour[contour.size() - 1] - front)
	var hull := Geometry2D.convex_hull(contour)
	hull.remove_at(hull.size() - 1)
	_footprints[frame] = hull
	return hull.duplicate()

static func _touches_floor(bottom: PackedFloat32Array, x: int) -> bool:
	# Isometric bases rise half a pixel per pixel away from the pivot.
	return not is_nan(bottom[x]) and bottom[x] >= -absf(x - 96) * .5 - 18

static func _measured(kind: String, table: Dictionary) -> PackedFloat32Array:
	_ensure()
	var entry := _entry(kind)
	if entry.is_empty() or _materials == null: return PackedFloat32Array()
	if _ground_lines.is_empty():
		var image := _materials.get_image()
		if image.is_compressed(): image.decompress()
		for name in _entries:
			var frame := int(_entries[name]["frame"])
			_art_bottoms[frame] = _measure_bottom(image, Vector2i((frame % COLUMNS) * CELL, (frame / COLUMNS) * CELL))
			_ground_lines[frame] = _ground_from(_art_bottoms[frame])
	return table.get(int(entry["frame"]), PackedFloat32Array())

static func _measure_bottom(image: Image, cell: Vector2i) -> PackedFloat32Array:
	var bottom := PackedFloat32Array()
	bottom.resize(CELL)
	for x in range(CELL):
		bottom[x] = NAN
		for y in range(CELL - 1, -1, -1):
			if image.get_pixel(cell.x + x, cell.y + y).a > .5:
				bottom[x] = y - 176
				break
	return bottom

static func _ground_from(bottom: PackedFloat32Array) -> PackedFloat32Array:
	var grounded: Array[int] = []
	for x in range(CELL):
		if _touches_floor(bottom, x): grounded.append(x)
	var line := bottom.duplicate()
	for x in range(CELL):
		if is_nan(bottom[x]) or grounded.has(x): continue
		var left := -1
		var right := -1
		for column in grounded:
			if column < x: left = column
			elif right < 0: right = column
		if left >= 0 and right >= 0:
			line[x] = lerpf(bottom[left], bottom[right], float(x - left) / (right - left))
		elif left >= 0 or right >= 0:
			line[x] = bottom[maxi(left, right)]
	return line

## O material da água, compartilhado; sea_depth.gd liga nele o mapa de profundidade.
static func water_material() -> ShaderMaterial:
	if _water_material == null:
		_water_material = ShaderMaterial.new()
		_water_material.shader = load("res://assets/shaders/harbor_pixel_water.gdshader") as Shader
	return _water_material

static func draw_water(canvas: CanvasItem, rect: Rect2, _clock: float) -> bool:
	_ensure()
	if _materials == null: return false
	canvas.material = water_material()
	canvas.draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([Color.WHITE]), PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]), _materials)
	return true
