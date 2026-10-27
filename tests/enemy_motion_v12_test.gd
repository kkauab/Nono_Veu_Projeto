extends SceneTree
const View = preload("res://scripts/actors/enemy_pixel_view.gd")
var checks := 0
var failures: Array[String] = []

class Target extends Node2D:
	var dead := false
	var contacts := 0
	func receive_hit(_amount: int, _from: Vector2) -> void: contacts += 1

class StraightEnemy extends VeilEnemy:
	func _route_direction() -> Vector2: return Vector2.RIGHT

func _initialize() -> void: call_deferred("_run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
func pose(enemy: VeilEnemy) -> int:
	return View.pose_for(enemy.state, enemy._distance_walked, enemy._animation_moving, enemy._animation_progress(), enemy._hurt_visual > 0)

func _run() -> void:
	var cycle: Array[int] = []
	for step in range(8): cycle.append(View.pose_for(VeilEnemy.State.CHASE, step*4.0+.01, true))
	check(cycle == [1,2,3,4,5,6,7,8], "A full stride selects eight different authored footfall poses in order")
	check(View.pose_for(VeilEnemy.State.CHASE,32.01,true)==1, "Footfalls wrap only after the complete stride distance")
	check(View.pose_for(VeilEnemy.State.CHASE,18,false)==0, "Stopped movement returns to a planted idle pose")
	check(View.pose_for(VeilEnemy.State.WAIT,18,false)==0, "Idle time cannot rotate through walking frames")
	var target := Target.new()
	target.position = Vector2(600,180)
	root.add_child(target)
	var enemy := StraightEnemy.new()
	enemy.target = target
	enemy.detection_radius = 1000
	root.add_child(enemy)
	enemy.state = VeilEnemy.State.CHASE
	var start := enemy.position
	var observed := {}
	for frame in range(40):
		await physics_frame
		observed[pose(enemy)] = true
	var travel := enemy._metric(enemy.position-start).length()
	check(travel>20 and absf(enemy._distance_walked-travel)<1.5, "Walk phase follows real ground travel instead of wall-clock time")
	check(observed.size()>=7, "Actual chase movement displays the distinct steps, not alternating idle images")
	check(enemy._visual_facing.x>.95 and absf(enemy._visual_facing.y)<.05 and enemy.facing.y>0, "Rendering follows the route while gameplay aim remains pointed at the target")
	target.dead = true
	await physics_frame
	await physics_frame
	var stopped_distance := enemy._distance_walked
	for frame in range(8): await physics_frame
	check(enemy._distance_walked==stopped_distance and not enemy._animation_moving and pose(enemy)==0, "An enemy without a living target stops its feet and keeps its stride distance")
	target.dead = false
	enemy.position = Vector2.ZERO
	target.position = Vector2(600,0)
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.position = Vector2(10,0)
	var wall_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(8,2000)
	wall_shape.shape = rectangle
	wall.add_child(wall_shape)
	root.add_child(wall)
	enemy.state = VeilEnemy.State.CHASE
	for frame in range(8): await physics_frame
	var blocked_distance := enemy._distance_walked
	for frame in range(12): await physics_frame
	check(absf(enemy._distance_walked-blocked_distance)<.1 and not enemy._animation_moving and pose(enemy)==0, "A real wall stops the feet instead of letting the chase timer shuffle them in place")
	wall.free()
	enemy.set_physics_process(false)
	enemy.position = Vector2.ZERO
	target.position = Vector2(12,0)
	enemy.facing = Vector2.RIGHT
	enemy._begin_windup()
	check(pose(enemy)==9, "Attack anticipation begins with the raised-weapon pose")
	enemy.state_timer = enemy._windup_length*.3
	check(pose(enemy)==10, "The second windup pose loads the weapon before the hit")
	enemy._physics_process(enemy.state_timer+.001)
	check(enemy.state==VeilEnemy.State.STRIKE and pose(enemy)==11 and target.contacts==0, "Entering strike shows the contact pose before damage is evaluated")
	enemy._physics_process(.001)
	check(target.contacts==1 and pose(enemy)==11, "The real damage event coincides with the authored contact pose")
	enemy._physics_process(.11)
	check(target.contacts==1 and pose(enemy)==12, "The follow-through does not apply a second hit")
	enemy._physics_process(.12)
	check(enemy.state==VeilEnemy.State.RECOVER and pose(enemy)==12, "Recovery starts from the end of the swing")
	enemy._physics_process(.25)
	check(pose(enemy)==13, "Recovery visibly brings the weapon back")
	enemy._physics_process(.35)
	check(pose(enemy)==15, "Late recovery settles into the separate guarded stance")
	enemy.receive_hit(1,Vector2.LEFT)
	check(pose(enemy)==14, "Taking damage selects a real recoil frame rather than resizing the body")
	enemy.reset_enemy()
	check(enemy._distance_walked==0 and not enemy._animation_moving and pose(enemy)==0, "Checkpoint reset clears animation travel and restores a planted idle")
	if ResourceLoader.exists(View.PATH):
		var texture := load(View.PATH) as Texture2D
		check(texture!=null and texture.get_size()==Vector2(2048,512), "The runtime uses the complete four-archetype sixteen-pose atlas")
		var atlas := texture.get_image()
		for row in range(4):
			var steps := {}
			var cuts := {}
			for index in range(1,9): steps[hash(atlas.get_region(Rect2i(index*128,row*128,128,128)).get_data())] = true
			for index in range(9,14): cuts[hash(atlas.get_region(Rect2i(index*128,row*128,128,128)).get_data())] = true
			check(steps.size()==8, "Archetype %d contains eight distinct raster footfall drawings" % row)
			check(cuts.size()==5, "Archetype %d contains five distinct raster attack phases" % row)
	else:
		check(false, "The authored enemy atlas must be exported and imported before final verification")
	enemy.free()
	target.free()
	print("ENEMY MOTION V12 CHECKS: %d passed=%d failures=%s" % [checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
