extends RefCounted
const Catalog = preload("res://scripts/economy/inventory_catalog.gd")
const Economy = preload("res://scripts/economy/economy.gd")
static var _icons := {}

static func build(book: Control) -> void:
	var game = book.game
	var data: Dictionary = game.store.data
	var items := Catalog.entries(data, game.player.weapons)
	var filter := str(book.hud.get("_book_inventory_filter"))
	if filter not in Catalog.FILTERS: filter = "Todos"
	book.hud.set("_book_inventory_filter", filter)
	var visible := Catalog.filtered(items, filter)
	book.set_meta("inventory_entries", visible)
	book.set_meta("inventory_slots", {})
	book._label(book, "Inventário da travessia", Rect2(155, 82, 292, 42), 21, book.INK)
	book._label(book, "O que foi encontrado permanece na memória.", Rect2(155, 124, 292, 30), 11, book.FADED)
	for i in range(Catalog.FILTERS.size()):
		var category: String = Catalog.FILTERS[i]
		var action: Button = book._button(book, category, Rect2(155 + i * 59, 159, 56, 25), func(): _filter(book, category))
		action.name = "InventoryFilter_" + category
		action.add_theme_font_size_override("font_size", roundi(10 * book._ui_scale))
		_skin(action, category == filter, book)
	var scroll := ScrollContainer.new()
	scroll.name = "InventorySlotsScroll"
	scroll.position = Vector2(155, 195) * book._ui_scale
	scroll.size = Vector2(292, 229) * book._ui_scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	book._theme_scroll(scroll)
	book.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", roundi(6 * book._ui_scale))
	grid.add_theme_constant_override("v_separation", roundi(6 * book._ui_scale))
	scroll.add_child(grid)
	var slots: Dictionary = book.get_meta("inventory_slots")
	for i in range(maxi(20, ceili(visible.size() / 5.0) * 5)):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(52, 52) * book._ui_scale
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		grid.add_child(slot)
		if i >= visible.size():
			slot.disabled = true
			_skin(slot, false, book, true)
			continue
		var entry: Dictionary = visible[i]
		var id: String = entry["id"]
		slot.name = "InventorySlot_" + id
		slot.tooltip_text = str(entry["name"])
		slot.pressed.connect(func(): select_item(book, id))
		slot.focus_entered.connect(func(): select_item(book, id))
		_icon(slot, str(entry["icon"]), Rect2(5, 4, 42, 42), book._ui_scale)
		if int(entry["count"]) > 1:
			var number: Label = book._label(slot, str(entry["count"]), Rect2(25, 32, 24, 17), 11, Color("e0c489"))
			number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if bool(entry.get("equipped", false)):
			book._label(slot, "◆", Rect2(3, 1, 14, 20), 9, Color("e0c489"))
		slots[id] = slot
		_skin(slot, false, book)
	book._label(book, "%d óbolos" % Economy.coins(data), Rect2(155, 435, 154, 20), 12, book.FADED)
	book._label(book, "%d registros" % visible.size(), Rect2(336, 435, 111, 20), 11, book.FADED)
	var detail := Control.new()
	detail.name = "InventoryDetail"
	book.add_child(detail)
	var chosen := str(book.hud.get("_book_inventory_selected"))
	if not slots.has(chosen): chosen = "" if visible.is_empty() else str(visible[0]["id"])
	if chosen.is_empty():
		book._label(detail, "Ainda em branco", Rect2(523, 90, 314, 55), 24, book.INK)
		book._label(detail, "Nenhum objeto desta categoria foi encontrado. As descobertas da jornada ocuparão estes espaços.", Rect2(523, 191, 311, 166), 18, book.FADED)
	else:
		select_item(book, chosen)

static func _filter(book: Control, category: String) -> void:
	book.hud.set("_book_inventory_filter", category)
	book.hud._build_controls()

static func select_item(book: Control, id: String) -> void:
	var entries: Array = book.get_meta("inventory_entries", [])
	var selected := {}
	for entry in entries:
		if str(entry["id"]) == id: selected = entry; break
	if selected.is_empty(): return
	book.hud.set("_book_inventory_selected", id)
	book.set_meta("inventory_selected", selected)
	var slots: Dictionary = book.get_meta("inventory_slots", {})
	for key in slots: _skin(slots[key], key == id, book)
	var detail: Control = book.get_node("InventoryDetail")
	for child in detail.get_children():
		detail.remove_child(child)
		child.queue_free()
	book._label(detail, str(selected["category"]).to_upper(), Rect2(523, 77, 314, 18), 11, book.FADED)
	book._label(detail, selected["name"], Rect2(523, 100, 314, 51), 22, book.INK).name = "InventoryItemName"
	var heirloom: bool=selected["kind"]=="heirloom"
	_icon(detail, str(selected["icon"]), Rect2(609,151,142,96) if heirloom else Rect2(593,151,174,131), book._ui_scale).name = "InventoryItemPreview"
	book._label(detail, selected["description"], Rect2(523,255,314,95) if heirloom else Rect2(523,289,314,61), 13 if heirloom else 14, book.INK).name = "InventoryItemDescription"
	var stats: Array = selected.get("stats", [])
	for i in range(mini(3, stats.size())):
		book._label(detail, str(stats[i]), Rect2(523, 355 + i * 19, 315, 20), 13, book.INK).name = "InventoryStat_%d" % i
	if selected["kind"] == "weapon":
		book._label(detail, selected["power"], Rect2(523, 415, 314, 20), 11, book.FADED)
		var equipped := bool(selected.get("equipped", false))
		var equip: Button = book._button(detail, "Equipada" if equipped else "Equipar", Rect2(523, 433, 309, 28), func(): _equip(book, selected))
		equip.name = "InventoryEquip"
		equip.disabled = equipped
		equip.add_theme_font_size_override("font_size", roundi(13 * book._ui_scale))
		_skin(equip, not equipped, book)
	else:
		book._label(detail, selected.get("note", ""), Rect2(523, 433, 309, 27), 12, book.FADED)

static func _equip(book: Control, selected: Dictionary) -> void:
	var game = book.game
	if game.player.equip_weapon(int(selected["weapon_index"])):
		game.store.data["equipped"] = str(selected["id"])
		if game.has_method("_stats_changed"): game.call("_stats_changed")
		elif game.has_method("_apply_upgrades"): game.call("_apply_upgrades", false)
		if game.has_method("_save"): game.call("_save")
		book.hud._build_controls()

static func _skin(button: Button, selected: bool, book: Control, empty: bool = false) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(.31, .24, .14, .12) if empty else Color("17262a")
	normal.border_color = Color("b7975a") if selected else Color(.34, .26, .16, .48)
	normal.set_border_width_all(2 if selected else 1)
	normal.set_corner_radius_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("disabled", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color("c9a86e")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_font_override("font", book.hud.title_font)
	button.add_theme_color_override("font_color", Color("e5d3ab"))

static func _icon(parent: Node, id: String, rect: Rect2, factor: float) -> TextureRect:
	var view := TextureRect.new()
	view.position = rect.position * factor
	view.size = rect.size * factor
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.texture = icon_texture(id)
	parent.add_child(view)
	return view

static func icon_texture(id: String) -> Texture2D:
	if _icons.has(id): return _icons[id]
	if id=="key_spear":
		_icons[id]=load("res://assets/ui/gatekeeper_key_spear.png") as Texture2D
		return _icons[id]
	if id in ["khopesh", "daggers"]:
		# These isolated equipment cels are the blades actually drawn in Senu's
		# hands. Cropping alpha keeps the game pixels, rather than enlarging SVG UI art.
		var equipment_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/senu_shared_v6_manifest.json"))
		var category := "espada" if id == "khopesh" else "leve"
		var equipment: Dictionary = equipment_plan["equipment"][category]
		var values: Array = equipment_plan["frame_regions"][int(equipment["frame"])]
		var frame_region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
		var equipment_atlas: Texture2D = load(str(equipment_plan["texture"])) as Texture2D
		var equipment_image := equipment_atlas.get_image()
		if equipment_image.is_compressed(): equipment_image.decompress()
		var blade_bounds := equipment_image.get_region(frame_region).get_used_rect()
		var blade := AtlasTexture.new()
		blade.atlas = equipment_atlas
		blade.region = Rect2(frame_region.position + blade_bounds.position, blade_bounds.size)
		blade.filter_clip = true
		_icons[id] = blade
		return blade
	# Reuse the same sprite frames that appear in the port and its interiors.
	var atlas_names := {"jar": "amphora", "tool": "anvil", "chest": "chest_closed", "map": "easel", "scroll": "easel", "cord": "cords"}
	if atlas_names.has(id):
		var manifest_path := "res://assets/world/interiors_v4_manifest.json"
		if FileAccess.file_exists(manifest_path):
			var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
			var entry: Dictionary = plan["sprites"].get(atlas_names[id], {})
			if not entry.is_empty():
				var atlas: Texture2D = load(str(plan["texture"])) as Texture2D
				var frame := int(entry["frames"][0])
				var columns := int(plan["columns"])
				var cell := Vector2i(int(plan["canvas"][0]), int(plan["canvas"][1]))
				var origin := Vector2i(frame % columns, frame / columns) * cell
				var image := atlas.get_image()
				if image.is_compressed(): image.decompress()
				var used := image.get_region(Rect2i(origin, cell)).get_used_rect()
				var result := AtlasTexture.new()
				result.atlas = atlas
				result.region = Rect2(origin + used.position, used.size)
				_icons[id] = result
				return result
	# These UI symbols already belong to the game; no new illustrated item style.
	var symbol := "hud_diamond.svg" if id in ["fragment", "seal", "amulet"] else "hud_inventory.svg"
	_icons[id] = load("res://assets/ui/" + symbol) as Texture2D
	return _icons[id]
