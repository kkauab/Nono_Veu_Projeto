extends SceneTree
## Actual world routes and renderers, captured into QA frames for GIF comparison.
const Main = preload("res://scenes/boot/main.tscn")
const WalkArt = preload("res://scripts/world/npc_walk_art.gd")
const OUT := "res://qa/npc_walk_v4"
const FRAME_COUNT := 48
var world: Node2D
var qa_path := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		push_error("NPC walk preview requires graphical Godot and -- --qa")
		quit(1)
		return
	if not ResourceLoader.exists(WalkArt.TEXTURE):
		push_error("NPC walk v4 atlas must be imported before the preview")
		quit(1)
		return
	Engine.max_fps = 60
	create_timer(90.0,true,false,true).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	world = Main.instantiate()
	root.add_child(world)
	await process_frame
	qa_path = "user://qa/npc_walk_v4_%d_%d/world.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(qa_path.get_base_dir()))
	world.store.path = qa_path
	world.hud.show_overlay("")
	world.hud.hide()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.nearest = null
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await process_frame
	var camera: Camera2D = world.player.get_node("IsometricCamera")
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2.ONE*1.4
	WalkArt._ensure()
	var walking_texture: Texture2D = WalkArt._texture
	for id in ["marinheiro_cais","carregador_mercado"]:
		var actor := _item(id)
		if actor == null:
			push_error("Missing walking preview actor: "+id)
			quit(1)
			return
		# Leave the initial natural stop through its real action and next route.
		actor._clock = 0.0
		actor._act(float(actor.stops[actor._stop]["time"])+.01)
		actor._hero = null
		var initial := {
			"position":actor.position, "stop":actor._stop, "waypoint":actor._waypoint,
			"clock":actor._clock, "acting":actor._acting, "carrying":actor.carrying,
			"facing":actor.facing, "distance":actor.walk_distance(), "walk_time":actor._walk_time
		}
		world.player.position = actor.position+Vector2(26,40)
		camera.reset_smoothing()
		camera.force_update_scroll()
		for version in ["previous","refined"]:
			actor.position = initial.position
			actor._stop = initial.stop
			actor._waypoint = initial.waypoint
			actor._clock = initial.clock
			actor._acting = initial.acting
			actor.carrying = initial.carrying
			actor.facing = initial.facing
			actor._walk_distance = initial.distance
			actor._walk_time = initial.walk_time
			actor._walking = false
			WalkArt._texture = null if version == "previous" else walking_texture
			var directory: String = OUT+"/"+id+"_"+version
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
			for frame in range(FRAME_COUNT):
				actor.advance(1.0/30.0)
				actor.queue_redraw()
				for wait_frame in range(2):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(directory+"/%03d.png" % frame)
			# An explicit zero-displacement tick must return to the untouched rest cel.
			actor.advance(0.0)
			if actor.is_walking():
				push_error("Stationary preview actor incorrectly remains in walking state")
				quit(1)
				return
			actor.queue_redraw()
			for wait_frame in range(2):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"/"+id+"_"+version+"_stopped.png")
			print("NPC WALK CAPTURE: "+directory+" /48 frames")
	WalkArt._texture = walking_texture
	if FileAccess.file_exists(qa_path):
		push_error("Walking preview unexpectedly wrote its QA journey")
		quit(1)
		return
	print("NPC WALK PREVIEW:192 real-route frames and four stationary captures, two appearances, prior/refined presentation; no journey saved")
	world.queue_free()
	await process_frame
	quit()

func _item(id: String) -> Node2D:
	for actor in get_nodes_in_group("townsfolk"):
		if actor.item_id == id:
			return actor
	return null
