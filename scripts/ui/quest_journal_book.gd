extends Control
## The notebook is a view over the saved quests. Selecting a page never mutates
## progress, awards rewards, or invents completed objectives.
const Quests = preload("res://scripts/world/port_quests.gd")
const PAPER := Color("d9c6a0")
const INK := Color("30291e")
const FADED := Color("77664a")
const GOLD := Color("b6975f")
const BOOK_RECT := Rect2(65, 25, 850, 480)
const BOOK_IMAGE := "res://assets/ui/quest_journal_v1.png"
const FLAVOR := {
	"merit": "O aroma resiste à cheia. Merit acredita que o jarro permaneceu entre as raízes do antigo jardim.",
	"nakht": "Uma espiral no cabo guarda a lembrança de um aprendiz. Nakht quer ouvir aquele bronze cantar outra vez.",
	"adiam": "Cada nó é uma margem. Adiam precisa de caminhos que alguém realmente tenha percorrido.",
	"tarek": "Os nomes de um turno inteiro repousam no Arquivo. Tarek não quer ser o único a lembrá-los.",
	"fisher": "Hori espera no cais. As mãos do irmão conservam um nó que a memória já não sabe nomear."
}

var _ui_scale := 1.0
var embedded := false
var hud: Control
var entries: Array[Dictionary] = []
var selected_id := ""
var list_scroll: ScrollContainer
var detail_scroll: ScrollContainer
var rows: Dictionary = {}
var _details: Control
var _background: Texture2D
var _serif: Font
var _plain: Font
var _selected_button: Button

func configure(owner_hud: Control) -> void:
	hud = owner_hud
	var factor: Variant = hud.get("_factor")
	_ui_scale = float(factor) if factor != null else 1.0
	scale = Vector2.ONE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	name = "QuestJournalBook"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE if embedded else Control.MOUSE_FILTER_STOP
	size = Vector2(960, 540) * _ui_scale
	_serif = hud.title_font
	_plain = hud.font
	if ResourceLoader.exists(BOOK_IMAGE): _background = load(BOOK_IMAGE) as Texture2D
	entries = entries_for(hud.game.store.data)
	if hud.game.has_method("objective"):
		entries[0]["objective"] = hud.game.objective()
	selected_id = str(hud.get("_selected_quest"))
	if not entries.any(func(entry): return entry["id"] == selected_id):
		selected_id = "" if entries.is_empty() else str(entries[0]["id"])
	hud.set("_selected_quest", selected_id)
	_build()
	_focus_selected.call_deferred()
	queue_redraw()

static func entries_for(data: Dictionary) -> Array[Dictionary]:
	var flags: Dictionary = data.get("flags", {})
	var finished := bool(flags.get("complete", false))
	var echo_open := bool(flags.get("echo", false))
	var main_steps: Array = [
		["Recupere a lembrança da Voz nos Sinos", bool(flags.get("seal_bells", false))],
		["Recupere a lembrança da Maré na Cisterna", bool(flags.get("seal_water", false))],
		["Recupere a lembrança do Céu no Observatório", bool(flags.get("seal_stars", false))],
		["Enfrente o Porteiro Sem Nome", bool(flags.get("boss", false))],
		["Atravesse o limiar das Catacumbas", finished]
	]
	if finished: main_steps.append(["Erga a grade pela Galeria do Eco", echo_open])
	var result: Array[Dictionary] = [{
		"id": "main_port", "category": "main", "name": "A Porta das Três Lembranças",
		"giver": "Travessia pelo Porto", "done": finished and echo_open,
		"objective": "Recupere as três lembranças para abrir a passagem às Catacumbas.",
		"flavor": "Em busca de Iri, Senu segue os vestígios que o Porto ainda conserva.",
		"steps": main_steps, "reward": "Passagem às Catacumbas"
	}]
	for raw in Quests.entries(data):
		var entry: Dictionary = raw.duplicate(true)
		entry["id"] = "fisher"
		for id in Quests.QUESTS:
			if entry["name"] == Quests.QUESTS[id]["name"]: entry["id"] = id
		entry["category"] = "side"
		entry["flavor"] = FLAVOR.get(entry["id"], "")
		entry["steps"] = _steps(data, entry["id"])
		result.append(entry)
	return result

static func _steps(data: Dictionary, id: String) -> Array:
	var c: Array = data["collected"]
	var visited: Array = data.get("visited", [])
	var done := "quest_done_" + id in c
	match id:
		"merit": return [["Vá ao Jardim Inundado", done or "garden" in visited or "quest_mirra" in c], ["Encontre o jarro de mirra", done or "quest_mirra" in c], ["Leve-o a Merit", done]]
		"nakht": return [["Vá aos Fornos do Bronze", done or "kilns" in visited or "quest_tenaz" in c], ["Recupere a tenaz marcada", done or "quest_tenaz" in c], ["Devolva a ferramenta a Nakht", done]]
		"tarek": return [["Explore o Arquivo dos Nomes Velados", done or "archive" in visited or "quest_escala" in c], ["Encontre a escala da guarda", done or "quest_escala" in c], ["Leve os nomes a Tarek", done]]
		"adiam": return [["Explore o Aqueduto Silencioso", done or "aqueduct" in visited], ["Explore o Terraço do Farol Partido", done or "beacon" in visited], ["Relate os caminhos a Adiam", done]]
		"fisher":
			var reunion := "fisher_done" in c
			var named := reunion or "fisher_named" in c
			return [["Encontre Sabu no Embarcadouro Velho", named or "fisher_brother_found" in c], ["Receba de Hori o cordão com o nó", named or "fisher_knot" in c], ["Mostre o nó a Sabu", named or "fisher_knot_shown" in c], ["Faça soar o sino da travessia", named or "fisher_bell_rung" in c], ["Ajude Sabu a recordar o nome de Hori", named], ["Retorne a Hori para reunir os irmãos", reunion]]
	return []

func _build() -> void:
	_label(self, "Missões", Rect2(155, 82, 290, 34), 25, INK)
	_label(self, "MEMÓRIAS DA TRAVESSIA", Rect2(156, 119, 288, 20), 11, FADED)
	if not embedded:
		_build_tabs()
		var back := _button(self, "Esc  ·  Voltar", Rect2(779, 502, 122, 29), func(): hud._back())
		back.name = "JournalBack"
		back.add_theme_font_size_override("font_size", roundi(14 * _ui_scale))
		back.add_theme_color_override("font_color", Color("d4bd8f"))
		for style in ["normal", "hover", "pressed", "focus"]: back.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	list_scroll = ScrollContainer.new()
	list_scroll.name = "QuestListScroll"
	list_scroll.position = Vector2(155, 150) * _ui_scale
	list_scroll.size = Vector2(292, 294) * _ui_scale
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.follow_focus = true
	_theme_scroll(list_scroll)
	add_child(list_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(5 * _ui_scale))
	list_scroll.add_child(list)
	for category in ["main", "side"]:
		var heading := _flow_label(list, "PRINCIPAIS" if category == "main" else "SECUNDÁRIAS", 12, FADED)
		heading.name = "MainQuestsHeading" if category == "main" else "SideQuestsHeading"
		heading.custom_minimum_size.y = 27 * _ui_scale
		var found := false
		for entry in entries:
			if entry["category"] != category: continue
			found = true
			_build_row(list, entry)
		if not found:
			_flow_label(list, "Converse com os moradores para registrar seus pedidos.", 16, FADED).name = "NoSideQuests"
	for index in range(entries.size()):
		var row: Button = rows[entries[index]["id"]]
		row.focus_neighbor_top = row.get_path_to(rows[entries[wrapi(index - 1, 0, entries.size())]["id"]])
		row.focus_neighbor_bottom = row.get_path_to(rows[entries[wrapi(index + 1, 0, entries.size())]["id"]])
	_details = Control.new()
	_details.name = "SelectedQuest"
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_details)
	select_quest(selected_id)

func _build_row(list: VBoxContainer, entry: Dictionary) -> void:
	var id: String = entry["id"]
	var row := Button.new()
	row.name = "Quest_" + id
	row.custom_minimum_size = Vector2(0, 76) * _ui_scale
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.tooltip_text = str(entry["name"])
	row.pressed.connect(func(): select_quest(id))
	row.focus_entered.connect(func(): select_quest(id))
	list.add_child(row)
	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: content.add_theme_constant_override("margin_" + side, roundi(10 * _ui_scale))
	for side in ["top", "bottom"]: content.add_theme_constant_override("margin_" + side, roundi(8 * _ui_scale))
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", roundi(4 * _ui_scale))
	content.add_child(lines)
	var title := _flow_label(lines, ("✓  " if entry["done"] else "◆  ") + str(entry["name"]), 17, FADED if entry["done"] else INK)
	title.size.x = 254 * _ui_scale
	_flow_label(lines, "Concluída" if entry["done"] else entry["giver"], 12, FADED)
	rows[id] = row

func _build_tabs() -> void:
	var tabs := [["journal", "Missões", "hud_journal.svg"], ["map", "Mapa", "hud_map.svg"], ["inventory", "Inventário", "hud_inventory.svg"], ["tree", "Emanações", "hud_tree.svg"]]
	for index in range(tabs.size()):
		var tab: Array = tabs[index]
		var target: String = tab[0]
		var button := _button(self, "", Rect2(35, 105 + index * 68, 49, 61), func(): hud.show_overlay(target))
		button.name = "JournalTab_" + target
		button.tooltip_text = tab[1]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("8e7046") if index == 0 else Color("152226")
		style.border_color = Color("a58a59")
		style.set_border_width_all(1)
		style.corner_radius_top_left = 3
		style.corner_radius_bottom_left = 3
		button.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color("9c8054")
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("focus", hover)
		button.add_theme_stylebox_override("pressed", hover)
		var path := "res://assets/ui/" + str(tab[2])
		if ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("icon_max_width", roundi(27 * _ui_scale))
		else:
			button.text = ["≡", "◇", "○", "✧"][index]

func select_quest(id: String) -> void:
	if not rows.has(id): return
	selected_id = id
	hud.set("_selected_quest", id)
	for key in rows:
		var row: Button = rows[key]
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.52, .39, .20, .17) if key == id else Color(0, 0, 0, 0)
		style.border_color = Color("6c5739") if key == id else Color(.37, .30, .20, .14)
		style.border_width_left = 3 if key == id else 0
		style.border_width_bottom = 1
		row.add_theme_stylebox_override("normal", style)
		var hover := style.duplicate() as StyleBoxFlat
		hover.bg_color = Color(.52, .39, .20, .12)
		row.add_theme_stylebox_override("hover", hover)
		row.add_theme_stylebox_override("pressed", style)
		row.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_selected_button = rows[id]
	if _details == null: return
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var entry: Dictionary
	for record in entries:
		if record["id"] == id: entry = record; break
	detail_scroll = ScrollContainer.new()
	detail_scroll.name = "QuestDetailsScroll"
	detail_scroll.position = Vector2(523, 83) * _ui_scale
	detail_scroll.size = Vector2(309, 360) * _ui_scale
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_theme_scroll(detail_scroll)
	_details.add_child(detail_scroll)
	var body := VBoxContainer.new()
	body.name = "QuestBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(12 * _ui_scale))
	detail_scroll.add_child(body)
	_flow_label(body, entry["name"], 23, INK).name = "QuestTitle"
	_flow_label(body, str(entry["giver"]).to_upper(), 12, FADED).name = "QuestGiver"
	_flow_label(body, "PRÓXIMO PASSO", 12, FADED)
	_flow_label(body, str(entry["objective"]), 18, INK).name = "CurrentObjective"
	var flavor := _flow_label(body, str(entry["flavor"]), 16, FADED)
	var italic := SystemFont.new()
	italic.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	italic.font_italic = true
	flavor.add_theme_font_override("font", italic)
	_flow_label(body, "OBJETIVOS", 12, FADED)
	for step in entry["steps"]:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", roundi(9 * _ui_scale))
		body.add_child(line)
		var mark := _flow_label(line, "✓" if step[1] else "◇", 16, FADED)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		mark.custom_minimum_size.x = 20 * _ui_scale
		var item := _flow_label(line, step[0], 18, FADED if step[1] else INK)
		item.name = "ObjectiveStep"
	var reward_status := "CAMINHO" if entry["category"] == "main" else ("RECOMPENSA RECEBIDA" if entry["done"] else "RECOMPENSA")
	_flow_label(body, reward_status, 12, FADED)
	_flow_label(body, entry["reward"], 16, INK).name = "QuestReward"
	queue_redraw()

func _focus_selected() -> void:
	if is_instance_valid(_selected_button) and _selected_button.is_inside_tree(): _selected_button.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or entries.is_empty(): return
	if event.keycode not in [KEY_UP, KEY_DOWN]: return
	var index := 0
	for i in range(entries.size()):
		if entries[i]["id"] == selected_id: index = i; break
	index = wrapi(index + (-1 if event.keycode == KEY_UP else 1), 0, entries.size())
	select_quest(entries[index]["id"])
	_focus_selected()
	get_viewport().set_input_as_handled()

func _flow_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_font_override("font", _serif)
	result.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("line_spacing", roundi(3 * _ui_scale))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	# Absolute labels need their width before text enters the tree; otherwise
	# autowrap first measures a zero-width column and leaves a tall minimum size.
	var result := Label.new()
	result.position = rect.position * _ui_scale
	result.size = rect.size * _ui_scale
	result.add_theme_font_override("font", _serif)
	result.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	result.add_theme_color_override("font_color", color)
	result.add_theme_constant_override("line_spacing", roundi(3 * _ui_scale))
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.position = rect.position * _ui_scale
	result.size = rect.size * _ui_scale
	result.add_theme_font_override("font", _serif)
	result.add_theme_color_override("font_color", Color("d4bd8f"))
	result.pressed.connect(callback)
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(result)
	return result

func _theme_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 6 * _ui_scale
	var track := StyleBoxFlat.new()
	track.bg_color = Color(.36, .27, .14, .06)
	bar.add_theme_stylebox_override("scroll", track)
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = Color(.36, .27, .14, .32)
	grabber.set_corner_radius_all(2)
	for key in ["grabber", "grabber_highlight", "grabber_pressed"]: bar.add_theme_stylebox_override(key, grabber)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _ui_scale)
	if embedded:
		_draw_page_marks()
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(960, 540)), Color(.025, .05, .06, .98))
	for origin in [Vector2(18, 17), Vector2(942, 17), Vector2(942, 522), Vector2(18, 522)]:
		var direction := Vector2(1 if origin.x < 480 else -1, 1 if origin.y < 270 else -1)
		draw_line(origin, origin + Vector2(100 * direction.x, 0), Color(.70, .57, .36, .35), 1)
		draw_line(origin, origin + Vector2(0, 30 * direction.y), Color(.70, .57, .36, .35), 1)
		_diamond(origin, 3, GOLD)
	if _background != null:
		draw_texture_rect(_background, BOOK_RECT, false)
	else:
		# Usable before the optional painted asset is imported.
		draw_style_box(_book_style(Color("2c2921"), Color("715432"), 8), BOOK_RECT.grow(6))
		draw_style_box(_book_style(PAPER, Color("aa9063"), 5), BOOK_RECT)
		for i in range(5):
			draw_line(Vector2(81 + i * 2, 51), Vector2(81 + i * 2, 481), Color(.28, .18, .08, .09))
			draw_line(Vector2(879 - i * 2, 51), Vector2(879 - i * 2, 481), Color(.28, .18, .08, .09))
		for i in range(12):
			var alpha := .13 * (1.0 - float(i) / 12.0)
			draw_line(Vector2(479 - i, 49), Vector2(479 - i, 484), Color(.22, .14, .07, alpha))
			draw_line(Vector2(480 + i, 49), Vector2(480 + i, 484), Color(.22, .14, .07, alpha))
	_draw_page_marks()
	_diamond(Vector2(480, 15), 6, GOLD)
	_diamond(Vector2(480, 521), 4, GOLD)

func _draw_page_marks() -> void:
	for line in [[Vector2(155, 144), Vector2(447, 144)]]:
		draw_line(line[0], line[1], Color(.32, .24, .13, .35), 1)
func _quest_sketch(at: Vector2) -> void:
	var color := Color(.25, .18, .09, .32)
	if selected_id == "merit":
		var outline := PackedVector2Array([Vector2(-6, -23), Vector2(-5, -17), Vector2(-10, -11), Vector2(-13, -2), Vector2(-10, 10), Vector2(-6, 14), Vector2(6, 14), Vector2(10, 10), Vector2(13, -2), Vector2(10, -11), Vector2(5, -17), Vector2(6, -23)])
		for i in range(outline.size()): outline[i] += at
		draw_polyline(outline, color, 1, true)
		draw_arc(at + Vector2(0, -23), 6, 0, TAU, 12, color, 1)
		draw_arc(at + Vector2(-13, -8), 5, 0, TAU, 10, color, 1)
		draw_arc(at + Vector2(13, -8), 5, 0, TAU, 10, color, 1)
		draw_line(at + Vector2(-11, -2), at + Vector2(11, -2), color, 1)
		_diamond(at + Vector2(0, 5), 4, color)
	elif selected_id == "nakht":
		draw_line(at + Vector2(-12, 13), at + Vector2(6, -15), color, 3)
		var head := PackedVector2Array([at + Vector2(-2, -22), at + Vector2(16, -11), at + Vector2(11, -3), at + Vector2(-7, -14), at + Vector2(-2, -22)])
		draw_polyline(head, color, 1, true)
	elif selected_id == "fisher":
		for i in range(3): draw_arc(at + Vector2(-8 + i * 8, -4), 9, 0, TAU, 16, color, 1)
		draw_line(at + Vector2(-19, 0), at + Vector2(-25, 13), color, 1)
		draw_line(at + Vector2(18, -5), at + Vector2(25, -19), color, 1)
	else:
		var outline := PackedVector2Array([at + Vector2(-18, -20), at + Vector2(-5, -16), at + Vector2(6, -22), at + Vector2(18, -18), at + Vector2(16, 12), at + Vector2(5, 8), at + Vector2(-6, 14), at + Vector2(-19, 10), at + Vector2(-18, -20)])
		draw_polyline(outline, color, 1, true)
		draw_line(at + Vector2(-5, -16), at + Vector2(-6, 14), color, 1)
		draw_line(at + Vector2(6, -22), at + Vector2(5, 8), color, 1)
		_diamond(at + Vector2(6, -7), 5, color)

func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(0, -radius), at + Vector2(radius, 0), at + Vector2(0, radius), at + Vector2(-radius, 0), at + Vector2(0, -radius)]), color, 1)

func _book_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style
