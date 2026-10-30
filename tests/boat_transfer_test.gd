extends SceneTree

## Real boarding/landing, pause and interruption on both piers.
## Uses only a fresh user://qa slot; append -- --qa.
const MainScene = preload("res://scenes/boot/main.tscn")
const Sea = preload("res://scripts/world/sea.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
var world: Node2D
var checks := 0
var failures: Array[String] = []
var layer := 0
var mask := 0
var qa_path := ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	if not "--qa" in OS.get_cmdline_user_args():
		push_error("Boat transfer test requires -- --qa")
		quit(1)
		return
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(2))
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	qa_path = "user://qa/boat_transfer_%d_%d/world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_path.get_base_dir()))
	world.store.path = qa_path
	for flag in ["boat_sailed", "isle_landed"]:
		if flag not in world.store.data["collected"]:
			world.store.data["collected"].append(flag)
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	layer = world.player.collision_layer
	mask = world.player.collision_mask
	for dock in ["sabu", "bennu"]:
		await _normal_transfer(dock)
		for phase in ["board", "align", "land"]:
			await _cancel_transfer(dock, phase)
	_check(not FileAccess.file_exists(qa_path), "Boarding, landing and cancelled transfers never write a save")
	print("BOAT TRANSFER RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _prepare(dock: String) -> void:
	paused = false
	world.hud.show_overlay("")
	world.store.data["checkpoint"] = "isle_rest" if dock == "bennu" else "hub"
	world.player.reset_at(Layout.iso(Sea.DOCKS[dock]["land"]))
	Sea.respawn(world)
	await process_frame
	await physics_frame


func _view() -> Node2D:
	return world.player.get_meta("sea_transfer") as Node2D if world.player.has_meta("sea_transfer") else null


func _normal_transfer(dock: String) -> void:
	await _prepare(dock)
	var player: SenuPlayer = world.player
	var start: Vector2 = player.global_position
	_check(Sea.board(world), "%s accepts boarding" % dock)
	_check(world.sea_busy and not player.controls_enabled and not player.visible, "%s hides the walking body and locks controls for boarding" % dock)
	_check(player.collision_layer == 0 and player.collision_mask == 0, "%s removes the walking collision during boarding" % dock)
	_check(not Sea.board(world), "%s ignores repeated boarding while busy" % dock)
	await create_timer(Sea.HOP * .3).timeout
	var view := _view()
	_check(is_instance_valid(view) and view.name == "SenuSeaTransfer" and view.get("state") == "board", "%s has a dedicated boarding sprite" % dock)
	_check(player.global_position.distance_to(start) > 1.0, "%s moves the logical ground pivot toward the boat" % dock)
	if is_instance_valid(view):
		var position_before: Vector2 = player.global_position
		var progress_before := float(view.get("progress"))
		paused = true
		await create_timer(.12, true, false, true).timeout
		_check(player.global_position == position_before and is_equal_approx(float(view.get("progress")), progress_before), "%s pause freezes both boarding movement and sprite" % dock)
		paused = false
		if "--capture-transfer" in OS.get_cmdline_user_args():
			await _capture("%s_board" % dock)
	await create_timer(Sea.HOP + .1).timeout
	await process_frame
	_check(world.at_sea and not world.sea_busy and world.boat.rider == player, "%s boarding finishes with one seated rider" % dock)
	_check(not player.has_meta("sea_transfer") and _transfer_count() == 0, "%s boarding removes the transient sprite" % dock)
	_check(not player.visible and player.global_position.distance_to(world.boat.global_position) < 1.0, "%s seated body stays hidden and follows the boat" % dock)
	Sea.land(world, dock)
	_check(world.sea_busy and world.boat.rider == player, "%s keeps the rower seated while aligning to the pier" % dock)
	await create_timer(.3 + Sea.HOP * .3).timeout
	view = _view()
	_check(is_instance_valid(view) and view.get("state") == "land" and world.boat.rider == null, "%s changes from the seated rower to its landing sprite" % dock)
	if is_instance_valid(view):
		var position_before: Vector2 = player.global_position
		var progress_before := float(view.get("progress"))
		paused = true
		await create_timer(.12, true, false, true).timeout
		_check(player.global_position == position_before and is_equal_approx(float(view.get("progress")), progress_before), "%s pause freezes landing movement and sprite" % dock)
		paused = false
		if "--capture-transfer" in OS.get_cmdline_user_args():
			await _capture("%s_land" % dock)
	await create_timer(Sea.HOP + .1).timeout
	await process_frame
	_assert_released("%s normal landing" % dock)
	_check(player.global_position.distance_to(Layout.iso(Sea.DOCKS[dock]["land"])) < 1.0, "%s returns the ground pivot to the pier" % dock)


func _cancel_transfer(dock: String, phase: String) -> void:
	await _prepare(dock)
	_check(Sea.board(world), "%s starts %s interruption fixture" % [dock, phase])
	if phase != "board":
		await create_timer(Sea.HOP + .1).timeout
		Sea.land(world, dock)
		await create_timer(.1 if phase == "align" else .3 + Sea.HOP * .3).timeout
	else:
		await create_timer(Sea.HOP * .3).timeout
	var player: SenuPlayer = world.player
	var tween: Tween = world.get_meta("sea_tween") if world.has_meta("sea_tween") else null
	var respawn_at := Layout.iso(Sea.DOCKS[dock]["land"])
	# Same order as port_demo._on_player_died: reset first, release second.
	player.reset_at(respawn_at)
	Sea.respawn(world)
	await process_frame
	_assert_released("%s cancelled %s" % [dock, phase])
	_check(tween == null or not tween.is_valid(), "%s cancelled %s kills the old tween" % [dock, phase])
	await create_timer(Sea.HOP + .4).timeout
	_check(player.global_position.distance_to(respawn_at) < 1.0 and not world.at_sea and not world.sea_busy, "%s cancelled %s has no late movement or seating callback" % [dock, phase])
	_check(world.boat_dock == dock and world.boat.global_position.distance_to(Layout.iso(Sea.DOCKS[dock]["water"])) < 1.0, "%s cancelled %s leaves the boat at the checkpoint pier" % [dock, phase])


func _assert_released(label: String) -> void:
	var player: SenuPlayer = world.player
	_check(player.visible and player.controls_enabled and not world.at_sea and not world.sea_busy, label + " restores the walking body and controls")
	_check(player.collision_layer == layer and player.collision_mask == mask, label + " restores the exact collision masks")
	_check(not player.has_meta("sea_transfer") and not player.has_meta("sea_collision") and _transfer_count() == 0, label + " removes temporary nodes and metadata")
	_check(world.boat.rider == null and not world.boat.rowing, label + " leaves no duplicate seated rider")


func _transfer_count() -> int:
	var count := 0
	for node in world.actors.get_children():
		if node.name == "SenuSeaTransfer":
			count += 1
	return count


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/boat_senu"))
	root.get_texture().get_image().save_png("res://qa/boat_senu/%s.png" % name)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("FAIL " + label)
