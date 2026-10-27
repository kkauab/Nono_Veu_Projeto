extends SceneTree
## Capturas reais dos menus sobre o mundo, em slot de QA separado.

func _initialize() -> void: call_deferred("_capture")

func _capture() -> void:
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	var mode := "pause"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui="): mode = argument.trim_prefix("--ui=")
	var scene := load("res://scenes/boot/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	if mode == "map":
		for room in PortLayout.ROOMS:
			if room["id"] not in world.store.data["visited"]: world.store.data["visited"].append(room["id"])
	world.hud.show_overlay("" if mode == "gameplay" else mode)
	await process_frame
	if mode == "pause":
		for child in world.hud.get_children():
			if child is Button and child.text == "Controles": child.grab_focus()
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://qa/hud_v6_%s.png" % mode
	root.get_texture().get_image().save_png(path)
	print("HUD_V6_CAPTURE_OK ", ProjectSettings.globalize_path(path))
	quit()
