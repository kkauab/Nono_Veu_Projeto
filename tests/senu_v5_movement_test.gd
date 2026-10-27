extends SceneTree

const Inputs = preload("res://scripts/core/input_bindings.gd")
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

func metric_speed(actor: SenuPlayer) -> float:
	return Vector2(actor.velocity.x, actor.velocity.y / actor.ISO_Y).length()

func finish_roll(actor: SenuPlayer) -> float:
	var distance := 0.0
	while actor._dodge_timer > 0:
		actor._physics_process(1.0 / 60)
		distance += metric_speed(actor) / 60
	return distance

func _run() -> void:
	Inputs.install()
	check(InputMap.has_action("sprint"), "Shift sprint action is installed")
	var actor := SenuPlayer.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.weapon_unlocked[1] = true
	Input.action_press("move_right")
	actor._physics_process(.01)
	check(is_equal_approx(metric_speed(actor), actor.move_speed) and not actor.is_sprinting, "Movement without Shift uses the walking speed")
	Input.action_press("sprint")
	actor._physics_process(.01)
	check(is_equal_approx(metric_speed(actor), actor.move_speed * actor.sprint_multiplier) and actor.is_sprinting, "Holding Shift enables a separate faster run")
	Input.action_press("move_down")
	actor._physics_process(.01)
	check(is_equal_approx(metric_speed(actor), actor.move_speed * actor.sprint_multiplier), "Diagonal sprint has the same metric speed")
	Input.action_release("move_down")
	actor.attack_timer = .4
	actor._physics_process(.01)
	check(not actor.is_sprinting and is_equal_approx(metric_speed(actor), actor.move_speed * .36), "Sprint cannot increase committed attack movement")
	actor.attack_timer = 0
	actor.parry_timer = .2
	actor._physics_process(.01)
	check(not actor.is_sprinting and is_equal_approx(metric_speed(actor), actor.move_speed * .22), "Sprint cannot increase guard movement")
	actor.parry_timer = 0
	actor._hurt_visual = .2
	actor._physics_process(.01)
	check(not actor.is_sprinting and is_equal_approx(metric_speed(actor), actor.move_speed), "Hurt prevents the run bonus")
	actor._hurt_visual = 0
	actor.controls_enabled = false
	actor._physics_process(.01)
	check(not actor.is_sprinting and actor.velocity.is_zero_approx(), "Disabled controls prevent walking and sprinting")
	actor.controls_enabled = true
	actor.dead = true
	actor._physics_process(.01)
	check(not actor.is_sprinting and actor.velocity.is_zero_approx(), "Death clears the running state")
	Input.action_release("sprint")
	Input.action_release("move_right")
	actor.reset_at(Vector2.ZERO)
	actor.facing = Vector2.RIGHT
	check(actor.try_dodge(), "Ordinary roll begins")
	check(is_equal_approx(actor._dodge_timer, .32) and is_equal_approx(actor.invulnerability_timer, .28), "Readable roll keeps the previous invulnerability window")
	check(is_equal_approx(finish_roll(actor), 60), "Partial final physics step conserves the original sixty-pixel roll distance")
	check(is_zero_approx(actor._dodge_timer) and not actor.is_sprinting, "Roll ends cleanly without a run bonus")
	actor.reset_at(Vector2.ZERO)
	actor.equip_weapon(1)
	check(actor.try_power(), "Dagger shadow step begins")
	check(is_equal_approx(actor._dodge_timer, .448) and is_equal_approx(actor.invulnerability_timer, .40), "Shadow step keeps its previous invulnerability window")
	check(is_equal_approx(finish_roll(actor), 84), "Shadow step conserves its original eighty-four-pixel range")
	if "--physics-only" not in OS.get_cmdline_user_args():
		check(FileAccess.file_exists(View.MOTION_MANIFEST_PATH), "New drawn movement export is present")
		if FileAccess.file_exists(View.MOTION_MANIFEST_PATH):
			await verify_motion(actor)
	print("SENU V5 MOVEMENT CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func verify_motion(actor: SenuPlayer) -> void:
	var view := View.new()
	var shared := FileAccess.file_exists(View.SHARED_MANIFEST_PATH)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(View.SHARED_MANIFEST_PATH if shared else View.MOTION_MANIFEST_PATH))
	var variants: Dictionary = manifest["weapon_variants"]
	for category in ["espada", "leve"]:
		for state in ["walk", "run", "dodge"]:
			for direction in View.DIRECTIONS:
				check(variants[category]["clips"][state]["directions"][direction].size() >= 8, "%s/%s/%s has at least eight drawn poses" % [category, state, direction])
	actor.reset_at(Vector2.ZERO)
	actor.equip_weapon(0)
	actor.facing = Vector2.RIGHT
	actor.velocity = Vector2(actor.move_speed, 0)
	var walk := view.sample(actor)
	check(walk.get("texture_path") == manifest["texture"] and view.current_state == "walk" and view.motion_load_error.is_empty(), "Walking uses the new pose atlas")
	actor._time += .17
	var stepped := view.sample(actor)
	check(stepped["frame_position"] != walk["frame_position"], "Walk advances to a different step pose")
	actor.is_sprinting = true
	actor.velocity *= actor.sprint_multiplier
	var run := view.sample(actor)
	check(view.current_state == "run" and view.current_clip == "run" and run["texture_path"] == manifest["texture"], "Running uses its own pose sequence in the new atlas")
	check(is_equal_approx(float(run["gait_phase"]), float(stepped["gait_phase"])), "Walk-to-run transition preserves the supporting leg phase")
	actor.facing = Vector2.UP
	var turn := view.sample(actor)
	check(is_equal_approx(float(run["gait_phase"]), float(turn["gait_phase"])) and view.current_direction == "up", "Turning does not restart the stride")
	actor.equip_weapon(1)
	var switched := view.sample(actor)
	check(view.current_weapon == "leve" and switched["texture_path"] == manifest["texture"] and is_equal_approx(float(switched["gait_phase"]), float(turn["gait_phase"])), "Both weapons keep the stride when switched")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	actor.try_dodge()
	var start := view.sample(actor)
	check(view.current_state == "dodge" and start["texture_path"] == manifest["texture"], "Roll selects the drawn roll sequence")
	actor._physics_process(actor.dodge_duration * .95)
	var landing := view.sample(actor)
	check(int(landing["frame_position"]) == int(landing["frame_count"]) - 1 and landing["size"] == start["size"], "Roll reaches landing without resizing the sprite canvas")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	actor.try_attack()
	var attack := view.sample(actor)
	check(view.current_state == "attack_light" and (bool(attack.get("modular_equipment")) if shared else attack["texture_path"] != manifest["texture"]), "Combat keeps its correct directional body and equipment contract")
