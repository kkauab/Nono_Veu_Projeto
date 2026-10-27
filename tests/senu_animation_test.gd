extends SceneTree

const View = preload("res://scripts/actors/senu_supplied_view.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var actor := SenuPlayer.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	var view := View.new()
	var first := view.sample(actor)
	check(not first.is_empty() and view.load_error.is_empty(), "Exported Pixelorama atlas loads in the player")
	check((first.get("offset") as Vector2).is_equal_approx(Vector2(-49.92, -72.8)) and (first.get("size") as Vector2).is_equal_approx(Vector2(99.84, 99.84)), "Feet use the shared pivot and game scale")
	for i in range(8):
		actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
		view.sample(actor)
		check(view.current_direction == View.DIRECTIONS[i], "Direction %s uses its expected clip" % View.DIRECTIONS[i])
	actor.facing = Vector2.LEFT
	actor.velocity = Vector2(-100, 0)
	var walk_first := view.sample(actor)
	actor._time += .16
	var walk_next := view.sample(actor)
	check(view.current_state == "walk" and walk_first["frame"] != walk_next["frame"], "Moving player advances the walk cycle")
	actor.velocity = Vector2.ZERO
	check(actor.try_attack(), "Real light attack starts")
	var windup := view.sample(actor)
	actor._physics_process(.09)
	var contact := view.sample(actor)
	check(view.current_state == "attack_light" and windup["frame"] != contact["frame"], "Light attack reaches a new frame at the damage time")
	actor.invulnerability_timer = 0
	actor.receive_hit(1, Vector2(20, 0))
	view.sample(actor)
	check(view.current_state == "hurt", "Damage overrides the attack visual")
	actor._time += .23
	actor._hurt_visual = 0
	actor._attack_visual = .01
	view.sample(actor)
	check(view.current_state != "attack_light", "Interrupted attack does not resume after hurt")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_attack(true), "Real heavy attack starts")
	view.sample(actor)
	check(view.current_state == "attack_heavy", "Heavy attack has its own animation")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_power(), "Real sword power starts")
	view.sample(actor)
	check(view.current_state == "power", "Sword power selects the supplied power pose and effect")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_dodge(), "Real dodge starts")
	actor.facing = Vector2.RIGHT
	view.sample(actor)
	check(view.current_state == "dodge" and view.current_direction == "left", "Dodge follows its committed direction")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_parry(), "Real parry starts")
	view.sample(actor)
	check(view.current_state == "parry", "Guard uses the supplied parry animation")
	actor.reset_at(Vector2.ZERO)
	actor.invulnerability_timer = 0
	view.sample(actor)
	actor.receive_hit(1000, Vector2(20, 0))
	view.sample(actor)
	check(view.current_state == "death", "Fatal hit selects death instead of attack or hurt")
	actor._time += 2
	var death_end := view.sample(actor)
	actor._time += 2
	check(view.sample(actor)["frame"] == death_end["frame"], "Death holds its last frame")
	actor.reset_at(Vector2(10, 20))
	view.sample(actor)
	check(view.current_state == "idle" and actor.health == actor.max_health, "Checkpoint clears death and returns to idle")
	var frames := load("res://resources/characters/senu_v3_frames.tres") as SpriteFrames
	check(frames != null and frames.has_animation("walk_up_left") and frames.has_animation("slash_fx"), "Editable Godot SpriteFrames includes body and supplied effects")
	print("SENU ANIMATION CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
