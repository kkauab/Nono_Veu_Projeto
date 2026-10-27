extends SceneTree
## Native-resolution interface QA; gameplay remains in its own pixel viewport.
func _initialize() -> void: call_deferred("_capture")

func _capture() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var mode := "gameplay"
	var height := 720
	var film := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--ui="): mode = argument.trim_prefix("--ui=")
		if argument.begins_with("--height="): height = int(argument.trim_prefix("--height="))
		if argument == "--film": film = true
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(height * 16 / 9, height)
	var world: Node2D = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	world.hud._hint_controls = false
	world.player.invulnerability_timer = 0
	world.hud.show_overlay("" if mode == "gameplay" else mode)
	if mode == "gameplay":
		world.hud.toast("+1 Fragmento de Nous · T abre a Árvore das Emanações", Color("e7c88d"), 20.0)
	await process_frame
	await process_frame
	var clock_at_start: float = world.hud._menu_clock
	var player_at_start: Vector2 = world.player.position
	var count := 56 if film else 1
	for index in range(count):
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var suffix := "_%02d" % index if film else ""
		picture.save_png("res://qa/hud_v8_%s_%dp%s.png" % [mode, height, suffix])
		if film: await create_timer(.1).timeout
	if film:
		print("MENU_V8_ANIMATION paused=", paused, " clock_advanced=", world.hud._menu_clock > clock_at_start + 4.0, " player_unchanged=", world.player.position == player_at_start)
	print("HUD_V8_CAPTURE_OK ", mode, " ", height, " frames=", count)
	quit()
