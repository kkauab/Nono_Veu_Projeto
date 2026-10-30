extends SceneTree
const Boss=preload("res://scripts/actors/nameless_gatekeeper.gd")
const Tools=preload("res://tests/gatekeeper_test_tools.gd")
const Inventory=preload("res://scripts/economy/inventory_catalog.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _world(path: String="") -> Node2D:
	var game=load("res://scenes/boot/main.tscn").instantiate()
	game.qa_save_path=path
	root.add_child(game)
	game.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):enemy.set_physics_process(false)
	game.player.set_physics_process(false)
	game.hud.show_overlay("")
	return game
func _item(game: Node2D,id: String) -> PortInteractable:
	for node in game.actors.get_children():
		if node is PortInteractable and node.item_id==id:return node
	return null
func _dispose(game: Node2D) -> void:
	game.hud.show_overlay("")
	game.queue_free()
	await process_frame
	await process_frame
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():quit(1);return
	var game:=_world()
	await process_frame
	var boss: Boss=game.boss
	game.store.data["checkpoint"]="s1"
	for flag in ["seal_bells","seal_water","seal_stars"]:game.store.data["flags"][flag]=true
	game.player.position=boss.position+Vector2(90,0)
	boss.begin_intro()
	game.gatekeeper_encounter._process(.02)
	check(paused and game.hud.get_node_or_null("NpcSpeechBubble")!=null,"Intro enters the existing conversation UI")
	game.hud.show_overlay("") # Escape/close follows the same release path.
	game.gatekeeper_encounter._process(.02)
	check(not paused and game.player.controls_enabled and boss.encounter_active,"Closing dialogue cannot leave controls or pause locked")
	check(not game.player.get_node("IsometricCamera").top_level,"Cutscene camera returns to Senu")
	boss.mode=Boss.Mode.APPROACH
	boss.phase=2
	boss.start_attack("echo_charge")
	game.player.apply_movement_slow(.8,.6,"gatekeeper")
	game.player.invulnerability_timer=0
	game.player.receive_hit(9999,boss.position)
	check(boss.health==boss.max_health and boss.phase==1 and not boss.performance.active,"Senu death resets health, phase and delayed attacks")
	check(game.boss_entry_gate.opened and not game.gatekeeper_encounter.gate_locked,"Failed attempt releases the entrance")
	check(game.player._slow_scale==1 and game.player._slow_seconds==0,"Failed attempt clears chain slow")
	await create_timer(1.65).timeout
	check(not game.player.dead and game.player.position==PortLayout.iso(PortLayout.MARKERS["s1"]),"Retry returns to the existing Guarita tower checkpoint")
	check(not FileAccess.file_exists(game.store.path),"A failed attempt does not save the journey")
	Tools.defeat(game)
	await process_frame
	check(game.store.data["flags"]["boss"] and game.store.data["fragments"]==2,"Actual sequence completion awards the victory once")
	var marks: Array=game.store.data["collected"].duplicate()
	check("gatekeeper_reward" in marks and "gatekeeper_key_spear" in marks,"Stable reward IDs share the existing collected list")
	check(game.store.data["weapons"].size()==1 and game.store.data["skills"].is_empty(),"Victory does not invent equipment slots or unlock Reverso skills")
	var entries:=Inventory.entries(game.store.data)
	var spears:=entries.filter(func(e):return e["id"]=="gatekeeper_key_spear")
	check(spears.size()==1 and spears[0]["kind"]=="heirloom" and not spears[0].has("weapon_index"),"Key-spear is a visible unique modular reward with no false equip action")
	var before:=FileAccess.file_exists(game.store.path)
	check(not before,"Victory remains in memory before a tower")
	var tower:=_item(game,"s1")
	game.player.position=tower.position
	check(game.activate(tower),"Existing tower anchors the whole boss transaction")
	await process_frame
	await process_frame
	var saved_path: String=game.store.path
	var saved:=DemoSaveStore.new(saved_path)
	check(saved.load_progress() and saved.data["flags"]["boss"] and "porteiro" in saved.data["defeated"],"Tower snapshot includes the original boss flag and ID")
	check(saved.data["fragments"]==2 and "gatekeeper_key_spear" in saved.data["collected"],"Tower snapshot includes Nous and key-spear ownership together")
	await _dispose(game)
	game=_world(saved_path)
	await process_frame
	check(game.boss is Boss and game.boss.mode==Boss.Mode.DEAD and game.boss.health==0,"Actual reload restores a human corpse, not a live boss")
	check(not game.boss.is_in_group("enemies") and game.boss.collision_layer==0,"Loaded corpse is not a combat target or an obstacle")
	check(game.exit_gate.opened and game.boss_entry_gate.opened,"Actual reload restores the free passage")
	var remains:=_item(game,"gatekeeper_remains")
	game.player.position=remains.position
	check(game.activate(remains),"Corpse belongings can be examined after reload")
	check(game.store.data["fragments"]==2,"Examining a new-victory corpse cannot pay the reward twice")
	await _dispose(game)
	# A genuinely old flag-only victory offers recovery explicitly, not on load.
	var legacy_path:="user://qa/gatekeeper_legacy_%d.json"%Time.get_ticks_usec()
	var legacy:=DemoSaveStore.new(legacy_path)
	legacy.data["flags"]["boss"]=true
	legacy.data["defeated"]=["porteiro"]
	check(legacy.save_progress(),"Legacy QA fixture is written outside real progress")
	game=_world(legacy_path)
	await process_frame
	check(game.boss.mode==Boss.Mode.DEAD and game.store.data["fragments"]==0 and "gatekeeper_reward" not in game.store.data["collected"],"Legacy load neither revives the boss nor silently gives rewards")
	remains=_item(game,"gatekeeper_remains")
	game.player.position=remains.position
	game.activate(remains)
	game.hud.show_overlay("")
	game.activate(remains)
	check(game.store.data["fragments"]==2,"Legacy recovery is explicit and unique")
	var unchanged:=DemoSaveStore.new(legacy_path)
	check(unchanged.load_progress() and unchanged.data["fragments"]==0,"Legacy recovery still waits for a tower to write disk")
	await _dispose(game)
	game=_world()
	await process_frame
	game.boss.begin_intro()
	game.gatekeeper_encounter._process(.02)
	check(paused,"Teardown test starts inside an active cutscene")
	game.queue_free()
	await process_frame
	check(not paused,"Leaving a scene during a cutscene releases global pause")
	print("GATEKEEPER PERSISTENCE checks=%d passed=%d failures=%s"%[checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
