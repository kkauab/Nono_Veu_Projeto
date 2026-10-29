extends SceneTree

const Story = preload("res://scripts/world/port_story.gd")
const Houses = preload("res://scripts/world/houses.gd")
var world: Node2D

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	for foe in get_nodes_in_group("enemies"): foe.queue_free()
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = resolution
		await process_frame
		world.hud.show_overlay("")
		var hori := _item("npc_fisher")
		world.player.position = hori.position + Vector2(-36, 35)
		var camera: Camera2D = world.player.get_node("IsometricCamera")
		camera.reset_smoothing()
		await physics_frame
		await process_frame
		world.hud.show_conversation("O pescador do cais", "PESCADOR — Você voltou. Achou seu mestre?\n\nSENU — Ainda não. Mas sigo o rastro dele.", "npc_fisher")
		await _capture("speech_hori_%d.png" % resolution.x)
		world.hud.get_node("NpcSpeechBubble").advance()
		await _capture("speech_senu_%d.png" % resolution.x)
		world.hud.show_overlay("")
		Houses._arrive(world, "emporio_merit", true)
		camera.force_update_scroll()
		for frame in range(4): await physics_frame
		world.talk_to_resident("merit")
		await _capture("speech_merit_%d.png" % resolution.x)
		world.hud.show_overlay("")
		Houses._arrive(world, "emporio_merit", false)
	world.queue_free()
	await process_frame
	quit()

func _capture(filename: String) -> void:
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/" + filename)
	print("Speech preview: qa/" + filename)

func _item(id: String) -> Node2D:
	for actor in get_nodes_in_group("interactables"):
		if actor.item_id == id: return actor
	return null
