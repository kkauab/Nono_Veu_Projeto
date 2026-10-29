extends RefCounted
## Authored poses with a small, pixel-snapped transfer of weight above the feet.

const ActorMotion := preload("res://scripts/actors/actor_pixel_motion.gd")

const PATH := "res://assets/sprites/port_enemies_v12.png"
const CELL := 128
const PIVOT := Vector2(64, 112)
const WALK_STRIDE := 32.0
const WALK_FRAMES := 8
const POSES_PER_ACTOR := 16
static var _texture: Texture2D


static func rest_offset(time: float) -> float:
	# A slow inhalation moves the chest one source pixel; the base never rises.
	return -roundf((sin(time * 1.65) * .5 + .5) * .8)


static func motion_sample(state: int, distance_walked: float, moving: bool, facing: Vector2, progress: float = 0.0, hurt_amount: float = 0.0, hit_direction: Vector2 = Vector2.ZERO, time: float = 0.0) -> Dictionary:
	var upper := Vector2.ZERO
	var middle := Vector2.ZERO
	var direction := Vector2(facing.x, facing.y * .70).normalized()
	var p := clampf(progress, 0.0, 1.0)
	if state == 0 or state == 1:
		if moving:
			# Two weight transfers per full authored stride, driven by ground travel.
			var gait := fposmod(distance_walked, WALK_STRIDE) / WALK_STRIDE * TAU
			upper = Vector2(sin(gait) * .65, -sin(gait * 2.0) * .55)
		else:
			upper.y = rest_offset(time)
	elif state == 2:
		# Settle the hips, load the shoulder, then hold the readable windup pose.
		var load := smoothstep(.12, .88, p)
		upper = -direction * (2.0 * load) + Vector2(0, load * .7)
		middle = -direction * (.55 * load)
	elif state == 3:
		# Damage already belongs to the contact pose at entry. Only the drawing
		# follows through here; this never moves the body or schedules a strike.
		var follow := 2.0 - smoothstep(.12, 1.0, p)
		upper = direction * follow + Vector2(0, .5)
		middle = direction * .55
	elif state == 4:
		var settle := 1.0 - smoothstep(0.0, .85, p)
		upper = direction * settle + Vector2(0, sin(p * PI) * .55)
		middle = direction * (.55 * settle)
	if hurt_amount > 0.0:
		# Immediate directional recoil followed by a small damped return. It is
		# independent of gameplay knockback, including when a wall blocks it.
		var elapsed := 1.0 - clampf(hurt_amount, 0.0, 1.0)
		var recoil := cos(elapsed * PI * .65) * pow(1.0 - elapsed, 1.3)
		upper = hit_direction.normalized() * (2.0 * recoil)
		middle = upper * .25
	upper = upper.round().clamp(Vector2(-2, -2), Vector2(2, 2))
	middle = middle.round().clamp(Vector2(-1, -1), Vector2(1, 1))
	return {"upper_offset": upper, "middle_offset": middle, "feet_offset": Vector2.ZERO}

static func pose_for(state: int, distance_walked: float, moving: bool, progress: float = 0.0, hurt: bool = false) -> int:
	# State values follow VeilEnemy.State without creating a circular script load.
	if hurt or state == 5 or state == 6: return 14 # Stagger/death use the recoil silhouette.
	match state:
		2: return 9 if progress < .55 else 10 # Raise weapon, then load the strike.
		3: return 11 if progress < .45 else 12 # Contact coincides with damage, then follow-through.
		4:
			if progress < .20: return 12
			return 13 if progress < .70 else 15 # Recover the weapon before resuming the guard.
	if moving:
		return 1 + int(fposmod(distance_walked, WALK_STRIDE) / WALK_STRIDE * WALK_FRAMES)
	return 0

static func draw_actor(canvas: CanvasItem, archetype: String, state: int, distance_walked: float, moving: bool, facing: Vector2, tint: Color, size: float, progress: float = 0.0, hurt: bool = false, time: float = 0.0, hit_direction: Vector2 = Vector2.ZERO, hurt_amount: float = 0.0) -> bool:
	if _texture == null and ResourceLoader.exists(PATH):
		_texture = load(PATH) as Texture2D
	if _texture == null:
		return false
	var row := int({"guard": 0, "runner": 1, "lancer": 2, "keeper": 3}.get(archetype, 0))
	var pose := pose_for(state, distance_walked, moving, progress, hurt)
	var flip := -1.0 if facing.x < -.1 else 1.0
	var motion := motion_sample(state, distance_walked, moving, facing, progress, hurt_amount, hit_direction, time)
	# Procedural directions are in screen space; source pixels are mirrored by
	# the authored facing transform, so compensate before drawing the bands.
	var upper: Vector2 = motion["upper_offset"] * Vector2(flip, 1)
	var middle: Vector2 = motion["middle_offset"] * Vector2(flip, 1)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0) * size)
	ActorMotion.draw_frame(canvas, _texture, -PIVOT, Vector2(CELL, CELL), Rect2(pose * CELL, row * CELL, CELL, CELL), tint, upper, middle)
	canvas.draw_set_transform(Vector2.ZERO)
	return true
