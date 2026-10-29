extends SceneTree
const View = preload("res://scripts/actors/senu_supplied_view.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
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
	Inputs.install()
	var actor := SenuPlayer.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.weapon_unlocked[1] = true
	var view := View.new()
	check(FileAccess.file_exists(View.SHARED_MANIFEST_PATH), "Shared native Pixelorama character is exported")
	if not failures.is_empty():
		quit(1)
		return
	for i in range(8):
		actor.reset_at(Vector2.ZERO)
		actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
		actor.equip_weapon(0)
		var sword := view.sample(actor)
		actor.equip_weapon(1)
		var daggers := view.sample(actor)
		check(sword.get("body_model_id") == "senu_shared_body_v6" and daggers.get("body_model_id") == "senu_shared_body_v6", "Both weapons use the same body model in " + View.DIRECTIONS[i])
		check(sword.get("frame") == daggers.get("frame") and sword.get("region") == daggers.get("region") and sword.get("size") == daggers.get("size"), "Weapon switch preserves the actual body pixels, proportions and pivot in " + View.DIRECTIONS[i])
		actor.velocity = Vector2(actor.facing.x, actor.facing.y * .7) * actor.move_speed
		actor._visual_speed = actor.move_speed # Selection-only shared-body fixture.
		var dagger_walk := view.sample(actor)
		actor.equip_weapon(0)
		var sword_walk := view.sample(actor)
		check(dagger_walk.get("frame") == sword_walk.get("frame"), "Walk uses shared anatomical frames in " + View.DIRECTIONS[i])
		actor.velocity = Vector2.ZERO
		actor._visual_speed = 0
		actor.reset_at(Vector2.ZERO)
		actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
		view.sample(actor)
		check(actor.try_attack(), "Sword attack starts in " + View.DIRECTIONS[i])
		view.sample(actor)
		actor._physics_process(.12)
		var contact := view.sample(actor)
		var blade := view.equipment_pose(actor, contact, "right")
		var desired := Vector2(actor.facing.x, actor.facing.y * .7).normalized()
		if bool(contact.get("embedded_equipment", false)):
			check(blade.is_empty() and contact.get("cut_pose") == "contato" and str(contact.get("texture_path", "")).ends_with("senu_sword_v8.png"), "Sword contact uses the authored wrist and blade together in " + View.DIRECTIONS[i])
		else:
			check(not blade.is_empty() and Vector2.RIGHT.rotated(float(blade.get("angle", 99))).dot(desired) > .99, "Sword blade points along the actual impact direction in " + View.DIRECTIONS[i])
		check(view.current_direction == View.DIRECTIONS[i], "Sword attack keeps its explicit directional body in " + View.DIRECTIONS[i])
		actor.reset_at(Vector2.ZERO)
		actor.equip_weapon(1)
		actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
		view.sample(actor)
		actor.try_attack()
		view.sample(actor)
		actor._physics_process(.17)
		var second := view.sample(actor)
		var left := view.equipment_pose(actor, second, "left")
		check(not left.is_empty() and Vector2.RIGHT.rotated(float(left.get("angle", 99))).dot(desired) > .99, "Second dagger points along the impact direction in " + View.DIRECTIONS[i])
	check(is_equal_approx(actor.move_speed, 80) and is_equal_approx(actor.move_speed * actor.sprint_multiplier, 136), "Walk/run responsiveness is 80/136 without changing dodge reach")
	actor.queue_free()
	await process_frame
	print("SENU V6 STANDARDIZATION CHECKS: ", checks, " passed=", checks-failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)
