extends SceneTree
const View = preload("res://scripts/actors/senu_supplied_view.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	Inputs.install()
	var actor := SenuPlayer.new()
	# Manual physics steps keep the fixture still; action controls remain enabled.
	actor.controls_enabled = true
	root.add_child(actor)
	actor.set_physics_process(false)
	var enemy := VeilEnemy.new()
	enemy.position = Vector2(26, 0)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	actor.facing = Vector2.RIGHT
	var view := View.new()
	view.sample(actor)
	check(actor.try_attack(), "Sword accepts ready state")
	view.sample(actor)
	actor._physics_process(.08)
	check(enemy.health == enemy.max_health, "Sword no longer deals damage during its visible windup")
	actor._physics_process(.039)
	check(enemy.health == enemy.max_health, "Blade acceleration precedes the committed .12 second impact")
	actor._physics_process(.002)
	var contact := view.sample(actor)
	check(enemy.health == enemy.max_health - 22 and contact["cut_pose"] == "contato", "Actual damage and the contact cel coincide")
	check(actor.attack_timer > .25 and not actor.try_attack(), "Recovery remains committed after the damage event")
	enemy.free()
	for i in range(8):
		for heavy in [false, true]:
			actor.reset_at(Vector2.ZERO)
			actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
			view = View.new()
			view.sample(actor)
			actor.try_attack(heavy)
			var start := view.sample(actor)
			var impact := .24 if heavy else .12
			var frames: Array = [int(start["frame"])]
			var previous := 0.0
			for at in [impact*.30, impact*.70, impact+.001, impact+.07, impact+.17]:
				actor._physics_process(at - previous)
				previous = at
				var pose := view.sample(actor)
				frames.append(int(pose["frame"]))
				check(pose["size"] == start["size"] and pose["offset"] == start["offset"], "Fixed body scale/root %s phase %d" % [View.DIRECTIONS[i], frames.size()-1])
			check(frames.size() == 6 and frames.duplicate().all(func(f): return frames.count(f) == 1), "Six real distinct phases %s heavy=%s" % [View.DIRECTIONS[i], heavy])
			check(start["direction"] == View.DIRECTIONS[i] and start["body_model_id"] == "senu_guided_cut_v8", "Dedicated aimed view %s" % View.DIRECTIONS[i])
	actor.reset_at(Vector2.ZERO)
	actor.weapon_unlocked[1] = true
	actor.equip_weapon(1)
	actor.try_attack()
	check(is_equal_approx(actor._hit_delay, .075) and is_equal_approx(actor._second_hit_delay, .17), "Daggers preserve their .075/.17 second double strike")
	actor.free()
	print("SENU SWORD V8 CHECKS: %d passed=%d failures=%s" % [checks, checks-failures.size(),failures])
	quit(1 if not failures.is_empty() else 0)
