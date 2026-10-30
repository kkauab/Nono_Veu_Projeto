extends SceneTree
## Isolated locomotion stage: no world scene, save store or player progress.
const People = preload("res://scripts/world/townsfolk.gd")
var checks := 0
var failures: Array[String] = []
var fixtures: Array[Node] = []

class StepSpace extends "res://scripts/world/townsfolk.gd":
	var allow_step := true
	func _free(_point: Vector2) -> bool:
		return allow_step

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_route_distance()
	_phase_continuity()
	_iso_distance()
	_block_and_make_way()
	_sleep()
	_cadence()
	for fixture in fixtures:
		fixture.free()
	print("NPC WALK ANIMATION checks=%d passed=%d failures=%s" % [checks, checks-failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func near(value: float, expected: float, text: String) -> void:
	check(absf(value-expected) < .001, text)

func person():
	var actor := StepSpace.new()
	actor.kind = "townsfolk"
	root.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.time = 0.0
	fixtures.append(actor)
	return actor

func route(actor, from: Vector2, to: Vector2) -> void:
	actor.position = from
	actor.stops = [{"at": to, "act": "idle", "time": 10.0, "extra": null, "path": PackedVector2Array([to])}]
	actor._stop = 0
	actor._waypoint = 0
	actor._acting = false

func hero_at(point: Vector2) -> Node2D:
	var hero := Node2D.new()
	root.add_child(hero)
	hero.position = point
	fixtures.append(hero)
	return hero

func _route_distance() -> void:
	var actor = person()
	route(actor, Vector2.ZERO, Vector2(5,0))
	actor.advance(.1)
	near(actor.position.x, 3.0, "Route speed remains30 ground pixels per second")
	near(actor.walk_distance(), 3.0, "Gait counts the actual first3 pixels")
	check(actor.is_walking(), "Displacement starts walking")
	actor.advance(.2)
	near(actor.position.x, 5.0, "Final short step ends exactly on waypoint")
	near(actor.walk_distance(), 5.0, "Final partial step counts only remaining2 pixels")
	check(actor.is_walking(), "Short arrival step is still a moving frame")
	actor.advance(.1)
	check(not actor.is_walking(), "Arrival changes immediately to stationary state")
	near(actor.walk_distance(), 5.0, "Arrival does not reset gait phase")
	check(actor.pose() == actor.rest_pose(), "Arrival renders the original rest pose")
	actor.advance(.5)
	check(not actor.is_walking(), "Waiting does not advance walking animation")
	near(actor.walk_distance(), 5.0, "Waiting preserves accumulated distance")
	route(actor, actor.position, Vector2(100,0))
	actor.advance(0.0)
	check(not actor.is_walking(), "Zero displacement with an unfinished route remains stationary")

func _phase_continuity() -> void:
	var actor = person()
	route(actor, Vector2.ZERO, Vector2(200,0))
	actor.advance(.25)
	var distance: float = actor.walk_distance()
	var unloaded: int = actor.pose()
	actor.facing = -1.0
	near(actor.walk_distance(), distance, "Turning preserves gait distance")
	check(actor.pose() == unloaded, "Turning preserves fallback gait frame")
	actor.carrying = true
	near(actor.walk_distance(), distance, "Taking cargo preserves gait distance")
	check(actor.pose() == unloaded+6, "Loaded fallback uses the same gait phase")
	actor.speed = 60.0
	check(actor.pose() == unloaded+6, "Speed change alone never changes gait phase")
	actor.advance(.1)
	near(actor.walk_distance(), distance+6.0, "New speed advances only by actual movement")
	actor.advance(0.0)
	check(not actor.is_walking(), "Stopping after movement clears walking state")
	var paused_distance: float = actor.walk_distance()
	actor.advance(.01)
	near(actor.walk_distance(), paused_distance+.6, "Resuming keeps phase instead of restarting")
	for look in range(12):
		actor.look = look
		var frame := int(actor.walk_distance()/6.0)%4
		check(actor.pose() == frame+7, "Appearance%d shares the same loaded gait phase" % look)
	actor.kind = "vendor"
	actor.advance(.1)
	check(not actor.is_walking(), "Fixed vendors never use walking presentation")
	check(actor.pose() == actor.rest_pose(), "Vendor resting art is unchanged")

func _iso_distance() -> void:
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2(1,1).normalized(), Vector2(-1,-1).normalized()]:
		var actor = person()
		var target := Vector2(direction.x, direction.y*People.ISO_Y)*100.0
		route(actor, Vector2.ZERO, target)
		actor.advance(.2)
		var normalized := Vector2(actor.position.x, actor.position.y/People.ISO_Y)
		near(normalized.length(), 6.0, "Direction%s retains physical isometric route speed" % direction)
		near(actor.walk_distance(), 6.0, "Direction%s uses normalized ground distance" % direction)

func _block_and_make_way() -> void:
	var actor = person()
	route(actor, Vector2.ZERO, Vector2(200,0))
	actor.advance(.25)
	var distance: float = actor.walk_distance()
	actor._hero = hero_at(actor.position+Vector2(14,0))
	var before: Vector2 = actor.position
	actor.advance(.1)
	check(actor.position == before, "Senu still blocks the forward route")
	check(not actor.is_walking(), "Blocked walker stops animating in place")
	near(actor.walk_distance(), distance, "Blocking preserves phase without counting intended movement")
	check(actor.pose() == actor.rest_pose(), "Blocking uses unchanged nonwalking art")
	actor._hero.position = Vector2(1000,0)
	actor.advance(.1)
	near(actor.walk_distance(), distance+3.0, "Unblocking continues the prior stride")
	# The original make-way behavior is retained, including its screen-space side step.
	actor._hero.position = actor.position+Vector2(-5,0)
	actor._pushed = .19
	actor._acting = true
	before = actor.position
	distance = actor.walk_distance()
	actor.advance(.02)
	var moved: Vector2 = actor.position-before
	var actual := Vector2(moved.x,moved.y/People.ISO_Y).length()
	check(actual > 0.0, "Making way still moves the physical actor")
	near(actor.walk_distance(), distance+actual, "Making way also animates by actual ground displacement")
	check(actor.is_walking(), "A real sidestep animates even during a waiting stop")
	check(actor.pose() in [1,2,3,4], "Sidestep selects walking rather than a stationary action")
	actor.allow_step = false
	actor._pushed = .19
	before = actor.position
	distance = actor.walk_distance()
	actor.advance(.02)
	check(actor.position == before, "No-free-space push keeps the actor still")
	check(not actor.is_walking(), "Blocked making-way attempt never walks in place")
	near(actor.walk_distance(), distance, "Blocked sidestep never adds gait distance")
	actor.advance(1.1)
	check(actor._body.collision_layer == 0, "Existing temporary ghost escape remains intact")
	check(not actor.is_walking(), "Ghost escape without displacement stays stationary")

func _sleep() -> void:
	var actor = person()
	route(actor, Vector2.ZERO, Vector2(200,0))
	actor.advance(.1)
	var distance: float = actor.walk_distance()
	var before: Vector2 = actor.position
	actor._hero = hero_at(Vector2(2000,0))
	actor._physics_process(.1)
	check(not actor.is_walking(), "Dormant distant actors leave the walking pose")
	check(actor.position == before, "Distant routine still pauses")
	near(actor.walk_distance(), distance, "Sleeping retains gait phase")

func _cadence() -> void:
	var distance := []
	var pose := []
	for fps in [30,60,120]:
		var actor = person()
		route(actor, Vector2.ZERO, Vector2(500,0))
		for frame in range(fps*2):
			actor.advance(1.0/float(fps))
		distance.append(actor.walk_distance())
		pose.append(actor.pose())
		near(actor.walk_distance(),60.0, "Two-second route covers60 pixels at%dHz" % fps)
	near(distance[0],distance[2], "Gait distance is independent of physics cadence")
	check(pose[0] == pose[1] and pose[1] == pose[2], "Fallback phase matches across physics cadences")
