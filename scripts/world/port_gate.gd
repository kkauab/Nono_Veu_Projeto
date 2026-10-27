extends StaticBody2D
class_name PortGate
const Art = preload("res://scripts/world/port_art.gd")

var end_a := Vector2(-32, -16)
var end_b := Vector2(32, 16)
var opened := false
var bars := 5

# A long gate cannot share one depth with the actors beside it: Senu on the near
# side of its far end was drawn behind the lattice. Each bar is a slice sorted at
# its own point of the line.
class GateSlice extends Node2D:
	var gate: PortGate
	var step := 0

	func _draw() -> void:
		gate.draw_slice(self, step)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	y_sort_enabled = true
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
	bars = maxi(5, ceili(end_a.distance_to(end_b) / 9.0))
	for step in range(bars + 1):
		var slice := GateSlice.new()
		slice.gate = self
		slice.step = step
		slice.position = end_a.lerp(end_b, float(step) / bars).round()
		add_child(slice)

func open() -> void:
	opened = true
	get_node("Barrier").set_deferred("disabled", true)
	for child in get_children():
		if child is GateSlice:
			child.queue_redraw()

func draw_slice(slice: GateSlice, step: int) -> void:
	var bronze := Color("ae8d57")
	var dark := Color("514d3b")
	var from := end_a.lerp(end_b, maxf(0, step - .5) / bars) - slice.position
	var to := end_a.lerp(end_b, minf(bars, step + .5) / bars) - slice.position
	# Stone piers and a bronze lattice share the materials of the nearby ruins.
	slice.draw_line(from + Vector2(0, 2), to + Vector2(0, 2), Color(.015, .03, .035, .3), 6)
	slice.draw_line(from, to, dark, 4)
	if not opened:
		if step > 0 and step < bars:
			slice.draw_line(Vector2.ZERO, Vector2(0, -31), dark, 3)
			slice.draw_line(Vector2(-1, -1), Vector2(-1, -30), bronze, 1)
			slice.draw_colored_polygon(PackedVector2Array([Vector2(0, -36), Vector2(-3, -30), Vector2(3, -30)]), bronze)
		for height in [12, 29]:
			slice.draw_line(from - Vector2(0, height), to - Vector2(0, height), dark, 4)
			slice.draw_line(from - Vector2(0, height + 1), to - Vector2(0, height + 1), bronze, 1)
	if step == 0 or step == bars:
		slice.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * .54)
		if not Art.draw_prop(slice, "pillar"):
			slice.draw_rect(Rect2(-9, -59, 18, 57), Color("69786e"))
			slice.draw_rect(Rect2(-12, -7, 24, 8), Color("849184"))
		slice.draw_set_transform(Vector2.ZERO)
