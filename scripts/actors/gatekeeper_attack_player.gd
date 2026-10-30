extends Node2D
## JSON-driven presentation/contact controller. No save/reward/AI ownership.
## The real boss consumes contact signals; art-only reviews do not apply damage.
signal contact(attack_id: String, kind: String, local_point: Vector2)
signal attack_finished(attack_id: String)
const Data = preload("res://scripts/actors/gatekeeper_attack_data.gd")
const View = preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const BELL = preload("res://assets/audio/sfx/gatekeeper_bell.wav")
const CHAIN = preload("res://assets/audio/sfx/gatekeeper_chain.wav")

var feedback: Node2D
var active_id := ""
var active := false
var elapsed := 0.0
var aim := Vector2.RIGHT
var distance_walked := 0.0
var walking := false
var art_direction := "down_right"
var live_art := false
var idle_clip:="idle"
var echo_path := PackedVector2Array()
var _walk_origin := 0.0
var _settle_elapsed := 1.0
var _attack: Dictionary = {}
var _events: Array[Dictionary] = []
var _event_index := 0
var _cracks: Array[Dictionary] = []
var _wave_dust_step := 0
var _echo_time := -1.0
var _voices: Array[WeakRef]=[]

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	Sfx.pool_for(self)

func play_attack(id: String, override_definition: Dictionary={}) -> bool:
	if active: return false
	var definition: Dictionary = Data.definition(id).duplicate(true) if override_definition.is_empty() else override_definition.duplicate(true)
	if definition.is_empty(): return false
	_voices=_voices.filter(func(reference):
		var voice=reference.get_ref()
		return is_instance_valid(voice) and int(voice.get_meta("sfx_owner",0))==get_instance_id() and voice.playing)
	active_id=id
	walking=false
	_settle_elapsed=1.0
	_attack=definition
	elapsed=0
	_event_index=0
	_wave_dust_step=0
	_echo_time=-1
	echo_path.clear()
	_events.clear()
	var impact: Dictionary = definition["impact"].duplicate(true)
	impact["time"]=Data.contact_time(definition)
	_events.append(impact)
	for extra in definition.get("events",[]):
		var cue: Dictionary = extra.duplicate(true)
		cue["time"]=Data.contact_time(definition)+float(extra["after_contact"])
		_events.append(cue)
	_events.sort_custom(func(a,b):return float(a["time"])<float(b["time"]))
	active=true
	if is_inside_tree():_remember_voice(Sfx.play(self,"enemy_windup",global_position,-3,.8))
	queue_redraw()
	return true

func cancel_attack() -> void:
	if is_instance_valid(feedback):feedback.call("clear_source",get_instance_id())
	for ref in _voices:
		var voice=ref.get_ref()
		if is_instance_valid(voice) and int(voice.get_meta("sfx_owner",0))==get_instance_id():voice.stop()
	_voices.clear()
	active=false
	active_id=""
	elapsed=0
	_events.clear()
	_event_index=0
	_cracks.clear()
	_echo_time=-1
	walking=false
	_settle_elapsed=1.0
	queue_redraw()

func _remember_voice(voice: Node) -> void:
	if voice==null:return
	voice.set_meta("sfx_owner",get_instance_id())
	_voices.append(weakref(voice))

func update_walk(total_distance: float, moving: bool) -> void:
	if moving and not walking:
		_walk_origin=total_distance
		_settle_elapsed=1.0
	elif walking and not moving and not active:
		_settle_elapsed=0.0
	walking=moving
	if moving:distance_walked=total_distance-_walk_origin
	queue_redraw()

func locomotion_sample() -> Dictionary:
	var clip:="walk" if walking else ("walk_settle" if _settle_elapsed<View.settle_duration() else idle_clip)
	var time:=_settle_elapsed if clip=="walk_settle" else elapsed
	if live_art:return View.sample_live(clip,art_direction,time,distance_walked,walking)
	return View.sample(clip,"down_right",time,distance_walked,walking)

func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if delta<=0 or (is_inside_tree() and get_tree().paused):return
	if _settle_elapsed<View.settle_duration():
		_settle_elapsed+=delta
		queue_redraw()
	var had_cracks := not _cracks.is_empty()
	for i in range(_cracks.size()-1,-1,-1):
		_cracks[i]["life"]=float(_cracks[i]["life"])-delta
		if float(_cracks[i]["life"])<=0:_cracks.remove_at(i)
	if not active:
		elapsed+=delta
		if live_art:queue_redraw()
		if had_cracks:queue_redraw()
		return
	elapsed+=delta
	# No Timers/awaits: cancellation removes every pending delayed contact.
	while _event_index<_events.size() and elapsed+0.00001>=float(_events[_event_index]["time"]):
		var cue: Dictionary = _events[_event_index]
		_event_index+=1
		_emit_cue(cue)
		if not active:return
	if str(_attack["shape"]["kind"])=="ring":_wave_dust()
	queue_redraw()
	if elapsed>=Data.duration(_attack):
		active=false
		attack_finished.emit(active_id)

func _emit_cue(cue: Dictionary) -> void:
	var kind := str(cue["kind"])
	var at := Data.orient(Data.vector(cue.get("offset",[0,0])),aim)
	var strength := float(cue.get("strength",.35))
	if is_instance_valid(feedback):
		match kind:
			"stone", "sweep", "scrape", "echo", "chains":
				feedback.call("ground_impact",global_position+at,strength,aim,get_instance_id())
			"bell":feedback.call("ground_dust",global_position,7,get_instance_id())
	if kind=="stone":_cracks.append({"at":at,"life":1.1,"strength":strength})
	if kind=="echo":_echo_time=float(cue["time"])
	if kind=="zones":
		for zone in _attack["shape"]["zones"]:
			var where := Data.orient(Data.vector(zone),aim)
			if is_instance_valid(feedback):feedback.call("ground_impact",global_position+where,.8,aim,get_instance_id())
			_cracks.append({"at":where,"life":.7,"strength":.6})
	if kind in ["bell","chains"] and is_inside_tree():
		var pool = Sfx.pool_for(self)
		if pool!=null:_remember_voice(pool.play_stream(BELL if kind=="bell" else CHAIN,global_position,-8,.85,"SFX",self))
	contact.emit(active_id,kind,at)

func _wave_dust() -> void:
	var t := elapsed-Data.contact_time(_attack)
	var length := float(_attack["shape"]["wave_seconds"])
	if t<0 or t>length:return
	var step := floori(t/.15)
	if step<=_wave_dust_step:return
	_wave_dust_step=step
	var radius := float(_attack["shape"]["reach"])*t/length
	if is_instance_valid(feedback):
		for i in range(8):
			var angle := float(i)*TAU/8
			feedback.call("ground_dust",global_position+Data.ground(Vector2(cos(angle),sin(angle))*radius),2,get_instance_id())

func _ellipse(at: Vector2,radius: float,color: Color,width: float=1.0) -> void:
	var points := PackedVector2Array()
	for i in range(41):
		var angle := i*TAU/40.0
		points.append(at+Data.ground(Vector2(cos(angle),sin(angle))*radius))
	draw_polyline(points,color,width,false)

func _warning() -> void:
	var shape: Dictionary = _attack["shape"]
	var kind := str(shape["kind"])
	var contact_at := Data.contact_time(_attack)
	var t := elapsed-contact_at
	var color := Color("c7a263",.35+minf(.35,elapsed/maxf(.01,contact_at)*.35))
	match kind:
		"disc":
			if t<.16:_ellipse(Data.orient(Data.vector(shape["offset"]),aim),float(shape["radius"]),color)
		"zones":
			if t<float(shape["delay"])+float(shape["active_seconds"]):
				for zone in shape["zones"]:
					var at := Data.orient(Data.vector(zone),aim)
					_ellipse(at,float(shape["radius"]),color)
					# Small strokes suggest worn names, not a new alphabet reveal.
					for line in range(3):draw_line(at+Vector2(-7+line*5,-2),at+Vector2(-5+line*5,3),color)
		"ring":
			if t<0:_ellipse(Vector2.ZERO,float(shape["reach"]),Color(color,.25))
			elif t<=float(shape["wave_seconds"]):
				var radius := float(shape["reach"])*t/float(shape["wave_seconds"])
				_ellipse(Vector2.ZERO,radius,Color("d2bb87",.8))
				_ellipse(Vector2.ZERO,maxf(0,radius-float(shape["width"])),Color("b5a487",.4))
		"line":
			if t<.16:
				var end := aim.normalized()*float(shape["reach"])
				var across := Vector2(-aim.y,aim.x).normalized()*float(shape["width"])
				for side in [-1,1]:draw_line(Data.ground(across*side),Data.ground(end+across*side),color)
		"arc":
			if t<.16:
				var points := PackedVector2Array()
				var arc := deg_to_rad(float(shape["degrees"]))
				for i in range(31):
					var angle := aim.angle()-arc*.5+arc*i/30.0
					points.append(Data.ground(Vector2(cos(angle),sin(angle))*float(shape["reach"])))
				draw_polyline(points,color,1,false)

func _draw() -> void:
	if active_id=="echo_charge" and active and echo_path.size()>=2:
		var t:=elapsed-Data.contact_time(_attack)
		if t>=.18 and t<.65:
			var across:=Data.ground(Vector2(-aim.y,aim.x)*12)
			for side in [-1,1]:draw_line((echo_path[0]-global_position+across*side).round(),(echo_path[1]-global_position+Data.ground(aim)*53+across*side).round(),Color("9ba6a0",.30),1)
	for crack in _cracks:
		var at: Vector2 = crack["at"]
		var color := Color("302d29",minf(.7,float(crack["life"])))
		for i in range(4):
			var direction := Vector2.from_angle(i*1.7+.25)
			var end := at+Data.ground(direction*(8+float(crack["strength"])*6))
			draw_polyline(PackedVector2Array([at.round(),at.lerp(end,.5).round()+Vector2(i%2,1),end.round()]),color,1,false)
	if active:_warning()
	if _echo_time>=0 and elapsed-_echo_time<.24:
		var echo := View.sample_live("charge",art_direction,Data.contact_time(Data.definition("charge"))) if live_art else View.sample("charge",art_direction,Data.contact_time(Data.definition("charge")))
		if not echo.is_empty():
			var offset: Vector2 = echo["offset"]+Data.ground(aim)*(-20+(elapsed-_echo_time)*90)
			if echo_path.size()>=2:offset=echo["offset"]+echo_path[0].lerp(echo_path[1],clampf((elapsed-_echo_time)/.24,0,1))-global_position
			draw_texture_rect_region(echo["texture"],Rect2(offset,echo.get("size",Vector2(160,160))),echo["region"],Color(.65,.72,.75,.34))
	draw_set_transform(Vector2.ZERO,0,Vector2(1,.36))
	draw_circle(Vector2.ZERO,10,Color(0,0,0,.28))
	draw_set_transform(Vector2.ZERO)
	if active:
		if live_art:View.draw_live(self,active_id,art_direction,elapsed)
		else:View.draw_actor(self,active_id,art_direction,elapsed)
	else:
		var frame:=locomotion_sample()
		if not frame.is_empty():draw_texture_rect_region(frame["texture"],Rect2(frame["offset"],frame.get("size",Vector2(160,160))),frame["region"])
	if active and str(_attack["impact"]["kind"])=="chains":
		var t := elapsed-Data.contact_time(_attack)
		if t>=0 and t<.6:
			var reach := minf(1,t/.25)*float(_attack["shape"]["reach"])
			for i in range(floori(reach/7)):
				var point := Data.ground(aim.normalized()*float(i)*7)+Vector2(0,-4+sin(i*.8)*3)
				var link := PackedVector2Array([point+Vector2(-2,0),point+Vector2(0,-1),point+Vector2(3,0),point+Vector2(0,1),point+Vector2(-2,0)])
				draw_polyline(link,Color("a68b60",.7*(1-t/.6)),1,false)
