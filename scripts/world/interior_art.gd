extends RefCounted

## Móveis e lojistas das casas, desenhados no Pixelorama (art/pixelorama/interiors_v4)
## e exportados por tools/pixelorama/export_interiors_v4.ps1. Mesmo contrato de
## port_art.gd: sem a folha exportada, `draw` devolve false e quem chama desenha a reserva.

const TEXTURE := "res://assets/world/interiors_v4.png"
const MANIFEST := "res://assets/world/interiors_v4_manifest.json"

## The same native plan defines painting, collision, shadow and depth. No
## separate hand-estimated rectangle can drift away from the visible feet.
static func footprint(name: String) -> PackedVector2Array:
	_ensure()
	var result := PackedVector2Array()
	for point in _sprites.get(name, {}).get("ground_base", []):
		result.append(Vector2(point[0], point[1]))
	return result

static func column_bounds(name: String) -> Vector2i:
	_ensure()
	var bounds: Array = _sprites.get(name, {}).get("painted_columns", [-64, 64])
	return Vector2i(bounds[0], bounds[1])

static var _texture: Texture2D
static var _sprites: Dictionary = {}
static var _cell := Vector2(128, 144)
static var _pivot := Vector2(64, 112)
static var _columns := 8
static var _loaded := false

static func _ensure() -> void:
	if _loaded: return
	_loaded = true
	if not ResourceLoader.exists(TEXTURE) or not FileAccess.file_exists(MANIFEST): return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary: return
	_texture = load(TEXTURE) as Texture2D
	_sprites = data.get("sprites", {})
	_cell = Vector2(data["canvas"][0], data["canvas"][1])
	_pivot = Vector2(data["pivot"][0], data["pivot"][1])
	_columns = int(data["columns"])

static func has(name: String) -> bool:
	_ensure()
	return _texture != null and _sprites.has(name)

## Desenha a peça com o pé no ponto (0, 0) do canvas; `clock` escolhe o quadro
## das peças animadas (lojistas, forno, carvão).
static func draw(canvas: CanvasItem, name: String, clock: float = 0.0) -> bool:
	if not has(name): return false
	var cell := _cell_origin(name, clock)
	canvas.draw_texture_rect_region(_texture, Rect2(-_pivot, _cell), Rect2(cell, _cell))
	return true

## Só as colunas [from, to) da peça, contadas a partir do pé; `origin` é onde o
## canvas está em relação ao pé. Usado pelas fatias de profundidade dos móveis longos.
static func draw_columns(canvas: CanvasItem, name: String, clock: float, from: int, to: int, origin: Vector2) -> bool:
	if not has(name): return false
	var cell := _cell_origin(name, clock)
	var width := float(to - from)
	canvas.draw_texture_rect_region(_texture, Rect2(Vector2(from, -_pivot.y) - origin, Vector2(width, _cell.y)), Rect2(cell + Vector2(_pivot.x + from, 0), Vector2(width, _cell.y)))
	return true

static func _cell_origin(name: String, clock: float) -> Vector2:
	var sprite: Dictionary = _sprites[name]
	var frames: Array = sprite["frames"]
	var sequence: Array = sprite.get("sequence", [0])
	var step := int(clock * float(sprite.get("fps", 1.0))) % sequence.size()
	var index := int(frames[int(sequence[step])])
	return Vector2(index % _columns, index / _columns) * _cell
