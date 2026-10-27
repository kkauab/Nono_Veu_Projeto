extends Node2D
class_name PortProp
const Art = preload("res://scripts/world/port_art.gd")

var kind := "pillar"
var tint := Color("818479")
var solid := true
var variant := 0
var mirror := false
var _hero: Node2D
var _time := 0.0
var _height := 48.0
var _width := 20.0
var _visibility_tick := 0.0
var _flame_tick := 0.0
var _opacity := 1.0
var _collision_radius := 0.0
var _ground_line := PackedFloat32Array()
var _art_bottom := PackedFloat32Array()

## Facades wider than an actor are cut into columns, each sorted at the floor line
## of its own art: Senu beside a warehouse wall or under an arch is no longer drawn
## behind the whole building.
const SLICED := ["warehouse", "temple", "arch", "stall", "lighthouse"]
const SLICE_WIDTH := 4
## Senu's sprite rises about 40 px above his feet.
const ACTOR_HEIGHT := 42.0

class ArtColumns extends Node2D:
	var prop: PortProp
	var from := 0
	var to := 0
	## Lowest painted pixel of these columns; a lintel stays above Senu's head.
	var lowest := 0.0

	func _draw() -> void:
		prop.draw_columns(self, from, to)

class GroundShadow extends Node2D:
	var prop: PortProp

	func _draw() -> void:
		prop.draw_ground(self)

func foundation_polygons() -> Array[PackedVector2Array]:
	# Ground-plane silhouettes follow the painted bases, not the tall facade.
	var result: Array[PackedVector2Array] = []
	if kind == "warehouse":
		# The painted crates in front of the tower belong to the solid base.
		result.append(PackedVector2Array([Vector2(-48, -23), Vector2(-8, -3), Vector2(20, 0), Vector2(50, -12), Vector2(49, -24), Vector2(7, -45)]))
	elif kind == "stall":
		# The four poles, not just the counter: Senu no longer walks under the awning.
		result.append(PackedVector2Array([Vector2(-27, -14), Vector2(13, -1), Vector2(29, -12), Vector2(-11, -25)]))
	elif kind == "temple":
		result.append(PackedVector2Array([Vector2(-34, -15), Vector2(0, -1), Vector2(35, -17), Vector2(1, -34)]))
	elif kind == "arch":
		# The passage remains empty; each upright has its own small footprint.
		result.append(PackedVector2Array([Vector2(-27, -21), Vector2(-18, -25), Vector2(-9, -21), Vector2(-18, -17)]))
		result.append(PackedVector2Array([Vector2(3, -7), Vector2(14, -12), Vector2(25, -7), Vector2(14, -2)]))
	elif kind == "lighthouse":
		# Tower plinth, the fallen blocks around it and the ground under its banner.
		result.append(PackedVector2Array([Vector2(-43, -20), Vector2(-36, -8), Vector2(-27, -3), Vector2(-3, -1), Vector2(24, -3), Vector2(33, -7), Vector2(40, -13), Vector2(0, -34)]))
	if mirror:
		for index in range(result.size()):
			var reflected := PackedVector2Array()
			for point in result[index]: reflected.append(Vector2(-point.x, point.y))
			result[index] = reflected
	return result

func blocks_ground_point(point: Vector2, clearance: float = 0.0) -> bool:
	var local := to_local(point)
	var polygons := foundation_polygons()
	if not polygons.is_empty():
		for polygon in polygons:
			if Geometry2D.is_point_in_polygon(local, polygon): return true
			for edge in range(polygon.size()):
				if local.distance_to(Geometry2D.get_closest_point_to_segment(local, polygon[edge], polygon[(edge + 1) % polygon.size()])) < clearance: return true
		return false
	return solid and _collision_radius > 0.0 and local.length() < _collision_radius + clearance

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visibility_tick = fposmod(position.x * .003 + position.y * .005, .12)
	_flame_tick = fposmod(position.x * .005 + position.y * .003, .1)
	var radius := 0.0
	match kind:
		"pillar": radius = 9.0
		"crate", "barrel", "bollard": radius = 8.0
		"statue": radius = 11.0
		"palm": radius = 7.0
		"stall": radius = 14.0
	_collision_radius = radius
	var foundations := foundation_polygons()
	if (solid and (radius > 0 or not foundations.is_empty())) or kind == "arch":
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 6
		if not foundations.is_empty():
			for polygon in foundations:
				var collider := CollisionShape2D.new()
				var shape := ConvexPolygonShape2D.new()
				shape.points = polygon
				collider.shape = shape
				body.add_child(collider)
		else:
			var collider := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = radius
			collider.shape = shape
			body.add_child(collider)
		add_child(body)
		add_to_group("world_obstacles")
	if kind in ["warehouse", "arch", "boat"]:
		_height = 90
		_width = 62
	elif kind in ["palm", "stall", "statue"]:
		_height = 68
		_width = 35
	var extent := Art.prop_extent("crate") * .72 if kind == "barrel" else Art.prop_extent(kind)
	if extent != Vector2.ZERO:
		_height = extent.y
		_width = extent.x * .45
	if kind in SLICED:
		_slice_art()

func _slice_art() -> void:
	_ground_line = Art.ground_line(kind)
	_art_bottom = Art.art_bottom(kind)
	if _ground_line.is_empty():
		return
	y_sort_enabled = true
	var shadow := GroundShadow.new()
	shadow.prop = self
	# The contact shadow lies on the floor, under everyone standing beside it.
	shadow.z_index = -1
	add_child(shadow)
	var column := 0
	while column < _ground_line.size():
		if is_nan(_ground_line[column]):
			column += 1
			continue
		var end := column
		var front := -INF
		var lowest := -INF
		while end < _ground_line.size() and end < column + SLICE_WIDTH and _same_slice(column, end):
			front = maxf(front, _ground_line[end])
			lowest = maxf(lowest, _art_bottom[end])
			end += 1
		var slice := ArtColumns.new()
		slice.prop = self
		slice.from = column - 96
		slice.to = end - 96
		slice.lowest = lowest
		# Whole pixels keep the columns of one facade seamless.
		slice.position = Vector2(-slice.to if mirror else slice.from, roundf(front))
		add_child(slice)
		column = end
	queue_redraw()

func _same_slice(first: int, column: int) -> bool:
	# Columns that touch the floor and overhangs never share a slice, and neither
	# do columns whose painted bottoms are far apart, like an arch's pier and lintel.
	if is_nan(_ground_line[column]):
		return false
	var first_overhangs := _ground_line[first] != _art_bottom[first]
	var overhangs := _ground_line[column] != _art_bottom[column]
	return overhangs == first_overhangs and absf(_art_bottom[column] - _art_bottom[first]) <= 6

func draw_columns(canvas: CanvasItem, from: int, to: int) -> void:
	canvas.draw_set_transform(-canvas.position, 0, Vector2(-1 if mirror else 1, 1))
	Art.draw_prop_columns(canvas, kind, from, to)

func draw_ground(canvas: CanvasItem) -> void:
	var foundations := foundation_polygons()
	for polygon in foundations:
		canvas.draw_colored_polygon(polygon, Color(.015, .025, .03, .28))
	if foundations.is_empty():
		_shadow(canvas, 17 if kind not in ["boat", "stall"] else 45, 7)

func _hides(offset: Vector2) -> bool:
	if _ground_line.is_empty():
		return offset.y < 5 and offset.y > -_height and absf(offset.x) < _width
	# A sliced facade fades only where its art is really drawn over Senu.
	var column := int(roundf(-offset.x if mirror else offset.x)) + 96
	if column < 0 or column >= _ground_line.size() or is_nan(_ground_line[column]):
		return false
	return offset.y < _ground_line[column] and offset.y - ACTOR_HEIGHT < _art_bottom[column] and offset.y > -_height

func _process(delta: float) -> void:
	_time += delta
	_visibility_tick += delta
	if _visibility_tick >= .12:
		_visibility_tick = 0.0
		if not is_instance_valid(_hero):
			_hero = get_tree().get_first_node_in_group("player") as Node2D
		_opacity = 1.0
		if is_instance_valid(_hero):
			if _hides(_hero.global_position - global_position):
				_opacity = .45
	modulate.a = move_toward(modulate.a, _opacity, delta * 5)
	_flame_tick += delta
	if kind == "torch" and _flame_tick >= .1 and (not is_instance_valid(_hero) or global_position.distance_squared_to(_hero.global_position) < 420000.0):
		_flame_tick = 0.0
		queue_redraw()

func _poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _shadow(canvas: CanvasItem, w: float, d: float) -> void:
	# A narrow contact shadow meets the object's feet, on the same pixel grid
	# as the sprites. Large offset circles made small props appear to float.
	var half_width := floorf(w * .8)
	var half_depth := maxf(2, floorf(d * .65))
	canvas.draw_rect(Rect2(-half_width + 3, -half_depth, half_width * 2 - 6, half_depth * 2), Color(.015, .025, .03, .20))
	canvas.draw_rect(Rect2(-half_width, -half_depth + 2, half_width * 2, maxf(2, half_depth * 2 - 4)), Color(.015, .025, .03, .20))

func _box(w: float, d: float, h: float, color: Color, origin: Vector2 = Vector2.ZERO) -> void:
	_poly([origin + Vector2(-w, -h), origin + Vector2(0, d - h), origin + Vector2(0, d), origin + Vector2(-w, 0)], color.darkened(.20))
	_poly([origin + Vector2(0, d - h), origin + Vector2(w, -h), origin + Vector2(w, 0), origin + Vector2(0, d)], color.darkened(.38))
	_poly([origin + Vector2(-w, -h), origin + Vector2(0, -d - h), origin + Vector2(w, -h), origin + Vector2(0, d - h)], color)

func _draw() -> void:
	if not _ground_line.is_empty():
		return
	draw_ground(self)
	draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if mirror else 1, 1))
	if kind == "barrel":
		# The cargo cel includes a wooden barrel; use the native pixel art rather
		# than an unshaded procedural cylinder among the painted objects.
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * .72)
		var drawn := Art.draw_prop(self, "crate", variant)
		draw_set_transform(Vector2.ZERO)
		if drawn:
			return
	if Art.draw_prop(self, kind, variant):
		return
	match kind:
		"pillar":
			_box(12, 6, 5, tint)
			_box(7, 4, 43 + variant * 4, tint.lightened(.06), Vector2(0, -5))
			_box(11, 6, 4, tint.lightened(.19), Vector2(0, -48 - variant * 4))
			draw_line(Vector2(-3, -37), Vector2(-3, -17), tint.darkened(.36), 1)
			draw_line(Vector2(3, -32), Vector2(3, -19), Color("ad9667"), 1)
			_poly([Vector2(-2, -40), Vector2(1, -36), Vector2(-1, -31), Vector2(-4, -35)], Color("c2aa75"))
		"crate":
			_box(13, 7, 18, Color("806343"))
			draw_line(Vector2(-11, -16), Vector2(-1, -3), Color("b69a66"), 2)
			draw_line(Vector2(-1, -12), Vector2(-11, -2), Color("aa8c57"), 1)
			draw_line(Vector2(1, -11), Vector2(11, -17), Color("b49a6d"), 2)
		"barrel":
			_poly([Vector2(-9, -3), Vector2(-11, -15), Vector2(-8, -23), Vector2(8, -23), Vector2(11, -15), Vector2(9, -3), Vector2(0, 1)], Color("7c6349"))
			for x in [-6, -2, 2, 6]:
				draw_line(Vector2(x, -22), Vector2(x, -2), Color("564b3d"), 1)
			draw_line(Vector2(-10, -17), Vector2(10, -17), Color("a6966e"), 2)
			draw_line(Vector2(-10, -7), Vector2(10, -7), Color("a6966e"), 2)
			_poly([Vector2(-8, -23), Vector2(0, -27), Vector2(8, -23), Vector2(0, -19)], Color("99805c"))
		"warehouse":
			_box(61, 29, 64, tint)
			for row in range(5):
				var y := -8.0 - row * 11
				draw_line(Vector2(-60, y - 18), Vector2(0, y + 10), tint.darkened(.4), 1)
				draw_line(Vector2(0, y + 10), Vector2(60, y - 18), tint.darkened(.4), 1)
			for window in [-40, -19]:
				draw_rect(Rect2(window, -42 + window * .46, 8, 14), Color("1a2c32"))
				draw_line(Vector2(window + 4, -41 + window * .46), Vector2(window + 4, -29 + window * .46), Color("b6a16c"), 1)
			_box(64, 31, 5, Color("8b8164"), Vector2(0, -64))
			_box(53, 23, 2, Color("444d4b"), Vector2(0, -71))
			draw_rect(Rect2(12, -42, 17, 33), Color("233438"))
			draw_line(Vector2(20, -40), Vector2(20, -10), Color("736954"), 2)
			_poly([Vector2(36, -55), Vector2(48, -61), Vector2(48, -29), Vector2(42, -23), Vector2(36, -31)], Color("75604f"))
		"arch":
			_box(10, 5, 62, tint, Vector2(-35, -5))
			_box(10, 5, 62, tint, Vector2(35, 5))
			_poly([Vector2(-45, -67), Vector2(-30, -83), Vector2(28, -74), Vector2(45, -57), Vector2(33, -57), Vector2(22, -64), Vector2(-25, -72), Vector2(-35, -62)], tint.lightened(.12))
			for x in range(-28, 30, 12):
				draw_line(Vector2(x, -76 + x * .15), Vector2(x + 2, -66 + x * .15), tint.darkened(.35), 1)
			draw_circle(Vector2(0, -71), 5, Color("c1a164"))
		"stall":
			_box(26, 13, 15, Color("6e5c43"))
			for x in [-24, 23]:
				draw_line(Vector2(x, -1), Vector2(x, -49), Color("b39766"), 2)
			_poly([Vector2(-34, -42), Vector2(-7, -58), Vector2(34, -42), Vector2(8, -26)], tint)
			for line in range(4):
				var x := -28 + line * 14
				draw_line(Vector2(x, -45 + abs(x) * .04), Vector2(x + 15, -29 - abs(x) * .05), tint.lightened(.17), 3)
			for x in range(-18, 23, 8):
				draw_circle(Vector2(x, -15 + abs(x) * .1), 3, Color("b39b64"))
		"palm":
			for section in range(7):
				var x := sin(section * .25) * 8
				draw_line(Vector2(x, -section * 7), Vector2(sin((section + 1) * .25) * 8, -(section + 1) * 7), Color("8b7960"), 5)
			var crown := Vector2(8, -51)
			for leaf in range(7):
				var angle := leaf * TAU / 7.0
				var tip := crown + Vector2(cos(angle) * 34, sin(angle) * 14 - 5)
				_poly([crown, crown.lerp(tip, .55) + Vector2(-4, -6), tip, crown.lerp(tip, .45) + Vector2(5, 1)], Color("435f51").lightened(leaf * .015))
		"boat":
			_poly([Vector2(-67, -9), Vector2(-40, 14), Vector2(37, 18), Vector2(70, -3), Vector2(40, 5), Vector2(-40, 1)], Color("4a4f48"))
			_poly([Vector2(-67, -9), Vector2(-37, -22), Vector2(42, -15), Vector2(70, -3), Vector2(37, 8), Vector2(-40, 1)], Color("806f52"))
			for plank in range(7):
				var x := -42 + plank * 14
				draw_line(Vector2(x, -13), Vector2(x - 3, 3), Color("4b5147"), 1)
			draw_line(Vector2(0, 1), Vector2(0, -88), Color("9f8c65"), 3)
			draw_line(Vector2(-51, -4), Vector2(0, -87), Color("9e9374"), 1)
			draw_line(Vector2(0, -87), Vector2(52, -1), Color("9e9374"), 1)
			_poly([Vector2(3, -80), Vector2(48, -27), Vector2(6, -37)], Color("b0aa8b"))
			draw_line(Vector2(9, -67), Vector2(39, -31), Color("827e68"), 1)
		"statue":
			_box(21, 11, 6, Color("766f56"))
			_box(14, 8, 7, tint, Vector2(0, -6))
			_poly([Vector2(-11, -13), Vector2(-8, -48), Vector2(-3, -59), Vector2(7, -56), Vector2(14, -38), Vector2(10, -13)], tint.lightened(.1))
			_poly([Vector2(-9, -40), Vector2(11, -40), Vector2(17, -30), Vector2(-14, -30)], Color("b7a16b"))
			draw_line(Vector2(0, -53), Vector2(0, -43), Color("3d4c4d"), 2)
			draw_line(Vector2(-5, -28), Vector2(4, -16), Color("b4ac84"), 1)
		"torch":
			_box(5, 3, 22, Color("5d6356"))
			var flicker := sin(_time * 13 + position.x) * 2
			for glow in range(4, 0, -1):
				draw_circle(Vector2(0, -27), 8 + glow * 5, Color(.96, .63, .22, .012))
			_poly([Vector2(-4, -24), Vector2(-3, -32), Vector2(0, -40 + flicker), Vector2(4, -30), Vector2(3, -24)], Color("d6a75b"))
			_poly([Vector2(-2, -24), Vector2(0, -34 + flicker), Vector2(2, -24)], Color("f8d99b"))
		"bollard":
			_box(7, 4, 12, Color("6e7264"))
			draw_arc(Vector2(0, -10), 8, 0, TAU, 16, Color("b6a579"), 2)
			draw_line(Vector2(5, -8), Vector2(28, 3), Color("968867"), 1)
		"reeds":
			for stem in range(7):
				var x := -12 + stem * 4
				draw_line(Vector2(x, 1), Vector2(x + 4, -13 - posmod(stem * 7, 18)), Color("576c53"), 1)
		"wall":
			_box(30, 9, 25 + variant * 4, tint)
			for line in range(3):
				draw_line(Vector2(-29, -line * 8), Vector2(0, 9 - line * 8), tint.darkened(.35), 1)
				draw_line(Vector2(0, 9 - line * 8), Vector2(29, -line * 8), tint.darkened(.35), 1)
			_box(7, 5, 4, tint.lightened(.08), Vector2(-16, -26 - variant * 4))
		_:
			_poly([Vector2(-13, 0), Vector2(-9, -9), Vector2(-1, -13), Vector2(9, -5), Vector2(15, 1), Vector2(0, 6)], tint.darkened(.2))
			_poly([Vector2(-9, -9), Vector2(-1, -13), Vector2(9, -5), Vector2(0, -3)], tint.lightened(.14))
	draw_set_transform(Vector2.ZERO)
