extends SceneTree
const Opening = preload("res://scripts/ui/opening_cutscene.gd")
## Exercise the real new-game button, continuous hold, session state and scene reload.
var checks := 0
var failures: Array[String] = []
var world: Node2D

func _initialize() -> void: call_deferred("_run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)

func button(caption: String) -> Button:
	for child in world.hud.find_children("*", "Button", true, false):
		if child.text == caption: return child
	return null

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	root.title = "O Nono Véu · teste da abertura obrigatória"
	check(not DemoSaveStore.fresh_data()["flags"]["opening_seen"], "Every fresh journey starts with its opening still to be shown")
	var fixture_path := "user://qa/opening_%d.json" % Time.get_ticks_usec()
	var legacy := DemoSaveStore.new(fixture_path)
	legacy.data["flags"].erase("opening_seen")
	check(legacy.save_progress(), "Legacy opening fixture uses an isolated save")
	var old_progress := DemoSaveStore.new(fixture_path)
	check(old_progress.load_progress() and old_progress.data["flags"]["opening_seen"], "Continuing an older journey does not force a new-game cinematic into its middle")
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.hud.show_overlay("intro")
	await process_frame
	await process_frame
	check(button("Assistir à abertura") == null, "Opening is not a separate optional menu item")
	var new_game := button("Nova jornada")
	check(new_game != null, "Native new-game button exists")
	if new_game == null:
		quit(1)
		return
	new_game.pressed.emit()
	await process_frame
	check(world.opening_active and paused and not world.hud.visible, "Clicking new game automatically shows the mandatory cinematic")
	check(world._opening_player.resources_ready(), "The opening uses its own imported RPG atlas")
	check(not world.player.controls_enabled and not world.world_container.visible, "Gameplay and its HUD are suspended during the film")
	var initial_position: Vector2 = world.player.position
	var initial_clock: float = world._opening_player.elapsed
	await create_timer(.2).timeout
	check(world._opening_player.elapsed > initial_clock and world.player.position == initial_position, "The film animates while the real player stays still")
	world._opening_player.call("seek", Opening.DIALOGUE_CUES[0])
	await process_frame
	await process_frame
	check(world._opening_player.dialogue_active and world._opening_player.dialogue_index == 0, "The arrival pauses for the first readable RPG dialogue")
	key(KEY_ENTER, true)
	key(KEY_ENTER, false)
	await process_frame
	check(world._opening_player.dialogue_active and world._opening_player.dialogue_index == 0 and world._opening_player.dialogue_visible_characters == world._opening_player._dialogue_text().length(), "First Enter reveals the current line without closing it")
	key(KEY_E, true)
	key(KEY_E, false)
	await create_timer(Opening.DIALOGUE_CUES[1]-Opening.DIALOGUE_CUES[0]+.15).timeout
	check(world._opening_player.dialogue_active and world._opening_player.dialogue_index == 1, "E advances to Senu's reply after the revealed line")
	key(KEY_ESCAPE, true)
	await create_timer(.1).timeout
	key(KEY_ESCAPE, false)
	check(world.opening_active, "Escape cannot bypass the required hold-to-skip")
	key(KEY_SPACE, true)
	await create_timer(1.0).timeout
	key(KEY_SPACE, false)
	await create_timer(.1).timeout
	check(world.opening_active, "A one-second press does not skip")
	key(KEY_SPACE, true)
	await create_timer(1.4).timeout
	key(KEY_SPACE, false)
	await create_timer(.1).timeout
	check(world.opening_active, "Separated presses do not accumulate into the three-second hold")
	key(KEY_SPACE, true)
	await create_timer(2.90).timeout
	check(world.opening_active and world.player.position == initial_position, "Even 2.9 continuous seconds cannot skip early")
	await create_timer(.25).timeout
	key(KEY_SPACE, false)
	await process_frame
	check(not world.opening_active and not paused and world.player.controls_enabled, "Three continuous seconds skip and restore player control")
	check(world.hud.visible and world.world_container.visible and world.hud.overlay == "", "World rendering, HUD and input resume together")
	check(world.store.data["flags"]["opening_seen"], "Completed or skipped opening is recorded in the current session")
	check(not FileAccess.file_exists(world.store.path), "Completing the opening does not anchor progress before a tower")
	world._opening_finished()
	check(not paused and not world.opening_active, "Repeated finish callbacks do not reopen or pause the world")
	# Start a second NEW journey. This must show the cinematic again, even
	# after the first journey has already recorded its completed opening.
	world.hud.show_overlay("intro")
	button("Nova jornada").pressed.emit()
	if world.hud.overlay == "new_journey": button("Confirmar").pressed.emit()
	for frame in range(4): await process_frame
	world = current_scene
	check(world.opening_active and paused and not world.store.data["flags"]["opening_seen"], "Starting another new game always shows the opening again")
	world._opening_player.set_process(false)
	world._opening_player.call("seek", Opening.DIALOGUE_CUES[0]-.01)
	world._opening_player._process(.02)
	await process_frame
	await process_frame
	for line in range(Opening.DIALOGUE_COUNT):
		key(KEY_ENTER, true)
		key(KEY_ENTER, false)
		await process_frame
		key(KEY_ENTER, true)
		key(KEY_ENTER, false)
		await process_frame
		if line<Opening.DIALOGUE_COUNT-1:
			world._opening_player._process(Opening.DIALOGUE_CUES[line+1]-world._opening_player.elapsed+.01)
	check(not world._opening_player.dialogue_active and world._opening_player.dialogue_index == Opening.DIALOGUE_COUNT-1 and world._opening_player.elapsed >= 12, "Every dialogue leads to the final walk instead of skipping gameplay context")
	world._opening_player.call("seek", Opening.DURATION - .04)
	world._opening_player._process(.05)
	await create_timer(.15).timeout
	check(not world.opening_active and not paused and world.hud.overlay == "", "Natural end of the full timeline also enters the game")
	print("OPENING FLOW V9 CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	paused = false
	quit(0 if failures.is_empty() else 1)
