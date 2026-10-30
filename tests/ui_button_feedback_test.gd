extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
const Feedback = preload("res://scripts/ui/ui_button_feedback.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
func click(button: BaseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = motion.position
	event.global_position = motion.position
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.size = Vector2i(960,540)
	root.content_scale_size = root.size
	var world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	await process_frame
	var hud: Control = world.hud
	var pool: Node = root.get_meta(Feedback.POOL_KEY)
	check(world.store.path.begins_with("user://qa/"), "Only isolated QA progress is loaded")
	check(pool.process_mode == Node.PROCESS_MODE_ALWAYS and pool._voices.size() == 4, "One paused-safe audio pool handles clicks across UI rebuilds")
	var initial_data := JSON.stringify(world.store.data)
	for page in ["intro","pause","settings","controls","inventory","map","tree","journal","exit"]:
		hud.show_overlay(page)
		for frame in range(4): await process_frame
		var buttons := hud.find_children("*","BaseButton",true,false)
		check(not buttons.is_empty(), page + " contains native controls")
		for button: BaseButton in buttons:
			var custom: bool = button.get_meta("title_menu_presentation",false)
			var visuals := button.get_node_or_null("PixelButtonFeedback")
			check(custom or visuals != null, page + ": feedback is attached to " + button.name)
			var original_rect := button.get_global_rect()
			var original_font: Font = button.get_theme_font("font")
			var before: int = pool.play_count
			button.button_down.emit()
			button.button_up.emit()
			check(pool.play_count == before + (0 if button.disabled else 1), page + ": exactly one sound per enabled press on " + button.name)
			if not button.disabled:
				check(pool.last_screen == page and is_equal_approx(pool.last_pitch, Feedback.SOUND_PROFILES[page].x), page + ": sound follows its own screen before the action changes pages")
			check(button.get_global_rect() == original_rect and button.get_theme_font("font") == original_font, page + ": animation cannot change text or hit areas")
			if not button.disabled and visuals != null:
				check(visuals.clicks > 0 and visuals._pulse < 1, page + ": click starts the common visual pulse")
			if button.disabled and visuals != null:
				check(visuals.clicks == 0, page + ": disabled control stays silent and inactive")
	check(JSON.stringify(world.store.data) == initial_data, "Button feedback alone never changes journey progress or grants skills/items")
	hud.show_overlay("settings")
	for frame in range(4): await process_frame
	var controls: Button = hud.get_node("PauseNotebook/NotebookControls")
	var before: int = pool.play_count
	await click(controls)
	check(hud.overlay == "controls" and pool.play_count == before+1, "Actual click opens the controls page and sounds only once")
	check(pool._voices.any(func(voice): return voice.playing), "The sound continues after the clicked button is removed by navigation")
	check(root.get_meta(Feedback.POOL_KEY) == pool, "Navigation reuses its original audio pool")
	check(pool.last_screen == "settings", "A navigation click uses the screen it leaves, not the destination")
	# Controls appearing later in a separate dialog receive feedback automatically.
	hud.show_conversation("O pescador", "PESCADOR — A memória permanece.", "npc_fisher")
	for frame in range(4): await process_frame
	for button: BaseButton in hud.find_children("*","BaseButton",true,false):
		check(button.has_meta(Feedback.ATTACHED_KEY), "Dialogue continuation gets the same click presentation")
		button.button_down.emit()
		button.button_up.emit()
		check(pool.last_screen == "dialog" and is_equal_approx(pool.last_pitch, 1.11), "Dialogue continuation uses its lighter speaking-screen tick")
	hud.show_overlay("")
	world.queue_free()
	await process_frame
	print("UI BUTTON FEEDBACK checks=%d failures=%s" % [checks,failures])
	quit(0 if failures.is_empty() else 1)
