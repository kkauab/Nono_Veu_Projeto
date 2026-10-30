extends SceneTree
const View=preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const Driver=preload("res://scripts/actors/gatekeeper_attack_player.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)
func _run() -> void:
	var driver:=Driver.new()
	root.add_child(driver)
	driver.set_physics_process(false)
	var settings:=View.walk_settings()
	check(View.sample("walk","down_right",0,0,true)["texture"].get_size()==Vector2(1120,1120),"Actual refined walk atlas is loaded separately from attacks")
	for phase in range(16):
		driver.cancel_attack()
		driver.update_walk(100,true)
		var distance:=float(phase)*float(settings["walk_stride"])/16+.01
		driver.update_walk(100+distance,true)
		var before:=driver.locomotion_sample()
		driver.update_walk(100+distance,false)
		var after:=driver.locomotion_sample()
		check(before["texture"]==after["texture"] and before["frame"]==after["frame"],"Phase %d: stopping begins on the last actual walking cel"%phase)
		driver.advance(.04)
		check(driver.locomotion_sample()["clip"]=="walk_settle" and driver.locomotion_sample()["frame"]>=16,"Phase %d: feet use their own closing-step poses"%phase)
		driver.advance(1)
		check(driver.locomotion_sample()["clip"]=="idle" and not driver.walking,"Phase %d: stopped feet finish in the original guard"%phase)
		driver.update_walk(900,true)
		check(driver.locomotion_sample()["pose"]==4,"Phase %d: restarting begins in compact passing pose"%phase)
	driver.update_walk(900,false)
	var elapsed:=driver._settle_elapsed
	paused=true
	driver.advance(3)
	check(driver._settle_elapsed==elapsed,"Pause freezes the closing steps")
	paused=false
	check(driver.play_attack("register") and not driver.walking,"An attack takes precedence over closing steps")
	check(not View.sample("register","down_right",1.09)["contact_pose"] and View.sample("register","down_right",1.11)["contact_pose"],"Refining footsteps preserves the attack contact timing")
	driver.queue_free()
	await process_frame
	print("GATEKEEPER WALK checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
