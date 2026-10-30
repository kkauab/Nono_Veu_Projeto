extends Control
## One binding for every pause page. Coordinates are logical; fonts and controls
## rasterize at the window size instead of scaling a small rendered page.
const INK := Color("30291e")
const FADED := Color("766248")
const GOLD := Color("b6975f")
const BOOK_RECT := Rect2(65, 25, 850, 480)
const BOOK_IMAGE := preload("res://assets/ui/quest_journal_v1.png")
const Journal = preload("res://scripts/ui/quest_journal_book.gd")
const Inventory = preload("res://scripts/ui/inventory_book_page.gd")
const Skills = preload("res://scripts/ui/skill_book_page.gd")
const MapPage = preload("res://scripts/ui/notebook_map_page.gd")
const SenuPreview = preload("res://scripts/ui/senu_notebook_preview.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const Catalog = preload("res://scripts/economy/shop_catalog.gd")
const FramePacing = preload("res://scripts/core/frame_pacing.gd")
var hud: Control
var game: Node2D
var page := "pause"
var _ui_scale := 1.0
var _serif: Font
var _preview: Node2D
var _entry_focus: Button

func configure(owner_hud: Control, mode: String) -> void:
	hud = owner_hud
	game = hud.game
	page = mode
	_ui_scale = hud._factor
	_serif = hud.title_font
	position = hud._offset
	size = Vector2(960, 540) * _ui_scale
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	name = "PauseNotebook"
	_build_tabs()
	var close := _button(self, "Esc  ·  Fechar caderno", Rect2(742, 506, 157, 27), hud._back)
	close.name = "NotebookClose"
	close.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	close.add_theme_color_override("font_color", Color("d4bd8f"))
	match page:
		"pause": _character_page()
		"journal":
			var journal := Journal.new()
			journal.embedded = true
			add_child(journal)
			journal.configure(hud)
		"inventory": Inventory.build(self)
		"tree":
			var skills := Skills.new()
			add_child(skills)
			skills.configure(self)
		"map":
			var chart := MapPage.new()
			add_child(chart)
			chart.configure(self)
		"settings": _settings_page()
		"controls": _controls_page()
		"exit": _exit_page()
	# Page roots fill the spread; the binding's navigation must stay on top.
	for child in get_children():
		if str(child.name).begins_with("NotebookTab_") or child.name == "NotebookClose":
			move_child(child, get_child_count() - 1)
	if _entry_focus != null: _focus_entry.call_deferred()
	queue_redraw()

func _focus_entry() -> void:
	if is_instance_valid(_entry_focus) and _entry_focus.is_inside_tree(): _entry_focus.grab_focus()

func _build_tabs() -> void:
	var tabs := [["pause", "Senu", "diamond"], ["journal", "Missões", "journal"], ["map", "Mapa", "map"], ["tree", "Emanações", "tree"], ["inventory", "Inventário", "inventory"], ["settings", "Configurações", "settings"], ["exit", "Sair", "exit"]]
	for index in range(tabs.size()):
		var tab: Array = tabs[index]
		var target: String = tab[0]
		var active: bool = target == page or (page == "controls" and target == "settings")
		var button := _button(self, "", Rect2(35, 69 + index * 55, 49, 49), func(): hud.show_overlay(target))
		button.name = "NotebookTab_" + target
		button.tooltip_text = tab[1]
		var path := "res://assets/ui/hud_" + str(tab[2]) + ".svg"
		if ResourceLoader.exists(path):
			button.icon = load(path) as Texture2D
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.add_theme_constant_override("icon_max_width", roundi(25 * _ui_scale))
		var style := _style(Color("8d6e43") if active else Color("142226"), Color("b39761"))
		button.add_theme_stylebox_override("normal", style)

func _character_page() -> void:
	_label(self, "SENU", Rect2(155, 82, 292, 52), 36, INK)
	_label(self, "D I S C Í P U L O", Rect2(157, 133, 260, 24), 11, FADED)
	_label(self, "“Entre ruínas e silêncios, ainda caminho.”", Rect2(157, 183, 115, 113), 15, FADED)
	_preview = SenuPreview.new()
	_preview.name = "SenuPreview"
	_preview.source = game.player
	_preview.position = Vector2(353, 415) * _ui_scale
	_preview.scale = Vector2.ONE * 4.5 * _ui_scale
	add_child(_preview)
	_label(self, "ATRIBUTOS", Rect2(157, 304, 116, 20), 11, FADED)
	var hero = game.player
	var damage: int = hero.equipped_weapon().damage + hero.damage_bonus
	var stats := [["Vida máxima", str(hero.max_health)], ["Dano", str(damage)], ["Velocidade", "%.0f" % hero.move_speed], ["Proteção", "15%" if hero.has_skill("pele_alabastro") else "0%"]]
	for i in range(stats.size()):
		_label(self, stats[i][0], Rect2(157, 331 + i * 24, 88, 24), 12, INK)
		_label(self, stats[i][1], Rect2(247, 331 + i * 24, 35, 24), 12, FADED)
	# Paragraphs determine their own height. Longer text scrolls inside the
	# narrative area instead of covering the next heading or action buttons.
	var narrative := ScrollContainer.new()
	narrative.name = "CharacterNarrativeScroll"
	narrative.position = Vector2(523, 80) * _ui_scale
	narrative.size = Vector2(314, 260) * _ui_scale
	narrative.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_theme_scroll(narrative)
	add_child(narrative)
	var paragraphs := VBoxContainer.new()
	paragraphs.name = "CharacterParagraphs"
	paragraphs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paragraphs.add_theme_constant_override("separation", roundi(10 * _ui_scale))
	narrative.add_child(paragraphs)
	_flow_label(paragraphs, "HISTÓRIA", 12, FADED).custom_minimum_size.y = 21 * _ui_scale
	_flow_label(paragraphs, "Um jovem discípulo chega ao Porto dos Esquecidos em busca de Iri. Entre nomes perdidos e memórias encobertas, Senu segue os vestígios da irmã e procura uma passagem para o norte.", 17, INK).name = "CharacterHistory"
	_flow_label(paragraphs, "ESTILO DE COMBATE", 12, FADED).custom_minimum_size.y = 21 * _ui_scale
	_flow_label(paragraphs, "Passos atentos, esquivas e aparos abrem espaço para a lâmina. A arma e as Emanações definem suas possibilidades.", 16, INK).name = "CharacterCombatStyle"
	for index in range(3):
		var action: String = ["attack", "dodge", "parry"][index]
		_button(self, ["Ataque", "Esquiva", "Aparar"][index], Rect2(523 + index * 106, 351, 98, 27), func(): _preview.demonstrate(action)).name = "SenuAction_" + action
	_label(self, "EQUIPAMENTO ATUAL", Rect2(523, 391, 310, 21), 12, FADED)
	var weapon = hero.equipped_weapon()
	var equipped_icon := _icon("", Rect2(526, 420, 42, 42))
	equipped_icon.texture = Inventory.icon_texture("daggers" if weapon.category == "leve" else "khopesh")
	equipped_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_label(self, weapon.display_name, Rect2(585, 418, 245, 31), 17, INK)
	_label(self, "Nível %d  ·  %d óbolos  ·  %d Nous" % [Economy.level(game.store.data), Economy.coins(game.store.data), game.store.data["fragments"]], Rect2(585, 442, 247, 22), 11, FADED)
	_entry_focus = _button(self, "Continuar jornada", Rect2(157, 430, 177, 28), func(): hud.show_overlay(""))
	_entry_focus.name = "NotebookResume"

func _settings_page() -> void:
	_heading("Configurações", "Os detalhes da travessia")
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	_button(self, "Tela cheia: " + ("ativada" if fullscreen else "desativada"), Rect2(155, 181, 292, 39), hud._toggle_fullscreen).name = "NotebookFullscreen"
	_button(self, "Limite de 60 quadros: " + ("ativado" if hud._limit_fps else "desativado"), Rect2(155, 235, 292, 39), func():
		hud._limit_fps = not hud._limit_fps
		FramePacing.apply(hud._limit_fps)
		hud._write_preferences()
		hud._build_controls()).name = "NotebookFrameLimit"
	_button(self, "Controles", Rect2(155, 289, 292, 39), func(): hud.show_overlay("controls")).name = "NotebookControls"
	_label(self, "PREFERÊNCIAS", Rect2(523, 86, 310, 22), 12, FADED)
	_label(self, "Ajuste a janela e o ritmo de exibição. Essas preferências ficam guardadas neste computador.", Rect2(523, 127, 309, 107), 18, INK)
	_label(self, "Os comandos de movimento, combate e exploração estão reunidos na página Controles.", Rect2(523, 252, 309, 102), 17, FADED)
	_label(self, "O progresso de Senu é gravado somente ao meditar em uma torre de salvamento.", Rect2(523, 379, 309, 80), 16, FADED)

func _controls_page() -> void:
	_heading("Controles", "Configurações · comandos da jornada")
	_label(self, "MOVIMENTO E EXPLORAÇÃO", Rect2(155, 181, 292, 25), 11, FADED)
	_label(self, "COMBATE", Rect2(523, 86, 310, 25), 12, FADED)
	var left := [["WASD / setas", "Andar"], ["Shift", "Correr"], ["Espaço", "Rolar / esquivar"], ["E", "Interagir / recolher"], ["M / N / T", "Mapa / missões / habilidades"], ["Esc", "Abrir / fechar o caderno"]]
	var right := [["J / botão esquerdo", "Ataque leve"], ["F", "Ataque forte"], ["K / botão direito", "Aparar"], ["Q", "Poder da arma"], ["Tab", "Trocar arma encontrada"], ["R", "Usar bálsamo"], ["C", "Selo de Mercúrio¹"]]
	for i in range(left.size()):
		_label(self, left[i][0], Rect2(155, 217 + i * 32, 99, 30), 12, INK)
		_label(self, left[i][1], Rect2(262, 217 + i * 32, 185, 30), 12, FADED)
	for i in range(right.size()):
		_label(self, right[i][0], Rect2(523, 133 + i * 37, 161, 31), 12, INK)
		_label(self, right[i][1], Rect2(692, 133 + i * 37, 140, 31), 12, FADED)
	_label(self, "¹ Aprenda essa Emanação antes de usar.", Rect2(523, 414, 308, 47), 13, FADED)
	_button(self, "Voltar às configurações", Rect2(155, 432, 250, 29), func(): hud.show_overlay("settings"))

func _exit_page() -> void:
	_heading("Encerrar a travessia", "O último ponto de repouso permanece")
	_label(self, "Senu só guarda a jornada ao meditar em uma torre de salvamento.", Rect2(155, 190, 292, 100), 19, INK)
	_label(self, "Ao sair, mudanças feitas desde a última torre não serão mantidas na próxima partida.", Rect2(155, 308, 292, 115), 17, FADED)
	_label(self, "SAIR DO JOGO", Rect2(523, 87, 309, 28), 18, INK)
	_label(self, "Você pode continuar explorando e procurar uma torre antes de encerrar.", Rect2(523, 141, 308, 95), 18, INK)
	_button(self, "Continuar jornada", Rect2(523, 294, 307, 39), func(): hud.show_overlay(""))
	_button(self, "Sair do jogo", Rect2(523, 350, 307, 39), func():
		if game.has_method("quit_without_save"): game.quit_without_save()
		else: game.save_and_quit()).name = "NotebookQuit"

func _heading(title: String, subtitle: String) -> void:
	_label(self, title, Rect2(155, 82, 292, 57), 25, INK)
	_label(self, subtitle, Rect2(155, 140, 292, 31), 11, FADED)

func _icon(path: String, rect: Rect2) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position * _ui_scale
	image.size = rect.size * _ui_scale
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(path): image.texture = load(path) as Texture2D
	add_child(image)
	return image

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position * _ui_scale
	label.size = rect.size * _ui_scale
	label.set_meta("notebook_text_box", rect)
	_theme_label(label, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = text
	parent.add_child(label)
	return label

func _flow_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	_theme_label(label, font_size, color)
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _theme_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", _serif)
	label.add_theme_font_size_override("font_size", roundi(font_size * _ui_scale))
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("line_spacing", roundi(2 * _ui_scale))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
	var button := Button.new()
	button.position = rect.position * _ui_scale
	button.size = rect.size * _ui_scale
	button.text = text
	button.add_theme_font_override("font", _serif)
	button.add_theme_font_size_override("font_size", roundi(15 * _ui_scale))
	button.add_theme_color_override("font_color", Color("ead6ac"))
	button.add_theme_color_override("font_disabled_color", Color("8e7e64"))
	button.add_theme_color_override("font_hover_color", Color("fff0c8"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(state, _style(Color("283234") if state not in ["hover", "focus"] else Color("4b4938"), GOLD))
	button.pressed.connect(callback)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	return button

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

func _theme_scroll(scroll: ScrollContainer) -> void:
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5 * _ui_scale
	bar.add_theme_stylebox_override("scroll", _style(Color(.3, .2, .1, .02), Color(0, 0, 0, 0)))
	for state in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(state, _style(Color(.36, .27, .14, .28), Color(0, 0, 0, 0)))

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _ui_scale)
	draw_rect(Rect2(0, 0, 960, 540), Color("09181e"))
	draw_texture_rect(BOOK_IMAGE, BOOK_RECT, false)
	for at in [Vector2(18, 17), Vector2(942, 17), Vector2(18, 522), Vector2(942, 522)]:
		var inward := Vector2(1 if at.x < 480 else -1, 1 if at.y < 270 else -1)
		draw_line(at, at + Vector2(inward.x * 90, 0), Color(GOLD, .4), 1)
		draw_line(at, at + Vector2(0, inward.y * 27), Color(GOLD, .4), 1)
	if page in ["pause", "settings", "controls", "exit"]:
		for line in [[Vector2(155, 175), Vector2(447, 175)], [Vector2(523, 107), Vector2(832, 107)]]:
			draw_line(line[0], line[1], Color(FADED, .35), 1)
