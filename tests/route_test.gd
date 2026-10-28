extends SceneTree

var world: Node2D
var failures: Array[String] = []
var checks := 0
var route_cursor := 0
var last_route_tile := Vector2.ZERO

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Este teste exige -- --qa para nunca usar o save real.")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	# Este percurso continua isolando a navegação da rota original. Os puzzles
	# obrigatórios e seu bloqueio físico são exercitados em world_v6_test.gd.
	for seal in ["seal_bells", "seal_water", "seal_stars"]:
		world.store.data["flags"][seal] = true
	world.refresh_seals()
	var markers: Dictionary = PortLayout.MARKERS
	last_route_tile = markers["hub_spawn"]
	check(world.qa_mode and world.store.path.begins_with("user://qa/"), "Save de teste isolado")
	var floor_layer: PortLayout = world.layout
	check(floor_layer != null and floor_layer.tiles.size() >= 1200, "Porto ampliado possui mais de 1.200 pisos caminháveis")
	check(PortLayout.ROOMS.size() >= 13, "Porto possui treze setores de exploração")
	for enemy in get_nodes_in_group("enemies"):
		if enemy.is_boss:
			enemy.set_physics_process(false)
		else:
			enemy.receive_hit(9999, world.player.position, true)
	await physics_frame
	print("ROUTE_STAGE portão e mercado")
	check(await walk_to(Vector2(1, 2.5)), "Caminho até a frente do portão inicial")
	await drive_to(PortLayout.iso(Vector2(1, 5)), 100)
	check(PortLayout.unproject(world.player.position).y < 3.8, "Atalho não pode ser atravessado antes da alavanca")
	check(await walk_to(markers["hub_spawn"]), "Retorno seguro da frente do portão")
	if not await follow_main(Vector2.ZERO, 0, "market"):
		await finish()
		return
	if not await walk_tiles([Vector2(20.5, 4), Vector2(20.5, 10), Vector2(20.5, 18.5)], "Ramo do Aqueduto"):
		await finish()
		return
	await drive_to(PortLayout.iso(Vector2(20.5, 21)), 100)
	check(PortLayout.unproject(world.player.position).y < 19.8, "Aqueduto fechado não permite antecipar o jardim")
	if not await walk_tiles([Vector2(20.5, 10), Vector2(21, 4), last_route_tile], "Retorno ao mercado"):
		await finish()
		return
	if not await follow_main(Vector2.ZERO, 0, "p3"):
		await finish()
		return
	if not await walk_tiles([Vector2(35, 20), Vector2(35, 27), markers["nous_patio"]], "Desvio do pátio"):
		await finish()
		return
	print("ROUTE_STAGE pátio e desvios de exploração")
	var pickup := find_item("nous_patio")
	check(pickup != null and world.activate(pickup), "Pickup alcançável no pátio")
	check(world.store.data["fragments"] == 1, "Nous coletado por exploração")
	check(await walk_to(markers["adagas"]), "Desvio da cripta leva à arma alternativa")
	check(world.activate(find_item("adagas")), "Descoberta das Adagas")
	check(world.player.weapon_unlocked[1] and world.player.equip_weapon(1), "Arma encontrada pode ser equipada")
	if not await walk_tiles([Vector2(36, 28), Vector2(30, 28), Vector2(30, 29), Vector2(30, 31), Vector2(30, 33), Vector2(30, 31), Vector2(30, 29), Vector2(35, 28), Vector2(35, 20), last_route_tile], "Desvio do embarcadouro"):
		await finish()
		return
	if not await follow_main(markers["alavanca_aqueduct"], 43):
		await finish()
		return
	check(world.activate(find_item("alavanca_aqueduct")), "Jardim abre o segundo atalho pelo lado distante")
	await physics_frame
	check(world.aqueduct_gate.opened and world.aqueduct_gate.get_node("Barrier").disabled, "Segundo atalho remove colisão física")
	print("ROUTE_STAGE segundo loop e guarita")
	if not await walk_tiles([Vector2(19, 21), Vector2(20.5, 20.3), Vector2(20.5, 18.5), Vector2(20.5, 10), Vector2(21, 4), Vector2(20.5, 10), Vector2(20.5, 18.5), Vector2(20.5, 20.3), Vector2(19, 21), last_route_tile], "Loop pelo Aqueduto"):
		await finish()
		return
	if not await follow_main(markers["s1"]):
		await finish()
		return
	check(world.activate(find_item("s1")) and world.store.data["checkpoint"] == "s1", "Checkpoint registra santuário válido")
	# O descanso agora recria encontros. Esta suíte isola somente a navegação;
	# enemy_respawn_test verifica o renascimento e combat_test verifica os golpes.
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		if enemy.is_boss: enemy.set_physics_process(false)
		else: enemy.queue_free()
	await physics_frame
	check(await walk_to(markers["alavanca"]), "Alavanca alcançável pelo lado de trás")
	check(world.activate(find_item("alavanca")), "Alavanca abre atalho")
	await physics_frame
	check(world.shortcut.opened and world.shortcut.get_node("Barrier").disabled, "Atalho remove colisão física")
	if not await walk_tiles([Vector2(3, 18), Vector2(2, 17), Vector2(2, 16), Vector2(1, 14), Vector2(1, 4), Vector2(1, 2), markers["hub_spawn"]], "Retorno físico ao hub"):
		await finish()
		return
	var balance_before: int = int(world.store.data["fragments"])
	# O XP recolhido no caminho já pode ter somado dano de nível; a compra soma +4.
	var damage_before: int = world.player.damage_bonus
	check(world.buy_skill("vontade"), "Compra de habilidade com o Nous encontrado")
	check(world.player.damage_bonus == damage_before + 4 and world.store.data["fragments"] == balance_before - 1, "Compra aplica melhoria e debita moeda")
	print("ROUTE_STAGE arena e Catacumbas")
	# O santuário é sólido: Senu o contorna pela esquerda e para na frente dele.
	if not await walk_tiles([Vector2(1, 2), Vector2(1, 4), Vector2(1, 14), Vector2(2, 16), Vector2(2, 17), Vector2(3, 18), Vector2(6.2, 20.6), markers["s1"] + Vector2(.4, .4)], "Retorno à guarita"):
		await finish()
		return
	if not await follow_main(markers["selo"]):
		await finish()
		return
	await drive_to(PortLayout.iso(Vector2(-14, 25)), 100)
	check(PortLayout.unproject(world.player.position).x > -12.8, "Catacumbas bloqueadas antes da derrota do chefe")
	check(await walk_to(markers["selo"]), "Reaproximação física pelo centro da saída após testar a barreira")
	world.boss.receive_hit(9999, world.player.position, true)
	await physics_frame
	check(world.store.data["flags"]["boss"] and world.exit_gate.opened, "Derrota real do chefe abre saída")
	if not await follow_main(PortLayout.MAIN_ROUTE_WAYPOINTS[-1]):
		await finish()
		return
	check(world.store.data["flags"]["complete"], "Limiar registra fim do percurso da demo")
	print("ROUTE_STAGE Galeria do Eco")
	var echo_lever := find_item("alavanca_eco")
	check(echo_lever != null and not world.echo_gate.opened, "Grade do Eco começa fechada")
	if not await walk_tiles([Vector2(-18, 22), Vector2(-18, 19), Vector2(-18, 3), Vector2(-18, 0), Vector2(-7, -.5)], "Subida pela Galeria do Eco"):
		await finish()
		return
	await drive_to(PortLayout.iso(Vector2(-3, -.5)), 100)
	check(PortLayout.unproject(world.player.position).x < -5.2, "Grade do Eco fechada segura Senu do lado da galeria")
	if not await walk_tiles([Vector2(-9, -1)], "Retorno à alavanca do Eco"):
		await finish()
		return
	check(world.activate(echo_lever) and world.echo_gate.opened and world.store.data["flags"]["echo"], "Alavanca ergue a grade pelo lado das Catacumbas")
	await physics_frame
	check(world.echo_gate.get_node("Barrier").disabled, "Grade erguida perde a colisão")
	if not await walk_tiles([Vector2(-6, -.5), markers["hub_spawn"]], "Retorno ao santuário pela grade"):
		await finish()
		return
	check(PortLayout.room_at(world.player.position) == "hub", "Galeria do Eco devolve Senu ao santuário")
	for room_id in ["hub", "p1", "market", "p2", "bridge", "p3", "secret", "lower_dock", "garden", "aqueduct", "p4", "b1", "a02", "echo_descent", "echo_gallery"]:
		check(room_id in world.store.data["visited"], "Jornada descobre o setor %s" % room_id)
	var reload := DemoSaveStore.new(world.store.path)
	check(reload.load_progress(), "Save real da jornada reabre")
	check(reload.data["flags"]["shortcut"] and reload.data["flags"]["boss"] and "vontade" in reload.data["skills"], "Mundo/chefe/habilidade persistem depois do percurso")
	check(reload.data["flags"].get("aqueduct", false), "Segundo atalho permanece aberto no save")
	check(reload.data["flags"].get("echo", false), "Grade do Eco permanece erguida no save")
	check(reload.data["equipped"] == DemoSaveStore.WEAPONS[1] and "nous_patio" in reload.data["collected"], "Equipamento e pickup persistem")
	await finish()

func finish() -> void:
	print("ROUTE CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	paused = false
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func follow_main(target_tile: Vector2, radius: float = 7.0, stop_room: String = "") -> bool:
	while route_cursor < PortLayout.MAIN_ROUTE_WAYPOINTS.size():
		var tile: Vector2 = PortLayout.MAIN_ROUTE_WAYPOINTS[route_cursor]
		route_cursor += 1
		if not await walk_tiles([tile], "Rota principal"):
			return false
		last_route_tile = tile
		if stop_room != "":
			if PortLayout.room_at(world.player.position) == stop_room:
				return true
		elif world.player.position.distance_to(PortLayout.iso(target_tile)) <= radius:
			return true
	check(false, "Destino não encontrado na rota principal: %s / %s" % [target_tile, stop_room])
	return false

func walk_tiles(tiles: Array, description: String) -> bool:
	for tile: Vector2 in tiles:
		var arrived := await walk_to(tile)
		check(arrived, "%s em %s" % [description, tile])
		if not arrived:
			return false
	return true

func find_item(id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id:
			return item
	return null

func walk_to(tile: Vector2) -> bool:
	var arrived := await drive_to(PortLayout.iso(tile), 480)
	if not arrived:
		print("ROUTE_BLOCKED target=%s actual_tile=%s" % [tile, PortLayout.unproject(world.player.position)])
	return arrived

func drive_to(target: Vector2, frames: int) -> bool:
	var arrived := false
	for frame in range(frames):
		if world.hud.overlay != "":
			world.hud.show_overlay("")
		var delta: Vector2 = target - world.player.position
		if delta.length() < 7:
			arrived = true
			break
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		if absf(delta.x) > 3:
			Input.action_press("move_right" if delta.x > 0 else "move_left")
		if absf(delta.y) > 3:
			Input.action_press("move_down" if delta.y > 0 else "move_up")
		await physics_frame
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)
	await physics_frame
	return arrived
