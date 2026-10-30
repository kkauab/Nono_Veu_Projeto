extends SceneTree

# Área inicial ampliada (docs/MUNDO_PROPOSTA_2026-10-30.md): o Claustro dos Iniciados,
# a sudoeste do Santuário da Primeira Palavra, onde Senu desperta depois da abertura.
# Confere que ele se liga só ao santuário (os portões do atalho, do Eco e do Porteiro
# continuam segurando), que tem cenário de pé sobre a pedra, que Senu chega a pé a
# cada peça e volta para a saída leste, e que as três lições abrem a Arca do Noviço
# uma vez só, sem Nous. Precisa do mundo real: -- --qa. Com --capture-cloister
# (Godot com janela), salva qa/mapa/claustro_*.png.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const CloisterLayout = preload("res://scripts/world/cloister_layout.gd")
const Cloister = preload("res://scripts/world/cloister.gd")
const Economy = preload("res://scripts/economy/economy.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D
var catalog: Dictionary
var navigation: AStar2D
var navigation_ids: Dictionary = {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(180.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE cloister test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/cloister_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	catalog = Layout.tile_catalog()
	_test_layout()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	await _test_walk()
	await _test_discovery()
	print("CLOISTER RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _test_layout() -> void:
	_check(world.store.data["checkpoint"] == "hub" and Layout.room_at(world.player.position) == "hub", "a new journey wakes Senu in the Santuário da Primeira Palavra")
	var ground := CloisterLayout.tiles()
	_check(ground.size() >= 110, "the cloister adds room to the first place (%d tiles; the sanctuary had 72)" % ground.size())
	var themed := true
	for tile in ground:
		themed = themed and catalog.has(tile) and catalog[tile]["theme"] == ground[tile] and Layout.room_at(Layout.iso(Vector2(tile))) == "cloister"
	_check(themed, "every cloister tile is ground of its own sector")
	var pool := true
	for x in range(CloisterLayout.POOL.position.x, CloisterLayout.POOL.end.x):
		for y in range(CloisterLayout.POOL.position.y, CloisterLayout.POOL.end.y):
			pool = pool and not catalog.has(Vector2i(x, y))
	_check(pool, "the sacred pool is open water")
	var neighbours := {}
	for tile in ground:
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = tile + step
			if catalog.has(next) and not ground.has(next):
				neighbours[Layout.room_at(Layout.iso(Vector2(next)))] = true
	_check(neighbours.keys() == ["cloister"], "the cloister only opens through its mouth (%s)" % str(neighbours.keys()))
	var mouth := 0
	for x in range(-5, -1):
		mouth += int(catalog.has(Vector2i(x, 2)) and catalog.has(Vector2i(x, 3)) and catalog.has(Vector2i(x, 4)))
	_check(mouth == 4, "a four-tile mouth joins the sanctuary to the cloister")
	var reached := _flood(Vector2i(Layout.MARKERS["hub_spawn"]))
	var all_in := true
	for tile in ground:
		all_in = all_in and reached.has(tile)
	_check(all_in, "the whole cloister is reachable from where Senu wakes")
	_check(not catalog.has(Vector2i(-6, 3)) and not catalog.has(Vector2i(-1, 3)) and not catalog.has(Vector2i(-1, 4)), "water flanks the mouth: no way into the shortcut corridor or the echo gallery")
	var ward := _flood_rooms(Vector2i(Layout.MARKERS["hub_spawn"]), ["hub", "cloister"])
	_check(ward.has(Vector2i(-8, 12)) and not ward.has(Vector2i(1, 5)), "from the sanctuary and the cloister alone, the shortcut gate still holds the corridor")
	_check(not reached.has(Vector2i(-12, 0)) and not reached.has(Vector2i(-20, 25)), "the echo grate still holds its gallery and the Catacombs")
	_check(not reached.has(Vector2i(-6, 23)), "the Porteiro's door still has no bypass")
	var quiet := true
	for spawn in Layout.ENEMY_SPAWNS:
		quiet = quiet and Layout.room_at(Layout.iso(spawn["tile"])) not in ["hub", "cloister"]
	_check(quiet, "no enemy waits in the sanctuary or the cloister")
	var kinds := {}
	var props := 0
	for node in world.actors.get_children():
		if node is PortProp and Layout.room_at(node.position) == "cloister":
			props += 1
			kinds[node.kind] = true
	_check(props >= 12 and kinds.has("temple") and kinds.has("palm") and kinds.has("statue"), "the cloister has its temple, masters of stone and palms (%d pieces)" % props)
	for id in ["cloister_lesson_name", "cloister_lesson_copy", "cloister_lesson_return", "cloister_chest"]:
		var item := _item(id)
		_check(item != null and Layout.room_at(item.position) == "cloister" and item.kind == "isle_altar", "cloister piece in place: " + id)
	var sign := _item("cloister_sign")
	_check(sign != null and Layout.room_at(sign.position) == "hub", "the crossroads sign stands in the sanctuary")


func _test_walk() -> void:
	# Senu desperta, entra no claustro, passa por cada peça e sai para o Cais.
	world.player.reset_at(Layout.iso(Layout.MARKERS["hub_spawn"]))
	await physics_frame
	Input.action_press("sprint")
	for id in ["cloister_lesson_return", "cloister_chest", "cloister_lesson_name", "cloister_lesson_copy", "cloister_sign"]:
		var item := _item(id)
		_check(await _walk_to(Layout.unproject(item.position + Vector2(0, 13))), "Senu walks to the front of " + id)
		if id == "cloister_chest":
			_check(world.current_room == "cloister" and "cloister" in world.store.data["visited"], "the cloister is recorded as visited")
			if "--capture-cloister" in OS.get_cmdline_user_args():
				await _capture("claustro_arca")
	_check(await _walk_to(Vector2(6, 0)) and world.current_room == "p1", "from the cloister Senu finds the east exit to the Cais")
	Input.action_release("sprint")


func _test_discovery() -> void:
	var coins := Economy.coins(world.store.data)
	var xp := int(world.store.data["xp"])
	var fragments: int = world.store.data["fragments"]
	var chest := _item("cloister_chest")
	_check(not await _use(chest) and world.hud.dialog_body.contains("0 de 3") and chest.active, "the chest waits for the three lessons")
	_close()
	var order := ["cloister_lesson_copy", "cloister_lesson_name", "cloister_lesson_return"]
	for index in range(order.size()):
		var lesson := _item(order[index])
		_check(await _use(lesson) and order[index] in world.store.data["collected"], "lesson read: " + order[index])
		_check(Cloister.lessons_read(world) == index + 1, "lessons remembered: %d of 3" % (index + 1))
		_close()
	_check(await _use(_item(order[0])) and Cloister.lessons_read(world) == 3, "rereading a lesson counts it once")
	_close()
	_check(await _use(chest) and chest.opened and "cloister_chest" in world.store.data["collected"], "the Novice's Chest opens")
	_check(Economy.coins(world.store.data) == coins + Cloister.CHEST_COINS and int(world.store.data["xp"]) == xp + Cloister.CHEST_XP, "the chest holds %d óbolos and %d XP" % [Cloister.CHEST_COINS, Cloister.CHEST_XP])
	_close()
	_check(not world.activate(chest) and Economy.coins(world.store.data) == coins + Cloister.CHEST_COINS, "the chest pays once")
	_check(world.store.data["fragments"] == fragments, "the cloister gives no Nous")
	_check(await _use(_item("cloister_sign")) and world.hud.dialog_body.contains("LESTE") and world.hud.dialog_body.contains("Cais"), "the crossroads sign names the way east to the Cais")
	_close()
	if "--capture-cloister" in OS.get_cmdline_user_args():
		world.player.reset_at(Layout.iso(Vector2(-4, 3.5)))
		await create_timer(.6).timeout
		await _capture("claustro_entrada")


func _blocked(a: Vector2i, b: Vector2i) -> bool:
	if not world.shortcut.opened and mini(a.y, b.y) == 3 and maxi(a.y, b.y) == 4 and a.x in range(0, 3): return true
	if not world.aqueduct_gate.opened and mini(a.y, b.y) == 19 and maxi(a.y, b.y) == 20 and a.x in range(20, 22): return true
	if not world.boss_entry_gate.opened and mini(a.x, b.x) == 0 and maxi(a.x, b.x) == 1 and a.y in range(21, 25): return true
	if not world.exit_gate.opened and mini(a.x, b.x) == -13 and maxi(a.x, b.x) == -12 and a.y in range(24, 27): return true
	if not world.echo_gate.opened and mini(a.x, b.x) == -6 and maxi(a.x, b.x) == -5 and a.y in range(-1, 1): return true
	return false


func _flood(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var pending := [start]
	while not pending.is_empty():
		var tile: Vector2i = pending.pop_back()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + direction
			if catalog.has(next) and not seen.has(next) and not _blocked(tile, next):
				seen[next] = true
				pending.append(next)
	return seen


## O mesmo, só pelos setores dados: o que se alcança sem sair do santuário e do claustro.
func _flood_rooms(start: Vector2i, rooms: Array) -> Dictionary:
	var seen := {start: true}
	var pending := [start]
	while not pending.is_empty():
		var tile: Vector2i = pending.pop_back()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = tile + direction
			if catalog.has(next) and not seen.has(next) and not _blocked(tile, next) and Layout.room_at(Layout.iso(Vector2(next))) in rooms:
				seen[next] = true
				pending.append(next)
	return seen


func _walk_to(tile: Vector2) -> bool:
	if navigation == null:
		navigation = AStar2D.new()
		var occupied: Dictionary = {}
		for prop in world.actors.get_children():
			if not prop.has_method("blocks_ground_point"):
				continue
			var at := Layout.unproject(prop.position)
			for x in range(floori(at.x) - 2, ceili(at.x) + 3):
				for y in range(floori(at.y) - 2, ceili(at.y) + 3):
					if prop.blocks_ground_point(Layout.iso(Vector2(x, y)), 7):
						occupied[Vector2i(x, y)] = true
		for cell in catalog:
			if not occupied.has(cell):
				navigation_ids[cell] = navigation_ids.size()
				navigation.add_point(navigation_ids[cell], Layout.iso(Vector2(cell)))
		for cell in navigation_ids:
			for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = cell + direction
				if navigation_ids.has(next) and not _blocked(cell, next):
					navigation.connect_points(navigation_ids[cell], navigation_ids[next])
	var path := navigation.get_point_path(navigation.get_closest_point(world.player.position), navigation.get_closest_point(Layout.iso(tile)))
	if path.is_empty():
		return false
	path.append(Layout.iso(tile))
	for goal in path:
		var arrived := false
		for step in range(200):
			world.hud.show_overlay("")
			var offset: Vector2 = goal - world.player.position
			if offset.length() < 6:
				arrived = true
				break
			for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
			if absf(offset.x) > 2: Input.action_press("move_right" if offset.x > 0 else "move_left")
			if absf(offset.y) > 2: Input.action_press("move_down" if offset.y > 0 else "move_up")
			await physics_frame
		if not arrived:
			print("CLOISTER_ROUTE_BLOCKED target=", Layout.unproject(goal), " actual=", Layout.unproject(world.player.position))
			for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
			return false
	for action in ["move_left", "move_right", "move_up", "move_down"]: Input.action_release(action)
	await physics_frame
	await physics_frame
	return world.player.position.distance_to(Layout.iso(tile)) < 24


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
		if item.item_id == id: return item
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
	push_error("Cloister test timed out before completion")
	quit(1)
