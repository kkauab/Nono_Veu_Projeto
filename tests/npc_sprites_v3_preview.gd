extends SceneTree
## Graphical QA capture of actual residents on their real map, with no journey slot.
## Run with: --script res://tests/npc_sprites_v3_preview.gd -- --qa
const Main = preload("res://scenes/boot/main.tscn")
const People = preload("res://scripts/world/townsfolk.gd")
const NpcArt = preload("res://scripts/world/npc_art.gd")
const OUT := "res://qa/npcs_v3"
var world: Node2D
var qa_path := ""
var camera: Camera2D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		push_error("NPC v3 preview needs graphical Godot and -- --qa")
		quit(1)
		return
	if not People.SHEET.ends_with("townsfolk_v3.png") or not NpcArt.TEXTURE.ends_with("ankhet_v3.png"):
		push_error("NPC v3 preview requires both new atlases to be integrated")
		quit(1)
		return
	create_timer(90.0, true, false, true).timeout.connect(func(): quit(2))
	Engine.max_fps = 30
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	world = Main.instantiate()
	root.add_child(world)
	await process_frame
	qa_path = "user://qa/npc_sprites_v3_%d_%d/world.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_path.get_base_dir()))
	world.store.path = qa_path
	world.hud.show_overlay("")
	world.hud.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.nearest = null
	for foe in get_nodes_in_group("enemies"):
		foe.queue_free()
	world.player.controls_enabled = false
	camera = world.player.get_node("IsometricCamera")
	camera.position_smoothing_enabled = false
	await process_frame
	for sample in [
		["market", "aguadeira_mercado", Vector2(30,34), 1.0],
		["market_close", "peixeira", Vector2(26,32), 1.6],
		["cais", "marinheiro_cais", Vector2(28,34), 1.0],
		["cais_close", "pescador_cais", Vector2(26,34), 1.6],
		["ankhet", "isle_ankhet", Vector2(34,34), 1.0],
		["ankhet_close", "isle_ankhet", Vector2(28,32), 1.6],
	]:
		var actor := _item(sample[1])
		if actor == null:
			push_error("Missing preview actor: " + str(sample[1]))
			quit(1)
			return
		world.player.position = actor.position + sample[2]
		camera.zoom = Vector2.ONE * float(sample[3])
		camera.reset_smoothing()
		camera.force_update_scroll()
		for person in get_nodes_in_group("townsfolk"):
			person.time = 0.0
			person.highlighted = false
			person.queue_redraw()
		actor.time = 0.0
		actor.highlighted = false
		actor.queue_redraw()
		world.player.queue_redraw()
		await _capture(str(sample[0]) + ".png")
	if FileAccess.file_exists(qa_path):
		push_error("Visual preview unexpectedly wrote a journey slot")
		quit(1)
		return
	print("NPC V3 PREVIEW: six real-map captures; QA-only slot unused; no journey saved")
	world.queue_free()
	await process_frame
	quit()

func _item(id: String) -> Node2D:
	for actor in get_nodes_in_group("interactables"):
		if actor.item_id == id:
			return actor
	return null

func _capture(filename: String) -> void:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(OUT + "/" + filename)
	if error != OK:
		push_error("Cannot save NPC v3 capture: " + filename)
		quit(1)
	print("NPC V3 CAPTURE: " + OUT + "/" + filename)
