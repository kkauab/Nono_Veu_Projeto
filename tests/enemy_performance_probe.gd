extends SceneTree
## Microbenchmark reproduzível; não altera o save nem mede o desenho do cenário.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node2D.new()
	root.add_child(stage)
	var hero := SenuPlayer.new()
	hero.controls_enabled = false
	hero.position = PortLayout.iso(Vector2(20, 35))
	stage.add_child(hero)
	hero.set_physics_process(false)
	var enemy := VeilEnemy.new()
	enemy.target = hero
	enemy.position = PortLayout.iso(Vector2(14, 35))
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	await process_frame
	var started := Time.get_ticks_usec()
	enemy._route_direction()
	var build_us := Time.get_ticks_usec() - started
	var samples: Array[int] = []
	for i in range(1000):
		enemy._path_refresh = 0
		started = Time.get_ticks_usec()
		enemy._route_direction()
		samples.append(Time.get_ticks_usec() - started)
	samples.sort()
	print("ENEMY PERF route_1000 median_us=%d p95_us=%d max_us=%d first_build_us=%d" % [samples[500], samples[950], samples.back(), build_us])
	var body = load("res://scripts/actors/senu_supplied_view.gd").new()
	body.sample(hero)
	print("SPRITE CACHE shared_v6=%s legacy_v4=%s legacy_motion_v5=%s texture_bytes=%.0f" % [ResourceLoader.has_cached("res://assets/sprites/senu_shared_v6.png"), ResourceLoader.has_cached("res://assets/sprites/senu_v4.png"), ResourceLoader.has_cached("res://assets/sprites/senu_motion_v5.png"), Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)])
	stage.queue_free()
	await process_frame
	quit()
