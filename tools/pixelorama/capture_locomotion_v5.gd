extends SceneTree
## Captura as ações reais dos dois jogadores sobre um piso fixo.
## Executar com --fixed-fps 60; saída em qa/locomotion_v5/<direção>/.

const Inputs = preload("res://scripts/core/input_bindings.gd")

class MovingFloor extends Node2D:
	func _draw() -> void:
		for y in range(-12, 13):
			for x in range(-30, 80):
				var shade := Color("26393b") if posmod(x + y, 2) == 0 else Color("314448")
				draw_rect(Rect2(x * 32, y * 32, 32, 32), shade)
				draw_rect(Rect2(x * 32, y * 32, 32, 32), Color("40565a"), false, .5)
		for x in range(-15, 40):
			draw_line(Vector2(x * 64, -10), Vector2(x * 64, 10), Color("7a8d80"), 1)

class Annotation extends Node2D:
	var mode := "ANDAR"
	var direction := "right"
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 960, 94), Color("102025"))
		draw_string(font, Vector2(28, 34), "SENU / ANDAR · CORRER · ROLAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e3c791"))
		draw_string(font, Vector2(28, 66), mode + " · duas armas · piso parado, movimento real do jogador", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("b7cbc5"))
		draw_rect(Rect2(0, 454, 960, 86), Color("102025"))
		draw_string(font, Vector2(154, 493), "KHOPESH", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("dfc69c"))
		draw_string(font, Vector2(657, 493), "DUAS ADAGAS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("dfc69c"))
		draw_string(font, Vector2(28, 523), "Captura do Godot na escala da partida; o piso permite observar o apoio dos pés.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("94aba8"))

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	Inputs.install()
	Engine.max_fps = 60
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	var stage := Node2D.new()
	root.add_child(stage)
	stage.add_child(MovingFloor.new())
	var actors: Array[SenuPlayer] = []
	for i in range(2):
		var actor := SenuPlayer.new()
		stage.add_child(actor)
		actor.position = Vector2(-130 + i * 260, 0)
		actor.weapon_unlocked[1] = true
		actor.weapon_index = i
		actors.append(actor)
	var camera := Camera2D.new()
	camera.zoom = Vector2(2, 2)
	camera.position_smoothing_enabled = false
	stage.add_child(camera)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var annotation := Annotation.new()
	overlay.add_child(annotation)
	var direction := "right"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--direction="):
			direction = argument.trim_prefix("--direction=")
	if direction not in ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]:
		direction = "right"
	var move_actions: Array[String] = []
	if "left" in direction: move_actions.append("move_left")
	if "right" in direction: move_actions.append("move_right")
	if "up" in direction: move_actions.append("move_up")
	if "down" in direction: move_actions.append("move_down")
	if move_actions.is_empty(): move_actions.append("move_right")
	for action in move_actions: Input.action_press(action)
	var folder := "res://qa/locomotion_v5/" + direction
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var start := actors[0]._time
	var records: Array = []
	var image_count := 0
	var render_count := 0
	var roll_started := false
	while actors[0]._time - start < 3.4:
		await process_frame
		var elapsed := actors[0]._time - start
		if elapsed < 1.1:
			annotation.mode = "ANDAR"
		elif elapsed < 2.2:
			annotation.mode = "CORRER"
			Input.action_press("sprint")
		elif not roll_started:
			annotation.mode = "ROLAR"
			Input.action_release("sprint")
			for actor in actors: actor.try_dodge()
			for action in move_actions: Input.action_release(action)
			roll_started = true
		camera.position = (actors[0].position + actors[1].position) * .5 - Vector2(0, 38)
		annotation.queue_redraw()
		await RenderingServer.frame_post_draw
		if render_count % 2 == 0:
			root.get_texture().get_image().save_png(folder + "/frame_%03d.png" % image_count)
			var views: Array = []
			for actor in actors:
				var sample: Dictionary = actor._supplied_view.sample(actor)
				views.append({"position": [actor.position.x, actor.position.y], "time": actor._time,
					"state": sample.get("state", ""), "frame": sample.get("frame", -1),
					"frame_position": sample.get("frame_position", -1), "gait_phase": sample.get("gait_phase", 0)})
			records.append({"image": image_count, "elapsed": elapsed, "mode": annotation.mode, "actors": views})
			image_count += 1
		render_count += 1
	for action in move_actions: Input.action_release(action)
	Input.action_release("sprint")
	var metadata := FileAccess.open(folder + "/capture.json", FileAccess.WRITE)
	metadata.store_string(JSON.stringify({"direction": direction, "frames": records}, "\t"))
	metadata.close()
	print("SENU_LOCOMOTION_CAPTURE_OK direction=", direction, " frames=", image_count, " folder=", ProjectSettings.globalize_path(folder))
	quit()
