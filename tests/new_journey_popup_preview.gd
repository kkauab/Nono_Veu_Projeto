extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH,true)
	var world = Main.instantiate()
	root.add_child(world)
	await process_frame
	Engine.max_fps = 30
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/new_journey_popup"))
	for dimensions in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		world.hud.show_overlay("new_journey")
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/new_journey_popup/popup_%d.png" % dimensions.x)
		print("POPUP CAPTURE ",dimensions)
	world.queue_free()
	await process_frame
	quit()
