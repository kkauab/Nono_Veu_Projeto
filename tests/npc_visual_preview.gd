extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
const Houses = preload("res://scripts/world/houses.gd")
const Story = preload("res://scripts/world/port_story.gd")
var world
func _init() -> void: _run.call_deferred()
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	for id in ["casa_guarda", "emporio_merit", "forja_nakht", "tenda_adiam"]:
		Houses._arrive(world, id, true)
		world.nearest = null
		world.player.get_node("IsometricCamera").force_update_scroll()
		await _capture("npc_v2_" + id)
	Houses._arrive(world, "tenda_adiam", false)
	for id in ["fisher_met", "fisher_brother_found", "fisher_knot", "fisher_named", "fisher_done"]:
		world.store.collect(id, 0)
	Story._move_brother_home(world)
	Story.refresh(world)
	world.player.position = PortLayout.iso(Vector2(13, 1.4)) + Vector2(0, 37)
	world.current_room = PortLayout.room_at(world.player.position)
	world.player.get_node("IsometricCamera").reset_smoothing()
	world.player.get_node("IsometricCamera").force_update_scroll()
	await _capture("npc_v2_irmaos")
	for id in ["merit", "nakht", "adiam", "tarek"]: world.talk_to_resident(id)
	world.hud.show_overlay("")
	world.hud.show_overlay("journal")
	await _capture("npc_v2_missoes")
	world.hud.show_overlay("")
	quit()
func _capture(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/" + id + ".png")
	print("CAPTURE ", id)
