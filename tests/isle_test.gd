extends SceneTree

# Ilha do Bennu: chão contínuo a partir do píer, vegetação sobre a terra sem
# tampar as peças, garças na água, e as quatro missões (Ankhet, três chamas,
# altar com a Pena do Bennu e a rede de Hori), com recompensas que não se
# repetem e um save que volta a carregar. Precisa do mundo real: -- --qa.
# Com --capture-isle (Godot com janela), salva qa/ilha_bennu.png e qa/ilha_mapa.png.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const IsleLayout = preload("res://scripts/world/isle_layout.gd")
const Isle = preload("res://scripts/world/isle.gd")
const IsleStory = preload("res://scripts/world/isle_story.gd")
const Sea = preload("res://scripts/world/sea.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(120.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE isle test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/isle_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	_test_ground()
	_test_dressing()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	await _test_ankhet()
	await _test_flames()
	await _test_altar()
	await _test_net()
	await _test_map()
	print("ISLE RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_ground() -> void:
	var island := IsleLayout.tiles()
	var catalog := Layout.tile_catalog()
	_check(island.size() >= 250, "the island has room to explore (%d tiles)" % island.size())
	var shared := true
	for tile in island:
		shared = shared and catalog.has(tile) and catalog[tile]["theme"] == island[tile]
	_check(shared, "every island tile is Port ground with its own theme")
	var themes := {}
	for tile in island:
		themes[island[tile]] = true
	_check(themes.has("sand") and themes.has("garden") and themes.has("wood") and themes.has("mosaic"), "beach, field, pier and ruins all appear")
	# A pé, a partir da ponta do píer, se chega a todo tile da ilha.
	var start := Vector2i(Vector2(Sea.DOCKS["bennu"]["land"]).round())
	var reached := {start: true}
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var tile: Vector2i = frontier.pop_back()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = tile + step
			if island.has(next) and not reached.has(next):
				reached[next] = true
				frontier.append(next)
	_check(reached.size() == island.size(), "every island tile is reachable on foot from the pier")
	var port_contact := false
	for tile in island:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if catalog.has(tile + step) and not island.has(tile + step):
				port_contact = true
	_check(not port_contact, "open water separates the island from the Port")
	for id in IsleLayout.MARKERS:
		_check(IsleLayout.is_land(IsleLayout.MARKERS[id]), "marker on land: " + id)
	for spawn in Layout.ENEMY_SPAWNS:
		if str(spawn["id"]) in IsleStory.FOES:
			_check(IsleLayout.is_land(spawn["tile"]), "island foe starts on land: " + spawn["id"])
	_check(Layout.room_at(Layout.iso(IsleLayout.MARKERS["ankhet"])) == "isle", "the island is its own map sector")
	_check(world.checkpoints.has("isle_rest") and "isle_rest" in SaveStore.CHECKPOINTS, "the Bennu stele is a valid checkpoint")


func _test_dressing() -> void:
	var props := []
	var herons := []
	for node in world.actors.get_children():
		if node is Isle.IsleProp:
			props.append(node)
		elif node is Isle.Heron:
			herons.append(node)
	_check(props.size() == IsleLayout.PROPS.size(), "all island props are placed (%d)" % props.size())
	var kinds := {}
	for prop in props:
		kinds[prop.kind] = true
	_check(kinds.has("palm") and kinds.has("acacia") and kinds.has("sycamore") and kinds.has("bush_a") and kinds.has("reeds"), "palms, acacias, a sycamore, bushes and reeds grow on the island")
	var grounded := true
	var clear := true
	for prop in props:
		var tile := Layout.unproject(prop.position)
		grounded = grounded and IsleLayout.is_land(tile)
		if not prop.solid or not Isle.SOLID_RADIUS.has(prop.kind):
			continue
		var radius: float = Isle.SOLID_RADIUS[prop.kind]
		for id in IsleLayout.MARKERS:
			if prop.position.distance_to(Layout.iso(IsleLayout.MARKERS[id])) < radius + 18.0:
				clear = false
				push_error("prop %s too close to %s" % [prop.kind, id])
		for dock_tile in [Sea.DOCKS["bennu"]["land"], Vector2(44.5, 61.5), Vector2(44.5, 63)]:
			if prop.position.distance_to(Layout.iso(dock_tile)) < radius + 14.0:
				clear = false
	_check(grounded, "every prop stands on island ground")
	_check(clear, "solid props leave the mission pieces and the pier path free")
	var wet := true
	for heron in herons:
		wet = wet and not IsleLayout.is_land(Layout.unproject(heron.position)) and not Layout.tile_catalog().has(Vector2i(Layout.unproject(heron.position).round()))
	_check(herons.size() == IsleLayout.HERONS.size() and wet, "herons wade in the shallows")


func _test_ankhet() -> void:
	var ankhet := _item("isle_ankhet")
	_check(ankhet != null and ankhet.label == "Falar com a guardiã das garças", "Ankhet waits unnamed")
	_check(await _use(ankhet) and "isle_ankhet_met" in world.store.data["collected"], "Ankhet asks Senu to drive the Forgotten away")
	_check(world.hud.dialog_body.contains("três Esquecidos"), "she names the task")
	_close()
	_check(await _use(ankhet) and world.hud.dialog_body.contains("3 deles"), "she still hears all three")
	_close()
	var coins := Economy.coins(world.store.data)
	var xp := int(world.store.data["xp"])
	# Os três caem; o registro sobrevive ao renascimento dos inimigos no descanso.
	for id in IsleStory.FOES:
		world.store.data["defeated"].append(id)
	for frame in range(25):
		await physics_frame
	for id in IsleStory.FOES:
		world.store.data["defeated"].erase(id)
	_check(IsleStory.foes_cleared(world) == 3, "defeats are remembered after the foes return")
	_check(await _use(ankhet) and "isle_foes_done" in world.store.data["collected"], "Ankhet thanks Senu")
	_check(Economy.coins(world.store.data) == coins + IsleStory.FOES_COINS and int(world.store.data["xp"]) == xp + IsleStory.FOES_XP, "the herons' reward: %d óbolos and %d XP" % [IsleStory.FOES_COINS, IsleStory.FOES_XP])
	_check(world.hud.dialog_body.contains("Catacumbas"), "she tells what the herons saw of Iri")
	_close()
	_check(await _use(ankhet) and Economy.coins(world.store.data) == coins + IsleStory.FOES_COINS, "the reward is paid once")
	_check(world.hud.dialog_body.contains("onde o sol nasce"), "afterwards she teaches the flight of the Bennu")
	_close()


func _test_flames() -> void:
	var east := _item("brazier_east")
	var north := _item("brazier_north")
	var west := _item("brazier_west")
	_check(not east.opened and not north.opened and not west.opened, "the three braziers start cold")
	_check(await _use(north) and not north.opened, "the north flame will not catch first")
	_check(await _use(east) and east.opened, "the east flame catches: the Bennu wakes")
	_check(await _use(west) and not east.opened and not west.opened, "the wrong order puts every flame out")
	_check(not "isle_flames" in world.store.data["collected"], "nothing is solved yet")
	await _use(east)
	await _use(north)
	_check(east.opened and north.opened and not west.opened, "east then north: two flames burn")
	_check(await _use(west) and "isle_flames" in world.store.data["collected"], "the third flame completes the flight")
	_check(east.opened and north.opened and west.opened, "all three keep burning")
	_close()


func _test_altar() -> void:
	var altar := _item("bennu_altar")
	var coins := Economy.coins(world.store.data)
	_check(Shop.capacity(world.store.data, "balsamo") == 0, "no balm jar yet")
	_check(await _use(altar) and "isle_chest" in world.store.data["collected"] and altar.opened, "the altar opens after the three flames")
	_check(Shop.owned(world.store.data, "pena_bennu") == 1 and Shop.capacity(world.store.data, "balsamo") == 1 and Shop.charges(world.store.data, "balsamo") == 1, "the Bennu feather holds one full balm charge")
	_check(Economy.coins(world.store.data) == coins + IsleStory.ALTAR_COINS, "the altar also holds %d óbolos" % IsleStory.ALTAR_COINS)
	_close()
	_check(await _use(altar) and Economy.coins(world.store.data) == coins + IsleStory.ALTAR_COINS and Shop.owned(world.store.data, "pena_bennu") == 1, "an empty altar gives nothing twice")
	_close()
	world.player.health = 30
	world._last_balm_ms = -100000
	_check(world.use_balm() and world.player.health > 30, "the feather's charge heals with R")
	Shop.refill(world.store.data)
	_check(Shop.charges(world.store.data, "balsamo") == 1, "a shrine refills the feather's charge")
	_check(Shop.purchase(world.store.data, "jarro_balsamo") == false or Shop.capacity(world.store.data, "balsamo") == 2, "jars still add on top of the feather")
	_check(await _use(_item("isle_rest")), "the island tower anchors the feather reward")
	var on_disk: DemoSaveStore = SaveStore.new(world.store.path)
	_check(on_disk.load_progress() and Shop.capacity(on_disk.data, "balsamo") == Shop.capacity(world.store.data, "balsamo"), "a save with the feather loads back")
	_check(not Shop.SHOPS["merit"].has("pena_bennu") and not Shop.SHOPS["adiam"].has("pena_bennu") and not Shop.SHOPS["nakht"].has("pena_bennu"), "no shop sells the feather")


func _test_net() -> void:
	var net := _item("hori_net")
	_check(net != null and net.active, "Hori's net lies on the south beach")
	_check(await _use(net) and "isle_net" in world.store.data["collected"] and not net.active, "Senu takes the net")
	_close()
	var coins := Economy.coins(world.store.data)
	var xp := int(world.store.data["xp"])
	var hori := _item("npc_fisher")
	_check(await _use(hori) and "isle_net_done" in world.store.data["collected"], "Hori takes his net back")
	_check(world.hud.dialog_body.contains("É a minha"), "Hori recognizes the knot")
	_check(Economy.coins(world.store.data) == coins + IsleStory.NET_COINS and int(world.store.data["xp"]) == xp + IsleStory.NET_XP, "the net pays %d óbolos and %d XP" % [IsleStory.NET_COINS, IsleStory.NET_XP])
	_close()
	_check(await _use(hori) and not world.hud.dialog_body.contains("É a minha") and Economy.coins(world.store.data) == coins + IsleStory.NET_COINS, "afterwards Hori talks as usual and pays nothing more")
	_close()


func _test_map() -> void:
	if "isle" not in world.store.data["visited"]:
		world.store.data["visited"].append("isle")
	if "lower_dock" not in world.store.data["visited"]:
		world.store.data["visited"].append("lower_dock")
	world.store.data["flags"]["sea_route"] = true
	var room: Dictionary = {}
	for candidate in Layout.ROOMS:
		if candidate["id"] == "isle": room = candidate
	_check(world.hud.call("_map_room_shape", room).size() == room["outline"].size(), "the map draws the island coast, not its rectangle")
	world.player.position = Layout.iso(IsleLayout.MARKERS["ankhet"]) + Vector2(0, 30)
	await physics_frame
	await physics_frame
	world.hud.show_overlay("map")
	await process_frame
	await process_frame
	_check(world.hud.overlay == "map", "the map opens with the island revealed")
	if "--capture-isle" in OS.get_cmdline_user_args():
		await _capture("ilha_mapa")
	world.hud.show_overlay("")
	if "--capture-isle" in OS.get_cmdline_user_args():
		await create_timer(.6).timeout
		await _capture("ilha_bennu")


func _use(item: PortInteractable) -> bool:
	world.player.position = item.position + Vector2(0, 12)
	await physics_frame
	return world.activate(item)


func _close() -> void:
	world.hud.show_overlay("")


func _item(id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id: return item
	return null


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	root.get_texture().get_image().save_png("res://qa/%s.png" % name)
	print("CAPTURE_SAVED ", name)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Isle test timed out before completion")
	quit(1)
