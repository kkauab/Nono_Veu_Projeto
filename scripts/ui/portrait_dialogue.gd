class_name VeilPortraitDialogue
extends Control
## Reusable two-portrait dialogue presentation. Story/input ownership stays outside.
signal line_revealed
signal advance_requested

const DESIGN_SIZE := Vector2(1280,720)
const PORTRAIT_CELL := Vector2(160,192)
const ATLAS_COLUMNS := 5
const PORTRAIT_PATHS := {
	"SENU": "res://assets/ui/dialogue_v15/senu.png",
	"PESCADOR": "res://assets/ui/dialogue_v15/fisherman.png"
}
const EXPRESSIONS := ["neutral","concerned","sad","resolute"]
# A complete-pose delivery loop. These timings never inspect the written text.
const SPEECH_POSES := [0,1,2,1,0,1,2,1,0]
const SPEECH_DURATIONS := [.10,.12,.14,.11,.13,.16,.12,.14]
const BOX := Rect2(40,506,1200,190)
const TEXT_AREA := Rect2(84,557,1112,100)
const LEFT_PORTRAIT := Rect2(54,234,240,288)
const RIGHT_PORTRAIT := Rect2(986,234,240,288)
const INK := Color("08191f")
const GOLD := Color("c6a264")
const IVORY := Color("f2e9d3")
const MUTED := Color("a8bbb1")

var visible_characters := 0
var full_text := ""
var is_typing := false
var is_speaking := false
var delivery_remaining := 0.0
var active_speaker := ""
var _expressions := [0,0]
var _mouth := [0,0]
var _eye := [0,0]
var _blink_due := [3.1,4.3]
var _blink_clock := [-1.0,-1.0]
var _blink_count := [0,0]
var _clock := 0.0
var _gesture_energy := [0.0,0.0]
var _letter_due := .025
var _speech_phase := 0
var _speech_phrase := 0
var _speech_due := 0.0
var _reveal_emitted := false
var _textures: Dictionary = {}
var _body: RichTextLabel
var _font: Font
var _name_font: Font
var _factor := 1.0
var _offset := Vector2.ZERO
var _last_size := Vector2.ZERO
var _body_font_size := 26

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_font = preload("res://scripts/ui/ui_typography.gd").body()
	_name_font = preload("res://scripts/ui/ui_typography.gd").title()
	theme = preload("res://scripts/ui/ui_typography.gd").make_theme()
	_body = RichTextLabel.new()
	_body.name = "DialogueText"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.focus_mode = Control.FOCUS_NONE
	_body.bbcode_enabled = false
	_body.scroll_active = false
	_body.fit_content = false
	_body.selection_enabled = false
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_body.add_theme_font_override("normal_font",_font)
	_body.add_theme_color_override("default_color",IVORY)
	_body.add_theme_constant_override("line_separation",5)
	add_child(_body)
	_geometry()
	_load_portraits()
	visible = false

func _load_portraits() -> void:
	for speaker in PORTRAIT_PATHS:
		if not _textures.has(speaker) and ResourceLoader.exists(PORTRAIT_PATHS[speaker]):
			_textures[speaker] = load(PORTRAIT_PATHS[speaker]) as Texture2D

func resources_ready() -> bool:
	_load_portraits()
	return _textures.get("SENU") != null and _textures.get("PESCADOR") != null

@warning_ignore("unused_parameter")
func begin_line(speaker: String, text: String, expression: String = "neutral", listener_expression: String = "neutral", delivery_seconds: float = 4.2) -> void:
	active_speaker = speaker.to_upper()
	full_text = text
	visible_characters = 0
	is_typing = not text.is_empty()
	_reveal_emitted = false
	_letter_due = .025
	_mouth = [0,0]
	_speech_phase = 0
	_speech_phrase = 0
	delivery_remaining = maxf(0,delivery_seconds)
	is_speaking = delivery_remaining > 0
	_speech_due = _speech_duration(0)
	var index := _speaker_index(active_speaker)
	_expressions[index] = maxi(0,EXPRESSIONS.find(expression))
	# The listener keeps the expression from their own last turn, at complete rest.
	# listener_expression remains accepted for existing callers but no longer drives them.
	var listener := 1-index
	_eye[listener] = 0
	_blink_clock[listener] = -1.0
	if _blink_due[listener] <= 0: _blink_due[listener] = 3.4+listener*.65
	if is_instance_valid(_body):
		_body.text = text
		_body.visible_characters = 0
		_body_font_size = 26
		_geometry()
		call_deferred("_fit_text")
	_load_portraits()
	visible = true
	queue_redraw()
	if not is_typing: _finish_reveal()

func is_revealed() -> bool:
	return not is_typing and visible_characters >= full_text.length()

func reveal_all() -> void:
	visible_characters = full_text.length()
	if is_instance_valid(_body): _body.visible_characters = visible_characters
	is_typing = false
	_finish_reveal()
	queue_redraw()

func stop_talking() -> void:
	is_speaking = false
	delivery_remaining = 0
	_speech_phase = 0
	_speech_due = 0
	_mouth = [0,0]
	queue_redraw()

func clear() -> void:
	stop_talking()
	visible = false
	active_speaker = ""
	full_text = ""
	visible_characters = 0
	is_typing = false
	if is_instance_valid(_body): _body.text = ""

func _process(delta: float) -> void:
	tick(delta)

func tick(delta: float) -> void:
	if not visible: return
	if size != _last_size: _geometry()
	_clock += delta
	_animate_blinks(delta)
	_animate_speech(delta)
	for index in range(2):
		var target := 1.0 if is_speaking and index == _speaker_index(active_speaker) else 0.0
		_gesture_energy[index] = lerpf(_gesture_energy[index],target,1.0-exp(-delta*5.0))
	if is_typing:
		_letter_due -= delta
		var revealed_this_tick := 0
		while _letter_due <= 0 and visible_characters < full_text.length():
			var character := full_text.substr(visible_characters,1)
			visible_characters += 1
			revealed_this_tick += 1
			_letter_due += _character_delay(character)
			# The text catches up independently after a delayed frame.
			if revealed_this_tick > 24: break
		if is_instance_valid(_body): _body.visible_characters = visible_characters
		if visible_characters >= full_text.length():
			is_typing = false
			_finish_reveal()
	queue_redraw()

func _finish_reveal() -> void:
	if not _reveal_emitted:
		_reveal_emitted = true
		line_revealed.emit()

func _character_delay(character: String) -> float:
	if character in [".","!","?","…"]: return .24
	if character in [",",";",":","—"]: return .13
	if character in [" ","\n","\t"]: return .016
	return .027

func _speech_duration(phase: int) -> float:
	if phase == SPEECH_POSES.size()-1:
		return .29+float(_speech_phrase%4)*.06 # A breath every one to two seconds.
	var variation := float((phase*3+_speech_phrase*2+_speaker_index(active_speaker))%5)*.012
	return float(SPEECH_DURATIONS[phase])+variation

func _animate_speech(delta: float) -> void:
	if not is_speaking: return
	delivery_remaining = maxf(0,delivery_remaining-delta)
	if delivery_remaining <= .000001:
		stop_talking()
		return
	_speech_due -= delta
	while _speech_due <= 0:
		_speech_phase = (_speech_phase+1)%SPEECH_POSES.size()
		if _speech_phase == 0: _speech_phrase += 1
		_speech_due += _speech_duration(_speech_phase)
	var index := _speaker_index(active_speaker)
	_mouth[index] = SPEECH_POSES[_speech_phase]
	_mouth[1-index] = 0

func _animate_blinks(delta: float) -> void:
	if active_speaker.is_empty(): return
	var index := _speaker_index(active_speaker)
	if _blink_clock[index] < 0:
		_blink_due[index] -= delta
		if _blink_due[index] <= 0: _blink_clock[index] = 0.0
	else:
		_blink_clock[index] += delta
		if _blink_clock[index] >= .18:
			_blink_clock[index] = -1.0
			_blink_count[index] += 1
			_blink_due[index] = 3.4+index*.65+float((_blink_count[index]*7+index*3)%5)*.29
	var phase: float = _blink_clock[index]
	_eye[index] = 0 if phase < 0 else (2 if phase >= .045 and phase < .125 else 1)

func _speaker_index(speaker: String) -> int:
	return 0 if speaker.to_upper() == "SENU" else 1

func portrait_state(speaker: String) -> Dictionary:
	var index := _speaker_index(speaker)
	var active: bool = active_speaker == speaker.to_upper()
	# Blink frames are complete drawings, not eyes pasted over a talking mouth.
	var eye: int = _eye[index] if active else 0
	var mouth: int = _mouth[index] if active else 0
	var pose: int = 4 if eye == 2 else (3 if eye == 1 else mouth)
	var displayed_mouth: int = mouth if eye == 0 else 0
	return {"mouth":displayed_mouth,"speech_mouth":mouth,"eye":eye,"expression":EXPRESSIONS[_expressions[index]],
		"expression_index":_expressions[index],"active":active_speaker == speaker.to_upper(),
		"pose":pose,"is_speaking":is_speaking and active,"delivery_remaining":delivery_remaining if active else 0.0,
		"frame":_expressions[index]*5+pose}

func _physical(rect: Rect2) -> Rect2:
	return Rect2(_offset+rect.position*_factor,rect.size*_factor)

func layout_snapshot() -> Dictionary:
	return {"box":_physical(BOX),"left_portrait":_physical(LEFT_PORTRAIT),
		"right_portrait":_physical(RIGHT_PORTRAIT),"text":_physical(TEXT_AREA),
		"name":_physical(Rect2(84,518,600,32)),"scale":_factor,
		"coordinate_space":"control","viewport_scale":get_viewport().get_stretch_transform().get_scale(),
		"content_height":_body.get_content_height() if is_instance_valid(_body) else 0,
		"text_font_size":roundi(_body_font_size*_factor)}

func _geometry() -> void:
	_last_size = size
	var available := size if size.x > 0 else get_viewport_rect().size
	_factor = minf(available.x/DESIGN_SIZE.x,available.y/DESIGN_SIZE.y)
	_offset = (available-DESIGN_SIZE*_factor)*.5
	if is_instance_valid(_body):
		var area := _physical(TEXT_AREA)
		_body.position = area.position.round()
		_body.size = area.size.round()
		_body.add_theme_font_size_override("normal_font_size",maxi(14,roundi(_body_font_size*_factor)))
		_body.add_theme_constant_override("line_separation",maxi(2,roundi(5*_factor)))
		call_deferred("_fit_text")
	queue_redraw()

func _fit_text() -> void:
	if not is_instance_valid(_body) or full_text.is_empty(): return
	if _body.get_content_height() > _body.size.y and _body_font_size > 22:
		_body_font_size -= 2
		_body.add_theme_font_size_override("normal_font_size",maxi(14,roundi(_body_font_size*_factor)))
		call_deferred("_fit_text")

func _gui_input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var at: Vector2 = (event.position-_offset)/_factor
		if BOX.has_point(at) or LEFT_PORTRAIT.has_point(at) or RIGHT_PORTRAIT.has_point(at):
			advance_requested.emit()
			accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		var at: Vector2 = (event.position-_offset)/_factor
		if BOX.has_point(at):
			advance_requested.emit()
			accept_event()

func _beveled(rect: Rect2, fill: Color, outline: Color, cut: float = 9) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var shape := PackedVector2Array([Vector2(x+cut,y),Vector2(x+w-cut,y),Vector2(x+w,y+cut),
		Vector2(x+w,y+h-cut),Vector2(x+w-cut,y+h),Vector2(x+cut,y+h),Vector2(x,y+h-cut),Vector2(x,y+cut)])
	draw_colored_polygon(shape,fill)
	shape.append(shape[0])
	draw_polyline(shape,outline,1)

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([at+Vector2(0,-radius),at+Vector2(radius,0),
		at+Vector2(0,radius),at+Vector2(-radius,0),at+Vector2(0,-radius)]),color,1)

func _draw_portrait(speaker: String, rect: Rect2) -> void:
	var state := portrait_state(speaker)
	var active: bool = state["active"]
	# Only the transparent cutout is drawn here; the world remains visible behind it.
	if _textures.get(speaker) != null:
		var tint := Color.WHITE if active else Color(.82,.86,.84,1)
		_draw_living_portrait(speaker,rect,state,tint)

## Stable shoulders, an independently blinking face and a slowly settling head.
## Destination rows stay filled; displacement changes sampling, never opens seams.
func portrait_motion(speaker: String) -> Dictionary:
	var index := _speaker_index(speaker)
	var energy: float = _gesture_energy[index]
	var phase := _clock * 1.55 + index * 1.9
	var breath := (sin(phase) + 1.0) * .45
	var gesture := sin(_clock * 2.6 + index * 1.4) * energy
	return {"breath":breath,"head_x":gesture * .85 * (1 if index == 0 else -1),
		"head_y":sin(_clock * 3.4 + index * 1.1 + .4) * energy * .65,"energy":energy}

func _draw_living_portrait(speaker: String, rect: Rect2, state: Dictionary, tint: Color) -> void:
	var motion := portrait_motion(speaker)
	var expression := int(state["expression_index"])
	var mouth_frame := expression * 5 + int(state["speech_mouth"])
	var eye_frame := expression * 5 + (4 if int(state["eye"]) == 2 else 3)
	var eyes := Rect2(91,55,47,22) if speaker == "SENU" else Rect2(51,60,41,22)
	var pixel_scale := rect.size / PORTRAIT_CELL
	for row in range(roundi(rect.size.y)):
		var y := (float(row)+.5) / pixel_scale.y
		var head_weight := 1.0-smoothstep(98.0,145.0,y)
		var chest_weight := 1.0-smoothstep(140.0,188.0,y)
		var lift := float(motion["breath"])*chest_weight + float(motion["head_y"])*head_weight
		var source_y := clampf(float(row)/pixel_scale.y + roundf(lift),0,PORTRAIT_CELL.y-1.0/pixel_scale.y)
		var shift := roundf(float(motion["head_x"])*head_weight*pixel_scale.x)
		var frame := mouth_frame if source_y < 112 else expression * 5
		var destination := Rect2(rect.position+Vector2(shift,row),Vector2(rect.size.x,1))
		if int(state["eye"]) > 0 and source_y >= eyes.position.y and source_y < eyes.end.y:
			_portrait_strip(speaker,frame,source_y,0,eyes.position.x,destination,pixel_scale,tint)
			_portrait_strip(speaker,eye_frame,source_y,eyes.position.x,eyes.size.x,destination,pixel_scale,tint)
			_portrait_strip(speaker,frame,source_y,eyes.end.x,PORTRAIT_CELL.x-eyes.end.x,destination,pixel_scale,tint)
		else:
			_portrait_strip(speaker,frame,source_y,0,PORTRAIT_CELL.x,destination,pixel_scale,tint)

func _portrait_strip(speaker: String, frame: int, source_y: float, x: float, width: float, destination: Rect2, pixel_scale: Vector2, tint: Color) -> void:
	var origin := Vector2(frame%ATLAS_COLUMNS,frame/ATLAS_COLUMNS)*PORTRAIT_CELL
	var source := Rect2(origin+Vector2(x,source_y),Vector2(width,1.0/pixel_scale.y))
	var target := Rect2(destination.position+Vector2(x*pixel_scale.x,0),Vector2(width*pixel_scale.x,1))
	draw_texture_rect_region(_textures[speaker],target,source,tint)

func _text(value: String, at: Vector2, point_size: int, color: Color, serif: bool = false) -> void:
	draw_set_transform(Vector2.ZERO)
	draw_string(_name_font if serif else _font,(_offset+at*_factor).round(),value,
		HORIZONTAL_ALIGNMENT_LEFT,-1,maxi(12,roundi(point_size*_factor)),color)
	draw_set_transform(_offset,0,Vector2.ONE*_factor)

func _draw() -> void:
	if not visible or _font == null: return
	draw_set_transform(_offset,0,Vector2.ONE*_factor)
	# Portraits sit behind the speech panel; its border masks their lower edge.
	_draw_portrait("SENU",LEFT_PORTRAIT)
	_draw_portrait("PESCADOR",RIGHT_PORTRAIT)
	# One broad panel leaves the centre of the world visible above the dialogue.
	_beveled(BOX.grow(5),Color(.01,.035,.045,.80),Color("263e40"),12)
	_beveled(BOX,Color(.025,.065,.075,1),GOLD,9)
	_beveled(BOX.grow(-7),Color(0,0,0,0),Color("3e5650"),5)
	draw_line(Vector2(78,548),Vector2(1202,548),Color("40584f"),1)
	draw_line(Vector2(78,666),Vector2(1202,666),Color("304a45"),1)
	_text(active_speaker,Vector2(84,540),21,Color("e4c68d"),true)
	var name_width := _name_font.get_string_size(active_speaker,HORIZONTAL_ALIGNMENT_LEFT,-1,21).x
	_diamond(Vector2(104+name_width,533),4,GOLD)
	var hint := "Enter / E: mostrar fala" if is_typing else "Enter / E: continuar"
	var hint_width := _font.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
	_text(hint,Vector2(1194-hint_width,686),15,MUTED)
	if not is_typing and int(_clock*2)%2 == 0:
		draw_colored_polygon(PackedVector2Array([Vector2(1207,677),Vector2(1214,681),Vector2(1207,685)]),GOLD)
	_text("Clique na caixa para avançar",Vector2(84,686),14,Color("9eafa4"))
