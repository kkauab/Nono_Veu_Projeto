extends VeilEnemy
## Interactive ART rehearsal: existing navigation/collision and walk stride,
## with nine independent JSON clips. No damage, defeat signal or rewards.
const AttackPlayback = preload("res://scripts/actors/gatekeeper_attack_player.gd")
const Attacks = preload("res://scripts/actors/gatekeeper_attack_data.gd")
const Art = preload("res://scripts/actors/nameless_gatekeeper_view.gd")
signal clip_started(id: String)
var performance: AttackPlayback
var automatic := true
var next_attack := 0
var rehearsal_cooldown := 1.0
var _rehearsal_ground: Dictionary={}
var _pending_clip := ""

func _ready() -> void:
	is_boss=true
	archetype="keeper"
	super._ready()
	move_speed=float(Art.walk_settings()["move_speed"])
	_rehearsal_ground=PortLayout.tile_catalog()
	# Navigation/collision are reused; combat feedback belongs to the clip
	# controller here. Avoid duplicate windup sounds and false Senu hit effects.
	remove_from_group("enemies")
	performance=AttackPlayback.new()
	add_child(performance)
	performance.set_physics_process(false)
	if is_instance_valid(target):performance.feedback=target.get("_fx")
	performance.attack_finished.connect(_on_finished)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):return
	if not _pending_clip.is_empty():
		velocity=Vector2.ZERO
		performance.advance(delta)
		if performance.locomotion_sample()["clip"]=="idle":
			var id:=_pending_clip
			_pending_clip=""
			_start_clip(id)
		return
	if performance.active:
		velocity=Vector2.ZERO
		performance.advance(delta)
		var definition := Attacks.definition(performance.active_id)
		var t := performance.elapsed-Attacks.contact_time(definition)
		state=State.WINDUP if t<0 else (State.STRIKE if t<.16 else State.RECOVER)
		return
	performance.advance(delta)
	rehearsal_cooldown=maxf(0,rehearsal_cooldown-delta)
	# The existing enemy owns navigation, obstacle avoidance, foot collision,
	# and distance-driven steps. No second navigation implementation.
	state=State.CHASE
	super._physics_process(delta)
	performance.update_walk(_distance_walked,_animation_moving)

func _route_direction() -> Vector2:
	# On the open arena floor, approach directly instead of alternating tile
	# centers. Keep the existing navigation for props, gaps and other rooms.
	if PortLayout.room_at(global_position)=="b1" and PortLayout.room_at(target.global_position)=="b1":
		var offset:=target.global_position-global_position
		var steps:=maxi(1,ceili(offset.length()/8))
		var clear:=true
		for i in range(steps+1):
			if not _rehearsal_ground.has(Vector2i(PortLayout.unproject(global_position+offset*float(i)/steps).round())):
				clear=false
				break
		if clear and not test_move(global_transform,offset-offset.normalized()*24):
			return _metric(offset).normalized()
	return super._route_direction()

func _begin_windup() -> void:
	if automatic and rehearsal_cooldown<=0:
		var order: Array=Attacks.load_data()["order"]
		play_clip(str(order[next_attack%order.size()]))
		next_attack+=1

func play_clip(id: String) -> bool:
	if performance.active or not _pending_clip.is_empty() or Attacks.definition(id).is_empty():return false
	if performance.walking:
		performance.update_walk(_distance_walked,false)
		_pending_clip=id
		velocity=Vector2.ZERO
		return true
	return _start_clip(id)

func _start_clip(id: String) -> bool:
	if not performance.play_attack(id):return false
	state=State.WINDUP
	velocity=Vector2.ZERO
	clip_started.emit(id)
	return true

func _on_finished(_id: String) -> void:
	state=State.CHASE
	rehearsal_cooldown=.9

func receive_hit(_amount: int, _from: Vector2, _stagger: bool=false) -> void:
	pass # This isolated review never grants victory or consumes the real save.

func _draw() -> void:
	pass # The child draws the real Gatekeeper atlas, never the common keeper.
