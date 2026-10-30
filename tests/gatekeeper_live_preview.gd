extends SceneTree
## Actual game actor, HUD, dialogue and impacts. Isolated QA progress only.
const Data=preload("res://scripts/actors/gatekeeper_attack_data.gd")
const Boss=preload("res://scripts/actors/nameless_gatekeeper.gd")
const Fx=preload("res://scripts/actors/combat_fx.gd")
const OUT="res://qa/porteiro_refino_v9/runtime/"
var game: Node2D
var boss: Boss
var origin:=Vector2.ZERO
func _initialize() -> void:_run.call_deferred()
func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func _capture(name: String) -> void:
	await _frame()
	root.get_texture().get_image().save_png(OUT+name+".png")
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":quit(1);return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	Fx.hitstop_enabled=false
	game=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	Engine.max_fps=30
	game.set_physics_process(false)
	game.current_room="b1"
	game.nearest=null
	game.gatekeeper_encounter.set_process(false)
	game.hud.show_overlay("")
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player._fx.set_process(false)
	game.player._fx.set_physics_process(false)
	boss=game.boss
	origin=boss.position
	for id in ["seal_bells","seal_water","seal_stars"]:game.store.data["flags"][id]=true
	game.refresh_seals()
	game.player.reset_at(origin+Vector2(100,30))
	boss.begin_intro()
	game.gatekeeper_encounter._process(.02)
	for frame in range(20):
		game.gatekeeper_encounter._process(1./30)
		await _frame()
	await _capture("introducao")
	var bubble=game.hud.get_node("NpcSpeechBubble")
	for i in range(8):bubble.advance()
	for frame in range(30):
		game.gatekeeper_encounter._process(1./30)
		await _frame()
	await _capture("registros_introducao")
	game.gatekeeper_encounter.finish_sequence()
	var camera: Camera2D=game.player.get_node("IsometricCamera")
	camera.top_level=true
	camera.global_position=origin+Vector2(28,-12)
	camera.reset_smoothing()
	camera.force_update_scroll()
	game.player.invulnerability_timer=0
	for direction in preload("res://scripts/actors/nameless_gatekeeper_view.gd").live_data()["directions"]:
		boss.performance.art_direction=direction
		boss.performance.idle_clip="idle"
		boss.performance.queue_redraw()
		await _capture("vista_"+direction)
	game.player.reset_at(origin+Vector2(-32,-12))
	game.player.invulnerability_timer=0
	boss.performance.art_direction="up_left"
	boss.performance.queue_redraw()
	await _frame()
	root.get_texture().get_image().get_region(Rect2i(430,250,300,240)).save_png(OUT+"silhueta_no_mapa.png")
	boss.reset_enemy()
	game.player.reset_at(origin+Vector2(180,0))
	boss.start_fight()
	for id in Data.load_data()["order"]:boss._cooldowns[id]=999
	for frame in range(120):
		boss._physics_process(1./30)
		await _frame()
		root.get_texture().get_image().get_region(Rect2i(320,135,640,450)).save_png(OUT+"walk_%03d.png"%frame)
	var back_targets={"up_left":Vector2(-110,-55),"up":Vector2(0,-100),"up_right":Vector2(110,-55)}
	for direction in back_targets:
		boss.reset_enemy()
		boss.phase=2
		game.player.reset_at(origin+back_targets[direction])
		game.player.invulnerability_timer=0
		boss.start_fight()
		for id in Data.load_data()["order"]:boss._cooldowns[id]=999
		for frame in range(90):
			boss._physics_process(1./30)
			await _frame()
			root.get_texture().get_image().get_region(Rect2i(320,105,640,450)).save_png(OUT+"walk_"+direction+"_%03d.png"%frame)
	boss.reset_enemy()
	var points={"charge":Vector2(90,0),"sweep":Vector2(34,24),"register":Vector2(0,32),"bell":Vector2(0,-60),"warning":Vector2(-42,0),"echo_charge":Vector2(-70,-40),"names":Vector2(45,0),"chains":Vector2(65,-30),"last_name":Vector2(39,0)}
	for id in Data.load_data()["order"]:
		boss.performance.cancel_attack()
		boss.position=origin
		boss.phase=int(Data.definition(id)["phase"])
		boss.mode=Boss.Mode.APPROACH
		boss.encounter_active=true
		boss.health=boss.max_health
		game.player.reset_at(origin+points[id])
		game.player.invulnerability_timer=0
		game.player.cancel_actions()
		game.player._fx._particles.clear()
		boss.start_attack(id)
		var rate:=float(boss._config["phase_two_speed"]) if boss.phase==2 else 1.0
		var frames:=ceili((Data.duration(Data.definition(id))/rate+.10)*30)
		for frame in range(frames):
			game.player.invulnerability_timer=maxf(0,game.player.invulnerability_timer-1./30)
			boss._physics_process(1./30)
			game.player._fx._update_particles(1./30)
			game.player._fx.queue_redraw()
			await _frame()
			var picture:=root.get_texture().get_image()
			picture.get_region(Rect2i(320,135,640,450)).save_png(OUT+id+"_%03d.png"%frame)
			if frame==ceili(Data.contact_time(Data.definition(id))/rate*30)+3:picture.save_png(OUT+id+"_impacto.png")
		print("LIVE BOSS CAPTURE ",id," health=",game.player.health," facing=",boss.performance.art_direction)
	boss.reset_enemy()
	game.player.reset_at(origin+Vector2(80,20))
	boss.start_fight()
	boss.receive_hit(9999,game.player.position)
	game.gatekeeper_encounter._process(.02)
	for frame in range(60):
		game.gatekeeper_encounter._process(1./30)
		await _frame()
	await _capture("transicao")
	game.gatekeeper_encounter.finish_sequence()
	boss.receive_hit(9999,game.player.position)
	game.gatekeeper_encounter._process(.02)
	for frame in range(70):
		game.gatekeeper_encounter._process(1./30)
		await _frame()
	await _capture("derrota_humana")
	game.gatekeeper_encounter.finish_sequence()
	for frame in range(45):
		game.gatekeeper_encounter._process(1./30)
		await _frame()
		if frame==30:root.get_texture().get_image().save_png(OUT+"passagem_livre.png")
	game.hud.set("_book_inventory_selected","gatekeeper_key_spear")
	game.hud.set("_book_inventory_filter","Armas")
	game.hud.show_overlay("inventory")
	await _capture("recompensa_inventario")
	game.hud.show_overlay("")
	game.queue_free()
	await process_frame
	Fx.hitstop_enabled=true
	print("GATEKEEPER LIVE PREVIEW complete; real game actor/UI; QA slot only")
	quit()
