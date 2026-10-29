extends SceneTree

class ObservedEnemy extends VeilEnemy:
	var draw_count := 0
	func _draw() -> void:
		draw_count += 1
		super._draw()

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	VeilEnemy._ensure_navigation()
	var lookup_matches := true
	var offsets := [Vector2.ZERO, Vector2(.49, .49), Vector2(-.49, -.49), Vector2(.49, -.49), Vector2(-.49, .49)]
	for tile in PortLayout.tile_catalog():
		for offset in offsets:
			var point := PortLayout.iso(Vector2(tile) + offset)
			var local_id := VeilEnemy._navigation_point(point)
			var reference_id := VeilEnemy._navigation.get_closest_point(point)
			var local_distance := point.distance_squared_to(VeilEnemy._navigation.get_point_position(local_id))
			var reference_distance := point.distance_squared_to(VeilEnemy._navigation.get_point_position(reference_id))
			if not is_equal_approx(local_distance, reference_distance):
				lookup_matches = false
	check(lookup_matches, "Local navigation preserves closest graph distance over all floor tiles and near their corners")
	var off_map := Vector2(12000, -12000)
	check(VeilEnemy._navigation_point(off_map) == VeilEnemy._navigation.get_closest_point(off_map), "Off-map navigation retains global fallback")
	var stage := Node2D.new()
	root.add_child(stage)
	var hero := SenuPlayer.new()
	hero.controls_enabled = false
	hero.position = Vector2(5000, 5000)
	stage.add_child(hero)
	hero.set_physics_process(false)
	var enemy := ObservedEnemy.new()
	enemy.target = hero
	stage.add_child(enemy)
	await process_frame
	await process_frame
	var first_draws := enemy.draw_count
	for i in range(12):
		await physics_frame
		await process_frame
	check(enemy.draw_count - first_draws <= 2, "Idle enemies retain their cached drawing between the sparse one-pixel breath transitions")
	# Simulate a complete breath independently of monitor/physics frequency.
	# Rendering every sample proves the cache is invalidated when needed,
	# while catching a regression to rebuilding every resting enemy each tick.
	enemy.set_physics_process(false)
	enemy._time = -enemy._breath_phase
	enemy._breath_pixel = 0.0
	enemy.queue_redraw()
	await process_frame
	await process_frame
	var breath_draws := enemy.draw_count
	for frame in range(240):
		enemy._physics_process(4.0 / 240.0)
		await process_frame
	await process_frame
	await process_frame
	var breath_changes := enemy.draw_count - breath_draws
	check(breath_changes >= 2 and breath_changes <= 4, "A complete four-second resting breath redraws only its two or three pixel transitions")
	enemy.set_physics_process(true)
	hero.position = Vector2(20, 0)
	await physics_frame
	await process_frame
	check(enemy.state != VeilEnemy.State.WAIT, "A cached idle enemy still wakes immediately when Senu approaches")
	enemy.receive_hit(1, hero.position)
	await process_frame
	await process_frame
	check(enemy.draw_count > first_draws, "Combat and damage still redraw the enemy")
	enemy.reset_enemy()
	check(enemy._path.is_empty() and enemy._path_refresh == 0, "Reset removes the previous chase path")
	print("ENEMY PERFORMANCE V7 CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
