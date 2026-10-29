extends SceneTree
## Real-world render/collision/combat capture; main creates only a user://qa slot.
const Main = preload("res://scenes/boot/main.tscn")
const OUT := "res://qa/actor_motion"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 30
	var world = Main.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var victim: VeilEnemy
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.enemy_id == "marinheiro_01": victim = enemy
	if victim == null:
		push_error("QA capture expected marinheiro_01")
		quit(1)
		return
	victim.target = world.player
	victim.detection_radius = 0 # Keep AI idle while physics and recoil remain live.
	victim.set_physics_process(true)
	world.player.position = victim.position - Vector2(30, 0)
	world.player.facing = Vector2.RIGHT
	world.player.controls_enabled = false
	var camera: Camera2D = world.player.get_node("IsometricCamera")
	camera.reset_smoothing()
	camera.force_update_scroll()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for frame in range(240):
		if frame == 30 or frame == 65:
			world.player.controls_enabled = true
			world.player.try_attack(frame == 65)
			world.player.controls_enabled = false
		if frame == 115:
			victim.set_physics_process(true)
			victim.target = world.player
			victim.detection_radius = 155
			victim.state = VeilEnemy.State.CHASE
		if frame == 200:
			victim.set_physics_process(false)
			world.player.controls_enabled = true
			Input.action_press("move_left")
		if frame == 220: Input.action_press("sprint")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "/world_%03d.png" % frame)
	Input.action_release("move_left")
	Input.action_release("sprint")
	print("ACTOR MOTION WORLD PREVIEW: 240 frames; slot=", "user://qa/", "; actual attacks, hurt, ground travel and depth")
	world.queue_free()
	await process_frame
	quit()


