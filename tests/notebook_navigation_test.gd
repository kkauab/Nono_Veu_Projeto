extends SceneTree
## Real GUI events, including N entry and clicks across embedded notebook pages.
const Main = preload("res://scenes/boot/main.tscn")
var checks := 0
var failures: Array[String] = []
var world

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	var hud: Control = world.hud
	hud.show_overlay("")
	await _key(KEY_N)
	_check(hud.overlay == "journal" and paused, "N opens missions and pauses the world")
	for target in ["pause", "map", "tree", "inventory", "settings", "exit", "journal"]:
		var book: Control = hud.get_node("PauseNotebook")
		await _click(book.get_node("NotebookTab_" + target))
		_check(hud.overlay == target and paused, "A real click reaches " + target + " from the notebook")
	await _key(KEY_M)
	_check(hud.overlay == "map" and paused, "M switches from missions to map")
	await _key(KEY_N)
	_check(hud.overlay == "journal" and paused, "N switches from map back to missions")
	await _key(KEY_ESCAPE)
	_check(hud.overlay == "" and not paused, "Escape resumes after opening missions with N")
	await _key(KEY_N)
	await _key(KEY_N)
	_check(hud.overlay == "" and not paused, "N also closes its own page")
	world.store.data["collected"].append("quest_started_merit")
	hud.show_overlay("journal")
	await process_frame
	var journal: Control = hud.find_child("QuestJournalBook", true, false)
	_check(journal.rows.has("main_port") and journal.rows.has("merit"), "Main journey and a known side request are both present")
	await _click(journal.rows["merit"])
	_check(journal.selected_id == "merit", "Real clicks still select side requests inside the journal")
	await _click(hud.get_node("PauseNotebook/NotebookClose"))
	_check(hud.overlay == "" and not paused, "The close button is reachable above the embedded journal")
	_check(not FileAccess.file_exists(world.store.path), "Browsing and closing the notebook never writes a journey save")
	paused = false
	world.queue_free()
	await process_frame
	print("NOTEBOOK NAVIGATION checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _key(code: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame

func _click(button: Button) -> void:
	await process_frame
	var at := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await process_frame

func _check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures.append(caption)
		push_error(caption)
