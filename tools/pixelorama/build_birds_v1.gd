extends SceneTree

## Aves do Porto (O Nono Véu): folha de pixel art gerada proceduralmente.
## 4 espécies: Papagaio Esmeralda, Gaivota do Porto, Falcão de Hórus e Garça do Bennu.
## 5 poses: perch_idle, perch_look, fly_down, fly_glide, fly_up.
##
## Execução:
## & "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/pixelorama/build_birds_v1.gd -- --preview

const CELL := Vector2i(32, 32)
const PIVOT := Vector2i(16, 20)
const OUT := "res://assets/world/birds_v1.png"
const MANIFEST := "res://assets/world/birds_v1_manifest.json"

const POSES := ["perch_idle", "perch_look", "fly_down", "fly_glide", "fly_up"]

const PAL := {
	"ink": "14252c", "night": "1e343a",
	# Papagaio Esmeralda Refinado (Periquito Alexandrino de Colar)
	"parrot_base": "29965a", "parrot_light": "4fd18b", "parrot_dark": "186638",
	"parrot_tail": "c43737", "parrot_tail_dark": "8e2222", "parrot_wing_tip": "1b4d8f",
	"parrot_ruby": "bf2e39", "parrot_cobalt": "226bc2", "parrot_collar": "e85d77", "parrot_collar_dark": "241b21",
	"parrot_beak": "e89525", "parrot_beak_light": "f7ba4a", "parrot_iris": "fce458",
	# Gaivota do Porto
	"gull_white": "f2f5f7", "gull_shade": "c8d0d8", "gull_wing": "5d6775", "gull_wing_dark": "303844",
	"gull_beak": "ea9423", "gull_leg": "db8e35",
	# Falcão de Hórus
	"falcon_brown": "684322", "falcon_dark": "3e2612", "falcon_light": "996a3d",
	"falcon_belly": "dac6a7", "falcon_belly_shade": "ad9574", "falcon_beak": "2b2622", "falcon_eye_ring": "e5b33d",
	# Garça do Bennu
	"heron_white": "edece6", "heron_shade": "b5b5ab", "heron_black": "1d2024",
	"heron_beak": "947444", "heron_leg": "524330",
	# Comuns
	"eye_black": "10161a", "eye_white": "ffffff"
}

const SPECIES := [
	{
		"id": "parrot",
		"name": "Papagaio Esmeralda",
		"size": 1.0,
		"tail_len": 9,
		"beak_type": "hook_short"
	},
	{
		"id": "seagull",
		"name": "Gaivota do Porto",
		"size": 1.1,
		"tail_len": 5,
		"beak_type": "straight"
	},
	{
		"id": "falcon",
		"name": "Falcão de Hórus",
		"size": 1.2,
		"tail_len": 7,
		"beak_type": "hook_sharp"
	},
	{
		"id": "heron",
		"name": "Garça do Bennu",
		"size": 1.3,
		"tail_len": 6,
		"beak_type": "long_slender"
	}
]

var _img: Image
var _sp: Dictionary


func _init() -> void:
	var sheet := Image.create(CELL.x * POSES.size(), CELL.y * SPECIES.size(), false, Image.FORMAT_RGBA8)
	for row in range(SPECIES.size()):
		_sp = SPECIES[row]
		for col in range(POSES.size()):
			_img = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			_draw_bird(POSES[col])
			_outline()
			sheet.blit_rect(_img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))

	sheet.save_png(ProjectSettings.globalize_path(OUT))

	var sp_ids: Array = []
	for s in SPECIES: sp_ids.append(s["id"])
	var manifest := {
		"version": 1,
		"texture": OUT,
		"cell": [CELL.x, CELL.y],
		"pivot": [PIVOT.x, PIVOT.y],
		"poses": POSES,
		"species": sp_ids,
		"source": "res://tools/pixelorama/build_birds_v1.gd"
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()

	if "--preview" in OS.get_cmdline_user_args():
		var preview := sheet.duplicate() as Image
		preview.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
		preview.save_png(ProjectSettings.globalize_path("res://qa/birds_v1_preview.png"))

	print("BIRDS_V1 species=%d poses=%d sheet=%s" % [SPECIES.size(), POSES.size(), ProjectSettings.globalize_path(OUT)])
	quit()


func _draw_bird(pose: String) -> void:
	match pose:
		"perch_idle":
			_perch(false)
		"perch_look":
			_perch(true)
		"fly_down":
			_fly(-1)
		"fly_glide":
			_fly(0)
		"fly_up":
			_fly(1)


func _perch(look_up: bool) -> void:
	var sp_id: String = _sp["id"]
	if sp_id == "heron":
		_perch_heron(look_up)
		return
	var head_y := -6 if not look_up else -8
	var head_x := 4 if not look_up else 3

	# Pernas/Pés no poleiro
	var leg_color := "heron_leg" if sp_id == "heron" else ("gull_leg" if sp_id == "seagull" else "parrot_beak")
	_px(-1, 0, leg_color)
	_px(0, 0, leg_color)
	_px(1, 0, leg_color)
	_px(2, 0, leg_color)

	# Cauda
	var tail_color := "parrot_tail" if sp_id == "parrot" else (
		"heron_black" if sp_id == "heron" else (
			"falcon_dark" if sp_id == "falcon" else "gull_wing_dark"
		)
	)
	var tail_len: int = _sp["tail_len"]
	for t in range(tail_len):
		_px(-3 - t, -1 + t / 2, tail_color)
		if sp_id == "parrot":
			_px(-3 - t, -2 + t / 2, "parrot_tail_dark")

	# Corpo
	var body_color := _color_body()
	var shade_color := _color_shade()
	var wing_color := _color_wing()

	# Base do torso
	_rect(-2, -5, 6, 4, body_color)
	_rect(-1, -6, 5, 5, body_color)
	_rect(-3, -4, 2, 3, shade_color)
	_rect(-1, -2, 4, 1, shade_color)

	# Asa dobrada na lateral
	_rect(-3, -6, 5, 4, wing_color)
	_rect(-4, -5, 2, 2, _color_wing_shade())
	if sp_id == "parrot":
		_px(-1, -6, "parrot_ruby") # Mancha rubi no ombro
		_px(0, -6, "parrot_ruby")
		_px(-4, -4, "parrot_cobalt") # Penas de voo azuis na ponta
	else:
		_px(-4, -4, _color_wing_shade())

	# Pescoço & Cabeça
	if sp_id == "heron":
		# Garça tem pescoço longo em S
		_rect(2, head_y + 1, 2, 4, body_color)
		_px(1, head_y + 2, shade_color)
	elif sp_id == "parrot":
		# Colar rosado e preto do periquito alexandrino
		_px(head_x - 1, head_y + 1, "parrot_collar_dark")
		_px(head_x, head_y + 1, "parrot_collar")

	_rect(head_x - 1, head_y - 2, 4, 4, body_color)
	_px(head_x + 2, head_y - 1, body_color)

	# Bico
	_draw_beak(head_x, head_y, look_up)

	# Olho
	_px(head_x + 1, head_y - 1, "eye_black")
	if sp_id == "falcon":
		_px(head_x + 1, head_y - 2, "falcon_eye_ring")
		_px(head_x, head_y - 1, "falcon_eye_ring")
	elif sp_id == "parrot":
		_px(head_x, head_y - 1, "parrot_iris") # Íris dourada
		_px(head_x + 1, head_y - 2, "parrot_light")


## Garça em pé: pernas longas, corpo alto, pescoço em S e bico comprido. Os pés
## ficam no pivô, como nas outras aves, e ela cabe nos 20 px acima dele.
func _perch_heron(look_up: bool) -> void:
	# Pernas finas
	for y in range(-6, 1):
		_px(0, y, "heron_leg")
		_px(2, y, "heron_leg")
	_px(-1, 0, "heron_leg")
	_px(3, 0, "heron_leg")
	# Cauda escura e pontas das asas
	_rect(-6, -9, 2, 2, "heron_black")
	_px(-7, -8, "heron_black")
	# Corpo
	_rect(-4, -11, 7, 4, "heron_white")
	_rect(-3, -12, 5, 1, "heron_white")
	_rect(-4, -8, 6, 1, "heron_shade")
	# Asa dobrada
	_rect(-4, -11, 4, 3, "heron_shade")
	_px(-5, -10, "heron_black")
	# Pescoço em S (esticado quando olha para cima)
	var neck := [Vector2i(2, -13), Vector2i(3, -14), Vector2i(3, -15), Vector2i(2, -16)] if not look_up else [Vector2i(2, -13), Vector2i(3, -14), Vector2i(4, -15), Vector2i(4, -16)]
	for point: Vector2i in neck:
		_px(point.x, point.y, "heron_white")
		_px(point.x + 1, point.y, "heron_shade" if point.y < -14 else "heron_white")
	# Olhando: cabeça adiante e mais alta, sem sair da célula.
	var head := Vector2i(3, -17) if not look_up else Vector2i(5, -18)
	_rect(head.x - 1, head.y - 1, 3, 2, "heron_white")
	# Penacho escuro na nuca
	_px(head.x - 2, head.y - 1, "heron_black")
	_px(head.x - 3, head.y, "heron_black")
	# Olho e bico longo
	_px(head.x, head.y - 1, "eye_black")
	for x in range(head.x + 2, head.x + 6):
		_px(x, head.y, "heron_beak")


func _fly(wing_state: int) -> void:
	# wing_state: -1 (down), 0 (glide), 1 (up)
	var sp_id: String = _sp["id"]
	var body_color := _color_body()
	var shade_color := _color_shade()
	var wing_color := _color_wing()
	var wing_shade := _color_wing_shade()

	# Cauda na horizontal/aerodinâmica
	var tail_color := "parrot_tail" if sp_id == "parrot" else (
		"heron_black" if sp_id == "heron" else (
			"falcon_dark" if sp_id == "falcon" else "gull_wing_dark"
		)
	)
	var tail_len: int = _sp["tail_len"]
	for t in range(tail_len):
		_px(-4 - t, 0, tail_color)
		if t < tail_len - 1:
			_px(-4 - t, -1, tail_color)

	# A garça voa com as pernas esticadas para trás, além da cauda.
	if sp_id == "heron":
		for x in range(-4 - tail_len - 5, -4 - tail_len + 1):
			_px(x, 1, "heron_leg")

	# Torso fusiforme horizontal
	_rect(-3, -2, 8, 4, body_color)
	_rect(-4, -1, 9, 2, body_color)
	_rect(-2, 1, 6, 1, shade_color)

	# Cabeça na ponta frontal
	var head_x := 5
	var head_y := -1
	_rect(head_x, head_y - 1, 3, 3, body_color)
	_px(head_x + 1, head_y - 1, "eye_black")

	# Bico de voo
	_draw_beak_flight(head_x + 2, head_y)

	# Asas dependendo do estado (-1 down, 0 glide, 1 up)
	match wing_state:
		-1: # Downstroke
			# Asa de lá (topo inclinado para baixo)
			_thick(Vector2(-1, -2), Vector2(1, 4), wing_shade)
			_line(Vector2(1, 4), Vector2(3, 7), wing_shade)
			# Asa de cá (frente, batendo para baixo)
			_thick(Vector2(0, -1), Vector2(2, 5), wing_color)
			_thick(Vector2(2, 5), Vector2(4, 9), wing_color)
			_thick(Vector2(4, 9), Vector2(6, 11), _color_wing_tip())
		0: # Glide (horizontal estendida)
			# Asa de lá
			_rect(-3, -6, 7, 3, wing_shade)
			_rect(-5, -8, 5, 3, wing_shade)
			_px(-6, -9, _color_wing_tip())
			# Asa de cá (aberta em perfil)
			_rect(-2, -3, 8, 3, wing_color)
			_rect(-4, -5, 6, 3, wing_color)
			_rect(-6, -6, 4, 2, _color_wing_tip())
		1: # Upstroke (asas erguidas em V)
			# Asa de lá (mais alta e escura)
			_thick(Vector2(-2, -3), Vector2(-1, -9), wing_shade)
			_thick(Vector2(-1, -9), Vector2(1, -13), wing_shade)
			_line(Vector2(1, -13), Vector2(3, -15), _color_wing_tip())
			# Asa de cá (erguida para cima)
			_thick(Vector2(-1, -2), Vector2(1, -7), wing_color)
			_thick(Vector2(1, -7), Vector2(3, -11), wing_color)
			_line(Vector2(3, -11), Vector2(5, -13), _color_wing_tip())


func _draw_beak(head_x: int, head_y: int, look_up: bool) -> void:
	var sp_id: String = _sp["id"]
	var by := head_y if not look_up else head_y - 1
	match sp_id:
		"parrot":
			_px(head_x + 3, by, "parrot_beak_light")
			_px(head_x + 3, by + 1, "parrot_beak")
			_px(head_x + 2, by + 1, "parrot_beak")
		"seagull":
			_px(head_x + 3, by, "gull_beak")
			_px(head_x + 4, by, "gull_beak")
			_px(head_x + 4, by + 1, "gull_leg") # Ponto vermelho/laranja na ponta do bico da gaivota
		"falcon":
			_px(head_x + 3, by, "falcon_beak")
			_px(head_x + 3, by + 1, "falcon_beak")
		"heron":
			_px(head_x + 3, by, "heron_beak")
			_px(head_x + 4, by, "heron_beak")
			_px(head_x + 5, by, "heron_beak")


func _draw_beak_flight(bx: int, by: int) -> void:
	var sp_id: String = _sp["id"]
	match sp_id:
		"parrot":
			_px(bx + 1, by, "parrot_beak_light")
			_px(bx + 1, by + 1, "parrot_beak")
		"seagull":
			_px(bx + 1, by, "gull_beak")
			_px(bx + 2, by, "gull_beak")
		"falcon":
			_px(bx + 1, by, "falcon_beak")
			_px(bx + 1, by + 1, "falcon_beak")
		"heron":
			_px(bx + 1, by, "heron_beak")
			_px(bx + 2, by, "heron_beak")
			_px(bx + 3, by, "heron_beak")


func _color_body() -> String:
	match _sp["id"]:
		"parrot": return "parrot_base"
		"seagull": return "gull_white"
		"falcon": return "falcon_belly"
		"heron": return "heron_white"
	return "parrot_base"


func _color_shade() -> String:
	match _sp["id"]:
		"parrot": return "parrot_dark"
		"seagull": return "gull_shade"
		"falcon": return "falcon_belly_shade"
		"heron": return "heron_shade"
	return "parrot_dark"


func _color_wing() -> String:
	match _sp["id"]:
		"parrot": return "parrot_light"
		"seagull": return "gull_wing"
		"falcon": return "falcon_brown"
		"heron": return "heron_shade"
	return "parrot_light"


func _color_wing_shade() -> String:
	match _sp["id"]:
		"parrot": return "parrot_dark"
		"seagull": return "gull_wing_dark"
		"falcon": return "falcon_dark"
		"heron": return "heron_black"
	return "parrot_dark"


func _color_wing_tip() -> String:
	match _sp["id"]:
		"parrot": return "parrot_wing_tip"
		"seagull": return "gull_wing_dark"
		"falcon": return "falcon_dark"
		"heron": return "heron_black"
	return "ink"


func _outline() -> void:
	var source := _img.duplicate() as Image
	for y in range(CELL.y):
		for x in range(CELL.x):
			if source.get_pixel(x, y).a > 0: continue
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor: Vector2i = Vector2i(x, y) + dir
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < CELL.x and neighbor.y < CELL.y and source.get_pixelv(neighbor).a > 0:
					_img.set_pixel(x, y, Color(PAL["ink"]))
					break


func _px(x: int, y: int, color: String) -> void:
	var point := PIVOT + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < CELL.x and point.y < CELL.y:
		_img.set_pixelv(point, Color(PAL[color]))


func _rect(x: int, y: int, w: int, h: int, color: String) -> void:
	for row in range(h):
		for column in range(w):
			_px(x + column, y + row, color)


func _line(a: Vector2, b: Vector2, color: String) -> void:
	var from := Vector2i(roundi(a.x), roundi(a.y))
	var to := Vector2i(roundi(b.x), roundi(b.y))
	var delta := Vector2i(absi(to.x - from.x), -absi(to.y - from.y))
	var step := Vector2i(1 if from.x < to.x else -1, 1 if from.y < to.y else -1)
	var error := delta.x + delta.y
	while true:
		_px(from.x, from.y, color)
		if from == to: break
		var twice := 2 * error
		if twice >= delta.y:
			error += delta.y
			from.x += step.x
		if twice <= delta.x:
			error += delta.x
			from.y += step.y


func _thick(a: Vector2, b: Vector2, color: String) -> void:
	_line(a, b, color)
	_line(a + Vector2(1, 0), b + Vector2(1, 0), color)
