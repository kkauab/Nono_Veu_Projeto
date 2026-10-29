extends SceneTree

# Casas, fase 2: Empório de Merit, painel da loja, compras e cargas no save,
# tecla R e recarga nos santuários. Regras e save rodam sozinhos; acrescente
# -- --qa para o mundo real e --capture-shop (Godot com janela) para as capturas.
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Catalog = preload("res://scripts/world/house_catalog.gd")
const ID := "emporio_merit"

var checks := 0
var failures: Array[String] = []
var session_dir: String
var world: Node2D


func _init() -> void:
	session_dir = "user://qa/shop_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(_on_timeout)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	_test_rules()
	_test_save()
	if "--qa" in OS.get_cmdline_user_args():
		await _test_world()
	else:
		print("NOTE world integration skipped; append -- --qa to enable it")
	print("SHOP RESULT checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)


func _test_rules() -> void:
	var data := SaveStore.fresh_data()
	_check(Shop.blocker(data, "jarro_balsamo").begins_with("Faltam 35"), "an empty purse says how much is missing")
	_check(not Shop.purchase(data, "jarro_balsamo") and Economy.coins(data) == 0, "no purchase without coins")
	Economy.add_coins(data, 300)
	_check(Shop.blocker(data, "mirra").begins_with("Precisa de"), "myrrh asks for a jar first")
	_check(not Shop.purchase(data, "mirra"), "myrrh is refused without a jar")
	_check(not Shop.purchase(data, "unknown") and Economy.coins(data) == 300, "an unknown item is refused")
	_check(Shop.purchase(data, "jarro_balsamo") and Economy.coins(data) == 265, "a jar costs 35")
	_check(Shop.capacity(data, "balsamo") == 1 and Shop.charges(data, "balsamo") == 1, "a new jar comes full")
	_check(Shop.balm_heal(data) == 40, "a balm heals 40")
	_check(Shop.purchase(data, "mirra") and Shop.balm_heal(data) == 55, "myrrh adds 15 to each balm")
	_check(not Shop.purchase(data, "mirra") and Shop.blocker(data, "mirra") == "Esgotado", "myrrh is sold once")
	_check(Shop.purchase(data, "jarro_balsamo") and Shop.purchase(data, "jarro_balsamo"), "two more jars")
	_check(not Shop.purchase(data, "jarro_balsamo") and Shop.capacity(data, "balsamo") == 3, "the third jar is the last")
	_check(Economy.coins(data) == 300 - 35 * 3 - 50, "the purse paid each item once")
	_check(Shop.spend_charge(data, "balsamo") and Shop.spend_charge(data, "balsamo") and Shop.charges(data, "balsamo") == 1, "charges are spent one at a time")
	Shop.refill(data)
	_check(Shop.charges(data, "balsamo") == 3, "a shrine refills every jar")
	for index in range(3): Shop.spend_charge(data, "balsamo")
	_check(not Shop.spend_charge(data, "balsamo") and Shop.charges(data, "balsamo") == 0, "an empty jar cannot be spent")


func _test_save() -> void:
	var path := session_dir + "/save.json"
	var store: DemoSaveStore = SaveStore.new(path)
	_check(store.data["purchases"] == {} and store.data["items"] == {}, "a new journey has bought nothing")
	Economy.add_coins(store.data, 100)
	Shop.purchase(store.data, "jarro_balsamo")
	Shop.purchase(store.data, "mirra")
	Shop.spend_charge(store.data, "balsamo")
	_check(store.save_progress(), "purchases are written")
	var reopened: DemoSaveStore = SaveStore.new(path)
	_check(reopened.load_progress() and Shop.owned(reopened.data, "jarro_balsamo") == 1 and Shop.owned(reopened.data, "mirra") == 1, "purchases survive a reload")
	_check(Shop.charges(reopened.data, "balsamo") == 0 and Shop.balm_heal(reopened.data) == 55, "spent charges and myrrh survive a reload")
	_check(not Shop.purchase(reopened.data, "mirra"), "a reloaded purchase stays unique")
	var legacy := SaveStore.fresh_data()
	legacy.erase("purchases")
	legacy.erase("items")
	_write(session_dir + "/legacy.json", JSON.stringify(legacy))
	var migrated: DemoSaveStore = SaveStore.new(session_dir + "/legacy.json")
	_check(migrated.load_progress() and migrated.data["purchases"] == {} and migrated.data["items"] == {}, "a save from before the shops loads with nothing bought")
	var cases := [
		["unknown item", {"espada_magica": 1}, {}],
		["over the limit", {"mirra": 2}, {}],
		["negative count", {"jarro_balsamo": -1}, {}],
		["fractional count", {"jarro_balsamo": 1.5}, {}],
		["charges above capacity", {"jarro_balsamo": 1}, {"balsamo": 2}],
		["unknown charge", {}, {"pocao": 1}],
		["purchases not a dictionary", [], {}]
	]
	for index in range(cases.size()):
		var invalid := SaveStore.fresh_data()
		invalid["purchases"] = cases[index][1]
		invalid["items"] = cases[index][2]
		var invalid_path := session_dir + "/invalid_%d.json" % index
		_write(invalid_path, JSON.stringify(invalid))
		_check(not SaveStore.new(invalid_path).load_progress(), "invalid shop state is rejected: " + cases[index][0])


func _test_world() -> void:
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	world.store.path = session_dir + "/world.json"
	var player: SenuPlayer = world.player
	var hud: Control = world.hud
	var house: Dictionary = Catalog.HOUSES[ID]
	player.health = 30
	world.store.data["coins"] = 200
	await physics_frame
	# R sem jarro só avisa.
	_check(not world.use_balm() and player.health == 30 and str(hud.message).begins_with("Sem jarros"), "R without a jar only points to the shop")
	player.position = Layout.iso(house["outside"])
	await physics_frame
	_check(world.activate(_fixture("porta_" + ID)), "Senu opens the Emporium door")
	await create_timer(.7).timeout
	await physics_frame
	_check(world.inside_house == ID, "Senu is inside the Emporium")
	var keeper := _fixture("loja_merit")
	player.position = keeper.position + Vector2(0, 14)
	await physics_frame
	_check(world.nearest == keeper and keeper.label == "Falar com Merit", "standing at the counter, Merit is the nearest interaction")
	_check(world.activate(keeper) and hud.overlay == "shop" and paused, "talking to Merit opens the paused shop")
	_check(hud.dialog_title == "Empório de Merit" and hud.shop_id == "merit", "the shop shows Merit's stock")
	var buy_jar := _button(hud, "Comprar · 35")
	var buy_myrrh := _button(hud, "Comprar · 50")
	_check(buy_jar != null and not buy_jar.disabled, "the jar can be bought")
	_check(buy_myrrh != null and buy_myrrh.disabled, "myrrh waits for the first jar")
	if "--capture-shop" in OS.get_cmdline_user_args():
		await _capture("loja_merit_painel")
	buy_jar.pressed.emit()
	await process_frame
	_check(Economy.coins(world.store.data) == 165 and Shop.charges(world.store.data, "balsamo") == 1, "the real button buys a full jar")
	buy_myrrh = _button(hud, "Comprar · 50")
	_check(buy_myrrh != null and not buy_myrrh.disabled, "after a jar, myrrh opens")
	buy_myrrh.pressed.emit()
	await process_frame
	_check(Economy.coins(world.store.data) == 115 and Shop.balm_heal(world.store.data) == 55, "the real button buys myrrh")
	_check(_button(hud, "Esgotado") != null and _button(hud, "Esgotado").disabled, "myrrh shows sold out")
	_check(not FileAccess.file_exists(world.store.path), "purchases remain in memory before the first tower")
	_button(hud, "Voltar · Esc").pressed.emit()
	await process_frame
	_check(hud.overlay == "" and not paused, "Back returns to the game")
	# R de verdade: a ação de entrada que o jogador usa, apertada dentro de um
	# quadro de física para valer como "acabou de apertar".
	await physics_frame
	Input.action_press("use_item")
	await physics_frame
	await physics_frame
	Input.action_release("use_item")
	_check(player.health == 85 and Shop.charges(world.store.data, "balsamo") == 0, "R drinks a balm: +55 with myrrh")
	# Os testes aceleram o tempo; o intervalo entre goles conta em tempo real.
	world._last_balm_ms = -100000
	_check(not world.use_balm() and player.health == 85 and str(hud.message).begins_with("Bálsamo esgotado"), "an empty jar does not heal")
	if "--capture-shop" in OS.get_cmdline_user_args():
		await _capture("loja_merit_dentro")
	# Santuário do mercado: vida e bálsamo cheios.
	player.position = Layout.iso(house["spawn"])
	world.activate(_fixture("saida_" + ID))
	await create_timer(.7).timeout
	await physics_frame
	var shrine := _fixture("market_rest")
	player.position = shrine.position + Vector2(18, 10)
	await physics_frame
	_check(world.activate(shrine) and Shop.charges(world.store.data, "balsamo") == 1, "meditating refills the balm")
	var on_disk: DemoSaveStore = SaveStore.new(world.store.path)
	_check(on_disk.load_progress() and Shop.owned(on_disk.data, "mirra") == 1 and Economy.coins(on_disk.data) == 115, "the tower saves purchases made earlier in the session")
	player.health = player.max_health
	world._last_balm_ms = -100000
	_check(not world.use_balm() and Shop.charges(world.store.data, "balsamo") == 1, "a full life keeps the charge")
	world.queue_free()
	await process_frame


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


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Shop test timed out before completion")
	quit(1)
