extends Node2D

## Pré-visualizador interativo de Cães e Gatos de O Nono Véu.
## Mostra os sprites dos gatos (Mau e Bastet) e cães (Tesem e Anúbis)
## em repouso, caminhada e reação com sombras de solo.

const Catalog = preload("res://scripts/world/animal_catalog.gd")
const TEXTURE_PATH := "res://assets/world/animals_v1.png"
const CELL_SIZE := Vector2(32, 32)

var texture: Texture2D
var animals: Array[Dictionary] = []
var clock: float = 0.0


func _ready() -> void:
	texture = load(TEXTURE_PATH) as Texture2D

	# Configurar 4 animais de demonstração (2 gatos, 2 cães)
	var breed_keys := ["cat_black", "cat_mau", "dog_tesem", "dog_guard"]
	for i in range(breed_keys.size()):
		var b_id: String = breed_keys[i]
		var data: Dictionary = Catalog.BREEDS[b_id]
		animals.append({
			"id": b_id,
			"name": data["name"],
			"type": data["type"],
			"row": data["row"],
			"scale": data["scale"],
			"base_pos": Vector2(180 + i * 190, 470),
			"pos": Vector2(180 + i * 190, 470),
			"facing": 1.0,
			"phase": float(i) * 1.8,
			"step": 0
		})


func _process(delta: float) -> void:
	clock += delta
	for a in animals:
		a["phase"] += delta * 1.8
		var radius_x := 50.0
		var radius_y := 24.0 # Proporção isométrica 2:1
		var angle: float = a["phase"]
		a["pos"] = a["base_pos"] + Vector2(cos(angle) * radius_x, sin(angle) * radius_y)
		a["facing"] = -1.0 if cos(angle + 0.1) < cos(angle) else 1.0

		var walk_cycle := fposmod(clock * 5.0 + a["row"], 4.0)
		a["step"] = int(walk_cycle)

	queue_redraw()


func _draw() -> void:
	# Fundo temático
	draw_rect(Rect2(0, 0, 960, 540), Color("1a2228"))

	# Título
	draw_string(ThemeDB.fallback_font, Vector2(40, 50), "O NONO VÉU — FAUNA TERRESTRE (CÃES & GATOS EGÍPCIOS)", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e0bd7e"))
	draw_string(ThemeDB.fallback_font, Vector2(40, 78), "Gatos de Bastet / Mau Egípcio e Cães Tesem Real / Guarda de Anúbis · 7 Poses", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("b4b298"))

	# Tabela de Poses
	var breed_labels := [
		"Gato de Bastet (Preto / Sagrado)",
		"Gato Mau Egípcio (Malhado / Ocre)",
		"Cão Tesem Real (Galgo Egípcio)",
		"Cão de Guarda Anúbis (Preto / Tan)"
	]
	var pose_labels := ["Sentado", "Dormindo", "Passo 1", "Passo 2", "Passo 3", "Passo 4", "Reação"]

	for row in range(4):
		var y := 125 + row * 65
		draw_string(ThemeDB.fallback_font, Vector2(40, y + 20), breed_labels[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("dbcfaa"))

		for col in range(7):
			var x := 330 + col * 75
			draw_rect(Rect2(x - 18, y - 10, 48, 48), Color(0.15, 0.2, 0.24, 0.6))
			draw_rect(Rect2(x - 18, y - 10, 48, 48), Color("3c5659"), false, 1.0)

			var src_rect := Rect2(col * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
			draw_texture_rect_region(texture, Rect2(x - 14, y - 6, 40, 40), src_rect)

			if row == 0:
				draw_string(ThemeDB.fallback_font, Vector2(x - 12, 108), pose_labels[col], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8c9380"))

	# Divisor
	draw_line(Vector2(40, 395), Vector2(920, 395), Color("3c5659"), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(40, 420), "SIMULAÇÃO AO VIVO EM PATRULHA ISOMÉTRICA COM SOMBRA DE SOLO:", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e0bd7e"))

	# Simulação ao vivo
	for a in animals:
		var ground: Vector2 = a["pos"]
		var is_cat: bool = a["type"] == "cat"
		var sc: Vector2 = a["scale"]

		# Sombra isométrica
		var rx := (8.0 if is_cat else 12.0) * sc.x
		var ry := (4.0 if is_cat else 6.0) * sc.y
		var shadow_points := PackedVector2Array()
		for i in range(12):
			var ang := (float(i) / 12.0) * TAU
			shadow_points.append(ground + Vector2(cos(ang) * rx, sin(ang) * ry))
		draw_colored_polygon(shadow_points, Color(0.05, 0.09, 0.12, 0.45))

		# Sprite
		var frame: int = 2 + a["step"]
		var src_rect := Rect2(frame * CELL_SIZE.x, a["row"] * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		var dest_rect := Rect2(ground.x - 16 * a["facing"], ground.y - 28, 32 * a["facing"], 32)
		draw_texture_rect_region(texture, dest_rect, src_rect)
