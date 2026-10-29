extends Node2D
class_name PortInteractable
const Art = preload("res://scripts/world/port_art.gd")
const ResidentArt = preload("res://scripts/world/interior_art.gd")

var item_id := ""
var kind := "nous"
var label := ""
var active := true
var opened := false
var highlighted := false
var perceived := false
var time := 0.0
var puzzle_value := 0
## Look of an "npc": "fisher" or "brother", both drawn from Kauã's fisherman sheet.
var figure := ""
var _draw_tick := 0.0
const FISHERMAN_SHEET := "res://assets/cinematics/rpg_v12/fisherman.png"
static var _fisherman: Texture2D
## Kinds drawn on a painted stand, with the frame and scale `_draw` uses. They are
## solid like the rest of the scenery; pickups, levers, seals and doors stay passable.
const STANDS := {"shrine": ["pillar", .58], "inscription": ["pillar", .44], "memory": ["pillar", .44], "clue": ["pillar", .44], "cache": ["crate", .72], "valve": ["wall", .61], "water_altar": ["wall", .61], "dial": ["pillar", .62], "stars_altar": ["pillar", .62], "boss_lock": ["pillar", .62]}
var _footprint := PackedVector2Array()
var _ground_shade: Array[PackedVector2Array] = []

func _ready() -> void:
	add_to_group("interactables")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_draw_tick = fposmod(position.x * .013 + position.y * .007, .1)
	time = fposmod(absf(position.x * .017 + position.y * .011), 6.0)
	_footprint = footprint()
	if _footprint.is_empty():
		return
	_ground_shade = Geometry2D.offset_polygon(_footprint, 2.0)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	var collider := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = _footprint
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	add_to_group("world_obstacles")

## Ground under the object, behind its pivot like every painted base.
func footprint() -> PackedVector2Array:
	var base := PackedVector2Array()
	match kind:
		"bell":
			# Both feet of the small arch the bell hangs from, as one convex outline.
			base = Geometry2D.convex_hull(PackedVector2Array([Vector2(-27, -21), Vector2(-18, -25), Vector2(25, -7), Vector2(14, -2), Vector2(-18, -17)]))
			base.remove_at(base.size() - 1)
			for index in range(base.size()): base[index] *= .49
		"iri_relic":
			base = PackedVector2Array([Vector2(-13, -2), Vector2(0, -9), Vector2(14, -2), Vector2(0, 5)])
		"iri_mark":
			base = PackedVector2Array([Vector2(-9, 0), Vector2(0, -4), Vector2(9, 0), Vector2(0, 4)])
		"npc":
			base = PackedVector2Array([Vector2(-6, 0), Vector2(0, -3), Vector2(6, 0), Vector2(0, 3)])
		_:
			if STANDS.has(kind):
				base = Art.footprint(STANDS[kind][0])
				for index in range(base.size()): base[index] *= STANDS[kind][1]
	return base

## Same contract as PortProp, for the enemies' navigation graph.
func blocks_ground_point(point: Vector2, clearance: float = 0.0) -> bool:
	if _footprint.is_empty(): return false
	var local := to_local(point)
	if Geometry2D.is_point_in_polygon(local, _footprint): return true
	for edge in range(_footprint.size()):
		if local.distance_to(Geometry2D.get_closest_point_to_segment(local, _footprint[edge], _footprint[(edge + 1) % _footprint.size()])) < clearance: return true
	return false

func _process(delta: float) -> void:
	time += delta
	_draw_tick += delta
	if _draw_tick >= .1:
		_draw_tick = 0.0
		queue_redraw()

func _base(kind_name: String, scale: float) -> bool:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale)
	var drawn := Art.draw_prop(self, kind_name)
	draw_set_transform(Vector2.ZERO)
	return drawn

func _contact_shadow(width: float) -> void:
	draw_rect(Rect2(-width + 3, -3, width * 2 - 6, 6), Color(.01, .025, .03, .24))
	draw_rect(Rect2(-width, -1, width * 2, 2), Color(.01, .025, .03, .24))

func _draw() -> void:
	if not active and kind not in ["cache", "bell", "valve", "water_altar", "dial", "stars_altar", "boss_lock", "iri_relic"]:
		return
	var gold := Color("dcc28c")
	var teal := Color("8ac5b2")
	if opened and kind in ["bell", "valve", "water_altar", "dial", "stars_altar", "boss_lock", "iri_mark"]:
		gold = teal
	var bob := roundf(sin(time * 2.4) * 2.0)
	if _ground_shade.is_empty():
		_contact_shadow({"nous": 5, "npc": 8}.get(kind, 12))
	for polygon in _ground_shade:
		draw_colored_polygon(polygon, Color(.01, .025, .03, .24))
	if perceived:
		# Percepção marca o objeto, sem resolver ou abrir o segredo.
		var gleam := Color("e8cd91")
		gleam.a = .65 + .2 * sin(time * 2.0)
		var center := Vector2(0, -42 + bob)
		var eye := PackedVector2Array([center + Vector2(-6, 0), center + Vector2(0, -3), center + Vector2(6, 0), center + Vector2(0, 3), center + Vector2(-6, 0)])
		draw_polyline(eye, gleam, 1.0)
		draw_rect(Rect2(center - Vector2.ONE, Vector2.ONE * 2), gleam)
	if highlighted:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 23, 0, TAU, 24, gold, 1)
		draw_set_transform(Vector2.ZERO)
	match kind:
		"quest_object":
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * .7)
			ResidentArt.draw(self, "amphora" if figure == "merit" else ("chest_closed" if figure == "nakht" else "easel"))
			draw_set_transform(Vector2.ZERO)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -34 + bob), Vector2(3, -30 + bob), Vector2(0, -26 + bob), Vector2(-3, -30 + bob)]), gold)
		"fisher_bell":
			draw_line(Vector2(-7, 0), Vector2(-7, -35), Color("674d34"), 3)
			draw_line(Vector2(-9, -35), Vector2(9, -35), Color("a27d50"), 3)
			draw_line(Vector2(4, -35), Vector2(4, -30), gold, 1)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -30), Vector2(8, -30), Vector2(11, -19), Vector2(-3, -19)]), Color("c39e65"))
			draw_line(Vector2(-3, -19), Vector2(11, -19), gold, 2)
			draw_line(Vector2(4, -18), Vector2(4, -7), Color("dbcfaa"), 1)
			draw_rect(Rect2(3, -7, 3, 3), teal if opened else gold)
		"shrine":
			if not _base("pillar", .58):
				draw_rect(Rect2(-8, -27, 16, 25), Color("69786f"))
			draw_line(Vector2(0, -26), Vector2(0, -14), gold, 1)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -49 + bob), Vector2(4, -43 + bob), Vector2(0, -37 + bob), Vector2(-4, -43 + bob)]), teal)
			draw_line(Vector2(0, -46 + bob), Vector2(0, -41 + bob), Color("d0e1c6"), 1)
		"nous":
			draw_circle(Vector2(0, -10 + bob), 13, Color(.65, .55, .9, .06))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -21 + bob), Vector2(6, -11 + bob), Vector2(0, -3 + bob), Vector2(-6, -11 + bob)]), Color("c5b6e0"))
			draw_line(Vector2(0, -18 + bob), Vector2(0, -7 + bob), Color("f3e7ff"), 1)
		"daggers":
			draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(0, -7), Vector2(13, 0), Vector2(0, 7)]), Color("665b51"))
			draw_line(Vector2(-7, -4), Vector2(5, -16), teal, 3)
			draw_line(Vector2(6, -4), Vector2(-5, -16), gold, 3)
		"lever":
			draw_rect(Rect2(-9, -5, 18, 9), Color("7e7461"))
			draw_line(Vector2.ZERO, Vector2(-8, -21), gold, 3)
			draw_circle(Vector2(-8, -21), 3, teal)
		"inscription", "memory", "clue":
			if not _base("pillar", .44):
				draw_colored_polygon(PackedVector2Array([Vector2(-11, 1), Vector2(-11, -22), Vector2(8, -27), Vector2(12, -20), Vector2(12, 1)]), Color("6f8078"))
			draw_rect(Rect2(-5, -24, 10, 15), Color("243f40"))
			for row in range(3):
				draw_line(Vector2(-3, -21 + row * 4), Vector2(3 - row, -21 + row * 4), gold, 1)
		"cache":
			if not _base("crate", .72):
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -2), Vector2(0, 5), Vector2(14, -2), Vector2(14, -15), Vector2(0, -8), Vector2(-13, -15)]), Color("6a6854"))
			if opened:
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -15), Vector2(-12, -27), Vector2(13, -26), Vector2(14, -15)]), Color("7c826c"))
			else:
				draw_line(Vector2(0, -17), Vector2(0, 3), gold, 2)
				draw_circle(Vector2(0, -7), 3, teal)
		"gate":
			draw_circle(Vector2(0, -17), 7, Color("a494bb"))
			draw_line(Vector2(-4, -17), Vector2(4, -17), Color("e3c68b"), 2)
		"bell":
			if not _base("arch", .49):
				draw_line(Vector2(-13, 0), Vector2(-13, -39), Color("81745e"), 4)
				draw_line(Vector2(13, 0), Vector2(13, -39), Color("81745e"), 4)
				draw_line(Vector2(-15, -39), Vector2(15, -39), gold, 3)
			draw_line(Vector2(0, -37), Vector2(0, -31), Color("6f5438"), 2)
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -32), Vector2(7, -32), Vector2(10, -15), Vector2(-10, -15)]), Color("aa8955") if not opened else teal)
			draw_line(Vector2(-6, -30), Vector2(-8, -18), Color("d0b278"), 2)
			draw_line(Vector2(-10, -15), Vector2(10, -15), Color("72583b"), 2)
			draw_circle(Vector2(0, -14), 3, gold)
			if item_id == "bell_sun":
				draw_circle(Vector2(0, -25), 3, Color("fff0ba"))
			elif item_id == "bell_moon":
				draw_arc(Vector2(1, -25), 4, .7, 5.5, 12, Color("e2dac2"), 1)
			else:
				draw_line(Vector2(-3, -28), Vector2(3, -22), gold)
				draw_line(Vector2(-3, -22), Vector2(3, -28), gold)
		"valve", "water_altar":
			if not _base("wall", .61):
				draw_rect(Rect2(-9, -25, 18, 23), Color("536c66"))
			draw_rect(Rect2(-5, -22, 10, 18), Color("253c3c"))
			for mark in range(6):
				draw_rect(Rect2(-5, -5 - mark * 3, 10, 2), teal if mark < puzzle_value else Color("364a48"))
			if kind == "valve":
				draw_arc(Vector2(0, -29), 8, 0, TAU, 20, gold, 2)
				draw_line(Vector2(-8, -29), Vector2(8, -29), gold, 1)
				draw_line(Vector2(0, -37), Vector2(0, -21), gold, 1)
			else:
				draw_arc(Vector2(0, -26), 12, PI, TAU, 20, gold, 2)
		"dial", "stars_altar", "boss_lock":
			if not _base("pillar", .62):
				draw_colored_polygon(PackedVector2Array([Vector2(-8, -4), Vector2(-7, -30), Vector2(0, -40), Vector2(8, -30), Vector2(8, -4)]), Color("6f8078"))
			if kind == "dial":
				var direction := Vector2.UP.rotated(float(puzzle_value) * PI / 2)
				draw_circle(Vector2(0, -23), 6, Color("354e50"))
				draw_line(Vector2(0, -23), Vector2(0, -23) + direction * 6, gold, 2)
			else:
				draw_arc(Vector2(0, -23), 6, 0, TAU, 20, gold, 1)
				draw_line(Vector2(0, -32), Vector2(0, -14), gold, 1)
		"npc":
			_draw_figure()
		"iri_mark":
			# A low stele with Hermes' sign: circle, staff and two wings.
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 1), Vector2(-9, -18), Vector2(-5, -24), Vector2(5, -24), Vector2(9, -18), Vector2(9, 1)]), Color("66766f"))
			draw_colored_polygon(PackedVector2Array([Vector2(1, 1), Vector2(1, -24), Vector2(5, -24), Vector2(9, -18), Vector2(9, 1)]), Color("55635d"))
			if not opened:
				draw_circle(Vector2(0, -14), 9 + bob * .5, Color(.86, .76, .55, .08))
			draw_arc(Vector2(0, -18), 2.5, 0, TAU, 10, gold, 1)
			draw_line(Vector2(0, -15), Vector2(0, -5), gold, 1)
			draw_line(Vector2(-5, -13), Vector2(-1, -11), gold, 1)
			draw_line(Vector2(5, -13), Vector2(1, -11), gold, 1)
		"iri_relic":
			# Iri's cedar box: one socket lights for each mark found on the trail.
			draw_colored_polygon(PackedVector2Array([Vector2(-13, -2), Vector2(0, 5), Vector2(14, -2), Vector2(14, -13), Vector2(0, -6), Vector2(-13, -13)]), Color("6d5a44"))
			draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(14, -2), Vector2(14, -13), Vector2(0, -6)]), Color("5a4a38"))
			if opened:
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -13), Vector2(-12, -25), Vector2(1, -19), Vector2(0, -6)]), Color("8a7155"))
				draw_line(Vector2(-6, -12), Vector2(5, -10), teal, 1)
			else:
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -13), Vector2(0, -20), Vector2(14, -13), Vector2(0, -6)]), Color("8a7155"))
				draw_arc(Vector2(0, -13), 2.5, 0, TAU, 10, gold, 1)
				for socket in range(4):
					var spot := Vector2(0, -13) + Vector2(7, 0).rotated(socket * PI / 2) * Vector2(1, .5)
					draw_circle(spot, 1.5, teal if socket < puzzle_value else Color("3b3a33"))

func _draw_figure() -> void:
	if ResidentArt.draw(self, "sabu" if figure == "brother" else "hori", time):
		return
	if _fisherman == null and ResourceLoader.exists(FISHERMAN_SHEET):
		_fisherman = load(FISHERMAN_SHEET) as Texture2D
	# Sheet poses: 0 idle, 5 talk, 6 listen. Sabu repeats the knot gesture until
	# he remembers; a faded tint marks the forgotten.
	var frame := 5 if highlighted else (6 if fmod(time, 3.2) > 2.4 else 0)
	var tint := Color.WHITE
	if figure == "brother":
		frame = 5 if fmod(time, 1.4) < .7 else 6
		tint = Color.WHITE if opened else Color("a9b3bd")
	if _fisherman == null:
		draw_rect(Rect2(-6, -38, 12, 38), Color("7d6a52") * tint)
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if figure == "brother" else 1, 1))
	draw_texture_rect_region(_fisherman, Rect2(-64, -112, 128, 128), Rect2(frame % 4 * 128, frame / 4 * 128, 128, 128), tint)
	draw_set_transform(Vector2.ZERO)
