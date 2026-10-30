extends Control
## Original RPG-style arrival scene. The actual game world stays paused.
signal finished

const DURATION := 21.0
const HOLD_TO_SKIP := 3.0
const SKIP_INSTRUCTION := "Mantenha Espaço pressionado por 3 s para pular"
const ATLAS_PATH := "res://assets/cinematics/rpg_v11/intro_atlas.png"
const FISHERMAN_PATH := "res://assets/cinematics/rpg_v12/fisherman.png"
const BOAT_PATH := "res://assets/cinematics/rpg_v12/arrival_boat.png"
const BOAT_START := Vector2(95,287)
const BOAT_MOORED := Vector2(125,280)
const BOAT_STANDING := Vector2(5,-25)
const BOAT_BOARDING := Vector2(25,-24)
const QUAY_EDGE := Vector2(175,243)
const LANDING := Vector2(209,214)
const Conversation = preload("res://resources/dialogue/opening_fisherman.gd")
const PortraitDialogue = preload("res://scripts/ui/portrait_dialogue.gd")
const DialogueBabble = preload("res://scripts/audio/dialogue_babble.gd")
static var DIALOGUES: Array = Conversation.legacy_lines()
static var DIALOGUE_COUNT: int = DIALOGUES.size()
static var DIALOGUE_CUES: Array[float] = _make_dialogue_cues()

static func _make_dialogue_cues() -> Array[float]:
	var result: Array[float] = []
	for index in range(DIALOGUE_COUNT):
		# The fisherman first receives the rope; Senu only disembarks after it.
		result.append(1.8 if index==0 else 4.0+(index-1)*.3)
	return result
var elapsed := 0.0
var active := false
var hold_elapsed := 0.0
var dialogue_active := false
var dialogue_index := -1
var dialogue_visible_characters := 0
var _dialogue_clock := 0.0
var _dialogue_ack: Array[bool] = []
var _animation_clock := 0.0
var _space_down := false
var _has_focus := true
var _require_release := false
var _finished := false
var _font: Font
var _title_font: Font
var _container: SubViewportContainer
var _view: SubViewport
var _stage: ArrivalStage
var _hero: SenuPlayer
var _camera: Camera2D
var _dialogue_view: VeilPortraitDialogue
var _babble: VeilDialogueBabble
var _factor := 1.0
var _offset := Vector2.ZERO
var _last_size := Vector2.ZERO

class ArrivalWater extends Node2D:
	var clock := 0.0
	var effect: ShaderMaterial
	func _ready() -> void:
		effect = ShaderMaterial.new()
		effect.shader = preload("res://assets/shaders/opening_rpg_water_v11.gdshader")
		material = effect
	func _draw() -> void:
		draw_rect(Rect2(-300,-300,1400,1000),Color.WHITE)
	func animate(value: float) -> void:
		clock = value
		if effect != null: effect.set_shader_parameter("clock",clock)

class ArrivalStage extends Node2D:
	var atlas: Texture2D
	var fisherman: Texture2D
	var boat: Texture2D
	var rim: BoatRim
	var clock := 0.0
	var boat_position := BOAT_START
	var npc_position := Vector2(274,181)
	var npc_moving := false
	var npc_facing := 1.0
	var npc_distance := 0.0
	var npc_speaking := false
	var npc_farewell := false
	var npc_working := false
	var story_time := 0.0
	var water: ArrivalWater

	func _ready() -> void:
		load_art()
		water = ArrivalWater.new()
		water.z_index = -10
		add_child(water)
		rim = BoatRim.new()
		rim.z_index = 2
		rim.atlas = boat
		add_child(rim)
	func load_art() -> void:
		if atlas == null and ResourceLoader.exists(ATLAS_PATH): atlas = load(ATLAS_PATH) as Texture2D
		if fisherman == null and ResourceLoader.exists(FISHERMAN_PATH): fisherman = load(FISHERMAN_PATH) as Texture2D
		if boat == null and ResourceLoader.exists(BOAT_PATH): boat = load(BOAT_PATH) as Texture2D
	func boat_part(frame: int, at: Vector2) -> void:
		if boat != null: draw_texture_rect_region(boat,Rect2(at.round()-Vector2(64,112),Vector2(128,128)),Rect2(frame*128,0,128,128))
	func tile(frame: int, at: Vector2) -> void:
		if atlas != null:
			var origin := Vector2(frame%4,frame/4)*128+Vector2(32,96)
			draw_texture_rect_region(atlas,Rect2(at+Vector2(-32,-16),Vector2(64,32)),Rect2(origin,Vector2(64,32)))
		else:
			draw_colored_polygon(PackedVector2Array([at+Vector2(-32,0),at+Vector2(0,-16),at+Vector2(32,0),at+Vector2(0,16)]),Color("655b44") if frame==1 else Color("657466"))
	func prop(frame: int, at: Vector2, flip: float = 1.0) -> void:
		if atlas == null: return
		draw_set_transform(at.round(),0,Vector2(flip,1))
		draw_texture_rect_region(atlas,Rect2(-64,-112,128,128),Rect2(frame%4*128,frame/4*128,128,128))
		draw_set_transform(Vector2.ZERO)
	func rope_coil(at: Vector2, variation: int) -> void:
		draw_set_transform(at,0,Vector2(1,.4))
		for radius in [4,6,8]:
			draw_arc(Vector2.ZERO,radius,0,TAU,16,Color("b99660"),1)
		draw_set_transform(Vector2.ZERO)
		draw_line(at+Vector2(6,0),at+Vector2(12+variation*3,3),Color("8b704a"),1)
	func fishing_net(at: Vector2) -> void:
		# A distinct work surface gives the fisherman a reason to stay at this quay.
		draw_colored_polygon(PackedVector2Array([at+Vector2(-14,0),at+Vector2(1,-7),at+Vector2(16,1),at+Vector2(0,9)]),Color("344d48"))
		for strand in range(6):
			var offset := Vector2(strand*5-13,strand*2.5-6)
			draw_line(at+offset,at+offset+Vector2(-14,7),Color("93896b"),1)
			var cross := Vector2(strand*5-13,7-strand*2.5)
			draw_line(at+cross,at+cross+Vector2(14,7),Color("7a7b61"),1)
		rope_coil(at+Vector2(17,6),0)
	func distant_shore() -> void:
		# New low-contrast silhouettes establish a town beyond this small quay.
		draw_colored_polygon(PackedVector2Array([Vector2(-50,59),Vector2(0,43),Vector2(186,38),Vector2(227,47),Vector2(194,58)]),Color("294247"))
		for part in [[Vector2(8,43),26,25],[Vector2(39,42),21,36],[Vector2(65,41),31,29],[Vector2(105,40),33,22],[Vector2(147,40),24,31]]:
			var foot: Vector2 = part[0]
			var width: float = part[1]
			var height: float = part[2]
			draw_rect(Rect2(foot-Vector2(0,height),Vector2(width,height)),Color("344e4f"))
			draw_rect(Rect2(foot-Vector2(0,height),Vector2(width,3)),Color("50605a"))
			for window in range(4,int(width)-4,9): draw_rect(Rect2(foot+Vector2(window,-height+8),Vector2(3,5)),Color("203b43"))
	func _draw() -> void:
		distant_shore()
		var origin := Vector2(330,145)
		var floor_cells: Array[Vector2i] = []
		for x in range(-4,9):
			for y in range(-1,6): floor_cells.append(Vector2i(x,y))
		floor_cells.sort_custom(func(a,b): return a.x+a.y < b.x+b.y)
		for cell in floor_cells:
			var at := origin+Vector2((cell.x-cell.y)*32,(cell.x+cell.y)*16)
			# Front faces and piles physically support the surface above the river.
			var wooden := cell.x<3
			var depth := 9.0 if wooden else 16.0
			for side in [Vector2i.RIGHT,Vector2i.DOWN]:
				if (side.x==1 and cell.x!=8) or (side.y==1 and cell.y!=5): continue
				var a := at+(Vector2(32,0) if side.x==1 else Vector2(0,16))
				var b := at+(Vector2(0,16) if side.x==1 else Vector2(-32,0))
				var face := Color("55452e") if wooden else Color("405951")
				if side.x==1: face = face.darkened(.16)
				draw_colored_polygon(PackedVector2Array([a,b,b+Vector2(0,depth),a+Vector2(0,depth)]),face)
				draw_line(a+Vector2(0,depth),b+Vector2(0,depth),Color("263e3e"),1)
				if not wooden: draw_line(a+Vector2(0,8),b+Vector2(0,8),Color("304b45"),1)
				if wooden and cell.x%2==0:
					var piling := (a+b)*.5+Vector2(0,depth)
					draw_line(piling,piling+Vector2(0,16),Color("3d3c2d"),4)
					draw_line(piling+Vector2(1,0),piling+Vector2(1,14),Color("786044"),1)
			tile(1 if cell.x<3 else 0,at)
		# The far-side rope rail stays clear of the boat and walking route.
		var previous_post := Vector2.INF
		for x in range(-4,9,2):
			var post := origin+Vector2((x+1)*32,(x-1)*16)+Vector2(16,-8)
			draw_rect(Rect2(post+Vector2(-2,-15),Vector2(4,17)),Color("6d5639"))
			draw_rect(Rect2(post+Vector2(-3,-16),Vector2(6,3)),Color("b59862"))
			if previous_post!=Vector2.INF:
				var a := previous_post+Vector2(0,-12)
				var b := post+Vector2(0,-12)
				draw_polyline(PackedVector2Array([a,(a+b)*.5+Vector2(0,2),b]),Color("b4a176"),1)
			previous_post = post
		rope_coil(Vector2(312,175),0)
		rope_coil(Vector2(390,190),1)
		fishing_net(Vector2(271,200))
		# Dedicated mooring and gangplank; no objects from the gameplay map.
		var bank := QUAY_EDGE
		var deck := boat_position+BOAT_BOARDING
		if story_time>1.6:
			var end := bank.lerp(deck,clampf((story_time-1.6)/.25,0,1))
			var edge := Vector2(2,5)
			draw_colored_polygon(PackedVector2Array([bank-edge,bank+edge,end+edge,end-edge]),Color("a88552"))
			for plank in range(1,8):
				var at := bank.lerp(end,plank/8.0)
				draw_line(at-edge,at+edge,Color("5a452f"),1)
		for wake in range(3):
			var point := boat_position+Vector2(-46-wake*7,2+wake*2)
			draw_line(point,point+Vector2(17-wake*3,-1),Color(.43,.65,.62,.32-wake*.07),1)
		boat_part(2+int(clock*3)%2,boat_position)
		boat_part(0,boat_position)
		var mooring_post := QUAY_EDGE+Vector2(8,-2)
		draw_rect(Rect2(mooring_post+Vector2(-2,-12),Vector2(5,13)),Color("614c34"))
		draw_rect(Rect2(mooring_post+Vector2(-3,-13),Vector2(7,3)),Color("b29866"))
		if story_time>1.7:
			var held_rope := npc_position+Vector2(-5,-17) if story_time<1.81 else mooring_post+Vector2(0,-9)
			draw_line(boat_position+Vector2(39,-15),held_rope,Color("b89a65"),1)
			draw_line(held_rope,mooring_post+Vector2(1,-6),Color("9f8557"),1)
		prop(7,Vector2(470,177))
		for lamp: Vector2 in [Vector2(333,200),Vector2(485,215),Vector2(118,176)]:
			prop(6,lamp)
			var flame := lamp+Vector2(0,-32)
			draw_rect(Rect2(flame+Vector2(-1,-3+roundf(sin(clock*9)*1)),Vector2(3,5)),Color("efbd68"))
		var frame: int = [1,2,3,4][int(npc_distance/24*4)%4] if npc_moving else 6
		if not npc_moving:
			if npc_speaking: frame = 5 if int(clock*2)%4<2 else 0
			elif npc_farewell: frame = 7
			elif npc_working: frame = 5 if int(clock*1.5)%2==0 else 6
		draw_rect(Rect2(npc_position+Vector2(-9,-2),Vector2(18,4)),Color(.02,.04,.04,.35))
		if fisherman != null:
			draw_set_transform(npc_position.round(),0,Vector2(npc_facing,1))
			draw_texture_rect_region(fisherman,Rect2(-64,-112,128,128),Rect2(frame%4*128,frame/4*128,128,128))
			draw_set_transform(Vector2.ZERO)

class BoatRim extends Node2D:
	var atlas: Texture2D
	func _draw() -> void:
		if atlas != null: draw_texture_rect_region(atlas,Rect2(-64,-112,128,128),Rect2(128,0,128,128))

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = preload("res://scripts/ui/ui_typography.gd").body()
	_title_font = preload("res://scripts/ui/ui_typography.gd").title()
	theme = preload("res://scripts/ui/ui_typography.gd").make_theme()
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.stretch_shrink = 2
	_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.show_behind_parent = true
	add_child(_container)
	_view = SubViewport.new()
	_view.size = Vector2i(640,360)
	_view.disable_3d = true
	_view.world_2d = World2D.new()
	_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_view.snap_2d_transforms_to_pixel = true
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_container.add_child(_view)
	_stage = ArrivalStage.new()
	_view.add_child(_stage)
	_hero = SenuPlayer.new()
	_hero.name = "CinematicSenu"
	_hero.controls_enabled = false
	_stage.add_child(_hero)
	_hero.remove_from_group("player")
	_hero.set_physics_process(false)
	_hero.invulnerability_timer = 0
	_hero.collision_layer = 0
	_hero.collision_mask = 0
	_camera = Camera2D.new()
	_camera.position = Vector2(320,180)
	_stage.add_child(_camera)
	_dialogue_view = PortraitDialogue.new()
	_dialogue_view.name = "PortraitDialogue"
	add_child(_dialogue_view)
	# One clock owns both the story and the facial/typewriter animation.
	_dialogue_view.set_process(false)
	_dialogue_view.advance_requested.connect(advance_dialogue)
	# Babble follows the speaker's mouth. As a child it processes after this node ticks the view.
	_babble = DialogueBabble.new()
	_babble.name = "DialogueBabble"
	_babble.dialogue = _dialogue_view
	add_child(_babble)
	_geometry()
	visible = false

func resources_ready() -> bool:
	return is_instance_valid(_stage) and _stage.atlas != null and _stage.fisherman != null and _stage.boat != null and is_instance_valid(_dialogue_view) and _dialogue_view.resources_ready()
func begin() -> void:
	elapsed = 0
	hold_elapsed = 0
	_animation_clock = 0
	_space_down = false
	_require_release = false
	_finished = false
	dialogue_active = false
	dialogue_index = -1
	dialogue_visible_characters = 0
	_dialogue_clock = 0
	_dialogue_view.clear()
	_dialogue_ack.resize(DIALOGUE_COUNT)
	_dialogue_ack.fill(false)
	active = true
	visible = true
	_stage.load_art()
	_update_scene()
	queue_redraw()
func seek(seconds: float) -> void:
	elapsed = clampf(seconds,0,DURATION)
	_animation_clock = elapsed
	dialogue_active = false
	_dialogue_clock = 0
	_dialogue_view.clear()
	dialogue_visible_characters = 0
	_dialogue_ack.resize(DIALOGUE_COUNT)
	for index in range(DIALOGUE_COUNT): _dialogue_ack[index] = elapsed>DIALOGUE_CUES[index]
	_update_scene()
	queue_redraw()
func _geometry() -> void:
	_last_size = size
	var dimensions := size if size.x>0 else get_viewport_rect().size
	_factor = minf(dimensions.x/1280.0,dimensions.y/720.0)
	_offset = (dimensions-Vector2(1280,720)*_factor)*.5
	if is_instance_valid(_container):
		_container.position = _offset
		_container.size = Vector2(1280,720)*_factor
func _process(delta: float) -> void:
	if not active: return
	if size!=_last_size: _geometry()
	_animation_clock += delta
	_dialogue_view.tick(delta)
	if dialogue_active:
		_dialogue_clock += delta
		dialogue_visible_characters = _dialogue_view.visible_characters
	else:
		var next := minf(DURATION,elapsed+delta)
		for index in range(DIALOGUE_COUNT):
			if not _dialogue_ack[index] and elapsed<=DIALOGUE_CUES[index] and next>=DIALOGUE_CUES[index]:
				next = DIALOGUE_CUES[index]
				_begin_dialogue(index)
				break
		elapsed = next
	if _require_release and not _space_down and not Input.is_physical_key_pressed(KEY_SPACE): _require_release = false
	if _has_focus and not _require_release and (_space_down or Input.is_physical_key_pressed(KEY_SPACE)):
		hold_elapsed += delta
	else: hold_elapsed = 0
	_update_scene()
	queue_redraw()
	if hold_elapsed>=HOLD_TO_SKIP or elapsed>=DURATION: _finish()
func _dialogue_text() -> String:
	return str(DIALOGUES[dialogue_index][1]) if dialogue_index>=0 else ""
func _begin_dialogue(index: int) -> void:
	dialogue_index = index
	dialogue_active = true
	_dialogue_clock = 0
	dialogue_visible_characters = 0
	var line: Dictionary = Conversation.LINES[index]
	_dialogue_view.begin_line(str(line["speaker"]),str(line["text"]),str(line["expression"]),str(line["listener_expression"]),float(Conversation.DELIVERY_SECONDS[index]))
func advance_dialogue() -> void:
	if not active or not dialogue_active: return
	var length := _dialogue_text().length()
	if not _dialogue_view.is_revealed():
		_dialogue_view.reveal_all()
		dialogue_visible_characters = _dialogue_view.visible_characters
	else:
		_dialogue_view.stop_talking()
		_dialogue_ack[dialogue_index] = true
		dialogue_active = false
		elapsed = DIALOGUE_CUES[dialogue_index]+.001
		if dialogue_index==DIALOGUE_COUNT-1:
			_dialogue_view.clear()
			elapsed = 12.0
	_update_scene()
	queue_redraw()
func _input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode!=0 else event.keycode
		if code==KEY_SPACE and not event.echo:
			_space_down = event.pressed
			if not _space_down:
				hold_elapsed = 0
				_require_release = false
		elif code in [KEY_ENTER,KEY_KP_ENTER,KEY_E] and event.pressed and not event.echo:
			advance_dialogue()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not dialogue_active:
		get_viewport().set_input_as_handled()
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_has_focus = false
		_space_down = false
		_require_release = true
		hold_elapsed = 0
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN,NOTIFICATION_APPLICATION_FOCUS_IN]: _has_focus = true
func _finish() -> void:
	if _finished: return
	_finished = true
	active = false
	visible = false
	_space_down = false
	hold_elapsed = 0
	_dialogue_view.clear()
	finished.emit()
func _update_scene() -> void:
	if not is_instance_valid(_stage): return
	_stage.story_time = elapsed
	_stage.clock = _animation_clock
	if _stage.water!=null: _stage.water.animate(_animation_clock)
	var arrival := smoothstep(0,1.8,elapsed)
	_stage.boat_position = BOAT_START.lerp(BOAT_MOORED,arrival)
	if elapsed<1.8: _stage.boat_position.y += roundf(sin(_animation_clock*3)*1)
	_stage.rim.position = _stage.boat_position.round()
	_stage.rim.atlas = _stage.boat
	_stage.rim.queue_redraw()
	var at := _stage.boat_position+BOAT_STANDING
	var velocity := Vector2.ZERO
	var distance := 0.0
	var landing := LANDING
	_hero.facing = Vector2(1,-.5)
	if elapsed>=1.8 and elapsed<3.8:
		var walk := clampf((elapsed-1.8)/2,0,1)
		# Feet cross the hull opening and the physical quay edge in order.
		var route: Array[Vector2] = [BOAT_MOORED+BOAT_STANDING,BOAT_MOORED+BOAT_BOARDING,QUAY_EDGE,landing]
		var lengths: Array[float] = [route[0].distance_to(route[1]),route[1].distance_to(route[2]),route[2].distance_to(route[3])]
		var total: float = lengths[0]+lengths[1]+lengths[2]
		distance = total*walk
		var remaining := distance
		for segment in range(3):
			if remaining<=lengths[segment] or segment==2:
				at = route[segment].lerp(route[segment+1],clampf(remaining/lengths[segment],0,1))
				velocity = (route[segment+1]-route[segment]).normalized()*total/2
				break
			remaining -= lengths[segment]
	elif elapsed>=3.8:
		at = landing
	if dialogue_active and dialogue_index==0: velocity = Vector2.ZERO
	if elapsed>=12:
		var destination := Vector2(447,226)
		var walk := clampf((elapsed-12)/6.5,0,1)
		at = landing.lerp(destination,walk)
		if walk<1: velocity = (destination-landing)/6.5
		distance = (destination-landing).length()*walk
		_hero.facing = Vector2.RIGHT if walk<1 else Vector2(1,-.7)
	_hero.position = at.round()
	_hero.velocity = velocity
	# The staged walk bypasses physics, so provide its authored ground travel
	# to the same visual observer used by the playable character.
	_hero._visual_speed = Vector2(velocity.x, velocity.y / SenuPlayer.ISO_Y).length()
	_hero._visual_distance = distance
	_hero._time = _animation_clock
	_hero._supplied_view.sample(_hero)
	_hero._supplied_view.gait_phase = fposmod(distance/28,1)
	_hero.queue_redraw()
	var npc_start := Vector2(254,191)
	var npc_mooring := Vector2(184,238)
	var npc_approach := clampf((elapsed-.5)/1.3,0,1)
	var npc_back := clampf((elapsed-1.9)/2,0,1)
	_stage.npc_position = npc_start.lerp(npc_mooring,npc_approach)
	_stage.npc_moving = npc_approach>0 and npc_approach<1
	_stage.npc_distance = npc_start.distance_to(npc_mooring)*npc_approach
	if elapsed>=1.9:
		_stage.npc_position = npc_mooring.lerp(npc_start,npc_back)
		_stage.npc_moving = npc_back<1
		_stage.npc_distance += npc_mooring.distance_to(npc_start)*npc_back
	_stage.npc_speaking = dialogue_active and str(DIALOGUES[dialogue_index][0])=="PESCADOR" and _dialogue_view.is_speaking
	_stage.npc_farewell = elapsed>=12 and elapsed<13
	_stage.npc_working = elapsed>=16
	_stage.npc_facing = 1 if _stage.npc_moving and npc_back>0 else -1
	if elapsed>=13:
		var returning := clampf((elapsed-13)/3,0,1)
		_stage.npc_position = npc_start.lerp(Vector2(263,205),returning)
		_stage.npc_moving = returning<1
		_stage.npc_distance = npc_start.distance_to(Vector2(263,205))*returning
		_stage.npc_facing = 1
	# Keep both actors visible above the dialogue panel and between the busts.
	var dialogue_camera := Vector2(320,180).lerp(Vector2(270,212),smoothstep(.6,1.8,elapsed))
	_camera.position = dialogue_camera.lerp(Vector2(356,198),smoothstep(12,18.5,elapsed)).round()
	_stage.queue_redraw()
func _text(value: String, at: Vector2, point_size: int, color: Color, serif: bool=false) -> void:
	draw_set_transform(Vector2.ZERO)
	draw_string(_title_font if serif else _font,(_offset+at*_factor).round(),value,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(point_size*_factor),color)
	draw_set_transform(_offset,0,Vector2.ONE*_factor)
func _draw() -> void:
	if not active or _font==null: return
	draw_set_transform(_offset,0,Vector2.ONE*_factor)
	draw_rect(Rect2(19,16,390,36),Color(.025,.06,.075,.85))
	_text("Porto dos Esquecidos / Alexandria",Vector2(31,41),17,Color("e4d4ab"))
	draw_rect(Rect2(736,16,525,36),Color(.025,.06,.075,.85))
	_text(SKIP_INSTRUCTION,Vector2(750,40),17,Color("d8dfd0"))
	if hold_elapsed>0:
		draw_rect(Rect2(750,49,489,4),Color("324641"))
		draw_rect(Rect2(750,49,489*clampf(hold_elapsed/HOLD_TO_SKIP,0,1),4),Color("e6c889"))
	if elapsed>=18.5:
		var title := "Uma pista entre os armazéns"
		var width := _font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x
		draw_rect(Rect2(640-width*.5-20,590,width+40,48),Color(.025,.06,.075,.88))
		_text(title,Vector2(640-width*.5,622),22,Color("e8d7ae"))
	var fade := maxf(1-clampf(elapsed/.55,0,1),clampf((elapsed-DURATION+.8)/.8,0,1))
	if fade>0: draw_rect(Rect2(0,0,1280,720),Color(0,0,0,fade))
