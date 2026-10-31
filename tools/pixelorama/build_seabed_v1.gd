extends SceneTree

## Gera a arte do fundo do mar para o mergulho (docs/MUNDO_BARCO_ILHA.md, "Mergulho"):
## o chão de areia contínuo e as peças (algas, pedras, ruínas do porto antigo, a
## âncora, a estela, o casco naufragado), na paleta do Porto v7. A cor de água, o
## escurecer com a profundidade e a luz da superfície vêm do shader do mergulho
## (harbor_pixel_underwater.gdshader); a arte fica nas cores de terra, como o porto.
##
## Saída: art/pixelorama/seabed_v1/seabed_floor_v1.pxo e seabed_props_v1.pxo, mais
## assets/world/seabed_v1/floor.png, props.png e seabed_v1_manifest.json (retângulo e
## pivô de cada peça). Um pixel da fonte é um pixel do mundo.
##
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_seabed_v1.gd
## Opcional: -- --preview grava qa/seabed_v1_preview.png (folha ampliada 3×).

const PERIOD := 8
const FLOOR_SIZE := Vector2i(64 * PERIOD, 32 * PERIOD)
const CELL := 96
const COLUMNS := 6
const PIVOT := Vector2i(48, 88)
const SHEET_SIZE := Vector2i(CELL * COLUMNS, CELL * 4)
const OUT_DIR := "res://art/pixelorama/seabed_v1"
const ASSET_DIR := "res://assets/world/seabed_v1"
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
## Rampas do claro ao escuro, com a luz de cima à esquerda como no porto.
const LIMESTONE := ["linen", "bone", "sand_dark", "stone_light", "stone"]
const ROCK := ["stone_light", "stone", "stone_dark", "charcoal"]
const CLAY := ["tan", "rust", "wood_light", "wood"]
const LIGHT := Vector3(-.5, -.62, .6)

var _props: Dictionary = {}
var _sheet: Image


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASSET_DIR))
	var floor_image := _floor()
	floor_image.save_png(ASSET_DIR + "/floor.png")
	_sheet = Image.create_empty(SHEET_SIZE.x, SHEET_SIZE.y, false, Image.FORMAT_RGBA8)
	var slot := 0
	for frame in range(3):
		_place("grass_a_%d" % frame, _grass(frame, 8, Vector2i(16, 32), ["olive_dark", "olive", "jade", "olive_light"], 11), slot)
		slot += 1
	for frame in range(3):
		_place("grass_b_%d" % frame, _grass(frame, 5, Vector2i(28, 46), ["olive_dark", "olive_dark", "olive", "tan"], 23), slot)
		slot += 1
	_place("rock_small", _rock([[Vector2(48, 80), Vector2(14, 9)]], 3), slot)
	_place("rock_large", _rock([[Vector2(43, 73), Vector2(22, 15)], [Vector2(60, 80), Vector2(15, 9)]], 5), slot + 1)
	_place("amphora", _amphora(), slot + 2)
	_place("drum", _drum(), slot + 3)
	_place("column", _column(), slot + 4)
	_place("head", _head(), slot + 5)
	_place("anchor", _anchor(), slot + 6)
	_place("urchins", _urchins(), slot + 7)
	_place("stela", _stela(), slot + 8)
	_place("shells", _shells(), slot + 9)
	# O casco naufragado ocupa duas células na última fileira.
	var wreck := _wreck()
	_sheet.blit_rect(wreck, Rect2i(Vector2i.ZERO, wreck.get_size()), Vector2i(0, CELL * 3))
	_props["wreck"] = {"rect": [0, CELL * 3, CELL * 2, CELL], "pivot": [CELL, PIVOT.y]}
	_sheet.save_png(ASSET_DIR + "/props.png")
	_write_pxo(OUT_DIR + "/seabed_floor_v1.pxo", [floor_image], FLOOR_SIZE, ["floor"], "Fundo")
	_write_pxo(OUT_DIR + "/seabed_props_v1.pxo", [_sheet], SHEET_SIZE, ["props"], "Peças")
	var manifest := {
		"version": 1, "pixel_art": true, "period_tiles": PERIOD, "floor_size": [FLOOR_SIZE.x, FLOOR_SIZE.y],
		"floor": ASSET_DIR + "/floor.png", "props_sheet": ASSET_DIR + "/props.png", "props": _props,
		"source": [OUT_DIR + "/seabed_floor_v1.pxo", OUT_DIR + "/seabed_props_v1.pxo"],
		"note": "Chão: UV = posição no mundo ÷ floor_size, com repetição. Peças: rect na folha e pivô (pé) dentro do rect."
	}
	for path in [ASSET_DIR + "/seabed_v1_manifest.json", OUT_DIR + "/export_plan.json"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	if "--preview" in OS.get_cmdline_user_args():
		var preview := _sheet.duplicate()
		preview.resize(preview.get_width() * 3, preview.get_height() * 3, Image.INTERPOLATE_NEAREST)
		var back := Image.create_empty(preview.get_width(), preview.get_height(), false, Image.FORMAT_RGBA8)
		back.fill(Color("1e3e44"))
		back.blend_rect(preview, Rect2i(Vector2i.ZERO, preview.get_size()), Vector2i.ZERO)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
		back.save_png("res://qa/seabed_v1_preview.png")
	print("SEABED_V1 pecas=%d chao=%s folha=%s" % [_props.size(), FLOOR_SIZE, SHEET_SIZE])
	quit()


func _place(name: String, image: Image, slot: int) -> void:
	var at := Vector2i((slot % COLUMNS) * CELL, (slot / COLUMNS) * CELL)
	_sheet.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), at)
	_props[name] = {"rect": [at.x, at.y, CELL, CELL], "pivot": [PIVOT.x, PIVOT.y]}


# --- Ruído e desenho --------------------------------------------------------------

func _hash(a: int, b: int, seed: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


func _noise(gx: float, gy: float, step: float, seed: int) -> float:
	var nodes := int(PERIOD / step)
	var fx := gx / step
	var fy := gy / step
	var ix := floori(fx)
	var iy := floori(fy)
	var tx := fx - ix
	var ty := fy - iy
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash(posmod(ix, nodes), posmod(iy, nodes), seed)
	var b := _hash(posmod(ix + 1, nodes), posmod(iy, nodes), seed)
	var c := _hash(posmod(ix, nodes), posmod(iy + 1, nodes), seed)
	var d := _hash(posmod(ix + 1, nodes), posmod(iy + 1, nodes), seed)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## Limiar em grãos agrupados, como no chão v8.
func _cluster(x: int, y: int) -> float:
	var bx := floori(x / 2.0)
	var by := floori(y / 2.0)
	return (float(BAYER[posmod(by, 4) * 4 + posmod(bx, 4)]) + .5) / 16.0 * .5 + _hash(floori(x / 4.0), floori(y / 2.0), 83) * .5


func _ground(x: int, y: int) -> Vector2:
	var px := float(x) + .5
	var py := float(y) + .5
	return Vector2((px / 32.0 + py / 16.0) * .5 + .5, (py / 16.0 - px / 32.0) * .5 + .5)


func _new_cell(width: int = CELL) -> Image:
	return Image.create_empty(width, CELL, false, Image.FORMAT_RGBA8)


func _px(image: Image, x: int, y: int, color: String) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, Color(PAL[color]))


func _solid(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > .5


## Elipse cheia com luz de cima à esquerda, em faixas da rampa. `rough` deixa a
## borda irregular (pedras); `seed` muda o desenho da borda.
func _blob(image: Image, center: Vector2, radius: Vector2, ramp: Array, rough: float = 0.0, seed: int = 0) -> void:
	var light := LIGHT.normalized()
	for y in range(floori(center.y - radius.y) - 2, ceili(center.y + radius.y) + 3):
		for x in range(floori(center.x - radius.x) - 2, ceili(center.x + radius.x) + 3):
			var d := Vector2((x + .5 - center.x) / radius.x, (y + .5 - center.y) / radius.y)
			var edge := 1.0 + (_hash(floori(x / 2.0), floori(y / 2.0), seed) - .5) * rough
			var r := d.length()
			if r > edge:
				continue
			var normal := Vector3(d.x, d.y, sqrt(maxf(0.0, 1.0 - minf(r * r, 1.0)))).normalized()
			var lit := normal.dot(light)
			var index := clampi(int((1.0 - lit) * .5 * ramp.size() * 1.25), 0, ramp.size() - 1)
			_px(image, x, y, ramp[index])


func _poly(image: Image, points: PackedVector2Array, color: String) -> void:
	var box := Rect2(points[0], Vector2.ZERO)
	for point in points:
		box = box.expand(point)
	for y in range(floori(box.position.y), ceili(box.end.y) + 1):
		for x in range(floori(box.position.x), ceili(box.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + .5, y + .5), points):
				_px(image, x, y, color)


func _line(image: Image, from: Vector2i, to: Vector2i, color: String) -> void:
	var delta := (to - from).abs()
	var step := Vector2i(1 if to.x >= from.x else -1, 1 if to.y >= from.y else -1)
	var error := delta.x - delta.y
	var at := from
	while true:
		_px(image, at.x, at.y, color)
		if at == to:
			break
		var twice := error * 2
		if twice > -delta.y:
			error -= delta.y
			at.x += step.x
		if twice < delta.x:
			error += delta.x
			at.y += step.y


## Contorno de 1 px em volta do que foi pintado, como nas peças do porto.
func _outline(image: Image, color: String) -> void:
	var source := image.duplicate()
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _solid(source, x, y):
				continue
			if _solid(source, x - 1, y) or _solid(source, x + 1, y) or _solid(source, x, y - 1) or _solid(source, x, y + 1):
				_px(image, x, y, color)


## Areia cobrindo a base: a peça parece afundada no fundo, com a borda irregular.
func _bury(image: Image, from_y: int, seed: int) -> void:
	for y in range(from_y - 3, image.get_height()):
		for x in range(image.get_width()):
			if not _solid(image, x, y):
				continue
			var line := from_y + int(round((_noise(x / 9.0, 0.0, 1.0, seed) - .5) * 5.0))
			if y >= line:
				_px(image, x, y, "sand" if y == line else ("sand_dark" if _hash(x, y, seed) > .25 else "stone_light"))


## Algas e cracas sobre as faces de cima.
func _encrust(image: Image, amount: float, seed: int) -> void:
	var source := image.duplicate()
	for y in range(1, image.get_height()):
		for x in range(image.get_width()):
			if not _solid(source, x, y) or _solid(source, x, y - 1):
				continue
			for depth in range(3):
				if _hash(x, y + depth, seed) < amount * (1.0 - depth * .3) and _solid(source, x, y + depth):
					_px(image, x, y + depth, "olive" if depth == 0 else "olive_dark")
	# Cracas raras: com mais delas, a peça inteira vira chuvisco branco.
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if _solid(source, x, y) and _hash(x, y, seed + 7) < amount * .012:
				_px(image, x, y, "bone")


# --- Chão -------------------------------------------------------------------------

## Areia do fundo: manchas de lodo, marcas da correnteza, seixos e conchinhas, em
## contraste baixo (o fundo fica atrás de Senu e das peças).
func _floor() -> Image:
	var image := Image.create_empty(FLOOR_SIZE.x, FLOOR_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(FLOOR_SIZE.y):
		for x in range(FLOOR_SIZE.x):
			var g := _ground(x, y)
			var silt := _noise(g.x, g.y, 2.0, 41)
			var color := "sand_dark"
			if smoothstep(.5, .72, silt) > _cluster(x, y):
				color = "lichen"
			# Marcas da correnteza: os coeficientes × PERIOD dão inteiros e fecham na emenda.
			var wave := fposmod(g.x * 3.0 + g.y * 1.0 + _noise(g.x, g.y, 1.0, 43) * 1.5, 1.0)
			if wave < .07:
				color = "stone_light"
			elif wave > .52 and wave < .58:
				color = "sand"
			var speck := _hash(x, y, 47)
			if speck < .006:
				color = "stone"
			elif speck > .996:
				color = "bone"
			# Seixos: grãozinhos de 2 px, raros.
			if _hash(floori(x / 2.0), floori(y / 2.0), 53) > .992:
				color = "stone_dark" if _hash(x, y, 59) < .5 else "stone"
			_px(image, x, y, color)
	return image


# --- Peças --------------------------------------------------------------------------

## Tufo de algas (fitas de posidônia): `blades` fitas que balançam em três quadros.
func _grass(frame: int, blades: int, heights: Vector2i, ramp: Array, seed: int) -> Image:
	var image := _new_cell()
	for blade in range(blades):
		var base_x := PIVOT.x - blades + blade * 2 + int(round((_hash(blade, 1, seed) - .5) * 4.0))
		var height := heights.x + int(_hash(blade, 2, seed) * (heights.y - heights.x))
		var lean := (_hash(blade, 3, seed) - .5) * 10.0
		var sway := sin(frame * TAU / 3.0 + blade * .9) * 3.0
		for step in range(height):
			var t := float(step) / height
			var x := base_x + int(round((lean + sway) * t * t))
			var y := PIVOT.y - step
			var tone: String = ramp[clampi(int(t * ramp.size()), 0, ramp.size() - 1)]
			_px(image, x, y, tone)
			if t < .55:
				_px(image, x + 1, y, ramp[0])
	return image


func _rock(blobs: Array, seed: int) -> Image:
	var image := _new_cell()
	for item: Array in blobs:
		_blob(image, item[0], item[1], ROCK, .35, seed)
	_encrust(image, .45, seed)
	_outline(image, "night")
	return image


## Ânfora deitada e meio enterrada, com a boca para a esquerda e o bico para a direita.
func _amphora() -> Image:
	var image := _new_cell()
	_blob(image, Vector2(50, 75), Vector2(15, 9), CLAY)
	_poly(image, PackedVector2Array([Vector2(62, 70), Vector2(72, 75), Vector2(62, 81)]), "wood_light")
	_px(image, 72, 75, "wood")
	_px(image, 73, 75, "wood")
	# Pescoço, boca e alças.
	for y in range(72, 79):
		for x in range(29, 36):
			_px(image, x, y, "tan" if y < 74 else ("rust" if y < 77 else "wood_light"))
	for y in range(70, 81):
		_px(image, 27, y, "wood")
		_px(image, 28, y, "tan" if y < 74 else "rust")
	for x in range(33, 39):
		_px(image, x, 69, "wood_light")
		_px(image, x, 81, "wood")
	_px(image, 38, 70, "wood_light")
	_px(image, 38, 80, "wood")
	_px(image, 44, 70, "cream")
	_px(image, 45, 70, "cream")
	_encrust(image, .18, 31)
	_bury(image, 82, 33)
	_outline(image, "umber")
	return image


## Tambor de coluna caído, de lado: a face redonda à esquerda e as caneluras.
func _drum() -> Image:
	var image := _new_cell()
	for y in range(60, 86):
		for x in range(36, 64):
			var row := float(y - 60) / 26.0
			var tone := "bone" if row < .3 else ("sand_dark" if row < .6 else ("stone_light" if row < .85 else "stone"))
			if posmod(y - 60, 4) == 3 and row > .15:
				tone = "stone_light" if row < .6 else "stone_dark"
			_px(image, x, y, tone)
	_blob(image, Vector2(36, 73), Vector2(8, 13), LIMESTONE)
	_blob(image, Vector2(64, 73), Vector2(3, 13), ["stone", "stone_dark"])
	# A face cortada: anéis gastos.
	for angle in range(0, 360, 20):
		var at := Vector2(36, 73) + Vector2(cos(deg_to_rad(angle)) * 4.0, sin(deg_to_rad(angle)) * 7.0)
		_px(image, int(at.x), int(at.y), "sand_dark")
	_encrust(image, .4, 37)
	_bury(image, 84, 39)
	_outline(image, "charcoal")
	return image


## Coluna papiriforme quebrada, de pé, com plinto e caneluras.
func _column() -> Image:
	var image := _new_cell()
	for y in range(80, 89):
		for x in range(35, 61):
			_px(image, x, y, "bone" if y < 82 else ("stone_light" if y < 86 else "stone"))
	for x in range(40, 56):
		var top := 26 + int(_hash(x, 0, 41) * 7.0) + (3 if x > 50 else 0)
		for y in range(top, 80):
			var column := x - 40
			var tone := "linen" if column < 3 else ("bone" if column < 8 else ("sand_dark" if column < 12 else "stone_light"))
			if posmod(column, 3) == 2:
				tone = "sand_dark" if column < 8 else "stone"
			if y == top:
				tone = "bone"
			_px(image, x, y, tone)
	# Faixas amarradas do fuste, como nos feixes de papiro.
	for y in [70, 72]:
		for x in range(40, 56):
			_px(image, x, y, "stone_light" if x < 48 else "stone")
	_encrust(image, .35, 43)
	_outline(image, "umber")
	return image


## Cabeça colossal de faraó com o nemes, enterrada até o queixo e sem o nariz.
func _head() -> Image:
	var image := _new_cell()
	# Nemes atrás do rosto: topo, abas laterais listradas.
	_poly(image, PackedVector2Array([Vector2(33, 44), Vector2(39, 32), Vector2(57, 32), Vector2(63, 44), Vector2(68, 84), Vector2(28, 84)]), "sand_dark")
	for y in range(32, 85):
		for x in range(26, 70):
			if not _solid(image, x, y):
				continue
			if posmod(y, 4) < 2:
				_px(image, x, y, "stone_light" if x < 48 else "stone")
			elif x > 56:
				_px(image, x, y, "stone_light")
	# Rosto, mais estreito no queixo.
	_blob(image, Vector2(48, 59), Vector2(9, 14), LIMESTONE)
	_poly(image, PackedVector2Array([Vector2(41, 66), Vector2(55, 66), Vector2(51, 75), Vector2(45, 75)]), "sand_dark")
	for x in range(42, 46):
		_px(image, x, 55, "stone")
		_px(image, x + 9, 55, "stone")
	# Olhos amendoados com o traço de kohl esticado para fora.
	for x in range(42, 46):
		_px(image, x, 58, "charcoal")
		_px(image, x + 9, 58, "charcoal")
	_px(image, 41, 59, "charcoal")
	_px(image, 55, 59, "charcoal")
	_px(image, 44, 57, "stone_dark")
	_px(image, 53, 57, "stone_dark")
	# Nariz quebrado: só a marca escura do corte; boca e queixo.
	_px(image, 48, 61, "stone")
	_px(image, 48, 62, "stone_dark")
	_px(image, 49, 62, "stone")
	for x in range(46, 51):
		_px(image, x, 67, "stone")
	_px(image, 47, 68, "stone_light")
	_px(image, 48, 68, "stone_light")
	_px(image, 48, 72, "stone_light")
	# Ureu na testa.
	_px(image, 48, 44, "gold_dark")
	_px(image, 48, 43, "gold_dark")
	_px(image, 47, 45, "stone")
	_encrust(image, .25, 47)
	_bury(image, 80, 49)
	_outline(image, "umber")
	return image


## Âncora de pedra: uma laje com um furo para o cabo e dois para as estacas.
func _anchor() -> Image:
	var image := _new_cell()
	_poly(image, PackedVector2Array([Vector2(34, 86), Vector2(62, 86), Vector2(57, 54), Vector2(52, 48), Vector2(44, 48), Vector2(39, 54)]), "stone")
	for y in range(46, 88):
		for x in range(30, 66):
			if not _solid(image, x, y):
				continue
			var shade := (x - 34) / 28.0 + (y - 48) / 80.0
			_px(image, x, y, "stone_light" if shade < .35 else ("stone" if shade < .75 else "stone_dark"))
	for hole in [[Vector2(48, 56), 3.0], [Vector2(41, 77), 2.0], [Vector2(55, 77), 2.0]]:
		var center: Vector2 = hole[0]
		var radius: float = hole[1]
		for y in range(int(center.y - radius), int(center.y + radius) + 1):
			for x in range(int(center.x - radius), int(center.x + radius) + 1):
				if Vector2(x + .5, y + .5).distance_to(center) <= radius:
					_px(image, x, y, "night")
	# Pedaço do cabo saindo do furo de cima e caindo na areia.
	var rope := [Vector2i(50, 55), Vector2i(55, 52), Vector2i(62, 54), Vector2i(68, 62), Vector2i(71, 74), Vector2i(76, 84)]
	for index in range(rope.size() - 1):
		_line(image, rope[index], rope[index + 1], "tan")
		_line(image, rope[index] + Vector2i(0, 1), rope[index + 1] + Vector2i(0, 1), "wood")
	_encrust(image, .3, 53)
	_outline(image, "charcoal")
	return image


## Ouriços: bolas escuras com espinhos, e duas conchas.
func _urchins() -> Image:
	var image := _new_cell()
	for item in [[Vector2(40, 82), 3.0], [Vector2(50, 84), 4.0], [Vector2(57, 80), 2.5]]:
		var center: Vector2 = item[0]
		var radius: float = item[1]
		for spike in range(12):
			var angle := spike * TAU / 12.0 + .2
			var tip := center + Vector2(cos(angle), sin(angle) * .8) * (radius + 3.0)
			_line(image, Vector2i(center), Vector2i(tip), "slate")
		_blob(image, center, Vector2(radius, radius * .85), ["sea", "slate", "night", "ink"])
	_shell(image, Vector2i(32, 85), 59)
	_shell(image, Vector2i(64, 86), 61)
	return image


func _shell(image: Image, at: Vector2i, seed: int) -> void:
	for y in range(-3, 1):
		for x in range(-3, 4):
			if absi(x) <= 3 + y:
				_px(image, at.x + x, at.y + y, "linen" if posmod(x, 2) == 0 else "bone")
	_px(image, at.x, at.y + 1, "sand_dark")
	if _hash(at.x, at.y, seed) > .5:
		_px(image, at.x, at.y - 3, "cream")


## Estela submersa: laje de topo redondo com o disco alado e linhas de escrita.
func _stela() -> Image:
	var image := _new_cell()
	for y in range(34, 88):
		for x in range(36, 61):
			var top := 34.0 + 12.0 - sqrt(maxf(0.0, 144.0 - pow(x + .5 - 48.5, 2.0))) if absf(x + .5 - 48.5) < 12.0 else 99.0
			if y < top:
				continue
			var column := x - 36
			_px(image, x, y, "linen" if column < 3 else ("bone" if column < 14 else ("sand_dark" if column < 21 else "stone_light")))
	# Disco alado no topo.
	_blob(image, Vector2(48, 44), Vector2(3, 3), ["gold", "gold_dark", "tan"])
	for x in range(39, 45):
		_px(image, x, 44 + (1 if x < 42 else 0), "gold_dark")
		_px(image, 96 - x, 44 + (1 if x < 42 else 0), "gold_dark")
	# Registros de hieróglifos: grupinhos gravados em fileiras.
	for row in range(5):
		var y := 52 + row * 6
		_line(image, Vector2i(39, y - 2), Vector2i(57, y - 2), "sand_dark")
		for glyph in range(5):
			var x := 40 + glyph * 4
			var shape := int(_hash(row, glyph, 67) * 4.0)
			match shape:
				0:
					_px(image, x, y, "stone")
					_px(image, x + 1, y, "stone")
				1:
					_px(image, x, y - 1, "stone")
					_px(image, x, y, "stone")
				2:
					_px(image, x, y, "stone")
					_px(image, x + 1, y - 1, "stone")
				_:
					_px(image, x + 1, y, "stone")
	_encrust(image, .3, 71)
	_bury(image, 84, 73)
	_outline(image, "umber")
	return image


## Conchas e uma estrela-do-mar alaranjada sobre a areia.
func _shells() -> Image:
	var image := _new_cell()
	var star := Vector2(50, 82)
	for arm in range(5):
		var angle := arm * TAU / 5.0 - PI / 2.0
		for step in range(6):
			var at := star + Vector2(cos(angle), sin(angle) * .6) * step
			_px(image, int(at.x), int(at.y), "rust" if step < 4 else "flame")
			if step < 3:
				_px(image, int(at.x) + 1, int(at.y), "tan")
	_px(image, int(star.x), int(star.y), "flame")
	_shell(image, Vector2i(36, 86), 79)
	_shell(image, Vector2i(62, 85), 83)
	_shell(image, Vector2i(42, 80), 89)
	_outline(image, "umber")
	return image


## Casco naufragado do Recife: quilha, cavernas quebradas, algumas tábuas e o mastro caído.
func _wreck() -> Image:
	var image := Image.create_empty(CELL * 2, CELL, false, Image.FORMAT_RGBA8)
	var keel_from := Vector2(18, 80)
	var keel_to := Vector2(174, 70)
	# Tábuas restantes no costado de baixo.
	for strip in range(3):
		var points := PackedVector2Array()
		for i in range(9):
			var t := i / 8.0
			var at := keel_from.lerp(keel_to, t)
			points.append(at + Vector2(0, -4.0 - strip * 4.0 - sin(t * PI) * 6.0))
		for i in range(8, -1, -1):
			var t := i / 8.0
			var at := keel_from.lerp(keel_to, t)
			points.append(at + Vector2(0, -1.0 - strip * 4.0 - sin(t * PI) * 6.0))
		var gap_from := 30 + strip * 25
		var cut := PackedVector2Array()
		for point in points:
			cut.append(point)
		_poly(image, cut, ["wood", "wood_light", "wood"][strip])
		# Buracos onde as tábuas apodreceram.
		for x in range(gap_from, gap_from + 18):
			for y in range(40, 90):
				if _hash(floori(x / 3.0), y, strip) < .9 and _solid(image, x, y) and y < 80 - strip * 4:
					image.set_pixel(x, y, Color(0, 0, 0, 0))
	# Cavernas: costelas curvas que sobem do costado.
	for rib in range(12):
		var t := (rib + .5) / 12.0
		var foot := keel_from.lerp(keel_to, t)
		var height := 18.0 + sin(t * PI) * 16.0 - _hash(rib, 1, 91) * 12.0
		var lean := -4.0 + t * 6.0
		var previous := Vector2i(foot)
		for step in range(1, int(height)):
			var s := float(step) / height
			var point := Vector2i(foot + Vector2(lean * s * s, -step))
			_line(image, previous, point, "wood_dark" if step % 5 == 0 else "wood_light")
			_px(image, point.x + 1, point.y, "wood")
			previous = point
	# Quilha e cadaste de popa quebrado.
	_line(image, Vector2i(keel_from), Vector2i(keel_to), "wood_dark")
	_line(image, Vector2i(keel_from) + Vector2i(0, 1), Vector2i(keel_to) + Vector2i(0, 1), "umber")
	_line(image, Vector2i(keel_to), Vector2i(keel_to) + Vector2i(6, -30), "wood_dark")
	_line(image, Vector2i(keel_to) + Vector2i(1, 0), Vector2i(keel_to) + Vector2i(7, -30), "wood")
	# Mastro caído atravessado, na frente.
	_line(image, Vector2i(30, 88), Vector2i(150, 58), "wood_light")
	_line(image, Vector2i(30, 89), Vector2i(150, 59), "wood")
	_encrust(image, .3, 97)
	_bury(image, 84, 99)
	_outline(image, "umber")
	return image


# --- Arquivos -------------------------------------------------------------------

func _write_pxo(path: String, frames: Array, size: Vector2i, names: Array, layer: String) -> void:
	var frame_data := []
	for index in range(frames.size()):
		frame_data.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tags := []
	for index in range(names.size()):
		tags.append({"name": names[index], "color": "6db0a4ff", "from": index + 1, "to": index + 1})
	var data := {
		"pixelorama_version": "v1.2.3-stable", "pxo_version": 7,
		"size_x": size.x, "size_y": size.y, "color_mode": 5,
		"layers": [{"name": layer, "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}],
		"frames": frame_data, "tags": tags, "fps": 1.0, "current_frame": 0, "current_layer": 0,
		"export_profile": {"orientation": "1", "lines_count": "1", "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}
	}
	var zip := ZIPPacker.new()
	var error := zip.open(ProjectSettings.globalize_path(path))
	assert(error == OK, "não foi possível criar " + path)
	_zip_file(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip_file(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for index in range(frames.size()):
		_zip_file(zip, "image_data/frames/%d/layer_1" % (index + 1), (frames[index] as Image).get_data())
	_zip_file(zip, "preview.png", (frames[0] as Image).save_png_to_buffer())
	zip.close()


func _zip_file(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()
