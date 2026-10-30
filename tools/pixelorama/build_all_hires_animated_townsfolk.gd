extends SceneTree

const OUT_TEXTURE := "res://assets/world/townsfolk_hires_v2.png"
const OUT_MANIFEST := "res://assets/world/townsfolk_hires_v2_manifest.json"

const Palette = preload("res://tools/pixelorama/build_townsfolk_v1.gd")

const CELL := Vector2i(128, 128)
const PIVOT := Vector2i(64, 112)
const TARGET_HEIGHT := 52.0

var palette: Array[Color] = []
var cached := {}

func _init() -> void:
	for hex in Palette.PAL.values():
		palette.append(Color(hex))

	var src_port := Image.load_from_file(ProjectSettings.globalize_path("res://qa/port_citizens_clean.png"))
	var src_new := Image.load_from_file(ProjectSettings.globalize_path("res://qa/new_npcs_clean.png"))

	if src_port == null or src_new == null:
		print("ERROR loading sources")
		quit(1)
		return

	# Caixas dos personagens de port_citizens:
	# 0: Estivador (center ~149)
	# 1: Carregador (center ~368)
	# 2: Marinheiro (center ~588)
	# 3: Velho (center ~809)
	# 4: Aguadeira (center ~1042)
	# 5: Remador (center ~1249)
	var port_boxes := [
		Rect2i(31, 34, 237, 631),    # 0 Estivador
		Rect2i(262, 106, 213, 562),  # 1 Carregador
		Rect2i(496, 103, 185, 565),  # 2 Marinheiro
		Rect2i(685, 123, 249, 545),  # 3 Velho
		Rect2i(939, 132, 207, 533),  # 4 Aguadeira
		Rect2i(1149, 112, 201, 556)  # 5 Remador
	]

	# Caixas dos personagens de new_npcs:
	# 0: Sacerdote, 1: Alquimista, 2: Sentinela, 3: Mercadora
	var new_boxes := [
		Rect2i(63, 58, 305, 674),    # Sacerdote
		Rect2i(383, 60, 325, 671),   # Alquimista
		Rect2i(743, 48, 298, 684),   # Sentinela
		Rect2i(1083, 63, 251, 668)   # Mercadora
	]

	# 16 Looks do catálogo oficial (em scripts/world/port_life_catalog.gd)
	# 0: estivador (port 0)
	# 1: carregador (port 1)
	# 2: peixeira (dialogue peixeira)
	# 3: mercador (dialogue tamareiro)
	# 4: marinheiro (port 2)
	# 5: remador (port 5)
	# 6: escriba (dialogue escriba)
	# 7: peregrina (dialogue peregrina)
	# 8: velho (port 3)
	# 9: aguadeira (port 4)
	# 10: padeira (dialogue padeira)
	# 11: caravaneiro (dialogue cervejeiro)
	# 12: sacerdote (new 0)
	# 13: alquimista (new 1)
	# 14: sentinela (new 2)
	# 15: mercadora (new 3)

	var poses := ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "talk", "carry_idle", "carry_1", "carry_2", "carry_3", "carry_4", "bend"]

	var sheet := Image.create_empty(CELL.x * poses.size(), CELL.y * 16, false, Image.FORMAT_RGBA8)

	for row in range(16):
		var raw_img: Image = null
		if row == 0: raw_img = src_port.get_region(port_boxes[0])
		elif row == 1: raw_img = src_port.get_region(port_boxes[1])
		elif row == 4: raw_img = src_port.get_region(port_boxes[2])
		elif row == 5: raw_img = src_port.get_region(port_boxes[5])
		elif row == 8: raw_img = src_port.get_region(port_boxes[3])
		elif row == 9: raw_img = src_port.get_region(port_boxes[4])
		elif row == 12: raw_img = src_new.get_region(new_boxes[0])
		elif row == 13: raw_img = src_new.get_region(new_boxes[1])
		elif row == 14: raw_img = src_new.get_region(new_boxes[2])
		elif row == 15: raw_img = src_new.get_region(new_boxes[3])
		else:
			# Para os comerciantes de bancada/interiores (peixeira, mercador, escriba, peregrina, padeira, caravaneiro)
			var path_map := {
				2: "res://assets/ui/dialogue_v15/peixeira.png",
				3: "res://assets/ui/dialogue_v15/tamareiro.png",
				6: "res://assets/ui/dialogue_v15/escriba.png",
				7: "res://assets/ui/dialogue_v15/peregrina.png",
				10: "res://assets/ui/dialogue_v15/padeira.png",
				11: "res://assets/ui/dialogue_v15/cervejeiro.png"
			}
			raw_img = Image.load_from_file(ProjectSettings.globalize_path(path_map[row]))

		assert(raw_img != null, "Falha ao carregar textura para look " + str(row))

		# Normaliza e redimensiona para altura de Senu (~52px)
		var scale_f := TARGET_HEIGHT / float(raw_img.get_height())
		var nw := maxi(18, roundi(raw_img.get_width() * scale_f))
		var nh := roundi(TARGET_HEIGHT)

		var base := raw_img.duplicate() as Image
		base.resize(nw, nh, Image.INTERPOLATE_LANCZOS)

		# Normaliza para a paleta oficial de 33 cores
		for py in range(nh):
			for px in range(nw):
				var c := base.get_pixel(px, py)
				if c.a > 0.35:
					c.a = 1.0
					base.set_pixel(px, py, _color(c))
				else:
					base.set_pixel(px, py, Color(0, 0, 0, 0))

		# Divide em 3 camadas anatômicas:
		# Cabeça (0 a h_head)
		# Tronco/Braços (h_head a h_torso)
		# Pernas/Pés (h_torso a nh)
		var h_head := roundi(nh * 0.32)
		var h_torso := roundi(nh * 0.68)
		var h_legs := nh - h_torso

		var head_img := base.get_region(Rect2i(0, 0, nw, h_head))
		var torso_img := base.get_region(Rect2i(0, h_head, nw, h_torso - h_head))
		var legs_img := base.get_region(Rect2i(0, h_torso, nw, h_legs))

		# Gera cada uma das 12 poses com articulação real de passos e gestos
		for col in range(poses.size()):
			var p_name: String = poses[col]
			var cel := Image.create_empty(CELL.x, CELL.y, false, Image.FORMAT_RGBA8)

			var bx := PIVOT.x - nw / 2
			var by := PIVOT.y - nh

			# Offsets anatômicos para cada pose
			var head_off := Vector2i.ZERO
			var torso_off := Vector2i.ZERO
			var leg_left_off := Vector2i.ZERO
			var leg_right_off := Vector2i.ZERO
			var arm_gesture_off := Vector2i.ZERO

			match p_name:
				"idle", "carry_idle":
					head_off = Vector2i(0, 0)
					torso_off = Vector2i(0, 0)
				"walk_1", "carry_1":
					# Passo 1: Descida do tronco, perna direita para frente, perna esquerda para trás
					head_off = Vector2i(1, 1)
					torso_off = Vector2i(1, 1)
					leg_right_off = Vector2i(3, 0)   # pé frente
					leg_left_off = Vector2i(-3, -1)   # pé trás
				"walk_2", "carry_2":
					# Passo 2: Elevação da passada, pé de trás recolhido no ar
					head_off = Vector2i(0, -1)
					torso_off = Vector2i(0, -1)
					leg_right_off = Vector2i(0, 0)
					leg_left_off = Vector2i(-1, -2)   # pé levantado do chão
				"walk_3", "carry_3":
					# Passo 3: Descida do tronco, perna esquerda para frente, perna direita para trás
					head_off = Vector2i(-1, 1)
					torso_off = Vector2i(-1, 1)
					leg_right_off = Vector2i(-3, -1)
					leg_left_off = Vector2i(3, 0)
				"walk_4", "carry_4":
					# Passo 4: Elevação da passada oposta
					head_off = Vector2i(0, -1)
					torso_off = Vector2i(0, -1)
					leg_right_off = Vector2i(1, -2)
					leg_left_off = Vector2i(0, 0)
				"talk":
					# Gesto expressivo: tronco reto, cabeça atenta, mão/braço elevado
					head_off = Vector2i(1, 0)
					torso_off = Vector2i(0, 0)
					arm_gesture_off = Vector2i(3, -3)
				"bend":
					# Reverência / oração / abaixar para carga
					head_off = Vector2i(4, 6)
					torso_off = Vector2i(3, 4)

			# Montagem composta da pose
			# 1. Pernas (divididas em metade esquerda e metade direita para stride)
			var half_w := nw / 2
			var leg_left := legs_img.get_region(Rect2i(0, 0, half_w, h_legs))
			var leg_right := legs_img.get_region(Rect2i(half_w, 0, nw - half_w, h_legs))

			cel.blit_rect(leg_left, Rect2i(Vector2i.ZERO, leg_left.get_size()), Vector2i(bx + leg_left_off.x, by + h_torso + leg_left_off.y))
			cel.blit_rect(leg_right, Rect2i(Vector2i.ZERO, leg_right.get_size()), Vector2i(bx + half_w + leg_right_off.x, by + h_torso + leg_right_off.y))

			# 2. Tronco
			cel.blit_rect(torso_img, Rect2i(Vector2i.ZERO, torso_img.get_size()), Vector2i(bx + torso_off.x, by + h_head + torso_off.y))

			# Se for pose de falar, sobrepõe gesto de braço
			if arm_gesture_off != Vector2i.ZERO:
				var arm_part := torso_img.get_region(Rect2i(roundi(nw * 0.5), 0, roundi(nw * 0.5), roundi((h_torso - h_head) * 0.6)))
				cel.blit_rect(arm_part, Rect2i(Vector2i.ZERO, arm_part.get_size()), Vector2i(bx + roundi(nw * 0.5) + arm_gesture_off.x, by + h_head + arm_gesture_off.y))

			# 3. Cabeça
			cel.blit_rect(head_img, Rect2i(Vector2i.ZERO, head_img.get_size()), Vector2i(bx + head_off.x, by + head_off.y))

			# Blit no sheet principal
			sheet.blit_rect(cel, Rect2i(Vector2i.ZERO, CELL), Vector2i(col * CELL.x, row * CELL.y))

	var out_p := ProjectSettings.globalize_path(OUT_TEXTURE)
	sheet.save_png(out_p)
	print("Master animated townsfolk sheet saved to: ", out_p)

	# Manifesto
	var looks_names := [
		"estivador", "carregador", "peixeira", "mercador",
		"marinheiro", "remador", "escriba", "peregrina",
		"velho", "aguadeira", "padeira", "caravaneiro",
		"sacerdote", "alquimista", "sentinela", "mercadora"
	]
	var manifest := {
		"version": 2,
		"texture": OUT_TEXTURE,
		"cell": [CELL.x, CELL.y],
		"pivot": [PIVOT.x, PIVOT.y],
		"poses": poses,
		"looks": looks_names
	}
	var mf := FileAccess.open(ProjectSettings.globalize_path(OUT_MANIFEST), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest, "  ") + "\n")
	mf.close()

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
