extends SceneTree
## Captura a apresentação real do jogador em nove estados, sem tocar no save.

class PreviewStage extends Node2D:
	const STATES := ["idle", "walk", "attack_light", "attack_heavy", "dodge", "parry", "hurt", "death", "power"]
	const LABELS := ["REPOUSO", "MOVIMENTO", "ATAQUE LEVE", "ATAQUE FORTE", "ESQUIVA", "APARAR", "DANO", "QUEDA", "PODER"]
	var daggers := "--daggers" in OS.get_cmdline_user_args()
	func _ready() -> void:
		for i in range(STATES.size()):
			var actor := SenuPlayer.new()
			add_child(actor)
			actor.set_physics_process(false)
			actor.controls_enabled = false
			if daggers:
				actor.weapon_unlocked[1] = true
				actor.weapon_index = 1
			actor.facing = Vector2(-1, 1).normalized()
			actor._attack_direction = actor.facing
			actor._dodge_direction = actor.facing
			actor.position = Vector2(160 + (i % 3) * 300, 245 + (i / 3) * 205)
			actor.scale = Vector2(2.8, 2.8)
			actor._time = 10
			match STATES[i]:
				"walk": actor.velocity = Vector2(-100, 0)
				"attack_light":
					actor._attack_visual = .19
					actor.attack_timer = .4
				"attack_heavy":
					actor._attack_visual = .36
					actor.attack_timer = .7
				"dodge": actor._dodge_timer = .2
				"parry": actor.parry_timer = .25
				"hurt": actor._hurt_visual = .22
				"death": actor.dead = true
				"power":
					actor._power_visual = .4
					actor.power_cooldown_remaining = 3
					if daggers:
						actor._shadow_finish = true
						actor._dodge_timer = .28
					else:
						actor._attack_visual = .34
						actor.attack_timer = .72
			actor._supplied_view.sample(actor)
			var elapsed := .26 if STATES[i] == "attack_heavy" else (.13 if STATES[i] == "attack_light" else .18)
			if STATES[i] == "death": elapsed = 2
			actor._time += elapsed
			actor.queue_redraw()
		queue_redraw()
	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, 960, 760), Color("111c22"))
		draw_string(font, Vector2(40, 45), "SENU / ADAGAS DO REVERSO" if daggers else "SENU / KHOPESH", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e3c791"))
		draw_string(font, Vector2(40, 73), "Sprites fornecidos · Projeto Pixelorama · Apresentação no Godot", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("a3b9b7"))
		for i in range(STATES.size()):
			var origin := Vector2(25 + (i % 3) * 300, 100 + (i / 3) * 205)
			draw_style_box(_panel(), Rect2(origin, Vector2(280, 190)))
			draw_line(origin + Vector2(35, 145), origin + Vector2(245, 145), Color("304348"), 1)
			draw_string(font, origin + Vector2(15, 174), LABELS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d1c2a1"))
		draw_string(font, Vector2(40, 748), "Duas armas · 12 quadros de caminhada por direção · quadros editáveis no Pixelorama", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8da3a3"))
	func _panel() -> StyleBoxFlat:
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("1b2b30")
		panel.border_color = Color("355057")
		panel.set_border_width_all(1)
		panel.set_corner_radius_all(7)
		return panel

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	root.content_scale_size = Vector2i(960, 760)
	root.size = Vector2i(960, 760)
	root.add_child(PreviewStage.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://qa/senu_adagas_preview.png" if "--daggers" in OS.get_cmdline_user_args() else "res://qa/senu_pixelorama_preview.png"
	root.get_texture().get_image().save_png(path)
	print("SENU_PREVIEW_SAVED ", ProjectSettings.globalize_path(path))
	quit()
