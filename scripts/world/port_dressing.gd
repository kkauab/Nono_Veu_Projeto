extends RefCounted
const Story = preload("res://scripts/world/port_story.gd")
const CloisterLayout = preload("res://scripts/world/cloister_layout.gd")
const FarIslesLayout = preload("res://scripts/world/far_isles_layout.gd")
const LifeCatalog = preload("res://scripts/world/port_life_catalog.gd")

# A arquitetura fica fora dos eixos de circulação. Tudo o que tem base pintada é
# sólido (muros, braseiros e entulho também); só juncos e barcos são atravessáveis.
# A base fica atrás do ponto do tile: ela inteira tem de estar sobre a pedra, senão
# a peça flutua. tests/map_ground_test.gd confere isso e as passagens.
const PROPS := [
	["pillar", Vector2(-5, -4), "97917b"], ["pillar", Vector2(-5, 2), "868b7c"],
	["pillar", Vector2(3.25, -4), "97917b"], ["pillar", Vector2(3, 2), "868b7c"],
	["statue", Vector2(-1, -4), "a5a087"], ["wall", Vector2(-1.1, -4.95), "747c70"], ["arch", Vector2(4, .5), "92917a"],
	["torch", Vector2(-3, -1), "a29b79"], ["torch", Vector2(2, -2), "a29b79"],
	["reeds", Vector2(-6, 1), "51695d"], ["warehouse", Vector2(-3, -3.9), "707b70"],
	["bollard", Vector2(6, 2), "857d62"], ["bollard", Vector2(10, 2), "857d62"],
	["bollard", Vector2(14, 2), "857d62"], ["crate", Vector2(7, -1), "806343"],
	["crate", Vector2(15, -1), "806343"],
	["boat", Vector2(8, 5), "86775b"], ["boat", Vector2(15, 5.5), "86775b"],
	["torch", Vector2(5.4, -.9), "a29b79"], ["torch", Vector2(16, 1), "a29b79"],
	["stall", Vector2(18, -1), "6f8c7a"], ["stall", Vector2(24, 3.5), "886b58"],
	["barrel", Vector2(18, 3), "806343"], ["crate", Vector2(22, 3), "806343"],
	["warehouse", Vector2(20, -3.5), "8a8270"], ["warehouse", Vector2(25, -3.5), "787e70"],
	["arch", Vector2(27, 1), "998b71"], ["torch", Vector2(24.9, 2), "a29b79"],
	["pillar", Vector2(17, -4), "8c8f78"], ["torch", Vector2(23.4, -4), "a29b79"],
	["warehouse", Vector2(30, -.25), "7f8374"], ["warehouse", Vector2(36, -.25), "8d826c"],
	["crate", Vector2(29.55, 3), "806343"],
	["barrel", Vector2(36.8, 1), "806343"], ["crate", Vector2(37, 7), "806343"],
	["torch", Vector2(34, -1), "a29b79"], ["pillar", Vector2(29, 7), "858675"],
	["bollard", Vector2(31, 11), "797b65"], ["torch", Vector2(34, 13), "a29b79"],
	["bollard", Vector2(34, 16), "797b65"], ["boat", Vector2(37, 13), "86775b"],
	["wall", Vector2(27, 19.1), "6f7c70"], ["arch", Vector2(32.5, 19), "9b9278"],
	["pillar", Vector2(25, 20), "878c75"], ["pillar", Vector2(37, 20), "878c75"],
	["statue", Vector2(34, 23), "8d957d"], ["rubble", Vector2(28, 26), "7f8b78"],
	["palm", Vector2(25, 28), "556f5a"], ["torch", Vector2(37.4, 29.3), "a29b79"],
	["wall", Vector2(42, 22.1), "737e70"], ["reeds", Vector2(31, 24), "51695d"],
	["arch", Vector2(39, 25), "8f8e78"], ["pillar", Vector2(40, 23), "878c75"],
	["pillar", Vector2(45, 23), "878c75"], ["statue", Vector2(44, 25), "87918a"],
	["torch", Vector2(40, 28), "a29b79"],
	["boat", Vector2(38, 39), "86775b"],
	["bollard", Vector2(25, 32), "797b65"], ["bollard", Vector2(34, 32), "797b65"],
	["barrel", Vector2(28, 34), "806343"], ["crate", Vector2(32, 34), "806343"],
	["torch", Vector2(35.3, 31.4), "a29b79"], ["reeds", Vector2(24, 37), "51695d"],
	["palm", Vector2(12, 21), "556f5a"], ["palm", Vector2(12, 29), "556f5a"],
	["palm", Vector2(18, 28), "556f5a"], ["palm", Vector2(21, 21), "556f5a"],
	["reeds", Vector2(15, 23), "51695d"], ["reeds", Vector2(20, 27), "51695d"],
	["statue", Vector2(14, 20.05), "849683"], ["torch", Vector2(18, 20.2), "a29b79"],
	["wall", Vector2(11, 22), "687a6a"], ["arch", Vector2(12, 25), "8a927c"],
	["pillar", Vector2(3.25, 17.05), "8c8b74"], ["pillar", Vector2(11, 17.05), "8c8b74"],
	["statue", Vector2(5, 18), "9d9a7d"], ["torch", Vector2(6, 21.6), "a29b79"],
	["warehouse", Vector2(9, 18.5), "69796d"], ["arch", Vector2(1, 23), "969077"],
	["crate", Vector2(9.8, 22), "806343"], ["barrel", Vector2(3, 26), "806343"],
	["pillar", Vector2(-11, 18), "94917d"], ["pillar", Vector2(-2, 18), "94917d"],
	["pillar", Vector2(-11, 29), "94917d"], ["pillar", Vector2(-1, 29), "94917d"],
	["wall", Vector2(-6, 16.1), "727f74"], ["statue", Vector2(-6, 17), "a09a7a"],
	["torch", Vector2(-10, 24), "a29b79"], ["torch", Vector2(-2, 24), "a29b79"],
	["arch", Vector2(-14, 25), "767f7a"], ["wall", Vector2(-22.5, 20.1), "5c6d6b"],
	["pillar", Vector2(-23, 22), "74837c"], ["statue", Vector2(-22, 28), "71847c"],
	["reeds", Vector2(22.5, 9), "51695d"], ["torch", Vector2(20.15, 10), "a29b79"],
	["torch", Vector2(21.45, 17), "a29b79"], ["wall", Vector2(.1, 8), "65786e", true],
	["wall", Vector2(2.5, 13), "65786e", true],
	# Echo gallery: the walking line runs from the descent along rows -1 and 0 to the grate.
	["pillar", Vector2(-18, -3), "6d6f7b"], ["pillar", Vector2(-8, -3), "6d6f7b"],
	["pillar", Vector2(-8, 2), "6d6f7b"], ["statue", Vector2(-13, -3), "7a7c88"],
	["wall", Vector2(-16, -3.65), "5f6170"], ["wall", Vector2(-10, -3.65), "5f6170"],
	["torch", Vector2(-15, -3), "a29b79"], ["torch", Vector2(-11, -3), "a29b79"],
	["rubble", Vector2(-12, 2), "6d6f7b"],
	["torch", Vector2(-18.85, 8), "a29b79"], ["torch", Vector2(-17, 14), "a29b79"]
]

static func populate(parent: Node2D) -> void:
	var site := _site()
	for index in range(PROPS.size()):
		var definition: Array = PROPS[index]
		# The opening must run across the road, rather than along it. A fourth
		# field mirrors other pieces: a ruined wall then runs along a north-south way.
		var mirror: bool = definition[3] if definition.size() > 3 else definition[0] == "arch" and definition[1] != Vector2(32.5, 19)
		var prop := _make(definition[0], definition[1], Color(definition[2]), index % 2, mirror)
		parent.add_child(prop)
		site["placed"].append_array(_ground_of(prop))
	_populate_districts(parent, site)

static func _make(kind: String, tile: Vector2, color: Color, variant: int = 0, mirror: bool = false) -> PortProp:
	var prop := PortProp.new()
	prop.kind = kind
	prop.position = PortLayout.iso(tile)
	prop.tint = color
	prop.solid = kind not in PortProp.PASSABLE
	prop.variant = variant
	prop.mirror = mirror
	if kind == "arch":
		prop.position += Vector2(-2 if mirror else 2, 13)
	return prop

## What the district generator respects: the floor, the props already standing,
## the doorways and every spot where the game puts something.
static func _site() -> Dictionary:
	var catalog := PortLayout.tile_catalog()
	var doorways: Array[Rect2] = []
	for connector in PortLayout.CONNECTORS:
		# The connector plus a tile and a half of floor on each side, along the
		# way through: a brazier or a facade there blocks the passage.
		var rect: Rect2i = connector["rect"]
		var along_x := catalog.has(rect.position - Vector2i(1, 0)) and catalog.has(Vector2i(rect.end.x, rect.position.y))
		var along_y := catalog.has(rect.position - Vector2i(0, 1)) and catalog.has(Vector2i(rect.position.x, rect.end.y))
		var reach_x := 1.5 if along_x else .25
		var reach_y := 1.5 if along_y else .25
		doorways.append(Rect2(Vector2(rect.position) - Vector2(.5, .5), Vector2(rect.size)).grow_individual(reach_x, reach_y, reach_x, reach_y))
	var spots: Array[Vector2] = []
	spots.append_array(PortLayout.MARKERS.values())
	for mark in Story.MARKS.values(): spots.append(mark["tile"])
	spots.append_array([Story.RELIC_TILE, Story.FISHER_TILE, Story.BROTHER_DOCK_TILE, Story.BROTHER_HOME_TILE])
	# As peças do claustro e das ilhas além da baía, e a ponta de cada píer novo.
	spots.append_array(CloisterLayout.MARKERS.values())
	spots.append_array(FarIslesLayout.MARKERS.values())
	for id in FarIslesLayout.ISLES: spots.append(FarIslesLayout.ISLES[id]["landing"])
	var spawns: Array[Vector2] = []
	for spawn in PortLayout.ENEMY_SPAWNS: spawns.append(spawn["tile"])
	return {"catalog": catalog, "doorways": doorways, "spots": spots, "spawns": spawns, "placed": []}

## Painted footprints of a prop, in world pixels.
static func _ground_of(prop: PortProp) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for polygon in prop.foundation_polygons():
		var moved := PackedVector2Array()
		for point in polygon: moved.append(point + prop.position)
		result.append(moved)
	return result

## Tall facades hang over the floor in front of their base, so they keep this
## much more room (in tiles) from a doorway than their footprint alone needs.
const FACADE_MARGIN := {"warehouse": 1.0, "temple": 1.0, "lighthouse": 1.0, "stall": .5}

static func _fits(ground: Array[PackedVector2Array], site: Dictionary, margin: float = 0.0) -> bool:
	var doorways: Array[Rect2] = []
	for doorway: Rect2 in site["doorways"]: doorways.append(doorway.grow(margin))
	for polygon in ground:
		var centre := Vector2.ZERO
		for point in polygon: centre += point / polygon.size()
		var probes: Array[Vector2] = [centre]
		for index in range(polygon.size()):
			var corner := polygon[index].move_toward(centre, 1.5)
			probes.append(corner)
			probes.append(corner.lerp(polygon[(index + 1) % polygon.size()].move_toward(centre, 1.5), .5))
		for probe in probes:
			# The whole base stands on stone: a corner over the water floats.
			var tile := PortLayout.unproject(probe)
			if not site["catalog"].has(Vector2i((tile + Vector2(.5, .5)).floor())): return false
			for doorway in doorways:
				if doorway.has_point(tile): return false
		for doorway in doorways:
			for corner in [doorway.position, doorway.end, Vector2(doorway.position.x, doorway.end.y), Vector2(doorway.end.x, doorway.position.y), doorway.get_center()]:
				if Geometry2D.is_point_in_polygon(PortLayout.iso(corner), polygon): return false
		# Room to stand in front of a mechanism, and a little around each enemy start.
		for spot: Vector2 in site["spots"] + site["spawns"]:
			var at := PortLayout.iso(spot)
			var room := 28.0 if spot in site["spots"] else 16.0
			if Geometry2D.is_point_in_polygon(at, polygon): return false
			for index in range(polygon.size()):
				if at.distance_to(Geometry2D.get_closest_point_to_segment(at, polygon[index], polygon[(index + 1) % polygon.size()])) < room: return false
		for other: PackedVector2Array in site["placed"]:
			if not Geometry2D.intersect_polygons(polygon, other).is_empty(): return false
	return true

## Places a district prop at the first of `shifts` (tile offsets) where it fits;
## where none does, the room goes without it.
static func _district_prop(parent: Node2D, site: Dictionary, kind: String, tile: Vector2, color: Color, variant: int = 0, shifts: Array = [Vector2.ZERO], mirror: bool = false) -> void:
	for shift: Vector2 in shifts:
		var at := tile + shift
		# Puzzle mechanisms, checkpoints and enemy starting positions stay clear.
		if site["spots"].any(func(spot: Vector2) -> bool: return at.distance_to(spot) < 1.2):
			continue
		if site["spawns"].any(func(spawn: Vector2) -> bool: return at.distance_to(spawn) < .9):
			continue
		var prop := _make(kind, at, color, variant, mirror)
		var ground := _ground_of(prop)
		if not _fits(ground, site, FACADE_MARGIN.get(kind, 0.0)):
			prop.free()
			continue
		parent.add_child(prop)
		site["placed"].append_array(ground)
		return

static func _populate_districts(parent: Node2D, site: Dictionary) -> void:
	# Landmarks first, then the larger pieces, then the dressing that fills the gaps.
	var sideways := [Vector2.ZERO, Vector2(-2.5, 0), Vector2(2.5, 0), Vector2(-5, 0), Vector2(5, 0)]
	var nudges := [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0)]
	_district_prop(parent, site, "lighthouse", Vector2(85, 24), Color("747366").lightened(.15))
	_district_prop(parent, site, "temple", Vector2(5, -34.5), Color("5a625d").lightened(.15))
	_district_prop(parent, site, "stairs", Vector2(25, -34), Color("707367").lightened(.15))
	for room in PortLayout.ROOMS.slice(13):
		if not room.get("generated", true):
			continue
		var rect: Rect2i = room["rect"]
		var origin := Vector2(rect.position)
		var size := Vector2(rect.size)
		var stone: Color = room["color"].lightened(.15)
		if room["id"] in ["caravan", "kilns", "copper_dock", "salt_road"]:
			_district_prop(parent, site, "warehouse", origin + Vector2(size.x * .5, 1.25), stone, 0, sideways)
			if room["id"] == "caravan":
				_district_prop(parent, site, "stall", origin + Vector2(2, 5), Color("657e70"), 0, nudges)
				_district_prop(parent, site, "stall", origin + Vector2(size.x - 2, 5), Color("a18162"), 1, nudges)
		elif room["id"] not in ["cistern", "sluice", "reservoir"]:
			_district_prop(parent, site, "arch", origin + Vector2(size.x * .5, 1), stone, 0, sideways)
		for corner in [Vector2(1, 1), Vector2(size.x - 2, 1), Vector2(1, size.y - 2), size - Vector2(2, 2)]:
			_district_prop(parent, site, "pillar", origin + corner, stone, int(corner.x))
		for along in range(3, rect.size.x - 2, 4):
			_district_prop(parent, site, "wall", origin + Vector2(along, .35), stone.darkened(.12))
			_district_prop(parent, site, "torch", origin + Vector2(along, 1), stone)
		if room["id"] in ["caravan", "kilns", "copper_dock", "salt_road"]:
			for index in range(3):
				_district_prop(parent, site, "crate" if index % 2 == 0 else "barrel", origin + Vector2(2 + index * 4, size.y - 2), Color("947657"), index)
		elif room["id"] in ["cistern", "sluice", "reservoir"]:
			for index in range(3):
				_district_prop(parent, site, "reeds", origin + Vector2(size.x - 1, 3 + index * 3), Color("5b7864"))
			_district_prop(parent, site, "statue", origin + Vector2(2, size.y - 3), stone)
		else:
			_district_prop(parent, site, "statue", origin + Vector2(2, size.y * .5), stone)
			_district_prop(parent, site, "rubble", origin + Vector2(size.x - 3, size.y - 3), stone)
		if room["id"] in ["pilgrim", "caravan", "salt_road"]:
			_district_prop(parent, site, "palm", origin + Vector2(1, 7), Color("647b60"))
	_populate_identity(parent, site)


## Identidade de cada lugar (docs/MUNDO_PROPOSTA_2026-10-30.md, Gustavo 30/10/2026):
## o que cada distrito foi, nos espaços que o molde comum deixou vazios, mais o
## Claustro dos Iniciados e a arquitetura de pedra das ilhas além da baía.
## [peça, tile, cor, espelhar]. Cada peça passa pelo mesmo teste do gerador (base
## inteira no chão, fora das bocas de passagem, longe das peças de missão, dos
## inimigos e das paradas dos moradores); a que não cabe tenta um passo ao lado
## e, se ainda não couber, fica de fora. A cor só pinta o que é desenhado por
## código (entulho, montes de sal e escória); a arte do Pixelorama mantém a sua.
const SALT := "ddd5c0"
const SLAG := "3d3631"
const IDENTITY := {
	# Fornos: duas fornalhas acesas, escória, lingotes e carvão.
	"kilns": [["torch", Vector2(70.4, -1.4), "a29b79"], ["torch", Vector2(71.6, -.2), "a29b79"], ["rubble", Vector2(71.6, 1.8), SLAG],
		["rubble", Vector2(59.6, -1.0), SLAG], ["crate", Vector2(69.0, -1.2), "806343"], ["barrel", Vector2(62.2, -1.2), "806343"],
		["rubble", Vector2(72.0, 4.6), SLAG], ["crate", Vector2(71.8, 6.6), "806343"], ["wall", Vector2(66.6, -1.6), "6f6a5f"],
		["torch", Vector2(67.6, -.6), "a29b79"], ["rubble", Vector2(65.2, -.4), SLAG]],
	# Estrada do Sal: montes de sal, a barraca do salineiro, carga e um marco.
	"salt_road": [["rubble", Vector2(59.4, 15.4), SALT], ["rubble", Vector2(60.6, 16.8), SALT], ["rubble", Vector2(59.0, 20.8), SALT],
		["rubble", Vector2(61.8, 22.0), SALT], ["stall", Vector2(61.6, 14.0), "a7a08a"], ["crate", Vector2(63.2, 19.4), "806343"],
		["barrel", Vector2(64.4, 20.4), "806343"], ["crate", Vector2(70.0, 13.2), "806343"], ["barrel", Vector2(71.0, 14.4), "806343"],
		["statue", Vector2(66.8, 21.2), "8b8168"], ["palm", Vector2(70.2, 23.2), "647b60"]],
	# Escadaria dos Peregrinos: estelas votivas, um braseiro e a sombra da aguadeira.
	"pilgrim": [["statue", Vector2(31.0, -15.4), "8a8574"], ["torch", Vector2(31.8, -13.4), "a29b79"], ["statue", Vector2(31.0, -11.6), "8a8574"],
		["statue", Vector2(26.4, -13.0), "8a8574"], ["palm", Vector2(18.6, -18.2), "647b60"], ["stall", Vector2(19.6, -14.6), "657e70"],
		["rubble", Vector2(32.2, -17.8), "8a8574"]],
	# Pátio dos Escribas: o toldo onde se copiava, fileiras de estelas de registro.
	"scriptorium": [["stall", Vector2(-1.0, -15.2), "8a8a74"], ["statue", Vector2(-2.6, -12.2), "858577"], ["palm", Vector2(-2.6, -17.8), "647b60"],
		["statue", Vector2(8.6, -15.6), "858577"], ["statue", Vector2(10.6, -15.6), "858577"], ["statue", Vector2(12.6, -15.6), "858577"],
		["torch", Vector2(12.6, -18.6), "a29b79"]],
	# Terraço do Farol: braseiro de sinal, jarros de óleo, blocos caídos do farol.
	"beacon": [["torch", Vector2(82.6, 13.0), "a29b79"], ["barrel", Vector2(83.6, 15.6), "806343"], ["crate", Vector2(85.4, 16.6), "806343"],
		["rubble", Vector2(86.2, 18.8), "7a7b70"], ["rubble", Vector2(82.4, 19.8), "7a7b70"], ["rubble", Vector2(75.6, 23.4), "7a7b70"]],
	# Reservatório: palmeiras e estátuas nas quinas do lago, juncos na margem.
	"reservoir": [["palm", Vector2(61.4, 32.4), "647b60"], ["palm", Vector2(67.6, 37.6), "647b60"], ["statue", Vector2(67.4, 32.4), "819489"],
		["statue", Vector2(61.4, 37.6), "819489"], ["reeds", Vector2(62.0, 36.6), "5b7864"], ["reeds", Vector2(66.4, 32.8), "5b7864"],
		["torch", Vector2(59.0, 29.4), "a29b79"], ["torch", Vector2(70.4, 29.4), "a29b79"]],
	# Cais do Cobre: carga empilhada e cabeços para os navios.
	"copper_dock": [["crate", Vector2(51.6, 33.6), "806343"], ["barrel", Vector2(52.8, 34.2), "806343"], ["crate", Vector2(53.2, 37.6), "806343"],
		["bollard", Vector2(42.6, 42.4), "797b65"], ["bollard", Vector2(51.6, 42.4), "797b65"]],
	# Limiar das Catacumbas: colunas e entulho longe da subida do Eco.
	"a02": [["pillar", Vector2(-24.4, 26.4), "74837c"], ["rubble", Vector2(-23.6, 29.4), "5e6d69"], ["torch", Vector2(-20.4, 29.6), "a29b79"],
		["statue", Vector2(-16.6, 29.4), "71847c"], ["wall", Vector2(-24.6, 23.6), "5c6d6b", true]],
	# Claustro dos Iniciados: a Casa das Primeiras Palavras, os mestres de pedra e o lago.
	"cloister": [["temple", Vector2(-12.3, 5.7), "6f7c70"], ["torch", Vector2(-13.5, 7.4), "a29b79"], ["torch", Vector2(-11.4, 4.7), "a29b79"],
		["statue", Vector2(-10.2, 4.6), "a5a087"], ["statue", Vector2(-6.6, 4.6), "a5a087"],
		["pillar", Vector2(-1.9, 5.8), "97917b"], ["wall", Vector2(-13.4, 10.4), "747c70", true], ["palm", Vector2(-12.8, 12.6), "556f5a"],
		["palm", Vector2(-3.0, 12.4), "556f5a"], ["reeds", Vector2(-8.6, 7.6), "51695d"], ["reeds", Vector2(-7.2, 9.2), "51695d"],
		["rubble", Vector2(-6.0, 12.8), "7f8b78"], ["torch", Vector2(-2.2, 9.6), "a29b79"]],
	# Ilha do Íbis Afogado: o templo dos escribas afundando, estelas e muros caídos.
	"ibis": [["temple", Vector2(7.2, 73.6), "6a6f78"], ["statue", Vector2(13.4, 71.4), "7d8290"], ["statue", Vector2(14.0, 76.8), "7d8290"],
		["wall", Vector2(9.2, 70.4), "666b74"], ["wall", Vector2(5.6, 76.8), "666b74", true], ["torch", Vector2(6.4, 71.4), "a29b79"],
		["rubble", Vector2(16.6, 69.6), "7d8290"], ["rubble", Vector2(5.0, 72.8), "7d8290"], ["pillar", Vector2(19.0, 74.6), "8a8578"],
		["palm", Vector2(6.0, 79.2), "556f5a"], ["palm", Vector2(18.8, 71.4), "556f5a"]],
	# Recife do Navio Esquecido: o navio encalhado, a carga espalhada e a fogueira dos náufragos.
	"wreck": [["boat", Vector2(89.6, 71.8), "86775b"], ["crate", Vector2(83.0, 70.4), "806343"], ["barrel", Vector2(81.6, 68.6), "806343"],
		["crate", Vector2(74.8, 66.6), "806343"], ["barrel", Vector2(88.2, 68.6), "806343"], ["torch", Vector2(73.2, 64.8), "a29b79"],
		["palm", Vector2(79.0, 61.8), "556f5a"], ["palm", Vector2(85.2, 63.4), "556f5a"], ["palm", Vector2(76.2, 65.4), "556f5a"],
		["bollard", Vector2(72.4, 65.6), "797b65"], ["stall", Vector2(80.6, 68.2), "b0a88e"], ["crate", Vector2(81.8, 66.2), "806343"]],
}
const IDENTITY_NUDGES := [Vector2.ZERO, Vector2(.4, 0), Vector2(-.4, 0), Vector2(0, .4), Vector2(0, -.4)]


static func _populate_identity(parent: Node2D, site: Dictionary) -> void:
	# As paradas dos moradores (port_life_catalog.gd) ficam livres, como os inimigos.
	# Só aqui: o molde comum dos distritos continua igual ao de antes.
	var guarded := site.duplicate()
	var spawns: Array[Vector2] = []
	spawns.append_array(site["spawns"])
	for folk in LifeCatalog.TOWNSFOLK:
		for stop in folk.get("route", []):
			spawns.append(stop[0])
	guarded["spawns"] = spawns
	for room_id in IDENTITY:
		for entry: Array in IDENTITY[room_id]:
			var mirror: bool = entry.size() > 3 and entry[3]
			_district_prop(parent, guarded, entry[0], entry[1], Color(entry[2]), 0, IDENTITY_NUDGES, mirror)
