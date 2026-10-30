extends SceneTree
const Data = preload("res://scripts/actors/gatekeeper_attack_data.gd")
const Driver = preload("res://scripts/actors/gatekeeper_attack_player.gd")
const View = preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const Fx = preload("res://scripts/actors/combat_fx.gd")
var checks := 0
var failures: Array[String] = []
var cues: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var root_actor := Node2D.new()
	root.add_child(root_actor)
	var fx := Fx.new()
	root_actor.add_child(fx)
	fx.set_process(false)
	fx.set_physics_process(false)
	Fx.hitstop_enabled=false
	var driver := Driver.new()
	root_actor.add_child(driver)
	driver.set_physics_process(false)
	driver.feedback=fx
	driver.contact.connect(func(id,kind,_at):cues.append(id+":"+kind))
	await process_frame
	var data := Data.load_data()
	check(data["order"].size()==9,"All nine specified attacks have JSON definitions")
	for id in data["order"]:
		driver.cancel_attack()
		cues.clear()
		var attack := Data.definition(id)
		var at := Data.contact_time(attack)
		check(driver.play_attack(id),id+": starts from ready pose")
		check(not driver.play_attack(id),id+": repeated input cannot restart or duplicate contact")
		driver.advance(at-.001)
		check(cues.is_empty(),id+": windup emits no premature impact")
		check(not View.sample(id,"down_right",at-.001)["contact_pose"],id+": atlas and JSON agree before contact")
		driver.advance(.002)
		check(cues.size()==1,id+": exactly one primary impact at contact")
		check(View.sample(id,"down_right",at+.001)["contact_pose"],id+": contact cel matches the impact cue")
		driver.advance(Data.duration(attack)+.1)
		check(cues.size()==1+attack["events"].size(),id+": delayed cues fire once, including large time steps")
		var count := cues.size()
		driver.advance(10)
		check(cues.size()==count and not driver.active,id+": recovery ends without repeating effects")
		check(View.sample(id,"down_right",100)["pose"]==8,id+": complete animation returns to guard")
		driver.cancel_attack()
		driver.play_attack(id)
		driver.advance(at*.5)
		driver.cancel_attack()
		cues.clear()
		driver.advance(10)
		check(cues.is_empty(),id+": cancellation clears every pending contact")
	driver.play_attack("register")
	var elapsed := driver.elapsed
	paused=true
	driver.advance(10)
	check(driver.elapsed==elapsed,"Pause freezes the presentation clock and contacts")
	paused=false
	driver.cancel_attack()
	var ring := Data.definition("bell")
	check(not Data.contains_point(ring,Vector2.ZERO,Vector2.RIGHT,.4),"Bell wave does not incorrectly damage its already-passed center")
	check(Data.contains_point(ring,Vector2(57.5,0),Vector2.RIGHT,.425),"Bell wave danger follows its expanding rim")
	check(not Data.contains_point(ring,Vector2(100,0),Vector2.RIGHT,.1),"Bell cannot hit distant floor before its wave arrives")
	var zones := Data.definition("names")
	check(not Data.contains_point(zones,Vector2(60,0),Vector2.RIGHT,.79),"Names stay safe during their individual warning")
	check(Data.contains_point(zones,Vector2(60,0),Vector2.RIGHT,.81),"Names activate after the signaled delay")
	check(not Data.contains_point(zones,Vector2(60,0),Vector2.RIGHT,1.11),"Names stop being dangerous after their short pulse")
	check(not Data.contains_point(Data.definition("charge"),Vector2(-20,0),Vector2.RIGHT,0),"Charge shape cannot reach behind the attacker")
	check(not Data.contains_point(Data.definition("sweep"),Vector2(-30,0),Vector2.RIGHT,0),"Sweep respects the indicated front arc")
	fx._particles.clear()
	fx.ground_impact(Vector2(50,30),2)
	var stones: Array = fx._particles.filter(func(p):return p["kind"]==Fx.Kind.STONE)
	check(not stones.is_empty(),"Ground impact creates actual stone fragments in the approved FX system")
	fx._update_particles(.05)
	check(float(stones[0]["height"])>1 and stones[0]["p"]!=Vector2(50,30),"Stone height and ground travel are separate from its shadow")
	for i in range(10):fx.ground_impact(Vector2.ZERO,2)
	stones=fx._particles.filter(func(p):return p["kind"]==Fx.Kind.STONE)
	check(stones.size()<=72,"Repeated heavy impacts keep a bounded stone particle budget")
	fx._update_particles(2)
	check(fx._particles.is_empty(),"Impact particles expire instead of remaining on the floor forever")
	Fx.hitstop_enabled=true
	root_actor.queue_free()
	await process_frame
	print("GATEKEEPER ATTACKS checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
