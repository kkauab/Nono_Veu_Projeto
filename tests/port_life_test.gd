extends SceneTree
## Port life: vendors at the stalls, townsfolk routines on free floor, trade
## ships on their cycle in open water, buying food and talking. Runs in a QA slot.

const Catalog = preload("res://scripts/world/port_life_catalog.gd")
const Life = preload("res://scripts/world/port_life.gd")
const Economy = preload("res://scripts/economy/economy.gd")
var world: Node
var space: PhysicsDirectSpaceState2D
var catalog: Dictionary
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
		push_error("port_life_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	check(world.store.path.begins_with("user://qa/"), "Port life test never uses the real save")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	space = world.actors.get_world_2d().direct_space_state
	catalog = PortLayout.tile_catalog()
	var people := get_nodes_in_group("townsfolk")
	var vendors := people.filter(func(person): return person.kind == "vendor")
	var walkers := people.filter(func(person): return person.kind == "townsfolk")
	check(vendors.size() == Catalog.VENDORS.size(), "Todas as bancadas têm vendedor (%d de %d)" % [vendors.size(), Catalog.VENDORS.size()])
	check(walkers.size() == Catalog.TOWNSFOLK.size(), "Todos os moradores do catálogo estão no Porto")
	check(get_nodes_in_group("trade_ships").size() == Catalog.SHIPS.size(), "Os navios mercantes estão no mar")
	_placement(vendors, walkers)
	await _routines(walkers)
	_ships()
	await _buying(vendors)
	_talking(walkers)
	_making_way(walkers)
	_detour(walkers)
	await _sleeping(walkers)
	print("PORT LIFE CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _placement(vendors: Array, walkers: Array) -> void:
	for vendor in vendors:
		var stall: Node2D = null
		for node in world.actors.get_children():
			if node is PortProp and node.kind == "stall" and node.position.distance_to(vendor.position) < 50: stall = node
		check(stall != null, "%s fica junto de uma barraca" % vendor.item_id)
		check(_free(vendor.position), "%s fica em chão livre" % vendor.item_id)
		check(not vendor.is_in_group("enemies"), "%s não é alvo da espada" % vendor.item_id)
	# Só as passagens de verdade, entre duas salas: um píer sem saída pode ter pescador.
	var doorways: Array = []
	for connector in PortLayout.CONNECTORS:
		var rect: Rect2i = connector["rect"]
		var along_x := catalog.has(rect.position - Vector2i(1, 0)) and catalog.has(Vector2i(rect.end.x, rect.position.y))
		var along_y := catalog.has(rect.position - Vector2i(0, 1)) and catalog.has(Vector2i(rect.position.x, rect.end.y))
		if along_x or along_y:
			doorways.append(Rect2(Vector2(rect.position) - Vector2(.5, .5), Vector2(rect.size)).grow_individual(1.5 if along_x else .25, 1.5 if along_y else .25, 1.5 if along_x else .25, 1.5 if along_y else .25))
	for person in walkers:
		check(not person.is_in_group("enemies"), "%s não é alvo da espada" % person.item_id)
		for stop in person.stops:
			var at := PortLayout.unproject(stop["at"])
			check(not doorways.any(func(doorway: Rect2) -> bool: return doorway.has_point(at)), "%s não para na boca de uma passagem (%.1f, %.1f)" % [person.item_id, at.x, at.y])
		check(_body_at(person.position, person), "Senu esbarra em %s" % person.item_id)
		for index in range(person.stops.size()):
			var stop: Dictionary = person.stops[index]
			var points := PackedVector2Array([person.stops[index - 1]["at"]])
			points.append_array(stop["path"])
			var clear := true
			for k in range(points.size() - 1):
				var samples := maxi(2, ceili(points[k].distance_to(points[k + 1]) / 4.0))
				for s in range(samples + 1):
					if not _free(points[k].lerp(points[k + 1], float(s) / samples)): clear = false
			var tile := PortLayout.unproject(stop["at"])
			check(clear, "%s: caminho livre até a parada %d (%.1f, %.1f)" % [person.item_id, index, tile.x, tile.y])
			if stop["act"] == "buy":
				check(stop["vendor"] != null and stop["at"].distance_to(stop["vendor"].position) < 44, "%s compra ao alcance do vendedor" % person.item_id)

func _routines(walkers: Array) -> void:
	# Senu longe de todos: ninguém para à espera dele.
	world.player.reset_at(PortLayout.iso(Vector2(85, 13)))
	await physics_frame
	for person in walkers: person.visits = 0
	for step in range(2400):
		for ship in get_nodes_in_group("trade_ships"): ship.advance(.1)
		for person in walkers: person.advance(.1)
	for person in walkers:
		check(person.visits >= person.stops.size(), "%s cumpre a rotina inteira em 4 minutos (%d paradas)" % [person.item_id, person.visits])
		check(_free(person.position), "%s termina em chão livre" % person.item_id)
	var porters := walkers.filter(func(person): return person.stops.any(func(stop): return stop["act"] == "ship"))
	check(porters.size() >= 4, "Há estivadores para os dois navios")

func _ships() -> void:
	for ship in get_nodes_in_group("trade_ships"):
		var seen: Array[String] = [ship.state]
		var in_water := true
		var berth: Vector2 = ship.arrive[ship.arrive.size() - 1]
		var docked_at_berth := true
		var heading_ok := true
		for step in range(2400):
			ship.advance(.5)
			if seen[seen.size() - 1] != ship.state: seen.append(ship.state)
			if ship.visible and catalog.has(Vector2i((PortLayout.unproject(ship.position) + Vector2(.5, .5)).floor())): in_water = false
			if ship.state == "docked" and ship.position.distance_to(berth) > 1.0: docked_at_berth = false
			if ship.state == "arriving" and ship.mirror != (berth.x < ship.arrive[0].x): heading_ok = false
		var order := " → ".join(seen)
		check(order.contains("away → arriving → docked"), "%s chega e atraca (%s)" % [ship.ship_id, order])
		check(order.contains("docked → astern → leaving") if not ship.astern.is_empty() else order.contains("docked → leaving"), "%s sai do cais pelo caminho certo" % ship.ship_id)
		check(order.contains("leaving → away → arriving"), "%s volta depois de partir" % ship.ship_id)
		check(in_water, "%s navega só na água" % ship.ship_id)
		check(docked_at_berth, "%s atraca na vaga" % ship.ship_id)
		check(heading_ok, "%s chega com a proa para a frente" % ship.ship_id)

func _buying(vendors: Array) -> void:
	var vendor = vendors[0]
	world.player.reset_at(vendor.position + Vector2(20, 14))
	await physics_frame
	var data: Dictionary = world.store.data
	Economy.add_coins(data, 30)
	var price: int = vendor.goods["price"]
	var heal: int = vendor.goods["heal"]
	world.player.health = world.player.max_health
	var coins := Economy.coins(data)
	check(not world.activate(vendor) and Economy.coins(data) == coins, "Com a vida cheia, a bancada não cobra")
	world.player.health = world.player.max_health - heal - 5
	check(world.activate(vendor), "Comprar %s na bancada" % vendor.goods["name"])
	check(Economy.coins(data) == coins - price, "A compra custa %d óbolos" % price)
	check(world.player.health == world.player.max_health - 5, "A comida cura %d de vida" % heal)
	Economy.spend_coins(data, Economy.coins(data))
	world.player.health = 10
	check(not world.activate(vendor) and world.player.health == 10, "Sem óbolos não há compra")
	world.hud.show_overlay("")

func _talking(walkers: Array) -> void:
	var person = walkers[0]
	world.player.reset_at(person.position + Vector2(18, 6))
	check(Life.activate(world, person) and world.hud.overlay == "dialog", "Falar com %s abre o diálogo" % person.item_id)
	check(person.talks == 1, "A próxima conversa traz outra fala")
	world.hud.show_overlay("")

func _making_way(walkers: Array) -> void:
	var person = walkers[0]
	var start: Vector2 = person.position
	world.player.position = start + Vector2(-12, 0)
	world.player.velocity = Vector2(90, 0)
	# Parado (rezando), o morador só sai do lugar se for para dar passagem.
	person._acting = true
	person._clock = 0.0
	for step in range(10): person.advance(.05)
	check(person.position.distance_to(start) > 4 and absf(person.position.y - start.y) > 3, "%s dá um passo para o lado quando Senu encosta" % person.item_id)
	world.player.velocity = Vector2.ZERO

## Senu parado no caminho de quem anda: o morador espera um instante e dá a volta
## por fora dele. Antes ficava parado a 16 px de Senu para sempre.
func _detour(walkers: Array) -> void:
	var person = walkers.filter(func(p): return p.item_id == "marinheiro_cais")[0]
	person._acting = false
	person._stop = 1
	person._waypoint = 0
	person._ghost = 0.0
	person.position = PortLayout.iso(Vector2(8.5, .5))
	var goal: Vector2 = person.stops[1]["path"][0]
	var heading: Vector2 = (goal - person.position).normalized()
	world.player.velocity = Vector2.ZERO
	world.player.position = person.position + heading * 14.0
	var hero_at: Vector2 = world.player.position
	var start_gap: float = person.position.distance_to(goal)
	var always_free := true
	for step in range(120):
		person.advance(.05)
		if not _free(person.position): always_free = false
	check(person.position.distance_to(goal) < start_gap - 30.0 or person._waypoint > 0 or person._acting, "%s contorna Senu parado no caminho (%.0f → %.0f px do destino)" % [person.item_id, start_gap, person.position.distance_to(goal)])
	check(always_free, "%s contorna Senu por chão livre" % person.item_id)
	check(world.player.position == hero_at, "Senu não é empurrado pelo desvio")
	person._body.collision_layer = 4
	person._ghost = 0.0

func _sleeping(walkers: Array) -> void:
	world.player.reset_at(PortLayout.iso(Vector2(85, 13)))
	var far: Array = walkers.filter(func(person): return person.position.distance_to(world.player.position) > 1400)
	var before: Array = far.map(func(person): return person.position)
	for frame in range(20):
		await physics_frame
	var still := true
	for index in range(far.size()):
		if far[index].position != before[index]: still = false
	check(not far.is_empty() and still, "Longe de Senu, a rotina pausa (%d moradores)" % far.size())
	check(far.all(func(person): return person._asleep), "Longe de Senu, o morador nem redesenha (adormecido)")

## Chão livre para um corpo de 6 px: sem cenário e sem borda de água.
func _free(point: Vector2) -> bool:
	if not catalog.has(Vector2i((PortLayout.unproject(point) + Vector2(.5, .5)).floor())): return false
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0, point)
	return space.intersect_shape(query, 1).is_empty()

func _body_at(point: Vector2, owner: Node) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 4
	for hit in space.intersect_point(query, 8):
		if hit["collider"].get_parent() == owner: return true
	return false
