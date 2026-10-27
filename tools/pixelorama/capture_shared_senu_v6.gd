extends SceneTree

class Comparison extends Node2D:
	var actors: Array[SenuPlayer] = []
	func _ready() -> void:
		for row in range(4):
			for col in range(8):
				var actor := SenuPlayer.new()
				add_child(actor)
				actor.set_physics_process(false)
				actor.weapon_unlocked[1] = true
				actor.weapon_index = 1 if row in [1, 3] else 0
				actor.facing = Vector2.DOWN.rotated(-col * PI / 4)
				actor.position = Vector2(90 + col * 156, 220 + row * 165)
				actor.scale = Vector2(2.1, 2.1)
				actor._supplied_view.sample(actor)
				if row >= 2:
					actor.try_attack()
					actor._supplied_view.sample(actor)
					actor._physics_process(.171 if row == 3 else .075)
				actor.queue_redraw()
				actors.append(actor)
		queue_redraw()
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0,0,1280,760),Color("111c22"))
		draw_string(font,Vector2(28,36),"SENU / CORPO ÚNICO · OITO DIREÇÕES",HORIZONTAL_ALIGNMENT_LEFT,-1,25,Color("e3c791"))
		draw_string(font,Vector2(28,64),"Mesmos pixels de corpo nas duas armas; lâminas presas às mãos e alinhadas ao contato.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("a3b9b7"))
		var directions := ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
		for row in range(4):
			for col in range(8):
				var x := 90 + col * 156
				var y := 220 + row * 165
				draw_line(Vector2(x-55,y),Vector2(x+55,y),Color("31464a"))
				if row == 0: draw_string(font,Vector2(x-10,96),directions[col],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("c7b68e"))
			var label: String = ["KHOPESH / REPOUSO", "ADAGAS / REPOUSO", "KHOPESH / CONTATO", "ADAGAS / SEGUNDO CONTATO"][row]
			draw_string(font,Vector2(22,246+row*165),label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("c7b68e"))

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var inputs = load("res://scripts/core/input_bindings.gd")
	inputs.install()
	root.content_scale_size=Vector2i(1280,760)
	root.size=Vector2i(1280,760)
	root.add_child(Comparison.new())
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/senu_shared_v6_eight_directions.png")
	print("SHARED_SENU_V6_CAPTURE_OK")
	quit()
