extends SceneTree
## All nine clips and actual shared ground particles in the real QA arena.
const Driver = preload("res://scripts/actors/gatekeeper_attack_player.gd")
const Data = preload("res://scripts/actors/gatekeeper_attack_data.gd")
const Fx = preload("res://scripts/actors/combat_fx.gd")
const OUT := "res://qa/porteiro_attacks_v5/"

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":
		push_error("Attack review requires graphical Godot with -- --qa")
		quit(1)
		return
	Engine.max_fps=30
	Fx.hitstop_enabled=false # deterministic capture; real impacts retain hitstop
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	Engine.max_fps=30
	if not world.qa_mode or not world.store.path.begins_with("user://qa/"):
		quit(1)
		return
	world.hud.show_overlay("")
	world.hud.visible=false
	world.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	world.boss.visible=false
	for group in ["townsfolk","animals","birds"]:
		for node in get_nodes_in_group(group):node.process_mode=Node.PROCESS_MODE_DISABLED
	world.player.controls_enabled=false
	world.player.set_physics_process(false)
	var actor := Driver.new()
	actor.position=world.boss.position
	actor.feedback=world.player._fx
	world.player._fx.set_process(false)
	world.player._fx.set_physics_process(false)
	world.actors.add_child(actor)
	actor.set_physics_process(false)
	world.player.position=actor.position+Vector2(105,50)
	var camera: Camera2D=world.player.get_node("IsometricCamera")
	camera.top_level=true
	camera.global_position=actor.global_position+Vector2(32,-15)
	camera.reset_smoothing()
	camera.force_update_scroll()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var title := Label.new()
	title.position=Vector2(30,20)
	title.add_theme_font_override("font",preload("res://assets/fonts/PixelOperatorHB.ttf"))
	title.add_theme_font_size_override("font_size",26)
	title.modulate=Color("e0c890")
	layer.add_child(title)
	var note := Label.new()
	note.position=Vector2(30,58)
	note.text="Estudo de golpes / JSON + contato + particulas reais / sem dano e sem gravar progresso"
	note.add_theme_font_size_override("font_size",16)
	layer.add_child(note)
	for id in Data.load_data()["order"]:
		var attack := Data.definition(id)
		title.text=str(attack["name"])+"  /  FASE "+str(int(attack["phase"]))
		actor.cancel_attack()
		world.player._fx._particles.clear()
		actor.play_attack(id)
		var frames := ceili((Data.duration(attack)+.45)*30)
		var contact_frame := ceili(Data.contact_time(attack)*30)
		for frame in range(frames):
			actor.advance(1./30)
			world.player._fx._update_particles(1./30)
			world.player._fx.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			if frame==contact_frame+2:picture.save_png(OUT+id+"_impacto.png")
			if frame%2==0:
				picture.get_region(Rect2i(320,145,640,420)).save_png(OUT+id+"_%03d.png"%frame)
		print("GATEKEEPER CAPTURE ",id," frames=",frames," contact=",Data.contact_time(attack))
	Fx.hitstop_enabled=true
	world.queue_free()
	layer.queue_free()
	await process_frame
	print("GATEKEEPER NINE ATTACKS: completed actual arena capture; QA only; no boss victory or rewards")
	quit()
