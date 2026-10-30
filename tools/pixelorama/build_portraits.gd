extends SceneTree

const SOURCE_PATH := "res://qa/new_npcs_clean.png"
const OUT_DIR := "res://assets/ui/dialogue_v15/"

const Palette = preload("res://tools/pixelorama/build_townsfolk_v1.gd")

var palette: Array[Color] = []
var cached := {}

func _init() -> void:
	for hex in Palette.PAL.values():
		palette.append(Color(hex))

	var src := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	if src == null:
		print("ERROR: could not load clean source")
		quit(1)
		return

	# Bust boxes for each character (Head and chest: width ~240-280, height ~300)
	var busts := [
		{"id": "sacerdote", "rect": Rect2i(90, 58, 250, 300)},
		{"id": "alquimista", "rect": Rect2i(410, 60, 270, 310)},
		{"id": "sentinela", "rect": Rect2i(760, 48, 260, 310)},
		{"id": "mercadora", "rect": Rect2i(1085, 63, 245, 300)}
	]

	for b in busts:
		var piece := src.get_region(b["rect"])
		# Scale to 160x192 preserving aspect ratio, centered
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
