extends SceneTree

var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	for action: String in ["move_left", "move_right", "move_up", "move_down", "attack", "heavy_attack", "dodge", "parry", "switch_weapon", "weapon_power"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var world := Node2D.new()
	root.add_child(world)
	var player := SenuPlayer.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2.ZERO
	var enemy := VeilEnemy.new()
	enemy.target = player
	enemy.position = Vector2(26, 0)
	world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	check(player.weapons[0].category == "espada" and player.weapons[1].category == "leve", "Two distinct weapon categories")
	check(player.try_attack(), "Sword attack accepts ready state")
	player._apply_attack()
	check(enemy.health == enemy.max_health - 22, "Sword damage applied in arc")
	check(not player.try_attack(), "Attack recovery prevents repeated input")
	check(not player.equip_weapon(1), "Undiscovered weapon cannot be equipped")
	player.attack_timer = 0.0
	player.weapon_unlocked[1] = true
	check(player.equip_weapon(1), "Discovered alternative equips")
	check(player.try_attack(), "Dagger attack accepts ready state")
	player._apply_attack()
	player._apply_attack()
	check(enemy.health == enemy.max_health - 42, "Dagger dual strikes each apply their own damage")
	player.reset_at(Vector2.ZERO)
	check(player.try_dodge(), "Dodge accepts ready state")
	check(not player.receive_hit(14, Vector2(26, 0)) and player.health == 100, "Dodge prevents damage during invulnerability")
	player.reset_at(Vector2.ZERO)
	player.invulnerability_timer = 0.0
	player.equip_weapon(0)
	player.facing = Vector2.RIGHT
	check(player.try_parry(), "Parry accepts ready state")
	check(not player.receive_hit(14, Vector2(26, 0)) and player.health == 100, "Frontal parry blocks damage")
	check(enemy.state == VeilEnemy.State.STAGGER, "Parry staggers attacker")
	check(player.try_power(), "Parry grants sword riposte")
	check(player._attack_damage == 62, "Riposte has separate reward damage")
	check(not player.equip_weapon(1), "Cannot switch during committed power animation")
	player.attack_timer = 0.0
	check(player.equip_weapon(1), "Can switch after recovery")
	check(player.try_power(), "Alternative power has independent cooldown")
	player._dodge_timer = 0.0
	player.equip_weapon(0)
	check(not player.try_power(), "Switching does not reset sword power cooldown")
	player.reset_at(Vector2.ZERO)
	player.invulnerability_timer = 0.0
	check(player.receive_hit(1000, Vector2(26, 0)) and player.dead and player.health == 0, "Fatal damage emits dead state")
	player.reset_at(Vector2(10, 20))
	check(not player.dead and player.health == 100 and player.position == Vector2(10, 20), "Reset restores player at checkpoint")
	var boss := VeilEnemy.new()
	boss.is_boss = true
	boss.target = player
	boss.position = Vector2(100, 0)
	world.add_child(boss)
	boss.set_physics_process(false)
	boss._begin_windup()
	check(boss.attack_pattern == 0 and boss.state_timer >= 0.90, "Boss cone has visible windup")
	boss._begin_windup()
	check(boss.attack_pattern == 1 and boss.state_timer >= 1.12, "Boss alternates to radial attack")
	boss.receive_hit(22, player.global_position, true)
	check(boss.state == VeilEnemy.State.STAGGER, "Boss can be staggered")
	boss.state = VeilEnemy.State.CHASE
	boss.receive_hit(22, player.global_position, true)
	check(boss.state == VeilEnemy.State.CHASE, "Boss resistance prevents permanent heavy-attack stunlock")
	boss.receive_hit(5, player.global_position, true)
	check(boss.state == VeilEnemy.State.STAGGER, "Parry still interrupts boss during resistance")
	print("COMBAT CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
