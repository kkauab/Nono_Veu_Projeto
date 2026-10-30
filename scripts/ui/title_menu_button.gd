extends Button
## Procedural title-menu presentation. Native focus, hit area and actions stay put.
signal selection_sounded

const Feedback := preload("res://scripts/ui/ui_button_feedback.gd")
const GOLD := Color("cfac70")
const IVORY := Color("f1e8d3")
var ui_scale := 1.0
var _selected := false
var _hover := false
var _amount := 0.0
var _press := 0.0
var _held := false
var _clock := 0.0
var _gleam := 1.0
var _silent_focus := false
var _sound_count := 0
var _click_count := 0
var _pointer_at_ready := Vector2.ZERO
var _first_pointer_entry := true
var _mark: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("title_menu_presentation", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mark = icon
	_pointer_at_ready = get_viewport().get_mouse_position()
	icon = null
	# Keep text available to native input/accessibility and draw its pixel-aligned
	# presentation here, together with the plate and ornament, without scaling it.
	for state in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color", "font_focus_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)
	Feedback.install(self)
	mouse_entered.connect(_pointer_entered)
	mouse_exited.connect(_pointer_exited)
	focus_entered.connect(_keyboard_selected)
	focus_exited.connect(func():
		if not _hover: set_selected(false))
	button_down.connect(func():
		if disabled: return
		_held = true
		_gleam = 0.0
		_click_count += 1
		Feedback.play(self))
	button_up.connect(func(): _held = false)

func focus_silently() -> void:
	if disabled: return
	_silent_focus = true
	grab_focus()
	_silent_focus = false
	_activate(false)

func set_selected(value: bool) -> void:
	_selected = value and not disabled
	queue_redraw()

func _pointer_entered() -> void:
	if _hover: return
	_hover = true
	if disabled: return
	_silent_focus = true
	grab_focus()
	_silent_focus = false
	# Opening/resizing a menu under a stationary pointer is not a new pass.
	var audible := not _first_pointer_entry or get_viewport().get_mouse_position() != _pointer_at_ready
	_first_pointer_entry = false
	_activate(audible)

func _pointer_exited() -> void:
	_hover = false
	set_selected(false)

func _keyboard_selected() -> void:
	if not _silent_focus: _activate(true)

func _activate(audible: bool) -> void:
	if disabled: return
	for sibling in get_parent().get_children():
		if sibling.get_script() == get_script(): sibling.set_selected(sibling == self)
	if audible:
		_gleam = 0.0
		Feedback.play(self)
		_sound_count += 1
		selection_sounded.emit()

func _process(delta: float) -> void:
	_clock += delta
	_gleam = minf(1.0, _gleam + delta / .38)
	if disabled:
		_selected = false
		_held = false
	_amount = lerpf(_amount, 1.0 if _selected else 0.0, 1.0 - exp(-delta * (15.0 if _selected else 10.0)))
	_press = lerpf(_press, 1.0 if _held else 0.0, 1.0 - exp(-delta * 24.0))
	if not is_visible_in_tree():
		_hover = false
		_selected = false
	queue_redraw()

func animation_snapshot() -> Dictionary:
	return {"selected":_selected,"amount":_amount,"hover":_hover,"press":_press,
		"sound_count":_sound_count,"click_count":_click_count,"hit_rect":get_global_rect()}

func _draw() -> void:
	if not is_node_ready(): return
	var unit := maxf(1.0, roundf(ui_scale))
	var plate := Rect2(Vector2.ZERO, size.round())
	var ink := Color("09181e").lerp(Color("182c2b"), _amount * .8)
	ink.a = .82
	draw_rect(plate, ink)
	var edge := Color("77633e").lerp(GOLD, _amount)
	if disabled: edge = Color("524c38")
	draw_rect(plate.grow(-unit * .5), edge, false, unit)
	if _amount > .01:
		# Low-amplitude light inside the plate, behind the lettering.
		for band in range(4):
			var tint := Color(GOLD, _amount * (.055 - band * .01))
			draw_rect(Rect2(Vector2(unit, unit + band * 3 * unit), Vector2(size.x - unit * 2, 3 * unit)), tint)
		var reach := roundf((size.x - unit * 2) * smoothstep(0.0, 1.0, _amount))
		draw_line(Vector2(unit, size.y - 2 * unit), Vector2(unit + reach, size.y - 2 * unit), Color(GOLD, _amount * .6), unit)
		for right in [false, true]:
			var x := size.x - 4 * unit if right else 4 * unit
			var sign_x := -1 if right else 1
			draw_line(Vector2(x, 4 * unit), Vector2(x + sign_x * 7 * unit, 4 * unit), Color(GOLD, _amount), unit)
			draw_line(Vector2(x, 4 * unit), Vector2(x, 9 * unit), Color(GOLD, _amount), unit)
	if _gleam < 1.0 and not disabled:
		var sweep := roundf(lerpf(12 * ui_scale, size.x - 12 * ui_scale, _gleam))
		var glow := sin(_gleam * PI) * .13 * _amount
		draw_rect(Rect2(sweep, 3 * unit, 3 * unit, size.y - 6 * unit), Color(GOLD, glow))
	var shift := Vector2(roundf(3.0 * ui_scale * _amount), roundf(ui_scale * _press))
	var tint := Color("78847d") if disabled else IVORY.lerp(Color("ffe4a8"), _amount)
	if _mark != null:
		var mark_size := Vector2.ONE * roundf(20 * ui_scale)
		var mark_at := Vector2(roundf(22 * ui_scale), roundf(size.y * .5))
		mark_at.y += roundf(sin(_clock * 2.2) * _amount * ui_scale * .65)
		draw_texture_rect(_mark, Rect2((mark_at - mark_size * .5 + shift).round(), mark_size), false, Color(GOLD, .45 if disabled else .8 + .2 * _amount))
	var face := get_theme_font("font")
	var point_size := get_theme_font_size("font_size")
	var width := face.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x
	var baseline := roundf((size.y - face.get_height(point_size)) * .5 + face.get_ascent(point_size))
	var start := Vector2(roundf((size.x - width) * .5 + 10 * ui_scale), baseline) + shift
	draw_string(face, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size, tint)
