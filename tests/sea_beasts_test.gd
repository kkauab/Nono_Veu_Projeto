extends SceneTree

# Bichos do mar, casco do barco, nado e escadas (docs/MUNDO_BARCO_ILHA.md):
# crocodilos em mar aberto e longe dos píeres; mordidas que tiram casco até ele
# ceder; Senu na água preso ao mar pelas bordas; mordidas no nadador; escadas só
# em chão aberto (sem portão), uma subida que devolve Senu à terra e leva o barco
# ao píer daquele chão; os bichos desistindo em terra; e a morte na água.
# Precisa do mundo real: rode com -- --qa.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Sea = preload("res://scripts/world/sea.gd")
const Boat = preload("res://scripts/world/sea_boat.gd")
const Swim = preload("res://scripts/world/sea_swim.gd")
const Beasts = preload("res://scripts/world/sea_beasts.gd")
const Ladders = preload("res://scripts/world/sea_ladders.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D
var catalog: Dictionary


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(240.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE sea beasts test needs the real world; append -- --qa")
		quit(1)
		return
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/sea_beasts_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	catalog = Layout.tile_catalog()
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	_test_beasts_placement()
	_test_ladders_placement()
	await _test_hull_and_capsize()
	await _test_swimming()
	await _test_climb()
	await _test_disengage()
	await _test_death_in_water()
	_check(not FileAccess.file_exists(world.store.path), "nada disso grava a jornada (só as torres gravam)")
	print("SEA BEASTS RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _beasts() -> Array:
	return get_nodes_in_group("sea_beasts")


func _ladders() -> Array:
	return get_nodes_in_group("sea_ladders")


func _tile(point: Vector2) -> Vector2i:
	return Vector2i(Layout.unproject(point).round())


func _free(point: Vector2, radius: float = 6.0) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0, point)
	return world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _test_beasts_placement() -> void:
	var beasts := _beasts()
	_check(beasts.size() == Beasts.HOMES.size(), "todos os bichos do catálogo estão no mar (%d)" % beasts.size())
	_check(beasts.any(func(beast): return beast.kind == "sobek"), "há um crocodilo de Sobek")
	for beast in beasts:
		_check(not beast.is_in_group("enemies"), "%s não é inimigo do porto" % beast.beast_id)
		var home := Layout.unproject(beast.home)
		var dry := false
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if catalog.has(Vector2i(home.round()) + Vector2i(dx, dy)):
					dry = true
		_check(not dry, "%s mora em mar aberto, a 2 tiles de qualquer chão" % beast.beast_id)
		_check(_free(beast.home, 9.0), "%s nasce sem tocar borda nem rochedo" % beast.beast_id)
		for id in Sea.DOCKS:
			_check(beast.home.distance_to(Layout.iso(Sea.DOCKS[id]["water"])) > Beasts.SAFE + 60.0, "%s mora longe do %s" % [beast.beast_id, Sea.DOCKS[id]["name"]])


func _test_ladders_placement() -> void:
	var ladders := _ladders()
	_check(ladders.size() >= 20, "há escadas em volta do mapa (%d)" % ladders.size())
	var open := _open_ground_independent()
	for ladder in ladders:
		var top := _tile(ladder.global_position)
		_check(catalog.has(top), "%s: o alto da escada é chão" % ladder.item_id)
		_check(open.has(top), "%s: chão que se alcança sem passar por portão" % ladder.item_id)
		_check(not catalog.has(_tile(ladder.water)), "%s: o pé da escada fica na água" % ladder.item_id)
		_check(not ladder.active, "%s: apagada enquanto Senu está em terra" % ladder.item_id)
		# Um ponto livre para o nadador (raio 6) dentro do alcance de subida.
		var reach: Vector2 = ladder.water + (ladder.water - ladder.global_position).normalized() * 10.0
		_check(_free(reach) and reach.distance_to(ladder.water) < Swim.LADDER_REACH, "%s: dá para nadar até o pé" % ladder.item_id)
	for id in Sea.DOCKS:
		_check(ladders.any(func(ladder): return ladder.dock == id), "o chão do %s tem escada" % Sea.DOCKS[id]["name"])
	var spaced := true
	for a in ladders:
		for b in ladders:
			if a != b and Layout.unproject(a.global_position).distance_to(Layout.unproject(b.global_position)) < Ladders.SPACING - .5:
				spaced = false
	_check(spaced, "as escadas ficam espaçadas (%.0f tiles)" % Ladders.SPACING)


## Chão aberto refeito aqui, sem o código do jogo: a pé a partir do santuário e
## dos píeres, sem cruzar nenhuma linha de portão.
func _open_ground_independent() -> Dictionary:
	var seen := {}
	var queue: Array[Vector2i] = [Vector2i((Layout.MARKERS["hub_spawn"] as Vector2).round())]
	for id in Sea.DOCKS:
		queue.append(Vector2i((Sea.DOCKS[id]["land"] as Vector2).round()))
	for start in queue:
		seen[start] = true
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = tile + step
			if seen.has(next) or not catalog.has(next):
				continue
			var middle := (Vector2(tile) + Vector2(next)) * .5
			var gated := false
			for gate: Dictionary in Layout.GATES.values():
				var a: Vector2 = gate["a"]
				var b: Vector2 = gate["b"]
				if Geometry2D.get_closest_point_to_segment(middle, a, b).distance_to(middle) < .01:
					gated = true
			if gated:
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _test_hull_and_capsize() -> void:
	world.player.reset_at(Layout.iso(Sea.DOCKS["sabu"]["land"]))
	await physics_frame
	_check(Sea.board(world), "Senu embarca no Píer de Sabu")
	for frame in range(60):
		await physics_frame
		if world.at_sea:
			break
	var boat: Node2D = world.boat
	_check(world.at_sea and boat.hull == Boat.HULL_MAX, "o casco começa inteiro (%d)" % boat.hull)
	# Barco parado em mar aberto, perto de um crocodilo.
	var croc: Node2D = _beasts().filter(func(beast): return beast.beast_id == "croc_baia")[0]
	boat.global_position = croc.home + Vector2(60, -20)
	var lowest: int = boat.hull
	var sank := false
	for frame in range(1500):
		await physics_frame
		lowest = mini(lowest, boat.hull)
		if Swim.active(world):
			sank = true
			break
	_check(lowest < Boat.HULL_MAX or sank, "os crocodilos mordem o casco (%d)" % lowest)
	_check(sank, "o casco cede e Senu cai na água")
	_check(not world.at_sea and Swim.active(world), "Senu sai do barco e passa a nadar")
	_check(world.boat_dock == Sea.dock_for_checkpoint(world) and boat.rider == null, "Sabu recupera o barco no píer do último santuário")
	_check(boat.hull == Boat.HULL_MAX, "o barco recuperado vem remendado")
	_check(not catalog.has(_tile(world.player.global_position)), "Senu cai na água, não em terra")
	_check(not world.player.visible and world.actors.get_node_or_null("SenuNadando") != null, "o nadador desenha o sprite de Senu cortado na água")
	_check(not world.player.controls_enabled, "na água não há golpe, esquiva nem selo")


func _test_swimming() -> void:
	var player: SenuPlayer = world.player
	player.heal_full()
	var before := player.global_position
	# Nadar contra a costa do porto, ao norte: as bordas seguram Senu na água.
	var wet := true
	for step in range(400):
		Swim.swim_step(world, Vector2(0, -1), true, 1.0 / 60.0)
		if catalog.has(_tile(player.global_position)):
			wet = false
		await physics_frame
	_check(wet, "nadando contra o paredão, Senu não sobe em terra sozinho")
	_check(player.global_position.distance_to(before) > 30.0, "Senu nada (%.0f px)" % player.global_position.distance_to(before))
	# Um crocodilo vai atrás e morde o nadador.
	var croc: Node2D = _beasts().filter(func(beast): return beast.beast_id == "croc_baia")[0]
	player.global_position = croc.global_position + Vector2(70, 0)
	player.heal_full()
	var bitten := false
	var chased := false
	for frame in range(900):
		await physics_frame
		chased = chased or croc.state in ["stalk", "bite"]
		if player.health < player.max_health:
			bitten = true
			break
	_check(chased, "o crocodilo persegue o nadador")
	_check(bitten, "o crocodilo morde Senu na água (%d de vida)" % player.health)
	player.heal_full()


func _test_climb() -> void:
	var player: SenuPlayer = world.player
	var ladder: Node2D = null
	for candidate in _ladders():
		if candidate.dock == "sabu" and (ladder == null or candidate.water.distance_to(player.global_position) < ladder.water.distance_to(player.global_position)):
			ladder = candidate
	player.global_position = ladder.water + (ladder.water - ladder.global_position).normalized() * 10.0
	await physics_frame
	_check(Swim.ladder_in_reach(world) == ladder, "ao pé da escada, ela é a escolhida")
	_check(ladder.active, "a escada próxima acende enquanto Senu nada")
	Sea.climb(world, ladder)
	for frame in range(90):
		await physics_frame
		if not world.sea_busy:
			break
	_check(not Swim.active(world) and not world.sea_busy, "Senu sobe pela escada e sai da água")
	_check(catalog.has(_tile(player.global_position)), "Senu termina em terra (%s)" % str(_tile(player.global_position)))
	_check(player.visible and player.controls_enabled and player.collision_layer == 2 and player.collision_mask == (1 | 4), "Senu volta a ter corpo, colisão e controles")
	_check(not _ladders().any(func(other): return other.active), "as escadas apagam em terra")
	# Numa ilha, a correnteza leva o barco ao píer daquele chão.
	var island: Node2D = _ladders().filter(func(other): return other.dock == "ibis")[0]
	Swim.start(world, island.water + (island.water - island.global_position).normalized() * 10.0)
	await physics_frame
	Sea.climb(world, island)
	for frame in range(90):
		await physics_frame
		if not world.sea_busy:
			break
	_check(world.boat_dock == "ibis", "subindo no Íbis, o barco aparece no Píer do Íbis (%s)" % world.boat_dock)
	_check(catalog.has(_tile(player.global_position)) and Layout.room_at(player.global_position) == "ibis", "Senu está na Ilha do Íbis")


func _test_disengage() -> void:
	for frame in range(600):
		await physics_frame
	_check(not _beasts().any(func(beast): return beast.state in ["stalk", "bite"]), "com Senu em terra, nenhum bicho caça")


func _test_death_in_water() -> void:
	var player: SenuPlayer = world.player
	var croc: Node2D = _beasts().filter(func(beast): return beast.beast_id == "croc_baia")[0]
	Swim.start(world, croc.global_position + Vector2(40, 0))
	await physics_frame
	player.receive_hit(999, croc.global_position)
	_check(player.dead, "Senu pode morrer na água")
	for frame in range(200):
		await physics_frame
		if not world.respawning and not player.dead:
			break
	_check(not Swim.active(world) and world.actors.get_node_or_null("SenuNadando") == null, "ao voltar ao santuário, Senu não está mais nadando")
	_check(player.visible and player.controls_enabled and player.collision_layer == 2, "Senu volta inteiro ao santuário")
	_check(catalog.has(_tile(player.global_position)), "Senu reaparece em terra")
	_check(_beasts().all(func(beast): return beast.state == "lurk" and beast.global_position.distance_to(beast.home) < 60.0), "os bichos voltam para casa")
	_check(world.boat.hull == Boat.HULL_MAX and world.boat_dock == Sea.dock_for_checkpoint(world), "o barco espera inteiro no píer do santuário")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Sea beasts test timed out before completion")
	quit(1)
