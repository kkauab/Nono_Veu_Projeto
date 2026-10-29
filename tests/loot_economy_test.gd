extends SceneTree

# Economia de combate: XP, nível e óbolos deixados pelos inimigos.
# Rode sozinho para as regras e o save; acrescente -- --qa para o mundo real.
# Cada arquivo fica num slot próprio em user://qa; progress.json nunca é usado.
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")

var checks := 0
var failures: Array[String] = []
var session_dir: String


func _init() -> void:
	session_dir = "user://qa/loot_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_run.call_deferred()


func _run() -> void:
	create_timer(40.0).timeout.connect(_on_timeout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	_test_rules()
	_test_balance()
	_test_save()
	if "--qa" in OS.get_cmdline_user_args():
		await _test_world()
	else:
		print("NOTE world integration skipped; append -- --qa to enable it")
	print("LOOT_RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_rules() -> void:
	_check(Economy.level_for(0) == 1 and Economy.level_for(39) == 1, "level 1 lasts until the first 40 XP")
	_check(Economy.level_for(40) == 2 and Economy.level_for(100) == 3, "each level asks 20 XP more than the previous one")
	_check(Economy.level_progress(50) == Vector2i(10, 60), "progress counts XP inside the current level")
	_check(Economy.level_for(Economy.MAX_XP) == Economy.MAX_LEVEL, "level stops at the cap")
	_check(Economy.health_bonus(1) == 0 and Economy.health_bonus(3) == 10, "each level above 1 adds max health")
	_check(Economy.damage_bonus(2) == 0 and Economy.damage_bonus(3) == 1 and Economy.damage_bonus(5) == 2, "damage grows every two levels")
	var first := Economy.reward_for("vigia_mercado", "guard", false)
	_check(first == Economy.reward_for("vigia_mercado", "guard", false), "the same enemy always drops the same reward")
	_check(Economy.reward_for("x", "unknown", false)["xp"] == Economy.REWARDS["guard"]["xp"], "unknown archetype pays like a guard")
	var boss := Economy.reward_for("porteiro", "guard", true)
	_check(boss["xp"] == 120 and boss["coins"] >= 55 and boss["coins"] <= 65, "the boss pays its own table")
	var pieces_ok := true
	for total in range(0, 301):
		var pieces := Economy.coin_pieces(total)
		var sum := 0
		for piece in pieces: sum += piece
		if sum != total or pieces.size() > Economy.MAX_COIN_PIECES: pieces_ok = false
	_check(pieces_ok, "coins on the floor always add up to the reward, in at most %d pieces" % Economy.MAX_COIN_PIECES)
	_check(Economy.coin_pieces(7) == [5, 1, 1] and Economy.coin_pieces(60) == [25, 25, 5, 5], "large coins come first")
	var orbs_ok := true
	for total in range(0, 200):
		var orbs := Economy.xp_pieces(total)
		var sum := 0
		for orb in orbs: sum += orb
		if sum != total or orbs.size() > Economy.MAX_XP_ORBS: orbs_ok = false
	_check(orbs_ok, "XP orbs always add up to the reward")
	var data := SaveStore.fresh_data()
	_check(Economy.grant_xp(data, 39) == 0 and Economy.grant_xp(data, 1) == 1, "grant reports the level gained")
	_check(Economy.grant_xp(data, 160) == 2 and Economy.level(data) == 4, "one large grant can climb several levels")
	_check(Economy.grant_xp(data, -50) == 0 and Economy.xp(data) == 200, "negative XP is ignored")
	Economy.add_coins(data, 10)
	_check(not Economy.spend_coins(data, 15) and Economy.coins(data) == 10, "a price above the balance is refused")
	_check(not Economy.spend_coins(data, -5) and Economy.coins(data) == 10, "a negative price is refused")
	_check(Economy.spend_coins(data, 10) and Economy.coins(data) == 0, "an exact price empties the purse")
	Economy.add_coins(data, Economy.MAX_COINS + 50)
	_check(Economy.coins(data) == Economy.MAX_COINS, "the purse stops at its cap")


func _test_balance() -> void:
	# Todos os inimigos do Porto, uma vez: não renascem nesta demonstração.
	var xp := 0
	var coins := 0
	for spawn in Layout.ENEMY_SPAWNS:
		var reward := Economy.reward_for(spawn["id"], spawn.get("archetype", "guard"), spawn.get("boss", false))
		xp += reward["xp"]
		coins += reward["coins"]
	print("BALANCE enemies=%d xp=%d level=%d coins=%d" % [Layout.ENEMY_SPAWNS.size(), xp, Economy.level_for(xp), coins])
	_check(Economy.level_for(xp) >= 5 and Economy.level_for(xp) <= 8, "clearing the Port reaches level 5 to 8")
	_check(coins >= 200 and coins <= 400, "clearing the Port pays 200 to 400 coins for the shops")


func _test_save() -> void:
	var path := session_dir + "/save.json"
	var store: DemoSaveStore = SaveStore.new(path)
	_check(store.data["xp"] == 0 and store.data["coins"] == 0, "a new journey starts without XP or coins")
	Economy.grant_xp(store.data, 75)
	Economy.add_coins(store.data, 33)
	_check(store.save_progress(), "XP and coins are written")
	var reopened: DemoSaveStore = SaveStore.new(path)
	_check(reopened.load_progress() and Economy.xp(reopened.data) == 75 and Economy.coins(reopened.data) == 33, "XP and coins survive a reload")
	var legacy := SaveStore.fresh_data()
	legacy.erase("xp")
	legacy.erase("coins")
	_write(session_dir + "/legacy.json", JSON.stringify(legacy))
	var migrated: DemoSaveStore = SaveStore.new(session_dir + "/legacy.json")
	_check(migrated.load_progress() and migrated.data["xp"] == 0 and migrated.data["coins"] == 0, "a save from before the economy loads with zero XP and coins")
	var cases := [["coins", -5], ["coins", "muitos"], ["xp", 1.5], ["xp", 1000000]]
	for index in range(cases.size()):
		var invalid := SaveStore.fresh_data()
		invalid[cases[index][0]] = cases[index][1]
		var invalid_path := session_dir + "/invalid_%d.json" % index
		_write(invalid_path, JSON.stringify(invalid))
		_check(not SaveStore.new(invalid_path).load_progress(), "invalid %s value is rejected: %s" % cases[index])


func _test_world() -> void:
	var world: Node2D = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	var store: DemoSaveStore = world.get("store")
	_check(store.path.begins_with("user://qa/"), "world never reads the player's normal save slot")
	store.path = session_dir + "/world.json"
	var player: SenuPlayer = world.get("player")
	var hud: Control = world.get("hud")
	var enemy: VeilEnemy
	for candidate in get_nodes_in_group("enemies"):
		if candidate.enemy_id == "marinheiro_01": enemy = candidate
	_check(enemy != null, "the first sailor stands on the quay")
	if enemy == null:
		return
	var reward := Economy.reward_for(enemy.enemy_id, enemy.archetype, false)
	var base_health := player.max_health
	# O corpo some em menos de meio segundo; a posição fica guardada antes do golpe.
	var spot := enemy.position
	enemy.receive_hit(9999, spot + Vector2(-20, 0))
	await process_frame
	await process_frame
	var drops := get_nodes_in_group("loot")
	_check(drops.size() == Economy.xp_pieces(reward["xp"]).size() + Economy.coin_pieces(reward["coins"]).size(), "the defeated sailor drops XP orbs and coins")
	_check(Economy.coins(store.data) == 0 and Economy.xp(store.data) == 0, "nothing counts before Senu touches it")
	# Senu chega ao corpo; as moedas assentam e são atraídas.
	player.position = spot + Vector2(10, 4)
	for frame in range(150):
		await physics_frame
		if get_nodes_in_group("loot").is_empty(): break
	_check(get_nodes_in_group("loot").is_empty(), "every drop reaches Senu")
	_check(Economy.xp(store.data) == reward["xp"], "XP orbs credit the sailor's XP")
	_check(Economy.coins(store.data) == reward["coins"], "coins credit the sailor's coins")
	_check(int(hud.get("_loot_coins")) == reward["coins"] and float(hud.get("_loot_time")) > 0, "the HUD shows what was collected")
	_check("marinheiro_01" in store.data["defeated"], "the sailor stays defeated")
	var dummy := VeilEnemy.new()
	world.call("_drop_loot", "marinheiro_01", false, dummy)
	dummy.free()
	await process_frame
	_check(get_nodes_in_group("loot").is_empty(), "a defeated enemy never pays twice within the same rest cycle")
	await create_timer(1.3).timeout
	_check(not FileAccess.file_exists(store.path), "coins are not autosaved after the pickup timer")
	var tower: PortInteractable
	for item in get_nodes_in_group("interactables"):
		if item.get_parent() == world.actors and item.item_id == "hub": tower = item
	player.position = tower.position
	_check(world.activate(tower), "the tower anchors collected coins")
	var on_disk: DemoSaveStore = SaveStore.new(store.path)
	_check(on_disk.load_progress() and Economy.coins(on_disk.data) == reward["coins"], "coins are saved by the tower")
	var needed := Economy.xp_to_next(1) - Economy.xp(store.data)
	world.call("collect_loot", "xp", needed)
	_check(Economy.level(store.data) == 2 and player.max_health == base_health + Economy.HEALTH_PER_LEVEL, "level 2 raises Senu's max health")
	_check(str(hud.get("message")).begins_with("NÍVEL 2"), "the level-up is announced")
	world.call("collect_loot", "xp", Economy.xp_to_next(2))
	_check(Economy.level(store.data) == 3 and player.damage_bonus == Economy.damage_bonus(3), "level 3 adds damage")
	world.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _on_timeout() -> void:
	push_error("Loot test timed out before completion")
	quit(1)
