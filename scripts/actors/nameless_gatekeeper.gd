extends VeilEnemy
## The A01 boss owns combat only. Encounter sequence/save/rewards live in world.
const AttackData=preload("res://scripts/actors/gatekeeper_attack_data.gd")
const AttackPlayer=preload("res://scripts/actors/gatekeeper_attack_player.gd")
const GateView=preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const COMBAT_PATH="res://resources/bosses/gatekeeper_combat.json"
const Sfx=preload("res://scripts/audio/sfx.gd")
const FOOT=preload("res://assets/audio/sfx/gatekeeper_step.wav")
const BREATH=preload("res://assets/audio/sfx/gatekeeper_breath.wav")
enum Mode { DORMANT, INTRO, APPROACH, ATTACK, RECOVERY, STAGGER, TRANSITION, DEFEAT, DEAD }
signal sequence_requested(kind: String)
signal attack_started(id: String)
signal phase_changed(value: int)
signal vocal_cue(kind: String)
var mode: Mode=Mode.DORMANT
var phase:=1
var performance: AttackPlayer
var encounter_active:=false
var narrative_clip:="kneel"
var narrative_elapsed:=0.0
var marker_offset:=Vector2(0,-7)
var _config: Dictionary={}
var _cooldowns: Dictionary={}
var _recent: Array[String]=[]
var _taught: Array[String]=[]
var _hits: Dictionary={}
var _live_attack: Dictionary={}
var _attack_id:=""
var _gap:=1.2
var _ground: Dictionary={}
var _echo_from:=Vector2.ZERO
var _echo_to:=Vector2.ZERO
var _victory_emitted:=false
var _intro_seen:=false
var _attack_completed:=false
var _step_distance:=0.0
var _breath_left:=5.0
var _voice_config: Dictionary={}

func _ready() -> void:
	is_boss=true
	archetype="keeper"
	super._ready()
	_config=JSON.parse_string(FileAccess.get_file_as_string(COMBAT_PATH))
	_voice_config=JSON.parse_string(FileAccess.get_file_as_string("res://resources/bosses/gatekeeper_audio.json"))
	max_health=int(_config["health"])
	health=max_health
	move_speed=float(_config["move_speed"])
	_ground=PortLayout.tile_catalog()
	set_meta("owns_attack_audio",true)
	performance=AttackPlayer.new()
	performance.name="GatekeeperAnimation"
	performance.live_art=true
	performance.use_parent_material=true
	add_child(performance)
	performance.set_physics_process(false)
	performance.visible=false
	performance.contact.connect(_on_contact)
	performance.attack_finished.connect(_on_attack_finished)
	if is_instance_valid(target):performance.feedback=target.get("_fx")
	_gap=1.2

func begin_intro() -> void:
	if mode!=Mode.DORMANT:return
	mode=Mode.INTRO
	narrative_clip="rise"
	narrative_elapsed=0
	sequence_requested.emit("intro")

func start_fight() -> void:
	if mode not in [Mode.INTRO,Mode.DORMANT]:return
	_intro_seen=true
	encounter_active=true
	mode=Mode.RECOVERY
	_gap=1.2
	performance.visible=true
	queue_redraw()

func resume_phase_two() -> void:
	if mode!=Mode.TRANSITION:return
	phase=2
	phase_changed.emit(2)
	mode=Mode.RECOVERY
	_gap=1.25
	performance.visible=true
	performance.idle_clip="idle_desperate"
	queue_redraw()

func set_loaded_defeat() -> void:
	_victory_emitted=true
	dead=true
	health=0
	mode=Mode.DEAD
	state=State.DEAD
	encounter_active=false
	performance.visible=false
	collision_layer=0
	collision_mask=0
	remove_from_group("enemies")
	narrative_clip="dead"
	narrative_elapsed=10
	queue_redraw()

func confirm_defeat() -> void:
	if mode!=Mode.DEFEAT or _victory_emitted:return
	set_loaded_defeat()
	defeated.emit(enemy_id,true)

func advance_narrative(delta: float) -> void:
	narrative_elapsed+=delta
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):return
	if bool(target.get("dead")):
		if encounter_active:reset_enemy()
		return
	_time+=delta
	_path_refresh-=delta
	_breath_left-=delta
	if _breath_left<=0 and mode not in [Mode.DORMANT,Mode.DEAD,Mode.DEFEAT]:
		_breath_left=3.4 if phase==2 else 6.0
		var pool=Sfx.pool_for(self)
		if pool!=null:pool.play_stream(BREATH,global_position,-22,.85,"Vozes",self)
	_hurt_visual=maxf(0,_hurt_visual-delta)
	_stagger_resistance_timer=maxf(0,_stagger_resistance_timer-delta)
	for id in _cooldowns:_cooldowns[id]=maxf(0,float(_cooldowns[id])-delta)
	if mode in [Mode.DORMANT,Mode.INTRO,Mode.TRANSITION,Mode.DEFEAT,Mode.DEAD]:return
	if not bool(target.get("controls_enabled")):return
	if _hurt_visual>0 and mode in [Mode.APPROACH,Mode.RECOVERY]:
		performance.advance(delta)
		performance.visible=false
		narrative_clip="hurt"
		narrative_elapsed=.17-_hurt_visual
		queue_redraw()
		return
	performance.visible=true
	if mode==Mode.ATTACK:_advance_attack(delta)
	else:performance.advance(delta)
	if mode==Mode.ATTACK:return
	if mode==Mode.STAGGER:
		performance.visible=false
		narrative_clip="stagger"
		narrative_elapsed+=delta
		queue_redraw()
		state=State.STAGGER
		_gap-=delta
		if _gap<=0:mode=Mode.RECOVERY;_gap=.6
		return
	if mode==Mode.RECOVERY:
		state=State.RECOVER
		_gap-=delta
		if _gap>0:return
		mode=Mode.APPROACH
	var offset:=_metric(target.global_position-global_position)
	if PortLayout.room_at(target.global_position)!="b1":
		reset_enemy()
		return
	facing=offset.normalized()
	performance.art_direction=GateView.direction_name(facing)
	performance.idle_clip="idle_desperate" if phase==2 else "idle_exhausted"
	var selected:=select_attack(offset.length())
	if not selected.is_empty():
		if performance.walking:
			performance.update_walk(_distance_walked,false)
			mode=Mode.RECOVERY
			_gap=GateView.settle_duration()
		else:start_attack(selected)
		return
	state=State.CHASE
	velocity=AttackData.ground(_approach_direction())*move_speed*(float(_config["phase_two_move_scale"]) if phase==2 else 1)
	var before:=global_position
	_safe_move(velocity*delta)
	var distance:=_metric(global_position-before).length()
	if distance>.03:performance.art_direction=GateView.direction_name(_metric(global_position-before))
	_distance_walked+=distance
	_step_distance+=distance
	if _step_distance>=11:
		_step_distance=fmod(_step_distance,11)
		var pool=Sfx.pool_for(self)
		if pool!=null:pool.play_stream(FOOT,global_position,-15,.9,"SFX",self)
	performance.update_walk(_distance_walked,distance>.03)
	queue_redraw()

func _approach_direction() -> Vector2:
	var offset:=target.global_position-global_position
	if not test_move(global_transform,offset-offset.normalized()*24) and _valid_ground(global_position+offset*.5):return _metric(offset).normalized()
	return super._route_direction()

func select_attack(distance: float) -> String:
	var choices: Array[String]=[]
	for id in AttackData.load_data()["order"]:
		var data:=AttackData.definition(id)
		var tune: Dictionary=_config["attacks"][id]
		if int(data["phase"])>phase or float(_cooldowns.get(id,0))>0:continue
		if distance<float(tune["min_distance"]) or distance>float(tune["max_distance"]):continue
		if _recent.size()>0 and _recent.back()==id:continue
		choices.append(id)
	if choices.is_empty():return ""
	for id in choices:
		if phase==2 and int(AttackData.definition(id)["phase"])==2 and id not in _taught:return id
	for id in choices:
		if id not in _taught:return id
	return choices[posmod(_attack_count*7+phase,choices.size())]

func start_attack(id: String) -> bool:
	if mode not in [Mode.APPROACH,Mode.RECOVERY] or int(AttackData.definition(id).get("phase",99))>phase:return false
	_attack_id=id
	_live_attack=AttackData.definition(id).duplicate(true)
	var tune: Dictionary=_config["attacks"][id]
	if tune.has("impact"):_live_attack["impact"]=tune["impact"].duplicate(true)
	for event in tune.get("events",[]):_live_attack["events"].append(event.duplicate(true))
	_attack_direction=_metric(target.global_position-global_position).normalized()
	if _attack_direction.is_zero_approx():_attack_direction=Vector2.RIGHT
	facing=_attack_direction
	if str(_live_attack["shape"]["kind"])=="zones":
		var valid: Array=[]
		for at in _live_attack["shape"]["zones"]:
			if _valid_ground(global_position+AttackData.orient(AttackData.vector(at),_attack_direction)):valid.append(at)
		_live_attack["shape"]["zones"]=valid if not valid.is_empty() else [[0,0]]
	_attack_origin=global_position
	_echo_from=global_position
	_echo_to=global_position
	_hits.clear()
	performance.aim=_attack_direction
	performance.art_direction=GateView.direction_name(_attack_direction)
	performance.update_walk(_distance_walked,false)
	if not performance.play_attack(id,_live_attack):return false
	mode=Mode.ATTACK
	state=State.WINDUP
	_attack_count+=1
	if phase==2 and _attack_count%3==0:play_vocal("effort")
	if id not in _taught:_taught.append(id)
	_recent.append(id)
	if _recent.size()>2:_recent.pop_front()
	_cooldowns[id]=float(_live_attack["cooldown"])*( .86 if phase==2 else 1)
	attack_started.emit(id)
	return true

func _advance_attack(delta: float) -> void:
	var tune: Dictionary=_config["attacks"][_attack_id]
	var rate:=float(_config["phase_two_speed"]) if phase==2 else 1.0
	var old:=performance.elapsed
	var next:=old+delta*rate
	var contact:=AttackData.contact_time(_live_attack)
	_attack_completed=false
	var motion_before:=global_position
	if tune.has("motion_distance"):
		var begin:=contact-float(tune["motion_lead"])
		var end:=begin+float(tune["motion_seconds"])
		var step:=maxf(0,minf(next,end)-maxf(old,begin))
		if step>0:
			_safe_move(AttackData.ground(_attack_direction)*float(tune["motion_distance"])*step/float(tune["motion_seconds"]))
			_echo_to=global_position
	performance.echo_path=PackedVector2Array([_echo_from,_echo_to])
	performance.advance(delta*rate)
	if mode!=Mode.ATTACK:return
	var since:=performance.elapsed-contact
	state=State.WINDUP if since<0 else (State.STRIKE if since<float(tune["active_seconds"]) else State.RECOVER)
	if since>=0 and since<=float(tune["active_seconds"]):_try_damage("primary",_live_attack,since)
	# Sweep moving fronts across a large physics step as well as at 60 Hz.
	var previous_since:=old-contact
	if _attack_id=="bell":
		var arrival:=_metric(target.global_position-global_position).length()/float(_live_attack["shape"]["reach"])*float(_live_attack["shape"]["wave_seconds"])
		if previous_since<=arrival and since>=arrival:_try_damage("primary",_live_attack,arrival)
	if _attack_id=="chains":
		var arrival:=_metric(target.global_position-global_position).dot(_attack_direction)/float(_live_attack["shape"]["reach"])*.30
		if arrival>=0 and previous_since<=arrival and since>=arrival:_try_damage("primary",_live_attack,arrival+.0001)
	if _attack_id in ["charge","echo_charge"] and since>=0 and previous_since<float(tune["active_seconds"]) and not _hits.has("primary"):
		var point:=AttackData.metric(target.global_position)
		var start:=AttackData.metric(motion_before)
		var end:=AttackData.metric(global_position)+_attack_direction*float(tune["contact_reach"])
		if Geometry2D.get_closest_point_to_segment(point,start,end).distance_to(point)<=18:_hit_target("primary",int(_live_attack["damage"]),true)
	if _attack_id=="echo_charge" and previous_since<=.89 and since>=.65:_try_echo(maxf(0,previous_since-.65),minf(.24,since-.65))
	if _attack_id=="names" and since>=.8 and since<=1.1:_try_damage("zones",_live_attack,since)
	if _attack_completed and mode==Mode.ATTACK:
		mode=Mode.RECOVERY
		state=State.RECOVER
		_gap=float(_config["phase_two_gap"] if phase==2 else _config["recovery_gap"])

func _try_damage(key: String, attack: Dictionary, since: float) -> void:
	if _hits.has(key) or not is_instance_valid(target):return
	var data:=attack.duplicate(true)
	if _attack_id in ["charge","echo_charge"]:data["shape"]["reach"]=_config["attacks"][_attack_id]["contact_reach"]
	if _attack_id=="chains":data["shape"]["reach"]=float(data["shape"]["reach"])*clampf(since/.30,0,1)
	if not AttackData.contains_point(data,target.global_position-global_position,_attack_direction,since,6):return
	_hit_target(key,int(attack["damage"]),str(attack["parry"])!="dodge")

func _try_echo(from_time: float, to_time: float) -> void:
	if _hits.has("echo"):return
	var a:=AttackData.metric(_echo_from.lerp(_echo_to,clampf(from_time/.24,0,1)))
	var b:=AttackData.metric(_echo_from.lerp(_echo_to,clampf(to_time/.24,0,1)))+_attack_direction*53
	var point:=AttackData.metric(target.global_position)
	if Geometry2D.get_closest_point_to_segment(point,a,b).distance_to(point)<=18:
		for event in _live_attack.get("events",[]):
			if event.get("kind")=="echo":_hit_target("echo",int(event["damage"]),false);break

func _hit_target(key: String, damage: int, parryable: bool) -> void:
	var query:=PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():return
	_hits[key]=true # Evasion/parry consume the contact, so i-frames cannot expire into a second hit.
	var result: int=target.receive_attack(damage,global_position,self,parryable)
	if result==SenuPlayer.AttackResult.HIT and _attack_id=="chains" and not target.dead and mode==Mode.ATTACK:target.apply_movement_slow(.8,.6,"gatekeeper")

func _on_contact(_id: String,kind: String,_at: Vector2) -> void:
	if mode!=Mode.ATTACK:return
	if kind=="zones":_try_damage("zones",_live_attack,.80001)
	elif kind=="echo":pass # Its moving front is sampled from the same clock below.
	elif not _hits.has("primary"):_try_damage("primary",_live_attack,0)

func _on_attack_finished(_id: String) -> void:
	_attack_completed=true

func on_parried(precise: bool) -> void:
	if mode!=Mode.ATTACK:return
	var seconds:=1.5 if _attack_id=="warning" else (.8 if _attack_id!="last_name" else (2.1 if precise else .9))
	receive_hit(5,target.global_position,false)
	if mode in [Mode.TRANSITION,Mode.DEFEAT,Mode.DEAD]:return
	_stagger(seconds)

func _stagger(seconds: float) -> void:
	performance.cancel_attack()
	mode=Mode.STAGGER
	state=State.STAGGER
	_gap=seconds
	narrative_elapsed=0
	_stagger_resistance_timer=2.8
	_hits.clear()
	queue_redraw()

func receive_hit(amount: int, from_position: Vector2, stagger: bool=false) -> void:
	if mode in [Mode.DORMANT,Mode.INTRO,Mode.TRANSITION,Mode.DEFEAT,Mode.DEAD] or amount<=0:return
	var next:=maxi(0,health-amount)
	_hurt_visual=.17
	_hurt_direction=(global_position-from_position).normalized()
	if phase==1 and next<=max_health/2:
		health=max_health/2
		_cancel_combat()
		mode=Mode.TRANSITION
		narrative_clip="despair"
		narrative_elapsed=0
		play_vocal("despair")
		sequence_requested.emit("phase")
	elif next<=0:
		health=0
		_cancel_combat()
		mode=Mode.DEFEAT
		encounter_active=false
		remove_from_group("enemies")
		collision_layer=0
		collision_mask=0
		narrative_clip="defeat"
		narrative_elapsed=0
		play_vocal("last_breath")
		sequence_requested.emit("defeat")
	else:
		health=next
		if stagger and _stagger_resistance_timer<=0:_stagger(.7)
	queue_redraw()

func play_vocal(kind: String) -> void:
	vocal_cue.emit(kind)
	var cue: Dictionary=_voice_config.get(kind,{})
	if cue.is_empty():return
	var stream:=load(str(cue["stream"])) as AudioStream
	var pool=Sfx.pool_for(self)
	if stream!=null and pool!=null:pool.play_stream(stream,global_position,float(cue["volume_db"]),float(cue["pitch"]),"Vozes",self)

func _cancel_combat() -> void:
	performance.cancel_attack()
	performance.visible=false
	velocity=Vector2.ZERO
	_hits.clear()
	if is_instance_valid(target):target.clear_movement_slow("gatekeeper")

func reset_enemy() -> void:
	if _victory_emitted:return
	_cancel_combat()
	super.reset_enemy()
	if not is_in_group("enemies"):add_to_group("enemies")
	phase=1
	encounter_active=false
	mode=Mode.DORMANT
	_cooldowns.clear()
	_recent.clear()
	_taught.clear()
	_gap=1.2
	narrative_clip="kneel"
	narrative_elapsed=0
	performance.visible=false
	queue_redraw()

func _valid_ground(at: Vector2) -> bool:
	return PortLayout.room_at(at)=="b1" and _ground.has(Vector2i(PortLayout.unproject(at).round()))

func _safe_move(motion: Vector2) -> void:
	var steps:=maxi(1,ceili(motion.length()/4))
	for i in range(steps):
		var part:=motion/steps
		if not _valid_ground(global_position+part):break
		if move_and_collide(part)!=null:break

func _draw() -> void:
	if performance!=null and performance.visible:return
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.36))
	draw_circle(Vector2.ZERO,10,Color(0,0,0,.3))
	draw_set_transform(Vector2.ZERO)
	GateView.draw_live(self,narrative_clip,"down_right" if mode in [Mode.DORMANT,Mode.INTRO,Mode.TRANSITION,Mode.DEFEAT,Mode.DEAD] else GateView.direction_name(facing),narrative_elapsed)
