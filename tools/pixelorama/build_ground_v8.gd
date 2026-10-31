extends SceneTree

## Gera o chão v8 do Porto (docs/MUNDO_CHAO_V8.md): uma textura contínua por tema,
## na paleta quente das construções do Porto v7, e as faces dos paredões. As peças
## (armazéns, templos, arcos) usam sobretudo madeiras, arenito ocre/oliva, areia e
## dourado; o chão antigo usava os cinzas frios que quase não aparecem nelas.
##
## Saída: art/pixelorama/ground_v8/ground_v8.pxo (um quadro por tema) e
## ground_faces_v8.pxo (pedra e madeira), mais os PNG do jogo em
## assets/world/ground_v8/ e o manifesto. Um pixel da fonte é um pixel do mundo.
##
## Cada textura repete a cada PERIOD tiles nos dois eixos do chão; no plano da tela
## isso dá um retângulo de 64·PERIOD × 32·PERIOD que fecha sem emenda. O jogo
## mapeia o mundo direto nela (UV = posição ÷ tamanho), então o piso atravessa os
## tiles sem a borda de cada losango.
##
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_ground_v8.gd
## Opcional: -- --preview grava qa/ground_v8_preview.png.

const PERIOD := 8
const SIZE := Vector2i(64 * PERIOD, 32 * PERIOD)
const FACE_SIZE := Vector2i(128, 32)
const THEMES := ["stone", "sand", "wood", "mosaic", "garden", "crypt", "aqueduct", "arena"]
const OUT_DIR := "res://art/pixelorama/ground_v8"
const ASSET_DIR := "res://assets/world/ground_v8"
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
## Lajotas de cada tema: comprimento e altura (tiles), deslocamento das fiadas, tons
## das lajotas, junta, luz e sombra do chanfro.
##
## O chão fica atrás das figuras: os tons vizinhos têm quase o mesmo valor e mudam por
## manchas de cerca de 2 tiles, não lajota a lajota; a junta fica um degrau abaixo da
## pedra, nunca no escuro dos contornos dos personagens. Meta: a faixa de luminância
## de cada tema (p5–p95) perto de 50, contra cerca de 100 na primeira versão.
const STYLE := {
	## Sem lajotas ocre: em manchas, elas viravam faixas laranja ao longo das fiadas.
	"stone": {"len": 1.0, "row": .5, "stagger": .5, "tones": ["olive", "olive", "stone_light", "stone_light", "stone_light"], "joint": "wood_light", "light": "sand_dark", "shade": "olive_dark"},
	"mosaic": {"len": 1.0, "row": 1.0, "stagger": .5, "tones": ["stone_light", "stone_light", "olive", "stone_light"], "joint": "olive_dark", "light": "sand_dark", "shade": "stone"},
	"garden": {"len": 1.0, "row": .5, "stagger": .5, "tones": ["olive", "olive", "stone_light", "olive", "stone_light"], "joint": "olive_dark", "light": "olive_light", "shade": "olive_dark"},
	## Cripta em lajes de 2×1 desencontradas: a grade de losangos sumia só com tons.
	"crypt": {"len": 2.0, "row": 1.0, "stagger": .5, "tones": ["sea", "moss", "sea", "sea", "moss"], "joint": "slate", "light": "sage", "shade": "slate"},
	"aqueduct": {"len": 1.0, "row": .5, "stagger": .5, "tones": ["moss", "sage", "moss", "stone"], "joint": "sea", "light": "lichen", "shade": "sea"},
	"sand": {"len": 1.0, "row": 1.0, "stagger": .5, "tones": ["stone_light", "sand_dark", "stone_light", "sand_dark"], "joint": "wood_light", "light": "sand", "shade": "olive"},
	## Arena do Porteiro: calcário claro e frio. O Porteiro é marrom-avermelhado escuro;
	## num chão de terra marrom ele sumia.
	"arena": {"len": 1.0, "row": 1.0, "stagger": .5, "tones": ["lichen", "lichen", "stone_light", "lichen"], "joint": "sage", "light": "bone", "shade": "stone"},
	"wood": {"len": 2.0, "row": .25, "stagger": .5, "tones": ["wood", "wood_light", "wood", "wood_light", "wood"], "joint": "wood_dark", "light": "tan", "shade": "wood_dark"},
}

var _frames: Array[Image] = []


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ASSET_DIR))
	for theme in THEMES:
		var image := _theme(theme)
		image.save_png("%s/%s.png" % [ASSET_DIR, theme])
		_frames.append(image)
	var faces: Array[Image] = [_face_stone(), _face_wood()]
	faces[0].save_png(ASSET_DIR + "/face_stone.png")
	faces[1].save_png(ASSET_DIR + "/face_wood.png")
	_write_pxo(OUT_DIR + "/ground_v8.pxo", _frames, SIZE, THEMES, "Chão")
	_write_pxo(OUT_DIR + "/ground_faces_v8.pxo", faces, FACE_SIZE, ["face_stone", "face_wood"], "Paredões")
	var manifest := {
		"version": 8, "pixel_art": true, "period_tiles": PERIOD, "size": [SIZE.x, SIZE.y], "face_size": [FACE_SIZE.x, FACE_SIZE.y],
		"themes": THEMES, "faces": ["face_stone", "face_wood"], "source": OUT_DIR + "/ground_v8.pxo",
		"note": "UV = posição no mundo ÷ size, com repetição; faces: u = x ÷ face_size.x, v = profundidade ÷ face_size.y"
	}
	for path in [ASSET_DIR + "/ground_v8_manifest.json", OUT_DIR + "/export_plan.json"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest, "\t"))
		file.close()
	if "--preview" in OS.get_cmdline_user_args():
		_write_preview()
	print("GROUND_V8 temas=%d faces=2 tamanho=%s" % [THEMES.size(), SIZE])
	quit()


# --- Ruído periódico ----------------------------------------------------------------

func _hash(a: int, b: int, seed: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


## Ruído de valor suave em nós a cada `step` tiles, fechando no período.
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


## Limiar do pontilhado ordenado 4×4 no pixel (0 a 1).
func _dither(x: int, y: int) -> float:
	return (float(BAYER[posmod(y, 4) * 4 + posmod(x, 4)]) + .5) / 16.0


## Limiar em grãos agrupados (0 a 1): o Bayer em blocos de 2×2 somado a um sorteio por
## célula de 4×2. A borda de uma mancha sai em montinhos de 2 a 6 px, como areia
## acumulada, e não no xadrez de pixel a pixel que nenhum sprite do jogo usa.
func _cluster(x: int, y: int) -> float:
	return _dither(floori(x / 2.0), floori(y / 2.0)) * .5 + _hash(floori(x / 4.0), floori(y / 2.0), 83) * .5


## Pixel da textura → chão em tiles, com 0 nas bordas dos tiles (o centro do tile
## (0, 0) é o ponto (0, 0) do mundo).
func _ground(x: int, y: int) -> Vector2:
	var px := float(x) + .5
	var py := float(y) + .5
	return Vector2((px / 32.0 + py / 16.0) * .5 + .5, (py / 16.0 - px / 32.0) * .5 + .5)


# --- Lajotas ----------------------------------------------------------------------

## Identidade da lajota sob o ponto do chão (periódica) e a posição dentro dela.
func _slab(g: Vector2, style: Dictionary, along_y: bool) -> Vector3i:
	var u := g.y if along_y else g.x
	var v := g.x if along_y else g.y
	var length: float = style["len"]
	var row_height: float = style["row"]
	var row := floori(v / row_height)
	var shift: float = float(style["stagger"]) * length if posmod(row, 2) == 1 else 0.0
	var column := floori((u + shift) / length)
	var rows := int(round(PERIOD / row_height))
	var columns := int(round(PERIOD / length))
	return Vector3i(posmod(column, columns), posmod(row, rows), 0)


## Centro da lajota `id` no chão (dentro do período), para o tom seguir as manchas.
func _slab_center(id: int, style: Dictionary) -> Vector2:
	var column := id / 1000
	var row := id % 1000
	var length: float = style["len"]
	var row_height: float = style["row"]
	var shift: float = float(style["stagger"]) * length if posmod(row, 2) == 1 else 0.0
	return Vector2((column + .5) * length - shift, (row + .5) * row_height)


func _theme(theme: String) -> Image:
	var style: Dictionary = STYLE[theme]
	var along_y := theme == "wood"
	var ids := PackedInt32Array()
	ids.resize(SIZE.x * SIZE.y)
	var grounds: Array[Vector2] = []
	grounds.resize(SIZE.x * SIZE.y)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var g := _ground(x, y)
			grounds[y * SIZE.x + x] = g
			var slab := _slab(g, style, along_y)
			ids[y * SIZE.x + x] = slab.x * 1000 + slab.y
	var image := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(SIZE.y):
		for x in range(SIZE.x):
			var g: Vector2 = grounds[y * SIZE.x + x]
			var id := ids[y * SIZE.x + x]
			var left := ids[y * SIZE.x + posmod(x - 1, SIZE.x)]
			var up := ids[posmod(y - 1, SIZE.y) * SIZE.x + x]
			var left2 := ids[y * SIZE.x + posmod(x - 2, SIZE.x)]
			var up2 := ids[posmod(y - 2, SIZE.y) * SIZE.x + x]
			var right := ids[y * SIZE.x + posmod(x + 1, SIZE.x)]
			var down := ids[posmod(y + 1, SIZE.y) * SIZE.x + x]
			var edge := "inner"
			if left != id or up != id:
				edge = "joint"
			elif right != id or down != id:
				edge = "shade"
			elif left2 != id or up2 != id:
				edge = "light"
			image.set_pixel(x, y, Color(PAL[_color(theme, style, g, id, edge, x, y)]))
	return image


## A cor de um pixel do tema: a lajota, a junta e o chanfro, e o que cada tema tem
## por cima (areia, musgo, incrustações, canaletas, marcas).
func _color(theme: String, style: Dictionary, g: Vector2, id: int, edge: String, x: int, y: int) -> String:
	var tones: Array = style["tones"]
	var tone_pick := _hash(id, 7, THEMES.find(theme))
	if theme != "wood":
		# O tom segue manchas de ~2 tiles (o centro da lajota no ruído), com um pouco
		# de sorteio por lajota; as tábuas variam uma a uma, como madeira de verdade.
		var center := _slab_center(id, style)
		tone_pick = clampf(_noise(center.x, center.y, 2.0, 37 + THEMES.find(theme)) * .7 + tone_pick * .3, 0.0, .999)
	var color: String = tones[mini(tones.size() - 1, int(tone_pick * tones.size()))]
	var speck := _hash(posmod(x, SIZE.x), posmod(y, SIZE.y), 91)
	var wear := _noise(g.x, g.y, 2.0, 13 + THEMES.find(theme))
	var patch := _noise(g.x + .37, g.y - .21, 1.0, 29 + THEMES.find(theme))
	match edge:
		"joint":
			color = style["joint"]
		"shade":
			color = style["shade"]
		"light":
			color = style["light"]
	match theme:
		"sand":
			# Chão de terra batida: lajotas só onde aflora a pedra; o resto é areia.
			var buried := wear < .58
			if buried:
				var warm := smoothstep(.35, .75, patch)
				color = "tan" if warm > _cluster(x, y) else "sand_dark"
				# Marcas de vento só em parte da praça, em duas direções e em traços
				# curtos. Os coeficientes × PERIOD dão inteiros, então fecham na emenda.
				var wind := _noise(g.x + .5, g.y - .5, 2.0, 71)
				var dash := _hash(posmod(floori(g.x * 4.0), PERIOD * 4), posmod(floori(g.y * 4.0), PERIOD * 4), 77)
				if wind > .5 and dash > .25:
					var turn := _noise(g.x, g.y, 4.0, 73)
					var ripple := fposmod(g.x * 2.25 + g.y * .75 + patch * 1.2, 1.0) if turn < .5 else fposmod(g.x * .5 + g.y * 2.0 - patch * 1.2, 1.0)
					if ripple < .06:
						color = "wood_light"
					elif ripple > .93 and ripple < .97:
						color = "sand"
			if speck < .012:
				color = "wood_dark" if speck < .006 else "stone_light"
		"arena":
			# Lajes de calcário gastas pelas lutas: marcas de arrasto e poeira cinza,
			# em pontilhado, sem marrom (a cor do Porteiro).
			if wear > .66 and smoothstep(.66, .9, wear) * .55 > _cluster(x, y) and edge == "inner":
				color = "sage"
			var scuff := fposmod(g.x * 1.7 - g.y * 2.3 + patch * 2.0, 1.0)
			if edge == "inner" and patch > .6 and scuff < .05:
				color = "stone"
		"wood":
			if edge == "inner":
				var grain := fposmod(g.x * 16.0 + _hash(id, 3, 5) * 9.0 + sin(g.y * 5.0 + _hash(id, 4, 5) * 6.0) * .25, 1.0)
				if grain < .08:
					color = "wood_dark"
				elif grain > .9 and grain < .95:
					color = "tan"
			# Pregos nas pontas das tábuas.
			var along := fposmod(g.y + (float(style["stagger"]) * float(style["len"]) if posmod(floori(g.x / float(style["row"])), 2) == 1 else 0.0), float(style["len"]))
			var across := fposmod(g.x, float(style["row"]))
			if (along < .06 or along > float(style["len"]) - .06) and absf(across - float(style["row"]) * .5) < .03 and edge == "inner":
				color = "charcoal"
		"mosaic":
			# Rosácea verde-azulada e dourada a cada 4 tiles, como as faixas dos templos.
			var cx := absf(fposmod(g.x, 4.0) - 2.0)
			var cy := absf(fposmod(g.y, 4.0) - 2.0)
			var r := maxf(cx, cy)
			if r < .1:
				color = "gold"
			elif r < .22:
				color = "teal"
			elif r < .28:
				color = "gold_dark"
			elif r < .36 and edge != "joint":
				color = "teal_light" if r < .32 else "teal"
			# Faixa de pequenas pedras alternadas a cada 4 fiadas.
			var band := fposmod(g.y, 4.0)
			if band < .16 and edge != "joint":
				color = "teal" if posmod(floori(g.x * 4.0), 2) == 0 else "gold_dark"
		"garden":
			# Lajotas faltando viram terra com capim: a lajota inteira some, então o
			# trecho de terra segue o contorno das lajotas em volta (nada de oval). A
			# terra é mais clara que qualquer sombra, para não ler como buraco.
			if wear > .7 and _hash(id, 31, 6) < smoothstep(.7, .88, wear):
				color = "tan" if _hash(floori(x / 2.0), floori(y / 2.0), 67) > .55 else "wood_light"
				# Folhinhas de capim: dois pixels em pé, esparsas.
				var blade := _hash(posmod(x, SIZE.x), posmod(floori(y / 2.0), SIZE.y), 61)
				if blade > .9:
					color = "olive_light" if posmod(y, 2) == 0 else "olive"
				return color
			elif edge == "joint" and patch > .45:
				color = "jade" if patch > .7 else "olive"
			elif patch > .74 and smoothstep(.74, .9, patch) > _cluster(x, y):
				color = "olive_dark" if edge == "inner" else color
		"crypt":
			# Marcas gravadas em poucas lajes e poeira de areia trazida pelos passos.
			var mark := _hash(id, 11, 3)
			# A laje tem dois tiles; a marca fica só num deles, senão sai em par.
			if mark < .1 and edge == "inner" and posmod(floori(g.x), 2) == 0:
				var local := Vector2(fposmod(g.x, 1.0), fposmod(g.y, 1.0))
				var glyph := int(mark * 40.0) % 4
				var hit := false
				match glyph:
					0: hit = absf(local.x - .5) < .03 and absf(local.y - .5) < .22
					1: hit = absf(local.y - .5) < .03 and absf(local.x - .5) < .22
					2: hit = absf(local.distance_to(Vector2(.5, .5)) - .16) < .03
					3: hit = absf(local.x - local.y) < .04 and absf(local.x - .5) < .2
				if hit:
					color = "slate"
			if wear > .7 and smoothstep(.7, .9, wear) * .5 > _cluster(x, y) and edge == "inner":
				color = "stone"
		"aqueduct":
			# Canaleta d'água a cada 4 tiles, com reflexo; lajes molhadas mais escuras.
			var channel := fposmod(g.y, 4.0)
			if channel < .2:
				color = "teal" if channel > .04 and channel < .16 else "teal_dark"
				if channel > .06 and channel < .1 and fposmod(g.x * 3.0, 1.0) < .35:
					color = "teal_light"
			elif wear > .65 and edge == "inner":
				color = "stone" if color == "sage" else "sea"
		"stone":
			# Areia acumulada nas juntas e manchas de desgaste.
			if edge == "joint" and wear > .6:
				color = "sand_dark"
			elif wear > .7 and smoothstep(.7, .92, wear) * .45 > _cluster(x, y) and edge == "inner":
				color = "tan"
	# Rachaduras em poucas lajotas.
	if edge == "inner" and theme not in ["sand", "arena", "wood"] and _hash(id, 19, 2) < .08:
		var local := Vector2(fposmod(g.x * 2.0, 1.0), fposmod(g.y * 2.0, 1.0))
		var slope := _hash(id, 23, 4) * 2.0 - 1.0
		if absf(local.y - (.5 + slope * (local.x - .5))) < .035 and local.x > .2 and local.x < .8:
			color = style["joint"]
	# Grão da pedra: um ponto claro ou escuro aqui e ali, sem virar ruído.
	if edge == "inner" and theme not in ["sand", "arena"]:
		if speck > .985:
			color = style["light"]
		elif speck < .02:
			color = style["shade"]
	return color


# --- Paredões ---------------------------------------------------------------------

## Face de pedra: capa clara, duas fiadas de blocos desencontrados e a faixa molhada
## com limo perto d'água (a profundidade usada é 20 px; o resto fica escuro).
func _face_stone() -> Image:
	var image := Image.create_empty(FACE_SIZE.x, FACE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(FACE_SIZE.y):
		for x in range(FACE_SIZE.x):
			var color := "olive_dark"
			if y == 0:
				color = "olive_light"
			elif y == 1:
				color = "olive"
			elif y == 2 or y == 9 or y == 16:
				color = "umber"
			elif y < 16:
				var course := 0 if y < 9 else 1
				var offset := 0 if course == 0 else 9
				var block := floori(float(x + offset) / 18.0)
				var local := posmod(x + offset, 18)
				if local == 0:
					color = "umber"
				else:
					var tone := _hash(posmod(block, FACE_SIZE.x / 18 + 1), course, 41)
					color = "olive" if tone < .45 else ("olive_dark" if tone < .85 else "stone_light")
					if y == 3 or y == 10:
						color = "olive_light" if tone < .7 else "olive"
					elif y == 8 or y == 15:
						color = "wood_dark"
					elif _hash(x, y, 5) > .97:
						color = "tan"
			elif y < 20:
				color = "teal_dark" if y > 17 else "slate"
				if _hash(x, y, 9) > .82:
					color = "jade" if y < 19 else "teal"
			else:
				color = "night"
			image.set_pixel(x, y, Color(PAL[color]))
	return image


## Face de madeira dos píeres: a viga de borda com veios e a sombra por baixo
## (profundidade 11 px). As estacas continuam desenhadas pelo layout.
func _face_wood() -> Image:
	var image := Image.create_empty(FACE_SIZE.x, FACE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(FACE_SIZE.y):
		for x in range(FACE_SIZE.x):
			var color := "wood_dark"
			if y == 0:
				color = "tan"
			elif y < 6:
				color = "wood" if _hash(floori(x / 32.0), y, 3) < .6 else "wood_light"
				if fposmod(x * .37 + y * 1.7, 5.0) < .5:
					color = "wood_dark"
				if posmod(x, 32) == 0:
					color = "umber"
				elif posmod(x, 32) == 2 and y == 3:
					color = "charcoal"
			elif y == 6:
				color = "umber"
			elif y < 11:
				color = "wood_dark" if _hash(x, y, 7) < .85 else "wood"
			else:
				color = "night"
			image.set_pixel(x, y, Color(PAL[color]))
	return image


# --- Arquivos -------------------------------------------------------------------

func _write_pxo(path: String, frames: Array[Image], size: Vector2i, names: Array, layer: String) -> void:
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
		_zip_file(zip, "image_data/frames/%d/layer_1" % (index + 1), frames[index].get_data())
	_zip_file(zip, "preview.png", frames[0].save_png_to_buffer())
	zip.close()


func _zip_file(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()


## Recortes de 160×80 de cada tema, ampliados 3×, para conferir de perto.
func _write_preview() -> void:
	var sheet := Image.create_empty(160 * 4 + 30, 80 * 2 + 10, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("0b1a1f"))
	for index in range(_frames.size()):
		sheet.blit_rect(_frames[index], Rect2i(40, 40, 160, 80), Vector2i((index % 4) * 170, (index / 4) * 90))
	sheet.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	sheet.save_png("res://qa/ground_v8_preview.png")
