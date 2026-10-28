extends RefCounted
const Story = preload("res://scripts/world/port_story.gd")

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
static func _district_prop(parent: Node2D, site: Dictionary, kind: String, tile: Vector2, color: Color, variant: int = 0, shifts: Array = [Vector2.ZERO]) -> void:
	for shift: Vector2 in shifts:
		var at := tile + shift
		# Puzzle mechanisms, checkpoints and enemy starting positions stay clear.
		if site["spots"].any(func(spot: Vector2) -> bool: return at.distance_to(spot) < 1.2):
			continue
		if site["spawns"].any(func(spawn: Vector2) -> bool: return at.distance_to(spawn) < .9):
			continue
		var prop := _make(kind, at, color, variant)
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
