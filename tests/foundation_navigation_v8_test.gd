extends SceneTree
## A real enemy must reach the opposite side of a solid warehouse foundation.
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	stage.add_child(PortLayout.new())
	var warehouse := PortProp.new()
	warehouse.kind = "warehouse"
	warehouse.solid = true
	warehouse.position = PortLayout.iso(Vector2(33, 2))
	stage.add_child(warehouse)
	var hero := SenuPlayer.new()
	hero.position = warehouse.position + Vector2(80, -20)
	hero.controls_enabled = false
	hero.max_health = 10000
	stage.add_child(hero)
	var enemy := VeilEnemy.new()
	enemy.position = warehouse.position + Vector2(-80, -20)
	enemy.detection_radius = 500
	enemy.target = hero
	stage.add_child(enemy)
	enemy.move_speed = 90
	await physics_frame
	await physics_frame
	var direct := PhysicsRayQueryParameters2D.create(enemy.global_position, hero.global_position, 1)
	check(not enemy.get_world_2d().direct_space_state.intersect_ray(direct).is_empty(), "The fixture has a real warehouse wall between enemy and hero")
	VeilEnemy._ensure_navigation(enemy)
	var graph_id := VeilEnemy._navigation.get_instance_id()
	var path := VeilEnemy._navigation.get_point_path(VeilEnemy._navigation_point(enemy.global_position), VeilEnemy._navigation_point(hero.global_position))
	var path_clear := path.size() > 2
	for i in range(path.size()):
		if warehouse.blocks_ground_point(path[i], 8.5): path_clear = false
		if i > 0:
			for ratio in [.25, .5, .75]:
				if warehouse.blocks_ground_point(path[i - 1].lerp(path[i], ratio), 8.5): path_clear = false
	check(path_clear, "Navigation points and edges skirt the painted solid foundation with foot clearance")
	var crossed_foundation := false
	var reached := false
	var steps := 0
	for step in range(600):
		await physics_frame
		steps = step + 1
		if warehouse.blocks_ground_point(enemy.global_position, 5.5): crossed_foundation = true
		if enemy.global_position.distance_to(hero.global_position) < 48:
			reached = true
			break
	check(reached, "The enemy physically travels around the warehouse and reaches combat distance")
	check(not crossed_foundation, "The enemy never walks through the warehouse foundation")
	check(VeilEnemy._navigation.get_instance_id() == graph_id, "The obstacle-aware graph is reused throughout pursuit")
	print("FOUNDATION NAVIGATION V8 CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures, " physical_steps=", steps)
	quit(0 if failures.is_empty() else 1)
