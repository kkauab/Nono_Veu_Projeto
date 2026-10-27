extends Node2D
## Separate art experiment. It never replaces the animated gameplay placeholder.

const ATLAS: Texture2D = preload("res://assets/sprites/senu_blockout.png")
const DIRECTIONS: Array[String] = ["S", "SE", "E", "NE", "N", "NO", "O", "SO"]
var selected_frame: int = 0
var small_preview: Sprite2D


func _ready() -> void:
	for index: int in range(8):
		var sprite := make_sprite(index, Vector2(46 + index * 78, 190), 1.0)
		add_child(sprite)
	small_preview = make_sprite(selected_frame, Vector2(320, 310), 0.5)
	add_child(small_preview)
	queue_redraw()


func make_sprite(index: int, feet: Vector2, sprite_scale: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = ATLAS
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.hframes = 8
	sprite.frame = index
	sprite.centered = false
	sprite.offset = -Vector2(32, 66)
	sprite.position = feet
	sprite.scale = Vector2.ONE * sprite_scale
	return sprite


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		selected_frame = (selected_frame + 1) % 8
	elif event.is_action_pressed("ui_left"):
		selected_frame = (selected_frame + 7) % 8
	else:
		return
	small_preview.frame = selected_frame
	queue_redraw()


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(640, 360)), Color("101a20"))
	draw_string(font, Vector2(28, 39), "SENU / ESTUDO ORTOGRÁFICO", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("dec38a"))
	draw_string(font, Vector2(28, 64), "Blender → PNG → Godot  |  Oito direções de idle", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("9fb8b2"))
	draw_string(font, Vector2(28, 87), "Prova de silhueta. Sem rig ou animação de combate.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("748e90"))
	for index: int in range(8):
		var feet := Vector2(46 + index * 78, 190)
		draw_line(feet + Vector2(-24, 0), feet + Vector2(24, 0), Color("33454c"))
		draw_line(feet + Vector2(0, -4), feet + Vector2(0, 4), Color("52665f"))
		draw_string(font, feet + Vector2(-7, 25), DIRECTIONS[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("becec2"))
	draw_line(Vector2(28, 234), Vector2(612, 234), Color("33454c"))
	draw_string(font, Vector2(28, 260), "64 × 80 por quadro / 1x acima", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fb8b2"))
	draw_string(font, Vector2(28, 281), "Pivô dos pés: 32, 66", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("748e90"))
	draw_colored_polygon(PackedVector2Array([Vector2(300, 310), Vector2(320, 302), Vector2(340, 310), Vector2(320, 318)]), Color("253b3f"))
	draw_string(font, Vector2(370, 287), "Escala de jogo: 0,5x", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fb8b2"))
	draw_string(font, Vector2(370, 308), "Setas: girar / " + DIRECTIONS[selected_frame], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("748e90"))
	draw_string(font, Vector2(28, 345), "ESTUDO ORIGINAL • ARTE PROVISÓRIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("807259"))
