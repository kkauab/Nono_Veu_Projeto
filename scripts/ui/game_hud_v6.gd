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
var game: Node2D
var overlay := ""
var message := ""
var message_color := GOLD
var message_time := 0.0
var dialog_title := ""
var dialog_body := ""
var font: Font
var title_font: SystemFont
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
var _hint_controls := false
var _limit_fps := true
var _buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var readable := SystemFont.new()
	readable.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "sans-serif"])
	font = readable
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
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
	_title_backdrop.visible = overlay == "intro" and _title_texture != null
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
	elif overlay in ["", "tree", "map"] and event.is_action_pressed("skill_tree"):
		show_overlay("" if overlay == "tree" else "tree")
		get_viewport().set_input_as_handled()
	elif overlay in ["", "tree", "map"] and event.is_action_pressed("world_map"):
		show_overlay("" if overlay == "map" else "map")
		get_viewport().set_input_as_handled()

func toast(text: String, color: Color = GOLD, duration: float = 3.8) -> void:
	message = text
	message_color = color
	message_time = duration

func show_dialog(title: String, body: String) -> void:
	dialog_title = title
	dialog_body = body
	_return_overlay = ""
	show_overlay("dialog")

func show_overlay(mode: String) -> void:
	if mode in ["tree", "map", "inventory", "controls", "settings"] and overlay in ["pause", "intro", ""]:
		_return_overlay = overlay
	if mode == "new_journey": _return_overlay = "intro"
	overlay = mode
	get_tree().paused = mode != ""
	mouse_filter = Control.MOUSE_FILTER_STOP if mode != "" else Control.MOUSE_FILTER_IGNORE
	_geometry()
	_build_controls()
	queue_redraw()

func _back() -> void:
	if overlay == "intro": return
	show_overlay("" if overlay == "pause" else _return_overlay)

func _build_controls() -> void:
	_buttons.clear()
	for child in get_children():
		if child == _title_backdrop: continue
		remove_child(child)
		child.queue_free()
	if game == null: return
	match overlay:
		"intro":
			_button("Nova jornada", Rect2(104, 294, 302, 44), func():
				if game.store.loaded_existing or bool(game.store.data["flags"].get("opening_seen", false)): show_overlay("new_journey")
				else: game.start_journey(), "diamond", "", true)
			var resume := _button("Retomar jornada", Rect2(104, 347, 302, 42), game.start_journey, "diamond", "", true)
			resume.disabled = not game.store.loaded_existing
			_button("Configurações", Rect2(104, 399, 302, 42), func(): show_overlay("settings"), "diamond", "", true)
			_button("Sair", Rect2(104, 451, 302, 42), game.save_and_quit, "diamond", "", true)
		"new_journey":
			_label("Uma cópia da jornada atual será preservada antes de começar.\nSenu voltará ao santuário e redescobrirá os caminhos do Porto.", Rect2(112, 205, 706, 100), 19, MUTED)
			_button("Iniciar nova jornada", Rect2(112, 370, 350, 46), game.begin_new_journey, "continue")
			_button("Voltar", Rect2(492, 370, 326, 46), func(): show_overlay("intro"), "back")
		"pause":
			var options := [
				["Continuar", "continue", "Retome a travessia entre as memórias do Porto.", func(): show_overlay("")],
				["Árvore das Emanações", "tree", "Transforme Fragmentos de Nous em novas capacidades.", func(): show_overlay("tree")],
				["Mapa", "map", "Consulte os lugares recordados e os atalhos abertos.", func(): show_overlay("map")],
				["Inventário", "inventory", "Examine suas armas e o que a jornada já revelou.", func(): show_overlay("inventory")],
				["Controles", "controls", "Veja os comandos e atalhos do jogo.", func(): show_overlay("controls")],
				["Configurações", "settings", "Ajuste a janela, os quadros e a ajuda de comandos.", func(): show_overlay("settings")],
				["Salvar e sair", "exit", "Ancore a memória e encerre a jornada por agora.", game.save_and_quit]
			]
			for index in range(options.size()):
				var option: Array = options[index]
				_button(option[0], Rect2(79, 142 + index * 44, 327, 40), option[3], option[1], option[2])
		"tree":
			var index := 0
			for id in DemoSaveStore.SKILLS:
				var definition: Dictionary = DemoSaveStore.SKILLS[id]
				var learned: bool = id in game.store.data["skills"]
				var available: bool = game.store.data["fragments"] >= definition["cost"]
				var skill_id: String = id
				_label(definition["description"], Rect2(98 + index * 270, 256, 210, 75), 18, MUTED)
				var button := _button("Aprendido" if learned else "Desbloquear · %d Nous" % definition["cost"], Rect2(91 + index * 270, 354, 238, 42), func():
					game.buy_skill(skill_id)
					_build_controls(), "tree", "", true)
				button.disabled = learned or not available
				index += 1
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
				["T", "Árvore das Emanações"], ["M", "Mapa"], ["Esc", "Pausa / voltar"], ["R", "Usar bálsamo"]]
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
				if DisplayServer.get_name() != "headless": Engine.max_fps = 60 if _limit_fps else 0
				_write_preferences()
				_build_controls(), "settings")
			_button("Lembrete de comandos: " + ("visível" if _hint_controls else "oculto"), Rect2(112, 283, 660, 47), func():
				_hint_controls = not _hint_controls
				_write_preferences()
				_build_controls(), "controls")
			_label("As alterações são salvas neste computador.\nOs menus aceitam mouse, setas, Tab e Enter.", Rect2(112, 350, 700, 60), 17, MUTED)
			_back_button()
		"dialog":
			_scroll_text(dialog_body, Rect2(100, 156, 760, 250), 19)
			_back_button()
		"shop":
			ShopPanel.build(self, game)
			_back_button()
	if not _buttons.is_empty():
		for button in _buttons:
			if not button.disabled:
				_focus_button.call_deferred(button)
				break

func _focus_button(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree() and button.get_parent() == self:
		button.grab_focus()

func _back_button() -> void:
	_button("Voltar · Esc", Rect2(373, 445, 214, 35), _back, "back", "", true)

func _button(caption: String, rect: Rect2, callback: Callable, icon: String = "", description: String = "", centered: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = _offset + rect.position * _factor
	button.size = rect.size * _factor
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", title_font)
	button.add_theme_font_size_override("font_size", maxi(9, roundi((20 if overlay in ["pause", "intro"] else 17) * _factor)))
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
	if overlay == "intro":
		_draw_intro()
		return
	_draw_gameplay()
	if overlay != "": _draw_modal()

func _draw_gameplay() -> void:
	var hero = game.player
	_frame(Rect2(11, 10, 938, 520), false)
	var data: Dictionary = game.store.data
	_frame(Rect2(22, 22, 360, 82), true, .94)
	_sun(Vector2(62, 62), 20)
	_text("SENU / DISCÍPULO", Vector2(101, 45), 15, GOLD)
	_text("NV %d" % Economy.level(data), Vector2(322, 45), 14, IVORY)
	draw_rect(Rect2(101, 53, 259, 9), Color("2d423c"))
	draw_rect(Rect2(101, 53, 259 * clampf(float(hero.health) / maxf(1, hero.max_health), 0, 1), 9), Color("9bc9ae"))
	# Barra fina de XP: o que já foi juntado dentro do nível atual.
	var progress := Economy.level_progress(Economy.xp(data))
	draw_rect(Rect2(101, 65, 259, 4), Color("22343a"))
	draw_rect(Rect2(101, 65, 259 * clampf(float(progress.x) / maxf(1, progress.y), 0, 1), 4), LOOT_XP)
	_text("%d / %d" % [hero.health, hero.max_health], Vector2(101, 92), 16, IVORY)
	draw_circle(Vector2(200, 86), 5, LOOT_COIN.darkened(.35))
	draw_circle(Vector2(200, 86), 3.5, LOOT_COIN)
	_text("%d" % Economy.coins(data), Vector2(210, 92), 15, LOOT_COIN)
	_diamond(Vector2(266, 86), 4)
	_text("%d NOUS" % data["fragments"], Vector2(280, 92), 15, GOLD)
	if _loot_time > 0 and overlay == "": _draw_loot_ticker()
	_draw_balm()
	_frame(Rect2(615, 22, 323, 112), true, .96)
	var area := "Porto dos Esquecidos"
	for room in PortLayout.ROOMS:
		if room["id"] == game.current_room: area = room["name"]
	var house_id := str(game.get("inside_house"))
	if HouseCatalog.HOUSES.has(house_id): area = HouseCatalog.HOUSES[house_id]["name"]
	_text_block(area, Vector2(634, 48), 240, 19, 21, IVORY, true)
	if game.has_method("seals_found"):
		_diamond(Vector2(884, 42), 4)
		_text("%d/3" % int(game.call("seals_found")), Vector2(895, 47), 13, GOLD)
	draw_line(Vector2(634, 77), Vector2(918, 77), Color(GOLD, .42), 1)
	var objective: String = game.objective()
	if objective.begins_with("Selos ") and " · " in objective: objective = objective.split(" · ", false, 1)[1]
	_text_block(objective, Vector2(634, 98), 284, 14, 18, IVORY)
	var weapon = hero.equipped_weapon()
	_frame(Rect2(24, 449, 294, 70), true, .96)
	draw_rect(Rect2(35, 459, 50, 50), Color("13282c"))
	draw_rect(Rect2(35, 459, 50, 50), GOLD.darkened(.4), false, 1)
	if _weapon_icons.has(weapon.category): draw_texture_rect(_weapon_icons[weapon.category], Rect2(39, 463, 42, 42), false)
	_fit_text(weapon.display_name, Vector2(97, 476), 203, 17, IVORY)
	_text("ADAGAS" if weapon.category == "leve" else "ESPADA", Vector2(97, 500), 13, GOLD)
	_text("Q · pronto" if hero.power_cooldown_remaining <= 0 else "Q · %.1f s" % hero.power_cooldown_remaining, Vector2(214, 500), 14, IVORY)
	if _hint_controls: _text("WASD mover · Shift correr · Espaço rolar · J/F atacar · E interagir", Vector2(333, 512), 14, IVORY)
	if game.nearest != null and is_instance_valid(game.nearest) and not game.respawning and overlay == "": _draw_interaction()
	if is_instance_valid(game.boss) and game.boss.health > 0 and hero.position.distance_to(game.boss.position) < 240 and overlay == "":
		_text("O PORTEIRO SEM NOME", Vector2(430, 426), 16, GOLD)
		draw_rect(Rect2(349, 438, 480, 7), Color("45312a"))
		draw_rect(Rect2(349, 438, 480 * float(game.boss.health) / maxf(1, game.boss.max_health), 7), Color("bb8062"))
	if message_time > 0 and overlay == "":
		var toast_width := minf(690, font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 40)
		var toast_rows := _wrapped_text(message, toast_width - 38, font, 16).split("\n").size()
		var rect := Rect2(480 - toast_width / 2, 145, toast_width, 36 if toast_rows == 1 else 54)
		_frame(rect, true, .97)
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
	_frame(Rect2(point, Vector2(width, height)), true, .97)
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
	var titles := {"pause": "Uma pausa entre os véus", "tree": "Árvore das Emanações", "map": "Memórias do Porto", "inventory": "Inventário da travessia", "controls": "Controles", "settings": "Configurações", "dialog": dialog_title, "new_journey": "Uma nova travessia", "shop": dialog_title}
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
			_text("%d Fragmentos de Nous · escolha o que recordar" % game.store.data["fragments"], Vector2(85, 145), 14, GOLD)
			for index in range(DemoSaveStore.SKILLS.size()):
				var definition: Dictionary = DemoSaveStore.SKILLS[DemoSaveStore.SKILLS.keys()[index]]
				var x := 81 + index * 270
				_frame(Rect2(x, 174, 258, 234), true, .65)
				_text(definition["branch"].to_upper(), Vector2(x + 18, 201), 12, GOLD)
				_fit_text(definition["name"], Vector2(x + 18, 236), 221, 21, IVORY, true)
		"map":
			_text("Lugares recordados, caminhos descobertos e selos da travessia.", Vector2(84, 143), 12, MUTED)
			_draw_map()
		"inventory":
			_text("O que foi encontrado permanece na memória.", Vector2(84, 143), 13, MUTED)
			for index in range(2): _frame(Rect2(86 + index * 404, 166, 384, 205), true, .7)
		"controls": _text("Pelo teclado, os golpes seguem a última direção. Com o mouse, miram o cursor.", Vector2(99, 425), 13, MUTED)
		"new_journey": _text("Sua travessia anterior ficará arquivada neste computador.", Vector2(112, 329), 14, GOLD)
		"shop": ShopPanel.draw(self, game)

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
				for corner in _map_room_corners(room["rect"]): bounds = bounds.expand(corner)
			continue
		revealed.append(room)
		for corner in _map_room_corners(room["rect"]): bounds = bounds.expand(corner)
	draw_rect(chart, Color("0d2027"))
	draw_rect(chart, GOLD.darkened(.67), false, 1)
	if revealed.is_empty():
		_text("Explore para recordar os caminhos.", chart.position + Vector2(100, 140), 18, MUTED, true)
		return
	var scale_factor := minf((chart.size.x - 32) / maxf(bounds.size.x, 1), (chart.size.y - 32) / maxf(bounds.size.y, 1))
	var origin := chart.get_center() - bounds.get_center() * scale_factor
	for room in hinted:
		var sketch := PackedVector2Array()
		for corner in _map_room_corners(room["rect"]): sketch.append(origin + corner * scale_factor)
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
		for corner in _map_room_corners(room["rect"]): outline.append(origin + corner * scale_factor)
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

func _map_room_corners(rect: Rect2i) -> PackedVector2Array:
	var start := Vector2(rect.position) - Vector2(.5, .5)
	var finish := Vector2(rect.end) - Vector2(.5, .5)
	return PackedVector2Array([PortLayout.iso(start), PortLayout.iso(Vector2(finish.x, start.y)), PortLayout.iso(finish), PortLayout.iso(Vector2(start.x, finish.y))])

func _preferences_path() -> String:
	return "user://qa/ui_preferences.cfg" if game != null and bool(game.get("qa_mode")) else "user://ui_preferences.cfg"

func _read_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(_preferences_path()) == OK:
		_hint_controls = bool(config.get_value("interface", "control_hints", false))
		_limit_fps = bool(config.get_value("display", "limit_fps", true))
	if DisplayServer.get_name() != "headless":
		Engine.max_fps = 60 if _limit_fps else 0
		if config.has_section_key("display", "fullscreen"):
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(config.get_value("display", "fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED)

func _write_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("interface", "control_hints", _hint_controls)
	config.set_value("display", "limit_fps", _limit_fps)
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
	_frame(Rect2(24, 404, 46 + room * 18, 38), true, .94)
	for slot in range(room):
		var center := Vector2(44 + slot * 18, 426)
		var tint := Color("b47a4a") if slot < full else Color("2b3a38")
		draw_circle(center, 6, tint.darkened(.35))
		draw_circle(center, 4.5, tint)
		draw_rect(Rect2(center + Vector2(-2, -11), Vector2(4, 5)), tint.darkened(.2))
	_text("R", Vector2(38 + room * 18, 431), 15, IVORY)
