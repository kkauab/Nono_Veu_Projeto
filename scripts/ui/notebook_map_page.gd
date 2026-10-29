extends Control
## The chart uses the actual explored room geometry. Representative landmarks
## come from the game's atlas, so there is no invented decorative map topology.
const Layout = preload("res://scripts/world/port_layout.gd")
const Art = preload("res://scripts/world/port_art.gd")
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const INK := Color("30291e")
const FADED := Color("766248")
const CHART := Rect2(520, 118, 326, 294)
var book: Control
var selected_id := ""
var rooms: Array[Dictionary] = []
var _details: Control
var _rows: Dictionary = {}
var _factor := 1.0
var _bounds := Rect2()
var _scale := 1.0
var _origin := Vector2.ZERO
var _centers := {}
var _hinted: Array[Dictionary] = []

func configure(owner_book: Control) -> void:
	book = owner_book
	_factor = book._ui_scale
	name = "NotebookMapPage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(960, 540) * _factor
	var data: Dictionary = book.game.store.data
	for room in Layout.ROOMS:
		if room["id"] in data["visited"] or room["id"] == book.game.current_room:
			rooms.append(room)
		elif Shop.reveals_map(data) and room["id"] not in Shop.MAP_HIDDEN:
			_hinted.append(room)
	book._label(self, "Memórias do Porto", Rect2(155, 82, 292, 43), 24, INK)
	book._label(self, "Lugares recordados e caminhos descobertos.", Rect2(155, 128, 292, 43), 12, FADED)
	book._label(self, "CARTA DAS MARGENS", Rect2(523, 80, 310, 22), 12, FADED)
	if rooms.is_empty():
		book._label(self, "Explore o Porto para registrar suas margens.", Rect2(155, 199, 292, 90), 20, INK)
		return
	var scroll := ScrollContainer.new()
	scroll.name = "NotebookRooms"
	scroll.position = Vector2(155, 181) * _factor
	scroll.size = Vector2(292, 158) * _factor
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	book._theme_scroll(scroll)
	add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(3 * _factor))
	scroll.add_child(list)
	for room in rooms:
		var id: String = room["id"]
		var index := Layout.ROOMS.find(room) + 1
		var row := Button.new()
		row.custom_minimum_size = Vector2(276, 38) * _factor
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.text = "%02d  %s" % [index, room.get("label", room["name"])]
		row.tooltip_text = str(room["name"])
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_override("font", book.hud.title_font)
		row.add_theme_font_size_override("font_size", roundi(14 * _factor))
		row.add_theme_color_override("font_color", INK)
		row.add_theme_color_override("font_hover_color", INK)
		row.pressed.connect(func(): select_room(id))
		row.focus_entered.connect(func(): select_room(id))
		row.name = "Room_" + id
		list.add_child(row)
		_rows[id] = row
	_details = Control.new()
	_details.name = "SelectedRoom"
	add_child(_details)
	selected_id = str(book.hud.get("_book_map_selected"))
	if not _rows.has(selected_id): selected_id = rooms[0]["id"]
	select_room(selected_id)
	book._label(self, "◆ Senu   ◇ Lugar atual", Rect2(523, 421, 309, 22), 12, FADED)
	book._label(self, "Conexões abertas · contornos de rotas", Rect2(523, 446, 309, 22), 10, FADED)
	_measure()
	queue_redraw()

func select_room(id: String) -> void:
	if not _rows.has(id): return
	selected_id = id
	book.hud.set("_book_map_selected", id)
	for key in _rows:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.48, .33, .14, .16) if key == id else Color(0, 0, 0, 0)
		style.border_color = Color(.35, .25, .1, .32)
		style.border_width_left = 3 if key == id else 0
		style.border_width_bottom = 1
		for state in ["normal", "hover", "pressed", "focus"]: _rows[key].add_theme_stylebox_override(state, style)
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	for room in rooms:
		if room["id"] != id: continue
		book._label(_details, room["name"], Rect2(155, 356, 292, 54), 19, INK)
		var current: bool = id == book.game.current_room
		book._label(_details, "Você está aqui." if current else "Uma margem já explorada por Senu.", Rect2(155, 417, 292, 38), 14, FADED)
	queue_redraw()

func _shape(room: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	if room.has("outline"):
		for point in room["outline"]: result.append(Layout.iso(point))
	else:
		var rect: Rect2i = room["rect"]
		var start := Vector2(rect.position) - Vector2(.5, .5)
		var end := Vector2(rect.end) - Vector2(.5, .5)
		for point in [start, Vector2(end.x, start.y), end, Vector2(start.x, end.y)]: result.append(Layout.iso(point))
	return result

func _measure() -> void:
	var hero: Vector2 = book.game.call("map_position") if book.game.has_method("map_position") else book.game.player.position
	_bounds = Rect2(hero - Vector2.ONE, Vector2.ONE * 2)
	for room in rooms + _hinted:
		for corner in _shape(room): _bounds = _bounds.expand(corner)
	_scale = minf((CHART.size.x - 30) / maxf(_bounds.size.x, 1), (CHART.size.y - 42) / maxf(_bounds.size.y, 1))
	_origin = CHART.get_center() - _bounds.get_center() * _scale
	for room in rooms:
		var rect: Rect2i = room["rect"]
		_centers[room["id"]] = _origin + Layout.iso(Vector2(rect.position) + (Vector2(rect.size) - Vector2.ONE) * .5) * _scale

func _draw() -> void:
	if book == null or rooms.is_empty() or _centers.is_empty(): return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _factor)
	# Very faint cartographer's grid on the paper, with no opaque map panel.
	for i in range(9):
		var x := CHART.position.x + i * 40
		draw_line(Vector2(x, CHART.position.y), Vector2(x, CHART.end.y), Color(FADED, .07), 1)
	for room in _hinted:
		var outline := PackedVector2Array()
		for point in _shape(room): outline.append(_origin + point * _scale)
		outline.append(outline[0])
		draw_polyline(outline, Color(FADED, .22), 1)
	for link in Layout.ROOM_LINKS:
		if not _centers.has(link[0]) or not _centers.has(link[1]): continue
		if link.size() > 2 and not book.game.store.data["flags"].get(link[2], false): continue
		draw_line(_centers[link[0]], _centers[link[1]], Color(FADED, .6), 2)
	var ordered := rooms.duplicate()
	ordered.sort_custom(func(a, b): return _centers[a["id"]].y < _centers[b["id"]].y)
	for room in ordered:
		var outline := PackedVector2Array()
		for point in _shape(room): outline.append(_origin + point * _scale)
		var color: Color = room["color"]
		color = Color("62706b").lerp(color, .45).lightened(.13)
		draw_colored_polygon(outline, Color(color, .75))
		outline.append(outline[0])
		draw_polyline(outline, Color("a17d43") if room["id"] == selected_id else Color(FADED, .6), 1.5 if room["id"] == selected_id else 1)
		var center: Vector2 = _centers[room["id"]]
		var landmark: String = {"hub": "temple", "p1": "stairs", "p2": "warehouse", "market": "stall", "caravan": "stall", "lower_dock": "boat", "beacon": "lighthouse", "bellcourt": "arch", "garden": "palm", "b1": "arch"}.get(room["id"], "pillar")
		var miniature := .20
		draw_set_transform(center * _factor, 0, Vector2.ONE * miniature * _factor)
		Art.draw_prop(self, landmark)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _factor)
		var number := str(Layout.ROOMS.find(room) + 1)
		draw_circle(center + Vector2(0, 3), 7, Color("233437"))
		draw_set_transform(Vector2.ZERO)
		draw_string(book.hud.title_font, (center + Vector2(-4 if number.length() == 1 else -7, 7)) * _factor, number, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(10 * _factor), Color("ead6a8"))
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * _factor)
	var hero: Vector2 = book.game.call("map_position") if book.game.has_method("map_position") else book.game.player.position
	var point := _origin + hero * _scale
	var marker := PackedVector2Array([point + Vector2(0, -5), point + Vector2(4, 0), point + Vector2(0, 5), point + Vector2(-4, 0)])
	draw_colored_polygon(marker, Color("e6b76a"))
