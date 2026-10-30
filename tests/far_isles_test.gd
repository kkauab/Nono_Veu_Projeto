extends SceneTree

# Ilhas além da Baía das Garças (docs/MUNDO_PROPOSTA_2026-10-30.md): a Ilha do Íbis
# Afogado e o Recife do Navio Esquecido. Confere o chão (contínuo a partir do píer,
# separado do resto), os píeres, as peças sobre a terra, a viagem real de barco do
# píer de Sabu até cada ilha e de uma ilha à outra, a atracação, as atividades (o
# enigma das estelas, o segredo, a carga e a arca do capitão) sem recompensa dobrada
# e sem Nous, o save ancorado numa torre e o barco voltando ao porto depois de morrer.
# Precisa do mundo real: -- --qa. Com --capture-far (Godot com janela), salva
# qa/mapa/ilha_ibis_*.png e qa/mapa/recife_*.png.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const FarLayout = preload("res://scripts/world/far_isles_layout.gd")
const FarIsles = preload("res://scripts/world/far_isles.gd")
const IsleLayout = preload("res://scripts/world/isle_layout.gd")
const Isle = preload("res://scripts/world/isle.gd")
const Sea = preload("res://scripts/world/sea.gd")
const Boat = preload("res://scripts/world/sea_boat.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D
var catalog: Dictionary


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE far isles test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/far_isles_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	catalog = Layout.tile_catalog()
	_test_ground()
	_test_pieces()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	var fragments: int = world.store.data["fragments"]
	await _test_voyage()
	await _test_ibis()
	await _test_wreck()
	_check(world.store.data["fragments"] == fragments, "no Nous comes from the far isles (%d → %d)" % [fragments, world.store.data["fragments"]])
	await _test_anchor_and_respawn()
	print("FAR ISLES RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _test_ground() -> void:
	var bennu := IsleLayout.tiles()
	var sabu := Layout.iso(Sea.DOCKS["sabu"]["water"])
	var bennu_reach := sabu.distance_to(Layout.iso(Sea.DOCKS["bennu"]["water"]))
	for id in FarLayout.ISLES:
		var ground := FarLayout.tiles(id)
		_check(ground.size() >= 180, "%s: room to explore (%d tiles)" % [id, ground.size()])
		var shared := true
		for tile in ground:
			shared = shared and catalog.has(tile) and catalog[tile]["theme"] == ground[tile]
		_check(shared, "%s: every tile is world ground with its own theme" % id)
		var start := Vector2i(Vector2(Sea.DOCKS[id]["land"]).round())
		var reached := {start: true}
		var frontier: Array[Vector2i] = [start]
		while not frontier.is_empty():
			var tile: Vector2i = frontier.pop_back()
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var next: Vector2i = tile + step
				if ground.has(next) and not reached.has(next):
					reached[next] = true
					frontier.append(next)
		_check(reached.size() == ground.size(), "%s: every tile is reachable on foot from the pier" % id)
		var contact := false
		for tile in ground:
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if catalog.has(tile + step) and not ground.has(tile + step):
					contact = true
		_check(not contact, "%s: open water separates it from the Port and the other isles" % id)
		var room: Dictionary = {}
		for candidate in Layout.ROOMS:
			if candidate["id"] == id: room = candidate
		_check(not room.is_empty() and not room.get("generated", true) and room.has("outline"), "%s: its own map sector, with the coast drawn on the map" % id)
		var inside := true
		for tile in ground:
			inside = inside and Layout.room_at(Layout.iso(Vector2(tile))) == id
		_check(inside, "%s: every tile belongs to its sector" % id)
		var dock: Dictionary = Sea.DOCKS[id]
		_check(dock["side"] == "far" and FarLayout.is_land(dock["land"]) and dock["land"] == FarLayout.ISLES[id]["landing"], "%s: the pier end is island ground" % id)
		_check(not catalog.has(Vector2i(Vector2(dock["water"]).round())), "%s: the mooring spot is water" % id)
		_check(sabu.distance_to(Layout.iso(dock["water"])) > bennu_reach * 1.6, "%s lies farther than the Bennu island (%.0f px against %.0f)" % [id, sabu.distance_to(Layout.iso(dock["water"])), bennu_reach])
		for tile in ground:
			if bennu.has(tile):
				contact = true
		_check(not contact, "%s does not overlap the Bennu island" % id)
	for id in FarLayout.MARKERS:
		_check(FarLayout.is_land(FarLayout.MARKERS[id]), "marker on land: " + id)
	var foes := 0
	for spawn in Layout.ENEMY_SPAWNS:
		var isle := FarLayout.isle_at(spawn["tile"])
		if isle != "":
			foes += 1
			_check(FarLayout.is_land(spawn["tile"]) and Layout.room_at(Layout.iso(spawn["tile"])) == isle, "far isle foe starts on its island: " + spawn["id"])
	_check(foes == 4, "two foes on each far isle (%d)" % foes)


func _test_pieces() -> void:
	var props := []
	var herons := []
	var stone := {"ibis": 0, "wreck": 0}
	for node in world.actors.get_children():
		var tile := Layout.unproject(node.position)
		var isle := FarLayout.isle_at(tile)
		if isle == "":
			continue
		if node is Isle.IsleProp:
			props.append(node)
		elif node is Isle.Heron:
			herons.append(node)
		elif node is PortProp:
			stone[isle] += 1
	_check(props.size() == FarLayout.PROPS.size(), "all far isle plants, rocks and driftwood are placed (%d)" % props.size())
	var grounded := true
	var clear := true
	for prop in props:
		var at := Layout.unproject(prop.position)
		# Juncos e madeira à deriva podem estar na água rasa (o lago do templo), junto à terra.
		var shore := false
		for step in [Vector2(0, 0), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			shore = shore or FarLayout.is_land(at + step)
		grounded = grounded and (FarLayout.is_land(at) if prop.solid else shore)
		if not prop.solid or not Isle.SOLID_RADIUS.has(prop.kind):
			continue
		var radius: float = Isle.SOLID_RADIUS[prop.kind]
		for id in FarLayout.MARKERS:
			if prop.position.distance_to(Layout.iso(FarLayout.MARKERS[id])) < radius + 18.0:
				clear = false
				push_error("prop %s too close to %s" % [prop.kind, id])
		for id in FarLayout.ISLES:
			if prop.position.distance_to(Layout.iso(FarLayout.ISLES[id]["landing"])) < radius + 30.0:
				clear = false
	_check(grounded, "every solid far isle prop stands on its island; reeds stay by the shore")
	_check(clear, "solid props leave the quest pieces and the piers free")
	var wet := true
	for heron in herons:
		wet = wet and not catalog.has(Vector2i(Layout.unproject(heron.position).round()))
	_check(herons.size() == FarLayout.HERONS.size() and wet, "herons wade in the shallows")
	_check(stone["ibis"] >= 9 and stone["wreck"] >= 9, "port stonework dresses both isles (íbis %d, recife %d)" % [stone["ibis"], stone["wreck"]])
	var ship := false
	for node in world.actors.get_children():
		if node is PortProp and node.kind == "boat" and FarLayout.isle_at(Layout.unproject(node.position)) == "wreck":
			ship = node.has_node("ShipWater") and not catalog.has(Vector2i(Layout.unproject(node.position).round()))
	_check(ship, "the stranded ship sits in the water beside the reef")
	for id in FarLayout.MARKERS:
		var item := _item(id)
		if id == "wreck_chest":
			_check(item == null, "the captain's chest stays hidden until the log is read")
		else:
			_check(item != null and item.kind == "isle_altar" and item.has_method("extra_activate"), "piece exists and routes through the island hook: " + id)


func _test_voyage() -> void:
	var player: SenuPlayer = world.player
	var boat: Node2D = world.boat
	player.reset_at(Layout.iso(Sea.DOCKS["sabu"]["land"]))
	await physics_frame
	_check(Sea.board(world), "Senu boards Sabu's boat")
	await create_timer(1.0).timeout
	_check(world.at_sea, "Senu rows away from the port")
	_check(await _row([Vector2(27, 48), Vector2(18, 58), Sea.DOCKS["ibis"]["water"]]), "rowing from Sabu's pier reaches the Íbis pier")
	if "--capture-far" in OS.get_cmdline_user_args():
		await _capture("ilha_ibis_chegada")
	await _land("ibis")
	_check(FarLayout.is_land(Layout.unproject(player.global_position)) and FarLayout.isle_at(Layout.unproject(player.global_position)) == "ibis", "Senu lands on the Íbis isle")
	_check(world.boat_dock == "ibis" and boat.global_position.distance_to(Layout.iso(Sea.DOCKS["ibis"]["water"])) < 1, "the boat stays moored at the Íbis pier")
	_check("ibis_landed" in world.store.data["collected"] and world.store.data["flags"]["sea_route"], "the first landing greets Senu and opens the sea route")
	_check(world.hud.overlay == "dialog" and world.hud.dialog_body.contains("íbis"), "the isle introduces itself")
	world.hud.show_overlay("")
	await physics_frame
	await physics_frame
	_check(world.current_room == "ibis" and "ibis" in world.store.data["visited"], "walking on the isle marks its sector visited")
	_check(_post("ibis").active and not _post("sabu").active, "the boat now waits at the Íbis pier")


func _test_ibis() -> void:
	var coins := Economy.coins(world.store.data)
	var xp := int(world.store.data["xp"])
	_check(await _use(_item("ibis_clue")) and world.hud.dialog_body.contains("Antes de escrever"), "the temple gives the order of the steles")
	_close()
	var niche := _item("ibis_niche")
	_check(not await _use(niche) and not niche.opened, "the niche stays shut before the steles")
	_close()
	var eye := _item("ibis_eye")
	var feather := _item("ibis_feather")
	var reed := _item("ibis_reed")
	_check(await _use(feather) and not feather.opened, "the feather does not start the sequence")
	_check(await _use(eye) and eye.opened, "the eye lights first")
	_check(await _use(reed) and not eye.opened and not reed.opened, "a wrong stele puts every mark out")
	await _use(eye)
	await _use(feather)
	_check(eye.opened and feather.opened and not reed.opened, "eye then feather: two steles shine")
	_check(await _use(reed) and "ibis_steles" in world.store.data["collected"], "the reed completes the order")
	_close()
	_check(await _use(niche) and niche.opened and "ibis_niche" in world.store.data["collected"], "the Copyist's niche opens")
	_check(Economy.coins(world.store.data) == coins + FarIsles.NICHE_COINS and int(world.store.data["xp"]) == xp + FarIsles.NICHE_XP, "the niche pays %d óbolos and %d XP" % [FarIsles.NICHE_COINS, FarIsles.NICHE_XP])
	_close()
	_check(not await _use(niche) and Economy.coins(world.store.data) == coins + FarIsles.NICHE_COINS, "the niche pays once")
	var tablet := _item("ibis_tablet")
	_check(await _use(tablet) and "ibis_tablet" in world.store.data["collected"] and not tablet.active, "the buried tablet is the isle's secret")
	_check(Economy.coins(world.store.data) == coins + FarIsles.NICHE_COINS + FarIsles.TABLET_COINS, "the secret pays %d óbolos" % FarIsles.TABLET_COINS)
	_close()
	_check(not world.activate(tablet), "the tablet cannot be dug twice")
	if "--capture-far" in OS.get_cmdline_user_args():
		world.player.reset_at(Layout.iso(Vector2(11, 75)))
		await create_timer(.5).timeout
		await _capture("ilha_ibis_templo")


func _test_wreck() -> void:
	var player: SenuPlayer = world.player
	player.reset_at(Layout.iso(Sea.DOCKS["ibis"]["land"]))
	await physics_frame
	_check(Sea.board(world), "Senu boards again at the Íbis pier")
	await create_timer(1.0).timeout
	_check(await _row([Vector2(18, 58), Vector2(30, 54), Vector2(58, 54), Vector2(62, 63), Sea.DOCKS["wreck"]["water"]]), "rowing from the Íbis reaches the reef pier, around the Bennu island")
	await _land("wreck")
	_check(FarLayout.isle_at(Layout.unproject(player.global_position)) == "wreck" and FarLayout.is_land(Layout.unproject(player.global_position)), "Senu lands on the reef")
	_check("wreck_landed" in world.store.data["collected"] and world.hud.dialog_body.contains("navio"), "the reef introduces itself")
	world.hud.show_overlay("")
	await physics_frame
	await physics_frame
	_check(world.current_room == "wreck", "the reef is its own sector")
	if "--capture-far" in OS.get_cmdline_user_args():
		await _capture("recife_chegada")
	var coins := Economy.coins(world.store.data)
	var xp := int(world.store.data["xp"])
	for index in range(FarIsles.CRATES.size()):
		var crate := _item(FarIsles.CRATES[index])
		_check(await _use(crate) and crate.opened and not crate.active, "sealed crate %d opens" % (index + 1))
		_check(not world.activate(crate), "crate %d pays once" % (index + 1))
	_check(Economy.coins(world.store.data) == coins + FarIsles.CRATE_COINS * FarIsles.CRATES.size(), "the cargo pays %d óbolos per crate" % FarIsles.CRATE_COINS)
	_check(_item("wreck_chest") == null, "no chest before the log")
	_check(await _use(_item("wreck_log")) and "wreck_log" in world.store.data["collected"], "the captain's log can be read")
	_check(world.hud.dialog_body.contains("palmeira torta"), "the log points to the bent palm")
	_close()
	await process_frame
	var chest := _item("wreck_chest")
	_check(chest != null and chest.active and FarLayout.is_land(Layout.unproject(chest.position)), "the captain's chest appears by the palm")
	var before := Economy.coins(world.store.data)
	_check(chest != null and await _use(chest) and chest.opened and "wreck_chest" in world.store.data["collected"], "the captain's chest opens")
	_check(Economy.coins(world.store.data) == before + FarIsles.CHEST_COINS and int(world.store.data["xp"]) == xp + FarIsles.CHEST_XP, "the chest pays %d óbolos and %d XP" % [FarIsles.CHEST_COINS, FarIsles.CHEST_XP])
	_close()
	_check(chest != null and not world.activate(chest) and Economy.coins(world.store.data) == before + FarIsles.CHEST_COINS, "the chest pays once")
	_check(await _use(_item("wreck_log")) and Economy.coins(world.store.data) == before + FarIsles.CHEST_COINS, "rereading the log pays nothing")
	_close()
	if "--capture-far" in OS.get_cmdline_user_args():
		world.player.reset_at(Layout.iso(Vector2(80, 67)))
		await create_timer(.5).timeout
		await _capture("recife_carga")


func _test_anchor_and_respawn() -> void:
	# A jornada só grava numa torre: a do santuário ancora o que se fez nas ilhas.
	var tower := _item("hub")
	world.player.reset_at(tower.position + Vector2(0, 12))
	await physics_frame
	_check(world.activate(tower), "a tower anchors the far isle discoveries")
	var on_disk: DemoSaveStore = SaveStore.new(world.store.path)
	var saved := on_disk.load_progress()
	var kept := saved
	for id in ["ibis_landed", "ibis_steles", "ibis_niche", "ibis_tablet", "wreck_landed", "wreck_log", "wreck_chest"] + FarIsles.CRATES:
		kept = kept and id in on_disk.data["collected"]
	_check(kept, "the anchored save keeps every far isle step")
	# Morrer numa ilha distante devolve Senu e o barco ao lado do último santuário.
	await create_timer(1.0).timeout
	world.player.reset_at(Layout.iso(FarLayout.MARKERS["wreck_crate_3"]) + Vector2(0, 14))
	Sea.moor(world, "wreck")
	# Reaparecer deixa Senu invulnerável por um instante.
	await create_timer(1.0).timeout
	world.player.receive_hit(9999, world.player.global_position + Vector2(10, 0))
	await create_timer(2.5).timeout
	_check(not world.player.dead and world.boat_dock == "sabu" and Layout.room_at(world.player.position) == "hub", "dying on the reef brings Senu and the boat back to the port")


func _row(path: Array) -> bool:
	# Um piloto aponta o barco para cada ponto; a física decide se há caminho.
	var boat: Node2D = world.boat
	boat.set_physics_process(false)
	var elapsed := 0.0
	for goal in path:
		var target := Layout.iso(goal)
		while elapsed < 90.0 and boat.global_position.distance_to(target) > 26.0:
			await physics_frame
			var step: float = boat.get_physics_process_delta_time()
			elapsed += step
			var aim: Vector2 = boat.global_position.direction_to(target)
			boat.drive(Vector2(aim.x, aim.y / Boat.ISO_Y).normalized(), true, step)
	boat.set_physics_process(true)
	boat.velocity = Vector2.ZERO
	print("ROW %.1f s of rowing, ends at %s" % [elapsed, Layout.unproject(boat.global_position).snapped(Vector2(.1, .1))])
	return boat.global_position.distance_to(Layout.iso(path[-1])) <= 26.0


func _land(dock: String) -> void:
	await physics_frame
	await physics_frame
	_check(world.nearest == _post(dock) and _post(dock).label.begins_with("Atracar"), "near the %s pier the boat offers to dock" % dock)
	Input.action_press("interact")
	await physics_frame
	await physics_frame
	Input.action_release("interact")
	await create_timer(1.0).timeout
	_check(not world.at_sea and not world.sea_busy and world.player.visible and world.player.controls_enabled, "Senu steps onto the %s pier with control back" % dock)


func _use(item) -> bool:
	if item == null:
		return false
	world.player.position = item.position + Vector2(0, 12)
	await physics_frame
	return world.activate(item)


func _close() -> void:
	world.hud.show_overlay("")


func _item(id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id and not item.is_queued_for_deletion(): return item
	return null


func _post(dock: String) -> PortInteractable:
	for post in get_nodes_in_group("moor_posts"):
		if post.dock == dock: return post
	return null


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mapa"))
	root.get_texture().get_image().save_png("res://qa/mapa/%s.png" % name)
	print("CAPTURE_SAVED ", name)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Far isles test timed out before completion")
	quit(1)
