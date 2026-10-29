extends SceneTree
## No save files, quest completion or rewards are touched by this test.
const Book = preload("res://scripts/ui/quest_journal_book.gd")
var checks := 0
var failures: Array[String] = []

class MemoryStore extends RefCounted:
	var data := {"collected": [], "visited": [], "flags": {"boss": false}}

class GameData extends RefCounted:
	var store := MemoryStore.new()
	func objective() -> String: return "Explore o Arquivo e os Sinos ao norte."

class TestHud extends Control:
	var game := GameData.new()
	var title_font := SystemFont.new()
	var font := SystemFont.new()
	var _selected_quest := ""
	var _factor := 1.0
	var destination := ""
	var back_count := 0
	func _back() -> void: back_count += 1
	func show_overlay(mode: String) -> void: destination = mode

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var hud := TestHud.new()
	hud.title_font.font_names = PackedStringArray(["Georgia", "serif"])
	hud.font.font_names = PackedStringArray(["Segoe UI", "sans-serif"])
	root.add_child(hud)
	var book := Book.new()
	hud.add_child(book)
	book.configure(hud)
	_check(book.entries.size() == 1 and book.rows.has("main_port"), "A new journey records its main objective without inventing optional requests")
	_check(book.find_child("NoSideQuests", true, false) != null, "The secondary section explains how to discover optional requests")
	_check(book.find_child("CurrentObjective", true, false).text == hud.game.objective(), "The main page uses the same live objective as the world")
	book.free()
	var data: Dictionary = hud.game.store.data
	data["collected"] = ["fisher_met", "quest_started_merit", "quest_started_nakht", "quest_started_adiam", "quest_started_tarek"]
	book = Book.new()
	hud.add_child(book)
	book.configure(hud)
	await process_frame
	_check(book.entries.size() == 6 and book.rows.size() == 6, "The main quest and five known requests each have one selectable page")
	await process_frame
	for id in book.rows:
		var row: Button = book.rows[id]
		_check(row.size.y <= 100, "Quest row %s keeps a readable height after wrapping" % id)
		var labels: Array[Node] = row.find_children("*", "Label", true, false)
		_check(labels.size() == 2 and labels[0].get_global_rect().end.y <= labels[1].get_global_rect().position.y, "Quest row %s does not overlap its subtitle" % id)
	_check(book.list_scroll != null and book.detail_scroll != null and book.list_scroll != book.detail_scroll, "List and details scroll independently inside their pages")
	_check(book.list_scroll.get_rect().end.x < 475 and book.detail_scroll.get_rect().position.x > 495, "Both text columns stay on their own side of the spine")
	book.select_quest("adiam")
	_check(book.selected_id == "adiam" and hud._selected_quest == "adiam", "Selecting a page persists only its UI selection")
	_check(book.find_child("QuestTitle", true, false).text == "Cartografia das margens", "Selecting a request changes the detail title")
	_check(book.find_child("QuestReward", true, false).text == "25 óbolos", "The page uses the actual quest reward")
	data["visited"] = ["aqueduct"]
	var adiam := _entry(Book.entries_for(data), "adiam")
	_check(adiam["steps"][0][1] and not adiam["steps"][1][1] and not adiam["done"], "Visiting one of Adiam's destinations marks only that destination")
	data["collected"].append("quest_mirra")
	var merit := _entry(Book.entries_for(data), "merit")
	_check(merit["steps"][0][1] and merit["steps"][1][1] and not merit["steps"][2][1], "An early item marks discovery without falsely marking its return")
	data["collected"].append("quest_done_merit")
	merit = _entry(Book.entries_for(data), "merit")
	_check(merit["done"] and merit["steps"].all(func(step): return bool(step[1])), "Completed requests show all steps completed")
	var snapshot := JSON.stringify(data)
	book.select_quest("fisher")
	book.select_quest("nakht")
	_check(JSON.stringify(data) == snapshot, "Browsing pages cannot complete requests or change progress")
	book.get_node("JournalTab_map").pressed.emit()
	_check(hud.destination == "map", "The map tab opens the map")
	book.get_node("JournalTab_inventory").pressed.emit()
	_check(hud.destination == "inventory", "The inventory tab opens inventory")
	book.get_node("JournalTab_tree").pressed.emit()
	_check(hud.destination == "tree", "The emanations tab opens the actual skill tree")
	book.get_node("JournalBack").pressed.emit()
	_check(hud.back_count == 1, "The notebook return button uses the HUD's return navigation")
	book.free()
	book = Book.new()
	hud.add_child(book)
	book.configure(hud)
	_check(book.selected_id == "nakht", "Reopening the notebook restores the selected page")
	book.free()
	hud._factor = 1280.0 / 960.0
	book = Book.new()
	hud.add_child(book)
	book.configure(hud)
	await process_frame
	_check(book.scale == Vector2.ONE and book.size.distance_to(Vector2(1280, 720)) < .01, "A 720p notebook scales layout without magnifying low-resolution text")
	var title: Label = book.find_child("QuestTitle", true, false)
	_check(title.get_theme_font_size("font_size") == roundi(23 * hud._factor), "Page titles rasterize at the actual window size")
	_check(book.detail_scroll.get_rect().end.y <= 450 * hud._factor, "Long details stay in a scrolling region above the paper border")
	var giver: Label = book.find_child("QuestGiver", true, false)
	_check(title.get_global_rect().end.y <= giver.get_global_rect().position.y, "A wrapping title cannot overlap its giver")
	book.select_quest("main_port")
	await process_frame
	await process_frame
	_check(book.detail_scroll.get_v_scroll_bar().max_value > book.detail_scroll.size.y, "The longer main quest can be scrolled to every objective and its destination")
	_check(book.find_child("MainQuestsHeading", true, false) != null and book.find_child("SideQuestsHeading", true, false) != null, "Main and side quests have separate headings")
	var main := _entry(Book.entries_for(data), "main_port")
	_check(not main["done"] and not main["steps"][0][1], "Reading the main page does not mark unknown seals complete")
	data["flags"]["seal_bells"] = true
	main = _entry(Book.entries_for(data), "main_port")
	_check(main["steps"][0][1] and not main["steps"][1][1], "Main checklist reads the actual individual seal flags")
	book.free()
	book = Book.new()
	book.embedded = true
	hud.add_child(book)
	book.configure(hud)
	_check(book.mouse_filter == Control.MOUSE_FILTER_IGNORE and book.get_node("SelectedQuest").mouse_filter == Control.MOUSE_FILTER_IGNORE, "Embedded mission roots do not intercept clicks on notebook tabs")
	book.free()
	hud.free()
	await process_frame
	print("JOURNAL BOOK checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _entry(entries: Array[Dictionary], id: String) -> Dictionary:
	for entry in entries:
		if entry["id"] == id: return entry
	return {}

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)
