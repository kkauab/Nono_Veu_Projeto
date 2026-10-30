extends SceneTree
## QA studio: actual enemy/Senu renderers and the reviewed Gatekeeper atlas.
const Inputs = preload("res://scripts/core/input_bindings.gd")
const View = preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const EnemyView = preload("res://scripts/actors/enemy_pixel_view.gd")
const OUT := "res://qa/porteiro_art_v4/"

class Gatekeeper extends Node2D:
	const PREVIOUS = preload("res://assets/sprites/porteiro_v3.png")
	var previous := false
	var clip := "idle"
	var elapsed := 0.0
	var distance := 0.0
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,.36))
		draw_circle(Vector2.ZERO,10,Color(0,0,0,.25))
		draw_set_transform(Vector2.ZERO)
		if previous:
			var sample := View.sample(clip,"down_right",elapsed,distance,clip=="walk")
			if not sample.is_empty(): draw_texture_rect_region(PREVIOUS,Rect2(sample["offset"],Vector2(160,160)),sample["region"])
		else:
			View.draw_actor(self,clip,"down_right",elapsed,distance,clip=="walk")

class LanceReference extends Node2D:
	var clip := "idle"
	var elapsed := 0.0
	var distance := 0.0
	func _draw() -> void:
		var state := VeilEnemy.State.WAIT
		var progress := 0.0
		if clip == "walk": state = VeilEnemy.State.CHASE
		elif clip == "thrust":
			if elapsed < 1.0:
				state = VeilEnemy.State.WINDUP
				progress = elapsed
			elif elapsed < 1.22:
				state = VeilEnemy.State.STRIKE
				progress = (elapsed-1.0)/.22
			else:
				state = VeilEnemy.State.RECOVER
				progress = clampf((elapsed-1.22)/.53,0,1)
		EnemyView.draw_actor(self,"lancer",state,distance,clip=="walk",Vector2(1,.5),Color.WHITE,1,progress)

class Ground extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,720),Color("142026"))
		for origin in [Vector2(150,350),Vector2(700,350)]:
			for step in range(7):
				var start: Vector2 = origin + Vector2(step*36,-step*18)
				draw_line(start,start+Vector2(300,150),Color("25363b"))
		for point in [Vector2(560,610),Vector2(660,610)]:
			draw_line(point-Vector2(30,0),point+Vector2(30,0),Color("4a5149"))

func _initialize() -> void: _run.call_deferred()

func label_at(parent: Node,value: String,at: Vector2,size: int=18) -> void:
	var label := Label.new()
	label.text=value
	label.position=at
	label.add_theme_font_override("font",preload("res://assets/fonts/PixelOperatorHB.ttf"))
	label.add_theme_font_size_override("font_size",size)
	label.modulate=Color("c7b38c")
	parent.add_child(label)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":
		push_error("Art preview requires a graphical run with -- --qa")
		quit(1)
		return
	Inputs.install()
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	DisplayServer.window_set_size(root.size)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if "--world" in OS.get_cmdline_user_args(): await world_review()
	else: await studio_review()
	quit()

func capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name)

func studio_review() -> void:
	var board := Node2D.new()
	board.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(board)
	board.add_child(Ground.new())
	label_at(board,"O PORTEIRO SEM NOME / PRESENCA NA ARENA",Vector2(28,20),30)
	label_at(board,"Lanceiro comum / referencia de atuacao",Vector2(80,82))
	label_at(board,"Porteiro / vista-piloto de tres quartos",Vector2(670,82))
	label_at(board,"Empunhar / preparar o corpo / estocar / recuperar",Vector2(28,465),23)
	label_at(board,"Escala nativa: Senu e Porteiro, no mesmo chao",Vector2(28,540),18)
	label_at(board,"Estudo visual. Combate e outras direcoes ainda pendentes.",Vector2(28,670),18)
	var reference := LanceReference.new()
	reference.scale=Vector2.ONE*3
	board.add_child(reference)
	var actor := Gatekeeper.new()
	actor.scale=Vector2.ONE*3
	board.add_child(actor)
	var hero := SenuPlayer.new()
	hero.position=Vector2(560,610)
	board.add_child(hero)
	hero.controls_enabled=false
	hero.facing=Vector2(1,.5)
	hero.set_physics_process(false)
	var native_actor := Gatekeeper.new()
	native_actor.position=Vector2(660,610)
	board.add_child(native_actor)
	var saved := 0
	for frame in range(120):
		var now := frame/30.0
		var clip := "walk" if now<1.65 else ("idle" if now<2 else "thrust")
		var elapsed := maxf(0,now-2)
		var distance := minf(now,1.65)*26.0
		var offset := Vector2(distance,distance*.45)*3
		reference.position=Vector2(200,350)+offset
		actor.position=Vector2(780,350)+offset
		for item in [reference,actor]:
			item.clip=clip
			item.elapsed=elapsed
			item.distance=distance
			item.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [0,15,30,49,57,65,78,88,90,95,100,108,119]:
			root.get_texture().get_image().save_png(OUT+"godot_%03d.png"%frame)
			saved+=1
	print("GATEKEEPER V4 STUDIO: 120 animated frames; %d captures; actual Senu/enemy renderers; no save loaded"%saved)
	board.queue_free()
	await process_frame

func world_review() -> void:
	var world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	if not world.qa_mode or not world.store.path.begins_with("user://qa/"):
		push_error("World art preview requires an isolated QA slot")
		quit(1)
		return
	world.hud.show_overlay("")
	world.hud.visible=false
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var ambient: Node = world.get_node_or_null("VeilAmbient")
	if ambient != null: ambient.set_process(false)
	world.boss.visible=false
	var actor := Gatekeeper.new()
	actor.position=world.boss.position
	world.actors.add_child(actor)
	world.player.position=actor.position+Vector2(52,23)
	world.player.facing=Vector2(-1,-.5)
	world.current_room="b1"
	var camera: Camera2D=world.player.get_node("IsometricCamera")
	camera.reset_smoothing()
	camera.force_update_scroll()
	actor.previous=true
	actor.queue_redraw()
	await capture("arena_antes.png")
	actor.previous=false
	actor.queue_redraw()
	await capture("arena_guarda.png")
	actor.clip="thrust"
	actor.elapsed=1.01
	actor.queue_redraw()
	await capture("arena_estocada.png")
	print("GATEKEEPER V4 WORLD: same arena/Senu, before and after plus thrust; slot=",world.store.path)
	world.queue_free()
	await process_frame
