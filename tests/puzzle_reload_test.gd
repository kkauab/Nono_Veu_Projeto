extends SceneTree
## Puzzle feedback and puzzle state after reopening a save, in a QA slot.

var world: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("puzzle_reload_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	check(world.store.path.begins_with("user://qa/"), "Puzzle test never uses the real save")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	await _bells()
	await _stars_after_reload()
	print("PUZZLE RELOAD CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _bells() -> void:
	world.store.data["flags"]["bells_clue"] = true
	await use_item("bell_sun")
	check(world.hud.message.contains("harmonia") and world.store.data["puzzles"]["bells"].is_empty(), "A bell out of order shows the broken-harmony warning")
	await use_item("bell_moon")
	check(world.hud.message.contains("1 de 3"), "The first right bell shows the progress")
	await use_item("bell_moon")
	check(world.hud.message.contains("harmonia") and world.hud.message.contains("1 de 3") and world.store.data["puzzles"]["bells"] == ["moon"], "Repeating the Moon restarts the sequence and says it counted")
	await use_item("bell_sun")
	await use_item("bell_star")
	check(world.store.data["flags"]["seal_bells"], "Moon, Dawn and Star still award the voice seal")

func _stars_after_reload() -> void:
	world.store.data["flags"]["stars_clue"] = true
	world.store.data["puzzles"]["stars"] = [1, 3, 2]
	check(world.store.save_progress(), "Aligned obelisks are saved")
	var reopened := DemoSaveStore.new(world.store.path)
	check(reopened.load_progress(), "The saved journey reopens")
	world.store = reopened
	world.refresh_seals()
	check(await use_item("stars_altar") and world.store.data["flags"]["seal_stars"], "The altar accepts an alignment made before reopening the game")

func use_item(id: String) -> bool:
	var target: PortInteractable
	for object in world.actors.get_children():
		if object is PortInteractable and object.item_id == id:
			target = object
	if target == null:
		check(false, "Interaction exists: " + id)
		return false
	world.player.position = target.position
	await physics_frame
	return world.activate(target)
