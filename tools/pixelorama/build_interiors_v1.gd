extends SceneTree

## Gera o projeto nativo do Pixelorama 1.2.3 (formato 7) com os móveis e os
## lojistas das casas: art/pixelorama/interiors_v1/interiors_v1.pxo, mais o
## manifesto export_plan.json. O PNG do jogo é exportado pelo próprio Pixelorama
## (tools/pixelorama/export_interiors_v1.ps1). Um pixel da fonte é um pixel do mundo.
##
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_interiors_v1.gd
## Opcional: -- --preview grava qa/interiors_v1_preview.png ampliado 3×.
##
## Só a paleta do Porto v7 (build_port_pixel_v7.py), alfa binário, contorno escuro.
## As caixas isométricas usam as mesmas medidas de house_interior.gd (BOXES).

const CELL := Vector2i(128, 144)
const PIVOT := Vector2i(64, 112)
const COLUMNS := 8
const OUT_DIR := "res://art/pixelorama/interiors_v1"
const PXO := OUT_DIR + "/interiors_v1.pxo"
const PLAN := OUT_DIR + "/export_plan.json"
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

var _img: Image
var _frames: Array[Image] = []
var _sprites := {}


func _init() -> void:
	_build_all()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_write_pxo()
	_write_plan()
	if "--preview" in OS.get_cmdline_user_args():
		_write_preview()
	print("INTERIORS_V1 frames=%d sprites=%d pxo=%s" % [_frames.size(), _sprites.size(), ProjectSettings.globalize_path(PXO)])
	quit()


# --- Peças --------------------------------------------------------------------

func _build_all() -> void:
	# Lojistas: parado, inspirando, piscando.
	for keeper in ["merit", "nakht", "adiam"]:
		for pose in [[0, false], [-1, false], [0, true]]:
			_begin()
			call("_" + keeper, pose[0], pose[1])
			_outline()
			_end(keeper)
		_sprites[keeper]["fps"] = 4.0
		_sprites[keeper]["sequence"] = [0, 0, 1, 1, 0, 0, 1, 1, 0, 2]
	for flame in range(3):
		_begin()
		_furnace(flame)
		_outline()
		_end("furnace")
	_sprites["furnace"]["fps"] = 8.0
	_sprites["furnace"]["sequence"] = [0, 1, 2, 1]
	for ember in range(2):
		_begin()
		_coal(ember)
		_outline()
		_end("coal")
	_sprites["coal"]["fps"] = 3.0
	_sprites["coal"]["sequence"] = [0, 1]
	for piece in ["counter", "shelf_a", "shelf_b", "rack", "cords", "trade_chest", "anvil", "tub", "easel", "saddle", "amphora", "bed", "table", "barrel", "chest_closed", "chest_open"]:
		_begin()
		call("_" + piece)
		_outline()
		_end(piece)


func _merit(lift: int, blink: bool) -> void:
	# Túnica verde-petróleo, colar largo dourado, peruca preta presa por uma faixa.
	_poly([_v(-8, 0), _v(8, 0), _v(6, -25 + lift), _v(-6, -25 + lift)], "teal")
	_poly([_v(3, 0), _v(8, 0), _v(6, -25 + lift), _v(3, -25 + lift)], "teal_dark")
	_line(_v(-6, -24 + lift), _v(-8, -1), "teal_light")
	_rect(-7, -17 + lift, 14, 1, "gold_dark")
	_rect(-1, -16 + lift, 2, 2, "gold")
	_rect(-8, -24 + lift, 2, 11, "tan")
	_rect(6, -24 + lift, 2, 11, "wood_light")
	_poly([_v(-7, -37 + lift), _v(6, -37 + lift), _v(7, -26 + lift), _v(-8, -26 + lift)], "ink")
	_rect(-5, -26 + lift, 10, 2, "gold")
	_rect(-4, -24 + lift, 8, 1, "teal_light")
	_rect(-3, -23 + lift, 6, 1, "gold_dark")
	_rect(-1, -28 + lift, 3, 2, "tan")
	_rect(-3, -35 + lift, 6, 7, "tan")
	_rect(2, -35 + lift, 1, 7, "wood_light")
	_rect(-6, -36 + lift, 12, 1, "gold")
	_eyes(-2, 1, -32 + lift, blink, "wood_light")
	_px(-3, -32 + lift, "ink")
	_px(0, -29 + lift, "wood_light")
	_px(-5, -30 + lift, "gold")


func _nakht(lift: int, blink: bool) -> void:
	# Túnica de linho cru, avental de couro, braços fortes, martelo erguido.
	_poly([_v(-9, 0), _v(9, 0), _v(8, -25 + lift), _v(-8, -25 + lift)], "wood_light")
	_poly([_v(4, 0), _v(9, 0), _v(8, -25 + lift), _v(4, -25 + lift)], "wood")
	_poly([_v(-6, 0), _v(6, 0), _v(5, -19 + lift), _v(-5, -19 + lift)], "wood_dark")
	_rect(-5, -19 + lift, 10, 1, "umber")
	_line(_v(-5, -19 + lift), _v(-3, -26 + lift), "umber")
	_line(_v(5, -19 + lift), _v(3, -26 + lift), "umber")
	_px(-4, -16 + lift, "gold_dark")
	_px(3, -16 + lift, "gold_dark")
	_rect(-11, -24 + lift, 3, 12, "wood")
	_rect(-11, -24 + lift, 1, 12, "wood_light")
	_rect(8, -24 + lift, 3, 9, "wood_dark")
	_rect(9, -16 + lift, 3, 3, "wood")
	_line(_v(10, -16 + lift), _v(12, -27 + lift), "umber")
	_rect(9, -31 + lift, 7, 4, "stone_dark")
	_rect(9, -31 + lift, 7, 1, "stone_light")
	_rect(-2, -28 + lift, 4, 3, "wood")
	_rect(-4, -36 + lift, 8, 8, "wood")
	_rect(-3, -37 + lift, 6, 1, "wood")
	_rect(-3, -36 + lift, 3, 1, "wood_light")
	_rect(3, -36 + lift, 1, 8, "wood_dark")
	_px(-5, -33 + lift, "wood")
	_rect(-3, -34 + lift, 2, 1, "umber")
	_rect(1, -34 + lift, 2, 1, "umber")
	_eyes(-2, 1, -33 + lift, blink, "wood_dark")
	_rect(-3, -30 + lift, 6, 2, "ink")
	_rect(-2, -28 + lift, 4, 1, "ink")


func _adiam(lift: int, blink: bool) -> void:
	# Algodão branco com barra tecida (tibeb) e um xale sobre a cabeça.
	_poly([_v(-9, 0), _v(9, 0), _v(7, -24 + lift), _v(-7, -24 + lift)], "cream")
	_poly([_v(3, 0), _v(9, 0), _v(7, -24 + lift), _v(3, -24 + lift)], "linen")
	_rect(-9, -4, 18, 1, "gold_dark")
	for x in range(-9, 9):
		_px(x, -2, "teal" if posmod(x, 2) == 0 else "gold")
		_px(x, -3, "gold" if posmod(x, 2) == 0 else "teal")
	for y in range(-22 + lift, -4):
		_px(-1, y, "teal" if posmod(y, 3) == 0 else "gold")
		_px(0, y, "gold_dark")
	_rect(-9, -21 + lift, 2, 9, "wood")
	_rect(7, -21 + lift, 2, 9, "wood_dark")
	_poly([_v(-7, -38 + lift), _v(7, -38 + lift), _v(10, -21 + lift), _v(-10, -21 + lift)], "cream")
	_poly([_v(4, -38 + lift), _v(7, -38 + lift), _v(10, -21 + lift), _v(5, -21 + lift)], "linen")
	_line(_v(-7, -38 + lift), _v(-10, -21 + lift), "gold_dark")
	_line(_v(7, -38 + lift), _v(10, -21 + lift), "gold_dark")
	_rect(-1, -27 + lift, 3, 2, "wood_light")
	_rect(-3, -34 + lift, 6, 7, "wood_light")
	_rect(2, -34 + lift, 1, 7, "wood")
	_rect(-4, -35 + lift, 8, 1, "teal_light")
	_eyes(-2, 1, -31 + lift, blink, "wood")
	_px(0, -28 + lift, "wood")


func _furnace(flame: int) -> void:
	var lid := _box(2.0, .9, 46, "stone", "stone_dark", "charcoal")
	var d := _iso(-1.0, .45)
	var c := _iso(1.0, .45)
	var b := _iso(1.0, -.45)
	for row in range(1, 6):
		_line(_face(d, c, 0, row * 8), _face(d, c, 1, row * 8), "charcoal")
		_line(_face(c, b, 0, row * 8), _face(c, b, 1, row * 8), "umber")
		for joint in range(3):
			var t := .17 + joint * .33 + (.16 if row % 2 == 0 else 0.0)
			if t < 1.0:
				_line(_face(d, c, t, row * 8 - 7), _face(d, c, t, row * 8 - 1), "charcoal")
	# Boca em arco com fogo que respira.
	_poly([_face(d, c, .3, 3), _face(d, c, .7, 3), _face(d, c, .7, 17), _face(d, c, .6, 22), _face(d, c, .4, 22), _face(d, c, .3, 17)], "ink")
	var rise: int = [0, 2, 1][flame]
	_poly([_face(d, c, .35, 4), _face(d, c, .65, 4), _face(d, c, .65, 11 + rise), _face(d, c, .5, 16 + rise), _face(d, c, .35, 11 + rise)], "rust")
	_poly([_face(d, c, .4, 4), _face(d, c, .6, 4), _face(d, c, .58, 9 + rise), _face(d, c, .47 + flame * .02, 13 + rise), _face(d, c, .42, 9)], "flame")
	_line(_face(d, c, .42, 5), _face(d, c, .58, 5), "glow")
	_line(_face(d, c, .3, 23), _face(d, c, .7, 23), "stone_light")
	# Chaminé.
	var top := (lid[0] + lid[2]) * .5
	_rectv(top + Vector2(-5, -28), 10, 28, "stone_dark")
	_rectv(top + Vector2(-5, -28), 3, 28, "stone")
	_rectv(top + Vector2(-6, -30), 12, 2, "stone_light")
	_line(lid[3], lid[2], "stone_light")


func _coal(ember: int) -> void:
	_poly([_v(-13, 0), _v(13, 0), _v(9, -5), _v(2, -8), _v(-6, -6)], "charcoal")
	for spot in [_v(-8, -2), _v(-2, -5), _v(5, -4), _v(9, -1)]:
		_pxv(spot, "stone_dark")
	var embers: Array = [[_v(-4, -3), _v(3, -5), _v(7, -1)], [_v(-6, -2), _v(1, -6), _v(5, -3)]][ember]
	for spot in embers:
		_pxv(spot, "flame")
		_pxv(spot + Vector2(1, 0), "rust")


func _counter() -> void:
	var lid := _box(2.4, .6, 14, "wood_light", "wood", "wood_dark")
	var d := _iso(-1.2, .3)
	var c := _iso(1.2, .3)
	for t in [.2, .4, .6, .8]:
		_line(_face(d, c, t, 1), _face(d, c, t, 12), "wood_dark")
	_line(_face(d, c, 0, 11), _face(d, c, 1, 11), "gold_dark")
	_line(lid[3], lid[2], "tan")
	var center := (lid[0] + lid[2]) * .5
	# Balança de pratos e três frascos.
	_line(center + Vector2(-14, -1), center + Vector2(-14, -10), "gold_dark")
	_line(center + Vector2(-19, -10), center + Vector2(-9, -10), "gold")
	_rectv(center + Vector2(-21, -9), 4, 1, "gold")
	_rectv(center + Vector2(-11, -9), 4, 1, "gold")
	for jar in [[Vector2(4, -5), "teal_light"], [Vector2(10, -3), "rust"], [Vector2(15, -6), "linen"]]:
		_rectv(center + jar[0], 3, 4, jar[1])
		_pxv(center + jar[0] + Vector2(1, -1), "umber")


func _shelf_a() -> void:
	_shelf(false)


func _shelf_b() -> void:
	_shelf(true)


func _shelf(scrolls: bool) -> void:
	_box(1.5, .3, 40, "wood_light", "wood", "wood_dark")
	var d := _iso(-.75, .15)
	var c := _iso(.75, .15)
	var colors := ["teal_light", "rust", "linen", "olive", "jade", "tan"]
	for board in range(3):
		var height := 6 + board * 12
		_line(_face(d, c, 0, height), _face(d, c, 1, height), "wood_light")
		_line(_face(d, c, 0, height - 1), _face(d, c, 1, height - 1), "wood_dark")
		for slot in range(4):
			var spot := _face(d, c, .14 + slot * .22, height)
			if scrolls and (slot + board) % 2 == 0:
				_rectv(spot + Vector2(-2, -3), 5, 3, "linen")
				_pxv(spot + Vector2(2, -2), "sand_dark")
			else:
				var tint: String = colors[(slot * 2 + board + (1 if scrolls else 0)) % colors.size()]
				_rectv(spot + Vector2(-1, -6), 3, 5, tint)
				_pxv(spot + Vector2(0, -7), "umber")
				_pxv(spot + Vector2(-1, -5), "bone")


func _rack() -> void:
	_box(1.4, .25, 34, "wood_light", "wood", "wood_dark")
	var d := _iso(-.7, .125)
	var c := _iso(.7, .125)
	for blade in range(4):
		var foot := _face(d, c, .18 + blade * .21, 6)
		_line(foot, foot + Vector2(0, -22), "stone_light")
		_pxv(foot + Vector2(0, -22), "bone")
		_line(foot + Vector2(-2, -4), foot + Vector2(2, -4), "gold_dark")
		if blade == 1:
			# Um khopesh: a lâmina curva para a frente no alto.
			_line(foot + Vector2(0, -22), foot + Vector2(3, -25), "stone_light")
			_pxv(foot + Vector2(3, -24), "bone")


func _cords() -> void:
	_box(1.4, .25, 38, "tan", "wood_light", "wood")
	var d := _iso(-.7, .125)
	var c := _iso(.7, .125)
	var colors := ["gold", "rust", "cream", "teal_light", "olive_light"]
	for cord in range(5):
		var top := _face(d, c, .12 + cord * .19, 35)
		var length := 24 - (cord % 2) * 6
		_line(top, top + Vector2(0, length), colors[cord])
		for knot in range(1 + cord % 3):
			_rectv(top + Vector2(-1, 5 + knot * 7), 3, 2, colors[cord])
			_pxv(top + Vector2(-1, 5 + knot * 7), "umber")


func _trade_chest() -> void:
	var lid := _box(1.6, .55, 12, "wood_light", "wood", "wood_dark")
	var d := _iso(-.8, .275)
	var c := _iso(.8, .275)
	for t in [.15, .85]:
		_line(_face(d, c, t, 1), _face(d, c, t, 11), "gold_dark")
	_rectv(_face(d, c, .5, 7), 2, 3, "gold")
	var center := (lid[0] + lid[2]) * .5
	_rectv(center + Vector2(-14, -4), 12, 3, "cream")
	_line(center + Vector2(-14, -3), center + Vector2(-3, -3), "rust")
	_rectv(center + Vector2(6, -5), 4, 4, "tan")
	_pxv(center + Vector2(7, -6), "umber")


func _anvil() -> void:
	_poly([_v(-7, 0), _v(7, 0), _v(6, -7), _v(-6, -7)], "wood")
	_poly([_v(2, 0), _v(7, 0), _v(6, -7), _v(2, -7)], "wood_dark")
	_rect(-3, -11, 6, 4, "charcoal")
	_poly([_v(-11, -11), _v(9, -11), _v(15, -14), _v(9, -16), _v(-11, -16)], "stone_dark")
	_line(_v(-11, -16), _v(9, -16), "stone_light")
	_px(14, -14, "lichen")


func _tub() -> void:
	_poly([_v(-11, -1), _v(0, 4), _v(11, -1), _v(11, -10), _v(0, -5), _v(-11, -10)], "wood")
	_poly([_v(0, 4), _v(11, -1), _v(11, -10), _v(0, -5)], "wood_dark")
	for height in [3, 8]:
		_line(_v(-11, -height), _v(0, 5 - height), "charcoal")
		_line(_v(0, 5 - height), _v(11, -height), "charcoal")
	_poly([_v(-11, -10), _v(0, -5), _v(11, -10), _v(0, -15)], "teal_light")
	_line(_v(-5, -11), _v(2, -9), "jade")
	_line(_v(-11, -10), _v(0, -15), "wood_light")


func _easel() -> void:
	_line(_v(-7, 0), _v(-2, -30), "wood_dark")
	_line(_v(7, 0), _v(2, -30), "wood_dark")
	_line(_v(0, 1), _v(0, -24), "wood")
	_line(_v(-5, -12), _v(5, -12), "wood")
	_poly([_v(-10, -13), _v(10, -15), _v(10, -33), _v(-10, -31)], "linen")
	_line(_v(10, -15), _v(10, -33), "bone")
	_line(_v(-10, -13), _v(10, -15), "sand_dark")
	for segment in [[_v(-7, -16), _v(-3, -23)], [_v(-3, -23), _v(2, -20)], [_v(2, -20), _v(7, -29)]]:
		_line(segment[0], segment[1], "rust")
	_px(7, -29, "teal")
	_px(-7, -16, "teal")


func _saddle() -> void:
	_poly([_v(-13, -1), _v(0, 4), _v(13, -1), _v(0, -6)], "rust")
	_line(_v(-13, -1), _v(0, 4), "flame")
	_poly([_v(-10, -5), _v(0, -1), _v(10, -5), _v(6, -12), _v(-6, -12)], "wood_light")
	_poly([_v(0, -1), _v(10, -5), _v(6, -12), _v(0, -9)], "wood")
	_line(_v(-6, -12), _v(6, -12), "gold_dark")
	_px(-11, 0, "gold")
	_px(11, 0, "gold")


func _amphora() -> void:
	_poly([_v(-2, 0), _v(2, 0), _v(6, -6), _v(6, -13), _v(3, -18), _v(-3, -18), _v(-6, -13), _v(-6, -6)], "tan")
	_poly([_v(1, 0), _v(2, 0), _v(6, -6), _v(6, -13), _v(3, -18), _v(1, -18)], "wood_light")
	_rect(-2, -22, 4, 4, "wood_light")
	_rect(-3, -23, 6, 1, "tan")
	_line(_v(-3, -21), _v(-6, -15), "wood")
	_line(_v(3, -21), _v(6, -15), "wood")
	_line(_v(-6, -11), _v(6, -11), "linen")
	for x in [-4, 0, 4]:
		_px(x, -10, "rust")


func _bed() -> void:
	# Mesmo losango de house_interior.gd (meia largura 26, meia profundidade 11).
	var back := _v(0, -13)
	var right := _v(26, -2)
	var front := _v(0, 9)
	var left := _v(-26, -2)
	var up := Vector2(0, -6)
	_poly([left, front, front + up, left + up], "wood")
	_poly([front, right, right + up, front + up], "wood_dark")
	_poly([back + up, right + up, front + up, left + up], "wood_light")
	_poly([back.lerp(left, .15) + up + Vector2(4, 0), right.lerp(back, .1) + up, front.lerp(right, .1) + up, left.lerp(front, .15) + up + Vector2(4, 0)], "sage")
	_line(left.lerp(front, .15) + up + Vector2(4, 0), front.lerp(right, .1) + up, "moss")
	_poly([right + up + Vector2(-12, -2), right + up + Vector2(-2, 0), right + up + Vector2(-6, -4), right + up + Vector2(-14, -5)], "linen")


func _table() -> void:
	for leg in [_v(-14, -2), _v(14, -2), _v(0, 5)]:
		_line(leg, leg + Vector2(0, -10), "wood_dark")
	_poly([_v(-20, -12), _v(0, -2), _v(20, -12), _v(0, -22)], "wood_light")
	_line(_v(-20, -12), _v(0, -2), "wood")
	_line(_v(0, -2), _v(20, -12), "wood_dark")
	_rect(-4, -21, 6, 3, "gold_dark")
	_px(-2, -22, "umber")
	_rect(6, -16, 5, 2, "stone_light")


func _barrel() -> void:
	_rect(-7, -18, 14, 18, "wood")
	_rect(3, -18, 4, 18, "wood_dark")
	_rect(-6, -19, 12, 2, "wood_light")
	_rect(-7, -6, 14, 1, "charcoal")
	_rect(-7, -13, 14, 1, "charcoal")
	_rect(-6, -17, 1, 15, "wood_light")


func _chest_closed() -> void:
	_chest(false)


func _chest_open() -> void:
	_chest(true)


func _chest(open: bool) -> void:
	_poly([_v(-13, -2), _v(0, 5), _v(14, -2), _v(14, -13), _v(0, -6), _v(-13, -13)], "wood")
	_poly([_v(0, 5), _v(14, -2), _v(14, -13), _v(0, -6)], "wood_dark")
	_line(_v(-13, -8), _v(0, -1), "gold_dark")
	_line(_v(0, -1), _v(14, -8), "gold_dark")
	if open:
		_poly([_v(-11, -12), _v(0, -7), _v(12, -12), _v(1, -16)], "umber")
		_poly([_v(-13, -13), _v(-12, -25), _v(1, -19), _v(0, -6)], "wood_light")
		_line(_v(-12, -25), _v(1, -19), "gold_dark")
	else:
		_poly([_v(-13, -13), _v(0, -20), _v(14, -13), _v(0, -6)], "wood_light")
		_line(_v(-13, -13), _v(0, -6), "wood")
		_rect(-2, -9, 4, 4, "gold")
		_px(-1, -8, "umber")


# --- Primitivas -----------------------------------------------------------------

func _begin() -> void:
	_img = Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)


func _end(name: String) -> void:
	_frames.append(_img)
	if not _sprites.has(name):
		_sprites[name] = {"frames": []}
	_sprites[name]["frames"].append(_frames.size() - 1)


func _v(x: float, y: float) -> Vector2:
	return Vector2(x, y)


func _iso(tx: float, ty: float) -> Vector2:
	return Vector2((tx - ty) * 32.0, (tx + ty) * 16.0)


## Ponto numa face vertical: `t` ao longo da aresta de chão a→b, `h` pixels acima.
func _face(a: Vector2, b: Vector2, t: float, h: float) -> Vector2:
	return a.lerp(b, t) + Vector2(0, -h)


func _px(x: int, y: int, color: String) -> void:
	var point := PIVOT + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < CELL.x and point.y < CELL.y:
		_img.set_pixelv(point, Color(PAL[color]))


func _pxv(point: Vector2, color: String) -> void:
	_px(roundi(point.x), roundi(point.y), color)


func _rect(x: int, y: int, w: int, h: int, color: String) -> void:
	for row in range(h):
		for column in range(w):
			_px(x + column, y + row, color)


func _rectv(point: Vector2, w: int, h: int, color: String) -> void:
	_rect(roundi(point.x), roundi(point.y), w, h, color)


func _poly(points: Array, color: String) -> void:
	var polygon := PackedVector2Array(points)
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + .5, y + .5), polygon):
				_px(x, y, color)


func _line(a: Vector2, b: Vector2, color: String) -> void:
	var from := Vector2i(roundi(a.x), roundi(a.y))
	var to := Vector2i(roundi(b.x), roundi(b.y))
	var delta := Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var step := Vector2i(1 if from.x < to.x else -1, 1 if from.y < to.y else -1)
	var error := delta.x + delta.y
	while true:
		_px(from.x, from.y, color)
		if from == to:
			break
		var twice := 2 * error
		if twice >= delta.y:
			error += delta.y
			from.x += step.x
		if twice <= delta.x:
			error += delta.x
			from.y += step.y


## Caixa isométrica com medidas em tiles (como BOXES em house_interior.gd);
## devolve os cantos do tampo: fundo, direita, frente, esquerda.
func _box(size_x: float, size_y: float, height: float, top: String, left: String, right: String) -> PackedVector2Array:
	var a := _iso(-size_x * .5, -size_y * .5)
	var b := _iso(size_x * .5, -size_y * .5)
	var c := _iso(size_x * .5, size_y * .5)
	var d := _iso(-size_x * .5, size_y * .5)
	var up := Vector2(0, -height)
	_poly([d, c, c + up, d + up], left)
	_poly([b, c, c + up, b + up], right)
	_poly([a + up, b + up, c + up, d + up], top)
	_line(c, c + up, "umber")
	return PackedVector2Array([a + up, b + up, c + up, d + up])


func _eyes(left: int, right: int, y: int, closed: bool, lid: String) -> void:
	if closed:
		_rect(left - 1, y, 2, 1, lid)
		_rect(right, y, 2, 1, lid)
	else:
		_px(left, y, "ink")
		_px(right, y, "ink")


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
		"layers": [{"name": "Interiores", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}],
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


func _write_plan() -> void:
	var plan := {
		"version": 1,
		"pixel_art": true,
		"canvas": [CELL.x, CELL.y],
		"pivot": [PIVOT.x, PIVOT.y],
		"columns": COLUMNS,
		"frames": _frames.size(),
		"texture": "res://assets/world/interiors_v1.png",
		"source": "res://art/pixelorama/interiors_v1/interiors_v1.pxo",
		"sprites": _sprites
	}
	var file := FileAccess.open(PLAN, FileAccess.WRITE)
	file.store_string(JSON.stringify(plan, "\t"))
	file.close()


func _write_preview() -> void:
	var rows := ceili(_frames.size() / float(COLUMNS))
	var sheet := Image.create_empty(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1a1f"))
	for index in range(_frames.size()):
		sheet.blend_rect(_frames[index], Rect2i(Vector2i.ZERO, CELL), Vector2i((index % COLUMNS) * CELL.x, (index / COLUMNS) * CELL.y))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	sheet.save_png("res://qa/interiors_v1_preview.png")
