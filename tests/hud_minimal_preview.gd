extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
const Houses = preload("res://scripts/world/houses.gd")
const Quests = preload("res://scripts/world/port_quests.gd")
var world

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	world.hud._process(.01)
	Houses._arrive(world, "emporio_merit", true)
	world.nearest = null
	world.player.get_node("IsometricCamera").force_update_scroll()
	await _capture("hud_minimal_v7_interior")
	Houses._arrive(world, "emporio_merit", false)
	world.player.position = PortLayout.iso(Vector2(2, 3))
	world.player.health = 61
	world.player.get_node("IsometricCamera").reset_smoothing()
	world.player.get_node("IsometricCamera").force_update_scroll()
	await _capture("hud_minimal_v7_porto")
	for id in ["merit", "nakht", "adiam", "tarek"]:
		var accepted: String = "quest_started_" + id
		if not accepted in world.store.data["collected"]: world.store.data["collected"].append(accepted)
	world.store.data["collected"].append("fisher_met")
	world.hud._selected_quest = "merit"
	world.hud.show_overlay("journal")
	await _capture("quest_journal_v1_merit")
	root.size = Vector2i(960, 540)
	await process_frame
	world.hud._geometry()
	world.hud._build_controls()
	await _capture("quest_journal_v1_960")
	world.hud.show_overlay("")
	quit()

func _capture(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/" + id + ".png")
	print("CAPTURE ", id)
