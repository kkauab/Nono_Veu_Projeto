extends SceneTree
## Real world events against a unique QA slot; desktop/reload side effects are
## intercepted so their file behavior can be tested without ending this runner.
const World = preload("res://scripts/world/port_demo.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Quests = preload("res://scripts/world/port_quests.gd")
var checks := 0
var failures: Array[String] = []

class ProbeWorld extends "res://scripts/world/port_demo.gd":
	var exit_requests := 0
	var restart_requests := 0
	var opening_requests := 0
	func _exit_to_desktop() -> void: exit_requests += 1
	func _restart_for_new_journey() -> void: restart_requests += 1
	func _play_opening() -> void: opening_requests += 1

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Use -- --qa; this test never reads the real progress file")
		quit(1)
		return
	var world := ProbeWorld.new()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	_silence(world)
	world.store.path = "user://qa/tower_only_%d_%d/progress.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	world.hud.show_overlay("")
	_check(world.qa_mode and world.store.path.begins_with("user://qa/"), "World starts in an isolated QA slot")
	_check(not FileAccess.file_exists(world.store.path), "Opening the world does not create a progress file")
	world.store.data["fragments"] = 10
	world.store.data["coins"] = 200
	var pickup := _item(world, "nous_cais")
	world.player.position = pickup.position
	_check(world.activate(pickup), "A real unique pickup updates the session")
	_check(world.buy_skill("vontade"), "A skill is learned and applied in memory")
	_check(world.buy_item("jarro_balsamo"), "A shop item is bought and applied in memory")
	Quests.talk(world, "merit")
	world.hud.show_overlay("")
	world.collect_loot("coin", 9)
	await create_timer(1.1).timeout
	_check(not FileAccess.file_exists(world.store.path), "Pickups, purchases, quests, learning and delayed loot updates never create an autosave")
	_check(world.has_unsaved_progress(), "Session changes are identified as unanchored progress")
	world.player.health = 11
	world.store.data["items"]["balsamo"] = 0
	var first_enemy := _regular_enemy(world)
	first_enemy.receive_hit(9999, first_enemy.position)
	var enemy_id := first_enemy.enemy_id
	await process_frame
	var shrine := _item(world, "hub")
	world.player.position = shrine.position
	_check(world.activate(shrine), "Interacting with a tower anchors the current session")
	await process_frame
	await process_frame
	_check(FileAccess.file_exists(world.store.path), "The tower actually creates the save file")
	_check(world.player.health == world.player.max_health and world.store.data["items"]["balsamo"] == 1, "Tower rest still restores life and consumables")
	var renewed := _enemy(world, enemy_id)
	_check(renewed != null and not renewed.dead and enemy_id not in world.store.data["defeated"], "Tower saving renews common enemies and their reward cycle")
	_check(not world.has_unsaved_progress(), "The anchored state matches the successful tower save")
	var path: String = world.store.path
	var anchored := FileAccess.get_file_as_string(path)
	var stored := SaveStore.new(path)
	_check(stored.load_progress() and "vontade" in stored.data["skills"] and "quest_started_merit" in stored.data["collected"], "The tower includes learned skills, discoveries and accepted quests")
	world.store.collect("unanchored_discovery", 1)
	_check(world.buy_skill("materia") and world.buy_item("mirra"), "Further skills and purchases continue to function before the next tower")
	world.collect_loot("coin", 5)
	world._flush_loot_save()
	renewed.receive_hit(9999, renewed.position)
	await process_frame
	_check(FileAccess.get_file_as_string(path) == anchored, "Further purchases, combat, coins and discoveries leave the last tower file byte-for-byte unchanged")
	_check(world.has_unsaved_progress(), "Further changes remain unanchored")
	world.quit_without_save()
	world.save_and_quit()
	world._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(world.exit_requests == 3, "Exit, legacy exit and window-close request the desktop exit path")
	_check(FileAccess.get_file_as_string(path) == anchored and renewed.dead, "Exiting never writes progress or begins a new enemy cycle")
	_check(world.store.archive_progress(), "The previous anchored journey can be archived safely")
	var archives := ProjectSettings.globalize_path(path.get_base_dir().path_join("archives"))
	var archive_matches := true
	for archive in DirAccess.get_files_at(archives):
		if FileAccess.get_file_as_string(archives.path_join(archive)) != anchored: archive_matches = false
	_check(archive_matches, "Archives copy the last disk save, not unsaved session discoveries")
	world.begin_new_journey()
	_check(world.restart_requests == 1 and has_meta("nono_fresh_journey"), "Starting anew requests a fresh in-memory scene")
	_check(FileAccess.get_file_as_string(path) == anchored, "Starting a new journey preserves the old slot until its first tower")
	var fresh := ProbeWorld.new()
	fresh.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(fresh)
	await process_frame
	_silence(fresh)
	_check(fresh.store.data["skills"].is_empty() and fresh.store.data["coins"] == 0 and not fresh.store.loaded_existing, "The new scene starts with fresh session data")
	_check(fresh.opening_requests == 1 and not has_meta("nono_fresh_journey"), "The fresh journey consumes its marker and begins the opening")
	fresh.hud.show_overlay("")
	fresh.store.path = path
	fresh.quit_without_save()
	_check(FileAccess.get_file_as_string(path) == anchored, "Leaving that fresh session before a tower retains the previous journey")
	var reread := SaveStore.new(path)
	_check(reread.load_progress() and not "materia" in reread.data["skills"] and not "unanchored_discovery" in reread.data["collected"], "Reloading restores exactly the last anchored progress")
	var fresh_shrine := _item(fresh, "hub")
	fresh.player.position = fresh_shrine.position
	_check(fresh.activate(fresh_shrine), "The first tower can intentionally replace the previous slot with the new journey")
	await process_frame
	await process_frame
	reread = SaveStore.new(path)
	_check(reread.load_progress() and reread.data["skills"].is_empty() and reread.data["coins"] == 0, "That explicit tower writes the new journey state")
	world.queue_free()
	fresh.queue_free()
	await process_frame
	print("TOWER ONLY SAVE checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _item(world: Node2D, id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.get_parent() == world.actors and item.item_id == id: return item
	return null

func _enemy(world: Node2D, id: String) -> VeilEnemy:
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get_parent() == world.actors and enemy.enemy_id == id: return enemy
	return null

func _regular_enemy(world: Node2D) -> VeilEnemy:
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get_parent() == world.actors and not enemy.is_boss: return enemy
	return null

func _silence(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D: node.stop()
	for child in node.get_children(): _silence(child)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)
