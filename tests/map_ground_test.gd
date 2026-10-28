extends SceneTree
## Every piece of scenery stands on stone, is as solid as it looks and leaves the
## ways between rooms open. Walks the whole port with Senu's 6 px body, every
## gate open, so locked progression is not mistaken for a blocked passage.

const Dressing = preload("res://scripts/world/port_dressing.gd")
## Pieces that must stop Senu. Reeds and boats are the only passable scenery.
const SOLID_KINDS := ["pillar", "statue", "wall", "torch", "rubble", "stairs", "crate", "barrel", "bollard", "palm", "warehouse", "stall", "temple", "lighthouse", "arch"]
## Lattice of a quarter tile: neighbours are under 9 px apart, so a 6 px body
## never slips between two samples across a wall or a floor edge.
const STEP := .25
var world: Node
var catalog: Dictionary
var space: PhysicsDirectSpaceState2D
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
		push_error("map_ground_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for node in world.actors.get_children():
		if node is PortGate: node.collision_layer = 0
	await physics_frame
	catalog = PortLayout.tile_catalog()
	space = world.actors.get_world_2d().direct_space_state
	var props: Array = world.actors.get_children().filter(func(node): return node is PortProp)
	var stands: Array = world.actors.get_children().filter(func(node): return node is PortInteractable and not node.footprint().is_empty())
	_ground(props, stands)
	_doorways(props)
	await _passages(props + stands)
	print("MAP GROUND CHECKS: %d passed=%d failures=%s props=%d stands=%d" % [checks, checks - failures.size(), failures, props.size(), stands.size()])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _footprints(node: Node2D) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var local: Array = node.foundation_polygons() if node is PortProp else [node.footprint()]
	for polygon: PackedVector2Array in local:
		var moved := PackedVector2Array()
		for point in polygon: moved.append(point + node.position)
		result.append(moved)
	return result

func _ground(props: Array, stands: Array) -> void:
	var standing: Array = []
	for node: Node2D in props + stands:
		var at := PortLayout.unproject(node.position)
		var name := "%s em (%.2f, %.2f)" % [node.kind, at.x, at.y]
		var bodies := node.get_children().filter(func(child): return child is StaticBody2D)
		if node is PortProp:
			check(bodies.is_empty() == (node.kind not in SOLID_KINDS), "%s: sólido só se não for junco ou barco" % name)
		else:
			check(bodies.size() == 1, "%s: a base do objeto interativo tem colisão" % name)
		var ground := _footprints(node)
		if ground.is_empty() or bodies.is_empty(): continue
		standing.append([node, ground, name])
		var floating := 0
		for polygon in ground:
			for probe in _probes(polygon):
				if not catalog.has(Vector2i((PortLayout.unproject(probe) + Vector2(.5, .5)).floor())): floating += 1
		check(floating == 0, "%s: a base inteira está sobre a pedra (%d pontos fora)" % [name, floating])
		var centre := Vector2.ZERO
		for point in ground[0]: centre += point / ground[0].size()
		check(_blocked_by(node, centre), "%s: a colisão cobre o meio da base pintada" % name)
		if node.kind not in ["bollard", "rubble", "iri_relic", "iri_mark", "npc"]:
			# The pivot is the front corner of a painted base: nothing invisible in front.
			check(not _blocked_by(node, node.position + Vector2(0, 3)), "%s: nenhuma parede invisível na frente da base" % name)
	for first in range(standing.size()):
		for second in range(first + 1, standing.size()):
			if standing[first][0].position.distance_to(standing[second][0].position) > 240: continue
			var overlap := false
			for a: PackedVector2Array in standing[first][1]:
				for b: PackedVector2Array in standing[second][1]:
					if not Geometry2D.intersect_polygons(a, b).is_empty(): overlap = true
			if overlap:
				check(false, "%s e %s não se sobrepõem" % [standing[first][2], standing[second][2]])

func _doorways(props: Array) -> void:
	# Hand-placed pieces come first; the generated districts keep every doorway clear.
	var site: Dictionary = Dressing._site()
	var generated := 0
	for index in range(Dressing.PROPS.size(), props.size()):
		var node: PortProp = props[index]
		generated += 1
		var inside := false
		for polygon in _footprints(node):
			for probe in _probes(polygon):
				for doorway: Rect2 in site["doorways"]:
					if doorway.has_point(PortLayout.unproject(probe)): inside = true
		var at := PortLayout.unproject(node.position)
		check(not inside, "%s gerado em (%.2f, %.2f) fica fora da boca das passagens" % [node.kind, at.x, at.y])
	check(generated > 100, "Os bairros gerados ainda têm cenário (%d peças)" % generated)

func _passages(pieces: Array) -> void:
	var walkable := _sample()
	var start := Vector2i(PortLayout.MARKERS["hub_spawn"] / STEP)
	check(walkable.get(start, false), "Senu começa num ponto livre")
	var reached := _flood(walkable, start)
	# The same walk with no scenery at all: what is out of reach then (house
	# interiors, land reached only by sea) is not the scenery's fault.
	var bodies: Array = []
	for node in pieces:
		for child in node.get_children():
			if child is StaticBody2D and child.collision_layer != 0:
				bodies.append(child)
				child.collision_layer = 0
	await physics_frame
	var open_floor := _flood(_sample(), start)
	for body in bodies: body.collision_layer = 1
	await physics_frame
	var cut_off: Dictionary = {}
	for key in walkable:
		if walkable[key] and open_floor.has(key) and not reached.has(key):
			var room := PortLayout.room_at(PortLayout.iso(Vector2(key) * STEP))
			cut_off[room] = cut_off.get(room, 0) + 1
	for room in cut_off:
		# A sliver between two pieces is harmless; a walkable patch nobody reaches is not.
		check(cut_off[room] <= 4, "%s: nenhum trecho de chão livre fica isolado (%d pontos)" % [room, cut_off[room]])
	for room in PortLayout.ROOMS:
		var rect: Rect2i = room["rect"]
		var area := Rect2(Vector2(rect.position) - Vector2(.5, .5), Vector2(rect.size))
		if not open_floor.keys().any(func(key): return area.has_point(Vector2(key) * STEP)): continue
		check(reached.keys().any(func(key): return area.has_point(Vector2(key) * STEP)), "%s: Senu alcança a sala" % room["id"])
	for connector in PortLayout.CONNECTORS:
		var rect: Rect2i = connector["rect"]
		var area := Rect2(Vector2(rect.position) - Vector2(.5, .5), Vector2(rect.size))
		var floor_samples := 0
		var open := 0
		for key in walkable:
			if area.has_point(Vector2(key) * STEP):
				floor_samples += 1
				if reached.has(key): open += 1
		# Gateway arches take part of a doorway; more than that is a blocked passage.
		check(open >= floor_samples * .45, "Passagem %s em %s: %d de %d pontos livres" % [connector["room"], rect, open, floor_samples])
	for waypoint: Vector2 in PortLayout.MAIN_ROUTE_WAYPOINTS:
		check(_reaches(reached, PortLayout.iso(waypoint), 14), "Rota principal passa por %s" % waypoint)
	for item in world.actors.get_children():
		# Quem anda pelo Porto não tem "frente" fixa; os vendedores, sim.
		if item is PortInteractable and item.active and item.kind != "townsfolk" and _reaches(open_floor, item.position, 40):
			# Bases lie behind the pivot: the spot just in front is where the player stops.
			check(_reaches(reached, item.position + Vector2(0, 13), 9), "Dá para parar na frente de %s %s" % [item.kind, item.item_id])

func _probes(polygon: PackedVector2Array) -> Array[Vector2]:
	# Corners and edge midpoints, a pixel and a half inside, and the centre.
	var centre := Vector2.ZERO
	for point in polygon: centre += point / polygon.size()
	var probes: Array[Vector2] = [centre]
	for index in range(polygon.size()):
		var corner := polygon[index].move_toward(centre, 1.5)
		probes.append(corner)
		probes.append(corner.lerp(polygon[(index + 1) % polygon.size()].move_toward(centre, 1.5), .5))
	return probes

func _blocked_by(node: Node, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	for hit in space.intersect_point(query, 32):
		if hit["collider"].get_parent() == node: return true
	return false

func _sample() -> Dictionary:
	var body := CircleShape2D.new()
	body.radius = 6.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body
	query.collision_mask = 1
	var result: Dictionary = {}
	for tile: Vector2i in catalog:
		# Offsets -.5 .. .25 of every tile: each lattice point belongs to one tile.
		for i in range(-2, 2):
			for j in range(-2, 2):
				var key := tile * 4 + Vector2i(i, j)
				query.transform = Transform2D(0, PortLayout.iso(Vector2(key) * STEP))
				result[key] = space.intersect_shape(query, 1).is_empty()
	return result

func _flood(walkable: Dictionary, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var key := queue[head]
		head += 1
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = key + step
			if walkable.get(next, false) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func _reaches(reached: Dictionary, point: Vector2, distance: float) -> bool:
	var around := Vector2i((PortLayout.unproject(point) / STEP).round())
	var span := ceili(distance / 16.0 / STEP) + 1
	for x in range(-span, span + 1):
		for y in range(-span, span + 1):
			var key := around + Vector2i(x, y)
			if reached.has(key) and PortLayout.iso(Vector2(key) * STEP).distance_to(point) < distance: return true
	return false
