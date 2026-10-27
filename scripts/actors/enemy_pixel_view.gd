extends RefCounted
## Authored footfalls and attack phases, with a fixed foot pivot and scale.

const PATH := "res://assets/sprites/port_enemies_v12.png"
const CELL := 128
const PIVOT := Vector2(64, 112)
const WALK_STRIDE := 32.0
const WALK_FRAMES := 8
const POSES_PER_ACTOR := 16
static var _texture: Texture2D

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

static func draw_actor(canvas: CanvasItem, archetype: String, state: int, distance_walked: float, moving: bool, facing: Vector2, tint: Color, size: float, progress: float = 0.0, hurt: bool = false) -> bool:
	if _texture == null and ResourceLoader.exists(PATH):
		_texture = load(PATH) as Texture2D
	if _texture == null:
		return false
	var row := int({"guard": 0, "runner": 1, "lancer": 2, "keeper": 3}.get(archetype, 0))
	var pose := pose_for(state, distance_walked, moving, progress, hurt)
	var flip := -1.0 if facing.x < -.1 else 1.0
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0) * size)
	canvas.draw_texture_rect_region(_texture, Rect2(-PIVOT, Vector2(CELL, CELL)), Rect2(pose * CELL, row * CELL, CELL, CELL), tint)
	canvas.draw_set_transform(Vector2.ZERO)
	return true
