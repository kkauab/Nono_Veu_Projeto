extends SceneTree
## Render the actual encounter HUD/dialogue at several window sizes in QA.
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _frame() -> void:
	await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":quit(1);return
	var game=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.gatekeeper_encounter.set_process(false)
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	game.current_room="b1"
	game.hud.show_overlay("")
	game.player.reset_at(game.boss.position+Vector2(70,20))
	game.player.get_node("IsometricCamera").reset_smoothing()
	game.boss.start_fight()
	for size in [Vector2i(960,540),Vector2i(1920,1080),Vector2i(800,900)]:
		root.size=size
		await _frame()
		await _frame()
		var viewport: Rect2=game.hud.get_viewport_rect()
		var offset: Vector2=game.hud._offset
		var factor: float=game.hud._factor
		var bar:=Rect2(offset+Vector2(239,413)*factor,Vector2(482,33)*factor)
		check(viewport.encloses(bar),"Boss name/bar fit %dx%d"%[size.x,size.y])
		root.get_texture().get_image().save_png("res://qa/porteiro_combate/hud_%dx%d.png"%[size.x,size.y])
		game.hud.show_conversation("O Porteiro Sem Nome",preload("res://resources/dialogue/gatekeeper_dialogue.gd").INTRO,"porteiro")
		await _frame()
		await _frame()
		var bubble=game.hud.get_node("NpcSpeechBubble")
		check(viewport.encloses(bubble.panel.get_global_rect()),"Existing dialogue fits %dx%d"%[size.x,size.y])
		root.get_texture().get_image().save_png("res://qa/porteiro_combate/dialogo_%dx%d.png"%[size.x,size.y])
		game.hud.show_overlay("")
	game.queue_free()
	await process_frame
	print("GATEKEEPER UI checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
