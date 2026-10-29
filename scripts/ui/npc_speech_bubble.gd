extends Control
## Exploration conversations: one speaker and at most four text lines per turn.
## Cutscenes and written inscriptions keep their own presentation.

signal finished

const PAPER := Color("f0e1bd")
const INK := Color("30291e")
const GOLD := Color("9d7944")
const MAX_LINES := 4
const NPC_IDS := {"HORI": "npc_fisher", "PESCADOR": "npc_fisher", "SABU": "npc_brother", "HOMEM": "npc_brother", "MERIT": "loja_merit", "NAKHT": "loja_nakht", "ADIAM": "loja_adiam", "TAREK": "missao_tarek", "ANKHET": "isle_ankhet", "MULHER": "isle_ankhet"}

var hud: Control
var npc_id := ""
var pages: Array[Dictionary] = []
var page_index := 0
var speaker_id := ""
var panel: PanelContainer
var speaker_label: Label
var body_label: Label
var next_button: Button
var _factor := 1.0
var _tail := PackedVector2Array()
var _body_width := 320.0
var _font_size := 17

func configure(owner_hud: Control, title: String, body: String, actor_id: String = "") -> void:
	hud = owner_hud
	npc_id = actor_id
	name = "NpcSpeechBubble"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_factor = maxf(.5, float(hud.get("_factor")))
	_body_width = minf(340.0 * _factor, hud.size.x - 72.0 * _factor)
	_font_size = roundi(17 * _factor)
	var default_speaker := title if not npc_id.is_empty() and npc_id not in NPC_IDS.values() else ""
	pages = paginate(body, hud.font, _font_size, _body_width, default_speaker)
	if pages.is_empty():
		finished.emit()
		return
	page_index = clampi(int(hud.get_meta("speech_page", 0)), 0, pages.size() - 1)
	_build()
	_show_page()

## Prefixes are source data only. Presentation separates the name from speech.
static func paginate(body: String, text_font: Font, font_size: int, width: float, default_speaker: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for raw in body.split("\n\n", false):
		var text := raw.strip_edges()
		var speaker := default_speaker
		var divider := text.find(" — ")
		if divider > 0 and divider < 24:
			var prefix := text.substr(0, divider).to_upper()
			if prefix == "SENU" or NPC_IDS.has(prefix):
				speaker = prefix
				text = text.substr(divider + 3)
		var lines: Array[String] = []
		var line := ""
		for word in text.replace("\n", " ").split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if not line.is_empty() and text_font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				lines.append(line)
				line = word
			else:
				line = candidate
		if not line.is_empty(): lines.append(line)
		for offset in range(0, lines.size(), MAX_LINES):
			result.append({"speaker": speaker, "text": "\n".join(lines.slice(offset, offset + MAX_LINES))})
	return result

func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "SpeechPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = GOLD
	style.set_border_width_all(maxi(1, roundi(_factor)))
	style.set_corner_radius_all(roundi(9 * _factor))
	style.content_margin_left = 18 * _factor
	style.content_margin_right = 18 * _factor
	style.content_margin_top = 12 * _factor
	style.content_margin_bottom = 10 * _factor
	style.shadow_color = Color(0, 0, 0, .3)
	style.shadow_size = roundi(5 * _factor)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(6 * _factor))
	panel.add_child(column)
	speaker_label = Label.new()
	speaker_label.add_theme_font_override("font", hud.title_font)
	speaker_label.add_theme_font_size_override("font_size", roundi(14 * _factor))
	speaker_label.add_theme_color_override("font_color", GOLD.darkened(.25))
	column.add_child(speaker_label)
	body_label = Label.new()
	body_label.name = "SpeechText"
	body_label.custom_minimum_size.x = _body_width
	body_label.add_theme_font_override("font", hud.font)
	body_label.add_theme_font_size_override("font_size", _font_size)
	body_label.add_theme_color_override("font_color", INK)
	body_label.add_theme_constant_override("line_spacing", roundi(3 * _factor))
	column.add_child(body_label)
	next_button = Button.new()
	next_button.name = "SpeechNext"
	next_button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_button.add_theme_font_override("font", hud.font)
	next_button.add_theme_font_size_override("font_size", roundi(11 * _factor))
	next_button.add_theme_color_override("font_color", GOLD.darkened(.25))
	for state in ["normal", "hover", "pressed", "focus"]:
		next_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	next_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	next_button.pressed.connect(advance)
	column.add_child(next_button)

func _show_page() -> void:
	var page: Dictionary = pages[page_index]
	speaker_id = str(page["speaker"])
	speaker_label.text = "Anotação" if speaker_id.is_empty() else _speaker_name(speaker_id)
	body_label.text = page["text"]
	next_button.text = ("Concluir" if page_index == pages.size() - 1 else "Continuar") + "  ·  E / Espaço   %d/%d" % [page_index + 1, pages.size()]
	hud.set_meta("speech_page", page_index)
	panel.reset_size()
	_position_bubble.call_deferred()

func _speaker_name(id: String) -> String:
	if id == "PESCADOR": return "Pescador"
	if id == "HOMEM": return "Homem das cordas"
	if id == "MULHER": return "Guardiã das garças"
	return id.capitalize() if id == "SENU" or NPC_IDS.has(id) else id

func advance() -> void:
	if page_index + 1 >= pages.size():
		finished.emit()
		return
	page_index += 1
	_show_page()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		advance()

func _process(_delta: float) -> void:
	if is_instance_valid(panel): _position_bubble()

func _actor() -> Node2D:
	if not is_inside_tree() or not is_instance_valid(hud) or not is_instance_valid(hud.game): return null
	if speaker_id == "SENU": return hud.game.player
	var target: String = NPC_IDS.get(speaker_id, npc_id)
	for actor in get_tree().get_nodes_in_group("interactables"):
		if str(actor.get("item_id")) == target: return actor as Node2D
	return hud.game.player

func _position_bubble() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(hud) or not is_instance_valid(panel): return
	var area := hud.size
	var margin := 20.0 * _factor
	var panel_size := panel.get_combined_minimum_size()
	panel.size = panel_size
	_tail.clear()
	if speaker_id.is_empty():
		panel.position = Vector2((area.x - panel_size.x) * .5, area.y - panel_size.y - 38 * _factor)
	else:
		var actor := _actor()
		if not is_instance_valid(actor): return
		var head := actor.global_position + Vector2(0, -48)
		var marker: Variant = actor.get("marker_offset")
		if marker is Vector2: head += marker
		var point: Vector2 = hud.game.world_to_ui(head)
		point.x = clampf(point.x, margin + 12 * _factor, area.x - margin - 12 * _factor)
		point.y = clampf(point.y, margin, area.y - margin)
		var above := point.y - panel_size.y - 18 * _factor >= margin
		var pos := Vector2(point.x - panel_size.x * .5, point.y - panel_size.y - 18 * _factor if above else point.y + 18 * _factor)
		pos.x = clampf(pos.x, margin, maxf(margin, area.x - panel_size.x - margin))
		pos.y = clampf(pos.y, margin, maxf(margin, area.y - panel_size.y - margin))
		panel.position = pos
		var edge := Vector2(clampf(point.x, pos.x + 15 * _factor, pos.x + panel_size.x - 15 * _factor), pos.y + panel_size.y if above else pos.y)
		_tail = PackedVector2Array([edge - Vector2(9 * _factor, 0), point, edge + Vector2(9 * _factor, 0)])
	queue_redraw()

func _draw() -> void:
	if _tail.size() == 3:
		draw_colored_polygon(_tail, PAPER)
		draw_polyline(_tail, GOLD, maxf(1, _factor), true)
