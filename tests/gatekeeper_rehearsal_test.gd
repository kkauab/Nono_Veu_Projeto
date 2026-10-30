extends SceneTree
const Actor=preload("res://tests/gatekeeper_rehearsal_actor.gd")
const Data=preload("res://scripts/actors/gatekeeper_attack_data.gd")
const View=preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const OUT="res://qa/porteiro_walk_v6/"
var checks:=0
var failures: Array[String]=[]
var capture:=false

func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	capture="--capture-walk" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless"
	var world=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	check(world.qa_mode and world.store.path.begins_with("user://qa/"),"World uses an isolated QA save")
	world.hud.show_overlay("")
	world.hud.visible=false
	world.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer=0
		enemy.collision_mask=0
	world.boss.visible=false
	var actor:=Actor.new()
	actor.target=world.player
	actor.position=world.boss.position
	actor.automatic=false
	world.actors.add_child(actor)
	actor.set_physics_process(false)
	world.player.controls_enabled=false
	world.player.set_physics_process(false)
	world.player.position=actor.position+Vector2(114,24)
	var toward:=actor._metric(world.player.position-actor.position).normalized()
	check(actor._route_direction().dot(toward)>.99,"Open arena approach does not zigzag between tile centers")
	var blocker:=StaticBody2D.new()
	blocker.position=actor.position.lerp(world.player.position,.45)
	blocker.collision_layer=1
	var obstacle_shape:=CollisionShape2D.new()
	var rectangle:=RectangleShape2D.new()
	rectangle.size=Vector2(12,36)
	obstacle_shape.shape=rectangle
	blocker.add_child(obstacle_shape)
	world.actors.add_child(blocker)
	await physics_frame
	check(actor.test_move(actor.global_transform,world.player.position-actor.position-toward*24),"A real arena obstacle blocks direct approach")
	actor._route_direction()
	check(not actor._path.is_empty(),"Obstructed approach falls back to existing enemy navigation")
	blocker.queue_free()
	await physics_frame
	var camera: Camera2D=world.player.get_node("IsometricCamera")
	camera.top_level=true
	camera.global_position=actor.position+Vector2(58,-15)
	camera.reset_smoothing()
	camera.force_update_scroll()
	var start:=actor.position
	var starting_health: int=world.player.health
	var seen: Dictionary={}
	for frame in range(240):
		actor._physics_process(1./60)
		if actor.performance.walking:
			seen[actor.performance.locomotion_sample()["frame"]]=true
		await physics_frame
		if capture and frame%2==0:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(320,145,640,420)).save_png(OUT+"walk_%03d.png"%frame)
	check(actor.position.distance_to(start)>40,"Gatekeeper actually traverses the real map toward Senu")
	check(actor._distance_walked>40 and seen.size()==16,"Actual ground travel drives all sixteen walking cels")
	check(PortLayout.tile_catalog().has(Vector2i(PortLayout.unproject(actor.global_position).round())),"Walking stays on the arena floor")
	var first:=actor.position
	world.player.position=actor.position+Vector2(95,42)
	for frame in range(90):
		actor._physics_process(1./60)
		await physics_frame
	check(actor.position.distance_to(first)>12,"Gatekeeper follows when Senu changes position")
	# Stop close to Senu. The actor must plant its feet instead of cycling in
	# place or snapping immediately from the last stride to the guard cel.
	world.player.position=actor.position+Vector2(30,0)
	for frame in range(24):
		actor._physics_process(1./60)
		await physics_frame
		if capture and frame%2==0:
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().get_region(Rect2i(320,145,640,420)).save_png(OUT+"stop_%03d.png"%frame)
	check(not actor.performance.walking and actor.performance.locomotion_sample()["clip"]=="idle","Stopping settles to planted guard without walking in place")
	world.player.position=actor.position+Vector2(100,20)
	actor._physics_process(1./60)
	check(actor.performance.walking,"Walking resumes from the settled stance")
	check(actor.play_clip("register") and not actor._pending_clip.is_empty() and not actor.performance.active,"An attack requested while walking waits for closing steps")
	actor._physics_process(.1)
	check(not actor.performance.active and actor.performance.locomotion_sample()["clip"]=="walk_settle","Preparation does not skip the foot-plant transition")
	actor._physics_process(.15)
	check(actor.performance.active and actor.performance.elapsed==0,"Attack starts its JSON clock only after the guard is planted")
	actor._physics_process(Data.duration(Data.definition("register"))+.01)
	# The locomotion-to-attack transition was exercised above. Keep Senu near
	# for the independent clip checks, so recovery does not start another chase.
	world.player.position=actor.position+Vector2(30,0)
	for id in Data.load_data()["order"]:
		check(actor.play_clip(id),id+": individual clip starts from planted guard")
		var at:=actor.position
		for frame in range(ceili(Data.duration(Data.definition(id))*60)+2):actor._physics_process(1./60)
		check(actor.position.distance_to(at)<2,id+": preparation and recovery do not slide across the floor")
	check(world.player.health==starting_health,"The art rehearsal cannot damage Senu")
	var before: int=actor.health
	actor.receive_hit(9999,world.player.position,true)
	check(actor.health==before and not actor.dead,"Rehearsal cannot trigger rewards or a boss victory")
	world.queue_free()
	await process_frame
	print("GATEKEEPER MAP REHEARSAL checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
