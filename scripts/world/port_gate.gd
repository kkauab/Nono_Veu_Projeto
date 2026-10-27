extends StaticBody2D
class_name PortGate
const Art = preload("res://scripts/world/port_art.gd")

var end_a := Vector2(-32, -16)
var end_b := Vector2(32, 16)
var opened := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 1
	collision_mask = 6
	var shape := SegmentShape2D.new()
	shape.a = end_a
	shape.b = end_b
	var collider := CollisionShape2D.new()
	collider.name = "Barrier"
	collider.shape = shape
	add_child(collider)
	if opened:
		collider.set_deferred("disabled", true)

func open() -> void:
	opened = true
	get_node("Barrier").set_deferred("disabled", true)
	queue_redraw()

func _draw() -> void:
	var bronze := Color("ae8d57")
	var dark := Color("514d3b")
	# Stone piers and a bronze lattice share the materials of the nearby ruins.
	draw_line(end_a + Vector2(0, 2), end_b + Vector2(0, 2), Color(.015, .03, .035, .3), 6)
	draw_line(end_a, end_b, dark, 4)
	if not opened:
		var bars := maxi(5, ceili(end_a.distance_to(end_b) / 9.0))
		for step in range(1, bars):
			var p := end_a.lerp(end_b, float(step) / bars).round()
			draw_line(p, p - Vector2(0, 31), dark, 3)
			draw_line(p - Vector2(1, 1), p - Vector2(1, 30), bronze, 1)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -36), p + Vector2(-3, -30), p + Vector2(3, -30)]), bronze)
		for height in [12, 29]:
			draw_line(end_a - Vector2(0, height), end_b - Vector2(0, height), dark, 4)
			draw_line(end_a - Vector2(0, height + 1), end_b - Vector2(0, height + 1), bronze, 1)
	for end in [end_a, end_b]:
		draw_set_transform(end.round(), 0, Vector2.ONE * .54)
		if not Art.draw_prop(self, "pillar"):
			draw_rect(Rect2(-9, -59, 18, 57), Color("69786e"))
			draw_rect(Rect2(-12, -7, 24, 8), Color("849184"))
		draw_set_transform(Vector2.ZERO)
