extends RefCounted

## A vida do Porto (docs/MUNDO_VIDA.md). Chamado pelo port_demo:
## - `build`, ao montar o mundo: vendedores nas bancadas, navios mercantes e
##   moradores com as rotinas de port_life_catalog.gd;
## - `activate`, para falar com um morador ou comprar numa bancada.

const Catalog = preload("res://scripts/world/port_life_catalog.gd")
const Townsperson = preload("res://scripts/world/townsfolk.gd")
const TradeShip = preload("res://scripts/world/trade_ship.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
## Folga dos caminhos em volta do cenário: corpo de 5 px e mais um pouco.
const CLEARANCE := 9.0
## Onde o vendedor fica, a partir do ponto da barraca: ao lado da mesa, por fora
## do toldo. Sob o toldo o balcão e a lona o escondiam quase inteiro.
const BESIDE_STALL := Vector2(-30, -8)
## Onde o freguês para: de frente para o balcão.
const AT_COUNTER := Vector2(2, 14)


static func build(game) -> void:
	var nav := Paths.new(game.actors)
	var vendors := {}
	for definition in Catalog.VENDORS:
		var stall := _stall_near(game.actors, definition["stall"])
		if stall == null:
			push_warning("Bancada não encontrada para %s em %s" % [definition["id"], definition["stall"]])
			continue
		var vendor := _person(definition, "vendor")
		vendor.position = stall.position + BESIDE_STALL
		vendor.goods = {"name": definition["goods"], "price": definition["price"], "heal": definition["heal"]}
		vendor.label = "Comprar %s · %d óbolos · +%d de vida" % [definition["goods"], definition["price"], definition["heal"]]
		vendor.facing = 1.0
		game.actors.add_child(vendor)
		vendors[definition["id"]] = vendor
	var ships := {}
	for definition in Catalog.SHIPS:
		var ship := TradeShip.new()
		ship.ship_id = definition["id"]
		ship.title = definition["name"]
		ship.tint = Color(definition["tint"])
		ship.arrive = _pixels(definition["arrive"])
		ship.astern = _pixels(definition["astern"])
		ship.leave = _pixels(definition["leave"])
		ship.dock_time = definition["dock"]
		ship.away_time = definition["away"]
		ship.phase = definition["phase"]
		game.actors.add_child(ship)
		ships[definition["id"]] = ship
	for definition in Catalog.TOWNSFOLK:
		var person := _person(definition, "townsfolk")
		person.speed = definition["speed"]
		person.ships = ships
		person.label = "Falar · " + str(definition["title"])
		var route: Array = definition["route"]
		for index in range(route.size()):
			var stop: Array = route[index]
			var at: Vector2 = PortLayout.iso(stop[0])
			if stop[1] == "buy" and vendors.has(stop[3]):
				# O freguês para na frente do balcão de verdade, onde quer que a barraca esteja.
				at = vendors[stop[3]].position - BESIDE_STALL + AT_COUNTER
			person.stops.append({"at": at, "act": stop[1], "time": float(stop[2]) if stop.size() > 2 else 0.0, "extra": stop[3] if stop.size() > 3 else null, "vendor": vendors.get(stop[3]) if stop[1] == "buy" else null})
		for index in range(person.stops.size()):
			var from: Vector2 = person.stops[index - 1]["at"]
			person.stops[index]["path"] = nav.route(from, person.stops[index]["at"])
		game.actors.add_child(person)


static func activate(game, item) -> bool:
	if item.kind == "vendor":
		return _buy(game, item)
	if item.item_id == "mendigo_alaude":
		return _talk_beggar(game, item)
	var line: String = item.lines[item.talks % item.lines.size()] if not item.lines.is_empty() else "..."
	item.talks += 1
	# Vira para Senu enquanto fala.
	item.facing = signf(game.player.position.x - item.position.x) if absf(game.player.position.x - item.position.x) > 1 else item.facing
	item.gesture(2.0)
	game.hud.show_conversation(item.title, line, item.item_id)
	return true


static func _talk_beggar(game, item) -> bool:
	var line: String = item.lines[item.talks % item.lines.size()] if not item.lines.is_empty() else "..."
	item.talks += 1
	item.facing = signf(game.player.position.x - item.position.x) if absf(game.player.position.x - item.position.x) > 1 else item.facing
	item.gesture(2.4)
	Sfx.play(game, "beggar_blessing", item.position, 1.5)

	if item.talks == 1 and Economy.coins(game.store.data) > 0:
		Economy.spend_coins(game.store.data, 1)
		game.hud.toast("Oferta de 1 óbolo ao velho marinheiro do alaúde!", Color("f3d489"), 3.2)
		game._save_soon()

	game.hud.show_conversation(item.title, line, item.item_id)
	return true


static func _buy(game, vendor) -> bool:
	var goods: Dictionary = vendor.goods
	var line: String = vendor.lines[vendor.talks % vendor.lines.size()]
	if game.player.health >= game.player.max_health:
		game.hud.toast("A vida já está cheia. %s" % line, Color("d8c9a8"), 3.0)
		vendor.talks += 1
		return false
	if not Economy.spend_coins(game.store.data, int(goods["price"])):
		game.hud.toast("Faltam óbolos: %s custa %d." % [goods["name"], goods["price"]], Color("d9ad8a"), 2.6)
		return false
	var healed := mini(game.player.max_health - game.player.health, int(goods["heal"]))
	game.player.health += healed
	vendor.talks += 1
	vendor.gesture()
	Sfx.play(game, "pickup_coin", vendor.position)
	game.hud.toast("%s · +%d de vida · −%d óbolos\n%s" % [String(goods["name"]).capitalize(), healed, goods["price"], line], Color("9bc9ae"), 3.4)
	game._save_soon()
	return true


static func _person(definition: Dictionary, kind: String) -> Node2D:
	var person := Townsperson.new()
	person.item_id = definition["id"]
	person.kind = kind
	person.look = Catalog.LOOKS.find(definition["look"])
	person.title = definition["title"]
	person.lines = definition["lines"]
	return person


static func _stall_near(actors: Node, tile: Vector2) -> Node2D:
	var best: Node2D = null
	var distance := 2.0
	for node in actors.get_children():
		if node is PortProp and node.kind == "stall":
			var gap := PortLayout.unproject(node.position).distance_to(tile)
			if gap < distance:
				distance = gap
				best = node
	return best


static func _pixels(tiles: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for tile in tiles: result.append(PortLayout.iso(tile))
	return result


## Caminhos a pé em volta do cenário: A* nos centros dos tiles livres, depois
## encurtado onde a linha reta também está livre.
class Paths:
	var graph := AStar2D.new()
	var ids: Dictionary = {}
	var catalog: Dictionary
	## Obstáculos por região de 4 × 4 tiles, cada um em todas as regiões que alcança.
	var buckets: Dictionary = {}

	func _init(actors: Node) -> void:
		catalog = PortLayout.tile_catalog()
		for node in actors.get_tree().get_nodes_in_group("world_obstacles"):
			if not node.has_method("blocks_ground_point"): continue
			var origin := Vector2i(PortLayout.unproject(node.position).round())
			for y in range(floori((origin.y - 3) / 4.0), floori((origin.y + 3) / 4.0) + 1):
				for x in range(floori((origin.x - 3) / 4.0), floori((origin.x + 3) / 4.0) + 1):
					if not buckets.has(Vector2i(x, y)): buckets[Vector2i(x, y)] = []
					buckets[Vector2i(x, y)].append(node)
		for tile: Vector2i in catalog:
			if clear(PortLayout.iso(Vector2(tile))):
				ids[tile] = ids.size()
				graph.add_point(ids[tile], PortLayout.iso(Vector2(tile)))
		for tile: Vector2i in ids:
			for step in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(1, -1)]:
				var next: Vector2i = tile + step
				if not ids.has(next): continue
				var a := PortLayout.iso(Vector2(tile))
				var b := PortLayout.iso(Vector2(next))
				if clear(a.lerp(b, .25)) and clear(a.lerp(b, .5)) and clear(a.lerp(b, .75)):
					graph.connect_points(ids[tile], ids[next])

	## Livre de cenário e dentro do chão, com folga para o corpo.
	func clear(point: Vector2) -> bool:
		var tile := PortLayout.unproject(point)
		# 0,3 tile dá uns 8,5 px até a borda do chão, mais que o corpo.
		for corner in [Vector2(.3, 0), Vector2(-.3, 0), Vector2(0, .3), Vector2(0, -.3)]:
			if not catalog.has(Vector2i((tile + corner + Vector2(.5, .5)).floor())): return false
		for node in buckets.get(Vector2i(floori(tile.x / 4.0), floori(tile.y / 4.0)), []):
			if is_instance_valid(node) and node.blocks_ground_point(point, CLEARANCE): return false
		return true

	func segment_clear(a: Vector2, b: Vector2) -> bool:
		var samples := maxi(2, ceili(a.distance_to(b) / 6.0))
		for index in range(samples + 1):
			if not clear(a.lerp(b, float(index) / samples)): return false
		return true

	func route(from: Vector2, to: Vector2) -> PackedVector2Array:
		if segment_clear(from, to):
			return PackedVector2Array([to])
		var points := graph.get_point_path(graph.get_closest_point(from), graph.get_closest_point(to))
		var path := PackedVector2Array([from])
		path.append_array(points)
		path.append(to)
		# Encurta: de cada ponto, pula para o mais distante visível em linha reta.
		var short := PackedVector2Array()
		var index := 0
		while index < path.size() - 1:
			var far := path.size() - 1
			while far > index + 1 and not segment_clear(path[index], path[far]):
				far -= 1
			short.append(path[far])
			index = far
		return short
