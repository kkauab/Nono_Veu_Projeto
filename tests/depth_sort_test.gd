extends SceneTree
# Senu must be drawn in front of gates and wide facades whenever he stands on their
# near side, and behind them on the far side. Both are split into depth slices.

const Dressing = preload("res://scripts/world/port_dressing.gd")
## Half of Senu's sprite and the distance his 6 px body keeps from any barrier.
const SENU_HALF_WIDTH := 7.0
const CLEARANCE := 6.5
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var stage := Node2D.new()
	stage.y_sort_enabled = true
	root.add_child(stage)
	Dressing.populate(stage)
	for id in PortLayout.GATES:
		var a := PortLayout.iso(PortLayout.GATES[id]["a"])
		var b := PortLayout.iso(PortLayout.GATES[id]["b"])
		var gate := PortGate.new()
		gate.name = "Gate_%s" % id
		gate.position = (a + b) * .5
		gate.end_a = a - gate.position
		gate.end_b = b - gate.position
		stage.add_child(gate)
	await process_frame
	var facades := 0
	for node in stage.get_children():
		if node is PortGate:
			_check_gate(node)
		elif node is PortProp and node.kind in PortProp.SLICED:
			facades += 1
			_check_facade(node)
	check(facades >= 25, "Every warehouse, temple, arch, stall and the lighthouse were checked (%d)" % facades)
	print("DEPTH SORT CHECKS: %d passed=%d failures=%s facades=%d" % [checks, checks - failures.size(), failures, facades])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

## Slices overlapping Senu's sprite, as [slice, left, right, lowest painted y] in
## world coordinates. A lintel above his head does not overlap him.
func _overlapping(actor: Vector2, spans: Array) -> Array:
	return spans.filter(func(span): return span[2] > actor.x - SENU_HALF_WIDTH and span[1] < actor.x + SENU_HALF_WIDTH and span[3] > actor.y - PortProp.ACTOR_HEIGHT)

func _drawn_over(actor: Vector2, spans: Array) -> Array:
	return _overlapping(actor, spans).filter(func(span): return span[0].global_position.y > actor.y)

func _check_gate(gate: PortGate) -> void:
	var spans := []
	for child in gate.get_children():
		if child is PortGate.GateSlice:
			# Bars and rails reach half a bar to each side; the end piers are wider.
			var reach := 8.0 if child.step in [0, gate.bars] else 5.0
			spans.append([child, child.global_position.x - reach, child.global_position.x + reach, child.global_position.y + 5])
	check(spans.size() == gate.bars + 1, "%s is cut into one slice per bar" % gate.name)
	var a := gate.to_global(gate.end_a)
	var b := gate.to_global(gate.end_b)
	var normal := (b - a).orthogonal().normalized()
	if normal.y < 0:
		normal = -normal
	var near_ok := true
	var far_ok := true
	for step in range(1, 10):
		var point := a.lerp(b, step / 10.0)
		if not _drawn_over(point + normal * CLEARANCE, spans).is_empty():
			near_ok = false
		var far := point - normal * CLEARANCE
		if _overlapping(far, spans).size() != _drawn_over(far, spans).size():
			far_ok = false
	check(near_ok, "Senu on the near side of %s is drawn in front of every bar" % gate.name)
	check(far_ok, "Senu on the far side of %s stays behind the lattice" % gate.name)

func _check_facade(prop: PortProp) -> void:
	var where := "%s at %s" % [prop.kind, PortLayout.unproject(prop.position)]
	var spans := []
	for child in prop.get_children():
		if child is PortProp.ArtColumns:
			var edges := [child.from, child.to] if not prop.mirror else [-child.to, -child.from]
			spans.append([child, prop.global_position.x + edges[0], prop.global_position.x + edges[1], prop.global_position.y + child.lowest])
	check(not spans.is_empty(), "%s is cut into depth columns" % where)
	var in_front := true
	var faded := false
	for polygon in prop.foundation_polygons():
		var center := Vector2.ZERO
		for point in polygon:
			center += point / polygon.size()
		for index in polygon.size():
			var a: Vector2 = polygon[index]
			var b: Vector2 = polygon[(index + 1) % polygon.size()]
			var normal := (b - a).orthogonal().normalized()
			if normal.dot((a + b) * .5 - center) < 0:
				normal = -normal
			# Only faces turned to the camera can have Senu standing in front of them.
			if normal.y <= 0:
				continue
			for step in range(1, 4):
				var actor := prop.to_global(a.lerp(b, step / 4.0) + normal * CLEARANCE)
				if not _drawn_over(actor, spans).is_empty():
					in_front = false
					print("DEPTH_COVERED %s actor=%s" % [where, PortLayout.unproject(actor)])
				if prop._hides(actor - prop.global_position):
					faded = true
	check(in_front, "Senu against the front of %s is drawn in front of it" % where)
	check(not faded, "%s does not fade while Senu stands in front of it" % where)
	if prop.kind == "arch":
		var opening: Vector2 = prop.global_position + Vector2(2 if prop.mirror else -2, -13)
		check(_drawn_over(opening + Vector2(0, 10), spans).is_empty(), "Senu in front of the opening of %s is not covered by the lintel" % where)
		check(not _drawn_over(opening - Vector2(0, 10), spans).is_empty(), "Senu beyond the opening of %s passes behind the arch" % where)
