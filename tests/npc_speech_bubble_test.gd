extends SceneTree

const Bubble = preload("res://scripts/ui/npc_speech_bubble.gd")
const Story = preload("res://scripts/world/port_story.gd")
const Quests = preload("res://scripts/world/port_quests.gd")
const IsleStory = preload("res://scripts/world/isle_story.gd")
const Life = preload("res://scripts/world/port_life.gd")
var world: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	check(world.store.path.begins_with("user://qa/"), "Conversation tests use an isolated save")
	for enemy in get_nodes_in_group("enemies"): enemy.queue_free()
	world.hud.show_overlay("")
	var hori := _item("npc_fisher")
	world.player.position = hori.position + Vector2(-40, 28)
	world.player.get_node("IsometricCamera").reset_smoothing()
	Story._talk_to_fisher(world)
	await process_frame
	var speech: Control = world.hud.get_node("NpcSpeechBubble")
	check(world.hud.overlay == "dialog" and paused, "A normal NPC conversation pauses exploration")
	check(speech.speaker_label.text == "Pescador" and speech._actor() == hori, "The fisherman speaks from his own actor")
	check(not speech.body_label.text.contains("PESCADOR —"), "Dialogue does not print a speaker prefix inside the speech")
	check(speech.pages[1]["speaker"] == "SENU", "Speaker changes remain separate turns")
	var first_body: String = speech.body_label.text
	await _key(KEY_E)
	speech = world.hud.get_node("NpcSpeechBubble")
	check(speech.page_index == 1 and speech.body_label.text != first_body, "E advances one speech turn")
	check(speech._actor() == world.player and speech.speaker_label.text == "Senu", "Senu's reply follows the player actor")
	world.hud._build_controls()
	await process_frame
	speech = world.hud.get_node("NpcSpeechBubble")
	check(speech.page_index == 1, "Rebuilding after a resize preserves the current turn")
	await _key(KEY_ESCAPE)
	check(world.hud.overlay.is_empty() and not paused, "Escape closes a conversation and resumes exploration")
	for id in Quests.QUESTS:
		world.talk_to_resident(id)
		await process_frame
		speech = world.hud.get_node("NpcSpeechBubble")
		check(speech.speaker_id == id.to_upper() and speech._actor() == _item("missao_tarek" if id == "tarek" else "loja_" + id), id + " uses its actual resident")
		for page in speech.pages:
			check(str(page["text"]).split("\n").size() <= Bubble.MAX_LINES, id + " has at most four lines per turn")
		world.hud.show_overlay("")
	IsleStory._talk_to_ankhet(world)
	await process_frame
	speech = world.hud.get_node("NpcSpeechBubble")
	check(speech.pages.any(func(page): return page["speaker"] == "MULHER"), "Ankhet's conversation is also presented as speech")
	var end_index: int = speech.pages.size() - 1
	while speech.page_index < end_index: speech.advance()
	await _key(KEY_E)
	check(world.hud.overlay.is_empty() and not paused, "Completing the final turn resumes play")
	world.hud.show_dialog("Inscrição", "Uma memória escrita na pedra.")
	check(world.hud.get_node_or_null("NpcSpeechBubble") == null, "Written inscriptions keep their existing reader")
	world.hud.show_overlay("")
	var resident: Node2D = get_nodes_in_group("townsfolk").filter(func(actor): return actor.kind == "townsfolk")[0]
	Life.activate(world, resident)
	await process_frame
	speech = world.hud.get_node("NpcSpeechBubble")
	check(speech.speaker_label.text == resident.title and speech._actor() == resident, "A passing resident also speaks from their own actor")
	world.hud.show_overlay("")
	await _layout_checks()
	print("NPC SPEECH CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _layout_checks() -> void:
	for resolution in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = resolution
		await process_frame
		world.hud._geometry()
		world.hud.show_conversation("Hori", "HORI — " + "As mãos lembram antes das palavras. ".repeat(16) + "\n\nSENU — Vou procurá-lo.", "npc_fisher")
		await process_frame
		await process_frame
		var speech: Control = world.hud.get_node("NpcSpeechBubble")
		check(speech.pages.size() > 2, "%s long speech is split into several turns" % resolution)
		var restored := ""
		for page in speech.pages:
			if page["speaker"] == "HORI": restored += str(page["text"]).replace("\n", " ") + " "
		check(restored.strip_edges() == "As mãos lembram antes das palavras. ".repeat(16).strip_edges(), "%s pagination preserves every word in order" % resolution)
		for _page in range(speech.pages.size()):
			speech._position_bubble()
			var rect: Rect2 = speech.panel.get_global_rect()
			check(Rect2(Vector2.ZERO, world.hud.size).encloses(rect), "%s balloon remains inside the screen" % resolution)
			check(speech.body_label.size.y >= speech.body_label.get_minimum_size().y, "%s text height fits the balloon" % resolution)
			if speech.page_index + 1 < speech.pages.size(): speech.advance()
			await process_frame
		world.hud.show_overlay("")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	await process_frame

func _item(id: String) -> Node2D:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id: return item
	return null
