extends SceneTree
## Autonomous selection/movement through both phases, not forced attack calls.
const Boss=preload("res://scripts/actors/nameless_gatekeeper.gd")
const Data=preload("res://scripts/actors/gatekeeper_attack_data.gd")
var failures: Array[String]=[]
var checks:=0
var seen: Array[String]=[]
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():quit(1);return
	preload("res://scripts/actors/combat_fx.gd").hitstop_enabled=false
	var game=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.gatekeeper_encounter.set_process(false)
	game.hud.show_overlay("")
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	var boss: Boss=game.boss
	var origin:=boss.position
	var measured_speeds: Array[float]=[]
	for phase in [1,2]:
		boss.reset_enemy()
		boss.start_fight()
		boss.phase=phase
		boss._gap=0
		for id in Data.load_data()["order"]:boss._cooldowns[id]=999
		game.player.reset_at(origin+Vector2(180,0))
		for frame in range(18):boss._physics_process(1./60)
		var measured:=Data.metric(boss.position-origin).length()/.3
		var expected: float=boss.move_speed*(float(boss._config["phase_two_move_scale"]) if phase==2 else 1)
		measured_speeds.append(snappedf(measured,.01))
		check(absf(measured-expected)<.1,"Phase %d moves at its configured ground speed, without sliding past collisions"%phase)
	boss.reset_enemy()
	game.player.reset_at(origin+Vector2(180,0))
	check(PortLayout.room_at(game.player.position)=="b1","Long-range pursuit fixture is inside the arena")
	boss.attack_started.connect(func(id):
		if id not in seen:seen.append(id))
	boss.start_fight()
	for frame in range(450):
		game.player.invulnerability_timer=1
		boss._physics_process(1./60)
	check(boss.position.distance_to(origin)>10,"Boss walks over real floor to approach a distant Senu")
	check(not seen.is_empty(),"Pursuit naturally chooses a reachable attack")
	var valid_floor:=true
	var max_recovery:=0.0
	var stuck:=0.0
	for phase in [1,2]:
		if phase==2:
			boss.receive_hit(9999,game.player.position)
			check(boss.mode==Boss.Mode.TRANSITION,"Autonomous first phase reaches the protected transition")
			game.gatekeeper_encounter._process(.016)
			game.gatekeeper_encounter.finish_sequence(true)
		for frame in range(60*65):
			game.player.invulnerability_timer=1 # This test observes decisions, not player damage.
			if boss.mode in [Boss.Mode.APPROACH,Boss.Mode.RECOVERY]:
				var toward_center:=Data.metric(origin-boss.position).normalized()
				if toward_center.is_zero_approx():toward_center=Vector2.RIGHT
				var at:=boss.position+Data.ground(toward_center*60)
				if boss._valid_ground(at):game.player.position=at
			boss._physics_process(1./60)
			valid_floor=valid_floor and boss._valid_ground(boss.position)
			if boss.mode==Boss.Mode.ATTACK:stuck=0
			else:stuck+=1./60;max_recovery=maxf(max_recovery,stuck)
			if frame%120==0:await physics_frame
		for id in Data.load_data()["order"]:
			if int(Data.definition(id)["phase"])<=phase:check(id in seen,"Phase %d autonomously uses %s"%[phase,id])
	check(valid_floor,"All autonomous movement stays on the arena floor")
	check(max_recovery<6,"AI returns to attacks without a stuck recovery or walk-settle loop")
	check(boss.phase==2 and boss.health==boss.max_health/2,"Second phase remains active without unintended health or victory changes")
	check(not game.store.data["flags"]["boss"] and not FileAccess.file_exists(game.store.path),"Autonomous QA cannot award or save a victory")
	game.queue_free()
	await process_frame
	preload("res://scripts/actors/combat_fx.gd").hitstop_enabled=true
	print("GATEKEEPER AI checks=%d passed=%d failures=%s attacks=%s measured_speeds=%s"%[checks,checks-failures.size(),failures,seen,measured_speeds])
	quit(0 if failures.is_empty() else 1)
