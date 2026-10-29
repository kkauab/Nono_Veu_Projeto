extends SceneTree

const Hud = preload("res://scripts/ui/game_hud_v6.gd")
var checks := 0
var failures: Array[String] = []

class Demo extends Node2D:
	var store := DemoSaveStore.new("user://qa/hud_v6_progress.json")
	var player: SenuPlayer
	var current_room := "hub"
	var nearest: Node2D
	var boss: Node2D
	var respawning := false
	var qa_mode := true
	var started := 0
	var restarted := 0
	var exited := 0
	var saves := 0
	func _ready() -> void:
		player = SenuPlayer.new()
		add_child(player)
		player.set_physics_process(false)
		player.weapon_unlocked[1] = true
		store.data["weapons"].append(DemoSaveStore.WEAPONS[1])
	func objective() -> String: return "Encontre os três selos."
	func seals_found() -> int: return 2
	func start_journey() -> void: started += 1
	func begin_new_journey() -> void: restarted += 1
	func save_and_quit() -> void: exited += 1
	func _save() -> bool:
		saves += 1
		return true
	func buy_skill(id: String) -> bool:
		if id in store.data["skills"]: return false
		store.data["skills"].append(id)
		return true

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func find_button(hud: Control, caption: String) -> Button:
	for child in hud.find_children("*", "Button", true, false):
		if child.text == caption or child.tooltip_text == caption: return child
	return null

func labels_fit(hud: Control) -> bool:
	for child in hud.get_children():
		if child is Label:
			var label: Label = child
			for line in label.text.split("\n"):
				if label.get_theme_font("font").get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x > label.size.x + 1:
					return false
	return true

func _run() -> void:
	root.content_scale_size = Vector2i(960, 540)
	root.size = Vector2i(960, 540)
	var demo := Demo.new()
	root.add_child(demo)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := Hud.new()
	hud.game = demo
	layer.add_child(hud)
	await process_frame
	hud.show_overlay("intro")
	check(paused and find_button(hud, "Nova jornada") != null, "Main menu pauses the world and exposes a native new-journey button")
	check(find_button(hud, "Retomar jornada").disabled, "Continue is disabled without saved progress")
	find_button(hud, "Nova jornada").pressed.emit()
	check(demo.started == 1, "First journey invokes the actual start callback")
	demo.store.loaded_existing = true
	hud.show_overlay("intro")
	find_button(hud, "Nova jornada").pressed.emit()
	check(hud.overlay == "new_journey", "Existing progress requires the in-game new-journey confirmation")
	find_button(hud, "Iniciar nova jornada").pressed.emit()
	check(demo.restarted == 1, "New-journey confirmation invokes its callback")
	hud.show_overlay("pause")
	check(hud.get_node_or_null("PauseNotebook") != null, "Pause opens the character page of the notebook")
	find_button(hud, "Configurações").pressed.emit()
	find_button(hud, "Controles").pressed.emit()
	check(hud.overlay == "controls" and paused, "Controls opens while gameplay remains paused")
	hud._back()
	check(hud.overlay == "settings", "Controls returns to its settings page")
	hud.show_overlay("pause")
	find_button(hud, "Continuar jornada").pressed.emit()
	check(hud.overlay == "" and not paused, "Continue unpauses gameplay")
	hud.show_overlay("pause")
	find_button(hud, "Inventário").pressed.emit()
	check(hud.overlay == "inventory", "Inventory is reachable through its real native button")
	hud.find_child("InventorySlot_" + DemoSaveStore.WEAPONS[1], true, false).pressed.emit()
	find_button(hud, "Equipar").pressed.emit()
	check(demo.player.weapon_index == 1 and demo.store.data["equipped"] == DemoSaveStore.WEAPONS[1], "Inventory equips the discovered alternate and updates save data")
	check(demo.saves == 1, "Equipping updates the session without requiring a disk save")
	check(labels_fit(hud), "Inventory descriptions fit their own cards without crossing adjacent content")
	hud.show_overlay("tree")
	check(labels_fit(hud), "Skill descriptions remain inside their cards")
	for room in PortLayout.ROOMS: demo.store.data["visited"].append(room["id"])
	hud.show_overlay("map")
	var scroll: ScrollContainer = hud.find_child("NotebookRooms", true, false)
	check(scroll != null and scroll.get_child(0).get_child_count() == PortLayout.ROOMS.size(), "The notebook map lists every revealed room")
	hud.show_overlay("settings")
	var before: bool = hud._limit_fps
	var limit_button: Button
	var old_hints := false
	for button in hud.find_children("*", "Button", true, false):
		if button.text.begins_with("Limite de 60"): limit_button = button
		if button.text.begins_with("Lembrete"): old_hints = true
	limit_button.pressed.emit()
	check(hud._limit_fps != before and FileAccess.file_exists("user://qa/ui_preferences.cfg"), "Frame preference still works and writes only the QA preference file")
	check(not old_hints and hud.HUD_STYLE_VERSION == 8, "Minimal HUD permanently removes the persistent movement command strip")
	hud.show_dialog("Prova", "Uma inscrição permanece legível.")
	check(hud.overlay == "dialog" and paused, "World dialogue API remains compatible")
	var dialog_scroll := false
	for child in hud.get_children():
		if child is ScrollContainer: dialog_scroll = true
	check(dialog_scroll, "World inscriptions can scroll without covering the back button")
	find_button(hud, "Voltar · Esc").pressed.emit()
	check(hud.overlay == "" and not paused, "Closing a world dialogue resumes gameplay")
	print("HUD V6 CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	demo.queue_free()
	layer.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
