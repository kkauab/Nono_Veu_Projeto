extends SceneTree
## Production title renderers and hover/click signals; QA progress only.
## Real pointer and keyboard events are covered by title_menu_test.gd.
const Main = preload("res://scenes/boot/main.tscn")
const OUT := "res://qa/title_menu"
func _initialize() -> void: _run.call_deferred()
func pointer(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 30
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	var world = Main.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("intro")
	# Fixture-only: show all four choices as in the player's reference picture.
	world.store.loaded_existing = true
	world.hud.show_overlay("intro")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Engine.max_fps = 30
	var voice_trace: Array[String] = []
	for button in world.hud._buttons:
		# PNG encoding can take longer than a screen frame. Sample presentation
		# explicitly at 30 Hz so the review animation keeps the runtime cadence.
		button.set_process(false)
		button._first_pointer_entry = false
		button.selection_sounded.connect(func(): voice_trace.append(button.text))
	pointer(Vector2(20,20))
	for frame in range(144):
		if frame in [12,42,72,102]:
			var index: int = (frame-12)/30
			world.hud._buttons[index].mouse_entered.emit()
		if frame in [34,64,94,124]:
			var index: int = (frame-34)/30
			world.hud._buttons[index].mouse_exited.emit()
		for button in world.hud._buttons: button._process(1.0/30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "/frame_%03d.png" % frame)
	print("TITLE MENU PREVIEW: 144 frames, sound entries=",voice_trace)
	# Check the compact window without activating or writing progress.
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	await process_frame
	await process_frame
	world.hud._buttons[2].mouse_entered.emit()
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/menu_960.png")
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	await process_frame
	world.hud.show_overlay("pause")
	for i in range(4): await process_frame
	var action: Button = world.hud.get_node("PauseNotebook/SenuAction_dodge")
	var click_visual: Control = action.get_node("PixelButtonFeedback")
	click_visual.set_process(false)
	action.mouse_entered.emit()
	action.button_down.emit()
	click_visual._process(.10)
	for i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "/caderno_click.png")
	action.button_up.emit()
	world.queue_free()
	await process_frame
	quit()
