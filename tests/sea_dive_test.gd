extends SceneTree

# Mergulho (docs/MUNDO_BARCO_ILHA.md, "Mergulho"): mapa de profundidade e água rasa;
# tesouros e ruínas no mar; salto do barco parado; mergulho e subida; fôlego que
# acaba e machuca; crocodilos sem faro para o mergulhador; ânforas que pagam uma
# vez só; a estela; subir de volta no barco pela água; reaparecer no santuário
# desfaz o mergulho. Precisa do mundo real: rode com -- --qa.
# Com --capture-dive (e janela), grava capturas do fundo em qa/mar_mergulho/.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Art = preload("res://scripts/world/port_art.gd")
const Sea = preload("res://scripts/world/sea.gd")
const Swim = preload("res://scripts/world/sea_swim.gd")
const Dive = preload("res://scripts/world/sea_dive.gd")
const Depth = preload("res://scripts/world/sea_depth.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE sea dive test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/sea_dive_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	_test_depth()
	_test_placement()
	_test_swim_poses()
	await _test_leap_and_dive()
	await _test_treasures()
	await _test_out_of_breath()
	await _test_reboard()
	await _test_respawn()
	if "--capture-dive" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		print("CAPTURE começa em t=%d s" % (Time.get_ticks_msec() / 1000))
		await _capture()
	_check(not FileAccess.file_exists(world.store.path), "nada disso grava a jornada (só as torres gravam)")
	print("SEA DIVE RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _free(point: Vector2, radius: float = 6.0) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0, point)
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _test_depth() -> void:
	_check(Depth.texture() != null, "o mapa de profundidade existe")
	var land: Vector2i = world.layout.tiles.keys()[0]
	_check(Depth.at_tile(land) == 0, "chão tem profundidade 0")
	_check(Depth.at_tile(Vector2i(40, 52)) > 0, "a Baía das Garças é mar")
	_check(Depth.at_tile(Vector2i(100, 120)) == Depth.MAX_DEPTH, "mar aberto longe de tudo é fundo")
	var water: ShaderMaterial = Art.water_material()
	_check(water.get_shader_parameter("depth_map") != null, "a água da superfície recebeu o mapa (água rasa)")
	var near := false
	for tile: Vector2i in world.layout.tiles:
		for side in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not world.layout.tiles.has(tile + side) and Depth.at_tile(tile + side) == 1:
				near = true
		if near:
			break
	_check(near, "o mar colado ao paredão tem profundidade 1")


func _test_placement() -> void:
	for item: Dictionary in Dive.TREASURES:
		var point := Layout.iso(item["tile"])
		_check(Depth.at_point(point) >= 2, "%s fica no mar, longe do paredão (%d)" % [item["id"], Depth.at_point(point)])
		_check(_free(point, 8.0), "%s fica em água livre para nadar até ele" % item["id"])
	for entry: Array in Dive.LANDMARKS:
		_check(Depth.at_point(Layout.iso(entry[1])) >= 1, "%s em %s fica no mar" % [entry[0], entry[1]])
	var markers := get_nodes_in_group("dive_treasures")
	_check(markers.size() == Dive.TREASURES.size(), "um marcador por tesouro (%d)" % markers.size())
	for marker in markers:
		_check(not marker.active, "%s fica fora do laço de interação da superfície" % marker.item_id)
	var scene: Dictionary = Dive.scene(world)
	var kinds := {}
	for item: Array in scene["items"]:
		kinds[item[0]] = int(kinds.get(item[0], 0)) + 1
	_check(kinds.get("block", 0) > 100 and kinds.get("post", 0) > 10 and kinds.get("prop", 0) > 200, "o fundo tem blocos, estacas e peças (%s)" % kinds)
	var ys: PackedFloat32Array = scene["ys"]
	var sorted := true
	for index in range(1, ys.size()):
		sorted = sorted and ys[index] >= ys[index - 1]
	_check(sorted, "o fundo é desenhado de trás para a frente")


## A folha de nado (build_senu_swim_v1.gd): 8 direções × 6 quadros nos dois ciclos,
## a superfície sem corpo abaixo da linha d'água e nada encostado na borda do quadro.
func _test_swim_poses() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Swim.POSES))
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(str(manifest["texture"])))
	var size := Vector2i(int(manifest["canvas"][0]), int(manifest["canvas"][1]))
	var pivot := Vector2i(int(manifest["pivot"][0]), int(manifest["pivot"][1]))
	var columns := int(manifest["columns"])
	for mode in ["surface", "dive"]:
		var complete := true
		var moving := true
		var dry := true
		var inside := true
		for direction in Swim.POSE_DIRECTIONS:
			var frames: Array = manifest["sprites"].get(mode + "_" + direction, {}).get("frames", [])
			complete = complete and frames.size() == 6
			var previous := PackedByteArray()
			var changes := 0
			for frame in frames:
				var cell := sheet.get_region(Rect2i(Vector2i(int(frame) % columns, int(frame) / columns) * size, size))
				var bytes := cell.get_data()
				changes += int(bytes != previous)
				previous = bytes
				for y in range(size.y):
					for x in range(size.x):
						if cell.get_pixel(x, y).a <= 0.0:
							continue
						if x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1:
							inside = false
						if mode == "surface" and y > pivot.y + 10:
							dry = false
			moving = moving and changes == frames.size()
		_check(complete, "nado %s: 8 direções com 6 quadros" % mode)
		_check(moving, "nado %s: cada quadro do ciclo muda" % mode)
		_check(inside, "nado %s: nada encosta na borda do quadro" % mode)
		if mode == "surface":
			_check(dry, "nado na superfície: só cabeça, ombros e braços acima d'água")
	_check(not Swim.pose("surface", Vector2.DOWN, .4).is_empty() and Swim.pose("dive", Vector2.RIGHT, .4)["lying"] and not Swim.pose("dive", Vector2.UP, .4)["lying"], "as poses saem pela direção certa (deitado para os lados, de pé para cima)")


func _test_leap_and_dive() -> void:
	var player: SenuPlayer = world.player
	player.heal_full()
	player.global_position = Layout.iso(Sea.DOCKS["sabu"]["land"])
	_check(Sea.board(world), "Senu embarca no Píer de Sabu")
	for frame in range(60):
		await physics_frame
	_check(world.at_sea, "Senu está no barco")
	world.boat.global_position = Layout.iso(Vector2(25.5, 45.5))
	world.boat.velocity = Vector2.ZERO
	_check(Sea.leap(world), "com o barco parado, Senu salta na água")
	_check(Swim.active(world) and not world.at_sea, "Senu nada e o barco fica vazio")
	_check(world.boat.rider == null, "ninguém rema o barco")
	_check(Depth.at_point(player.global_position) > 0, "o salto cai na água")
	var croc: Node2D = get_nodes_in_group("sea_beasts")[0]
	_check(not croc.target().is_empty(), "na superfície, o crocodilo sente o nadador")
	_check(Dive.start(world), "Espaço leva Senu ao fundo")
	_check(Dive.active(world), "Senu está mergulhado")
	_check(croc.target().is_empty(), "mergulhado, Senu some do faro dos crocodilos")
	var view := Dive.view(world)
	_check(view != null, "a camada do fundo aparece")
	_check(Swim.view(world) != null and not Swim.view(world).visible, "o nadador da superfície some")
	# A transição dura Dive.FADE segundos; em headless os quadros passam depressa.
	await create_timer(Dive.FADE + .2).timeout
	_check(view.modulate.a > .9, "o fundo entra por completo (%.2f)" % view.modulate.a)
	_check(not view.schools.is_empty(), "há cardumes no fundo")
	var muffled := false
	var bus := AudioServer.get_bus_index("Ambiente")
	if bus >= 0:
		for index in range(AudioServer.get_bus_effect_count(bus)):
			muffled = muffled or AudioServer.get_bus_effect(bus, index).resource_name == "mergulho"
		_check(muffled, "embaixo d'água o som do mar fica abafado")
	var before := player.global_position
	for frame in range(90):
		Dive.step(world, Vector2(1, 0), false, 1.0 / 60.0)
		await physics_frame
	_check(player.global_position.distance_to(before) > 40.0, "Senu nada no fundo (%.0f px)" % player.global_position.distance_to(before))
	var breath := Dive.breath(world)
	_check(Dive.spend_breath(world, 5.0) and is_equal_approx(Dive.breath(world), breath - 5.0), "o fôlego vai acabando")


func _test_treasures() -> void:
	var player: SenuPlayer = world.player
	var marker: Node2D = null
	for candidate in get_nodes_in_group("dive_treasures"):
		if candidate.item_id == "dive_amphora_1":
			marker = candidate
	player.global_position = marker.global_position + Vector2(6, 0)
	_check(Dive.treasure_in_reach(world) == marker, "perto da ânfora, ela é a escolhida")
	var coins: int = int(world.store.data.get("coins", 0))
	Dive.take(world, marker)
	await process_frame
	_check(int(world.store.data.get("coins", 0)) == coins + 15, "a ânfora do fundo paga 15 óbolos")
	_check("dive_amphora_1" in world.store.data["collected"], "a ânfora aberta fica registrada")
	_check(Dive.treasure_in_reach(world) == null, "a ânfora aberta some do fundo")
	var stela: Node2D = null
	for candidate in get_nodes_in_group("dive_treasures"):
		if candidate.item_id == "dive_stela":
			stela = candidate
	player.global_position = stela.global_position
	_check(Dive.treasure_in_reach(world) == stela, "perto da estela, E a lê")
	Dive.take(world, stela)
	_check(world.hud.dialog_title == Dive.STELA_TITLE, "a estela abre o texto")
	world.hud.show_overlay("")
	_check(is_instance_valid(stela) and stela.is_in_group("dive_treasures"), "a estela continua lá para reler")


func _test_out_of_breath() -> void:
	var player: SenuPlayer = world.player
	player.heal_full()
	for frame in range(30):
		await physics_frame
	var health := player.health
	_check(not Dive.spend_breath(world, Dive.BREATH + 1.0), "sem fôlego, Senu sobe")
	_check(not Dive.active(world) and Swim.active(world), "volta a nadar na superfície")
	_check(player.health < health, "subir sem fôlego machuca (%d → %d)" % [health, player.health])
	await create_timer(Dive.FADE + .2).timeout
	await process_frame
	_check(Dive.view(world) == null, "a camada do fundo some depois da subida")
	var muffled := false
	var bus := AudioServer.get_bus_index("Ambiente")
	if bus >= 0:
		for index in range(AudioServer.get_bus_effect_count(bus)):
			muffled = muffled or AudioServer.get_bus_effect(bus, index).resource_name == "mergulho"
	_check(not muffled, "na superfície o som volta ao normal")


func _test_reboard() -> void:
	var player: SenuPlayer = world.player
	player.heal_full()
	player.global_position = world.boat.global_position + Vector2(12, 4)
	_check(Sea.boat_in_reach(world), "nadando ao lado do barco vazio, dá para subir")
	_check(Sea.reboard(world), "E sobe no barco pela água")
	for frame in range(60):
		await physics_frame
	_check(world.at_sea and world.boat.rider == player, "Senu volta a remar")
	_check(not Swim.active(world), "e já não está nadando")


func _test_respawn() -> void:
	world.boat.velocity = Vector2.ZERO
	_check(Sea.leap(world), "salta de novo")
	_check(Dive.start(world), "e mergulha")
	Sea.respawn(world)
	await process_frame
	_check(not Dive.active(world) and not Swim.active(world), "reaparecer no santuário desfaz o mergulho e o nado")
	_check(Dive.view(world) == null, "e a camada do fundo")


## Capturas do fundo com janela: ruínas, casco, paredão e estacas.
func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/mar_mergulho"))
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world.hud.hide()
	var player: SenuPlayer = world.player
	player.heal_full()
	player.global_position = Layout.iso(Sea.DOCKS["sabu"]["land"])
	Sea.board(world)
	# Com janela a física segue o monitor (até 240 passos/s): espera pelo relógio.
	await create_timer(Sea.HOP + .4).timeout
	world.boat.global_position = Layout.iso(Vector2(24, 46))
	world.boat.velocity = Vector2.ZERO
	print("CAPTURE leap=", Sea.leap(world))
	var camera: Camera2D = player.get_node("IsometricCamera")
	camera.position_smoothing_enabled = false
	# Nado na superfície, de perto: braçada para a direita e para baixo.
	for heading in [["direita", Vector2.RIGHT], ["baixo", Vector2.DOWN]]:
		camera.zoom = Vector2.ONE * 3.0
		# Longe o bastante do barco vazio, que ficaria por cima do nadador.
		for frame in range(150):
			Swim.swim_step(world, heading[1], false, 1.0 / 60.0)
			await process_frame
		camera.reset_smoothing()
		camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/mar_mergulho/nado_superficie_%s.png" % heading[0])
		print("CAPTURE nado_superficie_", heading[0])
	print("CAPTURE dive=", Dive.start(world))
	for heading in [["direita", Vector2.RIGHT], ["baixo", Vector2.DOWN]]:
		for frame in range(30):
			Dive.step(world, heading[1], false, 1.0 / 120.0)
			await process_frame
		camera.reset_smoothing()
		camera.force_update_scroll()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/mar_mergulho/nado_fundo_%s.png" % heading[0])
		print("CAPTURE nado_fundo_", heading[0])
	player.facing = Vector2.RIGHT
	for spot in [["ruinas", Vector2(23, 49.5), 1.0], ["ruinas_perto", Vector2(22.5, 48.5), 2.0], ["paredao_estacas", Vector2(27, 40.5), 1.0], ["casco", Vector2(77, 79), 1.0], ["ilha_bennu", Vector2(44, 57), 1.0]]:
		player.global_position = Layout.iso(spot[1])
		world.set_meta("dive_breath", Dive.BREATH * .6)
		camera.zoom = Vector2.ONE * float(spot[2])
		camera.reset_smoothing()
		camera.force_update_scroll()
		var started := Time.get_ticks_msec()
		for frame in range(20):
			await process_frame
		print("CAPTURE quadros em %d ms (t=%d s)" % [Time.get_ticks_msec() - started, Time.get_ticks_msec() / 1000])
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/mar_mergulho/fundo_%s.png" % spot[0])
		print("CAPTURE fundo_", spot[0], " senu=", player.global_position, " camera=", camera.get_screen_center_position())


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		print("FAIL ", label)


func _on_timeout() -> void:
	print("SEA DIVE TIMEOUT checks=%d failures=%s" % [checks, failures])
	quit(2)
