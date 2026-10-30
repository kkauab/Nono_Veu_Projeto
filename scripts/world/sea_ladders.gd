extends RefCounted

## Escadas nos paredões em volta do mapa (docs/MUNDO_BARCO_ILHA.md): por onde
## Senu, caído na água, sobe de volta. Ficam só nas faces do paredão que dão para
## o mar aberto e em chão que se alcança sem atravessar portão, a partir do
## santuário ou do píer de cada ilha: nadar não pula puzzle, atalho nem chefe.
## O desenho de todas fica num nó só, junto do chão (sob os atores); cada escada
## tem um ponto de subida (PortInteractable "sea_ladder"), aceso só quando Senu
## nada perto dela.

const Layout = preload("res://scripts/world/port_layout.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")
const SHEET := "sea_beasts_v1"
## Distância mínima entre duas escadas, em tiles.
const SPACING := 7.0
## Até onde a busca do mar vai, em tiles (as casas, além de x = 140, ficam fora).
const SEA_BOUNDS := Rect2i(-48, -60, 170, 170)
## Faces visíveis do paredão: a borda +x desce para a esquerda; a +y, para a direita.
const FACES := {Vector2i(1, 0): "x", Vector2i(0, 1): "y"}
## Escada colada ao poste de amarração atrapalha: o píer já serve para subir no barco.
const POST_CLEARANCE := 1.4
const WOOD_DEPTH := 11.0
const STONE_DEPTH := 20.0


## Ponto de subida: em terra, no alto da escada. `water` é onde Senu precisa
## estar nadando; `dock`, o píer do mesmo pedaço de chão ("" se não houver).
class ClimbPoint extends PortInteractable:
	var water := Vector2.ZERO
	var dock := ""

	func _draw() -> void:
		if not active:
			return
		# Anéis na água ao pé da escada, mais fortes quando é a escolhida.
		var foot := water - global_position
		var alpha := .55 if highlighted else .25
		for ring in range(2):
			var grow := fposmod(time * .8 + ring * .5, 1.0)
			draw_set_transform(foot, 0, Vector2(1, .5))
			draw_arc(Vector2.ZERO, 5.0 + grow * 9.0, 0, TAU, 18, Color(.92, .86, .62, alpha * (1.0 - grow)), 1)
		draw_set_transform(Vector2.ZERO)


## Todas as escadas num desenho só, junto do chão.
class LadderArt extends Node2D:
	var spots: Array = []

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		for spot: Dictionary in spots:
			if not SeaArt.draw_frame(self, SHEET, spot["sprite"], 0, spot["foot"]):
				draw_line(spot["foot"], spot["foot"] + Vector2(0, -spot["depth"]), Color("674d34"), 2)


static func build(game, docks: Dictionary) -> void:
	var spots := compute(game, docks)
	var art := LadderArt.new()
	art.name = "SeaLadders"
	art.spots = spots
	# Depois dos pedaços de chão e, como eles, atrás dos desenhos do próprio layout.
	art.show_behind_parent = true
	game.layout.add_child(art)
	for spot: Dictionary in spots:
		var point := ClimbPoint.new()
		point.item_id = "ladder_%d_%d_%s" % [spot["tile"].x, spot["tile"].y, spot["face"]]
		point.kind = "sea_ladder"
		point.label = "Subir a escada"
		point.active = false
		point.position = spot["top"]
		point.water = spot["water"]
		point.dock = spot["dock"]
		point.add_to_group("sea_ladders")
		game.actors.add_child(point)


## As escadas: tile de cima, face, pé na água, alto em terra, ponto de nado e píer.
static func compute(game, docks: Dictionary) -> Array:
	var catalog := Layout.tile_catalog()
	var sea := _open_sea(catalog, docks)
	var owner := _open_ground(catalog, docks)
	var posts := []
	for id in docks:
		posts.append(docks[id]["land"])
	var obstacles: Array = game.get_tree().get_nodes_in_group("world_obstacles")
	var candidates := []
	for tile: Vector2i in owner:
		for face: Vector2i in FACES:
			if not sea.has(tile + face):
				continue
			var top := Vector2(tile) + Vector2(face) * .15
			if posts.any(func(post: Vector2) -> bool: return post.distance_to(top) < POST_CLEARANCE):
				continue
			var top_point := Layout.iso(top)
			if obstacles.any(func(node) -> bool: return is_instance_valid(node) and node.has_method("blocks_ground_point") and node.position.distance_to(top_point) < 160.0 and node.blocks_ground_point(top_point, 10.0)):
				continue
			candidates.append([tile, face])
	# Ordem fixa para a mesma partida ter as mesmas escadas.
	candidates.sort_custom(func(a, b) -> bool: return [a[0].y, a[0].x, a[1].x] < [b[0].y, b[0].x, b[1].x])
	var spots := []
	for candidate in candidates:
		var tile: Vector2i = candidate[0]
		var face: Vector2i = candidate[1]
		if spots.any(func(spot: Dictionary) -> bool: return Vector2(spot["tile"]).distance_to(Vector2(tile)) < SPACING):
			continue
		var wood: bool = str(catalog[tile].get("theme", "")) == "wood"
		var depth := WOOD_DEPTH if wood else STONE_DEPTH
		var edge := Layout.iso(Vector2(tile)) + (Vector2(16, 8) if face == Vector2i(1, 0) else Vector2(-16, 8))
		spots.append({
			"tile": tile, "face": FACES[face], "depth": depth,
			"sprite": "ladder_%s_%s" % [FACES[face], "wood" if wood else "stone"],
			"foot": edge + Vector2(0, depth),
			"top": Layout.iso(Vector2(tile) + Vector2(face) * .15),
			"water": Layout.iso(Vector2(tile) + Vector2(face) * .62),
			"dock": owner[tile],
		})
	return spots


## Água ligada ao mar dos píeres, tile a tile (sem diagonal: as bordas são as dos tiles).
static func _open_sea(catalog: Dictionary, docks: Dictionary) -> Dictionary:
	var sea := {}
	var queue: Array[Vector2i] = []
	for id in docks:
		var start := Vector2i((docks[id]["water"] as Vector2).round())
		if not catalog.has(start):
			sea[start] = true
			queue.append(start)
	while not queue.is_empty():
		var tile: Vector2i = queue.pop_back()
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = tile + step
			if sea.has(next) or catalog.has(next) or not SEA_BOUNDS.has_point(next):
				continue
			sea[next] = true
			queue.append(next)
	return sea


## Chão que se alcança a pé, com todos os portões fechados, a partir de cada píer
## e do santuário. Valor: o píer daquele pedaço de chão ("" se não tiver píer).
static func _open_ground(catalog: Dictionary, docks: Dictionary) -> Dictionary:
	var owner := {}
	var seeds := []
	for id in docks:
		seeds.append([Vector2i((docks[id]["land"] as Vector2).round()), id])
	seeds.append([Vector2i((Layout.MARKERS["hub_spawn"] as Vector2).round()), ""])
	for seed in seeds:
		var start: Vector2i = seed[0]
		if not catalog.has(start) or owner.has(start):
			continue
		owner[start] = seed[1]
		var queue: Array[Vector2i] = [start]
		while not queue.is_empty():
			var tile: Vector2i = queue.pop_back()
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var next: Vector2i = tile + step
				if owner.has(next) or not catalog.has(next) or crosses_gate(tile, next):
					continue
				owner[next] = seed[1]
				queue.append(next)
	return owner


## O passo de `a` para o vizinho `b` atravessa a linha de algum portão?
static func crosses_gate(a: Vector2i, b: Vector2i) -> bool:
	for gate: Dictionary in Layout.GATES.values():
		var from: Vector2 = gate["a"]
		var to: Vector2 = gate["b"]
		if is_equal_approx(from.y, to.y) and a.x == b.x:
			if is_equal_approx(minf(a.y, b.y) + .5, from.y) and a.x > minf(from.x, to.x) and a.x < maxf(from.x, to.x):
				return true
		elif is_equal_approx(from.x, to.x) and a.y == b.y:
			if is_equal_approx(minf(a.x, b.x) + .5, from.x) and a.y > minf(from.y, to.y) and a.y < maxf(from.y, to.y):
				return true
	return false
