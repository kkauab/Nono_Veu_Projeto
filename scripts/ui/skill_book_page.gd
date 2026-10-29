extends Control
## A notebook page over the real skill catalog. A click selects; learning
## requires one uninterrupted hold, whose prerequisites are checked throughout.
const Catalog = preload("res://scripts/progression/skill_catalog.gd")
const HOLD_SECONDS := 1.5
const POINTS := {
	"vontade": Vector2(200, 390), "materia": Vector2(300, 390), "intelecto": Vector2(400, 390),
	"ritmo_lamina": Vector2(200, 330), "passo_etereo": Vector2(300, 330), "selo_mercurio": Vector2(400, 330),
	"lamina_ascendente": Vector2(175, 270), "pele_alabastro": Vector2(300, 270), "olho_escriba": Vector2(425, 270),
	"contra_ataque_agil": Vector2(250, 217), "reflexo_palavra": Vector2(300, 201), "esquiva_eterea": Vector2(350, 217),
	"convergencia_nous": Vector2(300, 163)
}
const PAPER := Color("d9c6a0")
const INK := Color("30291e")
const FADED := Color("77664a")
const GOLD := Color("b6975f")

var book: Control
var selected_id := "vontade"
var nodes: Dictionary = {}
var hold_button: Button
var hold_progress := 0.0
var holding := false
var _hold_id := ""
var _detail_root: Control
var _fill: ColorRect
var _summary: Label
var _count: Label
var _factor := 1.0

func configure(owner_book: Control) -> void:
	book = owner_book
	name = "SkillBookPage"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_factor = float(book._ui_scale)
	size = Vector2(960, 540) * _factor
	var remembered := str(book.hud.get("_selected_skill"))
	selected_id = remembered if Catalog.NODES.has(remembered) else Catalog.ORDER[0]
	book._label(self, "Árvore das Emanações", Rect2(155, 82, 292, 36), 21, INK)
	_summary = book._label(self, "", Rect2(155, 122, 200, 24), 12, FADED)
	_count = book._label(self, "", Rect2(360, 122, 87, 24), 12, FADED)
	for id in Catalog.ORDER:
		var skill_id: String = id
		var point: Vector2 = POINTS[id]
		var node: Button = book._button(self, "", Rect2(point - Vector2(17, 17), Vector2(34, 34)), func(): select_skill(skill_id))
		node.name = "Skill_" + id
		node.tooltip_text = "%s · %d Nous\n%s" % [Catalog.NODES[id]["name"], Catalog.NODES[id]["cost"], Catalog.NODES[id]["description"]]
		for style in ["normal", "hover", "pressed", "focus"]:
			node.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		node.focus_entered.connect(func(): select_skill(skill_id))
		nodes[id] = node
	_wire_navigation()
	for index in range(3):
		var branch: Label = book._label(self, ["VONTADE", "MATÉRIA", "INTELECTO"][index], Rect2(157 + index * 100, 417, 88, 20), 10, FADED)
		branch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(3):
		book._label(self, ["Aprendida", "Disponível", "Bloqueada"][index], Rect2(170 + index * 94, 440, 84, 20), 10, FADED)
	_detail_root = Control.new()
	_detail_root.name = "SkillDetails"
	_detail_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_root)
	select_skill(selected_id)
	_focus_selected.call_deferred()

func select_skill(id: String) -> void:
	if not Catalog.NODES.has(id): return
	if id == selected_id and is_instance_valid(hold_button): return
	cancel_hold()
	selected_id = id
	book.hud.set("_selected_skill", id)
	_rebuild_details()
	queue_redraw()

func _rebuild_details() -> void:
	cancel_hold()
	for child in _detail_root.get_children():
		_detail_root.remove_child(child)
		child.queue_free()
	var data: Dictionary = book.game.store.data
	var skill: Dictionary = Catalog.NODES[selected_id]
	var owned: Array = data["skills"]
	_summary.text = "%d Fragmentos de Nous" % int(data["fragments"])
	_count.text = "%d / %d" % [owned.size(), Catalog.ORDER.size()]
	book._label(_detail_root, str(skill["branch"]).to_upper(), Rect2(524, 79, 308, 22), 11, FADED)
	book._label(_detail_root, str(skill["name"]), Rect2(522, 106, 313, 55), 24, INK).name = "SkillTitle"
	book._label(_detail_root, str(skill["description"]), Rect2(524, 177, 307, 97), 17, INK).name = "SkillDescription"
	book._label(_detail_root, "CUSTO", Rect2(524, 287, 307, 19), 11, FADED)
	book._label(_detail_root, "%d Fragmentos de Nous" % int(skill["cost"]), Rect2(538, 309, 293, 25), 16, INK)
	var required: Array = skill["requires"]
	book._label(_detail_root, "REQUISITOS", Rect2(524, 347, 307, 19), 11, FADED)
	if required.is_empty():
		book._label(_detail_root, "Nenhum requisito anterior", Rect2(525, 371, 306, 22), 14, FADED)
	else:
		for i in range(required.size()):
			var prerequisite: String = required[i]
			var present := prerequisite in owned
			book._label(_detail_root, ("✓  " if present else "◇  ") + str(Catalog.NODES[prerequisite]["name"]), Rect2(525, 369 + i * 18, 306, 21), 13, INK if present else FADED)
	hold_button = book._button(_detail_root, "", Rect2(524, 431, 308, 33), func(): pass)
	hold_button.name = "HoldToLearn"
	hold_button.add_theme_font_size_override("font_size", roundi(14 * _factor))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1d2929")
	normal.border_color = GOLD
	normal.set_border_width_all(1)
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		hold_button.add_theme_stylebox_override(style, normal.duplicate())
	hold_button.add_theme_color_override("font_color", Color("eee0ba"))
	hold_button.add_theme_color_override("font_hover_color", Color("fff0c7"))
	hold_button.add_theme_color_override("font_pressed_color", Color("fff0c7"))
	hold_button.add_theme_color_override("font_disabled_color", Color("a38e69"))
	hold_button.button_down.connect(begin_hold)
	hold_button.button_up.connect(cancel_hold)
	hold_button.mouse_exited.connect(cancel_hold)
	hold_button.focus_exited.connect(cancel_hold)
	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.color = GOLD
	_fill.position = Vector2(1, 30) * _factor
	_fill.size = Vector2(0, 2) * _factor
	hold_button.add_child(_fill)
	_refresh_button()
	queue_redraw()

func _refresh_button() -> void:
	if not is_instance_valid(hold_button): return
	var data: Dictionary = book.game.store.data
	var reason := Catalog.blocker(data, selected_id)
	hold_button.disabled = not reason.is_empty()
	hold_button.tooltip_text = reason if not reason.is_empty() else "Mantenha o botão pressionado por 1,5 segundos. Enter e Espaço também funcionam."
	if selected_id in data["skills"]:
		hold_button.text = "Aprendida"
	elif not Catalog.requires_met(data["skills"], selected_id):
		hold_button.text = "Pré-requisitos pendentes"
	elif not reason.is_empty():
		hold_button.text = "Nous insuficiente"
	else:
		hold_button.text = "Mantenha pressionado · 1,5 s"

func begin_hold() -> void:
	cancel_hold()
	if not is_inside_tree() or not is_visible_in_tree(): return
	if not Catalog.blocker(book.game.store.data, selected_id).is_empty():
		_refresh_button()
		return
	holding = true
	_hold_id = selected_id

func cancel_hold() -> void:
	holding = false
	hold_progress = 0.0
	_hold_id = ""
	if is_instance_valid(_fill): _fill.size.x = 0
	if is_instance_valid(book) and is_instance_valid(hold_button): _refresh_button()

func advance_hold(delta: float) -> void:
	if not holding: return
	if not is_inside_tree() or not is_visible_in_tree() or _hold_id != selected_id:
		cancel_hold()
		return
	if not Catalog.blocker(book.game.store.data, _hold_id).is_empty():
		cancel_hold()
		return
	hold_progress = minf(1.0, hold_progress + maxf(0.0, delta) / HOLD_SECONDS)
	if is_instance_valid(_fill): _fill.size.x = 306 * _factor * hold_progress
	hold_button.text = "Aprendendo · %d%%" % roundi(hold_progress * 100)
	if hold_progress >= 1.0:
		var completed := _hold_id
		# Clear the hold before the callback. Repeated input/frames cannot buy twice.
		cancel_hold()
		if Catalog.blocker(book.game.store.data, completed).is_empty():
			book.game.buy_skill(completed)
		_rebuild_details()

func _process(delta: float) -> void:
	if not holding: return
	if not is_instance_valid(hold_button) or not hold_button.is_pressed():
		cancel_hold()
		return
	advance_hold(delta)

func _exit_tree() -> void:
	cancel_hold()

func _focus_selected() -> void:
	if nodes.has(selected_id) and is_instance_valid(nodes[selected_id]) and nodes[selected_id].is_inside_tree():
		nodes[selected_id].grab_focus()

func _wire_navigation() -> void:
	for id in Catalog.ORDER:
		var node: Button = nodes[id]
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var closest := ""
			var best := INF
			for other in Catalog.ORDER:
				if other == id: continue
				var offset: Vector2 = POINTS[other] - POINTS[id]
				var dot := offset.normalized().dot(direction)
				if dot < .45: continue
				var score := offset.length() / (dot * dot)
				if score < best: best = score; closest = other
			if closest.is_empty(): continue
			var property: String = {Vector2.UP: "focus_neighbor_top", Vector2.RIGHT: "focus_neighbor_right", Vector2.DOWN: "focus_neighbor_bottom", Vector2.LEFT: "focus_neighbor_left"}[direction]
			node.set(property, node.get_path_to(nodes[closest]))

func _draw() -> void:
	if book == null or book.game == null: return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _factor)
	var data: Dictionary = book.game.store.data
	var owned: Array = data["skills"]
	for y in [115.0, 437.0]: draw_line(Vector2(155, y), Vector2(447, y), Color(FADED, .35), 1)
	for y in [166.0, 281.0, 341.0]: draw_line(Vector2(524, y), Vector2(832, y), Color(FADED, .35), 1)
	# Faint geometric guide on the paper, underneath the actual routes.
	draw_arc(Vector2(300, 292), 117, 0, TAU, 64, Color(FADED, .12), 1, true)
	for id in Catalog.ORDER:
		var point: Vector2 = POINTS[id]
		for prerequisite in Catalog.NODES[id]["requires"]:
			var from: Vector2 = POINTS[prerequisite]
			var direction := (point - from).normalized()
			var color := GOLD if id in owned else (Color("6c6a4d") if prerequisite in owned else Color(FADED, .45))
			draw_line(from + direction * 16, point - direction * 16, color, 1, true)
	for id in Catalog.ORDER:
		var point: Vector2 = POINTS[id]
		var learned: bool = id in owned
		var available := Catalog.blocker(data, id).is_empty()
		var border := GOLD if learned else (Color("3d5a53") if available else Color("8e8064"))
		draw_circle(point, 15, Color("273532") if learned or available else Color("c1af8b"))
		draw_arc(point, 15, 0, TAU, 32, border, 1.5, true)
		if id == selected_id:
			draw_arc(point, 20, 0, TAU, 32, Color("8c6734"), 1.5, true)
			_diamond(point + Vector2(-24, 0), 2.5, Color("8c6734"))
		if learned: _diamond(point + Vector2(0, -16), 2.5, GOLD)
		_glyph(point, str(Catalog.NODES[id]["branch_id"]), Color("dfc38a") if learned or available else Color("88765a"))
	for i in range(3): draw_circle(Vector2(161 + i * 94, 450), 3, [GOLD, Color("3d5a53"), Color("a58f69")][i])
	_diamond(Vector2(528, 321), 4, Color("8c6734"))

func _glyph(center: Vector2, branch: String, color: Color) -> void:
	if branch == "vontade":
		draw_polyline(PackedVector2Array([center + Vector2(-7, 7), center + Vector2(6, -8), center + Vector2(2, 3), center + Vector2(-7, 7)]), color, 1, true)
		draw_line(center + Vector2(-5, 2), center + Vector2(2, 8), color, 1, true)
	elif branch == "materia":
		_diamond(center, 8, color)
		_diamond(center, 4, color)
	elif branch == "intelecto":
		draw_arc(center, 3, 0, TAU, 16, color, 1, true)
		for i in range(6):
			var vector := Vector2.RIGHT.rotated(i * TAU / 6)
			draw_line(center + vector * 5, center + vector * 9, color, 1, true)
	elif branch == "convergencia":
		_diamond(center, 9, color)
		for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]: draw_line(center, center + direction * 11, color, 1, true)
	else:
		draw_arc(center + Vector2(-3, 0), 6, 0, TAU, 20, color, 1, true)
		draw_arc(center + Vector2(3, 0), 6, 0, TAU, 20, color, 1, true)

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([center + Vector2.UP * radius, center + Vector2.RIGHT * radius, center + Vector2.DOWN * radius, center + Vector2.LEFT * radius, center + Vector2.UP * radius]), color, 1, true)
