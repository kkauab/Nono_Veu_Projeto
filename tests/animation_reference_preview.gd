extends SceneTree
## Records the real combat/death/loot pipeline; never grants fabricated drops.
const Main = preload("res://scenes/boot/main.tscn")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	Engine.max_fps = 20
	var world = Main.instantiate()
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	var victim: VeilEnemy
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		if enemy.enemy_id == "marinheiro_01": victim = enemy
	victim.health = 1
	world.player.position = victim.position - Vector2(31, 0)
	world.player.facing = Vector2.RIGHT
	world.player.controls_enabled = false
	world.player.get_node("IsometricCamera").reset_smoothing()
	world.player.get_node("IsometricCamera").force_update_scroll()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/animation_reference"))
	for frame in range(64):
		if frame == 6:
			victim.set_physics_process(true)
			victim.target = null
			world.player.controls_enabled = true
			world.player.try_attack()
			world.player.controls_enabled = false
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://qa/animation_reference/frame_%03d.png" % frame)
	print("ANIMATION_REFERENCE recorded=64 source=real_combat_and_loot")
	quit()
