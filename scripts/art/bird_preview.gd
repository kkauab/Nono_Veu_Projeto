extends Node2D

## Pré-visualizador interativo das Aves e Papagaios de O Nono Véu.
## Mostra os sprites gerados, animações de asas e simulação de voo com sombra.

const Catalog = preload("res://scripts/world/bird_catalog.gd")
const TEXTURE_PATH := "res://assets/world/birds_v1.png"
const CELL_SIZE := Vector2(32, 32)

var texture: Texture2D
var birds: Array[Dictionary] = []
var clock: float = 0.0


func _ready() -> void:
	texture = load(TEXTURE_PATH) as Texture2D

	# Configurar 4 aves de demonstração em voo e pouso
	var species_list := ["parrot", "seagull", "falcon", "heron"]
	for i in range(species_list.size()):
		var sp: String = species_list[i]
		var data: Dictionary = Catalog.SPECIES[sp]
		birds.append({
			"id": sp,
			"name": data["name"],
			"row": data["row"],
			"size": data["size"],
			"base_pos": Vector2(180 + i * 180, 240),
			"pos": Vector2(180 + i * 180, 240),
			"altitude": 40.0 + i * 15.0,
			"target_alt": 40.0 + i * 15.0,
			"phase": float(i) * 1.5,
			"flying": true,
			"facing": 1.0,
			"frame": 0
		})


func _process(delta: float) -> void:
	clock += delta
	for b in birds:
		b["phase"] += delta * 2.5
		# Movimento circular orbital com sombra
		var radius_x := 65.0
		var radius_y := 32.0 # Proporção isométrica 2:1
		var angle: float = b["phase"]
		var ground: Vector2 = b["base_pos"] + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		b["pos"] = ground

		# Direção do olhar
		b["facing"] = -1.0 if cos(angle + 0.1) < cos(angle) else 1.0

		# Batimento de asas
		var wing_cycle := fposmod(clock * 6.0 + b["row"], 4.0)
		if wing_cycle < 1.0:
			b["frame"] = 2 # down
		elif wing_cycle < 2.0:
			b["frame"] = 3 # glide
		elif wing_cycle < 3.0:
			b["frame"] = 4 # up
		else:
			b["frame"] = 3 # glide

	queue_redraw()


func _draw() -> void:
	# Fundo temático do papiro / areia do deserto
	draw_rect(Rect2(0, 0, 960, 540), Color("1a2228"))

	# Título e Instruções
	draw_string(ThemeDB.fallback_font, Vector2(40, 50), "O NONO VÉU — SIMULAÇÃO DE AVES & PAPAGAIOS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e0bd7e"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 78), "Pseudo-3D Isométrico com Sombras Projetadas no Chão · 4 Espécies", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b4b298"))

	# Vitrine de Poses Estáticas
	var species_names := ["Papagaio Esmeralda (Oásis / Mercado)", "Gaivota do Porto (Cais / Docas)", "Falcão de Hórus (Alturas Sagradas)", "Garça do Bennu (Ilha Sagrada)"]
	var pose_names := ["Pousado", "Alerta", "Asas Baixo", "Planando", "Asas Cima"]

	for row in range(4):
		var y := 120 + row * 70
		draw_string(ThemeDB.fallback_font, Vector2(40, y + 20), species_names[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dbcfaa"))

		for col in range(5):
			var x := 340 + col * 75
			# Célula de fundo
			draw_rect(Rect2(x - 20, y - 10, 48, 48), Color(0.15, 0.2, 0.24, 0.6))
			draw_rect(Rect2(x - 20, y - 10, 48, 48), Color("3c5659"), false, 1.0)

			# Sprite em escala 1.5x
			var src_rect := Rect2(col * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
			draw_texture_rect_region(texture, Rect2(x - 16, y - 6, 40, 40), src_rect)

			if row == 0:
				draw_string(ThemeDB.fallback_font, Vector2(x - 14, 105), pose_names[col], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8c9380"))

	# Divisor
	draw_line(Vector2(40, 410), Vector2(920, 410), Color("3c5659"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(40, 435), "SIMULAÇÃO AO VIVO EM ÓRBITA ISOMÉTRICA (Chão + Altura Z):", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e0bd7e"))

	# Aves em Voo com Sombra no chão
	for b in birds:
		var ground: Vector2 = b["pos"] + Vector2(0, 180) # deslocar para área inferior
		var alt: float = b["altitude"]
		var bird_pos := ground - Vector2(0, alt)

		# 1. Sombra projetada
		var alpha := clampf(0.55 - alt * 0.0035, 0.15, 0.55)
		var scale_f := clampf(1.0 - alt * 0.003, 0.5, 1.0)
		var rx := 8.0 * scale_f * b["size"].x
		var ry := 4.0 * scale_f * b["size"].y

		var shadow_points := PackedVector2Array()
		for i in range(12):
			var a := (float(i) / 12.0) * TAU
			shadow_points.append(ground + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(shadow_points, Color(0.04, 0.08, 0.1, alpha))

		# 2. Linha guia sutil de altura
		draw_line(ground, bird_pos, Color(1, 1, 1, 0.08), 1.0)

		# 3. Sprite da Ave
		var src_rect := Rect2(b["frame"] * CELL_SIZE.x, b["row"] * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		var dest_rect := Rect2(bird_pos.x - 16 * b["facing"], bird_pos.y - 16, 32 * b["facing"], 32)
		draw_texture_rect_region(texture, dest_rect, src_rect)
