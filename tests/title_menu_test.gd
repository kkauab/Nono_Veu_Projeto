extends SceneTree
const Hud = preload("res://scripts/ui/game_hud_v6.gd")
const TitleButton = preload("res://scripts/ui/title_menu_button.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
const Feedback = preload("res://scripts/ui/ui_button_feedback.gd")
var checks := 0
var failures: Array[String] = []
var clicks := 0
class Demo extends Node2D:
	var store := DemoSaveStore.new("user://qa/title_menu_progress.json")
	var player: SenuPlayer
	var current_room := "hub"
	var nearest: Node2D
	var boss: Node2D
	var qa_mode := true
	var respawning := false
	var started := 0
	var restarted := 0
	var exited := 0
	func _ready() -> void:
		player = SenuPlayer.new()
		add_child(player)
		player.set_physics_process(false)
	func start_journey() -> void: started += 1
	func begin_new_journey() -> void: restarted += 1
	func save_and_quit() -> void: exited += 1
	func objective() -> String: return "Encontre os três selos."
	func seals_found() -> int: return 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		push_error(description)
func sound_count(hud: Control) -> int:
	var total := 0
	for node in hud.get_children():
		if node is TitleButton: total += node.animation_snapshot()["sound_count"]
	return total
func move_mouse(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	Input.parse_input_event(event)
	await process_frame
	await process_frame
func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.content_scale_size = Vector2i(960,540)
	Inputs.install()
	root.size = Vector2i(960,540)
	var demo := Demo.new()
	root.add_child(demo)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := Hud.new()
	hud.game = demo
	layer.add_child(hud)
	await process_frame
	await move_mouse(Vector2(20,20))
	hud.show_overlay("intro")
	await process_frame
	await process_frame
	check(paused, "Title presentation runs while gameplay is paused")
	check(hud._buttons.size() == 4, "All four original native title buttons remain available")
	var first: Button = hud._buttons[0]
	var resume: Button = hud._buttons[1]
	var settings: Button = hud._buttons[2]
	var exit: Button = hud._buttons[3]
	check(first is TitleButton and settings is TitleButton, "Only title buttons use the procedural presenter")
	check(sound_count(hud) == 0, "Initial programmatic focus is silent")
	check(resume.disabled, "Resume keeps its original unavailable state without a saved journey")
	var original_rect := first.get_global_rect()
	var original_text := first.text
	var original_data := JSON.stringify(demo.store.data)
	await move_mouse(first.get_global_rect().get_center())
	check(sound_count(hud) == 1, "Real pointer entry plays one selection sound, without a duplicate focus sound")
	check(first.animation_snapshot()["selected"], "Pointer entry selects its target")
	var audio: Node = root.get_meta(Feedback.POOL_KEY)
	check(audio._voices[0].stream.get_length() > .04 and audio._voices[0].bus == "SFX", "Selection uses the short dedicated sound on the effects bus")
	check(audio._voices.any(func(voice): return voice.playing), "The selection voice actually plays while the title pauses gameplay")
	first.set_process(false)
	var before: float = first.animation_snapshot()["amount"]
	first._process(.06)
	check(first.animation_snapshot()["amount"] > before and first.animation_snapshot()["amount"] < 1, "Highlight eases in rather than snapping to its final pose")
	for i in range(16): first._process(.025)
	check(first.get_global_rect() == original_rect and first.text == original_text, "Motion never moves the hit area, changes text or resizes the font")
	var held_count := sound_count(hud)
	for i in range(8): await move_mouse(first.get_global_rect().get_center() + Vector2(i,0))
	check(sound_count(hud) == held_count, "Moving inside the same button does not repeatedly sound")
	await move_mouse(Vector2(20,20))
	var lit: float = first.animation_snapshot()["amount"]
	first._process(.08)
	check(not first.animation_snapshot()["selected"] and first.animation_snapshot()["amount"] < lit, "Pointer exit recovers gradually to the resting plate")
	await move_mouse(first.get_global_rect().get_center())
	check(sound_count(hud) == held_count+1, "Re-entering the same still-focused button plays again")
	await move_mouse(resume.get_global_rect().get_center())
	check(sound_count(hud) == held_count+1 and not resume.animation_snapshot()["selected"], "Disabled resume cannot highlight or play a selection sound")
	await move_mouse(settings.get_global_rect().get_center())
	check(sound_count(hud) == held_count+2 and settings.animation_snapshot()["selected"] and not first.animation_snapshot()["selected"], "Moving to the next enabled option transfers selection and sounds once")
	await move_mouse(Vector2(20,20))
	var before_key := sound_count(hud)
	await key(KEY_TAB)
	check(exit.has_focus() and exit.animation_snapshot()["selected"], "Native Tab navigation still reaches the next menu action")
	check(sound_count(hud) == before_key+1, "Keyboard focus plays one selection sound")
	check(JSON.stringify(demo.store.data) == original_data and demo.started == 0 and demo.exited == 0, "Hover and focus cannot start a journey, exit, or change progress")
	await move_mouse(settings.get_global_rect().get_center())
	var mouse_click := InputEventMouseButton.new()
	mouse_click.button_index = MOUSE_BUTTON_LEFT
	mouse_click.position = settings.get_global_rect().get_center()
	mouse_click.global_position = mouse_click.position
	mouse_click.pressed = true
	Input.parse_input_event(mouse_click)
	mouse_click = mouse_click.duplicate()
	mouse_click.pressed = false
	Input.parse_input_event(mouse_click)
	await process_frame
	check(hud.overlay == "settings", "A real click still opens the production settings notebook")
	check(hud._buttons.is_empty(), "Closing the title destroys its animation and sound players")
	hud._back()
	await process_frame
	await process_frame
	check(hud.overlay == "intro" and sound_count(hud) == 0, "Returning to the title does not replay hover audio under a stationary pointer")
	demo.store.loaded_existing = true
	hud.show_overlay("intro")
	await process_frame
	await process_frame
	resume = hud._buttons[1]
	check(not resume.disabled, "Existing progress still enables resume")
	await move_mouse(resume.get_global_rect().get_center())
	check(resume.animation_snapshot()["selected"] and resume.animation_snapshot()["sound_count"] == 1, "Enabled resume receives the same hover presentation")
	resume.pressed.emit()
	check(demo.started == 1, "Resume retains its original start callback")
	hud.show_overlay("")
	layer.queue_free()
	demo.queue_free()
	await process_frame
	print("TITLE MENU checks=%d failures=%s" % [checks,failures])
	quit(0 if failures.is_empty() else 1)
