extends SceneTree

# Casas, fase 4: a arte dos interiores e dos lojistas no Pixelorama.
# Confere o projeto nativo (formato 7), a folha exportada pelo Pixelorama, a
# paleta do Porto e que todo móvel das casas tem arte. Roda sem o mundo.
const Catalog = preload("res://scripts/world/house_catalog.gd")
const InteriorArt = preload("res://scripts/world/interior_art.gd")
const PXO := "res://art/pixelorama/interiors_v4/interiors_v4.pxo"
const PLAN := "res://art/pixelorama/interiors_v4/export_plan.json"
const MANIFEST := "res://assets/world/interiors_v4_manifest.json"
const SHEET := "res://assets/world/interiors_v4.png"
## Peças que usam a arte do Porto (port_art.gd), não a dos interiores.
const PORT_ART := ["brazier", "crate"]
const PALETTE := ["14252c", "1e343a", "2b4449", "3c5659", "526765", "6d7b70", "8c9380", "b4b298", "dbcfaa", "eee0ba",
	"343b38", "4b5553", "646b60", "81816e", "a09a7e", "bdad89", "332e28", "4b3b2d", "674d34", "846443", "a27d50",
	"c39e65", "e0bd7e", "1f444b", "2c5b61", "3e7373", "609087", "5a623e", "7d8051", "a49e66", "be733a", "e69d4a", "f5cc76"]

var checks := 0
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_check(plan == manifest, "the game manifest is the art plan")
	var cell := Vector2i(int(plan["canvas"][0]), int(plan["canvas"][1]))
	var columns := int(plan["columns"])
	var count := int(plan["frames"])
	var zip := ZIPReader.new()
	_check(zip.open(ProjectSettings.globalize_path(PXO)) == OK, "the native project opens as a ZIP")
	_check(zip.read_file("mimetype").get_string_from_utf8() == "application/x-pixelorama", "the project declares Pixelorama")
	var data: Dictionary = JSON.parse_string(zip.read_file("data.json").get_string_from_utf8())
	_check(int(data["pxo_version"]) == 7 and data["pixelorama_version"] == "v1.2.3-stable" and int(data["color_mode"]) == 5, "format 7, Pixelorama 1.2.3, RGBA")
	_check(int(data["size_x"]) == cell.x and int(data["size_y"]) == cell.y and data["frames"].size() == count, "canvas and frame count match the plan")
	var tags := {}
	for tag in data["tags"]:
		tags[tag["name"]] = [int(tag["from"]), int(tag["to"])]
	var tags_ok := true
	for name in plan["sprites"]:
		var frames: Array = plan["sprites"][name]["frames"]
		if not tags.has(name) or tags[name] != [int(frames[0]) + 1, int(frames[frames.size() - 1]) + 1]: tags_ok = false
	_check(tags_ok and tags.size() == plan["sprites"].size(), "one Pixelorama tag per piece, over its own frames")
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	var rows := ceili(count / float(columns))
	_check(sheet != null and sheet.get_size() == Vector2i(cell.x * columns, cell.y * rows), "the exported sheet has %d columns of %s cells" % [columns, cell])
	sheet.convert(Image.FORMAT_RGBA8)
	var same := true
	var sizes_ok := true
	for index in range(count):
		var bytes := zip.read_file("image_data/frames/%d/layer_1" % (index + 1))
		if bytes.size() != cell.x * cell.y * 4:
			sizes_ok = false
			continue
		var frame := Image.create_from_data(cell.x, cell.y, false, Image.FORMAT_RGBA8, bytes)
		var region := sheet.get_region(Rect2i(Vector2i(index % columns, index / columns) * cell, cell))
		if region.get_data() != frame.get_data(): same = false
	zip.close()
	_check(sizes_ok, "every cel holds width × height × 4 bytes")
	_check(same, "the sheet exported by Pixelorama matches the native project pixel by pixel")
	var colors := {}
	for color in PALETTE: colors[color] = true
	var palette_ok := true
	var alpha_ok := true
	for y in range(sheet.get_height()):
		for x in range(sheet.get_width()):
			var pixel := sheet.get_pixel(x, y)
			if pixel.a8 == 0: continue
			if pixel.a8 != 255: alpha_ok = false
			if not colors.has(pixel.to_html(false)): palette_ok = false
	_check(alpha_ok, "binary alpha, like the Port art")
	_check(palette_ok, "only the 33 colors of the Port v7 palette")
	var missing := []
	for id in Catalog.HOUSES:
		for piece in Catalog.HOUSES[id]["furniture"]:
			var kind: String = piece[0]
			var name := "shelf_a" if kind == "shelf" else kind
			if kind not in PORT_ART and not InteriorArt.has(name) and not missing.has(kind): missing.append(kind)
	for name in ["chest_closed", "chest_open", "shelf_b"]:
		if not InteriorArt.has(name): missing.append(name)
	_check(missing.is_empty(), "every piece of furniture in the houses has art: missing %s" % [missing])
	var animated := true
	for name in ["merit", "nakht", "adiam", "furnace", "coal"]:
		var sprite: Dictionary = plan["sprites"][name]
		if sprite["frames"].size() < 2 or not sprite.has("sequence"): animated = false
	_check(animated, "shopkeepers, furnace and coal are animated")
	for npc in ["hori", "sabu", "merit", "nakht", "adiam", "tarek"]:
		var poses: Array = plan["sprites"][npc]["frames"]
		var hashes := {}
		var anchored := true
		for pose in poses:
			var region := sheet.get_region(Rect2i(Vector2i(int(pose) % columns, int(pose) / columns) * cell, cell))
			hashes[region.get_data().hex_encode().sha256_text()] = true
			var used := region.get_used_rect()
			if used.size.y > 44 or used.end.y != 113: anchored = false
		_check(poses.size() == 4 and hashes.size() == 4 and anchored, npc + " has four distinct authored poses, fixed feet and world scale")
	print("INTERIORS ART RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)
