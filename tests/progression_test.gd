extends SceneTree

# Run standalone, or append -- --qa to include the real world scene.
# Every file belongs to a unique user://qa slot; progress.json is never used.
const SaveStore = preload("res://scripts/save/save_store.gd")
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")

var checks: int = 0
var failures: Array[String] = []
var session_dir: String


func _init() -> void:
	session_dir = "user://qa/progression_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_run.call_deferred()


func _run() -> void:
	create_timer(25.0).timeout.connect(_on_timeout)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	_check(directory_error == OK, "isolated QA directory created")
	if directory_error != OK:
		_finish()
		return
	print("PROGRESSION_QA_SLOT ", ProjectSettings.globalize_path(session_dir))
	_test_roundtrip_and_backup()
	_test_invalid_schema()
	if "--qa" in OS.get_cmdline_user_args():
		await _test_world_events()
	else:
		print("NOTE world integration skipped; append -- --qa to enable it")
	_finish()


func _test_roundtrip_and_backup() -> void:
	var path: String = session_dir + "/roundtrip.json"
	var store: DemoSaveStore = SaveStore.new(path)
	_check(not store.load_progress(), "new slot has no previous progress")
	_check(store.collect("qa_fragment", 3), "first pickup grants its reward")
	_check(not store.collect("qa_fragment", 999), "same pickup cannot grant a second reward")
	_check(store.data["fragments"] == 3, "duplicate pickup does not alter balance")
	_check(not store.purchase("unknown_node"), "unknown skill cannot be purchased")
	_check(store.purchase("intelecto"), "two-point skill can be purchased with sufficient balance")
	_check(store.data["fragments"] == 1, "skill deducts its actual cost")
	_check(not store.purchase("intelecto"), "owned skill cannot be purchased twice")
	_check(store.data["fragments"] == 1, "duplicate purchase does not deduct again")
	_check(store.purchase("vontade"), "one-point skill consumes remaining point")
	_check(not store.purchase("materia"), "insufficient balance rejects another skill")
	_check(store.data["fragments"] == 0, "rejected purchase cannot create negative balance")
	_check(store.collect("qa_daggers", 0), "weapon pickup can be unique without granting currency")
	store.data["weapons"].append(SaveStore.WEAPONS[1])
	store.data["equipped"] = SaveStore.WEAPONS[1]
	store.data["checkpoint"] = "s1"
	store.data["flags"]["shortcut"] = true
	store.data["flags"]["boss"] = true
	store.data["flags"]["complete"] = true
	store.data["defeated"] = ["porteiro"]
	store.data["visited"] = ["hub", "p4", "a02"]
	var expected: Dictionary = store.data.duplicate(true)
	_check(store.save_progress(), "first snapshot is written to disk")
	_check(FileAccess.file_exists(path), "primary save exists on disk")
	_check(not FileAccess.file_exists(path + ".tmp"), "successful commit leaves no temporary save")
	var restored: DemoSaveStore = SaveStore.new(path)
	_check(restored.load_progress(), "new store reads an actual disk snapshot")
	_check(restored.loaded_existing, "load reports an existing valid snapshot")
	_check(_same_snapshot(restored.data, expected), "full state survives JSON roundtrip")
	_check(not restored.collect("qa_fragment", 3), "pickup remains consumed after reload")
	_check(not restored.purchase("intelecto"), "purchase remains unique after reload")
	_check(restored.data["equipped"] == SaveStore.WEAPONS[1], "equipped weapon is restored by stable ID")
	_check(restored.data["checkpoint"] == "s1", "checkpoint restores a named safe anchor")
	_check(restored.data["flags"]["shortcut"] and restored.data["flags"]["boss"] and restored.data["flags"]["complete"], "world flags survive reload")
	_check("porteiro" in restored.data["defeated"], "boss defeat survives reload")
	store.data["fragments"] = 2
	_check(store.save_progress(), "second snapshot commits and preserves backup")
	_check(FileAccess.file_exists(path + ".bak"), "previous committed snapshot exists as backup")
	print("NOTE malformed JSON fixtures below deliberately exercise backup recovery")
	_write_text(path, "{corrupted primary snapshot")
	var recovered: DemoSaveStore = SaveStore.new(path)
	_check(recovered.load_progress(), "corrupted primary falls back to actual backup file")
	_check(_same_snapshot(recovered.data, expected), "backup recovery restores the previous complete state")
	for skill_id: String in SaveStore.SKILLS:
		var definition: Dictionary = SaveStore.SKILLS[skill_id]
		_check(definition["requires"] is Array, "skill prerequisite list is explicit: " + skill_id)
	print("NOTE all current demo skills are root nodes (requires=[]); no configured dependent skill exists to exercise a missing-prerequisite purchase")


func _test_invalid_schema() -> void:
	var cases: Array[Dictionary] = [
		{"label": "unsupported version", "field": "version", "value": SaveStore.VERSION + 1},
		{"label": "negative balance", "field": "fragments", "value": -1},
		{"label": "string balance", "field": "fragments", "value": "three"},
		{"label": "invalid pickup collection type", "field": "collected", "value": {}},
		{"label": "non-string pickup ID", "field": "collected", "value": [123]},
		{"label": "unknown skill ID", "field": "skills", "value": ["invalid_skill"]},
		{"label": "unknown checkpoint name", "field": "checkpoint", "value": "outside_map"},
		{"label": "arbitrary checkpoint coordinates", "field": "checkpoint", "value": {"x": 999999, "y": -888888}},
		{"label": "equipped weapon not owned", "field": "equipped", "value": SaveStore.WEAPONS[1]},
		{"label": "missing starter inventory", "field": "weapons", "value": []},
		{"label": "non-boolean world flag", "field": "flags", "value": {"shortcut": "true", "boss": false, "complete": false}}
	]
	for index: int in range(cases.size()):
		var invalid: Dictionary = SaveStore.fresh_data()
		invalid[cases[index]["field"]] = cases[index]["value"]
		var path: String = session_dir + "/invalid_%d.json" % index
		_write_text(path, JSON.stringify(invalid))
		var rejected: DemoSaveStore = SaveStore.new(path)
		_check(not rejected.load_progress(), "invalid schema rejected: " + str(cases[index]["label"]))
		_check(rejected.data == SaveStore.fresh_data(), "rejected snapshot leaves fresh safe state: " + str(cases[index]["label"]))
	var malformed_path: String = session_dir + "/both_corrupted.json"
	_write_text(malformed_path, "not JSON")
	_write_text(malformed_path + ".bak", "[null, false]")
	var malformed: DemoSaveStore = SaveStore.new(malformed_path)
	_check(not malformed.load_progress(), "invalid primary and backup are rejected")
	_check(malformed.data["checkpoint"] == "hub", "invalid files fall back to a named hub checkpoint")


func _test_world_events() -> void:
	var world: Node2D = MainScene.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	_check(bool(world.get("qa_mode")), "world boots with QA isolation enabled")
	var store: DemoSaveStore = world.get("store")
	_check(store.path.begins_with("user://qa/"), "world never reads the player's normal save slot")
	store.path = session_dir + "/world.json"
	var player: SenuPlayer = world.get("player")
	var shortcut: PortGate = world.get("shortcut")
	var exit_gate: PortGate = world.get("exit_gate")
	_check(not shortcut.opened and not shortcut.get_node("Barrier").disabled, "shortcut initially blocks passage")
	_check(not exit_gate.opened and not exit_gate.get_node("Barrier").disabled, "boss seal initially blocks passage")
	for pickup_id: String in ["nous_cais", "nous_patio", "nous_arena"]:
		var pickup: PortInteractable = _find_item(world, pickup_id)
		_check(pickup != null, "world contains pickup " + pickup_id)
		if pickup == null:
			continue
		player.position = pickup.position
		_check(bool(world.call("activate", pickup)), "world interaction collects " + pickup_id)
		_check(not bool(world.call("activate", pickup)), "world interaction rejects duplicate " + pickup_id)
	_check(store.data["fragments"] == 3, "world pickup rewards are not duplicated")
	_check(bool(world.call("buy_skill", "materia")), "real skill purchase applies body upgrade")
	_check(player.max_health == 120, "body node modifies actual player maximum health")
	_check(not bool(world.call("buy_skill", "materia")), "real skill purchase cannot be repeated")
	_check(player.max_health == 120, "rejected duplicate does not stack player upgrade")
	_check(bool(world.call("buy_skill", "vontade")), "real skill purchase applies combat upgrade")
	_check(player.damage_bonus == 4, "combat node modifies actual player damage bonus")
	_check(not bool(world.call("buy_skill", "intelecto")), "world rejects skill beyond remaining balance")
	var daggers: PortInteractable = _find_item(world, "adagas")
	_check(daggers != null, "alternative weapon exists in world")
	if daggers != null:
		player.position = daggers.position
		_check(bool(world.call("activate", daggers)), "actual weapon pickup unlocks the inventory")
		_check(player.equip_weapon(1), "actual player equips discovered daggers")
		_check(store.data["equipped"] == SaveStore.WEAPONS[1], "equipment signal updates the saved weapon ID")
	var lever: PortInteractable = _find_item(world, "alavanca")
	_check(lever != null, "shortcut lever exists")
	if lever != null:
		player.position = lever.position
		_check(bool(world.call("activate", lever)), "lever interaction opens the actual shortcut")
		await process_frame
		_check(shortcut.opened and shortcut.get_node("Barrier").disabled, "opening shortcut disables its physical collider")
		_check(store.data["flags"]["shortcut"], "lever event persists shortcut flag")
	var shrine: PortInteractable = _find_item(world, "s1")
	_check(shrine != null, "pre-boss checkpoint exists")
	if shrine != null:
		player.position = shrine.position
		_check(bool(world.call("activate", shrine)), "meditation chooses named checkpoint")
		player.position = Vector2(999999, -888888)
		player.invulnerability_timer = 0.0
		player.receive_hit(player.max_health + 1, player.position + Vector2.LEFT)
		await create_timer(1.65).timeout
		var anchors: Dictionary = world.get("checkpoints")
		_check(player.position.is_equal_approx(Layout.iso(anchors["s1"])), "death returns to safe checkpoint instead of arbitrary previous coordinates")
		_check(store.data["fragments"] == 1, "death preserves remaining exploration currency")
	var boss: VeilEnemy = world.get("boss")
	_check(is_instance_valid(boss), "actual boss exists before defeat")
	if is_instance_valid(boss):
		boss.receive_hit(boss.max_health + 1, player.position)
		await process_frame
		_check(store.data["flags"]["boss"] and "porteiro" in store.data["defeated"], "boss damage emits defeat and persists its ID")
		_check(exit_gate.opened and exit_gate.get_node("Barrier").disabled, "boss defeat signal opens seal and disables collider")
	var restored: DemoSaveStore = SaveStore.new(store.path)
	_check(restored.load_progress(), "world events produce a readable actual save")
	_check(_same_snapshot(restored.data, store.data), "world inventory, upgrades, checkpoint and flags roundtrip together")
	_check(not restored.collect("nous_cais"), "world pickup remains consumed in a new store")
	_check(not restored.collect("adagas", 0), "world weapon pickup remains unique in a new store")
	world.free()
	await process_frame


func _find_item(world: Node2D, item_id: String) -> PortInteractable:
	var actors: Node2D = world.get("actors")
	for child: Node in actors.get_children():
		if child is PortInteractable and child.item_id == item_id:
			return child as PortInteractable
	return null


func _write_text(path: String, contents: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "test fixture can be written: " + path.get_file())
	if file == null:
		return
	file.store_string(contents)
	file.flush()
	file.close()


func _same_snapshot(actual: Dictionary, expected: Dictionary) -> bool:
	# Godot JSON loads numbers as floats. Normalize only the expected serialized
	# representation so dictionary equality does not mistake int/float for loss.
	return actual == JSON.parse_string(JSON.stringify(expected))


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _finish() -> void:
	print("PROGRESSION_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _on_timeout() -> void:
	push_error("Progression test timed out before completion")
	quit(1)
