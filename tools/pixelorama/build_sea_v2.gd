extends SceneTree

## Gera os bichos do mar e as escadas dos paredões (docs/MUNDO_BARCO_ILHA.md):
## art/pixelorama/sea_v2/sea_beasts_v1.pxo (Pixelorama 1.2.3, formato 7), o plano
## de exportação, e a folha do jogo assets/world/sea_beasts_v1.png com o manifesto
## que sea_art.gd lê. Um pixel da fonte é um pixel do mundo.
##
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_sea_v2.gd
## Opcional: -- --preview grava qa/sea_beasts_v1_preview.png ampliado 3×.
##
## Crocodilos do Nilo vistos do alto, quase submersos, em 8 direções (a mesma
## convenção de proa de sea_boat.gd: 0 aponta para a direita da tela). "croc" é o
## comum; "sobek", o maior, escuro e com colar dourado. Cada um tem "swim" (4
## quadros de cauda), "lurk" (2: só olhos, narinas e escamas acima d'água) e
## "bite" (2: mandíbula aberta e fechando). As escadas ficam na face do paredão:
## "x" na face que desce para a esquerda, "y" na que desce para a direita; pedra
## (20 px) e madeira dos píeres (11 px). O pivô é o pé da escada, na água.
## Só a paleta do Porto v7 (a mesma de build_interiors_v1.gd), alfa binário.

const CELL := Vector2i(64, 48)
const PIVOT := Vector2i(32, 32)
const COLUMNS := 8
const OUT_DIR := "res://art/pixelorama/sea_v2"
const PXO := OUT_DIR + "/sea_beasts_v1.pxo"
const PLAN := OUT_DIR + "/export_plan.json"
const SHEET := "res://assets/world/sea_beasts_v1.png"
const MANIFEST := "res://assets/world/sea_beasts_v1_manifest.json"
const PAL := {
	"ink": "14252c", "night": "1e343a", "slate": "2b4449", "sea": "3c5659", "moss": "526765",
	"sage": "6d7b70", "lichen": "8c9380", "bone": "b4b298", "linen": "dbcfaa", "cream": "eee0ba",
	"charcoal": "343b38", "stone_dark": "4b5553", "stone": "646b60", "stone_light": "81816e",
	"sand_dark": "a09a7e", "sand": "bdad89", "umber": "332e28", "wood_dark": "4b3b2d",
	"wood": "674d34", "wood_light": "846443", "tan": "a27d50", "gold_dark": "c39e65",
	"gold": "e0bd7e", "teal_dark": "1f444b", "teal": "2c5b61", "teal_light": "3e7373",
	"jade": "609087", "olive_dark": "5a623e", "olive": "7d8051", "olive_light": "a49e66",
	"rust": "be733a", "flame": "e69d4a", "glow": "f5cc76"
}
## Cores de cada espécie: costas, borda molhada, escamas, ventre do focinho e enfeite.
const SKINS := {
	"croc": {"back": "olive", "edge": "olive_dark", "scute": "olive_light", "wet": "teal_dark", "trim": "", "scale": 1.0},
	"sobek": {"back": "teal", "edge": "teal_dark", "scute": "jade", "wet": "night", "trim": "gold", "scale": 1.32},
}
const LENGTH := 40.0

var _img: Image
var _frames: Array[Image] = []
var _sprites := {}


func _init() -> void:
	for kind in SKINS:
		for direction in range(8):
			var heading := direction * TAU / 8.0
			for phase in range(4):
				_begin()
				_croc(kind, heading, phase / 4.0, "swim", 0.0)
				_outline()
				_end("%s_swim_%d" % [kind, direction])
			_sprites["%s_swim_%d" % [kind, direction]]["fps"] = 6.0
			for phase in range(2):
				_begin()
				_croc(kind, heading, phase / 2.0, "lurk", 0.0)
				_end("%s_lurk_%d" % [kind, direction])
			_sprites["%s_lurk_%d" % [kind, direction]]["fps"] = 2.0
			for jaw in [1.0, .35]:
				_begin()
				_croc(kind, heading, .25, "bite", jaw)
				_outline()
				_end("%s_bite_%d" % [kind, direction])
			_sprites["%s_bite_%d" % [kind, direction]]["fps"] = 6.0
	for face in ["x", "y"]:
		for wall in [["stone", 20], ["wood", 11]]:
			_begin()
			_ladder(face, wall[1])
			_end("ladder_%s_%s" % [face, wall[0]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write_pxo()
	_write_sheet()
	if "--preview" in OS.get_cmdline_user_args():
		_write_preview()
	print("SEA_V2 frames=%d sprites=%d sheet=%s" % [_frames.size(), _sprites.size(), ProjectSettings.globalize_path(SHEET)])
	quit()


# --- Crocodilo -------------------------------------------------------------------

## Meia largura do corpo em cada ponto `u` do eixo (focinho em +, cauda em −).
func _half_width(u: float, scale: float) -> float:
	var t := u / scale
	# Focinho longo e estreito, cabeça larga na base da mandíbula, pescoço curto,
	# barriga larga no meio e cauda que afina até a ponta.
	if t > 12.0: return lerpf(2.4, 1.5, clampf((t - 12.0) / 6.0, 0, 1)) * scale
	if t > 6.0: return lerpf(4.2, 2.4, (t - 6.0) / 6.0) * scale
	if t > 3.5: return 3.3 * scale
	if t > -8.0: return (5.6 - absf(t + 2.0) * .17) * scale
	return lerpf(4.3, .7, clampf((-8.0 - t) / 12.0, 0, 1)) * scale


## As quatro patas curtas, abertas para os lados, quase todas submersas.
func _legs(heading: float, phase: float, scale: float, wet: String, edge: String) -> Array:
	var result := []
	for leg in [[2.0, 1.0], [-6.5, -1.0]]:
		var at: float = leg[0] * scale
		var stroke: float = sin(phase * TAU) * float(leg[1]) * .9 * scale
		for side in [-1.0, 1.0]:
			var w := _half_width(at, scale)
			for step in range(4):
				var reach: float = w + .4 + step * .55 * scale
				var back: float = at - step * .5 * scale + stroke * side
				var spot := _ground(back, side * reach + _sway(at, phase, scale), heading)
				result.append([spot.y - .5, spot + Vector2(0, -.5), edge if step < 3 else wet])
	return result


## Altura acima d'água: o dorso aflora, a cauda e o focinho mal saem.
func _rise(u: float, v: float, w: float, scale: float) -> float:
	var t := u / scale
	var crown := 1.0 - pow(v / maxf(w, .01), 2.0)
	var base := 2.4 if t > -7.0 and t < 4.0 else (1.6 if t >= 4.0 else 1.0)
	return base * crown * scale


func _sway(u: float, phase: float, scale: float) -> float:
	var t := u / scale
	var tail := clampf((-t - 1.0) / 16.0, 0, 1)
	return sin(phase * TAU + t * .32) * (.6 + 3.2 * tail * tail) * scale


func _ground(u: float, v: float, heading: float) -> Vector2:
	return Vector2(u * cos(heading) - v * sin(heading), (u * sin(heading) + v * cos(heading)) * .5)


func _croc(kind: String, heading: float, phase: float, pose: String, jaw: float) -> void:
	var skin: Dictionary = SKINS[kind]
	var scale: float = skin["scale"]
	var half := LENGTH * .5 * scale
	var snout := 19.0 * scale
	var head := 10.0 * scale
	var samples := []
	var u := -half
	while u <= snout:
		var w := _half_width(u, scale)
		var v := -w
		var sway := _sway(u, phase, scale)
		while v <= w:
			var color := ""
			var lift := _rise(u, v, w, scale)
			var edge := absf(v) > w - .9
			if pose == "lurk":
				# Só aflora o que está acima d'água: olhos, narinas e a crista do dorso.
				if absf(v) < .8 and u > -10.0 * scale and u < 3.0 * scale and posmod(roundi(u / scale), 3) == 0:
					color = skin["edge"]
			else:
				color = skin["wet"] if edge else skin["back"]
				if not edge and absf(v) < w * .55 and posmod(roundi(u / (1.6 * scale)), 2) == 0 and u < head:
					color = skin["scute"]
				if absf(v) < .6 and u < head and u > -half + 2.0:
					color = skin["edge"]
			if pose == "bite" and u > head - 1.0:
				# A mandíbula de cima sobe; embaixo aparece a boca clara e os dentes.
				var open := jaw * (u - head + 1.0) * .55
				if not edge:
					samples.append([_ground(u, v + sway, heading).y, _ground(u, v + sway, heading) + Vector2(0, -lift), "sand"])
					if absf(absf(v) - (w - 1.2)) < .5 and posmod(roundi(u * 2.0), 3) == 0:
						samples.append([_ground(u, v + sway, heading).y + .01, _ground(u, v + sway, heading) + Vector2(0, -lift - 1.0), "bone"])
				lift += open
			if color != "":
				var at := _ground(u, v + sway, heading)
				samples.append([at.y + (.02 if pose == "bite" and u > head - 1.0 else 0.0), at + Vector2(0, -lift), color])
			v += .25
		u += .25
	if pose != "lurk":
		samples.append_array(_legs(heading, phase, scale, skin["wet"], skin["edge"]))
	if skin["trim"] != "" and pose != "lurk":
		# Colar sagrado de Sobek, logo atrás da cabeça.
		var collar_u := 4.5 * scale
		var w := _half_width(collar_u, scale)
		var v := -w
		while v <= w:
			var at := _ground(collar_u, v + _sway(collar_u, phase, scale), heading)
			samples.append([at.y + .03, at + Vector2(0, -_rise(collar_u, v, w, scale) - .5), skin["trim"]])
			v += .25
	samples.sort_custom(func(a, b): return a[0] < b[0])
	for sample in samples:
		_pxv(sample[1], sample[2])
	# Olhos dourados com pupila e narinas na ponta do focinho, sempre por cima.
	var eye_u := (head - 1.5)
	for side in [-1.0, 1.0]:
		var w := _half_width(eye_u, scale)
		var eye := _ground(eye_u, side * (w - 1.2) + _sway(eye_u, phase, scale), heading) + Vector2(0, -_rise(eye_u, 0, w, scale) - 1.6 - (jaw * 2.0 if pose == "bite" else 0.0))
		_pxv(eye, "glow")
		_pxv(eye + Vector2(0, 1), "ink")
	var tip := _ground(snout - 1.0, _sway(snout, phase, scale), heading) + Vector2(0, -1.0 - (jaw * (snout - head) * .55 if pose == "bite" else 0.0))
	_pxv(tip + _ground(0, -.8, heading), "ink")
	_pxv(tip + _ground(0, .8, heading), "ink")


# --- Escada do paredão --------------------------------------------------------------

## Face "x": do canto direito do tile (32, 0) ao de baixo (0, 16); face "y": do de
## baixo (0, 16) ao esquerdo (−32, 0). O pé (pivô) é o meio da aresta, `depth` abaixo.
func _ladder(face: String, depth: int) -> void:
	var half := Vector2(16, -8) if face == "x" else Vector2(16, 8)
	var rails: Array[float] = [-.3, .3]
	var top := -depth - 3
	for side in rails:
		var base: Vector2 = half * side
		for h in range(-1, depth + 4):
			_pxv(base + Vector2(0, -h), "wood_dark")
			_pxv(base + Vector2(1, -h), "wood")
		_pxv(base + Vector2(0, top), "tan")
		_pxv(base + Vector2(1, top), "tan")
	var h := 2
	while h <= depth + 1:
		var a: Vector2 = half * rails[0] + Vector2(1, -h)
		var b: Vector2 = half * rails[1] + Vector2(0, -h)
		_line(a, b, "wood_light")
		h += 4
	# Amarras de corda no alto, onde a escada se prende à borda do cais.
	for side in rails:
		_pxv(half * side + Vector2(0, -depth + 1), "linen")
		_pxv(half * side + Vector2(1, -depth + 1), "linen")
	# Limo na parte que molha.
	for side in rails:
		_pxv(half * side + Vector2(0, 0), "jade")
		_pxv(half * side + Vector2(1, 1), "jade")


# --- Pixels -----------------------------------------------------------------------

func _begin() -> void:
	_img = Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)


func _end(name: String) -> void:
	_frames.append(_img)
	if not _sprites.has(name):
		_sprites[name] = {"frames": []}
	_sprites[name]["frames"].append(_frames.size() - 1)


func _px(x: int, y: int, color: String) -> void:
	var point := PIVOT + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < CELL.x and point.y < CELL.y:
		_img.set_pixelv(point, Color(PAL[color]))


func _pxv(point: Vector2, color: String) -> void:
	_px(roundi(point.x), roundi(point.y), color)


func _line(a: Vector2, b: Vector2, color: String) -> void:
	var steps := maxi(1, ceili(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for index in range(steps + 1):
		_pxv(a.lerp(b, float(index) / steps), color)


## Contorno escuro de 1 pixel em volta da silhueta, como nos props do Porto.
func _outline(color: String = "ink") -> void:
	var source := _img.duplicate() as Image
	for y in range(CELL.y):
		for x in range(CELL.x):
			if source.get_pixel(x, y).a > 0:
				continue
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor: Vector2i = Vector2i(x, y) + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < CELL.x and neighbor.y < CELL.y and source.get_pixelv(neighbor).a > 0:
					_img.set_pixel(x, y, Color(PAL[color]))
					break


# --- Arquivos -------------------------------------------------------------------

func _write_pxo() -> void:
	var frames := []
	for index in range(_frames.size()):
		frames.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tags := []
	for name in _sprites:
		var list: Array = _sprites[name]["frames"]
		tags.append({"name": name, "color": "6db0a4ff", "from": int(list[0]) + 1, "to": int(list[list.size() - 1]) + 1})
	var data := {
		"pixelorama_version": "v1.2.3-stable", "pxo_version": 7,
		"size_x": CELL.x, "size_y": CELL.y, "color_mode": 5,
		"layers": [{"name": "Mar", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}],
		"frames": frames, "tags": tags, "fps": 12.0, "current_frame": 0, "current_layer": 0,
		"export_profile": {"orientation": "1", "lines_count": str(COLUMNS), "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}
	}
	var zip := ZIPPacker.new()
	var error := zip.open(ProjectSettings.globalize_path(PXO))
	assert(error == OK, "não foi possível criar " + PXO)
	_zip_file(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip_file(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for index in range(_frames.size()):
		_zip_file(zip, "image_data/frames/%d/layer_1" % (index + 1), _frames[index].get_data())
	_zip_file(zip, "preview.png", _frames[0].save_png_to_buffer())
	zip.close()


func _zip_file(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()


## A folha do jogo e o manifesto (mesmo formato de boat_v4) saem dos mesmos quadros
## do .pxo, então o que o Pixelorama mostra é o que o jogo desenha.
func _write_sheet() -> void:
	var rows := ceili(_frames.size() / float(COLUMNS))
	var sheet := Image.create_empty(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	for index in range(_frames.size()):
		sheet.blit_rect(_frames[index], Rect2i(Vector2i.ZERO, CELL), Vector2i((index % COLUMNS) * CELL.x, (index / COLUMNS) * CELL.y))
	sheet.save_png(SHEET)
	var manifest := {
		"version": 1, "pixel_art": true, "game_scale": 1.0,
		"canvas": [CELL.x, CELL.y], "pivot": [PIVOT.x, PIVOT.y], "columns": COLUMNS, "frames": _frames.size(),
		"source": "res://art/pixelorama/sea_v2/sea_beasts_v1.pxo", "texture": SHEET, "sprites": _sprites
	}
	for path in [MANIFEST, PLAN]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()


func _write_preview() -> void:
	var rows := ceili(_frames.size() / float(COLUMNS))
	var sheet := Image.create_empty(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2c5b61"))
	for index in range(_frames.size()):
		sheet.blend_rect(_frames[index], Rect2i(Vector2i.ZERO, CELL), Vector2i((index % COLUMNS) * CELL.x, (index / COLUMNS) * CELL.y))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	sheet.save_png("res://qa/sea_beasts_v1_preview.png")
