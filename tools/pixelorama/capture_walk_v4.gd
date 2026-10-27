extends SceneTree
## Prancha animada renderizada pelo Godot; não usa o save ou a cena da partida.

class WalkStage extends Node2D:
	var actors: Array[SenuPlayer] = []
	func _ready() -> void:
		for index in range(2):
			var actor := SenuPlayer.new()
			add_child(actor)
			actor.set_physics_process(false)
			actor.controls_enabled = false
			actor.weapon_unlocked[1] = true
			actor.weapon_index = index
			actor.position = Vector2(180 + index * 340, 285)
			actor.scale = Vector2(3.5, 3.5)
			actor.facing = Vector2(-1, 1).normalized()
			actor.velocity = Vector2(actor.facing.x, actor.facing.y * .7) * actor.move_speed
			actor._time = 10
			actor._supplied_view.sample(actor)
			actors.append(actor)
	func advance(delta: float) -> void:
		for actor in actors:
			actor._time += delta
			actor.queue_redraw()
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 720, 350), Color("111c22"))
		draw_string(font, Vector2(30, 40), "SENU / CAMINHADA", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e3c791"))
		draw_string(font, Vector2(30, 67), "12 quadros por direção · animação renderizada no Godot", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a3b9b7"))
		for i in range(2):
			draw_line(Vector2(65 + i * 340, 285), Vector2(295 + i * 340, 285), Color("304348"))
			draw_string(font, Vector2(100 + i * 340, 325), "KHOPESH" if i == 0 else "DUAS ADAGAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d1c2a1"))

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.content_scale_size = Vector2i(720, 350)
	root.size = Vector2i(720, 350)
	var stage := WalkStage.new()
	root.add_child(stage)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/walk_v4"))
	for index in range(24):
		stage.advance(.66 / 12)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/walk_v4/frame_%02d.png" % index)
	print("SENU_WALK_CAPTURE_OK 24 rendered frames")
	quit()
