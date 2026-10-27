extends RefCounted

# A arquitetura fica fora dos eixos de circulação. Props sólidos são pequenos
# elementos de cenário; fachadas e barcos ocupam a margem não caminhável.
const PROPS := [
	["pillar", Vector2(-5, -4), "97917b", true], ["pillar", Vector2(-5, 2), "868b7c", true],
	["pillar", Vector2(3, -4), "97917b", true], ["pillar", Vector2(3, 2), "868b7c", true],
	["statue", Vector2(-1, -4), "a5a087", true], ["wall", Vector2(-4, -5.5), "747c70", false],
	["wall", Vector2(0, -5.5), "747c70", false], ["arch", Vector2(4, .5), "92917a", false],
	["torch", Vector2(-3, -1), "a29b79", false], ["torch", Vector2(2, -2), "a29b79", false],
	["reeds", Vector2(-6, 1), "51695d", false], ["warehouse", Vector2(-3, -3.9), "707b70", true],
	["bollard", Vector2(6, 2), "857d62", true], ["bollard", Vector2(10, 2), "857d62", true],
	["bollard", Vector2(14, 2), "857d62", true], ["crate", Vector2(7, -1), "806343", true],
	["crate", Vector2(15, -1), "806343", true],
	["boat", Vector2(8, 5), "86775b", false], ["boat", Vector2(15, 5.5), "86775b", false],
	["torch", Vector2(5, -1), "a29b79", false], ["torch", Vector2(16, 1), "a29b79", false],
	["stall", Vector2(18, -1), "6f8c7a", true], ["stall", Vector2(24, 3.5), "886b58", true],
	["barrel", Vector2(18, 3), "806343", true], ["crate", Vector2(22, 3), "806343", true],
	["warehouse", Vector2(20, -3.5), "8a8270", true], ["warehouse", Vector2(25, -3.5), "787e70", true],
	["arch", Vector2(27, 1), "998b71", false], ["torch", Vector2(26, 2), "a29b79", false],
	["pillar", Vector2(17, -4), "8c8f78", true], ["torch", Vector2(23, -4), "a29b79", false],
	["warehouse", Vector2(30, -.25), "7f8374", true], ["warehouse", Vector2(36, -.25), "8d826c", true],
	["crate", Vector2(29, 3), "806343", true],
	["barrel", Vector2(37, 1), "806343", true], ["crate", Vector2(37, 7), "806343", true],
	["torch", Vector2(34, -1), "a29b79", false], ["pillar", Vector2(29, 7), "858675", true],
	["bollard", Vector2(31, 11), "797b65", true], ["torch", Vector2(34, 13), "a29b79", false],
	["bollard", Vector2(34, 16), "797b65", true], ["boat", Vector2(37, 13), "86775b", false],
	["wall", Vector2(29.5, 16), "6f7c70", false], ["arch", Vector2(32.5, 19), "9b9278", false],
	["pillar", Vector2(25, 20), "878c75", true], ["pillar", Vector2(37, 20), "878c75", true],
	["statue", Vector2(34, 23), "8d957d", true], ["rubble", Vector2(28, 26), "7f8b78", false],
	["palm", Vector2(25, 28), "556f5a", true], ["torch", Vector2(37, 28), "a29b79", false],
	["wall", Vector2(39.5, 20.5), "737e70", false], ["reeds", Vector2(31, 24), "51695d", false],
	["arch", Vector2(39, 25), "8f8e78", false], ["pillar", Vector2(40, 23), "878c75", true],
	["pillar", Vector2(45, 23), "878c75", true], ["statue", Vector2(44, 25), "87918a", true],
	["torch", Vector2(40, 28), "a29b79", false], ["wall", Vector2(43, 30.5), "626f6b", false],
	["boat", Vector2(29, 38), "86775b", false], ["boat", Vector2(38, 39), "86775b", false],
	["bollard", Vector2(25, 32), "797b65", true], ["bollard", Vector2(34, 32), "797b65", true],
	["barrel", Vector2(28, 34), "806343", true], ["crate", Vector2(32, 34), "806343", true],
	["torch", Vector2(33, 37), "a29b79", false], ["reeds", Vector2(24, 37), "51695d", false],
	["palm", Vector2(12, 21), "556f5a", true], ["palm", Vector2(12, 29), "556f5a", true],
	["palm", Vector2(18, 28), "556f5a", true], ["palm", Vector2(21, 21), "556f5a", true],
	["reeds", Vector2(15, 23), "51695d", false], ["reeds", Vector2(20, 27), "51695d", false],
	["statue", Vector2(14, 20), "849683", true], ["torch", Vector2(18, 20), "a29b79", false],
	["wall", Vector2(11, 22), "687a6a", false], ["arch", Vector2(12, 25), "8a927c", false],
	["pillar", Vector2(3, 17), "8c8b74", true], ["pillar", Vector2(11, 17), "8c8b74", true],
	["statue", Vector2(5, 18), "9d9a7d", true], ["torch", Vector2(6, 20), "a29b79", false],
	["warehouse", Vector2(9, 18.5), "69796d", true], ["arch", Vector2(1, 23), "969077", false],
	["crate", Vector2(10, 22), "806343", true], ["barrel", Vector2(3, 26), "806343", true],
	["pillar", Vector2(-11, 18), "94917d", true], ["pillar", Vector2(-1, 18), "94917d", true],
	["pillar", Vector2(-11, 29), "94917d", true], ["pillar", Vector2(-1, 29), "94917d", true],
	["wall", Vector2(-6, 14.5), "727f74", false], ["statue", Vector2(-6, 17), "a09a7a", true],
	["torch", Vector2(-10, 24), "a29b79", false], ["torch", Vector2(-2, 24), "a29b79", false],
	["arch", Vector2(-14, 25), "767f7a", false], ["wall", Vector2(-21, 19), "5c6d6b", false],
	["pillar", Vector2(-23, 22), "74837c", true], ["statue", Vector2(-22, 28), "71847c", true],
	["reeds", Vector2(22.5, 9), "51695d", false], ["torch", Vector2(20, 10), "a29b79", false],
	["torch", Vector2(21, 17), "a29b79", false], ["wall", Vector2(-.35, 8), "65786e", false],
	["wall", Vector2(2.35, 13), "65786e", false]
]

static func populate(parent: Node2D) -> void:
	for index in range(PROPS.size()):
		var definition: Array = PROPS[index]
		var prop := PortProp.new()
		prop.kind = definition[0]
		prop.position = PortLayout.iso(definition[1])
		prop.tint = Color(definition[2])
		prop.solid = definition[3]
		prop.variant = index % 2
		# The opening must run across the road, rather than along it.
		prop.mirror = prop.kind == "arch" and definition[1] != Vector2(32.5, 19)
		if prop.kind == "arch":
			prop.position += Vector2(-2 if prop.mirror else 2, 13)
		parent.add_child(prop)
	_populate_districts(parent)

static func _district_prop(parent: Node2D, kind: String, tile: Vector2, color: Color, solid: bool = false, variant: int = 0) -> void:
	# Puzzle mechanisms, checkpoints and enemy starting positions stay clear.
	for marker in PortLayout.MARKERS.values():
		if tile.distance_to(marker) < 1.2:
			return
	for spawn in PortLayout.ENEMY_SPAWNS:
		if tile.distance_to(spawn["tile"]) < .9:
			return
	var prop := PortProp.new()
	prop.kind = kind
	prop.position = PortLayout.iso(tile)
	prop.tint = color
	prop.solid = solid
	prop.variant = variant
	prop.mirror = false
	if kind == "arch":
		prop.position += Vector2(2, 13)
	parent.add_child(prop)

static func _populate_districts(parent: Node2D) -> void:
	for room in PortLayout.ROOMS.slice(13):
		var rect: Rect2i = room["rect"]
		var origin := Vector2(rect.position)
		var size := Vector2(rect.size)
		var stone: Color = room["color"].lightened(.15)
		for corner in [Vector2(1, 1), Vector2(size.x - 2, 1), Vector2(1, size.y - 2), size - Vector2(2, 2)]:
			_district_prop(parent, "pillar", origin + corner, stone, true, int(corner.x))
		for along in range(3, rect.size.x - 2, 4):
			_district_prop(parent, "torch", origin + Vector2(along, 1), stone)
			_district_prop(parent, "wall", origin + Vector2(along, .35), stone.darkened(.12))
		if room["id"] in ["caravan", "kilns", "copper_dock", "salt_road"]:
			for index in range(3):
				_district_prop(parent, "crate" if index % 2 == 0 else "barrel", origin + Vector2(2 + index * 4, size.y - 2), Color("947657"), true, index)
			_district_prop(parent, "warehouse", origin + Vector2(size.x * .5, 1.25), stone, true)
			if room["id"] == "caravan":
				_district_prop(parent, "stall", origin + Vector2(2, 5), Color("657e70"), true)
				_district_prop(parent, "stall", origin + Vector2(size.x - 2, 5), Color("a18162"), true, 1)
		elif room["id"] in ["cistern", "sluice", "reservoir"]:
			for index in range(3):
				_district_prop(parent, "reeds", origin + Vector2(size.x - 1, 3 + index * 3), Color("5b7864"))
			_district_prop(parent, "statue", origin + Vector2(2, size.y - 3), stone, true)
		else:
			_district_prop(parent, "arch", origin + Vector2(size.x * .5, 1), stone)
			_district_prop(parent, "statue", origin + Vector2(2, size.y * .5), stone, true)
			_district_prop(parent, "rubble", origin + Vector2(size.x - 3, size.y - 3), stone)
		if room["id"] in ["pilgrim", "caravan", "salt_road"]:
			_district_prop(parent, "palm", origin + Vector2(1, 7), Color("647b60"), true)
		if room["id"] == "copper_dock":
			_district_prop(parent, "boat", origin + Vector2(6, size.y + 2), Color("998060"))
		if room["id"] == "beacon":
			_district_prop(parent, "lighthouse", Vector2(85, 24), stone)
		elif room["id"] == "archive":
			_district_prop(parent, "temple", Vector2(5, -34.5), stone, true)
		elif room["id"] == "bellcourt":
			_district_prop(parent, "stairs", Vector2(25, -34), stone)
