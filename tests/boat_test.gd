extends SceneTree

# Barco de Sabu: píeres, embarque, remada com inércia, costa sólida, ânforas,
# travessia até a Ilha do Bennu, atracação e o barco voltando ao píer do lado do
# santuário. Precisa do mundo real: rode com -- --qa. Com --capture-boat (Godot
# com janela), salva qa/barco_pier.png, qa/barco_remando.png e qa/barco_ilha.png.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Sea = preload("res://scripts/world/sea.gd")
const Boat = preload("res://scripts/world/sea_boat.gd")
const IsleLayout = preload("res://scripts/world/isle_layout.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const FramePacing = preload("res://scripts/core/frame_pacing.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D
var catalog: Dictionary


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE boat test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/boat_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	catalog = Layout.tile_catalog()
	# Os encontros não fazem parte deste teste.
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	_test_placement()
	_test_smoothness()
	await _test_board()
	await _test_rowing()
	await _test_shore()
	await _test_amphora()
	await _test_crossing()
	await _test_respawn()
	print("BOAT RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_placement() -> void:
	for id in Sea.DOCKS:
		var dock: Dictionary = Sea.DOCKS[id]
		_check(catalog.has(Vector2i(Vector2(dock["land"]).round())), "%s: the pier end is walkable ground" % id)
		_check(not _on_land(Layout.iso(dock["water"])), "%s: the mooring spot is water" % id)
		var space: PhysicsDirectSpaceState2D = world.get_world_2d().direct_space_state
		var probe := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = Boat.RADIUS
		probe.shape = shape
		probe.transform = Transform2D(0, Layout.iso(dock["water"]))
		probe.collision_mask = 1
		_check(space.intersect_shape(probe).is_empty(), "%s: the moored hull touches no shore" % id)
	_check(IsleLayout.is_land(Sea.DOCKS["bennu"]["land"]), "the Bennu pier belongs to the island")
	for tile in Sea.AMPHORAE + Sea.SEA_ROCKS:
		_check(not _on_land(Layout.iso(tile)), "sea piece floats on open water: %s" % tile)
	var boat: Node2D = world.boat
	_check(world.boat_dock == "sabu" and boat.global_position.distance_to(Layout.iso(Sea.DOCKS["sabu"]["water"])) < 1, "a journey from the port starts with the boat at Sabu's pier")
	_check(boat.frame() == Boat.FRAME_EMPTY, "the moored boat is drawn empty")
	_check(_post("sabu").active and not _post("bennu").active, "only the pier holding the boat offers to board")


func _test_smoothness() -> void:
	# Ritmo dos quadros: sem o limite, a física acompanha o monitor.
	_check(FramePacing.ticks_for(165.0, false) == 165 and FramePacing.ticks_for(144.0, false) == 144 and FramePacing.ticks_for(59.94, false) == 60, "physics steps follow the monitor when uncapped")
	_check(FramePacing.ticks_for(165.0, true) == 60 and FramePacing.ticks_for(-1.0, false) == 60 and FramePacing.ticks_for(360.0, false) == FramePacing.MAX_TICKS, "the 60 cap, unknown monitors and very fast ones stay bounded")
	_check(world.hud.get("_limit_fps") == false, "the 60-frame cap is off by default")
	# Navios ancorados: linha d'água, balanço e anéis.
	var ships := 0
	var seated := 0
	for node in world.actors.get_children():
		if node is PortProp and node.kind == "boat":
			ships += 1
			var material := node.material as ShaderMaterial
			if material != null and material.shader == Sea.MOORED_SHADER and node.has_node("ShipWater") and material.get_shader_parameter("hull_bottom") != null:
				seated += 1
	_check(ships > 0 and seated == ships, "every moored ship sits in the water (%d of %d)" % [seated, ships])
	var keel := Sea.keel_line(PackedFloat32Array([NAN, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 2.0, NAN]))
	_check(absf(keel.x - 1.0) < .01 and absf(keel.y - 9.0) < .01, "the keel is the straight line through the middle of the hull, not the raised ends")
	_check(Boat.ROW_FRAMES == 8 and SeaArt.frame_count("boat_v1", "boat_00") == Boat.FRAME_EMPTY + 1, "the boat sheet has idle, eight stroke frames and the empty boat")


func _test_board() -> void:
	var player: SenuPlayer = world.player
	player.position = Layout.iso(Sea.DOCKS["sabu"]["land"])
	# Como o port_demo faz nos teleportes: sem isso, a suavização da câmera passa do
	# ponto quando a janela recém-aberta engasga nos primeiros quadros.
	player.get_node("IsometricCamera").reset_smoothing()
	await physics_frame
	await physics_frame
	_check(world.nearest == _post("sabu"), "standing on the pier end highlights the mooring post")
	if "--capture-boat" in OS.get_cmdline_user_args():
		await _capture("barco_pier")
	_check(world.activate(_post("sabu")), "Senu boards Sabu's boat")
	_check(world.sea_busy and not player.controls_enabled, "controls wait for the hop")
	_check(not world.activate(_post("sabu")), "a second press during the hop is ignored")
	await create_timer(.6).timeout
	await physics_frame
	var boat: Node2D = world.boat
	_check(world.at_sea and not world.sea_busy, "the hop ends with Senu at sea")
	_check(boat.rider == player and not player.visible, "Senu sits in the boat; the walking body is hidden")
	_check(player.collision_layer == 0 and player.collision_mask == 0, "the rider has no body of its own")
	_check(player.global_position.distance_to(boat.global_position) < 1, "the rider follows the boat")
	_check(boat.frame() == Boat.FRAME_IDLE, "an idle rower holds the oars still")
	_check("boat_sailed" in world.store.data["collected"], "the first boarding is remembered")
	world.hud.show_overlay("")


func _test_rowing() -> void:
	var boat: Node2D = world.boat
	var start: Vector2 = boat.global_position
	var heading_before: float = boat.heading
	Input.action_press("move_down")
	var strokes := {}
	var saw_speed := 0.0
	for frame in range(90):
		await physics_frame
		if boat.frame() >= 1 and boat.frame() <= Boat.ROW_FRAMES:
			strokes[boat.frame()] = true
		saw_speed = maxf(saw_speed, boat.velocity.length())
	Input.action_release("move_down")
	_check(boat.global_position.y - start.y > 60, "holding down rows the boat away from the pier (%.0f px)" % (boat.global_position.y - start.y))
	_check(strokes.size() == Boat.ROW_FRAMES, "rowing plays all %d stroke frames (%d seen)" % [Boat.ROW_FRAMES, strokes.size()])
	_check(saw_speed > 60 and saw_speed <= Boat.CRUISE * Boat.ISO_Y + 1, "the boat gathers speed up to its cruise pace (%.0f)" % saw_speed)
	_check(absf(angle_difference(boat.heading, Boat.ground_angle(Vector2(0, 1)))) < .2 and absf(angle_difference(heading_before, boat.heading)) > .2, "the bow turns toward the course")
	var camera: Camera2D = world.player.get_node("IsometricCamera")
	_check(camera.get_screen_center_position().distance_to(boat.global_position) < 60, "the camera keeps the boat in view")
	var wake: Node2D = world.layout.get_node("BoatWake")
	_check(not wake.trail.is_empty(), "the boat leaves a wake")
	var drifting: Vector2 = boat.global_position
	await create_timer(.4).timeout
	_check(boat.global_position.distance_to(drifting) > 4 and boat.velocity.length() < saw_speed, "released, the boat glides and slows")
	if "--capture-boat" in OS.get_cmdline_user_args():
		await _capture("barco_remando")


func _test_shore() -> void:
	# Remar contra o Embarcadouro Velho: a costa segura o barco na água.
	var boat: Node2D = world.boat
	boat.global_position = Layout.iso(Vector2(29.5, 39.5))
	boat.velocity = Vector2.ZERO
	var dry := false
	Input.action_press("move_up")
	Input.action_press("move_right")
	for frame in range(120):
		await physics_frame
		dry = dry or _on_land(boat.global_position)
	Input.action_release("move_up")
	Input.action_release("move_right")
	_check(not dry, "rowing into the pier never lifts the boat onto land")
	_check(world.at_sea, "bumping the shore does not end the voyage")


func _test_amphora() -> void:
	var boat: Node2D = world.boat
	var coins := Economy.coins(world.store.data)
	boat.global_position = Layout.iso(Sea.AMPHORAE[0]) + Vector2(-10, 4)
	boat.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	_check("isle_amphora_1" in world.store.data["collected"], "sailing over a drifting amphora collects it")
	_check(Economy.coins(world.store.data) == coins + Sea.AMPHORA_COINS, "an amphora pays %d óbolos" % Sea.AMPHORA_COINS)
	await physics_frame
	await physics_frame
	_check(Economy.coins(world.store.data) == coins + Sea.AMPHORA_COINS, "an amphora pays only once")


func _test_crossing() -> void:
	# Do píer de Sabu até o do Bennu, remando de verdade: um piloto aponta o barco
	# para a amarração da ilha e a física decide se há caminho.
	var boat: Node2D = world.boat
	boat.global_position = Layout.iso(Sea.DOCKS["sabu"]["water"])
	boat.velocity = Vector2.ZERO
	boat.set_physics_process(false)
	var target := Layout.iso(Sea.DOCKS["bennu"]["water"])
	var elapsed := 0.0
	while elapsed < 25.0 and boat.global_position.distance_to(target) > 30.0:
		await physics_frame
		# O mesmo passo que move_and_slide usa (com --time-scale, já multiplicado).
		var step := boat.get_physics_process_delta_time()
		elapsed += step
		var aim := boat.global_position.direction_to(target)
		boat.drive(Vector2(aim.x, aim.y / Boat.ISO_Y).normalized(), false, step)
	boat.set_physics_process(true)
	boat.velocity = Vector2.ZERO
	_check(boat.global_position.distance_to(target) <= 30.0, "rowing from Sabu's pier reaches the Bennu pier (%.1f s of rowing)" % elapsed)
	await physics_frame
	await physics_frame
	_check(world.nearest == _post("bennu") and _post("bennu").label.begins_with("Atracar"), "near the island pier the boat offers to dock")
	if "--capture-boat" in OS.get_cmdline_user_args():
		await _capture("barco_ilha")
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	_check(world.sea_busy, "pressing E starts the landing")
	await create_timer(1.0).timeout
	var player: SenuPlayer = world.player
	_check(not world.at_sea and not world.sea_busy and player.visible and player.controls_enabled, "Senu steps ashore with control back")
	_check(player.collision_layer == 2 and player.collision_mask != 0, "the walking body gets its collision back")
	_check(IsleLayout.is_land(Layout.unproject(player.global_position)), "Senu lands on the island")
	_check(world.boat_dock == "bennu" and boat.global_position.distance_to(Layout.iso(Sea.DOCKS["bennu"]["water"])) < 1, "the boat stays moored at the Bennu pier")
	_check(world.store.data["flags"].get("sea_route", false) and "isle_landed" in world.store.data["collected"], "the first landing opens the sea route on the map")
	_check(world.hud.overlay == "dialog", "the island greets Senu")
	world.hud.show_overlay("")
	await physics_frame
	await physics_frame
	_check(world.current_room == "isle" and "isle" in world.store.data["visited"], "walking on the island marks it visited")
	_check(_post("bennu").active and not _post("sabu").active, "the boat now waits at the island pier")


func _test_respawn() -> void:
	var player: SenuPlayer = world.player
	# Senu na ilha, último santuário no porto: o barco volta ao píer de Sabu.
	world.store.data["checkpoint"] = "hub"
	player.receive_hit(9999, player.global_position + Vector2(10, 0))
	await create_timer(2.0).timeout
	_check(not player.dead and world.boat_dock == "sabu", "dying with the boat on the island brings it back to Sabu's pier")
	_check(world.boat.global_position.distance_to(Layout.iso(Sea.DOCKS["sabu"]["water"])) < 1, "the boat is moored at Sabu's pier again")
	# Último santuário na ilha: o barco espera lá.
	_check(world.activate(_shrine("isle_rest")) or _near_and_activate("isle_rest"), "Senu can meditate at the Bennu stele")
	await physics_frame
	_check(world.store.data["checkpoint"] == "isle_rest", "the stele becomes the checkpoint")
	var on_disk: DemoSaveStore = SaveStore.new(world.store.path)
	_check(on_disk.load_progress() and on_disk.data["checkpoint"] == "isle_rest", "a save resting on the island loads back")
	# Meditar deixa Senu invulnerável por um instante.
	await create_timer(1.0).timeout
	player.receive_hit(9999, player.global_position + Vector2(10, 0))
	await create_timer(2.0).timeout
	_check(world.boat_dock == "bennu" and IsleLayout.is_land(Layout.unproject(player.global_position)), "dying after resting on the island returns Senu and the boat to the island")


func _shrine(id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id: return item
	return null


func _near_and_activate(id: String) -> bool:
	var item := _shrine(id)
	if item == null:
		return false
	world.player.position = item.position + Vector2(0, 10)
	return world.activate(item)


func _post(dock: String) -> PortInteractable:
	for post in get_nodes_in_group("moor_posts"):
		if post.dock == dock: return post
	return null


func _on_land(point: Vector2) -> bool:
	return catalog.has(Vector2i(Layout.unproject(point).round()))


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	root.get_texture().get_image().save_png("res://qa/%s.png" % name)
	var camera: Camera2D = world.player.get_node("IsometricCamera")
	print("CAPTURE_SAVED %s senu=%s camera=%s" % [name, Layout.unproject(world.player.global_position).snapped(Vector2(.1, .1)), Layout.unproject(camera.get_screen_center_position()).snapped(Vector2(.1, .1))])


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Boat test timed out before completion")
	quit(1)
