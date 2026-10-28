extends SceneTree

## Gera dois projetos nativos do Pixelorama 1.2.3 (formato 7) para o mar e a ilha
## (docs/MUNDO_BARCO_ILHA.md), cada um com seu export_plan.json:
##   art/pixelorama/sea_v1/boat_v1.pxo — o barco de Sabu em 16 direções; em cada
##     direção, Senu parado (quadro 0), remando (quadros 1 a 8) e o barco vazio (9);
##   art/pixelorama/sea_v1/isle_v1.pxo — árvores, rochas, braseiros, o altar,
##     Ankhet, a garça, a rede e a ânfora da Ilha do Bennu.
## Os PNG do jogo são exportados pelo próprio Pixelorama (tools/pixelorama/export_sea_v1.ps1).
##
## Rodar: Godot --headless --path . --script res://tools/pixelorama/build_sea_v1.gd
## Opcional: -- --preview grava qa/boat_v1_preview.png e qa/isle_v1_preview.png ampliados 3×.
##
## Só a paleta do Porto v7, alfa binário e contorno escuro, como build_interiors_v1.gd.
## O barco é um modelo 3D simples (casco, bancos, remos e Senu) girado e projetado
## em isométrico 2:1: tela = (x, y/2 − z).

const OUT_DIR := "res://art/pixelorama/sea_v1"
const DIRECTIONS := 16
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

## Casco: meio comprimento, meia boca e onde ficam o banco e os toletes.
const HALF_L := 25.0
const HALF_B := 8.5
const SEAT_U := 3.0
const OARLOCK_U := -2.0
const OAR_OUT := 22.0
const OAR_IN := 7.0
## Quadros de uma remada completa; mais quadros, remada mais fluida.
const ROW_FRAMES := 8
## Ângulo do remo a partir da perpendicular (positivo para a proa) na pegada e na saída.
const CATCH_ANGLE := 38.0
const FINISH_ANGLE := -30.0


class Sheet:
	var name := ""
	var cell := Vector2i.ZERO
	var pivot := Vector2i.ZERO
	var columns := 8
	var frames: Array[Image] = []
	var sprites := {}


var _sheet: Sheet
var _img: Image
var _heading := 0.0


func _init() -> void:
	var boat := _new_sheet("boat_v1", Vector2i(96, 80), Vector2i(48, 54), 10)
	_build_boat()
	var isle := _new_sheet("isle_v1", Vector2i(128, 144), Vector2i(64, 112), 8)
	_build_isle()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for sheet in [boat, isle]:
		_write_pxo(sheet)
		_write_plan(sheet)
		if "--preview" in OS.get_cmdline_user_args():
			_write_preview(sheet)
		print("SEA_V1 %s frames=%d sprites=%d" % [sheet.name, sheet.frames.size(), sheet.sprites.size()])
	quit()


func _new_sheet(name: String, cell: Vector2i, pivot: Vector2i, columns: int) -> Sheet:
	_sheet = Sheet.new()
	_sheet.name = name
	_sheet.cell = cell
	_sheet.pivot = pivot
	_sheet.columns = columns
	return _sheet


# --- Barco ----------------------------------------------------------------------

func _build_boat() -> void:
	var poses := _poses()
	for direction in range(DIRECTIONS):
		var name := "boat_%02d" % direction
		for pose in poses:
			_begin()
			_heading = direction * TAU / DIRECTIONS
			_boat(pose)
			_outline()
			_end(name)
		_sheet.sprites[name]["poses"] = poses.map(func(pose: Dictionary) -> String: return str(pose["name"]))


## Parado, os quadros da remada e o barco vazio. Cada pose diz o ângulo do remo,
## a altura da pá (abaixo de zero está dentro d'água), a inclinação do tronco
## (positivo para a popa) e se há respingo.
func _poses() -> Array:
	var list := [{"name": "parado", "angle": -22.0, "blade": .5, "lean": 0.0, "splash": false}]
	for frame in range(ROW_FRAMES):
		var t := float(frame) / ROW_FRAMES
		if t < .5:
			# Puxada: a pá entra na água perto da proa e varre até a popa.
			var u := t / .5
			list.append({"name": "puxada %d" % frame, "angle": lerpf(CATCH_ANGLE, FINISH_ANGLE, u), "blade": 0.0 if frame == 0 else -1.5, "lean": lerpf(3.0, -2.0, u), "splash": frame == 0})
		else:
			# Volta: a pá sai, sobe num arco e retorna à pegada.
			var u := (t - .5) / .5
			list.append({"name": "volta %d" % frame, "angle": lerpf(FINISH_ANGLE, CATCH_ANGLE, u), "blade": .5 + 4.0 * sin(u * PI), "lean": lerpf(-2.0, 3.0, u), "splash": false})
	# Atracado e vazio: os remos recolhidos ao longo do banco.
	list.append({"name": "vazio", "empty": true})
	return list


## Ponto do barco (u para a proa, v para estibordo, z para cima) na tela.
func _bp(u: float, v: float, z: float) -> Vector2:
	var c := cos(_heading)
	var s := sin(_heading)
	return Vector2(u * c - v * s, (u * s + v * c) * .5 - z)


func _half_width(u: float) -> float:
	var t := clampf(absf(u) / HALF_L, 0.0, 1.0)
	return HALF_B * pow(1.0 - t * t, .55)


## A borda sobe nas pontas como nos barcos de papiro do Nilo.
func _gunwale(u: float) -> float:
	return 5.0 + 8.0 * pow(clampf(absf(u) / HALF_L, 0.0, 1.0), 3.2)


func _stations() -> Array[float]:
	var list: Array[float] = []
	for i in range(25):
		list.append(-HALF_L + 2.0 * HALF_L * i / 24.0)
	return list


func _side(sign: float, top: bool) -> Array:
	var points := []
	for u in _stations():
		points.append(_bp(u, sign * _half_width(u), _gunwale(u)) if top else _bp(u, sign * _half_width(u) * .8, 0.0))
	return points


func _boat(pose: Dictionary) -> void:
	# Estibordo (+v) fica do lado da câmera quando sua normal aponta para baixo na tela.
	var near := 1.0 if cos(_heading) >= 0.0 else -1.0
	var far := -near
	var back_visible := sin(_heading) > 0.0
	# Costado de trás: só aparece nas pontas, acima do interior.
	var far_top := _side(far, true)
	var far_water := _side(far, false)
	far_water.reverse()
	_poly(far_top + far_water, "wood_dark")
	# Interior: paredes internas e o fundo, um pouco mais baixo.
	var loop := _side(-1.0, true)
	var other := _side(1.0, true)
	other.reverse()
	_poly(loop + other, "wood")
	var floor_points := []
	var floor_back := []
	for u in _stations():
		if absf(u) > HALF_L - 3.0:
			continue
		floor_points.append(_bp(u, -_half_width(u) * .7, 1.5))
		floor_back.append(_bp(u, _half_width(u) * .7, 1.5))
	floor_back.reverse()
	_poly(floor_points + floor_back, "wood_dark")
	for u in [-15.0, -8.0, 9.0, 16.0]:
		_line(_bp(u, -_half_width(u) * .7, 1.6), _bp(u, _half_width(u) * .7, 1.6), "umber")
	# Bancos.
	for u in [SEAT_U + 1.0, 13.0, -12.0]:
		var w := _half_width(u) * .92
		_poly([_bp(u - 1.2, -w, 4.0), _bp(u + 1.2, -w, 4.0), _bp(u + 1.2, w, 4.0), _bp(u - 1.2, w, 4.0)], "wood_light")
	# Borda de trás (o friso claro que se vê por cima do interior).
	_polyline(_side(far, true), "tan")
	# Remo de trás, Senu e o remo da frente, por profundidade.
	if pose.get("empty", false):
		for side in [-2.5, 2.5]:
			_line(_bp(-15.0, side, 5.0), _bp(12.0, side, 5.5), "wood_light")
			_poly([_bp(-15.0, side - 1.2, 5.0), _bp(-10.0, side - 1.2, 5.0), _bp(-10.0, side + 1.2, 5.0), _bp(-15.0, side + 1.2, 5.0)], "tan")
		_line(_bp(16.0, -1.0, 4.5), _bp(19.0, 1.0, 4.5), "wood_light")
		_disc(_bp(16.0, 0.0, 4.5), 1.5, "tan")
	else:
		_oar(far, pose)
		_rower(pose, back_visible)
	# Costado da frente: tábuas, amarras de corda e a linha d'água.
	var near_top := _side(near, true)
	var near_water := _side(near, false)
	var near_shape := near_top.duplicate()
	var reversed_water := near_water.duplicate()
	reversed_water.reverse()
	_poly(near_shape + reversed_water, "wood")
	var strake := []
	for u in _stations():
		strake.append(_bp(u, near * _half_width(u) * .92, _gunwale(u) * .55))
	_polyline(strake, "wood_light")
	_polyline(near_water, "wood_dark")
	for u in [-17.0, -9.0, 9.0, 17.0]:
		_line(_bp(u, near * _half_width(u), _gunwale(u) - .5), _bp(u, near * _half_width(u) * .82, .5), "tan")
	_polyline(near_top, "gold_dark")
	if not pose.get("empty", false):
		_oar(near, pose)
	# Pontas em forma de umbela de papiro.
	for tip in [HALF_L, -HALF_L]:
		var top := _bp(tip, 0.0, _gunwale(tip))
		var lean := _bp(tip * 1.08, 0.0, _gunwale(tip) + 2.0)
		_line(top, lean, "wood_light")
		_pxv(lean, "gold")
		_pxv(lean + Vector2(-1, 0), "gold_dark")
		_pxv(lean + Vector2(1, 0), "gold_dark")
		_pxv(lean + Vector2(0, -1), "gold")


func _oar(sign: float, pose: Dictionary) -> void:
	var angle := deg_to_rad(float(pose["angle"]))
	var pivot_v := sign * _half_width(OARLOCK_U)
	var pivot_z := _gunwale(OARLOCK_U) + 1.0
	var du := sin(angle)
	var dv := sign * cos(angle)
	var blade_z := float(pose["blade"])
	var handle := _bp(OARLOCK_U - du * OAR_IN, pivot_v - dv * OAR_IN, pivot_z + 2.5)
	var root := _bp(OARLOCK_U + du * (OAR_OUT - 5.0), pivot_v + dv * (OAR_OUT - 5.0), lerpf(pivot_z, blade_z, .78))
	var tip := _bp(OARLOCK_U + du * OAR_OUT, pivot_v + dv * OAR_OUT, blade_z)
	_line(handle, root, "wood_light")
	# Pá: mais larga que o cabo; abaixo da água fica escura e só a borda aparece.
	var across := Vector2(-(tip - root).y, (tip - root).x).normalized() * 1.5
	var blade := "tan" if blade_z >= 0.0 else "teal_light"
	_poly([root + across, tip + across, tip - across, root - across], blade)
	_pxv(_bp(OARLOCK_U, pivot_v, pivot_z), "umber")
	if pose["splash"]:
		for offset in [Vector2(-3, -1), Vector2(3, -1), Vector2(-2, -3), Vector2(2, -3), Vector2(0, -4)]:
			_pxv(tip + offset, "cream")
		_pxv(tip + Vector2(-4, 0), "bone")
		_pxv(tip + Vector2(4, 0), "bone")


## Senu sentado de costas para a proa (quem rema olha para a popa).
func _rower(pose: Dictionary, back_visible: bool) -> void:
	var lean := float(pose["lean"])
	var hips := Vector3(SEAT_U, 0.0, 4.5)
	var shoulders := Vector3(SEAT_U - lean, 0.0, 14.5)
	var hip_l := _bp(hips.x, -3.0, hips.z)
	var hip_r := _bp(hips.x, 3.0, hips.z)
	var sh_l := _bp(shoulders.x, -3.6, shoulders.z)
	var sh_r := _bp(shoulders.x, 3.6, shoulders.z)
	# Só os joelhos aparecem; o resto das pernas fica escondido pelo casco.
	for side in [-1.6, 1.6]:
		_line(_bp(hips.x, side, hips.z), _bp(hips.x - 4.0, side, 6.5), "bone")
	var cape := [_bp(shoulders.x + 1.2, -3.8, shoulders.z - .5), _bp(shoulders.x + 1.2, 3.8, shoulders.z - .5), _bp(hips.x + 1.8, 4.2, hips.z - .5), _bp(hips.x + 1.8, -4.2, hips.z - .5)]
	var torso := [hip_l, hip_r, sh_r, sh_l]
	var handle_l := _bp(OARLOCK_U - sin(deg_to_rad(float(pose["angle"]))) * OAR_IN, -_half_width(OARLOCK_U) + cos(deg_to_rad(float(pose["angle"]))) * OAR_IN, _gunwale(OARLOCK_U) + 3.5)
	var handle_r := _bp(OARLOCK_U - sin(deg_to_rad(float(pose["angle"]))) * OAR_IN, _half_width(OARLOCK_U) - cos(deg_to_rad(float(pose["angle"]))) * OAR_IN, _gunwale(OARLOCK_U) + 3.5)
	var arms := func() -> void:
		for pair in [[sh_l, handle_l], [sh_r, handle_r]]:
			var elbow: Vector2 = (pair[0] as Vector2).lerp(pair[1], .5) + Vector2(0, 1.5)
			_line(pair[0], elbow, "linen")
			_line(elbow, pair[1], "tan")
			_pxv(pair[1], "wood_light")
	if back_visible:
		_poly(torso, "linen")
		_line(_bp(hips.x, -3.0, hips.z + 2.0), _bp(hips.x, 3.0, hips.z + 2.0), "wood")
		arms.call()
		_poly(cape, "teal")
		_line(cape[0], cape[1], "teal_light")
		_pxv(_bp(shoulders.x + .5, 3.0, shoulders.z + .5), "gold")
	else:
		_poly(cape, "teal_dark")
		_poly(torso, "linen")
		_line(_bp(hips.x - .3, -3.0, hips.z + 2.0), _bp(hips.x - .3, 3.0, hips.z + 2.0), "wood")
		_line(_bp(shoulders.x - .3, -3.4, shoulders.z - 1.0), _bp(shoulders.x - .3, 3.4, shoulders.z - 1.0), "jade")
		_pxv(_bp(shoulders.x - .3, 3.0, shoulders.z), "gold")
		arms.call()
	# Cabeça: rosto quando Senu olha para a câmera, cabelo quando está de costas.
	var head := _bp(shoulders.x - lean * .2, 0.0, shoulders.z + 4.5)
	_disc(head, 3.2, "tan")
	if back_visible:
		_disc(head + Vector2(0, -.5), 3.0, "umber")
	else:
		_rect(roundi(head.x) - 3, roundi(head.y) - 4, 7, 2, "umber")
		_pxv(head + Vector2(-1, 0), "umber")
		_pxv(head + Vector2(1, 0), "umber")
	_line(head + Vector2(-3, -2), head + Vector2(3, -2), "cream")


# --- Ilha -----------------------------------------------------------------------

func _build_isle() -> void:
	for piece in ["acacia", "sycamore", "bush_a", "bush_b", "rock_a", "rock_b", "sea_rock", "reeds", "driftwood", "column_broken", "brazier_off", "altar_closed", "altar_open", "net", "amphora"]:
		_begin()
		call("_" + piece)
		_outline()
		_end(piece)
	for flame in range(3):
		_begin()
		_brazier(flame)
		_outline()
		_end("brazier_on")
	_sheet.sprites["brazier_on"]["fps"] = 8.0
	_sheet.sprites["brazier_on"]["sequence"] = [0, 1, 2, 1]
	for pose in [[0, false], [-1, false], [0, true]]:
		_begin()
		_ankhet(pose[0], pose[1])
		_outline()
		_end("ankhet")
	_sheet.sprites["ankhet"]["fps"] = 4.0
	_sheet.sprites["ankhet"]["sequence"] = [0, 0, 1, 1, 0, 0, 1, 1, 0, 2]
	for pose in range(4):
		_begin()
		_heron(pose)
		_outline()
		_end("heron")
	_sheet.sprites["heron"]["fps"] = 2.0
	_sheet.sprites["heron"]["sequence"] = [0, 0, 0, 1, 1, 0, 0, 2, 0, 3, 3, 0]
	for wing in range(2):
		_begin()
		_heron_flying(wing)
		_outline()
		_end("heron_fly")
	_sheet.sprites["heron_fly"]["fps"] = 6.0


## Copa em camadas de tufos: sombra embaixo, luz em cima e à esquerda.
func _canopy(center: Vector2, rx: float, ry: float, dark: String, mid: String, light: String, seed: int) -> void:
	_blob(center + Vector2(0, 3), rx, ry, dark, seed)
	_blob(center + Vector2(-1, 0), rx - 2.0, ry - 2.0, mid, seed + 3)
	for tuft in range(6):
		var angle := -2.4 + tuft * .55
		var at := center + Vector2(cos(angle) * rx * .45, sin(angle) * ry * .45 - 2.0)
		_blob(at, rx * .32, ry * .38, light if tuft % 2 == 0 else mid, seed + tuft * 7)


func _acacia() -> void:
	_trunk([Vector2(0, 0), Vector2(1, -12), Vector2(-2, -24), Vector2(-1, -34)], 3, "wood_dark", "wood")
	_line(Vector2(-1, -28), Vector2(-14, -40), "wood_dark")
	_line(Vector2(0, -30), Vector2(13, -41), "wood_dark")
	_line(Vector2(-1, -33), Vector2(2, -44), "wood_dark")
	# Copa achatada em guarda-chuva, típica da acácia.
	_canopy(Vector2(-12, -45), 17, 6, "olive_dark", "olive", "olive_light", 11)
	_canopy(Vector2(12, -46), 17, 6, "olive_dark", "olive", "olive_light", 23)
	_canopy(Vector2(1, -51), 15, 5, "olive_dark", "olive", "olive_light", 37)


func _sycamore() -> void:
	_trunk([Vector2(0, 0), Vector2(-1, -16), Vector2(1, -30)], 5, "wood_dark", "wood_light")
	_line(Vector2(-4, 0), Vector2(-9, 3), "wood_dark")
	_line(Vector2(4, 0), Vector2(9, 3), "wood_dark")
	_canopy(Vector2(-14, -46), 20, 15, "moss", "sage", "lichen", 5)
	_canopy(Vector2(15, -44), 19, 14, "moss", "sage", "lichen", 17)
	_canopy(Vector2(0, -60), 22, 15, "moss", "sage", "lichen", 29)
	# Figos do sicômoro.
	for fig in [Vector2(-18, -40), Vector2(-6, -52), Vector2(9, -38), Vector2(19, -50), Vector2(2, -66), Vector2(-12, -60)]:
		_pxv(fig, "rust")
		_pxv(fig + Vector2(1, 0), "tan")


func _bush_a() -> void:
	_canopy(Vector2(0, -8), 13, 8, "olive_dark", "olive", "olive_light", 41)


func _bush_b() -> void:
	_canopy(Vector2(0, -9), 12, 8, "moss", "sage", "lichen", 53)
	for flower in [Vector2(-6, -12), Vector2(3, -15), Vector2(7, -8), Vector2(-2, -6)]:
		_pxv(flower, "gold")
		_pxv(flower + Vector2(0, 1), "gold_dark")


func _rock_a() -> void:
	_poly([Vector2(-15, 0), Vector2(-12, -10), Vector2(-3, -16), Vector2(8, -14), Vector2(15, -5), Vector2(12, 2), Vector2(-4, 4)], "stone_dark")
	_poly([Vector2(-12, -9), Vector2(-3, -15), Vector2(7, -13), Vector2(3, -6), Vector2(-7, -4)], "stone")
	_poly([Vector2(-5, -14), Vector2(4, -13), Vector2(-1, -9)], "stone_light")
	_line(Vector2(3, -6), Vector2(12, 1), "charcoal")


func _rock_b() -> void:
	_poly([Vector2(-11, 0), Vector2(-9, -7), Vector2(-1, -11), Vector2(10, -8), Vector2(12, -1), Vector2(2, 3)], "stone_dark")
	_poly([Vector2(-8, -7), Vector2(-1, -10), Vector2(8, -8), Vector2(1, -4)], "stone")
	_pxv(Vector2(-2, -9), "stone_light")
	_pxv(Vector2(-1, -9), "stone_light")
	_poly([Vector2(13, 1), Vector2(15, -3), Vector2(20, -2), Vector2(19, 2)], "stone_dark")


func _sea_rock() -> void:
	_poly([Vector2(-20, 2), Vector2(-17, -12), Vector2(-8, -24), Vector2(4, -27), Vector2(13, -18), Vector2(20, -6), Vector2(19, 3), Vector2(0, 6)], "stone_dark")
	_poly([Vector2(-15, -12), Vector2(-7, -23), Vector2(4, -26), Vector2(6, -14), Vector2(-4, -8)], "stone")
	_poly([Vector2(-6, -22), Vector2(3, -25), Vector2(0, -17)], "stone_light")
	_line(Vector2(6, -14), Vector2(18, -4), "charcoal")
	# Base molhada e algas na linha d'água.
	_poly([Vector2(-20, 2), Vector2(-19, -3), Vector2(0, 1), Vector2(19, -3), Vector2(19, 3), Vector2(0, 6)], "slate")
	for weed in [Vector2(-14, -2), Vector2(-6, 0), Vector2(9, -1), Vector2(15, -3)]:
		_pxv(weed, "jade")
		_pxv(weed + Vector2(0, -1), "moss")


func _reeds() -> void:
	for stalk in range(9):
		var x := -12.0 + stalk * 3.0
		var height := 26.0 + float((stalk * 7) % 11)
		var top := Vector2(x + (stalk % 3 - 1) * 2.0, -height)
		_line(Vector2(x, 0), top, "olive" if stalk % 2 == 0 else "olive_light")
		# Umbela de papiro: um leque de fios no alto.
		for ray in range(-2, 3):
			_line(top, top + Vector2(ray * 2, -3 - absi(ray)), "olive_light" if ray % 2 == 0 else "gold_dark")


func _driftwood() -> void:
	var a := Vector2(-18, -2)
	var b := Vector2(16, 4)
	var across := Vector2(0, -3)
	_poly([a, b, b + across, a + across], "sand_dark")
	_line(a + across, b + across, "bone")
	_line(Vector2(-8, -3), Vector2(-13, -10), "sand_dark")
	_line(Vector2(6, 1), Vector2(10, -5), "sand_dark")
	_disc(a + Vector2(0, -1.5), 2, "wood_light")


func _column_broken() -> void:
	_poly([Vector2(-7, 0), Vector2(-7, -24), Vector2(-2, -29), Vector2(3, -25), Vector2(7, -27), Vector2(7, 0), Vector2(0, 3)], "sand_dark")
	_poly([Vector2(-7, -1), Vector2(-7, -24), Vector2(-2, -29), Vector2(0, -27), Vector2(0, 2)], "sand")
	for groove in [-5, -3, 2, 5]:
		_line(Vector2(groove, -1), Vector2(groove, -22), "stone_light")
	_poly([Vector2(-11, 2), Vector2(0, 7), Vector2(11, 2), Vector2(0, -3)], "stone")
	_poly([Vector2(9, 4), Vector2(14, 3), Vector2(16, 6), Vector2(11, 8)], "sand_dark")


func _brazier_base() -> void:
	var top := _box(.4, .4, 18, "sand", "stone", "sand_dark")
	_line(top[3] + Vector2(1, 6), top[2] + Vector2(0, 6), "gold_dark")
	_poly([Vector2(-11, -19), Vector2(0, -14), Vector2(11, -19), Vector2(8, -24), Vector2(0, -21), Vector2(-8, -24)], "rust")
	_poly([Vector2(-8, -24), Vector2(0, -27), Vector2(8, -24), Vector2(0, -21)], "charcoal")


func _brazier_off() -> void:
	_brazier_base()
	_pxv(Vector2(-2, -24), "stone")
	_pxv(Vector2(2, -25), "stone_dark")


func _brazier(flame: int) -> void:
	_brazier_base()
	var tall: int = [12, 15, 13][flame]
	var sway: int = [0, 1, -1][flame]
	_poly([Vector2(-6, -24), Vector2(sway - 2, -24 - tall), Vector2(sway, -24 - tall - 3), Vector2(sway + 2, -24 - tall + 1), Vector2(6, -24)], "flame")
	_poly([Vector2(-3, -24), Vector2(sway, -24 - tall + 3), Vector2(3, -24)], "glow")
	_pxv(Vector2(sway + 4, -24 - tall + 2), "glow")
	_pxv(Vector2(-4, -27), "rust")


func _altar_closed() -> void:
	_altar(false)


func _altar_open() -> void:
	_altar(true)


func _altar(open: bool) -> void:
	var top := _box(1.0, .7, 18, "sand", "stone_light", "sand_dark")
	# Relevo do Bennu na face: a garça de pé, com o disco do sol.
	var face := top[3].lerp(top[2], .5) + Vector2(0, 10)
	_line(face + Vector2(0, 4), face + Vector2(0, -2), "gold_dark")
	_line(face + Vector2(0, -2), face + Vector2(3, -5), "gold_dark")
	_line(face + Vector2(3, -5), face + Vector2(6, -4), "gold_dark")
	_disc(face + Vector2(-1, -7), 2, "gold")
	if open:
		# A tampa deslizou para trás e o fundo brilha.
		_poly([top[0] + Vector2(-6, -4), top[1] + Vector2(-6, -4), top[1] + Vector2(-6, -8), top[0] + Vector2(-6, -8)], "stone_light")
		var inner := [top[0].lerp(top[2], .2), top[1].lerp(top[3], .2), top[2].lerp(top[0], .2), top[3].lerp(top[1], .2)]
		_poly(inner, "umber")
		var center: Vector2 = (inner[0] + inner[2]) * .5
		_disc(center, 3, "glow")
		_line(center + Vector2(-3, 1), center + Vector2(4, -3), "gold")
	else:
		_poly([top[0], top[1], top[2], top[3]], "stone_light")
		_line(top[3], top[2], "sand")


func _net() -> void:
	# Rede enroscada sobre a areia, com bóias e o nó de três voltas.
	_blob(Vector2(0, -3), 16, 6, "sand_dark", 61)
	for row in range(-4, 5, 2):
		_line(Vector2(-14, -3 + row), Vector2(14, -3 + row * .4), "wood_light")
	for column in range(-12, 13, 4):
		_line(Vector2(column, -8), Vector2(column + 3, 2), "wood_light")
	for buoy in [Vector2(-13, -5), Vector2(10, -7), Vector2(14, 0)]:
		_disc(buoy, 2, "rust")
	_disc(Vector2(-2, -4), 2.5, "tan")
	_line(Vector2(-4, -6), Vector2(0, -2), "wood_dark")
	_line(Vector2(-4, -2), Vector2(0, -6), "wood_dark")


func _amphora() -> void:
	# Deitada e boiando na diagonal, com a boca tampada.
	var axis := Vector2(1, -.45).normalized()
	var across := Vector2(-axis.y, axis.x)
	var body := []
	for step in range(13):
		var t := step / 12.0
		var width := 6.5 * sin(t * PI) * (1.0 - .35 * t) + 1.5
		body.append(axis * lerpf(-12, 11, t) + across * width)
	for step in range(12, -1, -1):
		var t := step / 12.0
		var width := 6.5 * sin(t * PI) * (1.0 - .35 * t) + 1.5
		body.append(axis * lerpf(-12, 11, t) - across * width)
	_poly(body, "rust")
	_line(axis * -9 - across * 3, axis * 7 - across * 3, "flame")
	_line(axis * -8 + across * 4, axis * 6 + across * 3, "tan")
	_disc(axis * 13, 2, "wood_dark")
	_line(axis * 8 + across * 3, axis * 11 + across * 5, "tan")
	_line(axis * 8 - across * 3, axis * 11 - across * 5, "tan")
	_line(axis * -12 - across * 2, axis * -12 + across * 2, "tan")


func _ankhet(lift: int, blink: bool) -> void:
	# Guardiã das garças: idosa, cabelo branco, xale azul e cajado de junco.
	_line(Vector2(11, 0), Vector2(11, -40), "wood_light")
	_line(Vector2(12, -40), Vector2(9, -44), "olive_light")
	_line(Vector2(12, -40), Vector2(14, -44), "olive_light")
	_poly([Vector2(-9, 0), Vector2(-7, -22 + lift), Vector2(7, -22 + lift), Vector2(9, 0), Vector2(0, 2)], "linen")
	_poly([Vector2(-9, 0), Vector2(-7, -22 + lift), Vector2(-2, -22 + lift), Vector2(-3, 1)], "bone")
	_poly([Vector2(-8, -16 + lift), Vector2(-7, -24 + lift), Vector2(7, -24 + lift), Vector2(8, -15 + lift), Vector2(0, -12 + lift)], "teal")
	_line(Vector2(-7, -24 + lift), Vector2(7, -24 + lift), "teal_light")
	_line(Vector2(7, -17 + lift), Vector2(11, -20), "tan")
	_disc(Vector2(0, -28 + lift), 4.5, "tan")
	_poly([Vector2(-5, -29 + lift), Vector2(-4, -34 + lift), Vector2(4, -34 + lift), Vector2(5, -29 + lift), Vector2(4, -31 + lift), Vector2(-4, -31 + lift)], "cream")
	_line(Vector2(-5, -29 + lift), Vector2(-6, -22 + lift), "cream")
	_line(Vector2(5, -29 + lift), Vector2(6, -23 + lift), "cream")
	if blink:
		_line(Vector2(-3, -28 + lift), Vector2(-1, -28 + lift), "wood")
		_line(Vector2(1, -28 + lift), Vector2(3, -28 + lift), "wood")
	else:
		_pxv(Vector2(-2, -28 + lift), "ink")
		_pxv(Vector2(2, -28 + lift), "ink")
	_pxv(Vector2(0, -24 + lift), "gold")


func _heron(pose: int) -> void:
	# A garça de pé na água rasa: só as pernas finas e o reflexo.
	_line(Vector2(-2, 0), Vector2(-2, -12), "charcoal")
	_line(Vector2(2, 0), Vector2(1, -12), "charcoal")
	_line(Vector2(-6, 1), Vector2(6, 1), "sea")
	var body := [Vector2(-8, -16), Vector2(-3, -20), Vector2(6, -19), Vector2(9, -14), Vector2(2, -11), Vector2(-6, -12)]
	if pose == 3:
		body = [Vector2(-8, -17), Vector2(-3, -21), Vector2(6, -20), Vector2(10, -15), Vector2(2, -11), Vector2(-6, -12)]
	_poly(body, "bone")
	_poly([Vector2(-8, -16), Vector2(-3, -19), Vector2(4, -17), Vector2(-4, -13)], "sage")
	_line(Vector2(9, -14), Vector2(12, -11), "lichen")
	var neck: Array
	var beak_from: Vector2
	var beak_to: Vector2
	match pose:
		1:
			neck = [Vector2(-5, -19), Vector2(-9, -16), Vector2(-12, -9)]
			beak_from = Vector2(-12, -9)
			beak_to = Vector2(-15, -3)
		3:
			neck = [Vector2(-5, -20), Vector2(-3, -27), Vector2(2, -24)]
			beak_from = Vector2(2, -24)
			beak_to = Vector2(5, -19)
		_:
			var stretch := 2.0 if pose == 2 else 0.0
			neck = [Vector2(-5, -19), Vector2(-9, -26 - stretch), Vector2(-6, -32 - stretch)]
			beak_from = Vector2(-6, -32 - stretch)
			beak_to = Vector2(-13, -31 - stretch)
	_line(neck[0], neck[1], "cream")
	_line(neck[1], neck[2], "cream")
	_line(neck[0] + Vector2(1, 0), neck[1] + Vector2(1, 0), "bone")
	_disc(neck[2], 2, "cream")
	_line(beak_from, beak_to, "gold_dark")
	_pxv(neck[2] + Vector2(-1, -1), "ink")
	_line(neck[2] + Vector2(1, -1), neck[2] + Vector2(4, -2), "charcoal")


func _heron_flying(wing: int) -> void:
	_poly([Vector2(-10, -30), Vector2(8, -31), Vector2(12, -28), Vector2(-6, -27)], "bone")
	_line(Vector2(-10, -30), Vector2(-16, -31), "cream")
	_line(Vector2(-16, -31), Vector2(-21, -30), "gold_dark")
	_line(Vector2(12, -28), Vector2(19, -26), "charcoal")
	var up := wing == 0
	_poly([Vector2(-4, -30), Vector2(-10 if up else -8, -44 if up else -18), Vector2(4, -42 if up else -19), Vector2(5, -30)], "lichen")
	_poly([Vector2(-1, -30), Vector2(-4 if up else -3, -40 if up else -22), Vector2(4, -30)], "bone")


# --- Primitivas -------------------------------------------------------------------

func _begin() -> void:
	_img = Image.create_empty(_sheet.cell.x, _sheet.cell.y, false, Image.FORMAT_RGBA8)


func _end(name: String) -> void:
	_sheet.frames.append(_img)
	if not _sheet.sprites.has(name):
		_sheet.sprites[name] = {"frames": []}
	_sheet.sprites[name]["frames"].append(_sheet.frames.size() - 1)


func _iso(tx: float, ty: float) -> Vector2:
	return Vector2((tx - ty) * 32.0, (tx + ty) * 16.0)


func _px(x: int, y: int, color: String) -> void:
	var point := _sheet.pivot + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < _sheet.cell.x and point.y < _sheet.cell.y:
		_img.set_pixelv(point, Color(PAL[color]))


func _pxv(point: Vector2, color: String) -> void:
	_px(roundi(point.x), roundi(point.y), color)


func _rect(x: int, y: int, w: int, h: int, color: String) -> void:
	for row in range(h):
		for column in range(w):
			_px(x + column, y + row, color)


func _poly(points: Array, color: String) -> void:
	var polygon := PackedVector2Array(points)
	if polygon.size() < 3:
		return
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	for y in range(floori(bounds.position.y), ceili(bounds.end.y) + 1):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + .5, y + .5), polygon):
				_px(x, y, color)


func _polyline(points: Array, color: String) -> void:
	for index in range(points.size() - 1):
		_line(points[index], points[index + 1], color)


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


func _disc(center: Vector2, radius: float, color: String) -> void:
	for y in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			if Vector2(x + .5, y + .5).distance_to(center + Vector2(.5, .5)) <= radius:
				_px(x, y, color)


## Mancha de folhagem: elipse com a borda recortada por uma ondulação fixa.
func _blob(center: Vector2, rx: float, ry: float, color: String, seed: int) -> void:
	for y in range(floori(center.y - ry - 2), ceili(center.y + ry + 2) + 1):
		for x in range(floori(center.x - rx - 2), ceili(center.x + rx + 2) + 1):
			var offset := Vector2((x - center.x) / maxf(rx, 1.0), (y - center.y) / maxf(ry, 1.0))
			var angle := offset.angle()
			var edge := 1.0 + .12 * sin(angle * 5.0 + seed) + .08 * sin(angle * 9.0 + seed * 1.7)
			if offset.length() <= edge:
				_px(x, y, color)


func _trunk(points: Array, width: int, dark: String, light: String) -> void:
	for index in range(points.size() - 1):
		for offset in range(-width / 2, width - width / 2):
			var shift := Vector2(offset, 0)
			_line(points[index] + shift, points[index + 1] + shift, light if offset < 0 else dark)


## Caixa isométrica com medidas em tiles; devolve os cantos do tampo: fundo,
## direita, frente, esquerda (como em build_interiors_v1.gd).
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


## Contorno escuro de 1 pixel em volta da silhueta, como nos props do Porto.
func _outline(color: String = "ink") -> void:
	var source := _img.duplicate() as Image
	for y in range(_sheet.cell.y):
		for x in range(_sheet.cell.x):
			if source.get_pixel(x, y).a > 0:
				continue
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor: Vector2i = Vector2i(x, y) + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < _sheet.cell.x and neighbor.y < _sheet.cell.y and source.get_pixelv(neighbor).a > 0:
					_img.set_pixel(x, y, Color(PAL[color]))
					break


# --- Arquivos -------------------------------------------------------------------

func _write_pxo(sheet: Sheet) -> void:
	var frames := []
	for index in range(sheet.frames.size()):
		frames.append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tags := []
	for name in sheet.sprites:
		var list: Array = sheet.sprites[name]["frames"]
		tags.append({"name": name, "color": "6db0a4ff", "from": int(list[0]) + 1, "to": int(list[list.size() - 1]) + 1})
	var data := {
		"pixelorama_version": "v1.2.3-stable", "pxo_version": 7,
		"size_x": sheet.cell.x, "size_y": sheet.cell.y, "color_mode": 5,
		"layers": [{"name": "Mar" if sheet.name == "boat_v1" else "Ilha", "type": 0, "new_cels_linked": false, "visible": true, "locked": false, "blend_mode": 0, "opacity": 1.0, "parent": -1, "effects": []}],
		"frames": frames, "tags": tags, "fps": 8.0, "current_frame": 0, "current_layer": 0,
		"export_profile": {"orientation": "1", "lines_count": str(sheet.columns), "current_tab": "1", "crop_mode": "0", "resize": "100", "interpolation": "0"}
	}
	var path := "%s/%s.pxo" % [OUT_DIR, sheet.name]
	var zip := ZIPPacker.new()
	var error := zip.open(ProjectSettings.globalize_path(path))
	assert(error == OK, "não foi possível criar " + path)
	_zip_file(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip_file(zip, "data.json", JSON.stringify(data).to_utf8_buffer())
	for index in range(sheet.frames.size()):
		_zip_file(zip, "image_data/frames/%d/layer_1" % (index + 1), sheet.frames[index].get_data())
	_zip_file(zip, "preview.png", sheet.frames[0].save_png_to_buffer())
	zip.close()


func _zip_file(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()


func _write_plan(sheet: Sheet) -> void:
	var plan := {
		"version": 1,
		"pixel_art": true,
		"canvas": [sheet.cell.x, sheet.cell.y],
		"pivot": [sheet.pivot.x, sheet.pivot.y],
		"columns": sheet.columns,
		"frames": sheet.frames.size(),
		"texture": "res://assets/world/%s.png" % sheet.name,
		"source": "%s/%s.pxo" % [OUT_DIR, sheet.name],
		"sprites": sheet.sprites
	}
	var file := FileAccess.open("%s/%s_export_plan.json" % [OUT_DIR, sheet.name], FileAccess.WRITE)
	file.store_string(JSON.stringify(plan, "\t"))
	file.close()


func _write_preview(sheet: Sheet) -> void:
	var rows := ceili(sheet.frames.size() / float(sheet.columns))
	var image := Image.create_empty(sheet.cell.x * sheet.columns, sheet.cell.y * rows, false, Image.FORMAT_RGBA8)
	image.fill(Color("1d3a40"))
	for index in range(sheet.frames.size()):
		image.blend_rect(sheet.frames[index], Rect2i(Vector2i.ZERO, sheet.cell), Vector2i((index % sheet.columns) * sheet.cell.x, (index / sheet.columns) * sheet.cell.y))
	image.resize(image.get_width() * 3, image.get_height() * 3, Image.INTERPOLATE_NEAREST)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	image.save_png("res://qa/%s_preview.png" % sheet.name)
