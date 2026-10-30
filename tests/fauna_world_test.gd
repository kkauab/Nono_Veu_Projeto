extends SceneTree
## Fauna no mapa real (slot de QA, nunca o save do jogador): poleiros presos às
## peças do cenário (nada pousado na água, no ar ou dentro de parede), ordem por
## profundidade, casas dos animais em chão livre e longe de alavancas, e um
## minuto de Senu correndo e atacando pelo Cais e pelo Mercado sem animal na
## água ou dentro do cenário e sem duas aves no mesmo poleiro.
## Uso: Godot --headless --path . --script res://tests/fauna_world_test.gd -- --qa

const Threat = preload("res://scripts/world/fauna_threat.gd")
var world: Node
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)


func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("fauna_world_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	check(world.store.path.begins_with("user://qa/"), "Teste da fauna nunca usa o save real")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	var birds: BirdLife = world.actors.get_node("BirdLife")
	var animals: AnimalLife = world.actors.get_node("AnimalLife")
	# O teste avança o tempo à mão.
	birds.process_mode = Node.PROCESS_MODE_DISABLED
	animals.process_mode = Node.PROCESS_MODE_DISABLED
	world.player.controls_enabled = false
	_perches(birds, animals)
	_depth(birds)
	_homes(animals)
	await _chase(birds, animals)
	print("FAUNA WORLD CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)


func _perches(birds: BirdLife, animals: AnimalLife) -> void:
	for perch in birds.perches_by_id.values():
		var id: String = perch["id"]
		check(perch["enabled"], "Poleiro '%s' encontrou a sua peça no mapa" % id)
		if not perch["enabled"]: continue
		var ground: Vector2 = perch["ground"]
		if perch.has("prop"):
			var prop: Node2D = null
			for node in world.actors.get_children():
				if node is PortProp and node.kind == perch["prop"] and node.position.distance_to(ground) < 12.0:
					prop = node
			check(prop != null, "Poleiro '%s' fica sobre um(a) %s" % [id, perch["prop"]])
		else:
			check(animals.is_floor_free(ground), "Poleiro '%s' no chão fica em piso livre (nem água, nem cenário)" % id)


func _depth(birds: BirdLife) -> void:
	for bird in birds.birds:
		if bird.state != BirdLife.BirdActor.State.PERCHED: continue
		var perch: Dictionary = bird.current_perch
		check(bird.z_index == 0 and not bird.y_sort_enabled, "%s pousada entra na ordem por profundidade" % bird.bird_id)
		check(bird.position.y > perch["ground"].y, "%s ordena logo à frente do poleiro (não some atrás dele)" % bird.bird_id)
		check(bird.position.y - perch["ground"].y <= 3.0, "%s não passa na frente de quem está diante do poleiro" % bird.bird_id)


func _homes(animals: AnimalLife) -> void:
	for animal in animals.animals:
		check(animals.is_floor_free(animal.home_pos), "Casa de %s em chão livre" % animal.animal_id)
		var near := ""
		for node in world.actors.get_children():
			if node is PortInteractable and node.kind in ["lever", "npc", "shrine", "nous", "valve", "bell", "dial"] and node.position.distance_to(animal.home_pos) < 20.0:
				near = "%s %s" % [node.kind, node.item_id]
		check(near == "", "Casa de %s longe de alavancas e de quem se fala (%s)" % [animal.animal_id, near])


## Um minuto de Senu correndo em volta do Cais e do Mercado, atacando de vez em quando.
func _chase(birds: BirdLife, animals: AnimalLife) -> void:
	var hero = world.player
	var route := [Vector2(8, 1), Vector2(14, 0), Vector2(21, 1), Vector2(23, -2), Vector2(19, 2), Vector2(10, 0)]
	var leg := 0
	var on_water := 0
	var in_scenery := 0
	var stacked := 0
	var flying_low := 0
	var fled := 0
	var reacted := {}
	for step in range(1200):
		var goal: Vector2 = PortLayout.iso(route[leg])
		var offset: Vector2 = goal - hero.position
		if offset.length() < 6.0:
			leg = (leg + 1) % route.size()
		var velocity: Vector2 = offset.normalized() * 136.0
		hero.position += velocity * .05
		hero.velocity = velocity
		hero.attack_timer = .2 if step % 80 < 4 else 0.0
		await physics_frame
		birds._process(.05)
		animals._process(.05)
		for animal in animals.animals:
			if animal.state in [AnimalLife.AnimalActor.State.REACT, AnimalLife.AnimalActor.State.FLEE]:
				reacted[animal.animal_id] = true
			if not animals.is_floor_free(animal.position):
				var tile := Vector2i((PortLayout.unproject(animal.position) + Vector2(.5, .5)).floor())
				if not PortLayout.tile_catalog().has(tile): on_water += 1
				else: in_scenery += 1
		var held := {}
		for bird in birds.birds:
			var perched: bool = bird.state == BirdLife.BirdActor.State.PERCHED
			var perch: Dictionary = bird.current_perch if perched else bird.target_perch
			if held.has(perch.get("id", "")): stacked += 1
			held[perch.get("id", "")] = true
			if not perched and bird.z_index != BirdLife.FLY_Z: flying_low += 1
			if not perched and bird.flee_from.is_finite(): fled += 1
	hero.velocity = Vector2.ZERO
	hero.attack_timer = 0.0
	check(on_water == 0, "Nenhum animal anda sobre a água com Senu correndo (%d quadros)" % on_water)
	check(in_scenery == 0, "Nenhum animal entra no cenário com Senu correndo (%d quadros)" % in_scenery)
	check(stacked == 0, "Nenhum poleiro com duas aves (%d quadros)" % stacked)
	check(flying_low == 0, "Ave em voo sempre acima dos telhados (%d quadros)" % flying_low)
	check(fled > 0, "Senu correndo e atacando espanta aves do Cais e do Mercado")
	check(reacted.size() >= 2, "Senu correndo e atacando assusta cães e gatos do caminho (%s)" % str(reacted.keys()))
	# Desempenho: longe de Senu, nenhum animal processa.
	hero.position = PortLayout.iso(Vector2(85, 13))
	animals._process(.05)
	var awake := animals.awake_count()
	check(awake == 0, "Senu no Farol: nenhum cão ou gato processa (%d)" % awake)
	print("FAUNA: animais acordados com Senu no Cais = %d de %d" % [_awake_at(animals, Vector2(10, 1)), animals.animals.size()])


func _awake_at(animals: AnimalLife, tile: Vector2) -> int:
	world.player.position = PortLayout.iso(tile)
	animals._process(.0)
	return animals.awake_count()
