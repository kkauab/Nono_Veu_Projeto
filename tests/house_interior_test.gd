extends SceneTree

# Casas, fase 1: porta da Guarita, transição, Casa da Guarda, baú e bilhete.
# Precisa do mundo real: rode com -- --qa. Com --capture-houses (Godot com janela),
# salva qa/casa_guarda_fora.png e qa/casa_guarda_dentro.png.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Catalog = preload("res://scripts/world/house_catalog.gd")
const Houses = preload("res://scripts/world/houses.gd")
const Interior = preload("res://scripts/world/house_interior.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const ID := "casa_guarda"

var checks := 0
var failures: Array[String] = []
var world: Node2D
var house: Dictionary = Catalog.HOUSES[ID]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE house test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	var session_dir := "user://qa/houses_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	_test_placement()
	_test_depth()
	await _test_enter()
	await _test_walls()
	await _test_chest_and_note()
	await _test_leave()
	await _test_chest_after_tower()
	print("HOUSE RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_placement() -> void:
	var catalog := Layout.tile_catalog()
	var areas: Array[Rect2] = []
	for id in Catalog.HOUSES:
		var data: Dictionary = Catalog.HOUSES[id]
		var door := Layout.iso(data["door"])
		var outside := Layout.iso(data["outside"])
		_check(catalog.has(Vector2i(Vector2(data["door"]).round())) and catalog.has(Vector2i(Vector2(data["outside"]).round())), "%s: door and outside spot stand on Port ground" % id)
		_check(Layout.room_at(door) == data["district"] and Layout.room_at(outside) == data["district"], "%s: door belongs to its district" % id)
		var blocked := false
		var crowded := false
		for node in world.actors.get_children():
			if node is PortProp and node.solid and (node.blocks_ground_point(door, 6) or node.blocks_ground_point(outside, 8)):
				blocked = true
			if node is PortInteractable and not node is Houses.HouseFixture and node.position.distance_to(door) < 40:
				crowded = true
		_check(not blocked, "%s: no solid facade covers the door or the outside spot" % id)
		_check(not crowded, "%s: the door keeps 40 px from every other interaction" % id)
		var room_far := true
		var area := Rect2(Layout.iso(Vector2(data["origin"])), Vector2.ZERO)
		for tile in Catalog.tiles_of(data):
			var center := Layout.iso(Vector2(tile))
			area = area.expand(center)
			if not Catalog.is_interior_point(center + Vector2(-32, 0)) or catalog.has(tile):
				room_far = false
		_check(room_far, "%s: the room lies beyond the sea line and shares no tile with the Port" % id)
		var rect := Rect2(Vector2(data["origin"]) - Vector2(.5, .5), Vector2(data["size"]))
		var inside_ok := rect.has_point(data["spawn"]) and rect.has_point(data["exit"])
		for piece in data["furniture"] + data["fixtures"]:
			if not rect.has_point(piece[piece.size() - 1]): inside_ok = false
		_check(inside_ok, "%s: spawn, exit, furniture and fixtures are inside the room" % id)
		_check(_fixture("porta_" + id) != null and _fixture("saida_" + id) != null, "%s: both doors exist" % id)
		areas.append(area.grow(Interior.BACKDROP_MARGIN))
	var apart := true
	for first in range(areas.size()):
		for second in range(first + 1, areas.size()):
			if areas[first].intersects(areas[second]): apart = false
	_check(apart, "the dark backdrop of one room never covers another room")


func _test_depth() -> void:
	# Balcão e baú de troca ficam no meio da sala: Senu passa atrás e na frente.
	var sliced := 0
	var ordered := true
	for furniture in get_nodes_in_group("house_furniture"):
		if furniture.kind not in ["counter", "trade_chest"]:
			continue
		var slices := furniture.get_children().filter(func(child): return child is Interior.Furniture.ArtSlice)
		if slices.is_empty():
			continue
		sliced += 1
		var base: PackedVector2Array = furniture.ground_footprint()
		for along in [.1, .3, .5, .7, .9]:
			for side in [-1, 1]:
				var x := lerpf(base[3].x, base[1].x, along)
				var edge: float = furniture._front_edge(base, x)
				var spot: Vector2 = furniture.position + Vector2(x, edge + side * 10)
				for slice in slices:
					var left: float = furniture.position.x + slice.from
					if left + Interior.Furniture.SLICE_WIDTH < spot.x - 8 or left > spot.x + 8:
						continue
					# Atrás (side -1): a fatia vem depois e cobre Senu; na frente, antes.
					if (slice.global_position.y > spot.y) != (side == -1):
						ordered = false
	_check(sliced == 2, "the counter and the trade chest are drawn in depth slices")
	_check(ordered, "behind those pieces Senu is covered along their whole length, and in front he is not")


func _test_enter() -> void:
	var player: SenuPlayer = world.player
	player.position = Layout.iso(house["outside"])
	player.health = 61
	# Um passo de física registra a Guarita como visitada antes da contagem.
	await physics_frame
	await physics_frame
	var visited_before: int = world.store.data["visited"].size()
	_check(world.activate(_fixture("porta_" + ID)), "Senu opens the Guard House door")
	_check(not player.controls_enabled and world.house_busy, "controls wait for the fade")
	_check(not world.activate(_fixture("porta_" + ID)), "a second press during the fade is ignored")
	await create_timer(.7).timeout
	await physics_frame
	var camera: Camera2D = player.get_node("IsometricCamera")
	_check(world.inside_house == ID and player.position.distance_to(Layout.iso(house["spawn"])) < 2, "Senu appears on the inner threshold")
	_check(player.controls_enabled and not world.house_busy, "controls return after the fade")
	_check(player.health == 61, "doors do not heal")
	_check(camera.top_level and camera.global_position.distance_to(Interior.camera_point(house)) < 1, "the camera rests at the room center")
	_check(world.current_room == house["district"] and world.store.data["visited"].size() == visited_before, "the district stays current and visited sectors do not change")
	_check(world.map_position() == Layout.iso(house["door"]), "the map marks Senu at the outer door")
	var fade: ColorRect = world.hud.get_parent().get_node("HouseFade")
	_check(fade.color.a < .05, "the fade clears")
	if "--capture-houses" in OS.get_cmdline_user_args():
		await _capture("casa_guarda_dentro")


func _test_walls() -> void:
	var player: SenuPlayer = world.player
	var rect := Rect2(Vector2(house["origin"]) - Vector2(.6, .6), Vector2(house["size"]) + Vector2(.2, .2))
	var center := Layout.iso(Vector2(house["origin"]) + Vector2(2.5, 2))
	var held := true
	for action in ["move_up", "move_down", "move_left", "move_right"]:
		player.position = center
		Input.action_press(action)
		Input.action_press("sprint")
		for frame in range(150):
			await physics_frame
		Input.action_release(action)
		Input.action_release("sprint")
		if not rect.has_point(Layout.unproject(player.position)):
			held = false
			print("HOUSE_WALL_LEAK action=%s tile=%s" % [action, Layout.unproject(player.position)])
	_check(held, "walls hold Senu inside in all four directions")
	var enemy_far := true
	for enemy in get_nodes_in_group("enemies"):
		if Catalog.is_interior_point(enemy.position): enemy_far = false
	_check(enemy_far, "no enemy follows Senu into the house")


func _test_chest_and_note() -> void:
	var player: SenuPlayer = world.player
	var chest := _fixture("bau_guarda")
	player.position = chest.position + Vector2(20, 10)
	var coins := Economy.coins(world.store.data)
	_check(world.activate(chest), "the chest opens")
	_check(Economy.coins(world.store.data) == coins + 30 and "bau_guarda" in world.store.data["collected"], "the chest pays 30 coins once")
	_check(chest.opened and not chest.active, "the chest stays open")
	_check(not world.activate(chest), "an open chest cannot be opened again")
	_check(not FileAccess.file_exists(world.store.path), "opening the chest does not create an autosave inside the house")
	var note := _fixture("nota_guarda")
	player.position = note.position + Vector2(-14, 14)
	_check(world.activate(note) and world.hud.overlay == "dialog" and world.hud.dialog_title == Catalog.NOTES["nota_guarda"][0], "the note opens its own text")
	world.hud.show_overlay("")
	await process_frame


func _test_leave() -> void:
	var player: SenuPlayer = world.player
	player.position = Layout.iso(house["spawn"])
	_check(world.activate(_fixture("saida_" + ID)), "Senu steps out")
	await create_timer(.7).timeout
	await physics_frame
	var camera: Camera2D = player.get_node("IsometricCamera")
	_check(world.inside_house == "" and player.position.distance_to(Layout.iso(house["outside"])) < 2, "Senu is back in front of the door")
	_check(not camera.top_level and camera.position == Vector2(0, -20), "the camera follows Senu again")
	_check(world.current_room == house["district"] and not ID in world.store.data["visited"], "the Guarita is current and the house never became a sector")
	_check(world.map_position() == player.position, "the map follows Senu again")
	if "--capture-houses" in OS.get_cmdline_user_args():
		await _capture("casa_guarda_fora")


func _test_chest_after_tower() -> void:
	var coins := Economy.coins(world.store.data)
	var tower := _fixture("s1")
	world.player.position = tower.position
	_check(world.activate(tower), "tower outside the house anchors the chest reward")
	await process_frame
	await process_frame
	var on_disk := SaveStore.new(world.store.path)
	_check(on_disk.load_progress() and "bau_guarda" in on_disk.data["collected"] and Economy.coins(on_disk.data) == coins, "chest and coins are saved together after tower meditation")


func _fixture(id: String) -> PortInteractable:
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
	push_error("House test timed out before completion")
	quit(1)
