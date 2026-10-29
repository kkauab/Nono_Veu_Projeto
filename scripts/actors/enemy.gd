class_name VeilEnemy
extends CharacterBody2D
const PixelView = preload("res://scripts/actors/enemy_pixel_view.gd")

signal defeated(enemy_id: String, is_boss: bool)

enum State { WAIT, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }

@export var enemy_id: String = "guard_01"
@export var is_boss: bool = false
@export var target: Node2D
@export var max_health: int = 110
@export var move_speed: float = 52.0
@export var detection_radius: float = 155.0
@export var archetype := "guard"

var health: int = 110
var state: State = State.WAIT
var dead: bool = false
var attack_pattern: int = 0
var state_timer: float = 0.0
var facing: Vector2 = Vector2.DOWN
var _attack_direction: Vector2 = Vector2.DOWN
var _attack_origin: Vector2 = Vector2.ZERO
var _strike_applied: bool = false
var _knockback: Vector2 = Vector2.ZERO
var _hurt_visual: float = 0.0
var _hurt_direction := Vector2.ZERO
var _breath_phase := 0.0
var _breath_pixel := 0.0
var _stagger_resistance_timer: float = 0.0
var _time: float = 0.0
var _attack_count: int = 0
var _windup_length: float = 0.80
var _strike_length: float = .22
var _recovery_length: float = .78
var _distance_walked := 0.0
var _animation_moving := false
var _visual_facing := Vector2.DOWN
var _spawn_position: Vector2 = Vector2.ZERO
var _normal_damage := 14
var _normal_reach := 42.0
var _normal_windup := .76
var _path_refresh := 0.0
var _path: PackedVector2Array = []
static var _navigation: AStar2D
static var _tile_ids: Dictionary = {}
static var _navigation_world_id := 0
static var _navigation_obstacle_buckets: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	match archetype:
		"runner":
			max_health = 85
			move_speed = 70
			_normal_damage = 10
			_normal_windup = .60
		"lancer":
			max_health = 135
			move_speed = 46
			_normal_damage = 17
			_normal_reach = 59
			_normal_windup = .98
		"keeper":
			max_health = 160
			move_speed = 38
			_normal_damage = 18
			_normal_windup = 1.08
	if is_boss:
		max_health = 400
		move_speed = 39.0
		detection_radius = 205.0
	health = max_health
	_spawn_position = global_position
	_breath_phase = float(posmod(hash(enemy_id), 997)) / 997.0 * TAU
	_breath_pixel = PixelView.rest_offset(_breath_phase)
	var collider := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	# Only the ground-contact area blocks movement; the enlarged upper sprite
	# does not create an invisible wall around the weapon/cape.
	shape.radius = 10.0 if is_boss else 6.0
	collider.shape = shape
	add_child(collider)


func _physics_process(delta: float) -> void:
	var previous_state := state
	var previous_hurt := _hurt_visual
	_time += delta
	# Idle artwork only needs rebuilding when its one-pixel breath changes,
	# instead of redrawing every sentinel at the physics rate.
	var breath_pixel := PixelView.rest_offset(_time + _breath_phase)
	if breath_pixel != _breath_pixel and state == State.WAIT:
		queue_redraw()
	_breath_pixel = breath_pixel
	_hurt_visual = maxf(0.0, _hurt_visual - delta)
	_stagger_resistance_timer = maxf(0.0, _stagger_resistance_timer - delta)
	state_timer = maxf(0.0, state_timer - delta)
	_path_refresh -= delta
	velocity = Vector2.ZERO
	_animation_moving = false
	if dead:
		queue_redraw()
		if state_timer <= 0.0:
			queue_free()
		return
	if not is_instance_valid(target) or bool(target.get("dead")):
		state = State.WAIT
		if previous_state != State.WAIT or previous_hurt > 0:
			queue_redraw()
		return
	var offset: Vector2 = _metric(target.global_position - global_position)
	var distance: float = offset.length()
	match state:
		State.WAIT:
			if distance < detection_radius:
				state = State.CHASE
		State.CHASE:
			facing = offset.normalized()
			var attack_distance: float = 52.0 if is_boss else _normal_reach - 10
			if distance <= attack_distance:
				_begin_windup()
			elif distance < detection_radius * 1.80:
				var route_direction := _route_direction()
				velocity = Vector2(route_direction.x, route_direction.y * 0.70) * move_speed
				if test_move(global_transform, velocity * delta * 3):
					for turn in [.9, -.9, 1.5, -1.5]:
						var alternate := route_direction.rotated(turn)
						var trial := Vector2(alternate.x, alternate.y * .7) * move_speed
						if not test_move(global_transform, trial * delta * 5):
							velocity = trial
							break
			else:
				state = State.WAIT
		State.WINDUP:
			if state_timer <= 0.0:
				state = State.STRIKE
				_strike_length = 0.22 if attack_pattern == 0 else 0.34
				state_timer = _strike_length
				_strike_applied = false
		State.STRIKE:
			if not _strike_applied:
				_strike_applied = true
				_apply_strike()
			if state_timer <= 0.0:
				state = State.RECOVER
				_recovery_length = 1.05 if is_boss else 0.78
				state_timer = _recovery_length
		State.RECOVER:
			if state_timer <= 0.0:
				state = State.CHASE
		State.STAGGER:
			if state_timer <= 0.0:
				state = State.RECOVER
				_recovery_length = 0.40
				state_timer = _recovery_length
	_knockback = _knockback.move_toward(Vector2.ZERO, 280.0 * delta)
	velocity += _knockback
	if not velocity.is_zero_approx():
		var before_move := global_position
		move_and_slide()
		var travel := _metric(global_position - before_move)
		# A blocked enemy cannot cycle its feet in place. Knockback is a recoil,
		# so only voluntary chase displacement advances the authored walk cycle.
		if state == State.CHASE and _hurt_visual <= 0.0 and travel.length() > .05:
			_distance_walked += travel.length()
			_animation_moving = true
			_visual_facing = travel.normalized()
	# Sentinelas paradas têm o mesmo desenho. Reconstruí-lo 60 vezes por
	# segundo em cada distrito consumia CPU mesmo longe da câmera.
	if state != State.WAIT or previous_state != State.WAIT or previous_hurt > 0 or not velocity.is_zero_approx():
		queue_redraw()


func _begin_windup() -> void:
	_attack_count += 1
	attack_pattern = 1 if is_boss and _attack_count % 2 == 0 else 0
	_attack_direction = facing
	_visual_facing = _attack_direction
	_attack_origin = global_position
	_windup_length = 1.12 if attack_pattern == 1 else (0.90 if is_boss else _normal_windup)
	state = State.WINDUP
	state_timer = _windup_length


func _apply_strike() -> void:
	if not is_instance_valid(target) or not target.has_method("receive_hit"):
		return
	var offset: Vector2 = _metric(target.global_position - global_position)
	var reach: float = 64.0 if is_boss else _normal_reach
	var in_arc: bool = offset.length() < 7.0 or offset.normalized().dot(_attack_direction) > 0.35
	if attack_pattern == 1:
		reach = 79.0
		in_arc = true
	if offset.length() <= reach and in_arc:
		var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
		if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			target.call("receive_hit", 24 if is_boss else _normal_damage, global_position)


func receive_hit(amount: int, from_position: Vector2, stagger: bool = false) -> void:
	if dead:
		return
	health = maxi(0, health - maxi(0, amount))
	_hurt_visual = 0.17
	_hurt_direction = (global_position - from_position).normalized()
	if _hurt_direction.is_zero_approx():
		_hurt_direction = -Vector2(facing.x, facing.y * .70).normalized()
	_knockback = (global_position - from_position).normalized() * (22.0 if is_boss else 62.0)
	if health <= 0:
		dead = true
		state = State.DEAD
		state_timer = 0.45
		collision_layer = 0
		collision_mask = 0
		defeated.emit(enemy_id, is_boss)
	elif stagger and (not is_boss or _stagger_resistance_timer <= 0.0 or amount <= 5):
		state = State.STAGGER
		state_timer = 0.68 if is_boss else 0.92
		if is_boss:
			_stagger_resistance_timer = 2.80
	queue_redraw()


func reset_enemy() -> void:
	global_position = _spawn_position
	health = max_health
	dead = false
	state = State.WAIT
	state_timer = 0.0
	_knockback = Vector2.ZERO
	_attack_count = 0
	_hurt_visual = 0.0
	_hurt_direction = Vector2.ZERO
	_stagger_resistance_timer = 0.0
	_path.clear()
	_path_refresh = 0
	_distance_walked = 0.0
	_animation_moving = false
	_visual_facing = facing
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	queue_redraw()


func _metric(vector: Vector2) -> Vector2:
	return Vector2(vector.x, vector.y / 0.70)

static func _ensure_navigation(owner: Node2D = null) -> void:
	var world_id := owner.get_world_2d().get_instance_id() if owner != null else 0
	if _navigation != null and (owner == null or _navigation_world_id == world_id): return
	_navigation = AStar2D.new()
	_navigation_world_id = world_id
	_tile_ids.clear()
	_navigation_obstacle_buckets.clear()
	if owner != null:
		# Build the spatial index once for this collision world, never per frame.
		for prop in owner.get_tree().get_nodes_in_group("world_obstacles"):
			if not prop is Node2D or prop.get_world_2d() != owner.get_world_2d(): continue
			if not prop.has_method("blocks_ground_point"): continue
			var origin := Vector2i(PortLayout.unproject(prop.global_position).round())
			for y in range(floori((origin.y - 4) / 4.0), floori((origin.y + 4) / 4.0) + 1):
				for x in range(floori((origin.x - 4) / 4.0), floori((origin.x + 4) / 4.0) + 1):
					var bucket := Vector2i(x, y)
					if not _navigation_obstacle_buckets.has(bucket): _navigation_obstacle_buckets[bucket] = []
					_navigation_obstacle_buckets[bucket].append(prop)
	var catalog := PortLayout.tile_catalog()
	for tile in catalog:
		var point := PortLayout.iso(Vector2(tile))
		if not _navigation_ground_clear(point): continue
		var index := _tile_ids.size()
		_tile_ids[tile] = index
		_navigation.add_point(index, point)
	for tile: Vector2i in _tile_ids:
		for direction in [Vector2i.RIGHT, Vector2i.DOWN]:
			if not _tile_ids.has(tile + direction): continue
			var a := _navigation.get_point_position(_tile_ids[tile])
			var b := _navigation.get_point_position(_tile_ids[tile + direction])
			if _navigation_ground_clear(a.lerp(b, .25)) and _navigation_ground_clear(a.lerp(b, .5)) and _navigation_ground_clear(a.lerp(b, .75)):
				_navigation.connect_points(_tile_ids[tile], _tile_ids[tile + direction])

static func _navigation_ground_clear(point: Vector2) -> bool:
	var tile := PortLayout.unproject(point)
	var bucket := Vector2i(floori(tile.x / 4.0), floori(tile.y / 4.0))
	for prop in _navigation_obstacle_buckets.get(bucket, []):
		if is_instance_valid(prop) and prop.blocks_ground_point(point, 8.5): return false
	return true


static func _navigation_point(position: Vector2) -> int:
	# A projeção inversa dá uma vizinhança pequena do pé do personagem.
	# Preserva o nó mais próximo sem varrer o porto inteiro para cada inimigo.
	var tile := Vector2i(PortLayout.unproject(position).round())
	var closest := -1
	var closest_distance := INF
	for y in range(-1, 2):
		for x in range(-1, 2):
			var candidate := tile + Vector2i(x, y)
			if _tile_ids.has(candidate):
				var distance := position.distance_squared_to(PortLayout.iso(Vector2(candidate)))
				if distance < closest_distance:
					closest_distance = distance
					closest = int(_tile_ids[candidate])
	# Fora do chão (p. ex. uma ferramenta de inspeção), mantenha a busca
	# global para continuar alcançando a margem válida mais próxima.
	return closest if closest >= 0 else _navigation.get_closest_point(position)


func _route_direction() -> Vector2:
	_ensure_navigation(self)
	if _path_refresh <= 0:
		_path_refresh = .35 + float(get_instance_id() % 7) * .035
		var from := _navigation_point(global_position)
		var to := _navigation_point(target.global_position)
		_path = _navigation.get_point_path(from, to)
		# The first graph point represents the tile already occupied. Steering
		# back to its centre at every refresh can trap slower keepers in place.
		if _path.size() > 1:
			_path.remove_at(0)
	while _path.size() > 1 and global_position.distance_to(_path[0]) < 9:
		_path.remove_at(0)
	var goal := _path[0] if not _path.is_empty() else target.global_position
	if _metric(target.global_position - global_position).length() < 65:
		var sight := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
		if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
			goal = target.global_position
	return _metric(goal - global_position).normalized()


func _animation_progress() -> float:
	match state:
		State.WINDUP: return clampf(1.0 - state_timer / _windup_length, 0.0, 1.0)
		State.STRIKE: return clampf(1.0 - state_timer / _strike_length, 0.0, 1.0)
		State.RECOVER: return clampf(1.0 - state_timer / _recovery_length, 0.0, 1.0)
	return 0.0


func _draw() -> void:
	var scale_factor: float = 1.35 if is_boss else 1.0
	var tint: Color = Color("9f795c") if not is_boss else Color("bca170")
	if not is_boss:
		tint = {"guard": Color("9f795c"), "runner": Color("a17c70"), "lancer": Color("b09a72"), "keeper": Color("7c9b91")}.get(archetype, tint)
	if _hurt_visual > 0.0:
		tint = Color("fff0cb")
	if dead:
		tint.a = state_timer / 0.45
	var bob: float = -absf(sin(_time * 9.0)) if velocity.length() > 6.0 else 0.0
	var shadow := PackedVector2Array()
	for i: int in range(20):
		var angle: float = TAU * float(i) / 20.0
		shadow.append(Vector2(cos(angle) * 11.0, sin(angle) * 4.0) * scale_factor)
	draw_colored_polygon(shadow, Color(0.01, 0.015, 0.025, 0.42))
	if state == State.WINDUP or state == State.STRIKE:
		_draw_warning()
	var sprite_tint := Color("fff0cb") if _hurt_visual > 0 else Color.WHITE
	sprite_tint.a = tint.a
	var sprite_kind := "keeper" if is_boss else archetype
	var has_sprite := PixelView.draw_actor(self, sprite_kind, state, _distance_walked, _animation_moving, _visual_facing, sprite_tint, scale_factor, _animation_progress(), _hurt_visual > 0, _time + _breath_phase, _hurt_direction, _hurt_visual / .17)
	if not has_sprite:
		_draw_fallback_body(scale_factor, tint, bob)
	if health < max_health and not dead:
		var bar_width: float = 32.0 if is_boss else 23.0
		var bar_y: float = (-73.0 if is_boss else -56.0) if has_sprite else (-58.0 if is_boss else -35.0)
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width, 3), Color("302b36"))
		draw_rect(Rect2(-bar_width * 0.5, bar_y, bar_width * float(health) / float(max_health), 3), Color("d39e82"))
	if state == State.STAGGER:
		for i: int in range(3):
			var angle: float = _time * 4.0 + float(i) * TAU / 3.0
			draw_rect(Rect2(Vector2(cos(angle) * 10.0, (-53.0 if has_sprite else -39.0) * scale_factor + sin(angle) * 3.0), Vector2(2, 2)), Color("ffe3a1"))


func _draw_fallback_body(scale_factor: float, tint: Color, bob: float) -> void:
	draw_set_transform(Vector2(0.0, bob), 0.0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(-6, -22, 12, 17), Color("35313b"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -19), Vector2(6, -19), Vector2(9, -3), Vector2(0, -6), Vector2(-8, -3)]), tint)
	draw_rect(Rect2(-5, -9, 4, 9), Color("3a3034"))
	draw_rect(Rect2(2, -9, 4, 9), Color("3a3034"))
	draw_rect(Rect2(-4, -29, 9, 10), Color("40373e"))
	draw_rect(Rect2(-3, -27, 7, 7), tint)
	draw_rect(Rect2(-2, -24, 5, 2), Color("4b2545"))
	draw_rect(Rect2(-7, -18, 14, 3), Color("625257"))
	if is_boss:
		draw_rect(Rect2(-7, -32, 14, 4), Color("d8bf83"))
		draw_rect(Rect2(-6, -35, 3, 5), Color("d8bf83"))
		draw_rect(Rect2(4, -35, 3, 5), Color("d8bf83"))
		draw_line(Vector2(9, -20), Vector2(12, 1), Color("b8ac91"), 3.0)
		draw_rect(Rect2(7, -22, 11, 6), Color("7d7b79"))
	else:
		draw_line(Vector2(8, -16), Vector2(11, -2), Color("aaa087"), 2.0)
	draw_set_transform(Vector2.ZERO)


func _draw_warning() -> void:
	var progress: float = 1.0 if state == State.STRIKE else 1.0 - state_timer / _windup_length
	var reach: float = 64.0 if is_boss else 42.0
	var tint := Color(0.92, 0.38, 0.25, 0.20 + progress * 0.45)
	var width: float = TAU if attack_pattern == 1 else 2.40
	if attack_pattern == 1:
		reach = 79.0
		tint = Color(0.75, 0.42, 0.82, 0.20 + progress * 0.45)
	var points := PackedVector2Array()
	var sector := PackedVector2Array([Vector2.ZERO])
	var start: float = _attack_direction.angle() - width * 0.5
	for i: int in range(29):
		var angle: float = start + width * float(i) / 28.0
		var point := Vector2(cos(angle) * reach, sin(angle) * reach * 0.70)
		points.append(point)
		sector.append(point)
	var fill := tint
	fill.a *= 0.18
	draw_colored_polygon(sector, fill)
	draw_polyline(points, tint, 2.0 if state == State.STRIKE else 1.0, false)
	if state == State.WINDUP:
		var head_y := -76.0 if is_boss else -57.0
		draw_line(Vector2(-2, head_y), Vector2(-2, head_y - 6 - progress * 6.0), Color("ffd896"), 2.0)
