extends SceneTree
## Integração visual das duas armas com as ações reais do jogador.

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
	check(FileAccess.file_exists(View.V4_MANIFEST_PATH), "Native Pixelorama v4 export is available")
	if not failures.is_empty():
		quit(1)
		return
	var shared := FileAccess.file_exists(View.SHARED_MANIFEST_PATH)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(View.SHARED_MANIFEST_PATH if shared else View.V4_MANIFEST_PATH))
	var variants: Dictionary = manifest.get("weapon_variants", {})
	check(variants.has("espada") and variants.has("leve"), "Both weapons have their own exported presentation")
	if not failures.is_empty():
		quit(1)
		return
	for category in ["espada", "leve"]:
		var clips: Dictionary = variants[category]["clips"]
		for direction in View.DIRECTIONS:
			check(clips["walk"]["directions"][direction].size() >= 8, "%s: %s has a complete walk cycle" % [category, direction])
	var sword_idle: Array = variants["espada"]["clips"]["idle"]["directions"]["down_left"]
	var dagger_idle: Array = variants["leve"]["clips"]["idle"]["directions"]["down_left"]
	check(sword_idle[0] == dagger_idle[0] if shared else sword_idle[0] != dagger_idle[0], "Equipment uses the current body-model contract")
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var actor := SenuPlayer.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.weapon_unlocked[1] = true
	var view := View.new()
	var sword := view.sample(actor)
	check(not sword.is_empty() and view.current_weapon == "espada", "Player loads the sword variant from the v4 atlas")
	actor.facing = Vector2.DOWN
	Input.action_press("move_down")
	actor._physics_process(1.0 / 60.0)
	view.sample(actor)
	for step in range(8): actor._physics_process(1.0 / 60.0)
	Input.action_release("move_down")
	var forward := view.sample(actor)
	actor.facing = Vector2.LEFT
	actor.velocity = Vector2(-actor.move_speed, 0) # Selection-only turn keeps the last measured ground speed.
	var turned := view.sample(actor)
	check(is_equal_approx(float(forward["gait_phase"]), float(turned["gait_phase"])) and forward["frame_position"] == turned["frame_position"], "Turning preserves the same footfall phase")
	check(actor.equip_weapon(1), "Unlocked Daggers equip while walking")
	var daggers := view.sample(actor)
	check(not daggers.is_empty() and view.current_weapon == "leve" and daggers["weapon"] == "leve", "Equipping Daggers selects their own visual clips")
	check(is_equal_approx(float(turned["gait_phase"]), float(daggers["gait_phase"])) and turned["frame_position"] == daggers["frame_position"], "Weapon switch preserves the footfall phase")
	check(daggers["frame"] == turned["frame"] and bool(daggers.get("modular_equipment")) if shared else daggers["frame"] != turned["frame"], "Weapon switch preserves shared anatomy while changing equipment")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_attack(), "Real dagger double strike begins")
	view.sample(actor)
	actor._physics_process(.08)
	var first_contact := view.sample(actor)
	check(view.current_state == "attack_light" and int(first_contact["frame_position"]) >= 2, "First dagger contact is visible at the first damage time")
	actor._physics_process(.10)
	var second_contact := view.sample(actor)
	check(float(second_contact["elapsed"]) >= .17 and int(second_contact["frame_position"]) >= 5, "Second dagger contact advances the same animation without restarting")
	check(float(second_contact["elapsed"]) > float(first_contact["elapsed"]), "Second-hit visual refresh does not rewind the action clock")
	actor._physics_process(.08)
	var recovery := view.sample(actor)
	check(view.current_state == "attack_light" and int(recovery["frame_position"]) == 7, "Dagger recovery reaches its final frame before input unlocks")
	actor._physics_process(.06)
	view.sample(actor)
	check(view.current_state == "idle", "Dagger recovery returns to idle when the real action ends")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_power(), "Real Passo de Sombra begins")
	view.sample(actor)
	check(view.current_state == "power" and view.current_weapon == "leve", "Passo de Sombra uses the dagger power animation")
	actor._physics_process(actor.dodge_duration * 1.4 * .9)
	var shadow_end := view.sample(actor)
	check(view.current_state == "power" and int(shadow_end["frame_position"]) >= 4, "Dagger power progresses over its complete dodge window")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_dodge(), "Real dagger dodge begins")
	view.sample(actor)
	actor._physics_process(actor.dodge_duration * .95)
	var dodge_end := view.sample(actor)
	check(view.current_state == "dodge" and int(dodge_end["frame_position"]) == int(dodge_end["frame_count"]) - 1, "Dodge displays its final supplied frame before the roll ends")
	actor.reset_at(Vector2.ZERO)
	actor.invulnerability_timer = 0
	view.sample(actor)
	actor.receive_hit(1, Vector2(20, 0))
	view.sample(actor)
	actor._physics_process(.18)
	var hurt_end := view.sample(actor)
	check(view.current_state == "hurt" and int(hurt_end["frame_position"]) == 2, "Hurt displays the full reaction before the reaction window expires")
	actor.reset_at(Vector2.ZERO)
	view.sample(actor)
	check(actor.try_parry(), "Real dagger parry begins")
	view.sample(actor)
	actor._physics_process(.21)
	var parry_end := view.sample(actor)
	check(view.current_state == "parry" and int(parry_end["frame_position"]) == 3, "Parry displays its last supplied frame within the guard window")
	var sprite_frames := load("res://resources/characters/senu_shared_v6_frames.tres" if shared else "res://resources/characters/senu_v4_frames.tres") as SpriteFrames
	var clip_name := "leve_attack_light_down_left" if shared else "daggers_attack_light_down_left"
	check(sprite_frames != null and sprite_frames.has_animation(clip_name) and sprite_frames.get_frame_count(clip_name) == 8, "Godot exposes the complete editable dagger double strike")
	print("SENU V4 ANIMATION CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	actor.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
