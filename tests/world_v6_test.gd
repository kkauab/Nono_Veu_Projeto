extends SceneTree
## The puzzle unit fixtures and the travelled exploration route use a QA slot.

var world: Node2D
var checks := 0
var failures: Array[String] = []
var physical_steps := 0
var catalog: Dictionary
var navigation: AStar2D
var navigation_ids: Dictionary = {}
var navigation_signature := ""

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("world_v6_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	catalog = PortLayout.tile_catalog()
	print("WORLD_V6_LAYOUT rooms=", PortLayout.ROOMS.size(), " tiles=", catalog.size(), " enemies=", PortLayout.ENEMY_SPAWNS.size())
	check(world.store.path.begins_with("user://qa/"), "New world test never uses the real save")
	check(PortLayout.ROOMS.size() == 27 and catalog.size() >= 4000, "Expanded port has 27 districts and at least 4000 floor cells")
	check(PortLayout.ENEMY_SPAWNS.size() == 38 and get_nodes_in_group("enemies").size() == 38, "Thirty-seven regular enemies and one boss spawn")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	var reachable := flood(Vector2i(PortLayout.MARKERS["hub_spawn"]))
	check(not reachable.has(Vector2i(-6, 23)), "Closed three-seal door has no bypass into the arena")
	for spawn in PortLayout.ENEMY_SPAWNS:
		check(catalog.has(Vector2i(spawn["tile"])), "Enemy starts on valid ground: " + spawn["id"])
	var all_regular_reachable := true
	for spawn in PortLayout.ENEMY_SPAWNS:
		if not spawn.get("boss", false) and not reachable.has(Vector2i(spawn["tile"])):
			all_regular_reachable = false
	check(all_regular_reachable, "All regular encounters can be reached before entering the boss arena")
	check(flood(Vector2i(PortLayout.MARKERS["hub_spawn"]), true).size() == catalog.size(), "Every floor cell belongs to the connected explored port once gates are open")
	for id in ["bells_clue", "bell_moon", "bell_sun", "bell_star", "water_clue", "valve_two", "valve_three", "valve_drain", "valve_reset", "water_altar", "stars_clue", "star_sun", "star_moon", "star_eye", "stars_altar", "caravan_rest", "cistern_rest"]:
		check(reachable.has(Vector2i(PortLayout.MARKERS[id])), "Exploration mechanism is reachable before the boss: " + id)
	check(not world.boss_entry_gate.opened and world.seals_found() == 0, "Fresh journey starts with no seals and a closed boss entrance")
	# Enumerate every bounded partial cistern/source-bit state through its real
	# reset interaction. Teleporting here is only a unit fixture, before travel.
	for level in range(7):
		for bits in range(4):
			world.store.data["puzzles"]["water"] = level
			world.store.data["puzzles"]["water_sources"] = [bool(bits & 1), bool(bits & 2)]
			var reset := item("valve_reset")
			world.player.position = reset.position
			var accepted: bool = world.activate(reset)
			check(accepted and world.store.data["puzzles"]["water"] == 0 and world.store.data["puzzles"]["water_sources"] == [false, false], "Recirculation recovers partial water fixture %d/%d" % [level, bits])
	world.player.reset_at(PortLayout.iso(PortLayout.MARKERS["hub_spawn"]))
	Input.action_press("sprint")
	print("WORLD_V6_STAGE northern clue and bells")
	if not await use_item("bells_clue"):
		await finish()
		return
	check(world.store.data["flags"]["bells_clue"], "Archive inscription is remembered")
	await use_item("bell_sun")
	check(world.store.data["puzzles"]["bells"].is_empty() and not world.store.data["flags"]["seal_bells"], "Wrong opening bell resets only the note sequence")
	for id in ["bell_moon", "bell_sun", "bell_star"]:
		if not await use_item(id):
			await finish()
			return
	check(world.seals_found() == 1 and not world.boss_entry_gate.opened, "One completed puzzle cannot open the boss door")
	print("WORLD_V6_STAGE cistern, valves and buried shrine")
	if not await use_item("water_clue"):
		await finish()
		return
	for id in ["valve_two", "valve_three"]:
		if not await use_item(id):
			await finish()
			return
	check(world.store.data["puzzles"]["water"] == 5, "The two one-use sources provide two plus three marks")
	var duplicate: bool = await use_item("valve_three", false)
	check(not duplicate and world.store.data["puzzles"]["water"] == 5, "A source cannot be spammed for free levels")
	await use_item("water_altar", false)
	check(not world.store.data["flags"]["seal_water"], "A wrong water level is rejected without losing progress")
	if not await use_item("valve_drain"):
		await finish()
		return
	check(world.store.data["puzzles"]["water"] == 4, "Drain removes exactly one mark")
	var partial := DemoSaveStore.new(world.store.path)
	check(partial.load_progress() and partial.data["puzzles"]["water"] == 4 and partial.data["puzzles"]["water_sources"] == [true, true], "Partial valve state survives a save reload")
	if not await use_item("water_altar"):
		await finish()
		return
	check(world.seals_found() == 2 and not world.boss_entry_gate.opened, "Two seals still leave the boss entrance closed")
	if not await use_item("cistern_rest"):
		await finish()
		return
	check(world.store.data["checkpoint"] == "cistern_rest", "Southern expedition has its own persistent checkpoint")
	print("WORLD_V6_STAGE far eastern beacon and observatory")
	if not await use_item("stars_clue"):
		await finish()
		return
	await use_item("stars_altar", false)
	check(not world.store.data["flags"]["seal_stars"], "Unaligned obelisks do not award the sky seal")
	for pair in [["star_sun", 1], ["star_moon", 3], ["star_eye", 2]]:
		for turn in range(pair[1]):
			if not await use_item(pair[0]):
				await finish()
				return
	if not await use_item("stars_altar"):
		await finish()
		return
	await physics_frame
	check(world.seals_found() == 3 and world.boss_entry_gate.opened and world.boss_entry_gate.get_node("Barrier").disabled, "All three explored seals physically remove the boss entrance collision")
	var reward_before: int = world.store.data["fragments"]
	check(not world.activate(item("stars_altar")) and world.store.data["fragments"] == reward_before, "A completed puzzle cannot duplicate its reward")
	var reloaded := DemoSaveStore.new(world.store.path)
	check(reloaded.load_progress() and reloaded.data["flags"]["seal_bells"] and reloaded.data["flags"]["seal_water"] and reloaded.data["flags"]["seal_stars"], "All mandatory discoveries survive reload")
	if not await walk_to(Vector2(-5, 23)):
		check(false, "Unlocked arena can be entered by actual movement")
	else:
		check(PortLayout.room_at(world.player.position) == "b1", "Actual exploration route reaches the boss arena after the puzzles")
	await finish()

func item(id: String) -> PortInteractable:
	for object in world.actors.get_children():
		if object is PortInteractable and object.item_id == id:
			return object
	return null

func use_item(id: String, expect_success: bool = true) -> bool:
	var object := item(id)
	if object == null:
		check(false, "Interaction exists: " + id)
		return false
	if not await walk_to(PortLayout.unproject(object.position)):
		check(false, "Physical route reaches: " + id)
		return false
	var accepted: bool = world.activate(object)
	if expect_success:
		check(accepted, "Puzzle interaction accepts a valid action: " + id)
	world.hud.show_overlay("")
	return accepted

func blocked(a: Vector2i, b: Vector2i) -> bool:
	if not world.shortcut.opened and mini(a.y, b.y) == 3 and maxi(a.y, b.y) == 4 and a.x in range(0, 3): return true
	if not world.aqueduct_gate.opened and mini(a.y, b.y) == 19 and maxi(a.y, b.y) == 20 and a.x in range(20, 22): return true
	if not world.boss_entry_gate.opened and mini(a.x, b.x) == 0 and maxi(a.x, b.x) == 1 and a.y in range(21, 25): return true
	if not world.exit_gate.opened and mini(a.x, b.x) == -13 and maxi(a.x, b.x) == -12 and a.y in range(24, 27): return true
	return false

func flood(start: Vector2i, ignore_gates: bool = false) -> Dictionary:
	var seen := {start: true}
	var pending := [start]
	while not pending.is_empty():
		var tile: Vector2i = pending.pop_back()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + direction
			if catalog.has(next) and not seen.has(next) and (ignore_gates or not blocked(tile, next)):
				seen[next] = true
				pending.append(next)
	return seen

func walk_to(tile: Vector2) -> bool:
	if "--logic-only" in OS.get_cmdline_user_args():
		world.player.position = PortLayout.iso(tile)
		return true
	var signature := "%s/%s/%s/%s" % [world.shortcut.opened, world.aqueduct_gate.opened, world.boss_entry_gate.opened, world.exit_gate.opened]
	if navigation == null or signature != navigation_signature:
		navigation_signature = signature
		navigation = AStar2D.new()
		navigation_ids.clear()
		var occupied: Dictionary = {}
		for prop in world.actors.get_children():
			if not prop is PortProp or (not prop.solid and prop.kind != "arch"):
				continue
			var at := PortLayout.unproject(prop.position)
			for x in range(floori(at.x) - 2, ceili(at.x) + 3):
				for y in range(floori(at.y) - 2, ceili(at.y) + 3):
					var cell := Vector2i(x, y)
					if prop.blocks_ground_point(PortLayout.iso(Vector2(cell)), 7):
						occupied[cell] = true
		for cell in catalog:
			if not occupied.has(cell):
				navigation_ids[cell] = navigation_ids.size()
				navigation.add_point(navigation_ids[cell], PortLayout.iso(Vector2(cell)))
		for cell in navigation_ids:
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = cell + direction
				if navigation_ids.has(next) and not blocked(cell, next): navigation.connect_points(navigation_ids[cell], navigation_ids[next])
	var path := navigation.get_point_path(navigation.get_closest_point(world.player.position), navigation.get_closest_point(PortLayout.iso(tile)))
	if path.is_empty():
		return false
	for goal in path:
		var arrived := false
		for step in range(160):
			world.hud.show_overlay("")
			var offset: Vector2 = goal - world.player.position
			if offset.length() < 6:
				arrived = true
				break
			for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
			if absf(offset.x) > 2: Input.action_press("move_right" if offset.x > 0 else "move_left")
			if absf(offset.y) > 2: Input.action_press("move_down" if offset.y > 0 else "move_up")
			physical_steps += 1
			await physics_frame
		if not arrived:
			print("WORLD_V6_ROUTE_BLOCKED target=", goal, " actual=", world.player.position, " tile=", PortLayout.unproject(world.player.position))
			return false
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	await physics_frame
	return world.player.position.distance_to(PortLayout.iso(tile)) < 35

func finish() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down", "sprint"]: Input.action_release(action)
	print("WORLD V6 CHECKS: %d passed=%d failures=%s physical_steps=%d logic_only=%s" % [checks, checks - failures.size(), failures, physical_steps, "--logic-only" in OS.get_cmdline_user_args()])
	paused = false
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
