extends Control

const INK := Color("0e1820")
const GOLD := Color("d6bd87")
const IVORY := Color("eee4d0")
const MUTED := Color("99aaa4")
var game: Node2D
var overlay := ""
var message := ""
var message_color := GOLD
var message_time := 0.0
var dialog_title := ""
var dialog_body := ""
var font: Font
var title_font: SystemFont

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	title_font = SystemFont.new()
	title_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])

func _process(delta: float) -> void:
	message_time = maxf(0, message_time - delta)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause_game"):
		show_overlay("intro" if overlay == "new_journey" else ("pause" if overlay == "" else ""))
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
	show_overlay("dialog")

func show_overlay(mode: String) -> void:
	overlay = mode
	get_tree().paused = mode != ""
	mouse_filter = Control.MOUSE_FILTER_STOP if mode != "" else Control.MOUSE_FILTER_IGNORE
	for child in get_children():
		remove_child(child)
		child.queue_free()
	match mode:
		"intro":
			_button("Retomar jornada" if game.store.loaded_existing else "Iniciar jornada", Rect2(48, 244, 180, 34), game.start_journey)
			if game.store.loaded_existing:
				_button("Nova jornada", Rect2(240, 244, 160, 34), func(): show_overlay("new_journey"))
		"new_journey":
			_button("Iniciar nova jornada", Rect2(56, 244, 238, 34), game.begin_new_journey)
			_button("Voltar", Rect2(310, 244, 182, 34), func(): show_overlay("intro"))
		"pause":
			_button("Continuar", Rect2(56, 239, 158, 31), func(): show_overlay(""))
			_button("Árvore · T", Rect2(228, 239, 158, 31), func(): show_overlay("tree"))
			_button("Salvar e sair", Rect2(400, 239, 180, 31), game.save_and_quit)
		"tree":
			var index := 0
			for id in DemoSaveStore.SKILLS:
				var definition: Dictionary = DemoSaveStore.SKILLS[id]
				var learned: bool = id in game.store.data["skills"]
				var available: bool = game.store.data["fragments"] >= definition["cost"]
				var caption := "Aprendido" if learned else "Desbloquear · %d Nous" % definition["cost"]
				var skill_id: String = id
				var button := _button(caption, Rect2(46 + index * 186, 228, 174, 28), func():
					game.buy_skill(skill_id)
					show_overlay("tree"))
				button.disabled = learned or not available
				index += 1
			_button("Voltar · T / Esc", Rect2(231, 284, 178, 27), func(): show_overlay(""))
		"map", "dialog":
			if mode == "dialog":
				var label := Label.new()
				label.position = Vector2(52, 110)
				label.size = Vector2(536, 142)
				label.text = dialog_body
				label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				label.add_theme_font_size_override("font_size", 13)
				label.add_theme_color_override("font_color", IVORY)
				add_child(label)
			_button("Voltar · Esc", Rect2(231, 284, 178, 27), func(): show_overlay(""))
	queue_redraw()

func _button(caption: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	for style_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("26382f") if style_name == "hover" else Color("19282b")
		if style_name == "disabled":
			style.bg_color = Color("172126")
		style.border_color = GOLD.darkened(.5) if style_name != "focus" else GOLD
		style.set_border_width_all(1)
		style.set_content_margin_all(5)
		button.add_theme_stylebox_override(style_name, style)
	button.pressed.connect(callback)
	add_child(button)
	return button

func _text(text: String, position: Vector2, font_size: int = 12, color: Color = IVORY, serif: bool = false) -> void:
	draw_string(title_font if serif else font, position, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if game == null or game.player == null or font == null:
		return
	var hero = game.player
	draw_rect(Rect2(0, 0, 640, 66), Color(.035, .065, .08, .86))
	draw_line(Vector2(20, 65), Vector2(620, 65), Color(.5, .48, .35, .4), 1)
	_text("S E N U  /  D I S C Í P U L O", Vector2(22, 18), 8, GOLD)
	draw_rect(Rect2(22, 26, 136, 5), Color("35413e"))
	draw_rect(Rect2(22, 26, 136.0 * hero.health / hero.max_health, 5), Color("91baa4"))
	_text("%d / %d" % [hero.health, hero.max_health], Vector2(22, 44), 9, MUTED)
	_text("%d NOUS" % game.store.data["fragments"], Vector2(100, 44), 9, GOLD)
	var area := "Porto dos Esquecidos"
	for room in PortLayout.ROOMS:
		if room["id"] == game.current_room:
			area = room["name"]
	var width := title_font.get_string_size(area, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	_text("I  /  O DESPERTAR DO DISCÍPULO", Vector2(389, 19), 8, GOLD)
	_text(area, Vector2(620 - width, 39), 13, IVORY, true)
	var objective: String = game.objective()
	_text(objective, Vector2(620 - font.get_string_size(objective, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x, 55), 9, MUTED)
	draw_rect(Rect2(0, 324, 640, 36), Color(.035, .065, .08, .94))
	draw_line(Vector2(20, 324), Vector2(620, 324), Color(.5, .48, .35, .4), 1)
	var weapon = hero.equipped_weapon()
	_text(weapon.display_name, Vector2(22, 340), 11, GOLD)
	var power := "Q · poder pronto" if hero.power_cooldown_remaining <= 0 else "Q · %.1fs" % hero.power_cooldown_remaining
	_text(weapon.category.to_upper() + "  /  " + power, Vector2(22, 353), 8, MUTED)
	_text("WASD andar  Shift correr  J ataque  F forte  Espaço rolar  K parry", Vector2(245, 339), 8, IVORY)
	_text("E interagir    Q poder    Tab arma    T árvore    M mapa    Esc ajuda", Vector2(245, 352), 8, MUTED)
	if game.nearest != null and is_instance_valid(game.nearest) and not game.respawning and overlay == "":
		var prompt: String = "[E]  " + game.nearest.label
		var prompt_width := font.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_rect(Rect2(314 - prompt_width / 2, 298, prompt_width + 12, 19), Color(.05, .1, .12, .94))
		_text(prompt, Vector2(320 - prompt_width / 2, 311), 10, GOLD)
	if is_instance_valid(game.boss) and game.boss.health > 0 and hero.position.distance_to(game.boss.position) < 200 and overlay == "":
		_text("O PORTEIRO SEM NOME", Vector2(246, 270), 9, GOLD)
		draw_rect(Rect2(200, 277, 240, 4), Color("423330"))
		draw_rect(Rect2(200, 277, 240.0 * game.boss.health / game.boss.max_health, 4), Color("bf8065"))
	if message_time > 0 and overlay == "":
		var toast_width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_rect(Rect2(314 - toast_width / 2, 73, toast_width + 12, 20), Color(.04, .08, .1, .90))
		_text(message, Vector2(320 - toast_width / 2, 87), 10, message_color)
	if overlay != "":
		_draw_modal()

func _draw_modal() -> void:
	draw_rect(Rect2(0, 0, 640, 360), Color(.02, .035, .05, .85))
	draw_rect(Rect2(28, 24, 584, 306), INK)
	draw_rect(Rect2(28, 24, 584, 306), Color("6d6951"), false, 1)
	for corner in [Vector2(36, 32), Vector2(604, 32), Vector2(36, 322), Vector2(604, 322)]:
		draw_circle(corner, 2, GOLD)
	match overlay:
		"intro":
			_text("CAPÍTULO I  /  ALEXANDRIA", Vector2(48, 57), 9, GOLD)
			_text("O NONO", Vector2(45, 121), 43, IVORY, true)
			_text("VÉU", Vector2(45, 171), 48, GOLD, true)
			draw_line(Vector2(50, 188), Vector2(226, 188), GOLD.darkened(.55), 1)
			_text("A memória é a última margem.", Vector2(48, 213), 12, MUTED, true)
			_text("PORTO DOS ESQUECIDOS", Vector2(326, 108), 13, GOLD, true)
			_text("Procure o que resta dos nomes.", Vector2(326, 139), 12)
			_text("Encontre a guarita. Abra o retorno.", Vector2(326, 161), 12)
			_text("Enfrente aquele que guarda o eco.", Vector2(326, 183), 12)
			_text("Primeira demonstração · arte provisória original", Vector2(48, 305), 9, MUTED)
		"new_journey":
			_text("Uma nova travessia", Vector2(54, 82), 25, IVORY, true)
			_text("Uma cópia da jornada atual será preservada.", Vector2(56, 129), 13)
			_text("Senu voltará ao santuário, com o progresso da nova", Vector2(56, 158), 13)
			_text("travessia começando do início no Porto ampliado.", Vector2(56, 180), 13)
			_text("Você poderá continuar explorando o mapa e descobrir os dois atalhos.", Vector2(56, 213), 10, MUTED)
		"pause":
			_text("Uma pausa entre os véus", Vector2(54, 78), 25, IVORY, true)
			_text("WASD / setas   Andar      Shift   Correr", Vector2(56, 114), 12)
			_text("J / mouse esquerdo   Ataque      F   Golpe forte", Vector2(56, 138), 12)
			_text("Espaço   Esquiva      K / mouse direito   Parry", Vector2(56, 162), 12)
			_text("Q   Poder da arma      Tab   Trocar arma      E   Interagir", Vector2(56, 186), 12)
			_text("T   Árvore das Emanações      M   Mapa descoberto", Vector2(56, 210), 12)
			_text("Autosave em descobertas. Ao reabrir, você retorna ao último santuário.", Vector2(56, 302), 9, MUTED)
		"tree":
			_text("Árvore das Emanações", Vector2(46, 66), 24, IVORY, true)
			_text("%d Fragmentos de Nous · aprimoramentos opcionais" % game.store.data["fragments"], Vector2(46, 89), 11, GOLD)
			for branch_x in [133.0, 319.0, 505.0]:
				draw_line(Vector2(320, 102), Vector2(branch_x, 111), GOLD.darkened(.55), 1)
			draw_colored_polygon(PackedVector2Array([Vector2(320, 96), Vector2(324, 102), Vector2(320, 108), Vector2(316, 102)]), GOLD)
			var index := 0
			var descriptions := ["Golpes causam\n+4 de dano.", "Vida máxima\n100 → 120.", "Poder da arma recarrega\n20% mais rápido."]
			for id in DemoSaveStore.SKILLS:
				var x := 46 + index * 186
				var definition: Dictionary = DemoSaveStore.SKILLS[id]
				draw_rect(Rect2(x, 111, 174, 153), Color("17282a"))
				draw_line(Vector2(x + 12, 149), Vector2(x + 162, 149), GOLD.darkened(.6), 1)
				_text(definition["branch"].to_upper(), Vector2(x + 12, 131), 9, GOLD)
				_text(definition["name"], Vector2(x + 12, 169), 12, IVORY, true)
				var line := 0
				for part in descriptions[index].split("\n"):
					_text(part, Vector2(x + 12, 192 + line * 15), 10, MUTED)
					line += 1
				index += 1
		"map":
			_text("Memórias do Porto", Vector2(46, 63), 24, IVORY, true)
			_text("Só os lugares visitados e os caminhos descobertos são revelados.", Vector2(46, 85), 10, MUTED)
			_draw_map()
		"dialog":
			_text(dialog_title, Vector2(52, 80), 23, GOLD, true)

func _draw_map() -> void:
	var visited: Array = game.store.data["visited"]
	var chart := Rect2(49, 105, 334, 151)
	var revealed: Array[Dictionary] = []
	var bounds := Rect2(game.player.position - Vector2.ONE, Vector2.ONE * 2.0)
	for room in PortLayout.ROOMS:
		if room["id"] not in visited:
			continue
		revealed.append(room)
		for corner in _map_room_corners(room["rect"]):
			bounds = bounds.expand(corner)
	if revealed.is_empty():
		_text("Explore para recordar os caminhos.", chart.position + Vector2(18, 80), 10, MUTED)
		return
	var scale_factor := minf((chart.size.x - 24.0) / maxf(bounds.size.x, 1.0), (chart.size.y - 24.0) / maxf(bounds.size.y, 1.0))
	var origin := chart.get_center() - bounds.get_center() * scale_factor
	draw_rect(chart, Color("101f27"))
	draw_rect(chart, Color("31413d"), false, 1)
	var centers: Dictionary = {}
	for room in revealed:
		var rect: Rect2i = room["rect"]
		centers[room["id"]] = origin + PortLayout.iso(Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) / 2.0) * scale_factor
	for link in PortLayout.ROOM_LINKS:
		var required_flag: String = link[2] if link.size() > 2 else ""
		if required_flag != "" and not game.store.data["flags"].get(required_flag, false):
			continue
		if centers.has(link[0]) and centers.has(link[1]):
			draw_line(centers[link[0]], centers[link[1]], GOLD.darkened(.55) if required_flag != "" else MUTED.darkened(.60), 2)
	var number := 0
	for room in revealed:
		number += 1
		var id: String = room["id"]
		var outline := PackedVector2Array()
		for corner in _map_room_corners(room["rect"]):
			outline.append(origin + corner * scale_factor)
		var current: bool = id == game.current_room
		draw_colored_polygon(outline, Color("426052") if current else Color("263d3c"))
		outline.append(outline[0])
		draw_polyline(outline, GOLD.darkened(.1) if current else MUTED.darkened(.45), 1)
		var center: Vector2 = centers[id]
		draw_circle(center, 6, Color("14272b"))
		_text(str(number), center + Vector2(-3 if number < 10 else -5, 3), 7, GOLD if current else IVORY)
		var label: String = room.get("label", room["name"])
		label = "%02d  %s" % [number, label]
		while font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x > 190 and label.length() > 7:
			label = label.left(label.length() - 2).trim_suffix("…") + "…"
		_text(label, Vector2(397, 115 + (number - 1) * (11 if revealed.size() > 12 else 12)), 9, GOLD if current else MUTED)
	var hero_marker: Vector2 = origin + game.player.position * scale_factor
	draw_circle(hero_marker, 4, Color("162c32"))
	draw_colored_polygon(PackedVector2Array([hero_marker + Vector2(0, -4), hero_marker + Vector2(3, 0), hero_marker + Vector2(0, 4), hero_marker + Vector2(-3, 0)]), Color("a8e6d2"))
	_text("◆ Senu  ·  contorno dourado: área atual", Vector2(54, 270), 8, MUTED)

func _map_room_corners(rect: Rect2i) -> PackedVector2Array:
	var start := Vector2(rect.position) - Vector2(.5, .5)
	var finish := Vector2(rect.end) - Vector2(.5, .5)
	return PackedVector2Array([PortLayout.iso(start), PortLayout.iso(Vector2(finish.x, start.y)), PortLayout.iso(finish), PortLayout.iso(Vector2(start.x, finish.y))])
