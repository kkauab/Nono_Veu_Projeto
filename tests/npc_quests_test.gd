extends SceneTree

const Main = preload("res://scenes/boot/main.tscn")
const Quests = preload("res://scripts/world/port_quests.gd")
const Story = preload("res://scripts/world/port_story.gd")
var world
var checks := 0
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	check(world.store.path.begins_with("user://qa/"), "Quest test never opens the real save")
	for item in world.actors.get_children():
		if item is PortInteractable and item.kind in ["quest_object", "fisher_bell"]:
			check(PortLayout.tile_catalog().has(Vector2i(PortLayout.unproject(item.position).round())), item.item_id + " is on real floor")
			var clear := true
			for prop in world.actors.get_children():
				if prop is PortProp and prop.solid and prop.blocks_ground_point(item.position, 8): clear = false
			check(clear, item.item_id + " is accessible outside scenery foundations")
	check(Quests.entries(world.store.data).is_empty(), "New journal does not claim quests were accepted")
	# An item discovered before its owner's request is kept, not lost.
	use("quest_mirra")
	check("quest_mirra" in world.store.data["collected"] and Quests.journal_text(world.store.data).contains("Merit"), "Early discovery is retained and its owner appears in the journal")
	var expected := int(world.store.data["coins"])
	for id in Quests.QUESTS:
		var quest: Dictionary = Quests.QUESTS[id]
		check(world.talk_to_resident(id), "Resident offers " + id + " quest")
		check("quest_started_" + id in world.store.data["collected"], "Acceptance of " + id + " persists")
		if quest.has("item"):
			if quest["item"] not in world.store.data["collected"]: use(quest["item"])
			check(Quests.ready(world.store.data, id), "Collected item makes " + id + " ready")
		else:
			check(not Quests.ready(world.store.data, id), "Survey initially requires both locations")
			world.store.data["visited"].append("aqueduct")
			check(not Quests.ready(world.store.data, id), "One location cannot finish the survey")
			world.store.data["visited"].append("beacon")
			check(Quests.ready(world.store.data, id), "Both explored locations finish the survey")
		world.talk_to_resident(id)
		expected += int(quest["reward"])
		check("quest_done_" + id in world.store.data["collected"] and int(world.store.data["coins"]) == expected, id + " gives its exact one-time reward")
		world.talk_to_resident(id)
		check(int(world.store.data["coins"]) == expected, id + " cannot pay twice")
	check(Quests.entries(world.store.data).size() == 4, "Journal lists the four resident quests")
	for entry in Quests.entries(world.store.data): check(entry["done"], "Journal marks " + entry["name"] + " completed")
	var tardy := item("missao_tarek")
	world.player.position = tardy.position
	world.hud.show_overlay("")
	check(world.activate(tardy), "Tarek is an actual interactable in the guard house")
	world.hud.show_shop("Empório de Merit", "merit", "Teste")
	var conversation: Button
	for child in world.hud.get_children():
		if child is Button and child.text == "Conversar · missão": conversation = child
	check(conversation != null, "Shop exposes a separate mission conversation button")
	conversation.pressed.emit()
	check(world.hud.overlay == "dialog", "Mission button opens the resident's actual dialogue")
	world.hud.show_overlay("")
	var event := InputEventAction.new()
	event.action = "quest_journal"
	event.pressed = true
	world.hud._unhandled_input(event)
	check(world.hud.overlay == "journal" and paused, "N opens the actual paused quest journal")
	world.hud.show_overlay("")
	# A legacy journey waiting after the brother discovery now has a clear route.
	world.store.data["collected"].append_array(["fisher_met", "fisher_brother_found"])
	Story.refresh(world)
	check(Story.fisher_objective(world.store.data).contains("Hori"), "Legacy stuck quest tells the player to return to Hori")
	use("npc_fisher")
	check("fisher_knot" in world.store.data["collected"], "Legacy quest receives the next item")
	use("npc_brother")
	check("fisher_knot_shown" in world.store.data["collected"] and Story.fisher_objective(world.store.data).contains("sino"), "Showing the knot creates a concrete local objective")
	use("fisher_bell")
	check(Story.fisher_objective(world.store.data).contains("Sabu"), "Ringing the bell guides the return to Sabu")
	use("npc_brother")
	check("fisher_named" in world.store.data["collected"] and not world.store.data["flags"]["boss"], "Fisher quest advances without a mandatory boss victory")
	var nous := int(world.store.data["fragments"])
	use("npc_fisher")
	check("fisher_done" in world.store.data["collected"] and int(world.store.data["fragments"]) == nous + 2, "Reunion keeps the original two-Nous reward")
	check(item("npc_brother").position == PortLayout.iso(Story.BROTHER_HOME_TILE), "Sabu actually returns to the quay")
	use("npc_fisher")
	check(int(world.store.data["fragments"]) == nous + 2, "Reunion cannot pay twice")
	use("hub")
	await process_frame
	await process_frame
	var restored := DemoSaveStore.new(world.store.path)
	check(restored.load_progress(), "Expanded quest progress reloads from disk")
	check(Quests.journal_text(restored.data) == Quests.journal_text(world.store.data), "Journal states persist across sessions")
	world.hud.show_overlay("")
	_silence(world)
	world.queue_free()
	await process_frame
	print("NPC_QUESTS ", checks - failures.size(), "/", checks, " ", failures)
	quit(0 if failures.is_empty() else 1)

func item(id: String) -> PortInteractable:
	for node in world.actors.get_children():
		if node is PortInteractable and node.item_id == id: return node
	return null

func use(id: String) -> void:
	world.hud.show_overlay("")
	var target := item(id)
	check(target != null, "Interaction exists: " + id)
	world.player.position = target.position
	check(world.activate(target), "Interaction succeeds: " + id)

func _silence(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _silence(child)
