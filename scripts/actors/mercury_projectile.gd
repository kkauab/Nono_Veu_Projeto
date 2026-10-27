class_name MercuryProjectile
extends Node2D
## Swept collision against scenery and enemies prevents fast seals from crossing
## thin walls/closed gates. Piercing excludes each struck body exactly once.

signal struck(enemy: Node2D, was_killed: bool)

const ISO_Y: float = 0.70
var direction: Vector2 = Vector2.RIGHT
var damage: int = 32
var speed: float = 230.0
var max_range: float = 260.0
var max_targets: int = 1
var originator: Node2D
var shot_origin: Vector2 = Vector2.ZERO
var travelled_distance: float = 0.0
var hit_count: int = 0
var flying: bool = true
var blocked_by_scenery: bool = false

var _excluded: Array[RID] = []
var _hit_ids: Dictionary = {}
var _trail: Array[Vector2] = []
var _impact_timer: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	add_to_group("mercury_projectiles")
	direction = direction.normalized() if direction.length_squared() > 0.01 else Vector2.RIGHT
	max_targets = clampi(max_targets, 1, 3)
	if originator is CollisionObject2D:
		_excluded.append((originator as CollisionObject2D).get_rid())
	queue_redraw()


func _physics_process(delta: float) -> void:
	_clock += delta
	if not flying:
		_impact_timer -= delta
		if _impact_timer <= 0.0:
			queue_free()
		queue_redraw()
		return
	var step: float = minf(speed * delta, maxf(0.0, max_range - travelled_distance))
	if step <= 0.0:
		_finish()
		return
	_trail.append(global_position)
	if _trail.size() > 8:
		_trail.pop_front()
	var end: Vector2 = global_position + Vector2(direction.x, direction.y * ISO_Y) * step
	var ray_start: Vector2 = global_position
	for attempt: int in range(5):
		var query := PhysicsRayQueryParameters2D.create(ray_start, end, 1 | 4, _excluded)
		query.hit_from_inside = true
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var body: Object = hit["collider"]
		global_position = hit["position"]
		if not body is Node2D or not (body as Node2D).is_in_group("enemies") or not body.has_method("receive_hit"):
			blocked_by_scenery = true
			_finish()
			return
		var enemy: Node2D = body as Node2D
		var body_id: int = enemy.get_instance_id()
		if enemy is CollisionObject2D:
			_excluded.append((enemy as CollisionObject2D).get_rid())
		if not _hit_ids.has(body_id) and not bool(enemy.get("dead")):
			_hit_ids[body_id] = true
			hit_count += 1
			enemy.call("receive_hit", damage, shot_origin, false)
			struck.emit(enemy, bool(enemy.get("dead")))
			if hit_count >= max_targets:
				_finish()
				return
		ray_start = global_position + (end - global_position).normalized() * 0.01
	global_position = end
	travelled_distance += step
	if travelled_distance >= max_range:
		_finish()
	queue_redraw()


func _finish() -> void:
	flying = false
	_impact_timer = 0.16
	queue_redraw()


func _draw() -> void:
	for i: int in range(_trail.size()):
		var offset: Vector2 = (_trail[i] - global_position + Vector2(0, -11)).floor()
		var alpha: float = 0.10 + 0.40 * float(i + 1) / float(maxi(1, _trail.size()))
		draw_rect(Rect2(offset - Vector2.ONE, Vector2(2, 2)), Color(0.76, 0.68, 0.40, alpha))
	var tint := Color("efdaa1")
	if flying:
		var points := PackedVector2Array([Vector2(0, -18), Vector2(6, -12), Vector2(0, -6), Vector2(-6, -12), Vector2(0, -18)])
		draw_polyline(points, tint, 1.0, false)
		draw_line(Vector2(-3, -12), Vector2(3, -12), Color("b8c0d8"), 1.0)
		draw_line(Vector2(0, -15), Vector2(0, -9), tint, 1.0)
		draw_rect(Rect2(-1, -13, 2, 2), Color("fff2c4"))
	else:
		var progress: float = 1.0 - _impact_timer / 0.16
		for i: int in range(6):
			var angle: float = TAU * float(i) / 6.0
			var spark := Vector2(cos(angle), sin(angle) * ISO_Y) * (3.0 + progress * 13.0) + Vector2(0, -12)
			draw_rect(Rect2(spark.floor(), Vector2(2, 2)), Color(tint, 1.0 - progress))
