extends SceneTree
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
	root.add_child(actor)
	actor.set_physics_process(false)
	for definition in [["guard",false,5],["runner",false,4],["lancer",false,6],["keeper",false,7],["keeper",true,18]]:
		actor.reset_at(Vector2.ZERO)
		actor.facing = Vector2.RIGHT
		var enemy := VeilEnemy.new()
		enemy.archetype = definition[0]
		enemy.is_boss = definition[1]
		enemy.position = Vector2(26,0)
		root.add_child(enemy)
		enemy.set_physics_process(false)
		var hits := 0
		while not enemy.dead and hits < 25:
			check(actor.try_attack(), "%s accepts normal attack %d" % [definition[0],hits+1])
			actor._physics_process(.121)
			hits += 1
			if definition[0] == "guard" and not definition[1] and hits == 4:
				check(not enemy.dead and enemy.health > 0, "Guard survives four actual normal combo contacts")
			actor._physics_process(.319)
		check(hits == int(definition[2]), "%s boss=%s dies after %d real normal contacts (got %d)" % [definition[0],definition[1],definition[2],hits])
		check(enemy.dead and enemy.collision_layer == 0, "Defeat still removes the collision and enters death")
		enemy.reset_enemy()
		check(not enemy.dead and enemy.health == enemy.max_health, "Checkpoint reset restores the new maximum health")
		enemy.free()
	actor.free()
	print("ENEMY V9 BALANCE CHECKS: %d passed=%d failures=%s" % [checks,checks-failures.size(),failures])
	quit(1 if not failures.is_empty() else 0)
