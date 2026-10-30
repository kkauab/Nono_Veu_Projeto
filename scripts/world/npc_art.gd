extends RefCounted
## Ankhet's reimagined complete rest poses, with the same foot pivot as sea_v1.
const TEXTURE := "res://assets/world/ankhet_v3.png"
const MANIFEST := "res://assets/world/ankhet_v3_manifest.json"
static var _texture: Texture2D
static var _data: Dictionary = {}

static func draw(canvas: CanvasItem, name: String, clock: float) -> bool:
	if _texture == null:
		if not ResourceLoader.exists(TEXTURE) or not FileAccess.file_exists(MANIFEST): return false
		_texture = load(TEXTURE) as Texture2D
		_data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not _data.get("sprites", {}).has(name): return false
	var sprite: Dictionary = _data["sprites"][name]
	var sequence: Array = sprite["sequence"]
	var index := int(sprite["frames"][sequence[posmod(int(clock * float(sprite["fps"])), sequence.size())]])
	var cell := Vector2(_data["canvas"][0], _data["canvas"][1])
	var pivot := Vector2(_data["pivot"][0], _data["pivot"][1])
	var columns := int(_data["columns"])
	canvas.draw_texture_rect_region(_texture, Rect2(-pivot, cell), Rect2(Vector2(index % columns, index / columns) * cell, cell))
	return true
