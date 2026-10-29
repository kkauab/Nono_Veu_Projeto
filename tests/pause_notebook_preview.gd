extends SceneTree
const Main = preload("res://scenes/boot/main.tscn")
const Houses = preload("res://scripts/world/houses.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Shop = preload("res://scripts/economy/shop_catalog.gd")
var world

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	world.hud.show_overlay("")
	world.hud._process(.01)
	Houses._arrive(world, "emporio_merit", true)
	world.player.get_node("IsometricCamera").force_update_scroll()
	world.store.data["fragments"] = 5
	world.store.data["coins"] = 126
	world.store.data["weapons"].append("l01_adagas_reverso")
	world.player.weapon_unlocked[1] = true
	for id in Shop.ITEMS: Shop.grant(world.store.data, id)
	world._apply_upgrades(true)
	for room in Layout.ROOMS:
		if room["id"] not in ["secret", "echo_descent", "echo_gallery", "isle"] and not room["id"] in world.store.data["visited"]:
			world.store.data["visited"].append(room["id"])
	for id in ["merit", "nakht", "adiam", "tarek"]: world.store.data["collected"].append("quest_started_" + id)
	world.store.data["collected"].append("fisher_met")
	world.hud._selected_quest = "merit"
	for page in ["pause", "journal", "map", "tree", "inventory", "settings", "controls", "exit"]:
		world.hud.show_overlay(page)
		await _capture("notebook_v8_" + page)
	world.hud.show_overlay("pause")
	var notebook: Control = world.hud.get_node("PauseNotebook")
	notebook.get_node("SenuAction_attack").pressed.emit()
	await create_timer(.15).timeout
	await _capture("notebook_v8_senu_attack")
	root.size = Vector2i(960, 540)
	await process_frame
	world.hud._geometry()
	world.hud.show_overlay("inventory")
	await _capture("notebook_v8_inventory_960")
	world.hud.show_overlay("")
	quit()

func _capture(id: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://qa/" + id + ".png")
	print("CAPTURE ", id)
