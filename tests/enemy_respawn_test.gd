extends SceneTree
## Somente o descanso na torre grava e inicia um ciclo de encontros.
## O mundo fica desativado e todos os arquivos pertencem a user://qa.

const Main = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Economy = preload("res://scripts/economy/economy.gd")
var world: Node2D
var regular_spawns: Array = []
var checks := 0
var failures: Array[String] = []
var permanent: Dictionary

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func _run() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("enemy_respawn_test requires -- --qa; normal progress is never opened")
		quit(1)
		return
	for spawn in Layout.ENEMY_SPAWNS:
		if not spawn.get("boss", false): regular_spawns.append(spawn)
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	_silence(world)
	world.store.path = "user://qa/enemy_respawn_%d_%d/progress.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	world.hud.show_overlay("")
	check(world.qa_mode and world.store.path.begins_with("user://qa/"), "Only a unique QA save slot is used")
	_check_population(world, true, "Initial population")
	await _live_reset_and_progress()
	await _death_and_rewards()
	await _removed_and_queued_bodies()
	await _save_failure()
	await _boss_and_last_tower()
	world.queue_free()
	await process_frame
	print("ENEMY_RESPAWN_RESULT checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _live_reset_and_progress() -> void:
	var pickup := _item("nous_cais")
	world.player.position = pickup.position
	check(world.activate(pickup) and world.buy_skill("vontade"), "A unique pickup can fund an actual persistent skill")
	world.store.collect("fisher_met", 0)
	world.store.data["puzzles"]["stars"] = [1, 0, 2]
	world.store.data["flags"]["water_clue"] = true
	permanent = _progress_snapshot()
	var enemy := _enemy(world, regular_spawns[0]["id"])
	var identity := enemy.get_instance_id()
	enemy.position += Vector2(90, 35)
	enemy.health = 7
	enemy.state = VeilEnemy.State.WINDUP
	enemy.state_timer = .8
	enemy._knockback = Vector2(30, 20)
	world.player.health = 9
	world.player._hit_delay = .1
	world.player._second_hit_delay = .2
	world.player.attack_timer = .8
	var shrine := _item("hub")
	world.player.position = shrine.position + Vector2(14, 2)
	var rest_position: Vector2 = world.player.global_position
	var projectile: Node2D = world.player._spawn_mercury(Vector2.RIGHT, 9999, 3)
	check(projectile.is_in_group("mercury_projectiles"), "A pending offensive projectile exists before resting")
	check(world.activate(shrine), "Meditating saves and begins a new enemy cycle")
	check(not world.activate(shrine), "A second meditation cannot overlap deferred renewal")
	await _deferred()
	enemy = _enemy(world, regular_spawns[0]["id"])
	check(enemy.get_instance_id() == identity, "A living enemy is reset without creating another actor")
	check(enemy.health == enemy.max_health and enemy.state == VeilEnemy.State.WAIT and enemy.state_timer == 0, "Living enemy health, attack state and timer are reset")
	check(enemy.position.is_equal_approx(Layout.iso(regular_spawns[0]["tile"])) and enemy._knockback == Vector2.ZERO, "The living enemy returns to its original position without knockback")
	check(enemy.collision_layer == 4 and enemy.collision_mask == 7, "Renewed enemy collision remains enabled")
	check(world.player.health == world.player.max_health and world.player.global_position.is_equal_approx(rest_position), "Rest heals at the same position")
	check(world.player._hit_delay < 0 and world.player._second_hit_delay < 0 and world.player.attack_timer == 0, "Rest cancels pending melee contacts before enemies return")
	check(not is_instance_valid(projectile) and _owned_group(world, "mercury_projectiles").is_empty(), "Rest removes pending Mercury projectiles")
	check(_progress_snapshot() == permanent and "vontade" in world.store.data["skills"], "Rest preserves Nous, skill ownership, puzzle state and mission progress")
	_check_population(world, true, "After living enemy reset")

func _death_and_rewards() -> void:
	var id: String = regular_spawns[0]["id"]
	var enemy := _enemy(world, id)
	var reward := Economy.reward_for(id, enemy.archetype, false)
	enemy.receive_hit(9999, enemy.position)
	var corpse_id := enemy.get_instance_id()
	await _deferred()
	check(is_instance_valid(enemy) and enemy.dead, "Disabled world retains the fresh corpse before its .45-second lifetime")
	check(id in world.store.data["defeated"], "Death records the current encounter cycle in memory")
	check(_loot_value("xp") == reward["xp"] and _loot_value("coin") == reward["coins"], "First kill creates exactly one XP and coin reward")
	enemy.receive_hit(9999, enemy.position)
	world._drop_loot(id, false, enemy)
	await _deferred()
	check(_loot_value("xp") == reward["xp"] and _loot_value("coin") == reward["coins"], "Duplicate death or reward callback cannot pay twice within a cycle")
	var pickup := _item("nous_market")
	world.player.position = pickup.position
	check(world.activate(pickup), "A pickup updates the current session")
	var clue := _item("water_clue")
	world.player.position = clue.position
	check(world.activate(clue), "A clue updates the current puzzle session")
	world.hud.show_overlay("")
	world.collect_loot("coin", 1)
	world._flush_loot_save()
	check(_enemy(world, id) == enemy and enemy.dead and id in world.store.data["defeated"], "Pickup, puzzle and loot memory updates do not renew a defeated enemy")
	permanent = _progress_snapshot()
	check(await _rest(), "Rest accepts a recently defeated enemy")
	var renewed := _enemy(world, id)
	check(renewed != null and renewed.get_instance_id() != corpse_id and not renewed.dead, "The fresh corpse is replaced by one living enemy")
	check(id not in world.store.data["defeated"], "Rest clears the common enemy's previous-cycle marker")
	check(_loot_value("xp") == reward["xp"] and _loot_value("coin") == reward["coins"], "Uncollected legitimate rewards survive the new cycle")
	await _collect_drops()
	var xp_before := Economy.xp(world.store.data)
	var coins_before := Economy.coins(world.store.data)
	renewed.receive_hit(9999, renewed.position)
	await _deferred()
	check(_loot_value("xp") == reward["xp"] and _loot_value("coin") == reward["coins"], "Defeating the renewed enemy earns one new reward")
	await _collect_drops()
	check(Economy.xp(world.store.data) == xp_before + int(reward["xp"]) and Economy.coins(world.store.data) == coins_before + int(reward["coins"]), "Each legitimate cycle pays exactly once into the saved economy")
	check(await _rest(), "Second encounter cycle can finish normally")

func _removed_and_queued_bodies() -> void:
	var id: String = regular_spawns[1]["id"]
	var removed := _enemy(world, id)
	removed.receive_hit(9999, removed.position)
	# Drive only the corpse clock: the rest of the world remains disabled.
	removed._physics_process(.6)
	await _deferred()
	check(not is_instance_valid(removed) and _enemy(world, id) == null, "A body past its lifetime is actually removed")
	check(await _rest() and _enemy(world, id) != null and not _enemy(world, id).dead, "Rest recreates an enemy whose corpse already disappeared")
	var queued_id: String = regular_spawns[2]["id"]
	var queued := _enemy(world, queued_id)
	queued.receive_hit(9999, queued.position)
	queued.queue_free()
	check(queued.is_queued_for_deletion(), "The next corpse is explicitly queued for deletion")
	check(await _rest(), "Rest also accepts an already queued corpse in the same frame")
	check(not is_instance_valid(queued) and _enemy(world, queued_id) != null and not _enemy(world, queued_id).dead, "Queued deletion cannot remove the replacement enemy")
	for cycle in range(3):
		check(await _rest(), "Repeated meditation succeeds: %d" % cycle)
		_check_population(world, true, "Repeated meditation %d" % cycle)
	await _collect_drops()

func _save_failure() -> void:
	var defeated_id: String = regular_spawns[3]["id"]
	var corpse := _enemy(world, defeated_id)
	corpse.receive_hit(9999, corpse.position)
	var live := _enemy(world, regular_spawns[4]["id"])
	live.health = 19
	live.position += Vector2(40, 9)
	var prior_position: Vector2 = live.position
	world.store.data["purchases"]["jarro_balsamo"] = 1
	world.store.data["items"]["balsamo"] = 0
	var defeated_before: Array = world.store.data["defeated"].duplicate()
	var checkpoint_before: String = world.store.data["checkpoint"]
	var real_path: String = world.store.path
	check(FileAccess.file_exists(real_path), "Failure fixture starts from a real isolated save file")
	# The existing file cannot also be the directory of another save.
	world.store.path = real_path.path_join("cannot_write.json")
	world.player.health = 17
	var shrine := _item("cistern_rest")
	world.player.position = shrine.position
	check(not world.activate(shrine), "An impossible save path rejects meditation")
	await _deferred()
	check(world.store.data["defeated"] == defeated_before and world.store.data["checkpoint"] == checkpoint_before, "Failed save restores defeated IDs and the previous checkpoint")
	check(world.store.data["items"]["balsamo"] == 0 and world.player.health == 17, "Failed save neither refills items nor heals")
	check(live.health == 19 and live.position.is_equal_approx(prior_position) and corpse.dead, "Failed save leaves both live enemies and corpses unchanged")
	check(not world._enemy_renewal_pending, "Failed save schedules no deferred renewal")
	world.store.path = real_path
	await _collect_drops()
	check(await _rest(), "A successful meditation remains possible after save recovery")

func _boss_and_last_tower() -> void:
	var boss: VeilEnemy = world.boss
	var boss_id := boss.enemy_id
	preload("res://tests/gatekeeper_test_tools.gd").defeat(world)
	await _deferred()
	check(world.store.data["flags"]["boss"] and boss_id in world.store.data["defeated"], "Defeating the boss records its permanent flag and ID")
	await _collect_drops()
	check(await _rest(), "Meditation still succeeds after the boss victory")
	check(_enemy(world, boss_id) == null and world.store.data["flags"]["boss"] and boss_id in world.store.data["defeated"], "A defeated boss stays absent and its ID survives the new cycle")
	_check_population(world, false, "After boss victory")
	var regular_id: String = regular_spawns[5]["id"]
	var enemy := _enemy(world, regular_id)
	enemy.receive_hit(9999, enemy.position)
	await _collect_drops()
	world.player.health = 23
	var anchored := FileAccess.get_file_as_string(world.store.path)
	world._save()
	check(FileAccess.get_file_as_string(world.store.path) == anchored and enemy.dead, "Ordinary synchronization neither writes the file nor renews an enemy")
	check(await _rest(), "Only the next tower anchors the new encounter cycle")
	check(world.player.health == world.player.max_health and _enemy(world, regular_id) != null and not _enemy(world, regular_id).dead, "Tower saving heals and renews the current actors")
	var restored := DemoSaveStore.new(world.store.path)
	check(restored.load_progress(), "The tower encounter-cycle save reopens from disk")
	check(regular_id not in restored.data["defeated"] and boss_id in restored.data["defeated"], "The saved next cycle contains the boss victory and no common defeat")
	check(restored.data["skills"] == world.store.data["skills"] and restored.data["collected"] == world.store.data["collected"] and restored.data["puzzles"] == JSON.parse_string(JSON.stringify(world.store.data["puzzles"])), "Tower saving preserves skills, unique discoveries, mission steps and puzzles")
	var reloaded_world: Node2D = Main.instantiate()
	reloaded_world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(reloaded_world)
	await process_frame
	_silence(reloaded_world)
	# Rebuild the same spawn loop used by _ready, with the actual restored state.
	reloaded_world.store = restored
	for old in _owned_group(reloaded_world, "enemies"):
		old.free()
	reloaded_world.boss = null
	for spawn in Layout.ENEMY_SPAWNS:
		reloaded_world._spawn_enemy(spawn["id"], spawn["tile"], spawn.get("boss", false), spawn.get("archetype", "guard"))
	_check_population(reloaded_world, false, "Restored tower-save population")
	check(_enemy(reloaded_world, regular_id) != null and _enemy(reloaded_world, boss_id) == null, "Loading the next cycle recreates commons and omits the defeated boss")
	reloaded_world.queue_free()
	await process_frame

func _rest() -> bool:
	var shrine := _item("hub")
	world.player.position = shrine.position + Vector2(10, 0)
	var accepted: bool = world.activate(shrine)
	await _deferred()
	return accepted

func _deferred() -> void:
	await process_frame
	await process_frame

func _silence(node: Node) -> void:
	# The disabled fixture does not advance the sea's audio process. Stop its
	# looping playback explicitly so the audio thread releases it before exit.
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		node.stop()
	for child in node.get_children():
		_silence(child)

func _owned_group(owner: Node2D, group: String) -> Array:
	return get_nodes_in_group(group).filter(func(node): return node.get_parent() == owner.actors)

func _enemy(owner: Node2D, id: String) -> VeilEnemy:
	for enemy in _owned_group(owner, "enemies"):
		if enemy.enemy_id == id: return enemy
	return null

func _item(id: String) -> PortInteractable:
	for item in _owned_group(world, "interactables"):
		if item.item_id == id: return item
	return null

func _loot_value(kind: String) -> int:
	var total := 0
	for drop in _owned_group(world, "loot"):
		if drop.kind == kind: total += drop.value
	return total

func _collect_drops() -> void:
	await _deferred()
	for drop in _owned_group(world, "loot"):
		drop._collect()
	await _deferred()

func _check_population(owner: Node2D, include_boss: bool, context: String) -> void:
	var seen := {}
	var valid := true
	for enemy in _owned_group(owner, "enemies"):
		if seen.has(enemy.enemy_id) or enemy.dead or enemy.is_queued_for_deletion(): valid = false
		seen[enemy.enemy_id] = true
	for spawn in regular_spawns:
		if not seen.has(spawn["id"]): valid = false
	check(valid and seen.size() == regular_spawns.size() + int(include_boss), context + ": exactly one living actor per expected spawn")

func _progress_snapshot() -> Dictionary:
	return {
		"fragments": world.store.data["fragments"],
		"collected": world.store.data["collected"].duplicate(),
		"skills": world.store.data["skills"].duplicate(),
		"puzzles": world.store.data["puzzles"].duplicate(true),
		"water_clue": world.store.data["flags"]["water_clue"]
	}
