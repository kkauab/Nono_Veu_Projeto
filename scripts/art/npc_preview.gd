extends Node2D

## Visualizador de Moradores e Novos NPCs em Alta Fidelidade (O Nono Véu)
## Exibe os NPCs caminhando de corpo inteiro com deformação contínua e sem cortes.

const HIRES_TEXTURE: Texture2D = preload("res://assets/world/townsfolk_hires_v2.png")

const SHOWCASE_LOOKS := [12, 13, 14, 15, 2, 3, 6, 7]
const NAMES := [
	"Sacerdote", "Alquimista", "Sentinela", "Mercadora",
	"Peixeira", "Mercador", "Escriba", "Peregrina"
]
const ROLES := [
	"Santuário", "Cais do Cobre", "Guarita", "Mercado",
	"Cais Peixes", "Bancada Tâmaras", "Arquivo", "Santuário"
]

const PORTRAITS := [
	preload("res://assets/ui/dialogue_v15/sacerdote.png"),
	preload("res://assets/ui/dialogue_v15/alquimista.png"),
	preload("res://assets/ui/dialogue_v15/sentinela.png"),
	preload("res://assets/ui/dialogue_v15/mercadora.png"),
	preload("res://assets/ui/dialogue_v15/peixeira.png"),
	preload("res://assets/ui/dialogue_v15/mercador.png"),
	preload("res://assets/ui/dialogue_v15/escriba.png"),
	preload("res://assets/ui/dialogue_v15/peregrina.png")
]

var anim_time: float = 0.0
var animated_sprites: Array[Sprite2D] = []
var portrait_sprites: Array[Sprite2D] = []


func _ready() -> void:
	for i in range(SHOWCASE_LOOKS.size()):
		var look_idx: int = SHOWCASE_LOOKS[i]
		var col_idx := i % 4
		var row_idx := i / 4

		var x := 80 + col_idx * 160
		var y := 130 + row_idx * 140

		var sp := Sprite2D.new()
		sp.texture = HIRES_TEXTURE
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.hframes = 12
		sp.vframes = 16
		sp.frame = look_idx * 12 + 1
		sp.position = Vector2(x - 25, y)
		sp.scale = Vector2(1.8, 1.8)
		add_child(sp)
		animated_sprites.append(sp)

		var p_sp := Sprite2D.new()
		p_sp.texture = PORTRAITS[i]
		p_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		p_sp.position = Vector2(x + 35, y)
		p_sp.scale = Vector2(0.48, 0.48)
		add_child(p_sp)
		portrait_sprites.append(p_sp)


func _process(delta: float) -> void:
	anim_time += delta
	# Ciclo de caminhada (poses 1 a 4)
	var walk_frame := int(anim_time * 5.0) % 4 + 1
	for i in range(SHOWCASE_LOOKS.size()):
		var look_idx: int = SHOWCASE_LOOKS[i]
		animated_sprites[i].frame = look_idx * 12 + walk_frame
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("101a20"))

	draw_string(font, Vector2(24, 26), "O NONO VÉU — MORADORES DE CORPO INTEIRO (SEM CORTES)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("dec38a"))
	draw_string(font, Vector2(24, 44), "Sprites Completos da Cabeça aos Pés (128x128) com Deformação Contínua de Passada", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9fb8b2"))

	for i in range(SHOWCASE_LOOKS.size()):
		var col_idx := i % 4
		var row_idx := i / 4
		var x := 80 + col_idx * 160
		var y := 130 + row_idx * 140

		draw_string(font, Vector2(x - 60, y - 52), NAMES[i], HORIZONTAL_ALIGNMENT_CENTER, 130, 11, Color("ebd29b"))
		draw_string(font, Vector2(x - 60, y - 38), ROLES[i], HORIZONTAL_ALIGNMENT_CENTER, 130, 9, Color("8ca59f"))

		# Sombra sob os pés
		draw_rect(Rect2(Vector2(x - 39, y + 26), Vector2(28, 5)), Color(0, 0, 0, 0.35))
		# Borda do retrato
		draw_rect(Rect2(Vector2(x - 3, y - 46), Vector2(76, 92)), Color("dcc28c").darkened(0.5), false, 1.0)
