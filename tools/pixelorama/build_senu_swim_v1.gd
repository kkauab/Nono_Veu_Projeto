extends SceneTree

## Senu nadando v1 (docs/MUNDO_BARCO_ILHA.md, "Mergulho"): poses do Senu real, do
## mesmo jeito das poses do barco (build_senu_boat_v2.py). O corpo vem do quadro
## parado de senu_shared_v6 nas 8 direções, reduzido uma vez à escala do mundo
## (.26, 100×100) e articulado em pedaços; os braços são desenhados com o contorno
## e a pele dos braços do remo. Nada é espremido nem girado por ângulo quebrado:
## o corpo deitado do mergulho é o giro exato de 90° da vista de perfil.
##
## Dois ciclos de 6 quadros por direção, no canvas 96×96 do barco:
## - "surface": cabeça e ombros acima da linha d'água (o pivô 48,76 é a linha
##   d'água), braçada de peito na superfície;
## - "dive": embaixo d'água; nas direções laterais o corpo deitado com as pernas
##   batendo, para cima e para baixo o corpo de pé com a pernada; braçada de peito.
##
## Saída: art/pixelorama/senu/swim_v1/senu_swim_v1.pxo (96 quadros com tags) e
## assets/sprites/senu_swim_v1.png com o manifesto, no formato do senu_boat_v2.
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_senu_swim_v1.gd
## Opcional: -- --preview grava qa/senu_swim_v1_preview.png (4×, sobre a água).

const DIRS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const SOURCE := "res://assets/sprites/senu_shared_v6.png"
const SOURCE_META := "res://assets/sprites/senu_shared_v6_manifest.json"
const OUT_DIR := "res://art/pixelorama/senu/swim_v1"
const ASSET := "res://assets/sprites/senu_swim_v1.png"
const MANIFEST := "res://assets/sprites/senu_swim_v1_manifest.json"
const CANVAS := 96
const PIVOT := Vector2i(48, 76)
const FRAMES := 6
const COLUMNS := 8
## Linhas da vista de 100×100: topo da cabeça ~33, ombros ~43, cintura ~55, pés ~73.
const TOP := 28
const SHOULDER := 43
const WATERLINE := 46
const HIP := 57
const FEET := 74
const INK := "18262b"
const SKIN := "bd895c"
const SKIN_LIGHT := "d9ac76"
const ARM := "875735"
const CUFF := "c39e65"
## Braçada de peito, quadro a quadro: quanto a mão vai à frente e para o lado.
const REACH := [3.0, 8.0, 12.0, 9.0, 4.0, 1.0]
const SPREAD := [2.5, 2.5, 3.5, 8.0, 8.0, 5.0]
const BOB := [0, 1, 1, 0, -1, 0]
## Pernada: deslocamento de cada perna, em quadros alternados.
const KICK := [0, 1, 2, 1, 0, -1]

var _views: Dictionary = {}


func _init() -> void:
	_load_views()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var frames: Array[Image] = []
	var names: Array = []
	var sprites := {}
	for mode in ["surface", "dive"]:
		for direction in DIRS:
			var clip: Array = []
			for step in range(FRAMES):
				clip.append(frames.size())
				frames.append(_surface(direction, step) if mode == "surface" else _dive(direction, step))
			sprites[mode + "_" + direction] = {"frames": clip}
			names.append(mode + "_" + direction)
	var rows := ceili(frames.size() / float(COLUMNS))
	var sheet := Image.create_empty(CANVAS * COLUMNS, CANVAS * rows, false, Image.FORMAT_RGBA8)
	for index in range(frames.size()):
		sheet.blit_rect(frames[index], Rect2i(0, 0, CANVAS, CANVAS), Vector2i((index % COLUMNS) * CANVAS, (index / COLUMNS) * CANVAS))
	sheet.save_png(ASSET)
	_write_pxo(OUT_DIR + "/senu_swim_v1.pxo", frames, names)
	var manifest := {
		"version": 1, "texture": ASSET, "columns": COLUMNS, "canvas": [CANVAS, CANVAS], "pivot": [PIVOT.x, PIVOT.y],
		"game_scale": 1.0, "frame_count": frames.size(), "frames_per_clip": FRAMES, "directions": DIRS, "sprites": sprites,
		"source": OUT_DIR + "/senu_swim_v1.pxo", "body_source": SOURCE,
		"note": "surface: o pivô é a linha d'água. dive: o pivô é o ponto do leito sob Senu; o corpo flutua acima dele."
	}
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	if "--preview" in OS.get_cmdline_user_args():
		_preview(frames)
	print("SENU_SWIM_V1 quadros=%d folha=%s" % [frames.size(), sheet.get_size()])
	quit()


## O quadro parado de cada direção, reduzido uma vez à escala do mundo, com o
## alfa limpo (como no barco v2).
func _load_views() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_META))
	var atlas := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	for direction in DIRS:
		var frame := int(meta["clips"]["idle"]["directions"][direction][0])
		var r: Array = meta["frame_regions"][frame]
		var view := atlas.get_region(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		view.convert(Image.FORMAT_RGBA8)
		view.resize(100, 100, Image.INTERPOLATE_NEAREST)
		for y in range(100):
			for x in range(100):
				var color := view.get_pixel(x, y)
				color.a = 1.0 if color.a >= 96.0 / 255.0 else 0.0
				view.set_pixel(x, y, color)
		_views[direction] = view


# --- Direção ------------------------------------------------------------------------

## Frente e lado no plano da água, já achatados como o chão isométrico.
func _axes(direction: String) -> Array:
	var index := DIRS.find(direction)
	var angle := index * PI / 4.0
	var world := Vector2(cos(angle), sin(angle))
	var side := Vector2(-world.y, world.x)
	return [Vector2(world.x, world.y * .5), Vector2(side.x, side.y * .5)]


# --- Superfície ---------------------------------------------------------------------

func _surface(direction: String, step: int) -> Image:
	var image := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var view: Image = _views[direction]
	var bob: int = BOB[step]
	# Cabeça e ombros: da linha TOP até a linha d'água, com a linha d'água no pivô.
	var body := view.get_region(Rect2i(25, TOP, 50, WATERLINE - TOP))
	var origin := Vector2i(PIVOT.x - 25, PIVOT.y - (WATERLINE - TOP) + bob)
	var shoulder := Vector2(PIVOT.x, PIVOT.y - (WATERLINE - SHOULDER) + bob)
	_with_arms(image, body, origin, shoulder, direction, step, 1.0)
	return image


## Desenha o corpo e os dois braços na ordem certa: o braço do lado da câmera por
## cima do corpo, o outro por baixo; nadando para longe, os dois ficam atrás.
func _with_arms(image: Image, body: Image, origin: Vector2i, shoulder: Vector2, direction: String, step: int, scale: float, wide: float = 1.0) -> void:
	var axes := _axes(direction)
	var forward: Vector2 = axes[0]
	var side: Vector2 = axes[1]
	var arms := []
	for sign: float in [-1.0, 1.0]:
		var root: Vector2 = shoulder + side * 4.5 * sign
		var hand: Vector2 = shoulder + forward * float(REACH[step]) * scale + side * float(SPREAD[step]) * scale * wide * sign
		var near: bool = (side * sign).y > .05 or (absf(side.y) <= .05 and sign > 0.0)
		var behind: bool = forward.y < -.05 or not near
		arms.append([root, hand, sign, behind])
	for arm: Array in arms:
		if arm[3]:
			_arm(image, arm[0], arm[1], side * arm[2])
	image.blend_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), origin)
	for arm: Array in arms:
		if not arm[3]:
			_arm(image, arm[0], arm[1], side * arm[2])


## Braço dobrado com contorno, como o do remo: ombro, cotovelo para fora, mão.
func _arm(image: Image, root: Vector2, hand: Vector2, outward: Vector2) -> void:
	var elbow := (root + hand) * .5 + outward.normalized() * 1.5 + Vector2(0, 1)
	for pair in [[root, elbow], [elbow, hand]]:
		_thick(image, pair[0], pair[1], INK, 1)
	for pair in [[root, elbow], [elbow, hand]]:
		_thick(image, pair[0], pair[1], ARM, 0)
		_line(image, Vector2i(pair[0].round()) + Vector2i(0, -1), Vector2i(pair[1].round()) + Vector2i(0, -1), SKIN)
	_line(image, Vector2i(elbow.round()), Vector2i(hand.round()), SKIN_LIGHT)
	var cuff := Vector2i((elbow * .3 + hand * .7).round())
	_px(image, cuff.x, cuff.y, CUFF)
	var grip := Vector2i(hand.round())
	for y in range(-1, 1):
		for x in range(-1, 2):
			_px(image, grip.x + x, grip.y + y, SKIN)
	_px(image, grip.x, grip.y - 1, SKIN_LIGHT)


# --- Mergulho -----------------------------------------------------------------------

func _dive(direction: String, step: int) -> Image:
	if direction in ["up", "down"]:
		return _dive_upright(direction, step)
	var lying := _dive_lying("right", step)
	if direction in ["left", "down_left", "up_left"]:
		lying.flip_x()
	return lying


## Para cima e para baixo: o corpo de pé, flutuando, com a pernada de peito (as
## pernas abrem para os lados e fecham) e os braços varrendo para os lados, que é
## o que se vê de frente ou de costas.
func _dive_upright(direction: String, step: int) -> Image:
	var image := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var view: Image = _views[direction]
	var lift: int = 8 + int(BOB[step])
	var body := Image.create_empty(60, FEET - TOP + 4, false, Image.FORMAT_RGBA8)
	body.blit_rect(view, Rect2i(25, TOP, 50, HIP - TOP), Vector2i(5, 0))
	var open: int = KICK[step] + 1
	for half in [[25, 50, -open], [50, 75, open]]:
		var leg := view.get_region(Rect2i(int(half[0]), HIP, int(half[1]) - int(half[0]), FEET - HIP))
		body.blend_rect(leg, Rect2i(Vector2i.ZERO, leg.get_size()), Vector2i(int(half[0]) - 20 + int(half[2]), HIP - TOP - absi(int(half[2])) / 2 + 1))
	var origin := Vector2i(PIVOT.x - 30, PIVOT.y - lift - (FEET - TOP))
	var shoulder := Vector2(PIVOT.x, origin.y + SHOULDER - TOP - 1)
	_with_arms(image, body, origin, shoulder, direction, step, .7, 1.6)
	return image


## Para os lados: o perfil de Senu girado 90° (a cabeça para a frente), com as
## pernas ondulando da cintura aos pés e a braçada à frente da cabeça.
func _dive_lying(direction: String, step: int) -> Image:
	var image := Image.create_empty(CANVAS, CANVAS, false, Image.FORMAT_RGBA8)
	var view: Image = _views[direction]
	var upright := view.get_region(Rect2i(25, TOP, 50, FEET - TOP + 1))
	upright.rotate_90(CLOCKWISE)
	# Depois do giro: a largura é a altura do corpo (pés à esquerda, cabeça à direita).
	var size := upright.get_size()
	var body := Image.create_empty(size.x + 12, size.y + 6, false, Image.FORMAT_RGBA8)
	var legs := FEET - HIP
	# A capa da vista de perfil ia para trás; girada, ela subiria como um leque.
	# Fica só a parte colada às costas, e uma cauda de pano ondula para trás dos pés.
	# A linha das costas é a mediana do topo do tronco (da cintura ao ombro): a
	# echarpe, perto da cabeça, sobe mais e não pode puxar essa linha.
	var tops: Array[int] = []
	var cape_tones: Array[Color] = []
	for x in range(size.x):
		var top := -1
		for y in range(size.y):
			var color := upright.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if _cape(color):
				cape_tones.append(color)
			elif top < 0:
				top = y
		if x >= legs and x <= FEET - SHOULDER and top >= 0:
			tops.append(top)
	tops.sort()
	var back: int = tops[tops.size() / 2] if not tops.is_empty() else size.y / 2
	cape_tones.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() > b.get_luminance())
	for x in range(size.x):
		var wave := 0
		if x < legs:
			var weight := 1.0 - float(x) / legs
			wave = int(round(sin(step * TAU / FRAMES + x * .45) * 2.0 * weight))
		for y in range(size.y):
			var color := upright.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			if _cape(color) and back - y > 2:
				continue
			var at := Vector2i(x + 12, y + 3 + wave)
			if at.x >= 0 and at.y >= 0 and at.x < body.get_width() and at.y < body.get_height():
				body.set_pixel(at.x, at.y, color)
	if not cape_tones.is_empty():
		var tones := [cape_tones[cape_tones.size() / 5], cape_tones[cape_tones.size() / 2], cape_tones[cape_tones.size() * 4 / 5]]
		var shoulder_x := 12 + FEET - SHOULDER
		for x in range(shoulder_x - 2, 3, -1):
			var trail := float(shoulder_x - x) / float(shoulder_x)
			var ripple := int(round(sin(step * TAU / FRAMES + x * .4) * (.5 + trail * 1.8)))
			var thick := 3 if x > 14 else 2
			for row in range(thick):
				var y := back + 3 - thick + row + ripple
				if y >= 0 and y < body.get_height() and body.get_pixel(x, y).a <= 0.0:
					body.set_pixel(x, y, tones[row + 3 - thick])
	var origin := Vector2i(PIVOT.x - 12 - size.x / 2, PIVOT.y - 20 - size.y / 2 + BOB[step])
	# O ombro, depois do giro, fica a (FEET - SHOULDER) da borda dos pés.
	var shoulder := Vector2(origin.x + 12 + FEET - SHOULDER, origin.y + 3 + size.y / 2.0)
	_with_arms(image, body, origin, shoulder, "right", step, 1.15)
	return image


# --- Desenho --------------------------------------------------------------------------

## Pixel da capa verde-azulada (o mesmo critério do barco v2).
func _cape(color: Color) -> bool:
	return color.b > color.r * 1.05 and color.g > color.r * 1.02


func _px(image: Image, x: int, y: int, color: String) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, Color(color))


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


## Linha com espessura: a mesma reta repetida num quadradinho de raio `radius`.
func _thick(image: Image, from: Vector2, to: Vector2, color: String, radius: int) -> void:
	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			_line(image, Vector2i(from.round()) + Vector2i(x, y), Vector2i(to.round()) + Vector2i(x, y), color)


# --- Arquivos -------------------------------------------------------------------------

func _preview(frames: Array[Image]) -> void:
	var sheet := Image.create_empty(CANVAS * FRAMES, CANVAS * DIRS.size() * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("1e3e44"))
	for index in range(frames.size()):
		var at := Vector2i((index % FRAMES) * CANVAS, (index / FRAMES) * CANVAS)
		if index < DIRS.size() * FRAMES:
			for x in range(CANVAS):
				sheet.set_pixel(at.x + x, at.y + PIVOT.y, Color("7fa59c"))
		sheet.blend_rect(frames[index], Rect2i(0, 0, CANVAS, CANVAS), at)
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	sheet.save_png("res://qa/senu_swim_v1_preview.png")
	# De perto: os ciclos principais, recortados em volta do corpo e ampliados 5×.
	var clips := [0, 2, 6, 8 + 0, 8 + 2, 8 + 6]
	var crop := Rect2i(16, 26, 64, 54)
	var zoom := Image.create_empty(crop.size.x * FRAMES, crop.size.y * clips.size(), false, Image.FORMAT_RGBA8)
	zoom.fill(Color("1e3e44"))
	for row in range(clips.size()):
		for step in range(FRAMES):
			var frame: Image = frames[int(clips[row]) * FRAMES + step]
			var at := Vector2i(step * crop.size.x, row * crop.size.y)
			if clips[row] < 8:
				for x in range(crop.size.x):
					zoom.set_pixel(at.x + x, at.y + PIVOT.y - crop.position.y, Color("7fa59c"))
			zoom.blend_rect(frame, crop, at)
	zoom.resize(zoom.get_width() * 5, zoom.get_height() * 5, Image.INTERPOLATE_NEAREST)
	zoom.save_png("res://qa/senu_swim_v1_zoom.png")


func _write_pxo(path: String, frames: Array[Image], names: Array) -> void:
	var frame_data := []
	for index in range(frames.size()):
		frame_data.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tags := []
	for index in range(names.size()):
		tags.append({"name": names[index], "color": "6db0a4ff", "from": index * FRAMES + 1, "to": index * FRAMES + FRAMES})
	var data := {
		"pixelorama_version": "v1.2.3-stable", "pxo_version": 7,
		"size_x": CANVAS, "size_y": CANVAS, "color_mode": 5,
		"layers": [{"name": "Senu nadando", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}],
		"frames": frame_data, "tags": tags, "fps": 8.0, "current_frame": 0, "current_layer": 0,
		"export_profile": {"orientation": "1", "lines_count": str(COLUMNS), "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}
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
