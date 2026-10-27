extends SceneTree
const Dressing = preload("res://scripts/world/port_dressing.gd")
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
	root.add_child(stage)
	stage.add_child(PortLayout.new())
	Dressing.populate(stage)
	await physics_frame
	var catalog := PortLayout.tile_catalog()
	var architecture := 0
	for node in stage.get_children():
		if not node is PortProp: continue
		var polygons: Array[PackedVector2Array] = node.foundation_polygons()
		if polygons.is_empty(): continue
		architecture += 1
		var supported := true
		for polygon in polygons:
			for index in range(polygon.size()):
				for point in [polygon[index], polygon[index].lerp(polygon[(index + 1) % polygon.size()], .5)]:
					var tile := Vector2i(PortLayout.unproject(node.to_global(point)).round())
					if not catalog.has(tile): supported = false
		check(supported, "%s at %s has real floor beneath every foundation edge" % [node.kind, PortLayout.unproject(node.position)])
		var collisions := node.find_children("*", "CollisionShape2D", true, false)
		check(collisions.size() == polygons.size(), "%s uses its full painted ground footprint" % node.kind)
		if node.kind == "arch":
			var opening: Vector2 = node.position + Vector2(-2 if not node.mirror else 2, -13)
			check(not node.blocks_ground_point(opening, 6), "Arch opening has clearance for Senu")
	check(architecture >= 20, "All district and legacy architecture was checked")
	print("SCENE SUPPORT V8 CHECKS: %d passed=%d failures=%s architecture=%d" % [checks, checks - failures.size(), failures, architecture])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
