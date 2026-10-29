extends SceneTree
## Exercise real book text at both supported preview sizes, including the
## longest skill titles and every discovered inventory item. No journey saves.
const Main = preload("res://scenes/boot/main.tscn")
const Inventory = preload("res://scripts/ui/inventory_book_page.gd")
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Skills = preload("res://scripts/progression/skill_catalog.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	world.store.data["fragments"] = 50
	world.store.data["weapons"] = ["e01_khopesh_discipulo", "l01_adagas_reverso"]
	for room in Layout.ROOMS: world.store.data["visited"].append(room["id"])
	for id in Shop.ITEMS: Shop.grant(world.store.data, id)
	world.store.data["collected"].append_array(["quest_mirra", "quest_tenaz", "quest_escala", "fisher_knot", "isle_net"])
	for dimensions in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = dimensions
		await process_frame
		world.hud._geometry()
		for page in ["pause", "settings", "controls", "exit", "map", "inventory", "tree"]:
			world.hud.show_overlay(page)
			await process_frame
			await process_frame
			var book: Control = world.hud.get_node("PauseNotebook")
			if page == "inventory":
				for entry in book.get_meta("inventory_entries"):
					Inventory.select_item(book, entry["id"])
					await process_frame
					_check_text(book, str(dimensions.x) + " inventory " + str(entry["id"]))
			elif page == "map":
				var chart: Control = book.get_node("NotebookMapPage")
				for room in chart.rooms:
					chart.select_room(room["id"])
					await process_frame
					_check_text(book, str(dimensions.x) + " map " + str(room["id"]))
			elif page == "tree":
				var graph: Control = book.get_node("SkillBookPage")
				for id in Skills.ORDER:
					graph.select_skill(id)
					await process_frame
					_check_text(book, str(dimensions.x) + " tree " + id)
			else:
				_check_text(book, str(dimensions.x) + " " + page)
	world.hud.show_overlay("")
	world.queue_free()
	await process_frame
	print("NOTEBOOK LAYOUT checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check_text(book: Control, caption: String) -> void:
	var factor: float = book._ui_scale
	for button: Button in book.find_children("*", "Button", true, false):
		if button.text.is_empty() or button.name == "NotebookClose" or str(button.name).begins_with("Room_"): continue
		var bounds := button.get_global_rect()
		bounds.position = (bounds.position - book.global_position) / factor
		bounds.size /= factor
		var left := bounds.position.x < 480
		_check(bounds.position.x >= (155 if left else 520) - 1 and bounds.end.x <= (450 if left else 845) + 1, caption + ": button crosses the page margin: " + button.text)
	for label: Label in book.find_children("*", "Label", true, false):
		if not label.has_meta("notebook_text_box"): continue
		var box: Rect2 = label.get_meta("notebook_text_box")
		_check(label.size.y <= box.size.y * factor + 1, caption + ": text exceeds allocated height: " + label.text)
		var bounds := label.get_global_rect()
		bounds.position = (bounds.position - book.global_position) / factor
		bounds.size /= factor
		var on_left := bounds.position.x < 480
		_check(bounds.position.x >= (155 if on_left else 520) - 1 and bounds.end.x <= (450 if on_left else 845) + 1, caption + ": text crosses the page margin: " + label.text)
		var face := label.get_theme_font("font")
		var point_size := label.get_theme_font_size("font_size")
		for word in label.text.split(" "):
			_check(face.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x <= label.size.x + 1, caption + ": word cannot fit without breaking: " + word)

func _check(value: bool, caption: String) -> void:
	checks += 1
	if not value:
		failures.append(caption)
		push_error(caption)
