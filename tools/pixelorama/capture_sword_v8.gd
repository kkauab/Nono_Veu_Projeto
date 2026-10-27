extends SceneTree
const Inputs = preload("res://scripts/core/input_bindings.gd")
var actors: Array[SenuPlayer] = []

class Board extends Node2D:
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1280,590), Color("111c22"))
		draw_string(font, Vector2(25,34), "SENU / KHOPESH · SEIS POSES DE CORTE", HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e4c791"))
		draw_string(font, Vector2(25,60), "Cinco vistas próprias e espelhos; corpo estável, antecipação, aceleração, contato e retorno.", HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a8bfba"))
		var names := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
		for col in range(8):
			for row in range(2):
				var x := 80 + col * 160
				var y := 272 + row * 250
				draw_line(Vector2(x-65,y),Vector2(x+65,y),Color("35464a"))
				if row == 0: draw_string(font,Vector2(x-10,105),names[col],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("c5b587"))
		draw_string(font,Vector2(20,306),"LEVE / contato em 0,12 s",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d8c092"))
		draw_string(font,Vector2(20,558),"PESADO / contato em 0,24 s",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("d8c092"))

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	Inputs.install()
	root.content_scale_size=Vector2i(1280,590)
	root.size=Vector2i(1280,590)
	var stage := Board.new()
	root.add_child(stage)
	for row in range(2):
		for col in range(8):
			var actor := SenuPlayer.new()
			stage.add_child(actor)
			actor.set_physics_process(false)
			actor.position=Vector2(80+col*160,272+row*250)
			actor.scale=Vector2(2.6,2.6)
			actor.facing=Vector2.DOWN.rotated(-col*PI/4)
			actor.invulnerability_timer=0
			actor._supplied_view.sample(actor)
			actor.try_attack(row == 1)
			actor._supplied_view.sample(actor)
			actor.queue_redraw()
			actors.append(actor)
	var folder := "res://qa/sword_v8_motion"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for step in range(60):
		if step > 0:
			for actor in actors:
				actor._physics_process(1.0/60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if step % 2 == 0:
			root.get_texture().get_image().save_png(folder+"/frame_%03d.png" % (step/2))
		if step == 8:
			root.get_texture().get_image().save_png("res://qa/sword_v8_eight_directions.png")
	print("SENU_SWORD_V8_CAPTURE_OK")
	quit()
