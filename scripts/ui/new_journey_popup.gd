extends Control
## Compact in-viewport modal; story/save ownership remains with the game.
signal confirmed
signal cancelled
const Typography = preload("res://scripts/ui/ui_typography.gd")
const GOLD := Color("cfac70")
const IVORY := Color("f1e8d3")
var _choice_pending := false
var _body: Label
var _cancel: Button

func configure(ui_scale: float) -> void:
	name = "NewJourneyPopup"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "PopupPanel"
	panel.custom_minimum_size.x = 480 * ui_scale
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1b21")
	style.border_color = GOLD
	style.set_border_width_all(maxi(1,roundi(ui_scale)))
	style.set_content_margin_all(roundi(24 * ui_scale))
	style.shadow_color = Color(0,0,0,.35)
	style.shadow_size = roundi(8 * ui_scale)
	panel.add_theme_stylebox_override("panel",style)
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", roundi(16 * ui_scale))
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "Nova jornada"
	heading.add_theme_font_override("font",Typography.title())
	heading.add_theme_font_size_override("font_size",roundi(25 * ui_scale))
	heading.add_theme_color_override("font_color",GOLD)
	content.add_child(heading)
	_body = Label.new()
	_body.name = "OverwriteWarning"
	_body.text = "O último save será sobrescrito.\nDeseja continuar?"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font",Typography.body())
	_body.add_theme_font_size_override("font_size",roundi(20 * ui_scale))
	_body.add_theme_color_override("font_color",IVORY)
	content.add_child(_body)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", roundi(14 * ui_scale))
	content.add_child(actions)
	var confirm := _button(actions,"Confirmar","ConfirmNewJourney",ui_scale)
	_cancel = _button(actions,"Cancelar","CancelNewJourney",ui_scale)
	confirm.pressed.connect(func(): _choose(true))
	_cancel.pressed.connect(func(): _choose(false))
	for button in [confirm,_cancel]:
		var other: Button = _cancel if button == confirm else confirm
		for property in ["focus_next","focus_previous","focus_neighbor_left","focus_neighbor_right","focus_neighbor_top","focus_neighbor_bottom"]:
			button.set(property,button.get_path_to(other))
	_focus_cancel.call_deferred()

func _button(parent: Node, caption: String, id: String, ui_scale: float) -> Button:
	var button := Button.new()
	button.name = id
	button.text = caption
	button.custom_minimum_size = Vector2(190,38) * ui_scale
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font",Typography.title())
	button.add_theme_font_size_override("font_size",roundi(20 * ui_scale))
	button.add_theme_color_override("font_color",IVORY)
	button.add_theme_color_override("font_hover_color",Color("ffe4a8"))
	for state in ["normal","hover","pressed","focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("223432") if state in ["hover","pressed"] else Color("102329")
		style.border_color = GOLD if state in ["hover","focus"] else GOLD.darkened(.35)
		style.set_border_width_all(maxi(1,roundi(ui_scale)))
		button.add_theme_stylebox_override(state,style)
	parent.add_child(button)
	return button

func _focus_cancel() -> void:
	if is_instance_valid(_cancel) and _cancel.is_inside_tree(): _cancel.grab_focus()

func _choose(new_journey: bool) -> void:
	if _choice_pending: return
	_choice_pending = true
	# If archiving fails, the existing callback leaves this modal open for retry.
	_allow_retry.call_deferred()
	if new_journey: confirmed.emit()
	else: cancelled.emit()

func _allow_retry() -> void:
	_choice_pending = false

func show_error(message: String) -> void:
	_body.text = message
	_body.add_theme_color_override("font_color",Color("e4aaa0"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_choose(false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventScreenTouch: accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color(0,0,0,.55))
