extends SceneTree
const Boss=preload("res://scripts/actors/nameless_gatekeeper.gd")
const Data=preload("res://scripts/actors/gatekeeper_attack_data.gd")
const Fx=preload("res://scripts/actors/combat_fx.gd")
var failures: Array[String]=[]
var checks:=0
var game: Node2D
var boss: Boss
var hero: SenuPlayer
var origin:=Vector2.ZERO
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _step(seconds: float, step: float=.01) -> void:
	var remaining:=seconds
	while remaining>0:
		var dt:=minf(step,remaining)
		hero.invulnerability_timer=maxf(0,hero.invulnerability_timer-dt)
		hero.parry_timer=maxf(0,hero.parry_timer-dt)
		boss._physics_process(dt)
		remaining-=dt
func _prepare(id: String,at: Vector2) -> void:
	boss.performance.cancel_attack()
	boss.position=origin
	boss.phase=int(Data.definition(id)["phase"])
	boss.mode=Boss.Mode.APPROACH
	boss.health=boss.max_health
	boss._stagger_resistance_timer=0
	hero.position=origin+at
	hero.health=100
	hero.dead=false
	hero.invulnerability_timer=0
	hero.parry_timer=0
	hero.controls_enabled=true
	hero.cancel_actions()
	hero.clear_movement_slow("gatekeeper")
	check(boss.start_attack(id),id+": starts its own real combat clip")
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():quit(1);return
	Fx.hitstop_enabled=false
	game=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.gatekeeper_encounter.set_process(false)
	game.hud.show_overlay("")
	hero=game.player
	hero.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	boss=game.boss
	origin=boss.position
	check(boss is Boss,"The normal game spawns the specific Gatekeeper, not the common enemy")
	check(game.qa_mode and game.store.path.begins_with("user://qa/"),"World uses an isolated QA slot")
	boss.receive_hit(9999,hero.position)
	check(boss.health==boss.max_health,"Dormant introduction cannot be damaged")
	for id in ["seal_bells","seal_water","seal_stars"]:game.store.data["flags"][id]=true
	hero.position=origin+Vector2(80,10)
	boss.begin_intro()
	game.gatekeeper_encounter._process(.016)
	check(paused and game.hud.overlay=="dialog" and not hero.controls_enabled,"Introduction uses the existing paused dialogue and locks controls")
	game.gatekeeper_encounter.finish_sequence()
	check(not paused and hero.controls_enabled and boss.encounter_active,"Finishing/skipping introduction releases controls and begins the actual fight")
	check(not game.boss_entry_gate.opened,"Encounter temporarily closes the entrance")
	var points={"charge":Vector2(90,0),"sweep":Vector2(42,0),"register":Vector2(35,0),"bell":Vector2(60,0),"warning":Vector2(42,0),"echo_charge":Vector2(90,0),"names":Vector2(60,0),"chains":Vector2(70,0),"last_name":Vector2(39,0)}
	for id in Data.load_data()["order"]:
		_prepare(id,points[id])
		_step(Data.duration(Data.definition(id))-.001)
		var expected:=int(Data.definition(id)["damage"])+(int(Data.definition(id)["events"][0]["damage"]) if id=="echo_charge" else 0)
		check(hero.health==100-expected,id+": damage occurs once per original contact/echo")
		if id=="chains":check(hero._slow_seconds>0 and hero._slow_scale==.8,"Chains apply a short movement slow only on a damaging hit")
		check(not game.store.data["flags"]["boss"],id+": attacking cannot award victory")
	# Every shape rotates with the frozen aim, including floor offsets.
	for direction in [Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
		_prepare("register",Data.ground(direction*35))
		_step(1.12)
		check(hero.health==100-int(Data.definition("register")["damage"]),"Directional ground strike hits its signaled contact")
	# Entering an already-traversed part of the charge must not cause a ghost hit.
	_prepare("charge",Vector2(90,0))
	hero.position=origin+Vector2(100,50)
	_step(1.13)
	hero.position=origin+Vector2(15,0)
	_step(.10)
	check(hero.health==100,"Charge does not damage a trail it has already passed")
	_prepare("echo_charge",Vector2(90,0))
	hero.position=origin+Vector2(100,50)
	_step(1.6)
	hero.position=origin+Vector2(5,0)
	_step(.32)
	check(hero.health==100,"Echo has a moving, frozen-path front rather than an invisible full-lane hit")
	_prepare("warning",Vector2(42,0))
	_step(1.42)
	hero.facing=Vector2.LEFT
	hero.parry_cooldown_remaining=0
	hero.try_parry()
	_step(.05)
	check(hero.health==100 and boss.mode==Boss.Mode.STAGGER and not boss.performance.active,"Warning parry explicitly staggers the attacker and cancels pending contacts")
	check(boss._gap>1.4,"Warning parry grants a clear counterattack window")
	_prepare("last_name",Vector2(39,0))
	_step(1.65/float(boss._config["phase_two_speed"])-.03)
	hero.facing=Vector2.LEFT
	hero.parry_cooldown_remaining=0
	hero.try_parry()
	_step(.05)
	check(hero.health==100 and boss._gap>2,"Precise parry of Last Name grants its longer stagger")
	_prepare("register",Vector2(35,0))
	_step(1.08)
	hero.invulnerability_timer=.28
	_step(.4)
	check(hero.health==100,"Dodge invulnerability consumes the strike without a late repeat")
	_prepare("bell",Vector2(60,0))
	_step(1.60)
	hero.facing=Vector2.LEFT
	hero.parry_timer=.25
	_step(.1)
	check(hero.health==100-int(Data.definition("bell")["damage"]),"Bell resonance must be moved through or dodged, rather than parried")
	boss.reset_enemy()
	boss.start_fight()
	boss.receive_hit(9999,hero.position)
	check(boss.health==boss.max_health/2 and boss.mode==Boss.Mode.TRANSITION,"A burst cannot skip the 50-percent transition")
	boss.receive_hit(9999,hero.position)
	check(boss.health==boss.max_health/2 and not boss.performance.active,"Transition cancels attacks and blocks damage")
	game.gatekeeper_encounter._process(.016)
	game.gatekeeper_encounter.finish_sequence()
	check(boss.phase==2 and hero.controls_enabled and not paused,"Phase dialogue resumes phase two without leaving controls locked")
	_prepare("echo_charge",Vector2(90,0))
	_step(1.2)
	boss.health=10
	boss.receive_hit(10,hero.position)
	var health_before:=hero.health
	_step(1.0)
	check(boss.mode==Boss.Mode.DEFEAT and hero.health==health_before,"Defeat cancels the delayed echo")
	check(not game.store.data["flags"]["boss"],"Victory waits for the human final sequence")
	game.gatekeeper_encounter._process(.016)
	game.gatekeeper_encounter.finish_sequence()
	check(game.store.data["flags"]["boss"] and "porteiro" in game.store.data["defeated"],"Final sequence registers the original flag and ID")
	check(paused and not hero.controls_enabled and game.gatekeeper_encounter._reveal_left>0,"Victory briefly reveals the opened monumental gate")
	game.gatekeeper_encounter._process(1.3)
	check(not paused and hero.controls_enabled,"Gate reveal safely restores player control and pause")
	check(game.store.data["fragments"]==2 and "gatekeeper_key_spear" in game.store.data["collected"],"Victory grants Nous and the modular key-spear once")
	boss.confirm_defeat()
	game.gatekeeper_encounter.award_victory()
	check(game.store.data["fragments"]==2,"Repeated victory signals cannot duplicate rewards")
	check(boss.mode==Boss.Mode.DEAD and is_instance_valid(boss) and boss.collision_layer==0,"The human body remains without blocking the opened passage")
	check(not FileAccess.file_exists(game.store.path),"Victory does not autosave outside a tower")
	check(game.exit_gate.opened and game.boss_entry_gate.opened,"Victory releases both routes")
	game.queue_free()
	await process_frame
	Fx.hitstop_enabled=true
	print("GATEKEEPER COMBAT checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
