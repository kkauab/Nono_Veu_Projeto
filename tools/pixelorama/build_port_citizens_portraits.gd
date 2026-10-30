extends SceneTree

const SOURCE_PATH := "res://qa/port_citizens_clean.png"
const OUT_DIR := "res://assets/ui/dialogue_v15/"
const Palette = preload("res://tools/pixelorama/build_townsfolk_v1.gd")

var palette: Array[Color] = []
var cached := {}

func _init() -> void:
	for hex in Palette.PAL.values():
		palette.append(Color(hex))

	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if src == null:
		print("ERROR loading source")
		quit(1)
		return

	var busts := [
		{"id": "estivador", "rect": Rect2i(40, 34, 220, 280)},
		{"id": "carregador", "rect": Rect2i(265, 106, 210, 270)},
		{"id": "marinheiro", "rect": Rect2i(495, 103, 190, 260)},
		{"id": "velho", "rect": Rect2i(690, 123, 240, 280)},
		{"id": "aguadeira", "rect": Rect2i(940, 132, 205, 270)},
		{"id": "remador", "rect": Rect2i(1150, 112, 200, 260)}
	]

	for b in busts:
		var piece := src.get_region(b["rect"])
		var target_w := 160
		var target_h := 192
		var scale_factor := minf(float(target_w) / float(piece.get_width()), float(target_h) / float(piece.get_height()))
		var nw := roundi(piece.get_width() * scale_factor)
		var nh := roundi(piece.get_height() * scale_factor)

		var scaled := piece.duplicate() as Image
		scaled.resize(nw, nh, Image.INTERPOLATE_LANCZOS)

		var cel := Image.create_empty(target_w, target_h, false, Image.FORMAT_RGBA8)
		var dest_x := (target_w - nw) / 2
		var dest_y := target_h - nh

		for y in range(nh):
			for x in range(nw):
				var c := scaled.get_pixel(x, y)
				if c.a > 0.4:
					c.a = 1.0
					cel.set_pixel(dest_x + x, dest_y + y, _color(c))

		var out_p: String = OUT_DIR + str(b["id"]) + ".png"
		cel.save_png(ProjectSettings.globalize_path(out_p))
		print("Saved portrait: ", out_p)

	quit(0)

func _color(c: Color) -> Color:
	var key := c.to_rgba32()
	if cached.has(key): return cached[key]
	var distance := INF
	var chosen := palette[0]
	for candidate in palette:
		var d := pow(c.r - candidate.r, 2) + pow(c.g - candidate.g, 2) + pow(c.b - candidate.b, 2)
		if d < distance:
			distance = d
			chosen = candidate
	cached[key] = chosen
	return chosen
