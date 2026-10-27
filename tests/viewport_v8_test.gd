extends SceneTree
## Exercise actual root-window input routing, world coordinates and UI separation.
var world: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.hud.show_overlay("")
	for actor in get_nodes_in_group("enemies"): actor.set_physics_process(false)
	await process_frame
	await process_frame
	var hero: SenuPlayer = world.player
	check(hero.get_viewport() == world.world_view and world.hud.get_viewport() == root, "World and text render in separate viewports")
	check(world.world_view.size == Vector2i(640, 360) and root.get_visible_rect().size == Vector2(1280, 720), "World uses 640x360 while HUD has 1280x720 logical pixels")
	check(world.layout.get_world_2d() == hero.get_world_2d() and world.layout.get_world_2d() != root.find_world_2d(), "Actors and floor share the isolated collision world")
	var centre: Vector2 = world.world_to_ui(hero.global_position)
	var right: Vector2 = world.world_to_ui(hero.global_position + Vector2(45, 0))
	check(centre.distance_to(Vector2(640, 400)) < 3 and right.distance_to(centre + Vector2(90, 0)) < .1, "Interaction coordinates map world pixels to the correct UI location")
	hero.facing = Vector2.UP
	var motion := InputEventMouseMotion.new()
	motion.position = right
	motion.global_position = right
	Input.parse_input_event(motion)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = right
	click.global_position = right
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await process_frame
	check(hero.attack_timer > 0 and hero._attack_direction.dot(Vector2.RIGHT) > .99, "Root-window click reaches Senu and aims right in the low-resolution world")
	check(hero._event_mouse_world == Vector2.INF, "Event-local mouse aim is cleared after handling the click")
	click.pressed = false
	Input.parse_input_event(click)
	await create_timer(.6).timeout
	hero.facing = Vector2.LEFT
	var key := InputEventKey.new()
	key.physical_keycode = KEY_J
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame
	check(hero.attack_timer > 0 and hero._attack_direction.dot(Vector2.LEFT) > .99, "Keyboard attack reaches the world and keeps facing")
	key.pressed = false
	Input.parse_input_event(key)
	var pause := InputEventKey.new()
	pause.physical_keycode = KEY_ESCAPE
	pause.pressed = true
	Input.parse_input_event(pause)
	await process_frame
	check(paused and world.hud.overlay == "pause", "Pause input is handled by the high-resolution HUD")
	pause.pressed = false
	Input.parse_input_event(pause)
	await process_frame
	pause.pressed = true
	Input.parse_input_event(pause)
	await process_frame
	check(not paused and world.hud.overlay == "", "Second pause input resumes the world exactly once")
	pause.pressed = false
	Input.parse_input_event(pause)
	print("VIEWPORT V8 CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	paused = false
	quit(0 if failures.is_empty() else 1)
