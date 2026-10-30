extends Control
## HUD v6: desenho ornamental e controles nativos, dados e salvamento reais.

const UI_SIZE := Vector2(960, 540)
const INK := Color("09181e")
const GOLD := Color("cfac70")
const IVORY := Color("f1e8d3")
const MUTED := Color("a3b6ad")
const TITLE_IMAGE := "res://assets/ui/port_title_v7.png"
const PORTRAIT_IMAGE := "res://assets/ui/senu_portrait_v7.png"
const PORTRAIT_IDLE_IMAGE := "res://assets/ui/senu_menu_idle_v8.png"
const PortQuests = preload("res://scripts/world/port_quests.gd")
const SkillCatalog = preload("res://scripts/progression/skill_catalog.gd")
const JournalBook = preload("res://scripts/ui/quest_journal_book.gd")
const HUD_STYLE_VERSION := 8
const Notebook = preload("res://scripts/ui/pause_notebook.gd")
const SpeechBubble = preload("res://scripts/ui/npc_speech_bubble.gd")
const BOOK_MODES := ["pause", "journal", "inventory", "map", "tree", "settings", "controls", "exit"]
const FramePacing = preload("res://scripts/core/frame_pacing.gd")
const TitleMenuButton = preload("res://scripts/ui/title_menu_button.gd")
const ButtonFeedback = preload("res://scripts/ui/ui_button_feedback.gd")
const NewJourneyPopup = preload("res://scripts/ui/new_journey_popup.gd")
const SKILL_POINTS := {
	"vontade": Vector2(145, 392), "materia": Vector2(325, 392), "intelecto": Vector2(505, 392),
	"ritmo_lamina": Vector2(145, 326), "passo_etereo": Vector2(325, 326), "selo_mercurio": Vector2(505, 326),
	"lamina_ascendente": Vector2(100, 269), "pele_alabastro": Vector2(325, 269), "olho_escriba": Vector2(550, 269),
	"contra_ataque_agil": Vector2(210, 218), "reflexo_palavra": Vector2(325, 218), "esquiva_eterea": Vector2(440, 218),
	"convergencia_nous": Vector2(325, 164)
}
const SKILL_CODES := {
	"vontade": "V1", "materia": "M1", "intelecto": "I1",
	"ritmo_lamina": "V2", "passo_etereo": "M2", "selo_mercurio": "I2",
	"lamina_ascendente": "V3", "pele_alabastro": "M3", "olho_escriba": "I3",
	"contra_ataque_agil": "VM", "reflexo_palavra": "VI", "esquiva_eterea": "MI",
	"convergencia_nous": "N"
}
var game: Node2D
var overlay := ""
var message := ""
var message_color := GOLD
var message_time := 0.0
var dialog_title := ""
var dialog_body := ""
var _conversation_active := false
var conversation_npc_id := ""
var font: Font
var title_font: Font
var _factor := 1.0
var _offset := Vector2.ZERO
var _last_size := Vector2.ZERO
var _return_overlay := ""
var _selection_title := "CONTINUAR"
var _selection_description := "Retome a travessia entre as memórias do Porto."
var _title_texture: Texture2D
var _portrait_texture: Texture2D
var _portrait_idle_texture: Texture2D
var _title_backdrop: TextureRect
var _menu_clock := 0.0
var _redraw_tick := 0.0
var _weapon_icons: Dictionary = {}
var _next_asset_check := 0.0
var _selected_quest := ""
var _book_inventory_selected := ""
var _book_inventory_filter := "Todos"
var _book_map_selected := ""
var _book_return_to := ""
## Desligado por padrão: o jogo segue a taxa do monitor (scripts/core/frame_pacing.gd).
var _limit_fps := false
var _buttons: Array[Button] = []
var _selected_skill := "vontade"
var _skill_nodes: Dictionary = {}
var _skill_details: Array[Control] = []
var _skill_learn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ButtonFeedback.install(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = preload("res://scripts/ui/ui_typography.gd").body()
	title_font = preload("res://scripts/ui/ui_typography.gd").title()
	theme = preload("res://scripts/ui/ui_typography.gd").make_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_backdrop = TextureRect.new()
	_title_backdrop.name = "AnimatedPixelHarbor"
	_title_backdrop.show_behind_parent = true
	_title_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_backdrop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_title_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var sea_material := ShaderMaterial.new()
	sea_material.shader = preload("res://assets/shaders/menu_title_v8.gdshader")
	_title_backdrop.material = sea_material
	add_child(_title_backdrop)
	for category in ["espada", "leve"]:
		var path := "res://assets/ui/weapon_daggers.svg" if category == "leve" else "res://assets/ui/weapon_khopesh.svg"
		if ResourceLoader.exists(path): _weapon_icons[category] = load(path) as Texture2D
	_read_preferences()
	_geometry()

func _process(delta: float) -> void:
	_menu_clock += delta
	message_time = maxf(0, message_time - delta)
	_loot_time = maxf(0, _loot_time - delta)
	if size != _last_size:
		_geometry()
		if overlay != "": _build_controls()
	_next_asset_check -= delta
	if _next_asset_check <= 0:
		_next_asset_check = 2
		if _title_texture == null and ResourceLoader.exists(TITLE_IMAGE):
			_title_texture = load(TITLE_IMAGE) as Texture2D
		if _portrait_texture == null and ResourceLoader.exists(PORTRAIT_IMAGE):
			_portrait_texture = load(PORTRAIT_IMAGE) as Texture2D
		if _portrait_idle_texture == null and ResourceLoader.exists(PORTRAIT_IDLE_IMAGE):
			_portrait_idle_texture = load(PORTRAIT_IDLE_IMAGE) as Texture2D
		_title_backdrop.texture = _title_texture
	_title_backdrop.visible = overlay in ["intro","new_journey"] and _title_texture != null
	_redraw_tick += delta
	if _redraw_tick >= 1.0 / 30.0:
		_redraw_tick = 0.0
		queue_redraw()

func _geometry() -> void:
	_last_size = size
	var viewport_size := size if size.x > 0 and size.y > 0 else get_viewport_rect().size
	_factor = minf(viewport_size.x / UI_SIZE.x, viewport_size.y / UI_SIZE.y)
	_offset = (viewport_size - UI_SIZE * _factor) * .5
	if is_instance_valid(_title_backdrop):
		_title_backdrop.position = _offset
		_title_backdrop.size = UI_SIZE * _factor

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("pause_game"):
		if overlay == "": show_overlay("pause")
		else: _back()
		get_viewport().set_input_as_handled()
	elif overlay in [""] + BOOK_MODES and event.is_action_pressed("skill_tree"):
		show_overlay("" if overlay == "tree" else "tree")
		get_viewport().set_input_as_handled()
	elif overlay in [""] + BOOK_MODES and event.is_action_pressed("world_map"):
		show_overlay("" if overlay == "map" else "map")
		get_viewport().set_input_as_handled()
	elif InputMap.has_action("quest_journal") and overlay in [""] + BOOK_MODES and event.is_action_pressed("quest_journal"):
		show_overlay("" if overlay == "journal" else "journal")
		get_viewport().set_input_as_handled()

func toast(text: String, color: Color = GOLD, duration: float = 3.8) -> void:
	message = text
	message_color = color
	message_time = duration
	if overlay == "new_journey" and has_node("NewJourneyPopup"):
		get_node("NewJourneyPopup").show_error(text)

func show_dialog(title: String, body: String) -> void:
	_conversation_active = false
	dialog_title = title
	dialog_body = body
	_return_overlay = ""
	show_overlay("dialog")

func show_conversation(title: String, body: String, npc_id: String = "") -> void:
	_conversation_active = true
	conversation_npc_id = npc_id
	set_meta("speech_page", 0)
	dialog_title = title
	dialog_body = body
	_return_overlay = ""
	show_overlay("dialog")

func show_overlay(mode: String) -> void:
	if mode != "dialog": _conversation_active = false
	if mode in BOOK_MODES and overlay not in BOOK_MODES:
		_book_return_to = "intro" if overlay == "intro" else ""
	if mode in ["tree", "map", "inventory", "controls", "settings", "journal"] and overlay in ["pause", "intro", ""]:
		_return_overlay = overlay
	if mode == "new_journey": _return_overlay = "intro"
	overlay = mode
	set_meta(ButtonFeedback.SCREEN_KEY, mode)
	get_tree().paused = mode != ""
	mouse_filter = Control.MOUSE_FILTER_STOP if mode != "" else Control.MOUSE_FILTER_IGNORE
	_geometry()
	_build_controls()
	queue_redraw()

func _back() -> void:
	if overlay == "intro": return
	if overlay == "controls":
		show_overlay("settings")
	elif overlay in BOOK_MODES:
		show_overlay(_book_return_to)
	else:
		show_overlay(_return_overlay)

func _build_controls() -> void:
	_buttons.clear()
	_skill_nodes.clear()
	_skill_details.clear()
	_skill_learn = null
	for child in get_children():
		if child == _title_backdrop: continue
		remove_child(child)
		child.queue_free()
	if game == null: return
	if overlay in BOOK_MODES:
		var notebook := Notebook.new()
		add_child(notebook)
		notebook.configure(self, overlay)
		return
	match overlay:
		"intro", "new_journey":
			_button("Nova jornada", Rect2(104, 294, 302, 44), func():
				if game.store.loaded_existing or bool(game.store.data["flags"].get("opening_seen", false)): show_overlay("new_journey")
				else: game.start_journey(), "diamond", "", true)
			var resume := _button("Retomar jornada", Rect2(104, 347, 302, 42), game.start_journey, "diamond", "", true)
			resume.disabled = not game.store.loaded_existing
			_button("Configurações", Rect2(104, 399, 302, 42), func(): show_overlay("settings"), "diamond", "", true)
			_button("Sair", Rect2(104, 451, 302, 42), game.save_and_quit, "diamond", "", true)
			if overlay == "new_journey":
				for button in _buttons:
					button.focus_mode = Control.FOCUS_NONE
					button.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var popup := NewJourneyPopup.new()
				add_child(popup)
				popup.confirmed.connect(game.begin_new_journey)
				popup.cancelled.connect(func(): show_overlay("intro"))
				popup.configure(_factor)
				return
		"tree":
			_build_skill_tree()
			_back_button()
		"map":
			_map_legend()
			_back_button()
		"inventory":
			_inventory_controls()
			_back_button()
		"controls":
			var commands := [["WASD / setas", "Andar"], ["Shift + movimento", "Correr"], ["Espaço", "Rolar / esquivar"],
				["J / mouse esquerdo", "Ataque leve"], ["F", "Ataque forte"], ["K / mouse direito", "Aparar"],
				["Q", "Poder da arma"], ["Tab", "Trocar arma encontrada"], ["E", "Interagir / recolher"],
				["T", "Árvore das Emanações"], ["M / N", "Mapa / missões"], ["Esc", "Pausa / voltar"], ["R", "Usar bálsamo"], ["C", "Selo de Mercúrio¹"]]
			for index in range(commands.size()):
				var column := index / 7
				var row := index % 7
				_label(commands[index][0], Rect2(100 + column * 404, 154 + row * 42, 196, 30), 16, GOLD)
				_label(commands[index][1], Rect2(290 + column * 404, 154 + row * 42, 196, 30), 16, IVORY)
			_back_button()
		"settings":
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			_button("Tela cheia: " + ("ativada" if fullscreen else "desativada"), Rect2(112, 163, 660, 47), _toggle_fullscreen, "settings")
			_button("Limite de 60 quadros: " + ("ativado" if _limit_fps else "desativado"), Rect2(112, 223, 660, 47), func():
				_limit_fps = not _limit_fps
				FramePacing.apply(_limit_fps)
				_write_preferences()
				_build_controls(), "settings")
			_label("As alterações são salvas neste computador.\nOs menus aceitam mouse, setas, Tab e Enter.", Rect2(112, 306, 700, 60), 17, MUTED)
			_back_button()
		"dialog":
			if _conversation_active:
				var speech := SpeechBubble.new()
				add_child(speech)
				speech.finished.connect(func(): show_overlay(""))
				speech.configure(self, dialog_title, dialog_body, conversation_npc_id)
			else:
				var portrait := _find_npc_portrait(dialog_title)
				var text_rect := Rect2(100, 156, 530 if portrait != null else 760, 250)
				_scroll_text(dialog_body, text_rect, 19)
				_back_button()
		"journal":
			var book := JournalBook.new()
			book.name = "QuestJournalBook"
			book.position = _offset
			book.scale = Vector2.ONE * _factor
			book.size = UI_SIZE
			add_child(book)
			book.configure(self)
		"shop":
			ShopPanel.build(self, game)
			_back_button()
	if overlay == "tree" and _skill_nodes.has(_selected_skill):
		_focus_button.call_deferred(_skill_nodes[_selected_skill])
	elif not _buttons.is_empty():
		for button in _buttons:
			if not button.disabled:
				_focus_button.call_deferred(button)
				break

func _focus_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.get_parent() == self:
		if button is TitleMenuButton: button.focus_silently()
		else: button.grab_focus()

func _build_skill_tree() -> void:
	if not SkillCatalog.NODES.has(_selected_skill): _selected_skill = SkillCatalog.ORDER[0]
	for id in SkillCatalog.ORDER:
		var skill_id: String = id
		var point: Vector2 = SKILL_POINTS[id]
		var node := _button(SKILL_CODES[id], Rect2(point - Vector2(19, 19), Vector2(38, 38)), func(): _select_skill(skill_id), "", "", true)
		node.name = "Skill_" + id
		node.add_theme_font_override("font", font)
		node.add_theme_font_size_override("font_size", maxi(14, roundi(14 * _factor)))
		node.add_theme_color_override("font_color", IVORY)
		for style_name in ["normal", "hover", "pressed", "focus"]:
			node.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		var definition: Dictionary = SkillCatalog.NODES[id]
		node.tooltip_text = "%s · %d Nous\n%s" % [definition["name"], definition["cost"], definition["description"]]
		node.focus_entered.connect(func(): _select_skill(skill_id))
		node.mouse_entered.connect(func(): _select_skill(skill_id))
		_skill_nodes[id] = node
	_skill_learn = _button("Aprender", Rect2(615, 416, 248, 34), _learn_selected_skill, "", "", true)
	_skill_learn.name = "SkillLearn"
	# The next selection is geometric, rather than dictionary or purchase order.
	# Tab still visits every node, the learn button, and the return button.
	for id in SkillCatalog.ORDER:
		var node: Button = _skill_nodes[id]
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var closest := ""
			var best_score := INF
			for other in SkillCatalog.ORDER:
				if other == id: continue
				var offset: Vector2 = SKILL_POINTS[other] - SKILL_POINTS[id]
				if offset.normalized().dot(direction) < .45: continue
				var score := offset.length() / pow(offset.normalized().dot(direction), 2)
				if score < best_score:
					best_score = score
					closest = other
			if closest.is_empty(): continue
			var property: String = {Vector2.UP: "focus_neighbor_top", Vector2.RIGHT: "focus_neighbor_right", Vector2.DOWN: "focus_neighbor_bottom", Vector2.LEFT: "focus_neighbor_left"}[direction]
			node.set(property, node.get_path_to(_skill_nodes[closest]))
	_update_skill_details()

func _select_skill(id: String) -> void:
	if id == _selected_skill and not _skill_details.is_empty(): return
	_selected_skill = id
	_update_skill_details()
	queue_redraw()

func _update_skill_details() -> void:
	if overlay != "tree" or game == null or _skill_learn == null: return
	for old in _skill_details:
		if not is_instance_valid(old): continue
		remove_child(old)
		old.queue_free()
	_skill_details.clear()
	var definition: Dictionary = SkillCatalog.NODES[_selected_skill]
	var owned: Array = game.store.data["skills"]
	_skill_detail_label(str(definition["branch"]).to_upper(), Rect2(616, 160, 246, 22), 13, GOLD)
	_skill_detail_label(definition["name"], Rect2(616, 184, 246, 52), 21, IVORY, true)
	var learned := _selected_skill in owned
	_skill_detail_label("APRENDIDA" if learned else "Custo: %d Fragmentos de Nous" % definition["cost"], Rect2(616, 238, 246, 22), 15, GOLD if learned else IVORY)
	_skill_detail_label(definition["description"], Rect2(616, 267, 246, 69), 15, IVORY)
	var required: Array = definition["requires"]
	_skill_detail_label("SEM PRÉ-REQUISITOS" if required.is_empty() else "REQUER", Rect2(616, 338, 246, 20), 12, MUTED)
	for index in range(required.size()):
		var id: String = required[index]
		var unlocked := id in owned
		_skill_detail_label(("✓ " if unlocked else "◇ ") + str(SkillCatalog.NODES[id]["name"]), Rect2(616, 357 + index * 18, 246, 20), 13, GOLD if unlocked else MUTED)
	var reason := SkillCatalog.blocker(game.store.data, _selected_skill)
	_skill_learn.disabled = not reason.is_empty()
	_skill_learn.text = "Aprendida" if learned else ("Aprender · %d Nous" % definition["cost"] if reason.is_empty() else ("Pré-requisitos pendentes" if not SkillCatalog.requires_met(owned, _selected_skill) else "Nous insuficiente"))
	_skill_learn.tooltip_text = reason

func _skill_detail_label(text: String, rect: Rect2, point_size: int, color: Color, serif: bool = false) -> void:
	_skill_details.append(_label(text, rect, point_size, color, serif))

func _learn_selected_skill() -> void:
	if not SkillCatalog.blocker(game.store.data, _selected_skill).is_empty(): return
	if game.buy_skill(_selected_skill):
		_build_controls()
		queue_redraw()

func _draw_skill_tree() -> void:
	var owned: Array = game.store.data["skills"]
	_text("%d Fragmentos de Nous" % game.store.data["fragments"], Vector2(85, 145), 16, GOLD)
	_text("%d / %d recordadas" % [owned.size(), SkillCatalog.ORDER.size()], Vector2(428, 145), 13, MUTED)
	_frame(Rect2(600, 150, 279, 312), true, .98)
	for id in SkillCatalog.ORDER:
		var point: Vector2 = SKILL_POINTS[id]
		for prerequisite in SkillCatalog.NODES[id]["requires"]:
			var from: Vector2 = SKILL_POINTS[prerequisite]
			var direction := (point - from).normalized()
			var color := GOLD if id in owned else (Color("729e9a") if prerequisite in owned else Color("384c4c"))
			draw_line(from + direction * 22, point - direction * 22, Color(color, .8), 1.5)
	for id in SkillCatalog.ORDER:
		var point: Vector2 = SKILL_POINTS[id]
		var learned: bool = id in owned
		var available := SkillCatalog.blocker(game.store.data, id).is_empty()
		var border := GOLD if learned else (Color("8fc6b1") if available else Color("58696a"))
		draw_circle(point, 19, Color("243a38") if learned else Color("102329"))
		draw_arc(point, 19, 0, TAU, 32, border, 1.5)
		if learned: _diamond(point + Vector2(0, -19), 3, GOLD, true)
		if id == _selected_skill:
			draw_arc(point, 24, 0, TAU, 32, IVORY, 1.3)
			_diamond(point + Vector2(-29, 0), 3, IVORY, true)
		_text(str(SkillCatalog.NODES[id]["cost"]), point + Vector2(24, 17), 12, border)
	for index in range(3):
		_text(["VONTADE", "MATÉRIA", "INTELECTO"][index], Vector2(113 + index * 180, 427), 13, GOLD)
	for index in range(3):
		draw_circle(Vector2(90 + index * 97, 447), 3, [GOLD, Color("8fc6b1"), Color("58696a")][index])
		_text(["Aprendida", "Disponível", "Bloqueada"][index], Vector2(99 + index * 97, 451), 12, MUTED)
	_text("Selecione um nó · Tab / setas para navegar", Vector2(86, 472), 12, MUTED)

func _back_button() -> void:
	_button("Voltar · Esc", Rect2(373, 445, 214, 35), _back, "back", "", true)

func _button(caption: String, rect: Rect2, callback: Callable, icon: String = "", description: String = "", centered: bool = false) -> Button:
	var button: Button = TitleMenuButton.new() if overlay in ["intro","new_journey"] else Button.new()
	if button is TitleMenuButton: button.ui_scale = _factor
	button.text = caption
	button.position = _offset + rect.position * _factor
	button.size = rect.size * _factor
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", title_font)
	button.add_theme_font_size_override("font_size", maxi(9, roundi((20 if overlay in ["pause", "intro", "new_journey"] else 17) * _factor)))
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color("7b8985"))
	button.add_theme_color_override("font_hover_color", Color("ffe6ac"))
	var path := "res://assets/ui/hud_" + icon + ".svg"
	if not icon.is_empty() and ResourceLoader.exists(path):
		button.icon = load(path) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", maxi(12, roundi(24 * _factor)))
		button.add_theme_constant_override("h_separation", roundi(16 * _factor))
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.08, .16, .17, .84) if style_name in ["hover", "pressed"] else Color(.035, .075, .09, .65)
		if overlay == "pause" and style_name == "normal": style.bg_color.a = 0
		style.border_color = GOLD if style_name in ["hover", "focus"] else Color(.55, .43, .25, .56)
		style.set_border_width_all(1 if overlay != "pause" or style_name != "normal" else 0)
		style.set_content_margin(SIDE_LEFT, (11 if centered else 17) * _factor)
		style.set_content_margin(SIDE_RIGHT, 10 * _factor)
		button.add_theme_stylebox_override(style_name, style)
	button.pressed.connect(callback)
	if not description.is_empty():
		var title := caption.to_upper()
		button.mouse_entered.connect(func(): _select_description(title, description))
		button.focus_entered.connect(func(): _select_description(title, description))
	add_child(button)
	_buttons.append(button)
	return button

func _label(text: String, rect: Rect2, point_size: int, color: Color = IVORY, serif: bool = false) -> Label:
	var label := Label.new()
	var chosen_font: Font = title_font if serif else font
	var actual_size := maxi(8, roundi(point_size * _factor))
	label.text = _wrapped_text(text, rect.size.x * _factor - 4, chosen_font, actual_size)
	label.position = _offset + rect.position * _factor
	label.size = rect.size * _factor
	label.clip_text = true
	label.add_theme_font_override("font", chosen_font)
	label.add_theme_font_size_override("font_size", actual_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _wrapped_text(text: String, width: float, chosen_font: Font, point_size: int) -> String:
	var lines := PackedStringArray()
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var proposed := word if line.is_empty() else line + " " + word
			if not line.is_empty() and chosen_font.get_string_size(proposed, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > width:
				lines.append(line)
				line = word
			else:
				line = proposed
		lines.append(line)
	return "\n".join(lines)

func _scroll_text(text: String, rect: Rect2, point_size: int) -> void:
	var scroll := ScrollContainer.new()
	scroll.position = _offset + rect.position * _factor
	scroll.size = rect.size * _factor
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var actual_size := maxi(8, roundi(point_size * _factor))
	var body := Label.new()
	body.text = _wrapped_text(text, (rect.size.x - 22) * _factor, font, actual_size)
	body.add_theme_font_override("font", font)
	body.add_theme_font_size_override("font_size", actual_size)
	body.add_theme_color_override("font_color", IVORY)
	body.custom_minimum_size = Vector2((rect.size.x - 22) * _factor, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

func _select_description(title: String, description: String) -> void:
	_selection_title = title
	_selection_description = description
	queue_redraw()

func _text(text: String, position: Vector2, point_size: int = 14, color: Color = IVORY, serif: bool = false) -> void:
	# Fonts rasterize at the final interface size, rather than scaling a tiny glyph.
	draw_set_transform(Vector2.ZERO)
	draw_string(title_font if serif else font, (_offset + position * _factor).round(), text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(12, roundi(point_size * _factor)), color)
	draw_set_transform(_offset, 0.0, Vector2.ONE * _factor)

func _fit_text(text: String, position: Vector2, width: float, point_size: int = 20, color: Color = IVORY, serif: bool = false) -> void:
	var chosen_font: Font = title_font if serif else font
	var actual := point_size
	while chosen_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, actual).x > width and actual > 14: actual -= 1
	_text(text, position, actual, color, serif)

func _text_block(text: String, position: Vector2, width: float, point_size: int, line_height: float, color: Color = IVORY, serif: bool = false, max_lines: int = 2) -> void:
	var chosen_font: Font = title_font if serif else font
	var lines := _wrapped_text(text, width, chosen_font, point_size).split("\n")
	for index in range(mini(max_lines, lines.size())):
		var line := lines[index]
		if index == max_lines - 1 and lines.size() > max_lines:
			while chosen_font.get_string_size(line + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x > width and not line.is_empty(): line = line.left(-1)
			line += "…"
		_text(line, position + Vector2(0, index * line_height), point_size, color, serif)

func _diamond(center: Vector2, radius: float, color: Color = GOLD, filled: bool = false) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if filled: draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, color, 1, true)

func _frame(rect: Rect2, filled: bool = true, opacity: float = .93) -> void:
	if filled: draw_rect(rect, Color(INK.r, INK.g, INK.b, opacity))
	draw_rect(rect, Color(GOLD.r, GOLD.g, GOLD.b, .8), false, 1)
	draw_rect(rect.grow(-7), Color(GOLD.r, GOLD.g, GOLD.b, .23), false, 1)
	for point in [rect.position + Vector2(6, 6), Vector2(rect.end.x - 6, rect.position.y + 6), rect.end - Vector2(6, 6), Vector2(rect.position.x + 6, rect.end.y - 6)]:
		_diamond(point, 3, GOLD)

func _sun(center: Vector2, radius: float, opacity: float = 1.0) -> void:
	var color := Color(GOLD.r, GOLD.g, GOLD.b, opacity)
	draw_arc(center, radius * .36, 0, TAU, 32, color, 1, true)
	for index in range(8):
		var direction := Vector2.RIGHT.rotated(index * TAU / 8)
		draw_line(center + direction * radius * .48, center + direction * radius, color, 1, true)
	_diamond(center, radius * 1.3, color)

func _draw() -> void:
	if game == null or game.player == null or font == null: return
	draw_set_transform(_offset, 0, Vector2.ONE * _factor)
	if overlay in ["intro", "new_journey"]:
		_draw_intro()
		return
	if overlay in BOOK_MODES: return
	_draw_gameplay()
	if overlay != "" and not _conversation_active: _draw_modal()

## Gameplay chrome stays open to the world: only small corner marks, a
## health ribbon and the current area. Objectives live in the notebook.
func _draw_gameplay() -> void:
	var hero = game.player
	var data: Dictionary = game.store.data
	for corner in [Vector2(14, 14), Vector2(946, 14), Vector2(14, 526), Vector2(946, 526)]:
		var inward := Vector2(1 if corner.x < 480 else -1, 1 if corner.y < 270 else -1)
		draw_line(corner, corner + Vector2(16 * inward.x, 0), Color(GOLD, .28), 1)
		draw_line(corner, corner + Vector2(0, 16 * inward.y), Color(GOLD, .28), 1)
	_hud_shade(Rect2(23, 24, 337, 80))
	_sun(Vector2(57, 60), 20)
	_text("SENU", Vector2(98, 40), 16, GOLD, true)
	_text("/  DISCÍPULO", Vector2(154, 39), 11, MUTED, true)
	_text("NV %d" % Economy.level(data), Vector2(319, 40), 12, IVORY, true)
	var health := clampf(float(hero.health) / maxf(1, hero.max_health), 0, 1)
	var track := Rect2(98, 50, 216, 8)
	_ribbon(track, Color("332b2b"))
	if health > 0:
		_ribbon(Rect2(track.position, Vector2(maxf(7, track.size.x * health), track.size.y)), Color("a84442"))
	draw_line(Vector2(315, 54), Vector2(340, 54), Color(GOLD, .35), 1)
	_diamond(Vector2(346, 54), 1.5)
	var progress := Economy.level_progress(Economy.xp(data))
	draw_rect(Rect2(99, 64, 206, 3), Color("253233"))
	draw_rect(Rect2(99, 64, 206 * clampf(float(progress.x) / maxf(1, progress.y), 0, 1), 3), Color("9ba995"))
	_text("%d / %d" % [hero.health, hero.max_health], Vector2(99, 85), 13, IVORY, true)
	draw_circle(Vector2(211, 81), 3.5, LOOT_COIN)
	_text(str(Economy.coins(data)), Vector2(220, 85), 11, MUTED)
	_diamond(Vector2(265, 81), 3)
	_text("%d NOUS" % data["fragments"], Vector2(276, 85), 11, GOLD)
	if _loot_time > 0 and overlay == "": _draw_loot_ticker()
	_draw_balm()
	_hud_shade(Rect2(650, 25, 285, 39))
	draw_line(Vector2(655, 25), Vector2(655, 36), Color(GOLD, .8), 1)
	_diamond(Vector2(655, 42), 4)
	_diamond(Vector2(655, 42), 1.5)
	draw_line(Vector2(655, 48), Vector2(655, 58), Color(GOLD, .8), 1)
	var area := "Porto dos Esquecidos"
	for room in PortLayout.ROOMS:
		if room["id"] == game.current_room: area = room["name"]
	var house_id := str(game.get("inside_house"))
	if HouseCatalog.HOUSES.has(house_id): area = HouseCatalog.HOUSES[house_id]["name"]
	if game.get("at_sea") == true or bool(game.get_meta("swimming", false)): area = "Baía das Garças"
	_text_block(area, Vector2(677, 43), 219, 16, 18, GOLD, true)
	var weapon = hero.equipped_weapon()
	_hud_shade(Rect2(28, 458, 273, 58))
	draw_line(Vector2(33, 459), Vector2(76, 459), Color(GOLD, .65), 1)
	draw_line(Vector2(33, 459), Vector2(33, 509), Color(GOLD, .65), 1)
	draw_line(Vector2(33, 509), Vector2(76, 509), Color(GOLD, .65), 1)
	_diamond(Vector2(28, 454), 2.5)
	if _weapon_icons.has(weapon.category): draw_texture_rect(_weapon_icons[weapon.category], Rect2(37, 464, 38, 38), false)
	_fit_text(weapon.display_name, Vector2(89, 477), 203, 14, IVORY, true)
	var ready: bool = hero.power_cooldown_remaining <= 0
	if "selo_mercurio" in data["skills"]:
		_text("Q  Pronto" if ready else "Q  %.1f s" % hero.power_cooldown_remaining, Vector2(89, 500), 11, IVORY if ready else MUTED)
		var seal_value: Variant = hero.get("seal_cooldown_remaining")
		var seal_cooldown := float(seal_value) if seal_value != null else 0.0
		_text("C  Pronto" if seal_cooldown <= 0 else "C  %.1f s" % seal_cooldown, Vector2(197, 500), 11, GOLD)
	else:
		_text("ADAGAS" if weapon.category == "leve" else "ESPADA", Vector2(89, 500), 10, GOLD, true)
		_text("Q  Pronto" if ready else "Q  %.1f s" % hero.power_cooldown_remaining, Vector2(215, 500), 11, IVORY if ready else MUTED)
	if game.nearest != null and is_instance_valid(game.nearest) and not game.respawning and overlay == "": _draw_interaction()
	if is_instance_valid(game.boss) and game.boss.health > 0 and overlay == "":
		var active: Variant=game.boss.get("encounter_active")
		if active==true or (active==null and hero.position.distance_to(game.boss.position)<240):
			var boss_name:="O PORTEIRO SEM NOME"
			var width:=font.get_string_size(boss_name,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
			_text(boss_name,Vector2(480-width*.5,427),15,GOLD)
			draw_rect(Rect2(239,435,482,11),Color("172124"))
			draw_rect(Rect2(240,436,480,9),Color("45312a"))
			var desperate: Variant=game.boss.get("phase")
			draw_rect(Rect2(241,437,478*float(game.boss.health)/maxf(1,game.boss.max_health),7),Color("ba8764") if desperate!=2 else Color("af775d"))
			draw_line(Vector2(240,435),Vector2(720,435),Color(GOLD,.55))
	if message_time > 0 and overlay == "":
		var toast_width := minf(690, font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40)
		var toast_rows := _wrapped_text(message, toast_width - 38, font, 16).split("\n").size()
		var rect := Rect2(480 - toast_width / 2, 145, toast_width, 36 if toast_rows == 1 else 54)
		_notice_panel(rect)
		_text_block(message, rect.position + Vector2(19, 24), rect.size.x - 38, 16, 21, message_color)

func _draw_interaction() -> void:
	var screen_point: Vector2 = game.call("world_to_ui", game.nearest.global_position) if game.has_method("world_to_ui") else game.nearest.get_global_transform_with_canvas().origin
	var point := (screen_point - _offset) / maxf(.01, _factor) + Vector2(24, -31)
	var caption: String = game.nearest.label
	var width := minf(330, font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 62)
	var rows := _wrapped_text(caption, width - 58, font, 16).split("\n").size()
	var height := 36.0 if rows == 1 else 57.0
	point.x = clampf(point.x, 34, 926 - width)
	point.y = clampf(point.y, 202, 411 - height)
	_notice_panel(Rect2(point, Vector2(width, height)))
	draw_line(point + Vector2(36, 5), point + Vector2(36, height - 5), GOLD.darkened(.35), 1)
	_text("E", point + Vector2(13, 25), 19, IVORY)
	_text_block(caption, point + Vector2(48, 24), width - 58, 16, 21, IVORY)

func _draw_intro() -> void:
	if _title_texture == null:
		draw_rect(Rect2(Vector2.ZERO, UI_SIZE), INK)
	elif not is_instance_valid(_title_backdrop):
		_cover(_title_texture, Rect2(Vector2.ZERO, UI_SIZE))
	for index in range(96):
		var alpha := .94 * pow(1.0 - float(index) / 96.0, 1.6)
		draw_rect(Rect2(index * 7, 0, 7, 540), Color(.018, .055, .068, alpha))
	_frame(Rect2(12, 12, 936, 516), false)
	_sun(Vector2(245, 162), 111, .16)
	_text("O NONO", Vector2(87, 158), 60, IVORY, true)
	_text("VÉU", Vector2(168, 219), 68, GOLD, true)
	draw_line(Vector2(105, 241), Vector2(405, 241), GOLD.darkened(.15), 1)
	_diamond(Vector2(255, 241), 5)
	_text("A memória é a última margem.", Vector2(104, 270), 18, MUTED, true)

func _draw_modal() -> void:
	draw_rect(Rect2(Vector2.ZERO, UI_SIZE), Color(.015, .03, .04, .77))
	_frame(Rect2(51, 44, 858, 451), true, .96)
	_sun(Vector2(480, 44), 22, .65)
	_sun(Vector2(480, 495), 22, .65)
	var titles := {"pause": "Uma pausa entre os véus", "tree": "Árvore das Emanações", "map": "Memórias do Porto", "journal": "Caderno de Missões · N", "inventory": "Inventário da travessia", "controls": "Controles", "settings": "Configurações", "dialog": dialog_title, "new_journey": "Uma nova travessia", "shop": dialog_title}
	_fit_text(titles.get(overlay, "O Nono Véu"), Vector2(83, 101), 780, 34, IVORY, true)
	draw_line(Vector2(84, 118), Vector2(414 if overlay == "pause" else 875, 118), GOLD.darkened(.28), 1)
	_diamond(Vector2(249 if overlay == "pause" else 480, 118), 4)
	match overlay:
		"pause":
			draw_line(Vector2(427, 139), Vector2(427, 471), GOLD.darkened(.5), 1)
			_sun(Vector2(665, 260), 115, .12)
			if _portrait_texture != null: _portrait(_portrait_texture, Rect2(451, 134, 424, 267))
			draw_line(Vector2(464, 405), Vector2(867, 405), GOLD.darkened(.55), 1)
			_fit_text(_selection_title, Vector2(466, 432), 380, 20, GOLD)
			_fit_text(_selection_description, Vector2(466, 458), 380, 15, MUTED)
		"tree":
			_draw_skill_tree()
		"map":
			_text("Lugares recordados, caminhos descobertos e selos da travessia.", Vector2(84, 143), 12, MUTED)
			_draw_map()
		"inventory":
			_text("O que foi encontrado permanece na memória.", Vector2(84, 143), 13, MUTED)
			for index in range(2): _frame(Rect2(86 + index * 404, 166, 384, 205), true, .7)
		"controls": _text("O mouse mira o cursor. ¹ Selo de Mercúrio: aprenda na Árvore das Emanações.", Vector2(99, 143), 12, MUTED)
		"shop": ShopPanel.draw(self, game)
		"dialog":
			var portrait := _find_npc_portrait(dialog_title)
			if portrait != null:
				var p_rect := Rect2(650, 140, 220, 260)
				_frame(p_rect, true, .85)
				var canvas := Vector2(160, 192)
				var factor := minf((p_rect.size.x - 20) / canvas.x, (p_rect.size.y - 20) / canvas.y)
				var fitted := canvas * factor
				var dest := Rect2(p_rect.get_center() - fitted * .5, fitted)
				var src := Rect2(Vector2.ZERO, canvas)
				draw_texture_rect_region(portrait, dest, src)
				draw_rect(p_rect, GOLD.darkened(.35), false, 1.0)

func _find_npc_portrait(title: String) -> Texture2D:
	var lower := title.to_lower()
	var path := ""
	if lower == "senu": path = "res://assets/ui/dialogue_v15/senu.png"
	elif "mendigo" in lower or "cordas" in lower or "alaúde" in lower or "alaude" in lower: path = "res://assets/ui/dialogue_v15/mendigo.png"
	elif "escriba" in lower: path = "res://assets/ui/dialogue_v15/escriba.png"
	elif "peixeira" in lower: path = "res://assets/ui/dialogue_v15/peixeira.png"
	elif "tamareiro" in lower or "tâmara" in lower: path = "res://assets/ui/dialogue_v15/tamareiro.png"
	elif "padeira" in lower or "pão" in lower: path = "res://assets/ui/dialogue_v15/padeira.png"
	elif "cervejeiro" in lower or "cerveja" in lower or "caravaneiro" in lower: path = "res://assets/ui/dialogue_v15/cervejeiro.png"
	elif "peregrina" in lower: path = "res://assets/ui/dialogue_v15/peregrina.png"
	elif "pescador" in lower or "sabu" in lower or "hori" in lower: path = "res://assets/ui/dialogue_v15/fisherman.png"
	elif "sacerdote" in lower: path = "res://assets/ui/dialogue_v15/sacerdote.png"
	elif "alquimista" in lower: path = "res://assets/ui/dialogue_v15/alquimista.png"
	elif "sentinela" in lower: path = "res://assets/ui/dialogue_v15/sentinela.png"
	elif "mercadora" in lower: path = "res://assets/ui/dialogue_v15/mercadora.png"
	elif "estivador" in lower: path = "res://assets/ui/dialogue_v15/estivador.png"
	elif "carregador" in lower: path = "res://assets/ui/dialogue_v15/carregador.png"
	elif "marinheiro" in lower: path = "res://assets/ui/dialogue_v15/marinheiro.png"
	elif "velho" in lower: path = "res://assets/ui/dialogue_v15/velho.png"
	elif "aguadeira" in lower: path = "res://assets/ui/dialogue_v15/aguadeira.png"
	elif "remador" in lower: path = "res://assets/ui/dialogue_v15/remador.png"
	if path != "" and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _cover(texture: Texture2D, rect: Rect2) -> void:
	var texture_size := texture.get_size()
	var ratio := maxf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	var source_size := rect.size / ratio
	draw_texture_rect_region(texture, rect, Rect2((texture_size - source_size) * .5, source_size))

func _contain(texture: Texture2D, rect: Rect2) -> void:
	var factor := minf(rect.size.x / texture.get_width(), rect.size.y / texture.get_height())
	var fitted := texture.get_size() * factor
	draw_texture_rect(texture, Rect2(rect.get_center() - fitted * .5, fitted), false)

func _portrait(texture: Texture2D, rect: Rect2) -> void:
	var canvas := Vector2(160, 192)
	var factor := minf(rect.size.x / canvas.x, rect.size.y / canvas.y)
	var fitted := canvas * factor
	var destination := Rect2(rect.get_center() - fitted * .5, fitted)
	if _portrait_idle_texture == null:
		draw_texture_rect_region(texture, destination, Rect2(Vector2.ZERO, texture.get_size()))
		return
	var cycle := fmod(_menu_clock, 5.2)
	var blink := mini(5, int((cycle - 4.7) / .05)) if cycle >= 4.7 and cycle < 5.0 else 0
	var ribbon := 6 + int(_menu_clock * 5.0) % 6
	for frame in [blink, ribbon]:
		var source := Rect2(Vector2(frame % 4, frame / 4) * canvas, canvas)
		draw_texture_rect_region(_portrait_idle_texture, destination, source)

func _inventory_controls() -> void:
	for index in range(game.player.weapons.size()):
		var weapon = game.player.weapons[index]
		var unlocked: bool = game.player.weapon_unlocked[index]
		var rect := Rect2(105 + index * 404, 181, 344, 40)
		_label(weapon.display_name if unlocked else "Memória ainda velada", rect, 22, GOLD, true)
		_label(weapon.description if unlocked else "Explore os desvios do Porto para encontrar outra arma.", Rect2(rect.position + Vector2(0, 53), Vector2(335, 75)), 17, MUTED)
		if unlocked:
			var weapon_index: int = index
			var button := _button("Equipada" if game.player.weapon_index == index else "Equipar", Rect2(rect.position + Vector2(0, 133), Vector2(335, 38)), func():
				if game.player.equip_weapon(weapon_index):
					game.store.data["equipped"] = DemoSaveStore.WEAPONS[weapon_index]
					game.call("_save")
				_build_controls(), "diamond", "", true)
			button.disabled = game.player.weapon_index == index
	_label("%d Fragmentos de Nous   ·   %d emanações recordadas   ·   nível %d   ·   %d %s" % [game.store.data["fragments"], game.store.data["skills"].size(), Economy.level(game.store.data), Economy.coins(game.store.data), Economy.CURRENCY], Rect2(104, 397, 740, 30), 17, GOLD)

func _map_legend() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = _offset + Vector2(688, 161) * _factor
	scroll.size = Vector2(190, 267) * _factor
	add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", roundi(9 * _factor))
	scroll.add_child(list)
	var number := 0
	for room in PortLayout.ROOMS:
		if room["id"] not in game.store.data["visited"]: continue
		number += 1
		var label := Label.new()
		label.text = "%02d  %s" % [number, room.get("label", room["name"])]
		label.add_theme_font_size_override("font_size", maxi(14, roundi(14 * _factor)))
		label.add_theme_color_override("font_color", GOLD if room["id"] == game.current_room else MUTED)
		label.custom_minimum_size.x = 171 * _factor
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		list.add_child(label)

func _draw_map() -> void:
	var chart := Rect2(80, 159, 583, 271)
	var revealed: Array[Dictionary] = []
	var hero_position := _map_hero()
	var bounds := Rect2(hero_position - Vector2.ONE, Vector2.ONE * 2)
	# Com o Mapa das rotas de Adiam, os setores ainda não visitados viram contornos.
	var hinted: Array[Dictionary] = []
	var routes := ShopCatalog.reveals_map(game.store.data)
	for room in PortLayout.ROOMS:
		if room["id"] not in game.store.data["visited"]:
			if routes and room["id"] not in ShopCatalog.MAP_HIDDEN:
				hinted.append(room)
				for corner in _map_room_shape(room): bounds = bounds.expand(corner)
			continue
		revealed.append(room)
		for corner in _map_room_shape(room): bounds = bounds.expand(corner)
	draw_rect(chart, Color("0d2027"))
	draw_rect(chart, GOLD.darkened(.67), false, 1)
	if revealed.is_empty():
		_text("Explore para recordar os caminhos.", chart.position + Vector2(100, 140), 18, MUTED, true)
		return
	var scale_factor := minf((chart.size.x - 32) / maxf(bounds.size.x, 1), (chart.size.y - 32) / maxf(bounds.size.y, 1))
	var origin := chart.get_center() - bounds.get_center() * scale_factor
	for room in hinted:
		var sketch := PackedVector2Array()
		for corner in _map_room_shape(room): sketch.append(origin + corner * scale_factor)
		sketch.append(sketch[0])
		draw_polyline(sketch, MUTED.darkened(.45), 1)
	var centers: Dictionary = {}
	for room in revealed:
		var rect: Rect2i = room["rect"]
		centers[room["id"]] = origin + PortLayout.iso(Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) / 2) * scale_factor
	for link in PortLayout.ROOM_LINKS:
		var required_flag: String = link[2] if link.size() > 2 else ""
		if required_flag != "" and not game.store.data["flags"].get(required_flag, false): continue
		if centers.has(link[0]) and centers.has(link[1]):
			draw_line(centers[link[0]], centers[link[1]], GOLD.darkened(.48) if required_flag != "" else MUTED.darkened(.55), 2)
	var number := 0
	for room in revealed:
		number += 1
		var outline := PackedVector2Array()
		for corner in _map_room_shape(room): outline.append(origin + corner * scale_factor)
		var current: bool = room["id"] == game.current_room
		draw_colored_polygon(outline, Color("496754") if current else Color("294244"))
		outline.append(outline[0])
		draw_polyline(outline, GOLD if current else MUTED.darkened(.35), 1)
		var center: Vector2 = centers[room["id"]]
		draw_circle(center, 9, Color("0c242a"))
		_text(str(number), center + Vector2(-4 if number < 10 else -7, 4), 11, GOLD if current else IVORY)
	var hero_marker: Vector2 = origin + hero_position * scale_factor
	_diamond(hero_marker, 5, Color("b9efd8"), true)
	_text("◆ Senu · ouro: área atual · role a legenda", Vector2(84, 440), 13, MUTED)

## O contorno de uma sala no mapa: o retângulo, ou o desenho próprio ("outline")
## de salas como a Ilha do Bennu, que segue a costa.
func _map_room_shape(room: Dictionary) -> PackedVector2Array:
	if not room.has("outline"): return _map_room_corners(room["rect"])
	var shape := PackedVector2Array()
	for point in room["outline"]: shape.append(PortLayout.iso(point))
	return shape

func _map_room_corners(rect: Rect2i) -> PackedVector2Array:
	var start := Vector2(rect.position) - Vector2(.5, .5)
	var finish := Vector2(rect.end) - Vector2(.5, .5)
	return PackedVector2Array([PortLayout.iso(start), PortLayout.iso(Vector2(finish.x, start.y)), PortLayout.iso(finish), PortLayout.iso(Vector2(start.x, finish.y))])

func _preferences_path() -> String:
	return "user://qa/ui_preferences.cfg" if game != null and bool(game.get("qa_mode")) else "user://ui_preferences.cfg"

func _read_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(_preferences_path()) == OK:
		# Chave nova: a antiga ("limit_fps") era gravada ligada junto com as outras
		# preferências, sem o jogador escolher, e prendia monitores rápidos em 60.
		_limit_fps = bool(config.get_value("display", "limit_fps_60", false))
	FramePacing.apply(_limit_fps)
	if DisplayServer.get_name() != "headless":
		if config.has_section_key("display", "fullscreen"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(config.get_value("display", "fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED)

func _write_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "limit_fps_60", _limit_fps)
	config.set_value("display", "fullscreen", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_preferences_path().get_base_dir()))
	config.save(_preferences_path())

func _toggle_fullscreen() -> void:
	if DisplayServer.get_name() != "headless":
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		_write_preferences()
	_build_controls()

# Economia de combate (Gustavo, 27/10/2026): XP, nível e óbolos no painel de Senu.
const Economy = preload("res://scripts/economy/economy.gd")
const LOOT_XP := Color("8fd6c2")
const LOOT_COIN := Color("d9a35c")
var _loot_xp := 0
var _loot_coins := 0
var _loot_time := 0.0

## Chamado por port_demo.collect_loot; as coletas seguidas se somam numa linha só.
func loot_gained(kind: String, amount: int) -> void:
	if _loot_time <= 0:
		_loot_xp = 0
		_loot_coins = 0
	if kind == "xp": _loot_xp += amount
	else: _loot_coins += amount
	_loot_time = 2.4

func _draw_loot_ticker() -> void:
	var fade := clampf(_loot_time / .6, 0, 1)
	var x := 101.0
	if _loot_xp > 0:
		var gained := "+%d XP" % _loot_xp
		_text(gained, Vector2(x, 125), 14, Color(LOOT_XP, fade))
		x += font.get_string_size(gained, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 18
	if _loot_coins > 0:
		_text("+%d %s" % [_loot_coins, Economy.CURRENCY], Vector2(x, 125), 14, Color(LOOT_COIN, fade))

# Casas (Gustavo, 27/10/2026): nome da casa no painel e Senu na porta, no mapa.
const HouseCatalog = preload("res://scripts/world/house_catalog.gd")

func _map_hero() -> Vector2:
	return game.call("map_position") if game.has_method("map_position") else game.player.position

# Loja e bálsamo (Gustavo, 27/10/2026): painel em scripts/ui/shop_panel.gd.
const ShopPanel = preload("res://scripts/ui/shop_panel.gd")
const ShopCatalog = preload("res://scripts/economy/shop_catalog.gd")
var shop_id := ""
var shop_greeting := ""

## Abre a loja de um lojista; Esc e "Voltar" devolvem ao jogo.
func show_shop(title: String, id: String, greeting: String) -> void:
	dialog_title = title
	shop_id = id
	shop_greeting = greeting
	_return_overlay = ""
	show_overlay("shop")

## Cargas de bálsamo acima do painel da arma, só depois do primeiro jarro.
func _draw_balm() -> void:
	var room := ShopCatalog.capacity(game.store.data, "balsamo")
	if room <= 0: return
	var full := ShopCatalog.charges(game.store.data, "balsamo")
	_hud_shade(Rect2(30, 420, 34 + room * 18, 30))
	for slot in range(room):
		var center := Vector2(40 + slot * 18, 439)
		var tint := Color("b47a4a") if slot < full else Color("2b3a38")
		draw_circle(center, 6, tint.darkened(.35))
		draw_circle(center, 4.5, tint)
		draw_rect(Rect2(center + Vector2(-2, -11), Vector2(4, 5)), tint.darkened(.2))
	_text("R", Vector2(36 + room * 18, 444), 15, IVORY)

## A faint feathered wash keeps text readable over bright floor tiles, with no
## boxed panels or nested gold borders on the playfield.
func _hud_shade(rect: Rect2) -> void:
	for ring in range(8, -1, -1):
		draw_rect(rect.grow(ring * 1.5), Color(INK, .025))

func _ribbon(rect: Rect2, color: Color) -> void:
	var p := rect.position
	var e := rect.end
	var cut := minf(4, rect.size.x * .5)
	draw_colored_polygon(PackedVector2Array([p + Vector2(cut, 0), Vector2(e.x - cut, p.y), Vector2(e.x, p.y + rect.size.y * .5), e - Vector2(cut, 0), Vector2(p.x + cut, e.y), Vector2(p.x, p.y + rect.size.y * .5)]), color)

func _notice_panel(rect: Rect2) -> void:
	draw_rect(rect, Color(INK, .92))
	draw_rect(rect, Color(GOLD, .38), false, 1)
	draw_line(rect.position + Vector2(1, 4), Vector2(rect.position.x + 1, rect.end.y - 4), GOLD, 1)
