extends SceneTree

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
	var stage := Node2D.new()
	root.add_child(stage)
	stage.add_child(PortLayout.new())
	var hero := SenuPlayer.new()
	hero.controls_enabled = false
	hero.position = PortLayout.iso(Vector2(20, 35))
	stage.add_child(hero)
	var catalog := PortLayout.tile_catalog()
	for profile in ["guard", "runner", "lancer", "keeper"]:
		var enemy := VeilEnemy.new()
		enemy.archetype = profile
		enemy.target = hero
		enemy.detection_radius = 1000
		enemy.position = PortLayout.iso(Vector2(14, 35))
		stage.add_child(enemy)
		var windup := false
		var stayed_on_floor := true
		var start := enemy.position
		for tick in range(1500):
			await physics_frame
			if not catalog.has(Vector2i(PortLayout.unproject(enemy.position).round())):
				stayed_on_floor = false
			if enemy.state == VeilEnemy.State.WINDUP:
				windup = true
				break
		check(windup, profile + " navigates around the cistern pool and begins an attack")
		check(stayed_on_floor and enemy.position.distance_to(start) > 80, profile + " advances without walking across the water hole")
		enemy.queue_free()
		await physics_frame
	print("NAVIGATION V6 CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	stage.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
