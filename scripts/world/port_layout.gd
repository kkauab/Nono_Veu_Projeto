extends Node2D
class_name PortLayout
const Art = preload("res://scripts/world/port_art.gd")

const HALF_TILE := Vector2(32, 16)
const ROOMS := [
	{"id": "hub", "label": "Primeira Palavra", "name": "Santuário da Primeira Palavra", "rect": Rect2i(-5, -5, 9, 8), "color": Color("58645b"), "theme": "mosaic"},
	{"id": "p1", "label": "Cais dos Esquecidos", "name": "Cais dos Esquecidos", "rect": Rect2i(5, -2, 12, 5), "color": Color("77664c"), "theme": "wood"},
	{"id": "market", "label": "Mercado das Cinzas", "name": "Mercado das Cinzas", "rect": Rect2i(17, -5, 10, 10), "color": Color("6b6554"), "theme": "sand"},
	{"id": "p2", "label": "Armazém das Vozes", "name": "Armazém das Vozes", "rect": Rect2i(28, -2, 11, 11), "color": Color("565e59"), "theme": "stone"},
	{"id": "bridge", "label": "Ponte dos Barqueiros", "name": "Ponte dos Barqueiros", "rect": Rect2i(31, 9, 4, 10), "color": Color("6b5c45"), "theme": "wood"},
	{"id": "p3", "label": "Pátio das Memórias", "name": "Pátio das Memórias", "rect": Rect2i(24, 19, 15, 11), "color": Color("5e6557"), "theme": "mosaic"},
	{"id": "secret", "label": "Alcova do Escriba", "name": "Alcova do Escriba", "rect": Rect2i(39, 22, 7, 8), "color": Color("555563"), "theme": "crypt"},
	{"id": "lower_dock", "label": "Embarcadouro Velho", "name": "Embarcadouro Velho", "rect": Rect2i(24, 31, 13, 5), "color": Color("6f634a"), "theme": "wood"},
	{"id": "garden", "label": "Jardim Inundado", "name": "Jardim Inundado", "rect": Rect2i(12, 20, 11, 10), "color": Color("58634f"), "theme": "garden"},
	{"id": "p4", "label": "Guarita do Retorno", "name": "Guarita do Retorno", "rect": Rect2i(2, 17, 10, 12), "color": Color("646453"), "theme": "stone"},
	{"id": "b1", "label": "Porteiro Sem Nome", "name": "O Limiar Sem Nome", "rect": Rect2i(-12, 16, 13, 15), "color": Color("62544f"), "theme": "arena"},
	{"id": "a02", "label": "Catacumbas do Eco", "name": "Catacumbas do Eco · limiar", "rect": Rect2i(-25, 20, 10, 11), "color": Color("444854"), "theme": "crypt"},
	{"id": "aqueduct", "label": "Aqueduto Silencioso", "name": "Aqueduto Silencioso", "rect": Rect2i(20, 5, 2, 15), "color": Color("56635c"), "theme": "aqueduct"},
	{"id": "pilgrim", "label": "Peregrinos", "name": "Escadaria dos Peregrinos", "rect": Rect2i(16, -20, 18, 13), "color": Color("766c58"), "theme": "sand"},
	{"id": "bellcourt", "label": "Três Sinos", "name": "Praça dos Três Sinos", "rect": Rect2i(16, -36, 18, 15), "color": Color("707367"), "theme": "mosaic"},
	{"id": "archive", "label": "Arquivo Velado", "name": "Arquivo dos Nomes Velados", "rect": Rect2i(-4, -36, 19, 15), "color": Color("5a625d"), "theme": "crypt"},
	{"id": "scriptorium", "label": "Escribas", "name": "Pátio dos Escribas", "rect": Rect2i(-4, -20, 19, 13), "color": Color("747363"), "theme": "mosaic"},
	{"id": "caravan", "label": "Caravanas", "name": "Portão das Caravanas", "rect": Rect2i(40, -4, 16, 14), "color": Color("7a6c53"), "theme": "sand"},
	{"id": "kilns", "label": "Fornos de Bronze", "name": "Fornos do Bronze Esquecido", "rect": Rect2i(57, -4, 16, 14), "color": Color("77614c"), "theme": "stone"},
	{"id": "salt_road", "label": "Estrada do Sal", "name": "Estrada das Cargas de Sal", "rect": Rect2i(57, 11, 16, 15), "color": Color("8b8168"), "theme": "sand"},
	{"id": "beacon", "label": "Farol Partido", "name": "Terraço do Farol Partido", "rect": Rect2i(74, 11, 14, 15), "color": Color("747366"), "theme": "stone"},
	{"id": "oracle", "label": "Observatório", "name": "Observatório das Estrelas Mortas", "rect": Rect2i(74, 27, 14, 15), "color": Color("565b69"), "theme": "crypt"},
	{"id": "reservoir", "label": "Reservatório", "name": "Reservatório das Duas Margens", "rect": Rect2i(57, 27, 16, 15), "color": Color("586a62"), "theme": "aqueduct"},
	{"id": "copper_dock", "label": "Cais do Cobre", "name": "Cais do Cobre e das Ânforas", "rect": Rect2i(40, 31, 16, 12), "color": Color("75644e"), "theme": "wood"},
	{"id": "cistern", "label": "Cisterna", "name": "Cisterna das Duas Fontes", "rect": Rect2i(12, 31, 11, 14), "color": Color("5f7266"), "theme": "aqueduct"},
	{"id": "sluice", "label": "Comportas", "name": "Galeria das Comportas", "rect": Rect2i(0, 31, 11, 14), "color": Color("637266"), "theme": "stone"},
	{"id": "buried", "label": "Santuário Soterrado", "name": "Santuário Soterrado da Maré", "rect": Rect2i(-12, 32, 11, 13), "color": Color("53615d"), "theme": "crypt"}
]
const ROOM_LINKS := [
	["hub", "p1"], ["p1", "market"], ["market", "p2"], ["p2", "bridge"],
	["bridge", "p3"], ["p3", "garden"], ["garden", "p4"], ["p4", "b1"], ["b1", "a02"],
	["p3", "secret"], ["p3", "lower_dock"], ["market", "aqueduct"],
	["aqueduct", "garden", "aqueduct"], ["p4", "hub", "shortcut"],
	["market", "pilgrim"], ["pilgrim", "bellcourt"], ["bellcourt", "archive"],
	["archive", "scriptorium"], ["scriptorium", "hub"], ["scriptorium", "pilgrim"],
	["p2", "caravan"], ["caravan", "kilns"], ["kilns", "salt_road"],
	["salt_road", "beacon"], ["beacon", "oracle"], ["oracle", "reservoir"],
	["reservoir", "copper_dock"], ["copper_dock", "lower_dock"],
	["garden", "cistern"], ["cistern", "sluice"], ["sluice", "buried"]
]
const CONNECTORS := [
	{"rect": Rect2i(4, 0, 1, 2), "room": "p1", "theme": "stone", "color": Color("626456")},
	{"rect": Rect2i(27, 0, 1, 3), "room": "p2", "theme": "stone", "color": Color("5b6157")},
	{"rect": Rect2i(23, 23, 1, 3), "room": "garden", "theme": "garden", "color": Color("5b6655")},
	{"rect": Rect2i(29, 30, 3, 1), "room": "lower_dock", "theme": "wood", "color": Color("756449")},
	{"rect": Rect2i(1, 21, 1, 4), "room": "p4", "theme": "stone", "color": Color("676552")},
	{"rect": Rect2i(-15, 24, 3, 3), "room": "a02", "theme": "crypt", "color": Color("4e4d59")},
	{"rect": Rect2i(0, 3, 3, 14), "room": "hub", "theme": "aqueduct", "color": Color("566359")},
	{"rect": Rect2i(25, 36, 2, 3), "room": "lower_dock", "theme": "wood", "color": Color("6c6047")},
	{"rect": Rect2i(33, 36, 2, 3), "room": "lower_dock", "theme": "wood", "color": Color("71634a")},
	{"rect": Rect2i(20, -7, 3, 2), "room": "pilgrim", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(24, -21, 3, 1), "room": "bellcourt", "theme": "mosaic", "color": Color("777463")},
	{"rect": Rect2i(15, -30, 1, 4), "room": "archive", "theme": "crypt", "color": Color("646d65")},
	{"rect": Rect2i(4, -21, 3, 1), "room": "scriptorium", "theme": "mosaic", "color": Color("777463")},
	{"rect": Rect2i(15, -14, 1, 3), "room": "pilgrim", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(0, -7, 3, 2), "room": "hub", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(39, 1, 1, 4), "room": "caravan", "theme": "sand", "color": Color("84775c")},
	{"rect": Rect2i(56, 2, 1, 4), "room": "kilns", "theme": "stone", "color": Color("766751")},
	{"rect": Rect2i(63, 10, 3, 1), "room": "salt_road", "theme": "sand", "color": Color("84775c")},
	{"rect": Rect2i(73, 18, 1, 4), "room": "beacon", "theme": "stone", "color": Color("766751")},
	{"rect": Rect2i(79, 26, 3, 1), "room": "oracle", "theme": "crypt", "color": Color("626575")},
	{"rect": Rect2i(73, 34, 1, 4), "room": "reservoir", "theme": "aqueduct", "color": Color("61736b")},
	{"rect": Rect2i(56, 34, 1, 4), "room": "copper_dock", "theme": "wood", "color": Color("77634c")},
	{"rect": Rect2i(37, 33, 3, 3), "room": "copper_dock", "theme": "wood", "color": Color("77634c")},
	{"rect": Rect2i(16, 30, 3, 1), "room": "cistern", "theme": "aqueduct", "color": Color("61736b")},
	{"rect": Rect2i(11, 37, 1, 3), "room": "sluice", "theme": "stone", "color": Color("61736b")},
	{"rect": Rect2i(-1, 37, 1, 3), "room": "buried", "theme": "crypt", "color": Color("61736b")}
]
## Broad, level thresholds support both feet of the entrance arches.
## They are away from the locked shortcut/boss corridors, preserving their seals.
const LANDINGS := [
	{"rect": Rect2i(3, -1, 3, 4), "room": "p1", "theme": "stone", "color": Color("626456")},
	{"rect": Rect2i(26, -1, 3, 5), "room": "p2", "theme": "stone", "color": Color("5b6157")}
]
const WATER_HOLES := [Rect2i(32, 3, 2, 2), Rect2i(30, 23, 3, 3), Rect2i(15, 22, 3, 3), Rect2i(20, 26, 2, 3), Rect2i(-1, 16, 2, 3), Rect2i(0, 31, 1, 1), Rect2i(15, 35, 4, 4), Rect2i(62, 33, 5, 4)]
const MARKERS := {
	"hub_spawn": Vector2(-1, -1), "hub": Vector2(-3, -3), "hub_shrine": Vector2(-3, -3),
	"s1": Vector2(7, 20), "market_rest": Vector2(24, -3), "inscricao": Vector2(-3, 0),
	"adagas": Vector2(42, 26), "alavanca": Vector2(5, 20), "alavanca_aqueduct": Vector2(18, 24),
	"selo": Vector2(-12, 25), "nous_cais": Vector2(14, -1), "nous_patio": Vector2(36, 27),
	"nous_arena": Vector2(-9, 28), "nous_market": Vector2(25, 3), "nous_garden": Vector2(13, 28),
	"nous_dock": Vector2(35, 34), "nous_aqueduct": Vector2(20, 12), "cache": Vector2(44, 28),
	"memory_market": Vector2(19, -3), "memory_dock": Vector2(26, 37),
	"capture_market": Vector2(23, 0), "capture_cais": Vector2(11, 0), "capture_arena": Vector2(-4, 25),
	"caravan_rest": Vector2(52, -1), "cistern_rest": Vector2(20, 33),
	"bells_clue": Vector2(5, -28), "bell_moon": Vector2(22, -30), "bell_sun": Vector2(27, -30), "bell_star": Vector2(25, -26),
	"water_clue": Vector2(18, 41), "valve_two": Vector2(3, 35), "valve_three": Vector2(7, 35), "valve_drain": Vector2(5, 41), "valve_reset": Vector2(9, 38), "water_altar": Vector2(-6, 38),
	"stars_clue": Vector2(80, 16), "star_sun": Vector2(78, 34), "star_moon": Vector2(83, 34), "star_eye": Vector2(80, 39), "stars_altar": Vector2(85, 39),
	"sealed_entry": Vector2(3, 23), "nous_archive": Vector2(-1, -33), "nous_kilns": Vector2(69, 7),
	"nous_beacon": Vector2(85, 13), "nous_reservoir": Vector2(60, 39), "nous_buried": Vector2(-10, 42),
	"memory_pilgrim": Vector2(30, -17), "memory_copper": Vector2(48, 40),
	"capture_bells": Vector2(25, -28), "capture_oracle": Vector2(80, 35), "capture_cistern": Vector2(20, 39), "capture_caravan": Vector2(47, 3)
}
const GATES := {
	"shortcut": {"a": Vector2(-.5, 3.5), "b": Vector2(2.5, 3.5)},
	"aqueduct": {"a": Vector2(19.5, 19.5), "b": Vector2(21.5, 19.5)},
	"boss": {"a": Vector2(-12.5, 23.5), "b": Vector2(-12.5, 26.5)},
	"boss_entry": {"a": Vector2(.5, 20.5), "b": Vector2(.5, 24.5)}
}
const ENEMY_SPAWNS := [
	{"id": "marinheiro_01", "tile": Vector2(11, 1), "boss": false},
	{"id": "vigia_mercado", "tile": Vector2(22, 2), "boss": false},
	{"id": "carregador_armazem", "tile": Vector2(36, 5), "boss": false},
	{"id": "barqueiro_ponte", "tile": Vector2(33, 15), "boss": false},
	{"id": "marinheiro_02", "tile": Vector2(36, 26), "boss": false},
	{"id": "copista_alcova", "tile": Vector2(42, 24), "boss": false},
	{"id": "errante_jardim", "tile": Vector2(19, 28), "boss": false},
	{"id": "vigia_guarita", "tile": Vector2(9, 25), "boss": false},
	{"id": "porteiro", "tile": Vector2(-6, 23), "boss": true},
	{"id": "errante_escriba_01", "tile": Vector2(5, -11), "archetype": "runner"},
	{"id": "errante_escriba_02", "tile": Vector2(11, -17), "archetype": "guard"},
	{"id": "guardiao_arquivo_01", "tile": Vector2(4, -29), "archetype": "keeper"},
	{"id": "guardiao_arquivo_02", "tile": Vector2(11, -24), "archetype": "guard"},
	{"id": "sentinela_sinos_01", "tile": Vector2(20, -33), "archetype": "lancer"},
	{"id": "sentinela_sinos_02", "tile": Vector2(31, -25), "archetype": "guard"},
	{"id": "peregrino_vazio_01", "tile": Vector2(21, -16), "archetype": "runner"},
	{"id": "peregrino_vazio_02", "tile": Vector2(30, -10), "archetype": "guard"},
	{"id": "caravaneiro_01", "tile": Vector2(45, 3), "archetype": "lancer"},
	{"id": "caravaneiro_02", "tile": Vector2(51, 7), "archetype": "guard"},
	{"id": "fundidor_01", "tile": Vector2(61, 1), "archetype": "keeper"},
	{"id": "fundidor_02", "tile": Vector2(68, 6), "archetype": "guard"},
	{"id": "corredor_sal_01", "tile": Vector2(62, 15), "archetype": "runner"},
	{"id": "corredor_sal_02", "tile": Vector2(69, 22), "archetype": "lancer"},
	{"id": "vigia_farol_01", "tile": Vector2(78, 14), "archetype": "lancer"},
	{"id": "vigia_farol_02", "tile": Vector2(84, 22), "archetype": "guard"},
	{"id": "oraculo_vazio_01", "tile": Vector2(77, 29), "archetype": "keeper"},
	{"id": "oraculo_vazio_02", "tile": Vector2(85, 37), "archetype": "runner"},
	{"id": "aguadeiro_01", "tile": Vector2(62, 31), "archetype": "guard"},
	{"id": "aguadeiro_02", "tile": Vector2(69, 39), "archetype": "lancer"},
	{"id": "cobreiro_01", "tile": Vector2(45, 35), "archetype": "guard"},
	{"id": "cobreiro_02", "tile": Vector2(52, 40), "archetype": "runner"},
	{"id": "cisterna_01", "tile": Vector2(14, 35), "archetype": "runner"},
	{"id": "cisterna_02", "tile": Vector2(20, 42), "archetype": "guard"},
	{"id": "comporta_01", "tile": Vector2(3, 39), "archetype": "keeper"},
	{"id": "comporta_02", "tile": Vector2(8, 42), "archetype": "lancer"},
	{"id": "soterrado_01", "tile": Vector2(-8, 34), "archetype": "keeper"},
	{"id": "soterrado_02", "tile": Vector2(-3, 42), "archetype": "guard"},
	{"id": "cais_patrol", "tile": Vector2(30, 33), "archetype": "guard"}
]
const MAIN_ROUTE_WAYPOINTS := [
	Vector2(-1, -1), Vector2(3, 0), Vector2(6, 0), Vector2(11, 0), Vector2(16, 0),
	Vector2(20, 0), Vector2(25, 1), Vector2(28, 1), Vector2(35, 1), Vector2(35, 6),
	Vector2(32, 7), Vector2(32, 11), Vector2(32, 16), Vector2(32, 20), Vector2(35, 20),
	Vector2(35, 27), Vector2(28, 27), Vector2(25, 24), Vector2(23, 24), Vector2(19, 24),
	Vector2(19, 26), Vector2(18, 27), Vector2(14, 27), Vector2(12, 26), Vector2(10, 26),
	Vector2(7, 24), Vector2(7, 20), Vector2(5, 20), Vector2(4, 22), Vector2(1, 22),
	Vector2(-3, 22), Vector2(-5, 26), Vector2(-10, 26), Vector2(-12, 25),
	Vector2(-14, 25), Vector2(-18, 25), Vector2(-21, 25)
]

var tiles: Dictionary = {}
var tile_themes: Dictionary = {}

static func iso(tile: Vector2) -> Vector2:
	return Vector2((tile.x - tile.y) * HALF_TILE.x, (tile.x + tile.y) * HALF_TILE.y)

static func unproject(point: Vector2) -> Vector2:
	return Vector2(point.x / 64.0 + point.y / 32.0, point.y / 32.0 - point.x / 64.0)

static func spawn_points() -> Dictionary:
	return MARKERS.duplicate()

static func room_at(point: Vector2) -> String:
	var tile := Vector2i(unproject(point).round())
	for room in ROOMS:
		if room["rect"].has_point(tile):
			return room["id"]
	for connector in CONNECTORS + LANDINGS:
		if connector["rect"].has_point(tile):
			return connector["room"]
	return "p1"

static func tile_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for region in ROOMS + CONNECTORS + LANDINGS:
		var rect: Rect2i = region["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				catalog[Vector2i(x, y)] = {"color": region["color"], "theme": region["theme"]}
	for hole in WATER_HOLES:
		for x in range(hole.position.x, hole.end.x):
			for y in range(hole.position.y, hole.end.y):
				catalog.erase(Vector2i(x, y))
	return catalog

func _ready() -> void:
	z_index = -20
	var sea := HarborWater.new()
	sea.z_index = -1
	add_child(sea)
	var catalog := tile_catalog()
	for tile in catalog:
		tiles[tile] = catalog[tile]["color"]
		tile_themes[tile] = catalog[tile]["theme"]
	_build_boundaries()
	_build_floor_chunks()
	queue_redraw()

func _build_floor_chunks() -> void:
	# Each CanvasItem has a small real drawing bound: distant districts are culled.
	var groups: Dictionary = {}
	for tile: Vector2i in tiles:
		var key := Vector2i(floori(tile.x / 12.0), floori(tile.y / 12.0))
		if not groups.has(key): groups[key] = []
		groups[key].append(tile)
	for key in groups:
		var chunk := FloorChunk.new()
		chunk.name = "Ground_%s_%s" % [key.x, key.y]
		chunk.layout = self
		chunk.coordinates = groups[key]
		chunk.show_behind_parent = true
		add_child(chunk)

func _build_boundaries() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	add_child(body)
	var edges := {Vector2i(1, 0): [Vector2(32, 0), Vector2(0, 16)], Vector2i(0, 1): [Vector2(0, 16), Vector2(-32, 0)], Vector2i(-1, 0): [Vector2(-32, 0), Vector2(0, -16)], Vector2i(0, -1): [Vector2(0, -16), Vector2(32, 0)]}
	for tile in tiles:
		for direction in edges:
			if tiles.has(tile + direction):
				continue
			var shape := SegmentShape2D.new()
			shape.a = iso(Vector2(tile)) + edges[direction][0]
			shape.b = iso(Vector2(tile)) + edges[direction][1]
			var collision := CollisionShape2D.new()
			collision.shape = shape
			body.add_child(collision)

func _draw() -> void:
	_draw_seal(MARKERS["hub_spawn"], 72, Color("9b966b"))
	_draw_seal(Vector2(-6, 23), 118, Color("ad8d66"))
	_draw_seal(Vector2(35, 22), 48, Color("7a9279"))
	_draw_seal(Vector2(43, 26), 39, Color("8e82a2"))
	_draw_seal(Vector2(25, -28), 83, Color("aa9b68"))
	_draw_seal(Vector2(81, 36), 92, Color("aa9b85"))
	_draw_seal(Vector2(-6, 38), 70, Color("7dbaab"))

func _draw_tile(tile: Vector2i, target: CanvasItem) -> void:
	var center := iso(Vector2(tile))
	var theme: String = tile_themes[tile]
	var base: Color = tiles[tile]
	var noise := posmod(tile.x * 29 + tile.y * 17, 11)
	var color := base.lightened(float(noise) / 180.0)
	var top := PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)])
	var depth := 20.0 if theme != "wood" else 11.0
	for edge in [Vector2i(1, 0), Vector2i(0, 1)]:
		if tiles.has(tile + edge):
			continue
		var a := center + (Vector2(32, 0) if edge.x == 1 else Vector2(0, 16))
		var b := center + (Vector2(0, 16) if edge.x == 1 else Vector2(-32, 0))
		target.draw_colored_polygon(PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)]), base.darkened(.42))
		target.draw_line(a + Vector2(0, depth), b + Vector2(0, depth), Color("243e3e"), 2)
		if theme == "wood":
			target.draw_line(a + Vector2(-2, 3), a + Vector2(-2, 33), Color("443e32"), 4)
		else:
			target.draw_line(a + Vector2(0, 8), b + Vector2(0, 8), base.darkened(.6), 1)
		target.draw_line(a, b, base.lightened(.18), 1)
	if Art.draw_tile(target, center, theme, tile):
		return
	target.draw_colored_polygon(top, color)
	if theme == "wood":
		for plank in range(1, 5):
			var t := plank / 5.0
			var a := center + Vector2(-32, 0).lerp(Vector2(0, -16), t)
			var b := center + Vector2(0, 16).lerp(Vector2(32, 0), t)
			target.draw_line(a, b, base.darkened(.28), 1)
		if noise % 3 == 0:
			target.draw_line(center + Vector2(-4, -4), center + Vector2(9, 2), base.lightened(.13), 1)
			target.draw_rect(Rect2(center + Vector2(-21, -1), Vector2(1, 1)), Color("b1a07a"))
	else:
		var seam := base.darkened(.22)
		target.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), seam, 1)
		if theme in ["sand", "garden"]:
			for speck in range(4):
				var x := float(posmod(noise * 7 + speck * 11, 31) - 15)
				var y := float(posmod(noise * 3 + speck * 5, 11) - 5)
				target.draw_rect(Rect2(center + Vector2(x, y), Vector2(2, 1)), base.darkened(.1 if speck % 2 == 0 else .28))
		if theme in ["mosaic", "crypt", "aqueduct"] and noise % 3 == 0:
			var inlay := Color("a9a077") if theme != "crypt" else Color("8e82a4")
			target.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -3), center + Vector2(6, 0), center + Vector2(0, 3), center + Vector2(-6, 0)]), inlay.darkened(.15))
		if noise % 4 == 0:
			target.draw_polyline(PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, 0), center + Vector2(1, 5), center + Vector2(7, 7)]), base.darkened(.35), 1)
	if theme == "aqueduct":
		for side in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not tiles.has(tile + side):
				var rail := center + Vector2(17 if side.x == 1 else -17, 8)
				target.draw_line(rail, rail - Vector2(0, 11), Color("7e8e7a"), 2)

func _draw_seal(tile: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(iso(tile), 0, Vector2(1, .5))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color.darkened(.08), 2)
	draw_arc(Vector2.ZERO, radius - 10, 0, TAU, 64, color.darkened(.25), 1)
	var star := PackedVector2Array()
	for point in range(16):
		var angle := point * TAU / 16.0
		var length := radius * (.61 if point % 2 == 0 else .27)
		star.append(Vector2(cos(angle), sin(angle)) * length)
	star.append(star[0])
	draw_polyline(star, color.darkened(.2), 1)
	draw_set_transform(Vector2.ZERO)

class FloorChunk:
	extends Node2D
	var layout: Node2D
	var coordinates: Array = []

	func _ready() -> void:
		coordinates.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
		var shore := ShoreFoam.new()
		shore.show_behind_parent = true
		for tile: Vector2i in coordinates:
			var center: Vector2 = layout.iso(Vector2(tile))
			var depth := 11.0 if layout.tile_themes[tile] == "wood" else 20.0
			for edge in [Vector2i(1, 0), Vector2i(0, 1)]:
				if layout.tiles.has(tile + edge): continue
				var a := center + (Vector2(32, 0) if edge.x == 1 else Vector2(0, 16))
				var b := center + (Vector2(0, 16) if edge.x == 1 else Vector2(-32, 0))
				shore.lines.append(a + Vector2(1, depth + 4))
				shore.lines.append(b + Vector2(-1, depth + 4))
		add_child(shore)

	func _draw() -> void:
		for tile: Vector2i in coordinates:
			layout._draw_tile(tile, self)

class ShoreFoam:
	extends Node2D
	var lines := PackedVector2Array()

	func _ready() -> void:
		var effect := ShaderMaterial.new()
		effect.shader = preload("res://assets/shaders/harbor_pixel_foam.gdshader")
		material = effect

	func _draw() -> void:
		if not lines.is_empty():
			draw_multiline(lines, Color.WHITE, 2)

class HarborWater:
	extends Node2D

	func _draw() -> void:
		# TIME animates the shader without rebuilding the water drawing on the CPU.
		if not Art.draw_water(self, Rect2(-4000, -2400, 8000, 6000), 0.0):
			draw_rect(Rect2(-4000, -2400, 8000, 6000), Color("16343d"))
