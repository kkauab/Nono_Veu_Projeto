extends SceneTree

# Casas, fase 3: Forja de Nakht (dano por arma) e Tenda de Adiam (mapa, vida e
# esquiva). Regras rodam sozinhas; -- --qa usa o mundo real e --capture-shop3
# (Godot com janela) salva as capturas das duas salas e do mapa.
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Catalog = preload("res://scripts/world/house_catalog.gd")
const KHOPESH := "e01_khopesh_discipulo"
const DAGGERS := "l01_adagas_reverso"

var checks := 0
var failures: Array[String] = []
var session_dir: String
var world: Node2D


func _init() -> void:
	session_dir = "user://qa/shop3_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_run.call_deferred()


func _run() -> void:
	create_timer(80.0).timeout.connect(_on_timeout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	_test_rules()
	if "--qa" in OS.get_cmdline_user_args():
		await _test_world()
	else:
		print("NOTE world integration skipped; append -- --qa to enable it")
	print("SHOP3 RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_rules() -> void:
	var data := SaveStore.fresh_data()
	Economy.add_coins(data, 1000)
	_check(Shop.blocker(data, "tempera_adagas") == "Precisa das Adagas do Reverso", "the daggers' temper waits for the daggers")
	_check(Shop.blocker(data, "tempera_khopesh").begins_with("Precisa de: Pedra"), "the khopesh temper waits for the whetstone")
	_check(Shop.purchase(data, "pedra_amolar"), "the whetstone is sold")
	_check(Shop.damage_bonus(data, KHOPESH) == 2 and Shop.damage_bonus(data, DAGGERS) == 2, "the whetstone helps every weapon")
	_check(Shop.purchase(data, "tempera_khopesh") and Shop.damage_bonus(data, KHOPESH) == 5 and Shop.damage_bonus(data, DAGGERS) == 2, "the khopesh temper helps only the khopesh")
	data["weapons"].append(DAGGERS)
	_check(Shop.purchase(data, "tempera_adagas") and Shop.damage_bonus(data, DAGGERS) == 4 and Shop.damage_bonus(data, KHOPESH) == 5, "the daggers' temper helps only the daggers")
	_check(Shop.health_bonus(data) == 0 and is_equal_approx(Shop.dodge_scale(data), 1.0) and not Shop.reveals_map(data), "the Forge changes neither life, dodge nor map")
	_check(Shop.purchase(data, "amuleto_cornalina") and Shop.health_bonus(data) == 10, "the carnelian adds 10 life")
	_check(Shop.purchase(data, "sandalias_caravana") and is_equal_approx(Shop.dodge_scale(data), .85), "the sandals speed the dodge by 15%")
	_check(Shop.purchase(data, "mapa_rotas") and Shop.reveals_map(data), "the route map is sold")
	_check(Economy.coins(data) == 1000 - 45 - 70 - 60 - 70 - 55 - 30, "each item was paid once")
	var all_sold := true
	for id in Shop.SHOPS["nakht"] + Shop.SHOPS["adiam"]:
		if Shop.blocker(data, id) != "Esgotado": all_sold = false
	_check(all_sold, "every Forge and Tent item is sold once")
	var path := session_dir + "/save.json"
	var store: DemoSaveStore = SaveStore.new(path)
	store.data = data
	_check(store.save_progress(), "the purchases are written")
	var reopened: DemoSaveStore = SaveStore.new(path)
	_check(reopened.load_progress() and Shop.damage_bonus(reopened.data, DAGGERS) == 4 and Shop.health_bonus(reopened.data) == 10 and Shop.reveals_map(reopened.data), "Forge and Tent purchases survive a reload")


func _test_world() -> void:
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.store.path = session_dir + "/world.json"
	var player: SenuPlayer = world.player
	var hud: Control = world.hud
	world.store.data["coins"] = 600
	world.store.data["weapons"].append(DAGGERS)
	player.weapon_unlocked[1] = true
	var damage := player.damage_bonus
	var life := player.max_health
	var dodge := player.dodge_cooldown
	await _enter("forja_nakht")
	_check(world.inside_house == "forja_nakht" and world.current_room == "kilns", "Senu is inside the Forge, in the Kilns district")
	await _open_shop("loja_nakht", "Falar com Nakht")
	_check(hud.shop_id == "nakht" and hud.dialog_title == "Forja de Nakht", "Nakht's shop opens")
	var temper := _button(hud, "Comprar · 70")
	_check(temper != null and temper.disabled, "the khopesh temper waits for the whetstone")
	_button(hud, "Comprar · 45").pressed.emit()
	await process_frame
	_check(player.damage_bonus == damage + 2, "the whetstone raises damage at once")
	_button(hud, "Comprar · 70").pressed.emit()
	await process_frame
	_check(player.damage_bonus == damage + 5, "the khopesh temper adds 3 with the khopesh in hand")
	_button(hud, "Comprar · 60").pressed.emit()
	await process_frame
	_check(player.damage_bonus == damage + 5, "the daggers' temper does not touch the khopesh")
	_check(Economy.coins(world.store.data) == 600 - 175, "the Forge charged 175")
	if "--capture-shop3" in OS.get_cmdline_user_args():
		await _capture("loja_nakht_painel")
	hud.show_overlay("")
	await process_frame
	_check(player.equip_weapon(1) and world.store.data["equipped"] == DAGGERS, "Senu draws the daggers")
	_check(player.damage_bonus == damage + 4, "with the daggers, whetstone and daggers' temper count")
	_check(player.equip_weapon(0) and player.damage_bonus == damage + 5, "back to the khopesh, its temper counts again")
	world.store.data["equipped"] = DAGGERS
	world._apply_upgrades(false)
	_check(player.damage_bonus == damage + 4, "a journey reopened with the daggers starts with their bonus")
	world.store.data["equipped"] = KHOPESH
	world._apply_upgrades(false)
	if "--capture-shop3" in OS.get_cmdline_user_args():
		await _capture("loja_nakht_dentro")
	await _leave("forja_nakht")
	_check(world.inside_house == "" and world.current_room == "kilns", "Senu is back in the Kilns")
	await _enter("tenda_adiam")
	_check(world.inside_house == "tenda_adiam" and world.current_room == "caravan", "Senu is inside the Tent, at the Caravan Gate")
	await _open_shop("loja_adiam", "Falar com Adiam")
	_check(hud.shop_id == "adiam" and hud.dialog_title == "Tenda de Adiam", "Adiam's shop opens")
	var health := player.health
	_button(hud, "Comprar · 70").pressed.emit()
	await process_frame
	_check(player.max_health == life + 10 and player.health == mini(health + 10, player.max_health), "the carnelian raises life and its ceiling")
	_button(hud, "Comprar · 55").pressed.emit()
	await process_frame
	_check(is_equal_approx(player.dodge_cooldown, dodge * .85), "the sandals shorten the dodge cooldown")
	_button(hud, "Comprar · 30").pressed.emit()
	await process_frame
	_check(Shop.reveals_map(world.store.data) and Economy.coins(world.store.data) == 600 - 175 - 155, "the route map is bought and the Tent charged 155")
	if "--capture-shop3" in OS.get_cmdline_user_args():
		await _capture("loja_adiam_painel")
	hud.show_overlay("")
	await process_frame
	if "--capture-shop3" in OS.get_cmdline_user_args():
		await _capture("loja_adiam_dentro")
	hud.show_overlay("map")
	await process_frame
	await process_frame
	_check(hud.overlay == "map", "the map opens with the route outlines")
	if "--capture-shop3" in OS.get_cmdline_user_args():
		await _capture("mapa_rotas")
	hud.show_overlay("")
	_check(not FileAccess.file_exists(world.store.path), "Forge and Tent purchases are not autosaved")
	await _leave("tenda_adiam")
	var shrine := _fixture("caravan_rest")
	world.player.position = shrine.position
	_check(world.activate(shrine), "A real tower anchors Forge and Tent purchases")
	var on_disk: DemoSaveStore = SaveStore.new(world.store.path)
	_check(on_disk.load_progress() and Shop.owned(on_disk.data, "sandalias_caravana") == 1 and Shop.owned(on_disk.data, "tempera_adagas") == 1, "Forge and Tent purchases persist after the tower")
	world.queue_free()
	await process_frame


func _enter(id: String) -> void:
	world.player.position = Layout.iso(Catalog.HOUSES[id]["outside"])
	await physics_frame
	world.activate(_fixture("porta_" + id))
	await create_timer(.7).timeout
	await physics_frame


func _leave(id: String) -> void:
	world.player.position = Layout.iso(Catalog.HOUSES[id]["spawn"])
	await physics_frame
	world.activate(_fixture("saida_" + id))
	await create_timer(.7).timeout
	await physics_frame


func _open_shop(id: String, caption: String) -> void:
	var keeper := _fixture(id)
	world.player.position = keeper.position + Vector2(0, 14)
	await physics_frame
	_check(world.nearest == keeper and keeper.label == caption, "standing in front, %s is the nearest interaction" % caption.trim_prefix("Falar com "))
	_check(world.activate(keeper) and world.hud.overlay == "shop" and paused, "the shop opens and pauses the game")


func _button(hud: Control, caption: String) -> Button:
	for child in hud.get_children():
		if child is Button and child.text == caption: return child
	return null


func _fixture(id: String) -> PortInteractable:
	for item in get_nodes_in_group("interactables"):
		if item.item_id == id: return item
	return null


func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	root.get_texture().get_image().save_png("res://qa/%s.png" % name)
	print("CAPTURE_SAVED ", name)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Forge and Tent test timed out before completion")
	quit(1)
