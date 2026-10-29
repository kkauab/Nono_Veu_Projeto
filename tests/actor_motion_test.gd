extends SceneTree
## Presentation invariants and real blocked/unblocked travel. No world or save IO.
const View = preload("res://scripts/actors/senu_supplied_view.gd")
const EnemyView = preload("res://scripts/actors/enemy_pixel_view.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
func metric(value: Vector2) -> Vector2: return Vector2(value.x, value.y / .7)
func intact(motion: Dictionary, limit: float) -> bool:
	var upper: Vector2 = motion["upper_offset"]
	var middle: Vector2 = motion["middle_offset"]
	return motion["feet_offset"] == Vector2.ZERO and upper == upper.round() and middle == middle.round() and absf(upper.x) <= limit and absf(upper.y) <= limit and absf(middle.x) <= 1 and absf(middle.y) <= 1
func snapshot(actor: SenuPlayer) -> Array:
	return [actor.transform, actor.health, actor.attack_timer, actor._hit_delay, actor._second_hit_delay, actor.invulnerability_timer, actor.collision_layer, actor.collision_mask, actor.get_child(0).transform, actor.get_child(0).shape.radius]

func _run() -> void:
	Inputs.install()
	var stage := Node2D.new()
	stage.y_sort_enabled = true
	root.add_child(stage)
	var actor := SenuPlayer.new()
	stage.add_child(actor)
	actor.set_physics_process(false)
	var view := View.new()
	var base := view.sample(actor)
	var before := snapshot(actor)
	var breath := {}
	var bounded := true
	for frame in range(240):
		actor._time = frame / 60.0
		var pose := view.sample(actor)
		breath[pose["motion"]["upper_offset"]] = true
		bounded = bounded and intact(pose["motion"], 1) and pose["offset"] == base["offset"] and pose["size"] == base["size"]
	check(breath.size() == 2, "Senu breathes subtly through two one-pixel chest positions")
	check(bounded, "Idle keeps feet fixed, sprite size unchanged and chest movement on integer pixels")
	check(snapshot(actor) == before and actor.z_index == 0 and stage.y_sort_enabled, "Sampling idle cannot move physics, hurtboxes, damage clocks or depth")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		actor.reset_at(Vector2.ZERO)
		view = View.new()
		view.sample(actor)
		actor.invulnerability_timer = 0
		actor.receive_hit(1, actor.position - direction * 20)
		var pose := view.sample(actor)
		var recoil: Vector2 = pose["motion"]["upper_offset"]
		check(recoil.dot(direction) > 0 and intact(pose["motion"], 2), "Senu visual recoil points away from the actual %s impact source" % direction)
		check(actor._hurt_direction.dot(direction) > .99, "Senu remembers actual impact direction independently of facing")
		actor._physics_process(.21)
		var settled := view.sample(actor)
		check((settled["motion"]["upper_offset"] as Vector2).length() < recoil.length(), "Senu directional recoil settles before hurt animation ends")
	for heavy in [false, true]:
		actor.reset_at(Vector2.ZERO)
		actor.facing = Vector2.RIGHT
		view = View.new()
		view.sample(actor)
		actor.try_attack(heavy)
		view.sample(actor)
		var impact := .24 if heavy else .12
		actor._physics_process(impact * .55)
		var load := view.sample(actor)
		check(float(load["motion"]["upper_offset"].x) < 0, "Senu loads the shoulder before the %s strike" % ("heavy" if heavy else "light"))
		actor._physics_process(impact * .45 + .001)
		var contact := view.sample(actor)
		check(contact.get("cut_pose") == "contato" and contact["motion"]["upper_offset"].x > 0, "Authored contact and forward weight coincide at unchanged damage time")
		var invariant := snapshot(actor)
		for i in range(20): view.sample(actor)
		check(snapshot(actor) == invariant, "Repeated attack sampling cannot reschedule damage or alter commitment")
		actor._physics_process(maxf(0, actor.attack_timer - .01))
		var recovery := view.sample(actor)
		check(recovery["motion"]["upper_offset"] == Vector2.ZERO and recovery["offset"] == contact["offset"] and recovery["size"] == contact["size"], "Attack weight settles back to the fixed foot pivot before input unlocks")
	actor.reset_at(Vector2.ZERO)
	view = View.new()
	view.sample(actor)
	actor.set_physics_process(true)
	Input.action_press("move_right")
	for frame in range(18): await physics_frame
	var start_position := actor.position
	var start_distance := actor._visual_distance
	for frame in range(24): await physics_frame
	var walk_distance := actor._visual_distance - start_distance
	var walk_travel := metric(actor.position - start_position).length()
	check(walk_travel > 20 and absf(walk_distance - walk_travel) < .1, "Senu gait distance measures actual free ground travel")
	var walk := view.sample(actor)
	check(walk["state"] == "walk" and actor._visual_speed > 0, "Actual walking selects the authored walking clip")
	var walk_phase: float = walk["gait_phase"]
	Input.action_press("sprint")
	for frame in range(1): await physics_frame
	var run := view.sample(actor)
	check(run["state"] == "run" and float(run["gait_phase"]) != 0 and absf(float(run["gait_phase"]) - walk_phase) < .2, "Walking to sprint preserves support phase while actual speed changes")
	Input.action_release("sprint")
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = actor.position + Vector2(14, 0)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8, 300)
	collision.shape = rectangle
	wall.add_child(collision)
	stage.add_child(wall)
	for frame in range(20): await physics_frame
	var blocked_distance := actor._visual_distance
	var blocked_pose := view.sample(actor)
	for frame in range(20): await physics_frame
	check(absf(actor._visual_distance - blocked_distance) < .1 and actor._visual_speed < .1, "A real wall stops stride travel despite held movement input")
	check(view.sample(actor)["state"] == "idle" and blocked_pose["state"] == "idle", "Blocked Senu plants his feet instead of walking in place")
	Input.action_release("move_right")
	actor.set_physics_process(false)
	var enemy_breath := {}
	var enemy_bounds := true
	for frame in range(240):
		var motion := EnemyView.motion_sample(0, 0, false, Vector2.RIGHT, 0, 0, Vector2.ZERO, frame / 60.0)
		enemy_breath[motion["upper_offset"]] = true
		enemy_bounds = enemy_bounds and intact(motion, 1)
	check(enemy_breath.size() == 2 and enemy_bounds, "Enemy idle chest breathes one pixel while feet remain fixed")
	for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var recoil := EnemyView.motion_sample(1, 0, false, -direction, 0, 1, direction)
		var settled := EnemyView.motion_sample(1, 0, false, -direction, 0, .01, direction)
		check((recoil["upper_offset"] as Vector2).dot(direction) > 0 and intact(recoil, 2), "Enemy recoil follows impact rather than its facing direction")
		check((settled["upper_offset"] as Vector2).length() < (recoil["upper_offset"] as Vector2).length(), "Enemy impact weight decays to its planted stance")
	var enemy := VeilEnemy.new()
	enemy.position = Vector2(300, 200)
	stage.add_child(enemy)
	enemy.set_physics_process(false)
	var collider: CollisionShape2D = enemy.get_child(0)
	var enemy_before := [enemy.transform, enemy.health, enemy.state_timer, enemy.collision_layer, enemy.collision_mask, collider.transform, collider.shape.radius]
	for state in range(7):
		var valid := true
		for frame in range(61):
			var motion := EnemyView.motion_sample(state, frame * .5, state == 1, Vector2.RIGHT, frame / 60.0, 0, Vector2.ZERO, frame / 60.0)
			valid = valid and intact(motion, 2)
		check(valid, "Enemy state %d keeps procedural displacement bounded and feet fixed" % state)
	check(enemy_before == [enemy.transform, enemy.health, enemy.state_timer, enemy.collision_layer, enemy.collision_mask, collider.transform, collider.shape.radius], "Enemy presentation cannot change collision, health, root or state clock")
	var coil := EnemyView.motion_sample(2, 0, false, Vector2.RIGHT, 1)
	var release := EnemyView.motion_sample(3, 0, false, Vector2.RIGHT, 0)
	var recovery := EnemyView.motion_sample(4, 0, false, Vector2.RIGHT, 1)
	check(coil["upper_offset"].x < 0 and release["upper_offset"].x > 0 and recovery["upper_offset"] == Vector2.ZERO, "Enemy loads, follows through and recovers without relocating the foot pivot")
	enemy.receive_hit(1, enemy.position + Vector2(20, 0))
	check(enemy._hurt_direction.x < -.99, "Enemy stores incoming hit direction independently from body facing")
	enemy.reset_enemy()
	check(enemy._hurt_direction == Vector2.ZERO, "Enemy checkpoint reset clears procedural impact memory")
	stage.queue_free()
	await process_frame
	print("ACTOR MOTION CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)
