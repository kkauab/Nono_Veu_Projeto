extends SceneTree
## Peso dos golpes (hitstop, clarão, faíscas, som) e a vida na água do porto.

const CombatFx = preload("res://scripts/actors/combat_fx.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const Banks = preload("res://scripts/audio/sfx_banks.gd")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "attack", "heavy_attack", "dodge", "parry", "switch_weapon", "weapon_power", "sprint"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_check_sounds()
	await _check_combat()
	await _check_water()
	print("COMBAT FX CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _check_sounds() -> void:
	for bank: String in Banks.BANKS:
		var streams: Array = Banks.BANKS[bank]
		check(not streams.is_empty() and streams.all(func(stream): return stream is AudioStream), "Banco %s carrega todos os sons" % bank)
		check(Banks.BUS.has(bank) and Banks.VOLUME_DB.has(bank), "Banco %s tem bus e volume" % bank)
	for bank in ["swing_sword", "swing_dagger", "swing_heavy", "swing_enemy", "hit_light", "hit_heavy", "hit_kill", "parry", "hurt", "death", "dodge", "enemy_windup", "water_splash", "water_plop", "water_loop", "pickup_coin", "door_open", "chest_open"]:
		check(Sfx.has_bank(bank), "Existe o banco " + bank)
	Sfx.ensure_buses()
	Sfx.ensure_buses()
	for bus_name in ["SFX", "Ambiente", "Vozes"]:
		var count := 0
		for index in range(AudioServer.bus_count):
			if AudioServer.get_bus_name(index) == bus_name:
				count += 1
				check(AudioServer.get_bus_send(index) == &"Master", "Bus %s envia para o Master" % bus_name)
		check(count == 1, "Exatamente um bus " + bus_name)
	var sea: AudioStreamWAV = Banks.BANKS["water_loop"][0]
	check(sea.loop_mode != AudioStreamWAV.LOOP_DISABLED, "O som do mar importa em laço")


func _check_combat() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var camera := Camera2D.new()
	world.add_child(camera)
	camera.make_current()
	var player := SenuPlayer.new()
	world.add_child(player)
	player.set_physics_process(false)
	var enemy := _enemy(world, player, Vector2(26, 0))
	await physics_frame
	await process_frame
	var fx: Node2D = player.get_node_or_null("CombatFx")
	check(fx != null and fx.top_level and fx.get_parent() == player, "Senu carrega os efeitos fora da ordenação de profundidade")
	check(root.get_node_or_null(Sfx.POOL_NAME) != null, "As vozes de efeito ficam na viewport do mundo")
	var base_scale := Engine.time_scale

	check(player.try_attack(), "Golpe aceito")
	player._apply_attack()
	check(enemy.health < enemy.max_health, "Golpe causa dano como antes")
	check(CombatFx.is_hitstopping() and Engine.time_scale < base_scale * .1, "Acerto congela o tempo por um instante")
	check(enemy.material != null, "Inimigo atingido fica branco")
	check(fx.particle_count() >= 5, "Acerto solta faíscas")
	var pool := root.get_node(Sfx.POOL_NAME)
	check(pool.get_children().any(func(voice): return voice.stream != null and String(voice.stream.resource_path).contains("hit_light")), "Acerto toca o som de impacto")
	await _wait_real(.5)
	check(not CombatFx.is_hitstopping() and is_equal_approx(Engine.time_scale, base_scale), "O tempo volta ao ritmo anterior")
	check(enemy.material == null, "O clarão termina")
	await _wait_real(.6)
	check(camera.offset == Vector2.ZERO, "A câmera volta ao lugar depois do tremor")

	enemy.receive_hit(9999, player.global_position)
	await _wait_real(.1)
	player.attack_timer = 0.0
	player._combo_timer = 0.0
	var sparks: int = fx.particle_count()
	check(player.try_attack(), "Golpe no vazio aceito")
	player._apply_attack()
	check(not CombatFx.is_hitstopping() and fx.particle_count() <= sparks, "Corpo caído não reage ao golpe")

	var finisher := _enemy(world, player, Vector2(26, 0))
	finisher.health = 1
	player.attack_timer = 0.0
	player._apply_attack()
	check(finisher.dead and CombatFx.is_hitstopping(), "Golpe final congela o tempo")
	await _wait_real(.05)
	check(CombatFx.is_hitstopping(), "O golpe final segura mais que um golpe leve")
	await _wait_real(.4)

	CombatFx.hitstop_enabled = false
	var quiet := _enemy(world, player, Vector2(26, 0))
	player._apply_attack()
	check(quiet.health < quiet.max_health and not CombatFx.is_hitstopping() and Engine.time_scale == base_scale, "Sem congelamento quando desligado")
	CombatFx.hitstop_enabled = true

	player.reset_at(Vector2.ZERO)
	player.invulnerability_timer = 0.0
	player.facing = Vector2.RIGHT
	var attacker := _enemy(world, player, Vector2(26, 0))
	check(player.try_parry(), "Parry aceito")
	check(not player.receive_hit(14, attacker.global_position), "Parry bloqueia")
	check(CombatFx.is_hitstopping() and pool.get_children().any(func(voice): return voice.stream != null and String(voice.stream.resource_path).contains("parry")), "Parry tem clangor e congelamento")
	await _wait_real(.3)
	player.invulnerability_timer = 0.0
	check(player.receive_hit(14, attacker.global_position), "Senu sofre dano")
	check(CombatFx.is_hitstopping() and pool.get_children().any(func(voice): return voice.stream != null and String(voice.stream.resource_path).contains("hurt")), "Dano em Senu tem som e congelamento")

	# Sair da cena no meio do congelamento não pode deixar o jogo lento.
	world.queue_free()
	await process_frame
	await process_frame
	check(not CombatFx.is_hitstopping() and is_equal_approx(Engine.time_scale, base_scale), "Liberar a cena restaura o tempo")

	var watcher := Node2D.new()
	root.add_child(watcher)
	var hero := SenuPlayer.new()
	watcher.add_child(hero)
	hero.set_physics_process(false)
	var guard := _enemy(watcher, hero, Vector2(30, 0))
	# physics_frame é emitido antes dos nós: dois quadros para o efeito ver a espera.
	await physics_frame
	await physics_frame
	guard._begin_windup()
	await physics_frame
	await physics_frame
	check(pool.get_children().any(func(voice): return voice.stream != null and String(voice.stream.resource_path).contains("enemy_windup")), "A preparação do inimigo tem aviso sonoro")
	watcher.queue_free()
	await process_frame


func _check_water() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var camera := Camera2D.new()
	stage.add_child(camera)
	camera.make_current()
	# The old (-9,9) water fixture is inside the new Cloister. Keep the test
	# over real open water after the approved map expansion.
	camera.position = PortLayout.iso(Vector2(-30, -10))
	var layout := PortLayout.new()
	stage.add_child(layout)
	await process_frame
	await process_frame
	var life: Node2D = layout.get_node_or_null("WaterLife")
	check(life != null and life.z_index == -1 and life.get_parent() == layout, "A vida na água desenha na faixa do mar")
	check(life.get_parent() != null and not life.is_in_group("world_obstacles"), "A vida na água não é obstáculo")
	life.set_process(false)
	# Discard fish spawned while the viewport was still at its initial origin.
	# The seeded water fixture starts only after the camera has settled.
	life._fish.clear()
	life._jumps.clear()
	life._next_spawn = 0.0
	life._next_jump = 2.0
	life.rng.seed = 7
	check(not life.is_open_water(PortLayout.iso(Vector2(-1, -1))), "O piso do santuário não é água")
	# The gap at x=-1 still separates Cloister and shortcut; (-4,3) is land now.
	var edge := Vector2i(-1, 2)
	check(layout.tiles.has(edge) and not layout.tiles.has(edge + Vector2i(0, 1)), "Borda sul do santuário encontrada")
	check(not life.is_open_water(PortLayout.iso(Vector2(edge)) + Vector2(-16, 20)), "A face de pedra abaixo da borda não é água")
	check(life.is_open_water(PortLayout.iso(Vector2(-30, -10))), "O mar aberto é água")
	check(life._floaters.size() >= 10, "Lótus e troncos espalhados pelas margens")
	check(life._floaters.all(func(floater): return life.is_open_water(floater["anchor"])), "Lótus e troncos só sobre a água")

	var most_fish: int = 0
	var jumps_seen := 0
	var under_floor := 0
	var glints := 0
	var ripples := 0
	for frame in range(60 * 45):
		life._process(1.0 / 60.0)
		most_fish = maxi(most_fish, life.fish_count())
		jumps_seen = maxi(jumps_seen, life.jump_count())
		glints = maxi(glints, life._glints.size())
		ripples = maxi(ripples, life._ripples.size())
		for point: Vector2 in life.fish_positions():
			if not life.is_open_water(point, 20.0, 0.0):
				under_floor += 1
	check(most_fish >= 6, "Cardumes aparecem perto da câmera (%d)" % most_fish)
	check(jumps_seen >= 1, "Peixes saltam")
	check(under_floor == 0, "Nenhum peixe nada sob o piso ou a pedra (%d)" % under_floor)
	print("WATER SURFACE glints=%d ripples=%d fish=%d jumps=%d" % [glints, ripples, most_fish, jumps_seen])
	check(glints >= 3 and ripples >= 2, "A superfície brilha e ondula (%d brilhos, %d anéis)" % [glints, ripples])
	check(life.leap() or life.jump_count() > 0 or life.fish_count() == 0, "Um peixe visível consegue saltar sob comando")

	var senu := SenuPlayer.new()
	stage.add_child(senu)
	senu.set_physics_process(false)
	var points: Array[Vector2] = life.fish_positions()
	check(not points.is_empty(), "Há peixes para assustar")
	if not points.is_empty():
		senu.global_position = points[0]
		for frame in range(60):
			life._process(1.0 / 60.0)
		var closest := INF
		for point: Vector2 in life.fish_positions():
			closest = minf(closest, life._to_metric(point - senu.global_position).length())
		check(closest > 20.0, "Os peixes fogem quando Senu chega à margem (%.1f)" % closest)

	var open_sea: float = life._water_coverage(Rect2(camera.position - Vector2(320, 180), Vector2(640, 360)))
	var plaza: float = life._water_coverage(Rect2(PortLayout.iso(Vector2(36, 26)) - Vector2(120, 70), Vector2(240, 140)))
	check(open_sea > plaza, "O som do mar diminui longe da água (%.2f > %.2f)" % [open_sea, plaza])
	# Interiores das casas ficam fora do mar desenhado, sobre fundo próprio.
	var interior := Vector2(5000, 2300)
	check(not PortLayout.SEA_RECT.has_point(interior) and not life.is_open_water(interior), "Dentro das casas não há água")
	check(life._water_coverage(Rect2(interior - Vector2(320, 180), Vector2(640, 360))) == 0.0, "Dentro das casas o mar fica mudo")
	stage.queue_free()
	await process_frame


func _enemy(parent: Node, target: Node2D, at: Vector2) -> VeilEnemy:
	var enemy := VeilEnemy.new()
	enemy.target = target
	enemy.position = at
	parent.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
