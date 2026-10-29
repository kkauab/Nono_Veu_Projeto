extends SceneTree
## QA-only stage: actual actor renderers, isolated from the world and save slots.
const Inputs = preload("res://scripts/core/input_bindings.gd")
const SenuView = preload("res://scripts/actors/senu_supplied_view.gd")
const OUT := "res://qa/actor_motion"
var actors: Array[Node2D] = []
var fixtures: Array[Dictionary] = []
var canvas: Node2D

class Guides extends Node2D:
	var pivots: Array[Vector2] = []
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1280, 720), Color("101b24"))
		for point in pivots:
			draw_line(point + Vector2(-26, 0), point + Vector2(26, 0), Color("34454d"))
			draw_line(point + Vector2(0, -4), point + Vector2(0, 4), Color("a28450"))
			draw_circle(point, 1, Color("efca7e"))

func _initialize() -> void: _run.call_deferred()

func label_at(text: String, point: Vector2, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.position = point
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color("dfd5b7")
	canvas.add_child(label)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		push_error("Actor motion preview needs a graphical Godot run with -- --qa")
		quit(1)
		return
	Inputs.install()
	Engine.max_fps = 30
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for board in ["senu", "daggers", "enemies"]:
		_build_board(board)
		for frame in range(96):
			var now := float(frame) / 30.0
			_update_board(now)
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.save_png(OUT + "/%s_%03d.png" % [board, frame])
			if frame == 40:
				picture.save_png(OUT + "/%s_sheet.png" % board)
		canvas.free()
		actors.clear()
		fixtures.clear()
	print("ACTOR MOTION PREVIEW: 288 rendered frames, real actor sprites, QA stage only")
	quit()

func _build_board(board: String) -> void:
	canvas = Node2D.new()
	root.add_child(canvas)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var guides := Guides.new()
	canvas.add_child(guides)
	label_at("O NONO VÉU  /  " + ("Inimigos: peso e apoio" if board == "enemies" else "Senu / " + board + ": oito direções"), Vector2(24, 12), 24)
	label_at("Sprites atuais + apresentação procedural. Cruz dourada = pivô dos pés; linha = chão.", Vector2(24, 46))
	if board != "enemies":
		var rows := ["Respiração", "Caminhada", "Corrida", "Impacto", "Ataque leve", "Ataque forte"]
		for column in range(8):
			label_at(SenuView.DIRECTIONS[column], Vector2(145 + column * 143, 79), 14)
			for row in range(rows.size()):
				if column == 0: label_at(rows[row], Vector2(8, 129 + row * 95), 14)
				var actor := SenuPlayer.new()
				actor.position = Vector2(186 + column * 143, 178 + row * 91)
				canvas.add_child(actor)
				if board == "daggers":
					actor.weapon_unlocked[1] = true
					actor.equip_weapon(1)
				actor.controls_enabled = false
				actor.set_physics_process(false)
				actor._fx.set_process(false)
				actor.facing = Vector2.DOWN.rotated(-column * PI / 4)
				actors.append(actor)
				fixtures.append({"row": row, "column": column, "view": actor._supplied_view})
				guides.pivots.append(actor.position)
	else:
		var rows := ["Respiração", "Passos reais", "Preparação", "Impulso", "Recuperação", "Impacto"]
		for column in range(5):
			var kind: String = ["guard", "runner", "lancer", "keeper", "boss"][column]
			label_at(kind, Vector2(215 + column * 229, 79))
			for row in range(rows.size()):
				if column == 0: label_at(rows[row], Vector2(8, 129 + row * 95), 14)
				var actor := VeilEnemy.new()
				actor.archetype = "keeper" if kind == "boss" else kind
				actor.is_boss = kind == "boss"
				actor.position = Vector2(245 + column * 229, 178 + row * 91)
				canvas.add_child(actor)
				actor.set_physics_process(false)
				actors.append(actor)
				fixtures.append({"row": row, "column": column})
				guides.pivots.append(actor.position)
	guides.queue_redraw()

func _update_board(now: float) -> void:
	for index in range(actors.size()):
		var actor: Node2D = actors[index]
		var row := int(fixtures[index]["row"])
		actor.set("_time", now)
		if actor is SenuPlayer:
			var senu := actor as SenuPlayer
			var speed := senu.move_speed * (senu.sprint_multiplier if row == 2 else 1.0)
			var moving := row in [1, 2]
			senu.is_sprinting = row == 2
			senu.velocity = Vector2(senu.facing.x, senu.facing.y * .7) * speed if moving else Vector2.ZERO
			senu.set("_visual_distance", now * speed)
			senu.set("_visual_speed", speed if moving else 0.0)
			senu._hurt_visual = 0
			if row == 3:
				var impact_clock := fmod(now, .8)
				senu.set("_hurt_direction", Vector2.RIGHT.rotated(now * .8))
				senu._hurt_visual = maxf(0, .22 - impact_clock)
			elif row in [4, 5]:
				var heavy := row == 5
				var duration := senu.equipped_weapon().attack_interval * (1.75 if heavy else 1.0)
				var progress := fmod(now, duration + .35)
				senu.attack_timer = maxf(0, duration - progress)
				senu._attack_visual = maxf(0, (.36 if heavy else .19) - progress)
				senu._attack_direction = senu.facing
			senu.queue_redraw()
		else:
			var enemy := actor as VeilEnemy
			enemy.facing = Vector2.RIGHT
			enemy._visual_facing = Vector2.RIGHT if int(fixtures[index]["column"]) % 2 == 0 else Vector2.LEFT
			enemy._animation_moving = row == 1
			enemy._distance_walked = now * enemy.move_speed
			enemy._hurt_visual = 0
			enemy.state = VeilEnemy.State.WAIT
			var progress := fmod(now, 1.4) / 1.4
			if row == 1: enemy.state = VeilEnemy.State.CHASE
			elif row == 2:
				enemy.state = VeilEnemy.State.WINDUP
				enemy.state_timer = enemy._windup_length * (1 - progress)
			elif row == 3:
				enemy.state = VeilEnemy.State.STRIKE
				enemy.state_timer = enemy._strike_length * (1 - progress)
			elif row == 4:
				enemy.state = VeilEnemy.State.RECOVER
				enemy.state_timer = enemy._recovery_length * (1 - progress)
			elif row == 5:
				enemy.set("_hurt_direction", Vector2.LEFT.rotated(now * .8))
				enemy._hurt_visual = maxf(0, .17 - fmod(now, .8))
			enemy.queue_redraw()

