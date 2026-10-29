extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
var checks := 0
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	world.hud.show_overlay("pause")
	var hud: Control = world.hud
	var book: Control = hud.get_node("PauseNotebook")
	_check(paused and book.page == "pause", "Pause opens the Senu page of the notebook")
	_check(book.get_node("SenuPreview").source == world.player, "Character preview uses the real player's sprite model and equipment")
	var old_state := JSON.stringify(world.store.data)
	var old_position: Vector2 = world.player.position
	var old_health: int = world.player.health
	book.get_node("SenuAction_attack").pressed.emit()
	book.get_node("SenuAction_dodge").pressed.emit()
	book.get_node("SenuAction_parry").pressed.emit()
	_check(world.player.position == old_position and world.player.health == old_health and JSON.stringify(world.store.data) == old_state, "Preview actions cannot move Senu, deal damage or change progress")
	_check(book.get_node_or_null("NotebookTab_controls") == null and book.get_node_or_null("NotebookTab_save") == null, "Controls and saving are not top-level pause options")
	for page in ["journal", "map", "tree", "inventory", "settings", "exit"]:
		book.get_node("NotebookTab_" + page).pressed.emit()
		book = hud.get_node("PauseNotebook")
		_check(book.page == page and paused, page + " is a page in the same paused notebook")
		_check(book.get_node_or_null("NotebookTab_pause") != null, page + " can return to the character page")
	hud.show_overlay("settings")
	book = hud.get_node("PauseNotebook")
	book.get_node("NotebookControls").pressed.emit()
	_check(hud.overlay == "controls" and hud.get_node("PauseNotebook").page == "controls", "Controls opens inside the settings notebook")
	hud._back()
	_check(hud.overlay == "settings", "Returning from controls leads to settings")
	hud._back()
	_check(hud.overlay == "" and not paused, "Escape closes the notebook and resumes play")
	hud.show_overlay("intro")
	hud.show_overlay("settings")
	hud._back()
	_check(hud.overlay == "intro", "Settings opened from the title screen returns to the title")
	hud.show_overlay("")
	hud.show_overlay("pause")
	book = hud.get_node("PauseNotebook")
	book.get_node("NotebookResume").pressed.emit()
	_check(not paused and hud.overlay == "", "Continue on the Senu page resumes the world")
	world.queue_free()
	await process_frame
	print("PAUSE NOTEBOOK checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures.append(caption)
		push_error(caption)
