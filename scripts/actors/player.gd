class_name SenuPlayer
extends CharacterBody2D

signal stats_changed
signal died
signal combat_feedback(text: String, color: Color)

const ISO_Y: float = 0.70
const KHOPESH: WeaponDefinition = preload("res://resources/weapons/khopesh.tres")
const DAGGERS: WeaponDefinition = preload("res://resources/weapons/daggers.tres")
const SENU_BODY: Texture2D = preload("res://assets/sprites/senu_v2.png")
const SENU_FRAME := Vector2(96, 112)
const SENU_PIVOT := Vector2(48, 94)
const SENU_SCALE: float = 0.43
const SuppliedSpriteView = preload("res://scripts/actors/senu_supplied_view.gd")
const CombatFx = preload("res://scripts/actors/combat_fx.gd")
const MercurySeal = preload("res://scripts/actors/mercury_projectile.gd")

@export var move_speed: float = 80.0
@export var sprint_multiplier: float = 1.70
@export var max_health: int = 100
@export var dodge_speed: float = 187.5
@export var dodge_duration: float = 0.32
@export var dodge_invulnerability: float = 0.28
@export var shadow_invulnerability: float = 0.40
@export var dodge_cooldown: float = 0.66
@export var parry_window: float = 0.25

var health: int = 100
var weapon_index: int = 0
var weapons: Array[WeaponDefinition] = [KHOPESH, DAGGERS]
var weapon_unlocked: Array[bool] = [true, false]
var damage_bonus: int = 0
var power_cooldown_scale: float = 1.0
var controls_enabled: bool = true
var facing: Vector2 = Vector2.RIGHT
var power_cooldown_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var parry_cooldown_remaining: float = 0.0
var attack_timer: float = 0.0
var parry_timer: float = 0.0
var invulnerability_timer: float = 0.0
var dead: bool = false
var is_sprinting: bool = false
## Runtime configuration only; the save/catalog remains the source of ownership.
var learned_skills: Array = []
var seal_cooldown_remaining: float = 0.0

var _dodge_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.RIGHT
var _hit_delay: float = -1.0
var _second_hit_delay: float = -1.0
var _attack_direction: Vector2 = Vector2.RIGHT
var _attack_damage: int = 0
var _attack_range: float = 0.0
var _attack_arc: float = 0.0
var _attack_stagger: bool = false
var _attack_visual: float = 0.0
var _power_visual: float = 0.0
var _hurt_visual: float = 0.0
## Presentation only: actual travel after collision, never the requested velocity.
var _visual_distance: float = 0.0
var _visual_speed: float = 0.0
var _hurt_direction := Vector2.ZERO
var _riposte_timer: float = 0.0
var _shadow_finish: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _time: float = 0.0
var _combo_step: int = 0
var _combo_timer: float = 0.0
var _last_cooldown_display: int = 0
var _power_cooldowns: Array[float] = [0.0, 0.0]
var _senu_metadata: Dictionary = {}
var _senu_attack_peak: float = 0.19
var _senu_last_attack_visual: float = 0.0
var _supplied_view: SuppliedSpriteView = SuppliedSpriteView.new()
var _event_mouse_world := Vector2.INF
var _fx: CombatFx = CombatFx.new()
var _counter_timer: float = 0.0
var _counter_attack_bonus: int = 0
var _ascending_visual: float = 0.0
var _seal_cast_visual: float = 0.0
var _last_seal_display: int = 0
var _phase_mask_backup: int = -1


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	collider.shape = shape
	add_child(collider)
	_fx.name = "CombatFx"
	add_child(_fx)
	health = clampi(health, 0, max_health)
	stats_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	var mouse_aim: bool = event is InputEventMouseButton
	if mouse_aim:
		_event_mouse_world = get_viewport().get_canvas_transform().affine_inverse() * event.position
	if event.is_action_pressed("attack"):
		try_attack(false, mouse_aim)
	elif InputMap.has_action("heavy_attack") and event.is_action_pressed("heavy_attack"):
		try_attack(true, mouse_aim)
	elif event.is_action_pressed("weapon_power"):
		try_power(mouse_aim)
	elif InputMap.has_action("cast_seal") and event.is_action_pressed("cast_seal"):
		try_seal(mouse_aim)
	elif event.is_action_pressed("dodge"):
		try_dodge()
	elif event.is_action_pressed("parry"):
		try_parry(mouse_aim)
	elif event.is_action_pressed("switch_weapon"):
		equip_weapon((weapon_index + 1) % weapons.size())
	_event_mouse_world = Vector2.INF


func _physics_process(delta: float) -> void:
	_time += delta
	_visual_speed = 0.0
	is_sprinting = false
	attack_timer = maxf(0.0, attack_timer - delta)
	parry_timer = maxf(0.0, parry_timer - delta)
	parry_cooldown_remaining = maxf(0.0, parry_cooldown_remaining - delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	_attack_visual = maxf(0.0, _attack_visual - delta)
	_power_visual = maxf(0.0, _power_visual - delta)
	_hurt_visual = maxf(0.0, _hurt_visual - delta)
	_riposte_timer = maxf(0.0, _riposte_timer - delta)
	_combo_timer = maxf(0.0, _combo_timer - delta)
	_counter_timer = maxf(0.0, _counter_timer - delta)
	_ascending_visual = maxf(0.0, _ascending_visual - delta)
	_seal_cast_visual = maxf(0.0, _seal_cast_visual - delta)
	seal_cooldown_remaining = maxf(0.0, seal_cooldown_remaining - delta)
	for i: int in range(_power_cooldowns.size()):
		_power_cooldowns[i] = maxf(0.0, _power_cooldowns[i] - delta)
	power_cooldown_remaining = _power_cooldowns[weapon_index]
	var display_cooldown: int = ceili(power_cooldown_remaining)
	if display_cooldown != _last_cooldown_display:
		_last_cooldown_display = display_cooldown
		stats_changed.emit()
	var seal_display: int = ceili(seal_cooldown_remaining)
	if seal_display != _last_seal_display:
		_last_seal_display = seal_display
		stats_changed.emit()
	if dead:
		_restore_phase_collision()
		velocity = Vector2.ZERO
		queue_redraw()
		return
	if _hit_delay >= 0.0:
		_hit_delay -= delta
		if _hit_delay < 0.0:
			_apply_attack()
			if _second_hit_delay >= 0.0:
				_fx.swing("leve", false)
	if _second_hit_delay >= 0.0:
		_second_hit_delay -= delta
		if _second_hit_delay < 0.0:
			_attack_visual = 0.12
			_apply_attack()
	var was_dodging := _dodge_timer > 0.0
	if was_dodging:
		var remaining := _dodge_timer
		_dodge_timer = maxf(0, _dodge_timer - delta)
		# O último passo parcial conserva o alcance mesmo entre taxas de física.
		var step_fraction := minf(1, remaining / maxf(.0001, delta))
		velocity = Vector2(_dodge_direction.x, _dodge_direction.y * ISO_Y) * dodge_speed * step_fraction
		if _dodge_timer <= 0.0 and _shadow_finish:
			_shadow_finish = false
			_damage_nearby(24 + damage_bonus, 39.0, TAU, _dodge_direction, true)
			_power_visual = 0.23
	else:
		var movement := Vector2.ZERO
		if controls_enabled:
			movement = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if movement.length_squared() > 0.01:
			facing = movement.normalized()
		var movement_factor: float = 1.0
		if attack_timer > 0.0:
			movement_factor = 0.36
		if parry_timer > 0.0:
			movement_factor = 0.22
		is_sprinting = controls_enabled and movement.length_squared() > .01 and attack_timer <= 0 and parry_timer <= 0 and _hurt_visual <= 0 and InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
		if is_sprinting:
			movement_factor *= maxf(1, sprint_multiplier)
		velocity = Vector2(movement.x, movement.y * ISO_Y) * move_speed * movement_factor
	_knockback = _knockback.move_toward(Vector2.ZERO, 700.0 * delta)
	velocity += _knockback
	move_and_slide()
	if _hurt_visual <= 0.0 and not was_dodging:
		var travel := _metric(get_position_delta()).length()
		_visual_speed = travel / maxf(.0001, delta)
		_visual_distance += travel
	if _dodge_timer <= 0.0:
		_restore_phase_collision()
	queue_redraw()


func equipped_weapon() -> WeaponDefinition:
	return weapons[weapon_index]


func configure_skills(skills: Array) -> void:
	# Copy ownership rather than retaining the save's mutable Array. Effects are
	# derived from IDs, so applying the same configuration never stacks bonuses.
	var normalized: Array = []
	for id: Variant in skills:
		if id is String and id not in normalized:
			normalized.append(id)
	learned_skills = normalized
	if not has_skill("contra_ataque_agil"):
		_counter_timer = 0.0
		_counter_attack_bonus = 0
	if not has_skill("esquiva_eterea"):
		_restore_phase_collision()


func has_skill(id: String) -> bool:
	return id in learned_skills


func equip_weapon(index: int) -> bool:
	if index < 0 or index >= weapons.size() or not weapon_unlocked[index]:
		return false
	if dead or attack_timer > 0.0 or _dodge_timer > 0.0 or parry_timer > 0.0:
		return false
	weapon_index = index
	_hit_delay = -1.0
	_second_hit_delay = -1.0
	_attack_visual = 0.0
	_power_visual = 0.0
	_shadow_finish = false
	_combo_step = 0
	_combo_timer = 0.0
	_riposte_timer = 0.0
	_counter_attack_bonus = 0
	power_cooldown_remaining = _power_cooldowns[weapon_index]
	stats_changed.emit()
	queue_redraw()
	return true


func try_attack(heavy: bool = false, use_mouse: bool = false) -> bool:
	if not _can_act():
		return false
	var weapon: WeaponDefinition = equipped_weapon()
	_attack_direction = _aim_direction(use_mouse)
	facing = _attack_direction
	if _combo_timer <= 0.0 or (heavy and has_skill("ritmo_lamina")):
		_combo_step = 0
	if not heavy or not has_skill("ritmo_lamina"):
		_combo_step = (_combo_step + 1) % 3
	_combo_timer = 1.15 if has_skill("ritmo_lamina") and not heavy else 0.82
	_attack_damage = weapon.damage + damage_bonus
	_counter_attack_bonus = 0
	_attack_range = weapon.range_px
	_attack_arc = deg_to_rad(weapon.arc_degrees)
	_attack_stagger = heavy or _combo_step == 0
	attack_timer = weapon.attack_interval
	# The khopesh needs a readable coil and acceleration before its contact.
	# Daggers keep their separate fast two-hit rhythm.
	_hit_delay = 0.12 if weapon.category == "espada" else 0.075
	_second_hit_delay = -1.0
	_attack_visual = 0.19
	if heavy:
		_attack_damage = roundi(float(_attack_damage) * 1.70)
		_attack_range += 8.0
		_attack_arc *= 1.15
		attack_timer *= 1.75
		_hit_delay = 0.24
		_attack_visual = 0.36
		if has_skill("lamina_ascendente") and weapon.id == KHOPESH.id:
			_attack_damage += 20
			_attack_range += 14.0
			_ascending_visual = 0.46
			combat_feedback.emit("LÂMINA ASCENDENTE", Color("f2d58f"))
	elif weapon.category == "leve":
		_second_hit_delay = 0.17
	else:
		if _combo_step == 0:
			_attack_damage += 5
	if not heavy:
		if has_skill("ritmo_lamina") and _combo_step == 0:
			_attack_damage += 8
		if has_skill("contra_ataque_agil") and _counter_timer > 0.0:
			_counter_attack_bonus = 12
			_attack_damage += _counter_attack_bonus
			_counter_timer = 0.0
			combat_feedback.emit("CONTRA-ATAQUE ÁGIL", Color("f0d5a2"))
	_fx.swing(weapon.category, heavy)
	stats_changed.emit()
	return true


func try_dodge() -> bool:
	if not _can_act() or dodge_cooldown_remaining > 0.0:
		return false
	var movement: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dodge_direction = movement.normalized() if movement.length_squared() > 0.01 else facing
	_dodge_timer = dodge_duration
	invulnerability_timer = dodge_invulnerability
	dodge_cooldown_remaining = dodge_cooldown
	_begin_phase_dodge()
	_fx.dodge()
	stats_changed.emit()
	return true


func try_parry(use_mouse: bool = false) -> bool:
	if not _can_act() or parry_cooldown_remaining > 0.0:
		return false
	facing = _aim_direction(use_mouse)
	parry_timer = parry_window
	parry_cooldown_remaining = 0.67
	stats_changed.emit()
	return true


func try_power(use_mouse: bool = false) -> bool:
	if not _can_act() or _power_cooldowns[weapon_index] > 0.0:
		return false
	var weapon: WeaponDefinition = equipped_weapon()
	_power_cooldowns[weapon_index] = weapon.power_cooldown * power_cooldown_scale
	power_cooldown_remaining = _power_cooldowns[weapon_index]
	facing = _aim_direction(use_mouse)
	_power_visual = 0.40
	_fx.power(weapon.power_id)
	if weapon.power_id == "passo_sombra":
		_dodge_direction = facing
		_dodge_timer = dodge_duration * 1.40
		invulnerability_timer = shadow_invulnerability
		_shadow_finish = true
		_begin_phase_dodge()
		_damage_nearby(12 + damage_bonus, 33.0, TAU, facing, false)
		combat_feedback.emit("PASSO DE SOMBRA", Color("aaa9f0"))
	else:
		_attack_direction = facing
		_attack_range = 58.0
		_attack_arc = deg_to_rad(175.0)
		_attack_damage = 36 + damage_bonus
		if _riposte_timer > 0.0:
			_attack_damage = 62 + damage_bonus
			_riposte_timer = 0.0
			combat_feedback.emit("RIPOSTA PERFEITA", Color("ffe0a2"))
		else:
			combat_feedback.emit("RIPOSTA HERMÉTICA", Color("e8bd75"))
		_attack_stagger = true
		attack_timer = 0.72
		_attack_visual = 0.34
		_hit_delay = 0.15
		_second_hit_delay = -1.0
	stats_changed.emit()
	return true


func try_seal(use_mouse: bool = false) -> bool:
	if not has_skill("selo_mercurio") or not _can_act() or seal_cooldown_remaining > 0.0:
		return false
	facing = _aim_direction(use_mouse)
	seal_cooldown_remaining = 6.0 if has_skill("convergencia_nous") else 8.0
	attack_timer = 0.28
	_counter_attack_bonus = 0
	_seal_cast_visual = 0.38
	_spawn_mercury(facing, 32, 3 if has_skill("convergencia_nous") else 1)
	combat_feedback.emit("SELO DE MERCÚRIO", Color("e5d6a0"))
	stats_changed.emit()
	return true


func _spawn_mercury(direction: Vector2, damage: int, max_targets: int) -> Node2D:
	var projectile: Node2D = MercurySeal.new()
	projectile.direction = direction.normalized() if direction.length_squared() > 0.01 else facing
	projectile.damage = damage
	projectile.max_targets = max_targets
	projectile.originator = self
	projectile.struck.connect(_on_mercury_hit)
	# Starting at the feet avoids spawning on the far side of a nearby wall.
	get_parent().add_child(projectile)
	projectile.global_position = global_position
	projectile.shot_origin = global_position
	return projectile


func _on_mercury_hit(enemy: Node2D, was_killed: bool) -> void:
	_fx.enemy_hit(enemy, false, was_killed, false)


func _begin_phase_dodge() -> void:
	if not has_skill("esquiva_eterea") or _phase_mask_backup >= 0:
		return
	_phase_mask_backup = collision_mask
	# The environment bit stays enabled; only enemy bodies can be crossed.
	set_collision_mask_value(3, false)


func _restore_phase_collision() -> void:
	if _phase_mask_backup < 0:
		return
	collision_mask = _phase_mask_backup
	_phase_mask_backup = -1


func receive_hit(damage: int, from_position: Vector2) -> bool:
	if dead or invulnerability_timer > 0.0:
		return false
	var incoming: Vector2 = _metric(from_position - global_position).normalized()
	if parry_timer > 0.0 and facing.dot(incoming) >= -0.1:
		parry_timer = 0.0
		invulnerability_timer = 0.34
		_riposte_timer = 2.80
		if has_skill("contra_ataque_agil"):
			dodge_cooldown_remaining = 0.0
			_counter_timer = 2.80
		if equipped_weapon().category == "espada":
			_power_cooldowns[weapon_index] = 0.0
			power_cooldown_remaining = 0.0
		_power_visual = 0.33
		_fx.parry(from_position)
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node2D and enemy.has_method("receive_hit"):
				var body: Node2D = enemy as Node2D
				if _metric(body.global_position - from_position).length() < 20.0:
					body.call("receive_hit", 5, global_position, true)
		if has_skill("reflexo_palavra"):
			_spawn_mercury(_metric(from_position - global_position), 24, 1)
		combat_feedback.emit("APARADO · Q PARA RIPOSTA", Color("ffe7a3"))
		stats_changed.emit()
		return false
	var received_damage: int = maxi(0, damage)
	if has_skill("pele_alabastro") and received_damage > 0:
		received_damage = maxi(1, roundi(float(received_damage) * 0.85))
	health = maxi(0, health - received_damage)
	invulnerability_timer = 0.58
	_hurt_visual = 0.22
	_hurt_direction = (global_position - from_position).normalized()
	parry_timer = 0.0
	_hit_delay = -1.0
	_second_hit_delay = -1.0
	_counter_attack_bonus = 0
	attack_timer = maxf(attack_timer, 0.18)
	_knockback = (global_position - from_position).normalized() * 88.0
	_fx.player_hurt(from_position, health <= 0)
	stats_changed.emit()
	if health <= 0:
		dead = true
		velocity = Vector2.ZERO
		_dodge_timer = 0.0
		_shadow_finish = false
		_restore_phase_collision()
		died.emit()
	return true


func heal_full() -> void:
	health = max_health
	stats_changed.emit()


func reset_at(spawn_position: Vector2) -> void:
	global_position = spawn_position
	dead = false
	is_sprinting = false
	health = max_health
	velocity = Vector2.ZERO
	attack_timer = 0.0
	parry_timer = 0.0
	_dodge_timer = 0.0
	_hit_delay = -1.0
	_second_hit_delay = -1.0
	_attack_visual = 0.0
	_power_visual = 0.0
	_hurt_visual = 0.0
	_visual_distance = 0.0
	_visual_speed = 0.0
	_hurt_direction = Vector2.ZERO
	_knockback = Vector2.ZERO
	_shadow_finish = false
	_riposte_timer = 0.0
	_combo_timer = 0.0
	_power_cooldowns = [0.0, 0.0]
	power_cooldown_remaining = 0.0
	dodge_cooldown_remaining = 0.0
	parry_cooldown_remaining = 0.0
	invulnerability_timer = 0.65
	seal_cooldown_remaining = 0.0
	_counter_timer = 0.0
	_counter_attack_bonus = 0
	_ascending_visual = 0.0
	_seal_cast_visual = 0.0
	_restore_phase_collision()
	stats_changed.emit()


func is_parrying() -> bool:
	return parry_timer > 0.0


func _can_act() -> bool:
	return controls_enabled and not dead and attack_timer <= 0.0 and _dodge_timer <= 0.0 and parry_timer <= 0.0


func _aim_direction(use_mouse: bool) -> Vector2:
	if use_mouse:
		var mouse_world := get_global_mouse_position() if _event_mouse_world == Vector2.INF else _event_mouse_world
		var aim: Vector2 = _metric(mouse_world - global_position)
		if aim.length_squared() > 9.0:
			return aim.normalized()
	return facing


func _metric(vector: Vector2) -> Vector2:
	return Vector2(vector.x, vector.y / ISO_Y)


func _apply_attack() -> void:
	_damage_nearby(_attack_damage, _attack_range, _attack_arc, _attack_direction, _attack_stagger)
	# The agile counter rewards one contact, not both cuts of a dagger attack.
	if _counter_attack_bonus > 0:
		_attack_damage -= _counter_attack_bonus
		_counter_attack_bonus = 0


func _damage_nearby(amount: int, reach: float, arc: float, direction: Vector2, stagger: bool) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D or not enemy.has_method("receive_hit"):
			continue
		var body: Node2D = enemy as Node2D
		var offset: Vector2 = _metric(body.global_position - global_position)
		var radius: float = 11.0
		if bool(body.get("is_boss")):
			radius = 18.0
		if offset.length() <= reach + radius and (offset.length() < 5.0 or direction.dot(offset.normalized()) >= cos(arc * 0.5)):
			var query := PhysicsRayQueryParameters2D.create(global_position, body.global_position, 1)
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				var was_dead := bool(body.get("dead"))
				body.call("receive_hit", amount, global_position, stagger)
				if not was_dead:
					_fx.enemy_hit(body, stagger, bool(body.get("dead")), equipped_weapon().category == "leve")


func _draw() -> void:
	var weapon: WeaponDefinition = equipped_weapon()
	if _supplied_view.draw(self):
		_draw_skill_fx()
		return
	var fade: float = 0.50 if dead else 1.0
	var direction: int = posmod(roundi((PI * .5 - facing.angle()) / (PI * .25)), 8)
	var row: int = 0
	var attack_progress: float = 0.0
	if _attack_visual > _senu_last_attack_visual:
		_senu_attack_peak = maxf(.01, _attack_visual)
	_senu_last_attack_visual = _attack_visual
	if _attack_visual > 0.0:
		attack_progress = 1.0 - clampf(_attack_visual / _senu_attack_peak, 0.0, 1.0)
		row = 5 + mini(2, int(attack_progress * 3.0))
	elif parry_timer > 0.0:
		row = 5
	elif _dodge_timer > 0.0:
		row = 3
	elif velocity.length() > 8.0 and not dead:
		row = 1 + posmod(int(_time * 8.0), 4)
	var source := Rect2(Vector2(direction * 96, row * 112), SENU_FRAME)
	var frame: int = row * 8 + direction
	var body_tint := Color(1, 1, 1, fade)
	if _hurt_visual > 0.0:
		body_tint = Color(1.65, 1.35, 1.12, fade)
	draw_ellipse_shadow(Vector2.ZERO, Vector2(11.0, 4.5), Color(0.01, 0.015, 0.02, 0.48))
	if _dodge_timer > 0.0:
		for echo: int in range(1, 4):
			var echo_offset: Vector2 = -Vector2(_dodge_direction.x, _dodge_direction.y * ISO_Y) * float(echo * 9)
			_draw_senu_body(source, echo_offset, Color(.55, .84, .85, .19 / float(echo)))
	if facing.y < -.25 and not dead:
		_draw_senu_weapons(frame, weapon, attack_progress, fade)
	_draw_senu_body(source, Vector2(0, -2) if _dodge_timer > 0.0 else Vector2.ZERO, body_tint)
	if facing.y >= -.25 and not dead:
		_draw_senu_weapons(frame, weapon, attack_progress, fade)
	if parry_timer > 0.0:
		_draw_sweep(facing, 19.0, 2.6, Color("f8d794"), 2.0)
	if _attack_visual > 0.0:
		var progress: float = 1.0 - clampf(_attack_visual / 0.34, 0.0, 1.0)
		var slash_color: Color = weapon.color
		slash_color.a = 0.55 + 0.4 * (1.0 - progress)
		_draw_sweep(_attack_direction, _attack_range * (0.62 + progress * 0.30), _attack_arc, slash_color, 3.0)
	if _power_visual > 0.0:
		var power_color: Color = weapon.color
		power_color.a = _power_visual * 1.7
		_draw_sweep(facing, 24.0 + (0.4 - _power_visual) * 55.0, TAU, power_color, 1.0)
	if invulnerability_timer > 0.0 and fmod(_time, 0.16) < 0.065:
		draw_circle(Vector2(0, -20), 3.0, Color(1, 0.94, 0.76, 0.75))
	_draw_skill_fx()


func _draw_skill_fx() -> void:
	if _ascending_visual > 0.0:
		var progress: float = 1.0 - _ascending_visual / 0.46
		var tint := Color(0.96, 0.80, 0.46, minf(1.0, _ascending_visual * 3.0))
		var origin := Vector2(facing.x * 6.0, -9.0 + facing.y * 4.0)
		var slash := PackedVector2Array()
		for i: int in range(8):
			var t: float = float(i) / 7.0
			slash.append(origin + Vector2(facing.x * (t * 25.0 + progress * 12.0), -sin(t * PI * 0.75) * 35.0 - progress * 10.0))
		draw_polyline(slash, tint, 2.0, false)
		for i: int in range(4):
			var spark := slash[mini(7, i * 2)] + Vector2(float(i * 3 - 4), -progress * 12.0)
			draw_rect(Rect2(spark.floor(), Vector2(2, 2)), tint)
	if _seal_cast_visual > 0.0:
		var radius: float = 7.0 + (0.38 - _seal_cast_visual) * 26.0
		var tint := Color(0.90, 0.83, 0.56, _seal_cast_visual * 2.3)
		var ring := PackedVector2Array()
		for i: int in range(9):
			var angle: float = TAU * float(i) / 8.0
			ring.append(Vector2(cos(angle) * radius, sin(angle) * radius * ISO_Y - 13.0))
		draw_polyline(ring, tint, 1.0, false)
	if _phase_mask_backup >= 0 and _dodge_timer > 0.0:
		for i: int in range(3):
			var offset := -Vector2(_dodge_direction.x, _dodge_direction.y * ISO_Y) * float(7 + i * 7)
			draw_rect(Rect2((offset + Vector2(-2, -11)).floor(), Vector2(3, 3)), Color(0.66, 0.63, 0.92, 0.42 - float(i) * 0.10))


func _draw_senu_body(source: Rect2, offset: Vector2, tint: Color) -> void:
	var scale_xy := Vector2(SENU_SCALE, SENU_SCALE * (.45 if dead else 1.0))
	draw_texture_rect_region(SENU_BODY, Rect2(-SENU_PIVOT * scale_xy + offset, SENU_FRAME * scale_xy), source, tint)


func _senu_hand(frame: int, side: String) -> Vector2:
	if _senu_metadata.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/senu_v2.json"))
		if parsed is Dictionary:
			_senu_metadata = parsed
	var anchors: Array = _senu_metadata.get("hands", [])
	if frame >= anchors.size():
		return Vector2(8 if side == "right" else -8, -18)
	var point: Array = anchors[frame][side]
	return (Vector2(float(point[0]), float(point[1])) - SENU_PIVOT) * SENU_SCALE


func _draw_senu_weapons(frame: int, weapon: WeaponDefinition, attack_progress: float, fade: float) -> void:
	var direction: Vector2 = _attack_direction if _attack_visual > 0.0 else facing
	var angle: float = direction.angle()
	if _attack_visual > 0.0:
		angle += lerpf(-.85, 1.05, attack_progress)
	var hand := _senu_hand(frame, "right")
	if _dodge_timer > 0.0:
		hand.y -= 2
	_draw_senu_blade(hand, angle, weapon.category == "leve", fade)
	if weapon.category == "leve":
		_draw_senu_blade(_senu_hand(frame, "left"), angle - .22, true, fade)


func _draw_senu_blade(hand: Vector2, angle: float, dagger: bool, fade: float) -> void:
	var outline: PackedVector2Array
	if dagger:
		outline = PackedVector2Array([Vector2(3, -1.5), Vector2(11, -1.5), Vector2(17, 0), Vector2(11, 1.5), Vector2(3, 1.5)])
	else:
		outline = PackedVector2Array([Vector2(3, -1), Vector2(12, -1), Vector2(16, -3), Vector2(19, -8), Vector2(22, -12), Vector2(24, -12), Vector2(24, -8), Vector2(23, -4), Vector2(21, 0), Vector2(18, 3), Vector2(13, 4), Vector2(3, 2)])
	var polygon := PackedVector2Array()
	for point in outline:
		var p: Vector2 = point.rotated(angle)
		polygon.append(hand + Vector2(p.x, p.y * ISO_Y))
	draw_colored_polygon(polygon, Color(.59, .47, .28, fade) if not dagger else Color(.73, .84, .78, fade))
	var grip: Vector2 = Vector2(4, 0).rotated(angle)
	draw_line(hand - Vector2(grip.x, grip.y * ISO_Y), hand + Vector2(grip.x, grip.y * ISO_Y), Color(.29, .19, .10, fade), 2)
	var edge := PackedVector2Array()
	for point in (PackedVector2Array([Vector2(4, -1), Vector2(11, -1), Vector2(17, 0)]) if dagger else PackedVector2Array([Vector2(4, -1), Vector2(12, -1), Vector2(16, -3), Vector2(19, -8), Vector2(22, -12), Vector2(24, -12)])):
		var p: Vector2 = point.rotated(angle)
		edge.append(hand + Vector2(p.x, p.y * ISO_Y))
	draw_polyline(edge, Color(.95, .85, .59, fade), 1)


func _draw_sweep(direction: Vector2, radius: float, angle_width: float, tint: Color, width: float) -> void:
	var points := PackedVector2Array()
	var start: float = direction.angle() - angle_width * 0.5
	for i: int in range(19):
		var angle: float = start + angle_width * float(i) / 18.0
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius * ISO_Y - 9.0))
	draw_polyline(points, tint, width, false)


func draw_ellipse_shadow(center: Vector2, radii: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i: int in range(20):
		var angle: float = TAU * float(i) / 20.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	draw_colored_polygon(points, tint)
