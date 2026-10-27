extends RefCounted

## Entrar e sair das casas. Chamado pelo port_demo: `build` ao montar o mundo e
## `activate` para as portas, baús e bilhetes de dentro. O estado fica no próprio
## port_demo (`inside_house`, `house_busy`), que é recriado a cada cena.

const Catalog = preload("res://scripts/world/house_catalog.gd")
const Interior = preload("res://scripts/world/house_interior.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const InteriorArt = preload("res://scripts/world/interior_art.gd")
const FADE := .22
const KINDS := ["door", "house_chest", "house_note", "shopkeeper"]
const CAMERA_OFFSET := Vector2(0, -20)


## Porta, baú ou bilhete de uma casa. Desenho próprio; o resto é PortInteractable.
class HouseFixture extends PortInteractable:
	var house_id := ""
	var leads_inside := false

	func _draw() -> void:
		var gold := Color("dcc28c")
		if highlighted:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
			draw_arc(Vector2.ZERO, 21, 0, TAU, 24, gold, 1)
			draw_set_transform(Vector2.ZERO)
		match kind:
			"door":
				# Uma soleira de pedra gasta; brilha quando Senu está perto.
				draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(0, 6), Vector2(12, 0), Vector2(0, -6)]), Color(.55, .5, .38, .55))
				if highlighted:
					draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(0, 4), Vector2(8, 0), Vector2(0, -4)]), Color(.96, .85, .58, .35 + sin(time * 4.0) * .1))
			"house_chest":
				draw_rect(Rect2(-12, -2, 24, 4), Color(.01, .025, .03, .28))
				if InteriorArt.draw(self, "chest_open" if opened else "chest_closed"):
					return
				draw_colored_polygon(PackedVector2Array([Vector2(-13, -2), Vector2(0, 5), Vector2(14, -2), Vector2(14, -13), Vector2(0, -6), Vector2(-13, -13)]), Color("5d4630"))
				draw_colored_polygon(PackedVector2Array([Vector2(0, 5), Vector2(14, -2), Vector2(14, -13), Vector2(0, -6)]), Color("4b3826"))
				draw_line(Vector2(-13, -8), Vector2(0, -1), Color("a68a55"), 1)
				draw_line(Vector2(0, -1), Vector2(14, -8), Color("8a7046"), 1)
				if opened:
					draw_colored_polygon(PackedVector2Array([Vector2(-13, -13), Vector2(-12, -25), Vector2(1, -19), Vector2(0, -6)]), Color("6d553a"))
					draw_colored_polygon(PackedVector2Array([Vector2(-11, -12), Vector2(0, -7), Vector2(12, -12), Vector2(1, -16)]), Color("231a12"))
				else:
					draw_colored_polygon(PackedVector2Array([Vector2(-13, -13), Vector2(0, -20), Vector2(14, -13), Vector2(0, -6)]), Color("6d553a"))
					draw_rect(Rect2(-2, -9, 4, 4), Color("c9a25a"))
			"house_note":
				# Bilhete preso à parede do fundo, um pouco acima do chão.
				draw_colored_polygon(PackedVector2Array([Vector2(-6, -30), Vector2(6, -24), Vector2(6, -12), Vector2(-6, -18)]), Color("cbbf9c"))
				for row in range(3):
					draw_line(Vector2(-4, -25 + row * 3), Vector2(3, -21.5 + row * 3), Color("6a5e48"), 1)
				draw_rect(Rect2(-1, -30, 2, 2), Color("8a5a3a"))


static func build(game) -> void:
	game.inside_house = ""
	game.house_busy = false
	for id in Catalog.HOUSES:
		var house: Dictionary = Catalog.HOUSES[id]
		var room := Interior.new()
		room.house_id = id
		room.house = house
		game.world_stage.add_child(room)
		for piece in house["furniture"]:
			var furniture := Interior.Furniture.new()
			furniture.kind = piece[0]
			furniture.position = Layout.iso(piece[1])
			game.actors.add_child(furniture)
		var district := _district_label(house["district"])
		_fixture(game, id, "porta_" + id, "door", house["door"], "Entrar · " + str(house["name"])).leads_inside = true
		_fixture(game, id, "saida_" + id, "door", house["exit"], "Sair para " + district)
		for fixture in house["fixtures"]:
			var caption: String = {"house_chest": "Abrir o baú", "house_note": "Ler o bilhete", "shopkeeper": "Falar com " + str(house.get("keeper", ""))}[fixture[0]]
			var item := _fixture(game, id, fixture[1], fixture[0], fixture[2], caption)
			if fixture[0] == "house_chest" and fixture[1] in game.store.data["collected"]:
				item.opened = true
				item.active = false

static func activate(game, item: PortInteractable) -> bool:
	if not item is HouseFixture:
		return false
	match item.kind:
		"door":
			return _travel(game, item)
		"house_chest":
			return _open_chest(game, item)
		"house_note":
			var note: Array = Catalog.NOTES.get(item.item_id, ["", ""])
			game.hud.show_dialog(note[0], note[1])
			return true
		"shopkeeper":
			var house: Dictionary = Catalog.HOUSES[item.house_id]
			game.hud.show_shop(str(house["name"]), str(house["shop"]), str(house["greeting"]))
			return true
	return false

static func inside(game) -> bool:
	return str(game.inside_house) != ""

## Onde o mapa marca Senu: dentro de uma casa, na porta de fora.
static func map_position(game) -> Vector2:
	if inside(game):
		return Layout.iso(Catalog.HOUSES[game.inside_house]["door"])
	return game.player.position

static func _travel(game, item: HouseFixture) -> bool:
	if game.house_busy or game.respawning:
		return false
	game.house_busy = true
	game.player.controls_enabled = false
	game.player.velocity = Vector2.ZERO
	sound(game.player, "door_open", item.global_position)
	var fade := _fade(game)
	var tween: Tween = game.create_tween()
	tween.tween_property(fade, "color:a", 1.0, FADE)
	var id := item.house_id
	var entering := item.leads_inside
	tween.tween_callback(func(): _arrive(game, id, entering))
	tween.tween_property(fade, "color:a", 0.0, FADE)
	tween.tween_callback(func(): _finish_travel(game))
	return true

static func _arrive(game, id: String, entering: bool) -> void:
	var house: Dictionary = Catalog.HOUSES[id]
	var player: SenuPlayer = game.player
	var camera: Camera2D = player.get_node("IsometricCamera")
	player.velocity = Vector2.ZERO
	# Só a posição muda: reset_at curaria Senu a cada porta.
	player.position = Layout.iso(house["spawn"] if entering else house["outside"])
	if entering:
		game.inside_house = id
		# O setor continua sendo o distrito da porta: a casa não entra em "visited".
		game.current_room = house["district"]
		# A sala cabe inteira na tela; a câmera fica parada no centro dela.
		camera.top_level = true
		camera.global_position = Interior.camera_point(house)
	else:
		game.inside_house = ""
		game.current_room = Layout.room_at(player.position)
		camera.top_level = false
		camera.position = CAMERA_OFFSET
	camera.reset_smoothing()

static func _finish_travel(game) -> void:
	game.house_busy = false
	if not game.opening_active:
		game.player.controls_enabled = true

static func _open_chest(game, item: HouseFixture) -> bool:
	if not game.store.collect(item.item_id, 0):
		return false
	var reward: int = Catalog.CHEST_REWARDS.get(item.item_id, 0)
	item.opened = true
	item.active = false
	sound(game.player, "chest_open", item.global_position)
	game.collect_loot("coin", reward)
	game.call("_save")
	game.hud.toast("Baú aberto · +%d %s" % [reward, Economy.CURRENCY], Color("e2c693"), 4)
	return true

static func _fixture(game, house_id: String, id: String, kind: String, tile: Vector2, label: String) -> HouseFixture:
	var item := HouseFixture.new()
	item.house_id = house_id
	item.item_id = id
	item.kind = kind
	item.label = label
	item.position = Layout.iso(tile)
	game.actors.add_child(item)
	return item

static func _fade(game) -> ColorRect:
	var layer: Node = game.hud.get_parent()
	var fade := layer.get_node_or_null("HouseFade") as ColorRect
	if fade == null:
		fade = ColorRect.new()
		fade.name = "HouseFade"
		fade.color = Color(.01, .02, .025, 0)
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(fade)
	return fade

static func _district_label(room_id: String) -> String:
	for room in Layout.ROOMS:
		if room["id"] == room_id:
			return str(room["name"])
	return "o Porto"

static func sound(context: Node, bank: String, at: Vector2) -> void:
	if Sfx.has_bank(bank):
		Sfx.play(context, bank, at)
