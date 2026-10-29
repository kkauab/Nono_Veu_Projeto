extends SceneTree
const Page = preload("res://scripts/ui/skill_book_page.gd")
const Store = preload("res://scripts/save/save_store.gd")
var checks := 0
var failures: Array[String] = []

class HudState extends RefCounted:
	var _selected_skill := "vontade"

class GameData extends RefCounted:
	var store := Store.new("user://qa/skill_book_no_file.json")
	var buy_calls := 0
	func buy_skill(id: String) -> bool:
		if not store.purchase(id): return false
		buy_calls += 1
		return true

class Book extends Control:
	var hud := HudState.new()
	var game := GameData.new()
	var _ui_scale := 1.0
	var font := SystemFont.new()
	func _label(parent: Node, text: String, rect: Rect2, point_size: int, color: Color) -> Label:
		var label := Label.new()
		label.position = rect.position
		label.size = rect.size
		label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", point_size)
		label.add_theme_color_override("font_color", color)
		label.text = text
		parent.add_child(label)
		return label
	func _button(parent: Node, text: String, rect: Rect2, callback: Callable) -> Button:
		var button := Button.new()
		button.position = rect.position
		button.size = rect.size
		button.text = text
		button.pressed.connect(callback)
		parent.add_child(button)
		return button

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var book := Book.new()
	root.add_child(book)
	book.game.store.data["fragments"] = 20
	var page := Page.new()
	book.add_child(page)
	page.configure(book)
	_check(page.nodes.size() == 13, "All 13 real skill nodes are available for selection")
	page.nodes["intelecto"].pressed.emit()
	_check(page.selected_id == "intelecto" and book.hud._selected_skill == "intelecto", "A node click selects its page and remembers the selection")
	_check(book.game.store.data["skills"].is_empty() and book.game.buy_calls == 0, "Selecting a node never learns it")
	page.select_skill("vontade")
	page.hold_button.pressed.emit()
	_check(book.game.buy_calls == 0, "A normal button pressed signal cannot bypass the hold")
	page.begin_hold()
	page.advance_hold(.75)
	_check(page.holding and is_equal_approx(page.hold_progress, .5) and book.game.buy_calls == 0, "Half a hold only fills half of the confirmation")
	page.cancel_hold()
	page.advance_hold(3)
	_check(page.hold_progress == 0 and book.game.store.data["fragments"] == 20, "Releasing cancels all progress and spends nothing")
	page.begin_hold()
	page.advance_hold(1.49)
	_check(book.game.buy_calls == 0, "A hold shorter than 1.5 seconds cannot complete")
	page.advance_hold(.02)
	_check(book.game.buy_calls == 1 and "vontade" in book.game.store.data["skills"] and book.game.store.data["fragments"] == 19, "A continuous complete hold learns and charges the actual catalog cost once")
	page.advance_hold(5)
	page.begin_hold()
	page.advance_hold(5)
	_check(book.game.buy_calls == 1 and not page.holding, "An already learned node cannot buy again or repeat while held")
	page.select_skill("lamina_ascendente")
	page.begin_hold()
	page.advance_hold(3)
	_check(not page.holding and book.game.buy_calls == 1 and page.hold_button.disabled, "Missing prerequisites block the hold and preserve the balance")
	page.select_skill("materia")
	page.begin_hold()
	page.advance_hold(.5)
	page.select_skill("intelecto")
	_check(not page.holding and page.hold_progress == 0 and book.game.buy_calls == 1, "Changing a node cancels the unfinished confirmation")
	page.select_skill("materia")
	page.begin_hold()
	page.advance_hold(.5)
	book.game.store.data["fragments"] = 0
	page.advance_hold(2)
	_check(book.game.buy_calls == 1 and not "materia" in book.game.store.data["skills"], "The balance is checked again during the hold, before committing")
	book.game.store.data["fragments"] = 19
	page.select_skill("intelecto")
	page.select_skill("materia")
	page.begin_hold()
	page.advance_hold(.7)
	book.remove_child(page)
	page.advance_hold(3)
	_check(not page.holding and book.game.buy_calls == 1, "Leaving the page cancels without learning off screen")
	page.free()
	book.free()
	await process_frame
	print("SKILL BOOK checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
