extends SceneTree
const Hud = preload("res://scripts/ui/game_hud_v6.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
var checks := 0
var failures: Array[String] = []
class Demo extends Node2D:
	var store := DemoSaveStore.new("user://qa/new_journey_popup_progress.json")
	var player: SenuPlayer
	var current_room := "hub"
	var nearest: Node2D
	var boss: Node2D
	var qa_mode := true
	var started := 0
	var restarted := 0
	var exited := 0
	var fail_restart := false
	var hud: Control
	func _ready() -> void:
		player = SenuPlayer.new()
		player.controls_enabled = false
		add_child(player)
		player.set_physics_process(false)
	func start_journey() -> void: started += 1
	func begin_new_journey() -> void:
		restarted += 1
		if fail_restart: hud.toast("Não foi possível arquivar o progresso. A jornada atual foi preservada.")
	func save_and_quit() -> void: exited += 1
	func objective() -> String: return "Encontre os três selos."
	func seals_found() -> int: return 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
func button(hud: Control, caption: String) -> Button:
	for child in hud.find_children("*","Button",true,false):
		if child.text == caption: return child
	return null
func click_at(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	Input.parse_input_event(motion)
	await process_frame
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = at
		event.global_position = at
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func key(code: Key) -> void:
	for down in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	Inputs.install()
	var demo := Demo.new()
	root.add_child(demo)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := Hud.new()
	hud.game = demo
	demo.hud = hud
	layer.add_child(hud)
	await process_frame
	demo.store.data["coins"] = 25
	check(demo.store.save_progress(), "Fixture writes only its named QA save")
	demo.store.loaded_existing = true
	var disk_before := FileAccess.get_file_as_string(demo.store.path)
	var data_before := JSON.stringify(demo.store.data)
	for dimensions in [Vector2i(960,540),Vector2i(1280,720)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		hud.show_overlay("intro")
		await process_frame
		await click_at(button(hud,"Nova jornada").get_global_rect().get_center())
		for i in range(3): await process_frame
		check(hud.overlay == "new_journey" and hud.has_node("NewJourneyPopup"), "New journey opens a compact popup over the title")
		var popup: Control = hud.get_node("NewJourneyPopup")
		var panel: PanelContainer = popup.find_child("PopupPanel",true,false)
		var confirm := button(popup,"Confirmar")
		var cancel := button(popup,"Cancelar")
		check(confirm != null and cancel != null and popup.find_children("*","Button",true,false).size() == 2, "Popup exposes exactly Confirmar and Cancelar")
		check(cancel.has_focus(), "Cancel receives initial keyboard focus")
		check(panel.size.x <= hud.size.x*.65 and panel.size.y <= hud.size.y*.65 and hud.get_global_rect().encloses(panel.get_global_rect()), "Popup stays compact and centered inside the window")
		var warning: Label = popup.find_child("OverwriteWarning",true,false)
		check(warning.text.contains("último save será sobrescrito") and panel.get_global_rect().encloses(warning.get_global_rect()), "Overwrite warning fits in the popup")
		var locked := true
		for choice in hud._buttons:
			locked = locked and choice.focus_mode == Control.FOCUS_NONE and choice.mouse_filter == Control.MOUSE_FILTER_IGNORE
		check(locked, "Background title buttons cannot receive focus or clicks")
		await key(KEY_TAB)
		check(confirm.has_focus(), "Tab moves from Cancel to Confirm")
		await key(KEY_TAB)
		check(cancel.has_focus(), "Tab wraps inside the popup instead of reaching the background")
		await key(KEY_LEFT)
		check(confirm.has_focus(), "Arrow navigation stays between the two choices")
		var before := demo.restarted
		await click_at(hud._offset + Vector2(115,310)*hud._factor)
		check(hud.overlay == "new_journey" and demo.restarted == before, "Clicking the dimmed title cannot activate the background New journey button")
		await key(KEY_ESCAPE)
		check(hud.overlay == "intro" and not hud.has_node("NewJourneyPopup"), "Escape cancels and restores the title menu")
		check(JSON.stringify(demo.store.data) == data_before and FileAccess.get_file_as_string(demo.store.path) == disk_before, "Opening and cancelling preserve session data and the saved bytes")
		hud.show_overlay("new_journey")
		for i in range(3): await process_frame
		await click_at(button(hud,"Cancelar").get_global_rect().get_center())
		check(hud.overlay == "intro" and demo.restarted == before, "Actual Cancel click never restarts or overwrites progress")
	hud.show_overlay("new_journey")
	for i in range(3): await process_frame
	var before := demo.restarted
	var confirm := button(hud,"Confirmar")
	confirm.pressed.emit()
	confirm.pressed.emit()
	check(demo.restarted == before+1, "Repeated confirmation in one frame invokes the restart callback only once")
	await process_frame
	demo.fail_restart = true
	await click_at(confirm.get_global_rect().get_center())
	check(demo.restarted == before+2 and hud.overlay == "new_journey", "A failed restart leaves the popup open for retry")
	check(hud.find_child("OverwriteWarning",true,false).text.contains("Não foi possível"), "Archive failure remains visible inside the compact popup")
	check(FileAccess.get_file_as_string(demo.store.path) == disk_before, "Popup presentation never writes or deletes the anchored save")
	hud.show_overlay("intro")
	demo.store.loaded_existing = false
	demo.store.data["flags"]["opening_seen"] = false
	await process_frame
	await click_at(button(hud,"Nova jornada").get_global_rect().get_center())
	check(demo.started == 1 and not hud.has_node("NewJourneyPopup"), "A first journey without saved progress retains its direct start")
	hud.show_overlay("")
	layer.queue_free()
	demo.queue_free()
	await process_frame
	print("NEW JOURNEY POPUP checks=%d failures=%s" % [checks,failures])
	quit(0 if failures.is_empty() else 1)
