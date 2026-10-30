extends SceneTree

## Moradores do Porto (docs/MUNDO_VIDA.md): folha de pixel art desenhada ponto a
## ponto, na paleta do Porto v7. Uma linha por aparência e uma coluna por pose.
## Todos olham para a direita; o jogo espelha para a esquerda.
##
## & "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/pixelorama/build_townsfolk_v1.gd [-- --preview]

const CELL := Vector2i(32, 52)
const PIVOT := Vector2i(16, 49)
const OUT := "res://assets/world/townsfolk_v1.png"
const MANIFEST := "res://assets/world/townsfolk_v1_manifest.json"
const POSES := ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "talk", "carry_idle", "carry_1", "carry_2", "carry_3", "carry_4", "bend"]
const PAL := {
	"ink": "14252c", "night": "1e343a", "slate": "2b4449", "sea": "3c5659", "moss": "526765",
	"sage": "6d7b70", "lichen": "8c9380", "bone": "b4b298", "linen": "dbcfaa", "cream": "eee0ba",
	"stone_dark": "4b5553", "stone": "646b60", "stone_light": "81816e",
	"sand_dark": "a09a7e", "sand": "bdad89", "umber": "332e28", "wood_dark": "4b3b2d",
	"wood": "674d34", "wood_light": "846443", "tan": "a27d50", "gold_dark": "c39e65",
	"gold": "e0bd7e", "teal_dark": "1f444b", "teal": "2c5b61", "teal_light": "3e7373",
	"jade": "609087", "olive_dark": "5a623e", "olive": "7d8051", "olive_light": "a49e66",
	"rust": "be733a", "clay": "8e5634", "flame": "e69d4a"
}
## Quem anda pelo Porto. `garment`: kilt (tanga), tunic (até o joelho), robe (até
## o tornozelo). `head`: band, cap, cloth, turban, bald, hood. `load`: o que levam
## nas poses de carga.
const LOOKS := [
	{"id": "estivador", "skin": "wood", "cloth": "linen", "accent": "rust", "garment": "kilt", "head": "band", "hair": "ink", "load": "crate"},
	{"id": "carregador", "skin": "tan", "cloth": "sand", "accent": "wood_dark", "garment": "tunic", "head": "cap", "hat": "teal", "hair": "ink", "load": "sack"},
	{"id": "peixeira", "skin": "wood_light", "cloth": "teal", "accent": "cream", "garment": "robe", "head": "cloth", "hat": "cream", "hair": "ink", "load": "basket"},
	{"id": "mercador", "skin": "tan", "cloth": "rust", "accent": "gold", "garment": "robe", "head": "turban", "hat": "linen", "hair": "ink", "beard": true, "load": "amphora"},
	{"id": "marinheiro", "skin": "wood_light", "cloth": "linen", "accent": "teal", "garment": "tunic", "head": "cap", "hat": "teal_dark", "hair": "umber", "stripes": true, "load": "crate"},
	{"id": "remador", "skin": "wood", "cloth": "olive", "accent": "olive_dark", "garment": "kilt", "head": "bald", "hair": "ink", "load": "sack"},
	{"id": "escriba", "skin": "tan", "cloth": "cream", "accent": "sand_dark", "garment": "robe", "head": "bald", "hair": "ink", "load": "scroll"},
	{"id": "peregrina", "skin": "wood_light", "cloth": "bone", "accent": "gold_dark", "garment": "robe", "head": "cloth", "hat": "sand", "hair": "ink", "load": "amphora"},
	{"id": "velho", "skin": "tan", "cloth": "stone_light", "accent": "stone", "garment": "robe", "head": "hood", "hat": "stone", "hair": "bone", "beard": true, "stoop": 2, "load": "sack"},
	{"id": "aguadeira", "skin": "wood", "cloth": "olive_light", "accent": "rust", "garment": "tunic", "head": "cloth", "hat": "rust", "hair": "ink", "load": "amphora"},
	{"id": "padeira", "skin": "tan", "cloth": "sage", "accent": "clay", "garment": "robe", "head": "cloth", "hat": "clay", "hair": "ink", "load": "basket"},
	{"id": "caravaneiro", "skin": "wood_light", "cloth": "tan", "accent": "teal", "garment": "tunic", "head": "turban", "hat": "cream", "hair": "umber", "beard": true, "load": "sack"},
	{"id": "sacerdote", "skin": "wood_light", "cloth": "cream", "accent": "gold", "garment": "robe", "head": "cloth", "hat": "bone", "hair": "ink", "beard": true, "stoop": 1, "load": "scroll"},
	{"id": "alquimista", "skin": "tan", "cloth": "teal_dark", "accent": "rust", "garment": "robe", "head": "hood", "hat": "teal", "hair": "ink", "load": "amphora"},
	{"id": "sentinela", "skin": "wood", "cloth": "sand_dark", "accent": "gold_dark", "garment": "tunic", "head": "cap", "hat": "wood_dark", "hair": "ink", "beard": true, "load": "crate"},
	{"id": "mercadora", "skin": "wood_light", "cloth": "jade", "accent": "gold", "garment": "robe", "head": "turban", "hat": "cream", "hair": "umber", "load": "basket"}
]
## Pés (perto, longe), quanto cada pé sobe e o balanço do corpo, por pose de passo.
const STEPS := {
	"idle": [1, -1, 0, 0, 0], "walk_1": [5, -4, 0, 0, 0], "walk_2": [1, -1, 0, 2, -1],
	"walk_3": [-4, 5, 0, 0, 0], "walk_4": [-1, 1, 2, 0, -1]
}

var _img: Image
var _look: Dictionary


func _init() -> void:
	var sheet := Image.create(CELL.x * POSES.size(), CELL.y * LOOKS.size(), false, Image.FORMAT_RGBA8)
	for row in range(LOOKS.size()):
		_look = LOOKS[row]
		for column in range(POSES.size()):
			_img = Image.create(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)
			_figure(POSES[column])
			_shade()
			_outline()
			sheet.blit_rect(_img, Rect2i(Vector2i.ZERO, CELL), Vector2i(column * CELL.x, row * CELL.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT))
	var looks: Array = []
	for look in LOOKS: looks.append(look["id"])
	var manifest := {"version": 1, "texture": OUT, "cell": [CELL.x, CELL.y], "pivot": [PIVOT.x, PIVOT.y], "poses": POSES, "looks": looks, "source": "res://tools/pixelorama/build_townsfolk_v1.gd"}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	if "--preview" in OS.get_cmdline_user_args():
		var preview := sheet.duplicate() as Image
		preview.resize(sheet.get_width() * 3, sheet.get_height() * 3, Image.INTERPOLATE_NEAREST)
		preview.save_png(ProjectSettings.globalize_path("res://qa/townsfolk_v1_preview.png"))
	print("TOWNSFOLK_V1 looks=%d poses=%d sheet=%s" % [LOOKS.size(), POSES.size(), ProjectSettings.globalize_path(OUT)])
	quit()


# --- Figura ---------------------------------------------------------------------

func _figure(pose: String) -> void:
	var carrying := pose.begins_with("carry")
	var step: Array = STEPS.get(pose.replace("carry_idle", "idle").replace("carry_", "walk_"), STEPS["idle"])
	if pose in ["talk", "bend"]: step = STEPS["idle"]
	var bob: int = step[4]
	var stoop: int = _look.get("stoop", 0)
	var lean := 0
	if pose == "bend":
		lean = 4
		bob = 6
	var hip := Vector2(0, -17 + bob)
	var shoulder := Vector2(lean + stoop, -29 + bob + stoop)
	var head := shoulder + Vector2(1 + lean / 2 + stoop, -6)
	var skin: String = _look["skin"]
	var shade := _darker(skin)
	# Perna e braço do lado de lá, mais escuros, primeiro.
	var far_foot := Vector2(step[1], -step[3])
	var near_foot := Vector2(step[0], -step[2])
	_leg(hip + Vector2(-1, 0), far_foot, shade)
	_arm_far(pose, shoulder, step, carrying, shade)
	_body(pose, hip, shoulder, near_foot, far_foot)
	_head(head, pose)
	if carrying: _load_behind(shoulder, head)
	_leg_near(hip, near_foot, skin)
	_arm_near(pose, shoulder, step, carrying, skin)
	if carrying: _load_front(shoulder, head)
	elif _look["load"] == "scroll" and pose != "bend": _scroll(shoulder)


func _leg(from: Vector2, foot: Vector2, color: String) -> void:
	var knee := from.lerp(foot, .5) + Vector2(1, 0)
	_thick(from, knee, color)
	_thick(knee, foot + Vector2(0, -1), color)
	# Sandália egípcia com correia de couro
	_rect(roundi(foot.x) - 1, roundi(foot.y) - 1, 4, 1, "wood_dark")
	_px(roundi(foot.x) + 1, roundi(foot.y) - 2, "umber")


func _leg_near(hip: Vector2, foot: Vector2, color: String) -> void:
	if _look["garment"] == "robe":
		# Sob o manto aparecem os pés e as tiras da sandália
		_rect(roundi(foot.x) - 1, roundi(foot.y) - 1, 4, 1, "wood_dark")
		_px(roundi(foot.x) + 1, roundi(foot.y) - 2, "umber")
		_px(roundi(foot.x) + 2, roundi(foot.y) - 2, color)
		return
	_leg(hip + Vector2(1, 0), foot, color)


func _arm_far(pose: String, shoulder: Vector2, step: Array, carrying: bool, color: String) -> void:
	var from := shoulder + Vector2(-2, 1)
	if carrying and _look["load"] in ["sack", "amphora"]:
		_thick(from, from + Vector2(-1, -6), color)
		return
	var swing := -signf(step[0]) * 3.0 if absi(step[0]) > 2 else 0.0
	_thick(from, from + Vector2(swing - 1, 10), color)


func _arm_near(pose: String, shoulder: Vector2, step: Array, carrying: bool, color: String) -> void:
	var from := shoulder + Vector2(1, 1)
	var hand: Vector2
	if pose == "talk":
		hand = from + Vector2(6, -3)
		_thick(from, from + Vector2(3, 4), color)
		_thick(from + Vector2(3, 4), hand, color)
		_rect(roundi(hand.x), roundi(hand.y) - 1, 2, 2, color)
		_px(roundi(hand.x) + 1, roundi(hand.y) - 2, _lighter(color))
		return
	if pose == "bend":
		hand = from + Vector2(3, 11)
	elif carrying and _look["load"] in ["crate", "basket"]:
		hand = from + Vector2(1, -9)
	else:
		var swing := signf(step[0]) * 3.0 if absi(step[0]) > 2 else 1.0
		hand = from + Vector2(swing, 10)
	_thick(from, hand, color)
	_rect(roundi(hand.x), roundi(hand.y), 2, 2, color)
	# Munhequeira / detalhe de manga
	if _look.get("accent") != "":
		_px(roundi(from.x) + 1, roundi(from.y) + 2, _look["accent"])


func _body(pose: String, hip: Vector2, shoulder: Vector2, near_foot: Vector2, far_foot: Vector2) -> void:
	var cloth: String = _look["cloth"]
	var accent: String = _look["accent"]
	var skin: String = _look["skin"]
	var waist := Vector2(hip.x + (shoulder.x - hip.x) * .2, hip.y - 2)
	match _look["garment"]:
		"kilt":
			_poly([shoulder + Vector2(-4, 0), shoulder + Vector2(3, 0), shoulder + Vector2(4, 4), waist + Vector2(3, 0), waist + Vector2(-3, 0)], skin)
			_line(shoulder + Vector2(1, 3), waist + Vector2(1, -1), _darker(skin))
			_poly([waist + Vector2(-4, 0), waist + Vector2(4, 0), hip + Vector2(5, 6), hip + Vector2(-4, 6)], cloth)
			# Cinto ornamental com faixa suspensa
			_line(waist + Vector2(-4, 0), waist + Vector2(4, 0), accent)
			_line(waist + Vector2(1, 0), waist + Vector2(1, 4), accent)
			_line(hip + Vector2(1, 1), hip + Vector2(3, 6), _darker(cloth))
		"tunic":
			_poly([shoulder + Vector2(-4, 0), shoulder + Vector2(3, 0), shoulder + Vector2(4, 4), hip + Vector2(5, 8), hip + Vector2(-5, 8)], cloth)
			_line(hip + Vector2(1, 1), hip + Vector2(2, 7), _darker(cloth))
			_line(waist + Vector2(-4, 0), waist + Vector2(4, 0), accent)
			# Gola V decorada
			_line(shoulder + Vector2(-1, 0), shoulder + Vector2(0, 3), accent)
			_line(shoulder + Vector2(2, 0), shoulder + Vector2(1, 3), accent)
			if _look.get("stripes", false):
				for row in [3, 6]:
					_line(shoulder + Vector2(-3, row), shoulder + Vector2(3, row), accent)
		"robe":
			var hem := (near_foot.x + far_foot.x) * .25
			_poly([shoulder + Vector2(-4, 0), shoulder + Vector2(3, 0), shoulder + Vector2(4, 4), Vector2(hem + 5, -2), Vector2(hem - 5, -2)], cloth)
			# Pregas e dobras verticais de tecido egípcio
			_line(waist + Vector2(1, 2), Vector2(hem + 2, -3), _darker(cloth))
			_line(waist + Vector2(-2, 3), Vector2(hem - 3, -3), _darker(cloth))
			_line(shoulder + Vector2(0, 4), waist + Vector2(0, 0), _darker(cloth))
			# Barra decorada da túnica
			_line(Vector2(hem - 5, -2), Vector2(hem + 5, -2), accent)
			_line(Vector2(hem - 4, -3), Vector2(hem + 4, -3), _darker(cloth))
			_line(waist + Vector2(-4, 0), waist + Vector2(4, 0), accent)
			# Colar ou detalhe no peito (como nos retratos)
			if _look["id"] in ["escriba", "peregrina", "mercador"]:
				_line(shoulder + Vector2(-1, 1), shoulder + Vector2(2, 1), "gold")
			elif _look["id"] == "peixeira":
				# Cordão de junco cruzando o peito
				_line(shoulder + Vector2(-3, 1), waist + Vector2(2, 0), "clay")
	# Ombro e pescoço
	_rect(roundi(shoulder.x), roundi(shoulder.y) - 2, 2, 2, skin)


func _head(center: Vector2, pose: String) -> void:
	var skin: String = _look["skin"]
	var hair: String = _look["hair"]
	var hat: String = _look.get("hat", hair)
	var c := Vector2i(roundi(center.x), roundi(center.y))
	# Base anatômica do crânio com maçã do rosto
	_rect(c.x - 3, c.y - 4, 7, 8, skin)
	_rect(c.x - 2, c.y - 5, 5, 1, skin)
	_rect(c.x - 2, c.y + 4, 5, 1, skin)
	# Nariz e perfil
	_px(c.x + 4, c.y, skin)
	_px(c.x + 4, c.y - 1, _lighter(skin))
	# Olho egípcio com contorno kohl e esclera viva
	_px(c.x + 1, c.y - 1, "bone") # esclera
	_px(c.x + 2, c.y - 1, "ink")  # pupila
	_px(c.x + 2, c.y - 2, "ink")  # delineado superior
	_px(c.x + 3, c.y - 1, "ink")  # ponta externa do kohl
	# Sobrancelha
	_px(c.x + 1, c.y - 3, hair)
	_px(c.x + 2, c.y - 3, hair)
	# Boca expressiva
	if pose == "talk":
		_px(c.x + 3, c.y + 2, "ink") # boca aberta falando
	else:
		_px(c.x + 3, c.y + 2, _darker(skin))
	_px(c.x + 2, c.y + 3, _darker(skin)) # sombra do queixo

	if _look.get("beard", false):
		_rect(c.x - 1, c.y + 2, 5, 3, hair)
		_px(c.x + 3, c.y + 2, hair)
		_px(c.x + 4, c.y + 3, hair)
		if _look["id"] == "caravaneiro":
			# Mechas grisalhas como no retrato
			_px(c.x + 1, c.y + 3, "bone")
			_px(c.x + 2, c.y + 4, "bone")

	match _look["head"]:
		"band":
			_rect(c.x - 3, c.y - 5, 6, 3, hair)
			_rect(c.x - 4, c.y - 3, 2, 5, hair)
			_rect(c.x - 3, c.y - 3, 7, 1, _look["accent"])
		"cap":
			_rect(c.x - 3, c.y - 6, 7, 3, hat)
			_rect(c.x - 4, c.y - 4, 9, 1, hat)
			_rect(c.x - 4, c.y - 3, 2, 4, hair)
			_px(c.x + 2, c.y - 4, _look["accent"])
		"cloth":
			_rect(c.x - 3, c.y - 6, 7, 3, hat)
			_poly([Vector2(c.x - 4, c.y - 4), Vector2(c.x, c.y - 4), Vector2(c.x - 1, c.y + 6), Vector2(c.x - 5, c.y + 7)], hat)
			_line(Vector2(c.x - 3, c.y - 3), Vector2(c.x + 3, c.y - 3), _darker(hat))
			if _look["id"] == "peixeira":
				# Pino/broche de bronze prendendo o lenço
				_px(c.x - 1, c.y - 5, "gold")
			elif _look["id"] == "peregrina":
				# Véu com queda suave sobre o ombro e detalhe místico
				_line(Vector2(c.x - 4, c.y + 2), Vector2(c.x - 4, c.y + 8), hat)
				_px(c.x - 2, c.y - 4, "gold")
		"turban":
			_rect(c.x - 4, c.y - 8, 8, 5, hat)
			_rect(c.x - 3, c.y - 9, 6, 1, hat)
			_line(Vector2(c.x - 4, c.y - 6), Vector2(c.x + 3, c.y - 4), _look["accent"])
			_line(Vector2(c.x - 3, c.y - 8), Vector2(c.x + 2, c.y - 8), _darker(hat))
			if _look["id"] == "mercador":
				# Broche de mercador
				_px(c.x + 1, c.y - 6, "gold")
		"bald":
			_px(c.x - 1, c.y - 4, _lighter(skin))
			_px(c.x, c.y - 4, _lighter(skin))
			_rect(c.x - 3, c.y, 1, 2, hair)
			if _look["id"] == "escriba":
				# Pena de escriba de bronze atrás da orelha (como no retrato)
				_px(c.x - 2, c.y - 3, "gold")
				_px(c.x - 3, c.y - 5, "gold_dark")
		"hood":
			_poly([Vector2(c.x - 5, c.y + 6), Vector2(c.x - 5, c.y - 4), Vector2(c.x - 2, c.y - 7), Vector2(c.x + 3, c.y - 6), Vector2(c.x + 4, c.y - 3), Vector2(c.x + 1, c.y - 3), Vector2(c.x - 1, c.y + 6)], hat)
			_rect(c.x + 1, c.y - 2, 2, 1, hair)


func _load_behind(shoulder: Vector2, head: Vector2) -> void:
	match _look["load"]:
		"sack":
			# Saco de juta nas costas, amarrado em cima.
			var top := shoulder + Vector2(-9, -6)
			_poly([top + Vector2(2, 0), top + Vector2(6, -1), top + Vector2(8, 5), top + Vector2(7, 12), top + Vector2(1, 12), top + Vector2(-1, 6)], "wood_light")
			_line(top + Vector2(1, 6), top + Vector2(7, 6), "wood")
			_rect(roundi(top.x) + 3, roundi(top.y) - 2, 3, 2, "tan")
		"amphora":
			# Ânfora no ombro de lá, atrás da cabeça.
			var base := Vector2i(roundi(shoulder.x) - 6, roundi(shoulder.y) - 1)
			_poly([Vector2(base.x - 2, base.y), Vector2(base.x + 3, base.y - 1), Vector2(base.x + 4, base.y - 8), Vector2(base.x + 1, base.y - 13), Vector2(base.x - 2, base.y - 10), Vector2(base.x - 3, base.y - 4)], "clay")
			_line(Vector2(base.x + 1, base.y - 12), Vector2(base.x + 2, base.y - 15), "rust")
			_line(Vector2(base.x - 1, base.y - 3), Vector2(base.x + 2, base.y - 9), "rust")


func _load_front(shoulder: Vector2, head: Vector2) -> void:
	match _look["load"]:
		"crate":
			# Caixote na cabeça, firmado pela mão de cá.
			var corner := Vector2i(roundi(head.x) - 5, roundi(head.y) - 12)
			_rect(corner.x, corner.y, 11, 7, "wood_light")
			_rect(corner.x, corner.y, 11, 2, "tan")
			_rect(corner.x + 8, corner.y + 2, 3, 5, "wood")
			_line(Vector2(corner.x, corner.y + 4), Vector2(corner.x + 7, corner.y + 4), "wood_dark")
		"basket":
			var top := Vector2i(roundi(head.x) - 5, roundi(head.y) - 9)
			_rect(top.x, top.y + 1, 11, 3, "gold_dark")
			_rect(top.x + 1, top.y + 4, 9, 1, "tan")
			_rect(top.x + 2, top.y - 1, 3, 2, "teal_light")
			_rect(top.x + 6, top.y - 1, 3, 2, "lichen")


func _scroll(shoulder: Vector2) -> void:
	var at := Vector2i(roundi(shoulder.x) + 1, roundi(shoulder.y) + 6)
	_rect(at.x, at.y, 6, 2, "cream")
	_px(at.x + 6, at.y, "sand_dark")
	_px(at.x - 1, at.y + 1, "sand_dark")
	# Fita de amarração do papiro
	_px(at.x + 3, at.y, "rust")


# --- Desenho --------------------------------------------------------------------

## Luz direcional e ambient occlusion nos contornos
func _shade() -> void:
	var source := _img.duplicate() as Image
	for y in range(CELL.y):
		for x in range(1, CELL.x):
			var here := source.get_pixel(x, y)
			if here.a == 0: continue
			# Borda esquerda recebe iluminação
			if source.get_pixel(x - 1, y).a == 0:
				_img.set_pixel(x, y, here.lightened(.16))
			# Borda direita recebe sombra
			elif x + 1 < CELL.x and source.get_pixel(x + 1, y).a == 0:
				_img.set_pixel(x, y, here.darkened(.18))
			# Sombra superior sob queixo ou ombro
			elif y > 0 and source.get_pixel(x, y - 1).a == 0:
				_img.set_pixel(x, y, here.lightened(.08))


func _outline() -> void:
	var source := _img.duplicate() as Image
	for y in range(CELL.y):
		for x in range(CELL.x):
			if source.get_pixel(x, y).a > 0: continue
			for direction in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbor: Vector2i = Vector2i(x, y) + direction
				if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < CELL.x and neighbor.y < CELL.y and source.get_pixelv(neighbor).a > 0:
					_img.set_pixel(x, y, Color(PAL["ink"]))
					break


func _darker(name: String) -> String:
	return {"wood": "wood_dark", "wood_light": "wood", "tan": "wood_light", "linen": "sand", "sand": "sand_dark", "cream": "bone", "teal": "teal_dark", "teal_light": "teal", "rust": "clay", "olive": "olive_dark", "olive_light": "olive", "bone": "sand_dark", "stone_light": "stone", "stone": "stone_dark", "sage": "moss", "clay": "wood", "gold": "gold_dark", "gold_dark": "tan"}.get(name, name)


func _lighter(name: String) -> String:
	return {"wood": "wood_light", "wood_light": "tan", "tan": "gold_dark", "cream": "linen", "bone": "cream", "teal": "teal_light"}.get(name, name)


func _px(x: int, y: int, color: String) -> void:
	var point := PIVOT + Vector2i(x, y)
	if point.x >= 0 and point.y >= 0 and point.x < CELL.x and point.y < CELL.y:
		_img.set_pixelv(point, Color(PAL[color]))


func _rect(x: int, y: int, w: int, h: int, color: String) -> void:
	for row in range(h):
		for column in range(w):
			_px(x + column, y + row, color)


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


## Membro de 2 pixels de espessura.
func _thick(a: Vector2, b: Vector2, color: String) -> void:
	_line(a, b, color)
	_line(a + Vector2(1, 0), b + Vector2(1, 0), color)
