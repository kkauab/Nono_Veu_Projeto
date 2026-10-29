extends SceneTree
## Exercises actual viewport mouse/keyboard input against Main's pause notebook.
## The only store used is the fresh --qa store created by port_demo.
const Main = preload("res://scenes/boot/main.tscn")
var checks := 0
var failures: Array[String] = []
var world

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Use -- --qa")
		quit(1)
		return
	root.size = Vector2i(960, 540)
	# Synthetic mouse positions below are viewport coordinates. Keep the test
	# window and its canvas the same size rather than stretching 1280 into 960.
	root.content_scale_size = Vector2i(960, 540)
	world = Main.instantiate()
	# Freeze actors but keep the notebook's explicit ALWAYS controls processing.
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.store.data["fragments"] = 5
	world.store.data["skills"] = []
	world._apply_upgrades(true)
	var original_damage: int = world.player.damage_bonus
	world.hud.show_overlay("tree")
	await process_frame
	await process_frame
	var page = world.hud.find_child("SkillBookPage", true, false)
	_check(page != null and paused, "The actual tree overlay opens the paused notebook skill page")
	if page == null:
		_finish()
		return
	_check(page.nodes.size() == 13, "The real notebook exposes all 13 catalog nodes")
	await _click(page.nodes["vontade"])
	_check(page.selected_id == "vontade" and world.store.data["skills"].is_empty(), "Clicking the real node selects without buying")
	page.hold_button.pressed.emit()
	_check(world.store.data["fragments"] == 5 and world.store.data["skills"].is_empty(), "A direct pressed callback cannot bypass confirmation")
	var at: Vector2 = page.hold_button.get_global_rect().get_center()
	await _mouse(at, true)
	await create_timer(.28).timeout
	_check(page.holding and page.hold_progress > 0 and page.hold_progress < 1, "The actual GUI mouse-down starts a partial timed hold while paused")
	await _mouse(at, false)
	await create_timer(1.6).timeout
	_check(not page.holding and page.hold_progress == 0 and world.store.data["fragments"] == 5, "Mouse release cancels; waiting afterward never completes the purchase")
	at = page.hold_button.get_global_rect().get_center()
	await _mouse(at, true)
	await create_timer(1.7).timeout
	_check("vontade" in world.store.data["skills"] and world.store.data["fragments"] == 4, "One uninterrupted GUI hold buys the selected catalog skill at its real cost")
	_check(world.player.damage_bonus == original_damage + 4, "The real world immediately applies the learned skill to Senu")
	await create_timer(.25).timeout
	_check(world.store.data["fragments"] == 4 and world.store.data["skills"].count("vontade") == 1, "Keeping the input held cannot repeat the purchase")
	await _mouse(at, false)
	_check(not FileAccess.file_exists(world.store.path), "Learning through the notebook does not write a tower save")
	await _click(page.nodes["materia"])
	at = page.hold_button.get_global_rect().get_center()
	await _mouse(at, true)
	await create_timer(.3).timeout
	world.hud.show_overlay("pause")
	await process_frame
	await create_timer(1.6).timeout
	await _mouse(at, false)
	_check(not "materia" in world.store.data["skills"] and world.store.data["fragments"] == 4, "Leaving the notebook page cancels the pending GUI purchase")
	world.hud.show_overlay("tree")
	await process_frame
	await process_frame
	page = world.hud.find_child("SkillBookPage", true, false)
	page.select_skill("materia")
	page.hold_button.grab_focus()
	await _key(KEY_SPACE, true)
	await create_timer(.3).timeout
	_check(page.holding and page.hold_progress > 0, "Space starts the focused hold button without requiring a mouse")
	await _key(KEY_SPACE, false)
	_check(not page.holding and not "materia" in world.store.data["skills"], "Releasing Space also cancels the purchase")
	page.select_skill("intelecto")
	page.hold_button.grab_focus()
	await _key(KEY_ENTER, true)
	await create_timer(1.7).timeout
	await _key(KEY_ENTER, false)
	_check("intelecto" in world.store.data["skills"] and world.store.data["fragments"] == 2, "Enter can complete one real purchase at the correct cost")
	_check(is_equal_approx(world.player.power_cooldown_scale, .8), "The keyboard purchase applies its real cooldown effect")
	page.select_skill("lamina_ascendente")
	_check(page.hold_button.disabled, "An unavailable real node explains its prerequisite state and disables confirmation")
	_finish()

func _click(button: Button) -> void:
	var at := button.get_global_rect().get_center()
	await _mouse(at, true)
	await _mouse(at, false)

func _mouse(at: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	await process_frame

func _key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _finish() -> void:
	paused = false
	if is_instance_valid(world): world.queue_free()
	await process_frame
	print("SKILL BOOK INTEGRATION checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
