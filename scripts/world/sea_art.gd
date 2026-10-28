extends RefCounted

## Folhas do Pixelorama do mar (art/pixelorama/sea_v1), exportadas por
## tools/pixelorama/export_sea_v1.ps1: "boat_v1" (o barco em 16 direções) e
## "isle_v1" (as peças da ilha). Mesmo contrato de interior_art.gd: sem a folha
## exportada, `draw` devolve false e quem chama desenha a reserva.

static var _sheets: Dictionary = {}

static func _sheet(sheet: String) -> Dictionary:
	if _sheets.has(sheet):
		return _sheets[sheet]
	var entry := {}
	_sheets[sheet] = entry
	var texture := "res://assets/world/%s.png" % sheet
	var manifest := "res://assets/world/%s_manifest.json" % sheet
	if not ResourceLoader.exists(texture) or not FileAccess.file_exists(manifest):
		return entry
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(manifest))
	if not data is Dictionary:
		return entry
	entry["texture"] = load(texture) as Texture2D
	entry["sprites"] = data.get("sprites", {})
	entry["cell"] = Vector2(data["canvas"][0], data["canvas"][1])
	entry["pivot"] = Vector2(data["pivot"][0], data["pivot"][1])
	entry["columns"] = int(data["columns"])
	return entry

static func has(sheet: String, name: String) -> bool:
	var entry := _sheet(sheet)
	return entry.get("texture") != null and (entry["sprites"] as Dictionary).has(name)

static func frame_count(sheet: String, name: String) -> int:
	return (_sheet(sheet)["sprites"][name]["frames"] as Array).size() if has(sheet, name) else 0

## O quadro `frame` da peça, com o pé no ponto `at` do canvas.
static func draw_frame(canvas: CanvasItem, sheet: String, name: String, frame: int, at: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> bool:
	if not has(sheet, name):
		return false
	var entry := _sheet(sheet)
	var frames: Array = entry["sprites"][name]["frames"]
	var index := int(frames[clampi(frame, 0, frames.size() - 1)])
	var cell: Vector2 = entry["cell"]
	var columns: int = entry["columns"]
	canvas.draw_texture_rect_region(entry["texture"], Rect2(at - (entry["pivot"] as Vector2), cell), Rect2(Vector2(index % columns, index / columns) * cell, cell), tint)
	return true

## O quadro que o relógio escolhe, pela "sequence" e pelo "fps" do manifesto.
static func draw(canvas: CanvasItem, sheet: String, name: String, clock: float = 0.0, at: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> bool:
	if not has(sheet, name):
		return false
	var sprite: Dictionary = _sheet(sheet)["sprites"][name]
	var sequence: Array = sprite.get("sequence", range((sprite["frames"] as Array).size()))
	var step := int(clock * float(sprite.get("fps", 1.0))) % sequence.size()
	return draw_frame(canvas, sheet, name, int(sequence[step]), at, tint)
