extends SceneTree

## Animais Terrestres do Porto (O Nono Véu): folha de pixel art gerada proceduralmente.
## 4 raças autênticas: Gato Preto de Bastet, Gato Mau Egípcio, Cão Tesem Real e Cão de Guarda Anúbis.
## 7 poses: sit, sleep, walk_1, walk_2, walk_3, walk_4, react.
##
## Execução:
## & "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/pixelorama/build_animals_v1.gd -- --preview

const CELL := Vector2i(32, 32)
const PIVOT := Vector2i(16, 26)
const OUT := "res://assets/world/animals_v1.png"
const MANIFEST := "res://assets/world/animals_v1_manifest.json"

const POSES := ["sit", "sleep", "walk_1", "walk_2", "walk_3", "walk_4", "react"]

const PAL := {
	"ink": "14252c", "night": "1e343a",
	# Gato de Bastet (Preto sagrado)
	"cat_black_coat": "1c1f24", "cat_black_shade": "101214", "cat_black_light": "333a42",
	"collar_copper": "c26d36", "collar_gold": "e5b842", "eye_amber": "f7b634",
	# Gato Mau Egípcio (Malhado / Ocre)
	"cat_mau_base": "c2995b", "cat_mau_shade": "946e38", "cat_mau_stripe": "543c1c",
	"cat_mau_belly": "dbc193", "eye_emerald": "40bd6d",
	# Cão Tesem Real (Galgo Egípcio)
	"dog_tesem_base": "d1a666", "dog_tesem_shade": "9e753b", "dog_tesem_light": "edd19d",
	"dog_tesem_muzzle": "362b20", "dog_tesem_ear": "c4934d",
	# Cão de Guarda Anúbis (Preto e Dourado)
	"dog_anubis_black": "1e2024", "dog_anubis_shade": "121317", "dog_anubis_tan": "ba8f4e",
	"dog_anubis_collar": "9e3329",
	# Comuns
	"eye_black": "0e1214", "tongue_pink": "e05e73", "nose_dark": "1a1310", "white": "f4f6f8"
}

const BREEDS := [
	{
		"id": "cat_black",
		"name": "Gato de Bastet",
		"type": "cat",
		"scale": Vector2(0.9, 0.9),
		"tail_curl": "up"
	},
	{
		"id": "cat_mau",
		"name": "Gato Mau Egípcio",
		"type": "cat",
		"scale": Vector2(0.9, 0.9),
		"tail_curl": "s_curve"
	},
	{
		"id": "dog_tesem",
		"name": "Cão Tesem Real",
		"type": "dog",
		"scale": Vector2(1.05, 1.05),
		"tail_curl": "ring"
	},
	{
		"id": "dog_guard",
		"name": "Cão de Guarda Anúbis",
		"type": "dog",
		"scale": Vector2(1.15, 1.15),
		"tail_curl": "low"
	}
]

var _img: Image
var _breed: Dictionary


func _init() -> void:
	var sheet := Image.create(CELL.x * POSES.size(), CELL.y * BREEDS.size(), false, Image.FORMAT_RGBA8)
	for row in range(BREEDS.size()):
		_breed = BREEDS[row]
		for col in range(POSES.size()):
			_img = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			_draw_animal(POSES[col])
			_outline()
			sheet.blit_rect(_img, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))

	sheet.save_png(ProjectSettings.globalize_path(OUT))

	var breed_ids: Array = []
	for b in BREEDS: breed_ids.append(b["id"])
	var manifest := {
		"version": 1,
		"texture": OUT,
		"cell": [CELL.x, CELL.y],
		"pivot": [PIVOT.x, PIVOT.y],
		"poses": POSES,
		"breeds": breed_ids,
		"source": "res://tools/pixelorama/build_animals_v1.gd"
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()

	if "--preview" in OS.get_cmdline_user_args():
		var preview := sheet.duplicate() as Image
		preview.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
		preview.save_png(ProjectSettings.globalize_path("res://qa/animals_v1_preview.png"))

	print("ANIMALS_V1 breeds=%d poses=%d sheet=%s" % [BREEDS.size(), POSES.size(), ProjectSettings.globalize_path(OUT)])
	quit()


func _draw_animal(pose: String) -> void:
	var is_cat: bool = _breed["type"] == "cat"
	if is_cat:
		_draw_cat(pose)
	else:
		_draw_dog(pose)


# ==============================================================================
# GATOS (MAU EGÍPCIO / BASTET)
# ==============================================================================

func _draw_cat(pose: String) -> void:
	var base_col: String = _color_main()
	var shade_col: String = _color_shade()
	var eye_col := "eye_amber" if _breed["id"] == "cat_black" else "eye_emerald"

	match pose:
		"sit":
			# Pata e quadril sentados, apoiados no chão (linha 0, a do pivô)
			_rect(-3, -2, 6, 3, shade_col)
			_rect(-4, -6, 7, 5, base_col)
			_rect(-1, -11, 4, 6, base_col)
			# Cabeça
			_rect(1, -14, 5, 4, base_col)
			_px(5, -13, "nose_dark")
			_px(3, -13, eye_col)
			_px(3, -14, eye_col)
			# Orelhas pontudas
			_px(1, -16, base_col)
			_px(1, -15, base_col)
			_px(4, -16, base_col)
			_px(4, -15, base_col)
			# Coleira de cobre
			if _breed["id"] == "cat_black":
				_rect(1, -11, 4, 1, "collar_copper")
				_px(3, -10, "collar_gold")
			# Cauda enrolada na frente
			_line(Vector2(-4, -3), Vector2(-7, -4), shade_col)
			_line(Vector2(-7, -4), Vector2(-8, -8), base_col)
			_px(-7, -9, base_col)

		"sleep":
			# Corpo enrolado em círculo dormindo
			_rect(-5, -4, 10, 4, base_col)
			_rect(-4, -5, 8, 5, base_col)
			_rect(-6, -3, 2, 2, shade_col)
			# Cabeça aninhada
			_rect(3, -3, 4, 3, base_col)
			_px(6, -2, "nose_dark")
			_px(4, -3, shade_col) # Olho fechado
			_px(3, -5, base_col)  # Orelha recolhida
			# Cauda envolvendo o corpo
			_line(Vector2(-5, -1), Vector2(-2, 0), shade_col)
			_line(Vector2(-2, 0), Vector2(3, 0), shade_col)

		"react":
			# Gato arqueado com pelos eriçados
			_rect(-4, -8, 7, 6, base_col)
			_rect(-3, -10, 5, 4, base_col) # Dorso empinado
			# Pernas esticadas rígidas
			_thick(Vector2(-3, -2), Vector2(-4, 0), shade_col)
			_thick(Vector2(2, -2), Vector2(3, 0), base_col)
			# Cabeça abaixada alerta
			_rect(3, -8, 5, 4, base_col)
			_px(7, -7, "nose_dark")
			_px(5, -8, eye_col)
			_px(4, -10, base_col) # Orelha para trás
			# Cauda empinada e eriçada
			_line(Vector2(-4, -8), Vector2(-8, -13), base_col)
			_px(-8, -14, base_col)
			_px(-7, -13, shade_col)

		"walk_1", "walk_2", "walk_3", "walk_4":
			var step_idx: int = int(pose.substr(5)) - 1
			_draw_cat_walk(step_idx, base_col, shade_col, eye_col)


func _draw_cat_walk(step: int, base_col: String, shade_col: String, eye_col: String) -> void:
	# offsets das 4 patas [diant_esq, diant_dir, tras_esq, tras_dir]
	var offsets: Array = [
		[2, -2, -2, 2],
		[0, 0, 0, 0],
		[-2, 2, 2, -2],
		[0, 0, 0, 0]
	][step]

	# Torso horizontal esguio
	_rect(-4, -6, 9, 4, base_col)
	_rect(-5, -5, 10, 3, base_col)
	if _breed["id"] == "cat_mau":
		_px(-2, -6, "cat_mau_stripe")
		_px(1, -6, "cat_mau_stripe")
		_px(0, -5, "cat_mau_stripe")

	# Patas
	_line(Vector2(3, -2), Vector2(3 + offsets[0], 0), base_col)
	_line(Vector2(2, -2), Vector2(2 + offsets[1], 0), shade_col)
	_line(Vector2(-3, -2), Vector2(-3 + offsets[2], 0), base_col)
	_line(Vector2(-4, -2), Vector2(-4 + offsets[3], 0), shade_col)

	# Cabeça à frente
	_rect(4, -9, 4, 4, base_col)
	_px(8, -8, "nose_dark")
	_px(6, -8, eye_col)
	_px(5, -11, base_col) # Orelhas
	_px(7, -11, base_col)

	# Cauda sinuosa atrás
	var tail_lift: int = int([-2, -4, -3, -1][step])
	_line(Vector2(-5, -5), Vector2(-8, -7 + tail_lift), base_col)
	_px(-9, -8 + tail_lift, base_col)


# ==============================================================================
# CÃES (TESEM REAL / ANÚBIS)
# ==============================================================================

func _draw_dog(pose: String) -> void:
	var base_col: String = _color_main()
	var shade_col: String = _color_shade()
	var tan_col := "dog_tesem_light" if _breed["id"] == "dog_tesem" else "dog_anubis_tan"

	match pose:
		"sit":
			# Quadril sentado no chão e peito profundo erguido
			_rect(-4, -4, 7, 4, shade_col)
			_rect(-3, -11, 6, 8, base_col)
			_rect(0, -14, 4, 7, base_col)
			# Pata dianteira apoiada firme
			_line(Vector2(2, -4), Vector2(2, 0), base_col)
			_line(Vector2(3, -4), Vector2(3, 0), base_col)
			# Cabeça erguida com focinho comprido
			_rect(2, -18, 5, 5, base_col)
			_rect(6, -17, 3, 3, tan_col)
			_px(9, -17, "eye_black") # Focinho
			_px(5, -17, "eye_black") # Olho
			# Orelhas triangulares Tesem eretas
			_line(Vector2(2, -18), Vector2(1, -23), base_col)
			_line(Vector2(4, -18), Vector2(3, -23), base_col)
			# Cauda enrolada em anel sobre o dorso
			if _breed["tail_curl"] == "ring":
				_line(Vector2(-4, -6), Vector2(-7, -8), base_col)
				_line(Vector2(-7, -8), Vector2(-6, -12), base_col)
				_px(-5, -12, base_col)
			else:
				_line(Vector2(-4, -6), Vector2(-7, -2), base_col)

		"sleep":
			# Cão deitado descansando com a cabeça entre as patas, encostado no chão
			_rect(-6, -4, 12, 5, base_col)
			_rect(-5, -6, 10, 4, base_col)
			_rect(-3, -7, 6, 2, shade_col)
			# Cabeça apoiada no chão
			_rect(4, -3, 5, 3, base_col)
			_rect(8, -2, 2, 2, tan_col)
			_px(10, -2, "eye_black")
			_px(7, -3, shade_col) # Olho fechado
			# Orelhas descansando para trás
			_line(Vector2(3, -4), Vector2(0, -6), base_col)

		"react":
			# Cão em alerta latindo / cauda empinada
			_rect(-4, -10, 8, 7, base_col)
			_rect(0, -12, 5, 6, base_col)
			# Pernas firmes
			_thick(Vector2(-3, -3), Vector2(-4, 0), shade_col)
			_thick(Vector2(3, -3), Vector2(4, 0), base_col)
			# Cabeça erguida latindo (focinho aberto com língua)
			_rect(3, -17, 5, 5, base_col)
			_rect(7, -17, 4, 3, tan_col)
			_px(11, -17, "eye_black") # Trufa
			_px(9, -15, "tongue_pink") # Língua / boca aberta
			_px(6, -16, "eye_black")
			# Orelhas super empinadas
			_line(Vector2(3, -18), Vector2(2, -24), base_col)
			_line(Vector2(5, -18), Vector2(5, -24), base_col)
			# Cauda ereta
			_line(Vector2(-4, -9), Vector2(-7, -13), base_col)
			_line(Vector2(-7, -13), Vector2(-6, -16), base_col)

		"walk_1", "walk_2", "walk_3", "walk_4":
			var step_idx: int = int(pose.substr(5)) - 1
			_draw_dog_walk(step_idx, base_col, shade_col, tan_col)


func _draw_dog_walk(step: int, base_col: String, shade_col: String, tan_col: String) -> void:
	var offsets: Array = [
		[3, -3, -3, 3],
		[1, -1, -1, 1],
		[-3, 3, 3, -3],
		[-1, 1, 1, -1]
	][step]

	# Torso esguio musculoso
	_rect(-5, -8, 11, 5, base_col)
	_rect(-4, -9, 8, 6, base_col)
	_rect(1, -10, 4, 4, base_col) # Peito proeminente do galgo

	# Pernas longas do Tesem
	_line(Vector2(4, -4), Vector2(4 + offsets[0], 0), base_col)
	_line(Vector2(3, -4), Vector2(3 + offsets[1], 0), shade_col)
	_line(Vector2(-4, -4), Vector2(-4 + offsets[2], 0), base_col)
	_line(Vector2(-5, -4), Vector2(-5 + offsets[3], 0), shade_col)

	# Cabeça erguida à frente
	_rect(5, -13, 5, 5, base_col)
	_rect(9, -12, 3, 3, tan_col)
	_px(12, -12, "eye_black")
	_px(8, -12, "eye_black")
	# Orelhas Tesem
	_line(Vector2(5, -14), Vector2(4, -18), base_col)
	_line(Vector2(7, -14), Vector2(7, -18), base_col)

	# Cauda
	if _breed["tail_curl"] == "ring":
		_line(Vector2(-5, -7), Vector2(-8, -10), base_col)
		_px(-7, -11, base_col)
	else:
		_line(Vector2(-5, -7), Vector2(-8, -5), base_col)


func _color_main() -> String:
	match _breed["id"]:
		"cat_black": return "cat_black_coat"
		"cat_mau": return "cat_mau_base"
		"dog_tesem": return "dog_tesem_base"
		"dog_guard": return "dog_anubis_black"
	return "cat_black_coat"


func _color_shade() -> String:
	match _breed["id"]:
		"cat_black": return "cat_black_shade"
		"cat_mau": return "cat_mau_shade"
		"dog_tesem": return "dog_tesem_shade"
		"dog_guard": return "dog_anubis_shade"
	return "cat_black_shade"


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
		for col in range(w):
			_px(x + col, y + row, color)


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
