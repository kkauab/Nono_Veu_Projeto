extends SceneTree

const Hud = preload("res://scripts/ui/game_hud_v6.gd")
const Skills = preload("res://scripts/progression/skill_catalog.gd")
var checks := 0
var failures: Array[String] = []

class Demo extends Node2D:
	var store := DemoSaveStore.new("user://qa/skill_tree_ui_progress.json")
	var player: SenuPlayer
	var current_room := "hub"
	var nearest: Node2D
	var boss: Node2D
	var respawning := false
	var qa_mode := true
	var purchases := 0
	func _ready() -> void:
		player = SenuPlayer.new()
		add_child(player)
		player.set_physics_process(false)
	func objective() -> String: return "Encontre as três lembranças."
	func seals_found() -> int: return 0
	func buy_skill(id: String) -> bool:
		if not store.purchase(id): return false
		purchases += 1
		return true

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	root.content_scale_size = Vector2i.ZERO
	for action in ["pause_game", "skill_tree", "world_map", "attack", "weapon_power", "dodge", "parry", "switch_weapon", "move_left", "move_right", "move_up", "move_down"]:
		if not InputMap.has_action(action): InputMap.add_action(action)
	var demo := Demo.new()
	root.add_child(demo)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var hud := Hud.new()
	hud.game = demo
	layer.add_child(hud)
	await process_frame
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await process_frame
		demo.store.data = DemoSaveStore.fresh_data()
		demo.store.data["fragments"] = 22
		hud._selected_skill = "vontade"
		hud.show_overlay("tree")
		await process_frame
		var page: Control = hud.find_child("SkillBookPage", true, false)
		check(paused and page.nodes.size() == 13, "%s: tree pauses the world and exposes all 13 nodes" % resolution)
		check(page.hold_button != null and not page.hold_button.disabled, "%s: root can be learned with available Nous" % resolution)
		var balance: int = demo.store.data["fragments"]
		var purchases := demo.purchases
		page.nodes["convergencia_nous"].pressed.emit()
		check(demo.store.data["fragments"] == balance and demo.purchases == purchases, "%s: selecting a node never buys it" % resolution)
		check(hud._selected_skill == "convergencia_nous" and page.hold_button.disabled, "%s: final node explains locked prerequisites" % resolution)
		check(not page.nodes["convergencia_nous"].disabled, "%s: locked nodes remain inspectable" % resolution)
		check(page.hold_button.tooltip_text.contains("Contra-ataque ágil") and page.hold_button.tooltip_text.contains("Esquiva etérea"), "%s: missing prerequisites have their actual names" % resolution)
		for id in Skills.ORDER:
			page.select_skill(id)
			for detail in page._detail_root.get_children():
				if not detail is Label: continue
				var label: Label = detail
				var label_font := label.get_theme_font("font")
				var point_size := label.get_theme_font_size("font_size")
				for line in label.text.split("\n"):
					check(label.autowrap_mode != TextServer.AUTOWRAP_OFF or label_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, point_size).x <= label.size.x + 1, "%s: %s detail stays within its panel" % [resolution, id])
				check(label.get_rect().end.x <= hud.size.x and label.get_rect().end.y <= hud.size.y, "%s: %s detail stays within the viewport" % [resolution, id])
			page.nodes[id].grab_focus()
			check(hud._selected_skill == id, "%s: keyboard focus selects %s" % [resolution, id])
		for id in ["vontade", "ritmo_lamina"]:
			page.select_skill(id)
			check(not page.hold_button.disabled, "%s: prerequisite path unlocks %s" % [resolution, id])
			page.hold_button.pressed.emit()
			check(not id in demo.store.data["skills"], "%s: a click alone cannot learn %s" % [resolution, id])
			page.begin_hold()
			page.advance_hold(1.5)
			check(id in demo.store.data["skills"], "%s: holding the learn button buys %s" % [resolution, id])
			check(page.hold_button.disabled and page.hold_button.text == "Aprendida", "%s: owned %s cannot be bought twice" % [resolution, id])
		check(demo.store.data["fragments"] == balance - 3 and demo.purchases == purchases + 2, "%s: only actual purchases debit the exact cost" % resolution)
		var selected: String = hud._selected_skill
		hud._build_controls()
		await process_frame
		page = hud.find_child("SkillBookPage", true, false)
		check(hud._selected_skill == selected and page.nodes[selected].has_focus(), "%s: rebuild preserves selected node and keyboard focus" % resolution)
		demo.store.data["fragments"] = 0
		page.select_skill("materia")
		check(page.hold_button.disabled and page.hold_button.text == "Nous insuficiente", "%s: insufficient Nous is distinct from missing prerequisite" % resolution)
		if DisplayServer.get_name() != "headless":
			demo.store.data["fragments"] = 19
			page.select_skill("selo_mercurio" if resolution.y == 720 else "convergencia_nous")
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			capture.save_png("res://qa/skill_tree_%dp.png" % resolution.y)
		hud.show_overlay("")
		check(not paused, "%s: closing the tree resumes the world" % resolution)
	print("SKILL TREE UI CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	demo.queue_free()
	layer.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
