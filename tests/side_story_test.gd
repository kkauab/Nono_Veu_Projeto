extends SceneTree
## Iri's trail and the fisherman's brother: where they stand, every step of both
## stories, and their state after the save is reopened. Runs in a QA slot.

const Story = preload("res://scripts/world/port_story.gd")
var world: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("side_story_test requires -- --qa")
		quit(1)
		return
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	world.hud.show_overlay("")
	check(world.store.path.begins_with("user://qa/"), "Side story test never uses the real save")
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	await physics_frame
	_placement()
	await _iri_trail()
	await _fisherman()
	_after_reopening()
	print("SIDE STORY CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _story_items() -> Array:
	return world.actors.get_children().filter(func(node): return node is PortInteractable and (node.kind in ["iri_mark", "iri_relic", "npc"]))

func _placement() -> void:
	var items := _story_items()
	check(items.size() == 7, "Four marks, the relic, Hori and Sabu are in the port (%d)" % items.size())
	var catalog := PortLayout.tile_catalog()
	for item in items:
		var tile := PortLayout.unproject(item.position)
		check(catalog.has(Vector2i(tile.round())), "%s stands on a floor tile" % item.item_id)
		var clear := true
		for other in world.actors.get_children():
			if other is PortProp and other.solid and other.blocks_ground_point(item.position, 8):
				clear = false
			elif other is PortInteractable and other != item and other.position.distance_to(item.position) < 40:
				clear = false
		check(clear, "%s has room for Senu and no other interaction on top of it" % item.item_id)
	check(Story.MARKS.keys().map(func(id): return PortLayout.room_at(PortLayout.iso(Story.MARKS[id]["tile"]))) == ["archive", "oracle", "buried", "p4"], "The marks are in the Archive, Observatory, Buried Sanctuary and Guard post")

func _iri_trail() -> void:
	var fragments := int(world.store.data["fragments"])
	check(not await use_item("iri_relic") and int(world.store.data["fragments"]) == fragments, "The relic stays shut without the four marks")
	check(world.hud.dialog_body.contains("0 deles brilham"), "The shut relic tells how many marks shine")
	var read := 0
	for id in Story.MARKS:
		check(await use_item(id), "Mark %s can be read" % id)
		read += 1
		check(Story.marks_read(world) == read and world.hud.dialog_body.contains("Marcas de Iri: %d de 4" % read if read < 4 else "apontam para o Santuário"), "Reading %s counts the trail (%d/4)" % [id, read])
	await use_item("iri_mark_archive")
	check(Story.marks_read(world) == 4 and not world.hud.dialog_body.contains("◆"), "Rereading a mark neither counts again nor repeats the progress line")
	check(await use_item("iri_relic") and int(world.store.data["fragments"]) == fragments + Story.RELIC_REWARD, "The four marks open Iri's relic and its reward")
	check(world.hud.dialog_title == "O que Iri deixou" and not find_item("iri_relic").active, "The relic shows Iri's message and stays open")
	check(not await use_item("iri_relic") and int(world.store.data["fragments"]) == fragments + Story.RELIC_REWARD, "The relic cannot be emptied twice")

func _fisherman() -> void:
	await use_item("npc_brother")
	check(world.hud.dialog_title == "O homem das cordas" and "fisher_brother_found" in world.store.data["collected"], "Finding Sabu before Hori records the discovery instead of losing it")
	await use_item("npc_fisher")
	check("fisher_met" in world.store.data["collected"] and "fisher_knot" in world.store.data["collected"], "Hori recognizes the early discovery and immediately gives the knot")
	check(find_item("npc_fisher").label == "Falar com Hori", "The fisherman is called by his name after meeting him")
	await use_item("npc_brother")
	check("fisher_knot_shown" in world.store.data["collected"] and find_item("npc_brother").label == "Falar com Sabu", "Sabu recognizes the knot and gives the next concrete objective")
	world.store.data["flags"]["boss"] = false
	await use_item("npc_brother")
	check(not "fisher_named" in world.store.data["collected"] and world.hud.dialog_body.contains("sino"), "Before the bell Sabu explains the objective without requiring the boss")
	await use_item("fisher_bell")
	check("fisher_bell_rung" in world.store.data["collected"], "The pier bell answers the fisherman's memory")
	await use_item("npc_brother")
	check("fisher_named" in world.store.data["collected"] and find_item("npc_brother").opened and not world.store.data["flags"]["boss"], "Sabu remembers Hori and the quest advances before defeating the boss")
	var fragments := int(world.store.data["fragments"])
	await use_item("npc_fisher")
	check("fisher_done" in world.store.data["collected"] and int(world.store.data["fragments"]) == fragments + Story.FISHER_REWARD, "Hori's thanks closes the story with its reward")
	check(find_item("npc_brother").position == PortLayout.iso(Story.BROTHER_HOME_TILE), "Sabu goes back to the quay beside his brother")
	await use_item("npc_fisher")
	check(int(world.store.data["fragments"]) == fragments + Story.FISHER_REWARD and world.hud.dialog_body.contains("entardecer"), "Talking again gives no second reward")

func _after_reopening() -> void:
	world.hud.show_overlay("")
	var tower := find_item("hub")
	world.player.position = tower.position
	check(world.activate(tower), "A tower anchors both completed stories")
	var reopened := DemoSaveStore.new(world.store.path)
	check(reopened.load_progress(), "The journey with both stories reopens")
	for id in ["iri_mark_archive", "iri_mark_oracle", "iri_mark_buried", "iri_mark_guard", "iri_relic", "fisher_met", "fisher_brother_found", "fisher_knot", "fisher_named", "fisher_done"]:
		check(id in reopened.data["collected"], "%s survives the save" % id)
	# Rebuild the story objects from the reopened save, as a new session would.
	for item in _story_items():
		world.actors.remove_child(item)
		item.free()
	world.store = reopened
	Story.build(world)
	check(not find_item("iri_relic").active and find_item("iri_relic").opened, "A reopened save keeps Iri's relic open")
	check(find_item("npc_brother").position == PortLayout.iso(Story.BROTHER_HOME_TILE) and find_item("npc_brother").opened, "A reopened save keeps Sabu on the quay, remembered")
	check(find_item("iri_mark_oracle").label == "Reler a marca de Iri", "A reopened save remembers the marks already read")

func find_item(id: String) -> PortInteractable:
	for object in world.actors.get_children():
		if object is PortInteractable and object.item_id == id:
			return object
	return null

func use_item(id: String) -> bool:
	var target := find_item(id)
	if target == null:
		check(false, "Interaction exists: " + id)
		return false
	world.hud.show_overlay("")
	world.player.position = target.position
	await physics_frame
	return world.activate(target)
