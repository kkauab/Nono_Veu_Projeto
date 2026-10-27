extends SceneTree
## Skill mechanics in an isolated world. No store, main scene, or real save.

const Inputs = preload("res://scripts/core/input_bindings.gd")
const CombatFx = preload("res://scripts/actors/combat_fx.gd")
const MercurySeal = preload("res://scripts/actors/mercury_projectile.gd")

class SkillTarget extends StaticBody2D:
	var health: int = 400
	var dead: bool = false
	var is_boss: bool = false
	var state: int = 0
	var hits: Array[int] = []
	func _ready() -> void:
		add_to_group("enemies")
		collision_layer = 4
		collision_mask = 0
		var shape := CircleShape2D.new()
		shape.radius = 7.0
		var collider := CollisionShape2D.new()
		collider.shape = shape
		add_child(collider)
	func receive_hit(amount: int, _from: Vector2, _stagger: bool = false) -> void:
		hits.append(amount)
		health -= amount
		dead = health <= 0

var checks: int = 0
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
	CombatFx.hitstop_enabled = false
	await _check_configuration_and_attacks()
	await _check_parry_and_damage()
	await _check_projectiles()
	await _check_dodge_collision()
	CombatFx.hitstop_enabled = true
	CombatFx.end_hitstop()
	print("SKILL COMBAT CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func _stage() -> Node2D:
	var world := Node2D.new()
	root.add_child(world)
	return world


func _player(world: Node2D) -> SenuPlayer:
	var player := SenuPlayer.new()
	world.add_child(player)
	player.set_physics_process(false)
	player._fx.set_physics_process(false)
	player.weapon_unlocked[1] = true
	return player


func _target(world: Node2D, at: Vector2) -> SkillTarget:
	var target := SkillTarget.new()
	target.position = at
	world.add_child(target)
	return target


func _clean(world: Node2D) -> void:
	world.queue_free()
	await process_frame
	await physics_frame


func _ready_attack(player: SenuPlayer) -> void:
	player.attack_timer = 0.0
	player._hit_delay = -1.0
	player._second_hit_delay = -1.0


func _latest_shot() -> Node2D:
	var shots: Array[Node] = get_nodes_in_group("mercury_projectiles")
	if shots.is_empty():
		return null
	var shot: Node2D = shots.back()
	shot.set_physics_process(false)
	return shot


func _fly(shot: Node2D) -> void:
	for frame: int in range(100):
		if not shot.flying:
			break
		shot._physics_process(1.0 / 60.0)


func _check_configuration_and_attacks() -> void:
	var world := _stage()
	var player := _player(world)
	await physics_frame
	check(not player.try_seal() and get_nodes_in_group("mercury_projectiles").is_empty(), "Locked seal cannot cast or create a projectile")
	var source: Array = ["ritmo_lamina", "pele_alabastro", "ritmo_lamina"]
	player.damage_bonus = 4
	player.max_health = 120
	player.dodge_cooldown = 0.66 * 0.8
	player.dodge_invulnerability = 0.28 + 0.06
	player.power_cooldown_scale = 0.8
	player.configure_skills(source)
	player.configure_skills(source)
	source.append("selo_mercurio")
	check(player.learned_skills.size() == 2 and not player.has_skill("selo_mercurio"), "Configuration is deduplicated and does not alias the save Array")
	check(player.damage_bonus == 4 and player.max_health == 120 and is_equal_approx(player.power_cooldown_scale, 0.8), "Applying ownership repeatedly does not stack world-owned root bonuses")
	check(is_equal_approx(player.dodge_cooldown, .528) and is_equal_approx(player.dodge_invulnerability, .34), "World-owned dodge bases are not scaled a second time")
	player.damage_bonus = 0
	player.max_health = 100
	player.reset_at(Vector2.ZERO)
	player.configure_skills([])
	var baseline: Array[int] = []
	for i: int in range(3):
		_ready_attack(player)
		player.try_attack()
		baseline.append(player._attack_damage)
	check(baseline == [22, 22, 27] and is_equal_approx(player._combo_timer, .82), "Unlearned rhythm keeps the existing sword combo")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["ritmo_lamina"])
	var improved: Array[int] = []
	for i: int in range(3):
		_ready_attack(player)
		player.try_attack()
		improved.append(player._attack_damage)
	check(improved == [22, 22, 35] and is_equal_approx(player._combo_timer, 1.15), "Rhythm extends the combo window and adds eight to the third light attack")
	_ready_attack(player)
	player.try_attack(true)
	_ready_attack(player)
	player.try_attack()
	check(player._combo_step == 1, "A heavy strike cannot count toward the learned three-light finisher")
	player.reset_at(Vector2.ZERO)
	player.configure_skills([])
	player.try_attack(true)
	check(player._attack_damage == 37 and is_equal_approx(player._attack_range, 50), "Unlearned ascending strike keeps base heavy damage and reach")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["lamina_ascendente"])
	player.try_attack(true)
	check(player._attack_damage == 57 and is_equal_approx(player._attack_range, 64) and player._ascending_visual > 0.0, "Ascending khopesh adds twenty damage, fourteen reach and readable FX")
	player.reset_at(Vector2.ZERO)
	player.equip_weapon(1)
	player.try_attack(true)
	check(player._attack_damage == 17 and is_equal_approx(player._attack_range, 39), "Ascending strike does not upgrade dagger heavy attacks")
	await _clean(world)


func _check_parry_and_damage() -> void:
	var world := _stage()
	var player := _player(world)
	var enemy := _target(world, Vector2(28, 0))
	await physics_frame
	player.configure_skills([])
	player.invulnerability_timer = 0.0
	player.receive_hit(20, enemy.position)
	check(player.health == 80, "Locked alabaster does not reduce incoming damage")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["pele_alabastro"])
	player.invulnerability_timer = 0.0
	player.receive_hit(20, enemy.position)
	check(player.health == 83, "Alabaster reduces received damage by fifteen percent")
	player.reset_at(Vector2.ZERO)
	player.invulnerability_timer = 0.0
	player.facing = Vector2.RIGHT
	player.try_parry()
	check(not player.receive_hit(20, enemy.position) and player.health == 100, "Parry is evaluated before the damage-reduction effect")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["contra_ataque_agil"])
	player.invulnerability_timer = 0.0
	player.facing = Vector2.RIGHT
	player.dodge_cooldown_remaining = .5
	player.try_parry()
	player.receive_hit(20, enemy.position)
	check(is_zero_approx(player.dodge_cooldown_remaining) and is_equal_approx(player._counter_timer, 2.8), "Agile counter refreshes dodge and opens a finite reward window")
	player.try_attack(true)
	check(player._attack_damage == 37 and player._counter_timer > 0.0, "Heavy attacks neither receive nor consume the agile light reward")
	_ready_attack(player)
	player.try_power()
	check(player._attack_damage == 62 and player._counter_timer > 0.0, "Weapon power does not consume or add the agile light reward")
	_ready_attack(player)
	player._combo_timer = 0.0
	player.try_attack()
	check(player._attack_damage == 34 and is_zero_approx(player._counter_timer), "The next light attack receives twelve bonus damage exactly once")
	player._apply_attack()
	check(player._attack_damage == 22 and player._counter_attack_bonus == 0, "The contact consumes the bonus rather than carrying it into later hits")
	player.reset_at(Vector2.ZERO)
	player.equip_weapon(1)
	player._counter_timer = 2.8
	player.try_attack()
	check(player._attack_damage == 22, "Agile counter works with the dagger light move")
	player._apply_attack()
	player._apply_attack()
	check(enemy.hits.slice(-2) == [22, 10], "The dagger's second cut does not duplicate the twelve-point reward")
	player.reset_at(Vector2.ZERO)
	player._counter_timer = .01
	player._physics_process(.02)
	player.try_attack()
	check(player._attack_damage == 10, "An expired counter cannot be spent later")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["reflexo_palavra"])
	player.equip_weapon(0)
	player.invulnerability_timer = 0.0
	player.facing = Vector2.RIGHT
	player.try_parry()
	player.receive_hit(20, enemy.position)
	var reflected := _latest_shot()
	check(reflected != null and reflected.damage == 24 and reflected.direction.dot(Vector2.RIGHT) > .99, "Word reflection launches twenty-four damage toward the aggressor")
	if reflected != null:
		var before: int = enemy.health
		_fly(reflected)
		check(enemy.health == before - 24, "The reflected projectile actually damages its target")
	check(not player.try_seal(), "Reflection does not silently unlock manual seal casting")
	await _clean(world)


func _check_projectiles() -> void:
	var world := _stage()
	var player := _player(world)
	var targets: Array[SkillTarget] = []
	for x: float in [50.0, 100.0, 150.0, 200.0]:
		targets.append(_target(world, Vector2(x, 0)))
	await physics_frame
	player.configure_skills(["selo_mercurio"])
	check(player.try_seal() and is_equal_approx(player.seal_cooldown_remaining, 8.0), "Manual seal starts its eight-second cooldown")
	var basic := _latest_shot()
	check(basic != null and basic.damage == 32 and basic.max_targets == 1 and is_equal_approx(basic.max_range, 260), "Base seal has the configured damage, single target and range")
	_ready_attack(player)
	check(not player.try_seal(), "Cooldown rejects repeated casts without spawning another seal")
	_fly(basic)
	check(targets[0].health == 368 and targets[1].health == 400 and basic.hit_count == 1, "Base seal stops at the first target")
	basic.queue_free()
	await process_frame
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["selo_mercurio", "convergencia_nous"])
	for target: SkillTarget in targets:
		target.health = 400
		target.hits.clear()
	check(player.try_seal() and is_equal_approx(player.seal_cooldown_remaining, 6.0), "Convergence changes new casts to a six-second cooldown")
	var piercing := _latest_shot()
	_fly(piercing)
	check(piercing.hit_count == 3 and targets[0].health == 368 and targets[1].health == 368 and targets[2].health == 368 and targets[3].health == 400, "Convergence pierces exactly three enemies and stops before the fourth")
	check(targets[0].hits == [32] and targets[1].hits == [32] and targets[2].hits == [32], "Piercing cannot hit an excluded enemy a second time")
	player.configure_skills(["selo_mercurio", "convergencia_nous"])
	check(is_equal_approx(player.seal_cooldown_remaining, 6.0), "Reapplying learned skills does not reset an active spell cooldown")
	piercing.queue_free()
	await process_frame
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var segment := SegmentShape2D.new()
	segment.a = Vector2(30, -30)
	segment.b = Vector2(30, 30)
	var collider := CollisionShape2D.new()
	collider.shape = segment
	wall.add_child(collider)
	world.add_child(wall)
	for target: SkillTarget in targets:
		target.health = 400
	await physics_frame
	player.reset_at(Vector2.ZERO)
	player.try_seal()
	var blocked := _latest_shot()
	blocked._physics_process(1.0)
	check(blocked.blocked_by_scenery and not blocked.flying and blocked.global_position.x <= 30.1, "A swept cast cannot tunnel through a thin closed gate even at a long physics step")
	check(targets.all(func(target: SkillTarget): return target.health == 400), "Piercing cannot damage targets behind the closed gate")
	wall.queue_free()
	blocked.queue_free()
	for target: SkillTarget in targets:
		target.queue_free()
	await process_frame
	await physics_frame
	var ranged: Node2D = MercurySeal.new()
	ranged.direction = Vector2(1, 1).normalized()
	world.add_child(ranged)
	ranged.set_physics_process(false)
	ranged._physics_process(2.0)
	var metric_position := Vector2(ranged.position.x, ranged.position.y / .70)
	check(not ranged.flying and is_equal_approx(ranged.travelled_distance, 260) and is_equal_approx(metric_position.length(), 260), "Diagonal seals expire at the same metric range as horizontal seals")
	await _clean(world)


func _check_dodge_collision() -> void:
	var world := _stage()
	var player := _player(world)
	player.facing = Vector2.RIGHT
	player.configure_skills([])
	check(player.try_dodge() and player.collision_mask == 5, "Unlearned dodge keeps enemy collision")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["esquiva_eterea", "passo_etereo"])
	player.dodge_cooldown = .66 * .8
	player.dodge_invulnerability = .28 + .06
	check(player.try_dodge() and player.collision_mask == 1, "Ethereal dodge ignores enemies but retains scenery collision")
	check(is_equal_approx(player.dodge_cooldown_remaining, .528) and is_equal_approx(player.invulnerability_timer, .34), "The dodge uses configured cooldown and extended invulnerability")
	player._dodge_timer = .005
	player._physics_process(.01)
	check(player.collision_mask == 5 and player._phase_mask_backup == -1, "Enemy collision returns when the dodge finishes")
	player.reset_at(Vector2.ZERO)
	player.try_dodge()
	player.configure_skills([])
	check(player.collision_mask == 5, "Removing the skill cannot leave collision disabled")
	player.reset_at(Vector2.ZERO)
	player.configure_skills(["esquiva_eterea"])
	player.try_dodge()
	player.invulnerability_timer = 0.0
	player.receive_hit(1000, Vector2(-20, 0))
	check(player.dead and player.collision_mask == 5, "Death restores collision even during an ethereal dodge")
	player.reset_at(Vector2.ZERO)
	check(player.collision_mask == 5 and player.has_skill("esquiva_eterea"), "Checkpoint reset preserves learned ownership while restoring collision")
	var enemy := _target(world, Vector2(25, 0))
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var shape := SegmentShape2D.new()
	shape.a = Vector2(45, -35)
	shape.b = Vector2(45, 35)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	await physics_frame
	player.facing = Vector2.RIGHT
	player.set_physics_process(true)
	player.try_dodge()
	for frame: int in range(26):
		await physics_frame
	player.set_physics_process(false)
	check(player.position.x > enemy.position.x + 7 and player.position.x < 40, "Ethereal dodge crosses an enemy body but stops before the wall")
	check(player.collision_mask == 5, "Collision is restored after a real sequence of physics frames")
	await _clean(world)
