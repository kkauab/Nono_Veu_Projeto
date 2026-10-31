extends RefCounted

## Mergulho (docs/MUNDO_BARCO_ILHA.md, "Mergulho"): nadando, Espaço leva Senu ao
## fundo da baía e Espaço de novo o traz à tona. Embaixo d'água a tela mostra o
## leito: areia, algas, pedras, as ruínas do porto antigo e o casco naufragado do
## Recife, com a luz da superfície em cáusticas. O chão do porto vira blocos de
## pedra que sobem do leito, e os píeres, estacas.
##
## O fôlego aparece em bolhas sobre Senu; quando acaba, ele sobe sozinho e perde
## vida. Os crocodilos caçam na superfície: mergulhado, Senu some do faro deles
## (sea_beasts.gd). No fundo há ânforas com óbolos e uma estela para ler, com IDs
## na lista `collected` do save, como as ânforas à deriva.
##
## O corpo continua sendo o de Senu, movido como no nado (sea_swim.gd): as mesmas
## bordas dos tiles o seguram no mar. O estado é a meta "diving" do port_demo, que
## só existe enquanto ele também está nadando.

const Layout = preload("res://scripts/world/port_layout.gd")
const Swim = preload("res://scripts/world/sea_swim.gd")
const Depth = preload("res://scripts/world/sea_depth.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")

## Px/s: mais lento que o nado na superfície (48).
const SPEED := 40.0
const STROKE := 1.35
const ISO_Y := .70
## Segundos de fôlego, mostrados em BUBBLES bolhas.
const BREATH := 22.0
const BUBBLES := 6
const DROWN_DAMAGE := 15
## Distância do ponto de mergulho a um tesouro em que E alcança.
const REACH := 30.0
## Quanto o chão do porto sobe acima do leito, em px.
const RISE := 24.0
## Quanto Senu flutua acima do leito.
const FLOAT := 9.0
const FADE := .3
const FLOOR_SIZE := Vector2(512, 256)
const FACE_SIZE := Vector2(128, 32)
const FLOOR := "res://assets/world/seabed_v1/floor.png"
const SHEET := "res://assets/world/seabed_v1/props.png"
const MANIFEST := "res://assets/world/seabed_v1/seabed_v1_manifest.json"
const FACE := "res://assets/world/ground_v8/face_stone.png"
const SHADER := "res://assets/shaders/harbor_pixel_underwater.gdshader"
## As classes de desenho chamam as funções deste módulo pelo próprio script.
const SELF := "res://scripts/world/sea_dive.gd"
const MUFFLED_BUSES := ["Ambiente", "SFX"]

## Tesouros do fundo, em tiles. As ânforas somem ao serem abertas; a estela fica.
const TREASURES := [
	{"id": "dive_amphora_1", "kind": "amphora", "tile": Vector2(17, 55), "coins": 15},
	{"id": "dive_amphora_2", "kind": "amphora", "tile": Vector2(40, 47.5), "coins": 15},
	{"id": "dive_amphora_3", "kind": "amphora", "tile": Vector2(58, 56.5), "coins": 15},
	{"id": "dive_amphora_4", "kind": "amphora", "tile": Vector2(72.5, 78.5), "coins": 15},
	{"id": "dive_amphora_5", "kind": "amphora", "tile": Vector2(27, 58.5), "coins": 15},
	{"id": "dive_stela", "kind": "stela", "tile": Vector2(23.5, 47)},
]
const STELA_TITLE := "A estela do porto afundado"
const STELA_TEXT := "“Aqui era a porta do Grande Verde. Cada navio que entrava pagava ao templo o dízimo da carga, e o escriba gravava o nome do dono na pedra, para que o rio se lembrasse dele.\n\nO mar subiu e levou o cais. Os nomes ficaram aqui embaixo, onde nada escreve por cima.”\n\n— Estela fictícia encontrada por Senu no fundo da baía"
## Ruínas e marcos fixos, sem interação: [peça, tile].
const LANDMARKS := [
	["head", Vector2(22, 49)], ["column", Vector2(19.5, 47.5)], ["column", Vector2(25, 51.5)],
	["drum", Vector2(21, 52)], ["drum", Vector2(26.5, 49)], ["anchor", Vector2(29, 42.5)],
	["wreck", Vector2(78, 77.5)], ["anchor", Vector2(74, 77)], ["column", Vector2(46, 80)],
]

static var _floor: Texture2D
static var _sheet: Texture2D
static var _face: Texture2D
static var _props: Dictionary = {}
static var _scene := {}


static func active(game) -> bool:
	return bool(game.get_meta("diving", false))


## A camada vive no palco do mundo (a SubViewport de pixel do port_demo), junto
## dos atores: assim segue a câmera e sai na mesma grade de pixels.
static func _stage(game) -> Node:
	var stage = game.get("world_stage")
	return stage if stage != null else game


static func view(game) -> Node2D:
	return _stage(game).get_node_or_null("Mergulho")


static func breath(game) -> float:
	return float(game.get_meta("dive_breath", BREATH))


## Os tesouros do fundo: marcadores inativos (o laço de interação do porto não os
## vê); só o mergulho os oferece.
static func build(game) -> void:
	for item: Dictionary in TREASURES:
		if item["kind"] == "amphora" and item["id"] in game.store.data["collected"]:
			continue
		var marker := PortInteractable.new()
		marker.item_id = item["id"]
		marker.kind = "dive_" + str(item["kind"])
		marker.label = "Abrir a ânfora" if item["kind"] == "amphora" else "Ler a estela"
		marker.active = false
		marker.position = Layout.iso(item["tile"])
		marker.add_to_group("dive_treasures")
		game.actors.add_child(marker)


static func start(game) -> bool:
	var player: SenuPlayer = game.player
	if active(game) or not Swim.active(game) or game.sea_busy or player.dead:
		return false
	game.set_meta("diving", true)
	game.set_meta("dive_breath", BREATH)
	game.nearest = null
	var swimmer := Swim.view(game)
	if swimmer != null:
		swimmer.visible = false
	var layer := view(game)
	if layer == null:
		layer = DiveLayer.new()
		layer.name = "Mergulho"
		layer.game = game
		_stage(game).add_child(layer)
	layer.open()
	_muffle(true)
	_sound(player, "water_splash", -10.0)
	if "dive_learned" not in game.store.data["collected"]:
		game.store.collect("dive_learned", 0)
		game.hud.toast("Mergulho · WASD nada, Shift dá braçadas, E pega o que brilha, Espaço volta à tona", Color("9fd0c4"), 6)
	return true


## Um quadro embaixo d'água.
static func update(game, delta: float) -> void:
	var player: SenuPlayer = game.player
	if player.dead:
		game.nearest = null
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var strong := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	step(game, input, strong, delta)
	if not spend_breath(game, delta):
		return
	var treasure := treasure_in_reach(game)
	game.nearest = treasure
	if treasure != null and Input.is_action_just_pressed("interact"):
		take(game, treasure)
	elif Input.is_action_just_pressed("dodge"):
		surface(game, false)


## Uma braçada no fundo. Separada do teclado para os testes poderem mergulhar.
static func step(game, input: Vector2, strong: bool, delta: float) -> void:
	var player: SenuPlayer = game.player
	var motion := Vector2(input.x, input.y * ISO_Y) * SPEED * (STROKE if strong else 1.0) * delta
	if motion.length_squared() > 0.0001:
		player.move_and_collide(motion)
		player.facing = input.normalized()
	player.global_position = player.global_position.clamp(Swim.BOUNDS.position, Swim.BOUNDS.end)
	var swimmer := Swim.view(game)
	if swimmer != null:
		swimmer.global_position = player.global_position
	var layer := view(game)
	if layer != null:
		layer.moving = motion.length_squared() > 0.0001


## Gasta o fôlego; sem ele, Senu volta à tona machucado. False quando subiu.
static func spend_breath(game, delta: float) -> bool:
	var left := breath(game) - delta
	game.set_meta("dive_breath", left)
	if left > 0.0:
		return true
	surface(game, true)
	return false


static func treasure_in_reach(game) -> Node2D:
	var player: SenuPlayer = game.player
	var best: Node2D = null
	var gap := REACH
	for marker in game.get_tree().get_nodes_in_group("dive_treasures"):
		if marker.is_queued_for_deletion():
			continue
		var distance := player.global_position.distance_to(marker.global_position)
		if distance < gap:
			gap = distance
			best = marker
	return best


static func take(game, marker: Node2D) -> void:
	if marker.kind == "dive_stela":
		game.hud.show_dialog(STELA_TITLE, STELA_TEXT)
		return
	var item := {}
	for entry: Dictionary in TREASURES:
		if entry["id"] == marker.item_id:
			item = entry
	if item.is_empty() or not game.store.collect(marker.item_id, 0):
		return
	marker.remove_from_group("dive_treasures")
	marker.queue_free()
	game.nearest = null
	game.collect_loot("coin", int(item["coins"]))
	var found := 0
	var total := 0
	for entry: Dictionary in TREASURES:
		if entry["kind"] == "amphora":
			total += 1
			found += int(entry["id"] in game.store.data["collected"])
	game.hud.toast("Ânfora do fundo · %d de %d" % [found, total], Color("e2c693"), 3)
	_sound(game.player, "water_bubble", -6.0)


## Volta à tona. Sem fôlego, chega machucada.
static func surface(game, out_of_breath: bool) -> void:
	if not active(game):
		return
	game.set_meta("diving", false)
	game.nearest = null
	var layer := view(game)
	if layer != null:
		layer.close()
	var swimmer := Swim.view(game)
	if swimmer != null:
		swimmer.visible = true
		swimmer.splash = 1.0
	_muffle(false)
	_sound(game.player, "water_splash", -8.0)
	if out_of_breath:
		game.player.receive_hit(DROWN_DAMAGE, game.player.global_position + Vector2(0, -1))
		game.hud.toast("Sem fôlego! Senu volta à tona.", Color("dfb5b0"), 3)


## Sem animação nem dano: ao reaparecer no santuário ou ao sair do nado.
static func stop(game) -> void:
	game.set_meta("diving", false)
	var layer := view(game)
	if layer != null:
		layer.queue_free()
	_muffle(false)


static func _sound(at: Node2D, bank: String, volume: float) -> void:
	if Sfx.has_bank(bank):
		Sfx.play(at, bank, at.global_position, volume)


## Embaixo d'água, o mar e os golpes soam abafados.
static func _muffle(on: bool) -> void:
	for name: String in MUFFLED_BUSES:
		var bus := AudioServer.get_bus_index(name)
		if bus < 0:
			continue
		for index in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if AudioServer.get_bus_effect(bus, index).resource_name == "mergulho":
				AudioServer.remove_bus_effect(bus, index)
		if on:
			var filter := AudioEffectLowPassFilter.new()
			filter.resource_name = "mergulho"
			filter.cutoff_hz = 900.0
			AudioServer.add_bus_effect(bus, filter)


# --- Cena do fundo ------------------------------------------------------------------

static func _load_art() -> bool:
	if _sheet != null:
		return true
	if not ResourceLoader.exists(SHEET) or not ResourceLoader.exists(FLOOR) or not FileAccess.file_exists(MANIFEST):
		return false
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not data is Dictionary:
		return false
	_props = data.get("props", {})
	_floor = load(FLOOR) as Texture2D
	_sheet = load(SHEET) as Texture2D
	_face = load(FACE) as Texture2D if ResourceLoader.exists(FACE) else null
	return _sheet != null and _floor != null


static func load_art() -> bool:
	return _load_art()


static func floor_texture() -> Texture2D:
	return _floor


static func face_texture() -> Texture2D:
	return _face


## O que não se move no fundo, ordenado pela base na tela, para desenhar de trás
## para a frente com Senu no meio: blocos do chão do porto, estacas dos píeres,
## algas, pedras, ruínas e tesouros. Calculado no primeiro mergulho de cada mundo.
static func scene(game) -> Dictionary:
	var layout = game.layout
	if _scene.get("layout", 0) == layout.get_instance_id():
		return _scene
	var keys: Array[Vector3] = []
	var items: Array = []
	var shadows: Array[Vector2] = []
	for tile: Vector2i in layout.tiles:
		var center := Layout.iso(Vector2(tile))
		if layout.tile_themes[tile] == "wood":
			shadows.append(center)
			if posmod(tile.x + tile.y, 2) == 0:
				items.append(["post", center])
				keys.append(Vector3(center.y, center.x, items.size() - 1))
			continue
		var open_x: bool = not layout.tiles.has(tile + Vector2i(1, 0))
		var open_y: bool = not layout.tiles.has(tile + Vector2i(0, 1))
		items.append(["block", center, open_x, open_y, layout.tile_themes[tile]])
		keys.append(Vector3(center.y + 16.0, center.x, items.size() - 1))
	# Algas, pedras e conchas: um sorteio fixo por tile do mar, mais denso no raso.
	var near := []
	for entry: Array in LANDMARKS:
		near.append(Vector2(entry[1]))
	for entry: Dictionary in TREASURES:
		near.append(Vector2(entry["tile"]))
	var span := Depth.size_tiles()
	for y in range(span.y):
		for x in range(span.x):
			var tile := Depth.origin_tile() + Vector2i(x, y)
			var depth := Depth.at_tile(tile)
			if depth == 0:
				continue
			var roll := _hash(tile.x, tile.y, 5)
			var name := ""
			if depth <= 3 and roll < .2:
				name = "grass_a" if _hash(tile.x, tile.y, 7) < .55 else "grass_b"
			elif roll < (.23 if depth < 6 else .05):
				name = ["rock_small", "rock_small", "shells", "urchins", "rock_large"][int(_hash(tile.x, tile.y, 9) * 5.0)]
			if name == "":
				continue
			var spot := Vector2(tile) + Vector2(_hash(tile.x, tile.y, 11) - .5, _hash(tile.x, tile.y, 13) - .5) * .7
			var clear := true
			for point: Vector2 in near:
				if point.distance_to(spot) < 1.6:
					clear = false
					break
			if not clear:
				continue
			var at := Layout.iso(spot).round()
			items.append(["prop", at, name, _hash(tile.x, tile.y, 17) * 3.0])
			keys.append(Vector3(at.y, at.x, items.size() - 1))
	for entry: Array in LANDMARKS:
		var at := Layout.iso(entry[1]).round()
		items.append(["prop", at, entry[0], 0.0])
		keys.append(Vector3(at.y, at.x, items.size() - 1))
	for marker in game.get_tree().get_nodes_in_group("dive_treasures"):
		var at: Vector2 = marker.global_position.round()
		items.append(["treasure", at, marker])
		keys.append(Vector3(at.y, at.x, items.size() - 1))
	keys.sort()
	var ys := PackedFloat32Array()
	var order := PackedInt32Array()
	for key in keys:
		ys.append(key.x)
		order.append(int(key.z))
	_scene = {"layout": layout.get_instance_id(), "ys": ys, "order": order, "items": items, "shadows": shadows}
	return _scene


static func _hash(a: int, b: int, seed: int) -> float:
	var h: int = (a * 374761393 + b * 668265263 + seed * 1442695041) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


static func draw_prop(canvas: CanvasItem, name: String, at: Vector2) -> bool:
	var entry: Dictionary = _props.get(name, {})
	if entry.is_empty():
		return false
	var rect: Array = entry["rect"]
	var pivot: Array = entry["pivot"]
	canvas.draw_texture_rect_region(_sheet, Rect2(at - Vector2(float(pivot[0]), float(pivot[1])), Vector2(float(rect[2]), float(rect[3]))), Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
	return true


## A camada inteira do mergulho, por cima do mundo e embaixo do HUD. Entra e sai
## com uma transparência curta, e se desfaz quando some.
class DiveLayer extends Node2D:
	var game
	var dive: GDScript
	var moving := false
	var clock := 0.0
	## Fase do ciclo de nado no fundo (sea_swim.gd, poses "dive").
	var phase := 0.0
	var _target := 0.0
	var _bubble_timer := 0.0
	var bubbles: Array = []
	var schools: Array = []
	var seabed: Seabed
	var top: SurfaceView

	func _ready() -> void:
		z_index = 4000
		z_as_relative = false
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		modulate.a = 0.0
		dive = load(SELF)
		seabed = Seabed.new()
		seabed.layer = self
		add_child(seabed)
		top = SurfaceView.new()
		top.layer = self
		add_child(top)

	func open() -> void:
		_target = 1.0
		visible = true
		schools.clear()

	func close() -> void:
		_target = 0.0

	## A cabeça de Senu no fundo, de onde saem as bolhas: na ponta do corpo deitado,
	## ou no alto do corpo de pé (nadando para cima ou para baixo).
	func head_point() -> Vector2:
		var player: SenuPlayer = game.player
		var stroke: Dictionary = Swim.pose("dive", player.facing, phase)
		if stroke.is_empty():
			return player.global_position + Vector2(0, -60.0 - FLOAT)
		if stroke["lying"]:
			return player.global_position + Vector2(20.0 * signf(player.facing.x if absf(player.facing.x) > .01 else 1.0), -24.0)
		return player.global_position + Vector2(0, -52.0)

	func view_rect() -> Rect2:
		var inverse := get_viewport().get_canvas_transform().affine_inverse()
		var size := get_viewport().get_visible_rect().size
		var a: Vector2 = inverse * Vector2.ZERO
		var b: Vector2 = inverse * size
		return Rect2(a, b - a).abs()

	func _process(delta: float) -> void:
		clock += delta
		modulate.a = move_toward(modulate.a, _target, delta / FADE)
		if _target <= 0.0 and modulate.a <= 0.0:
			queue_free()
			return
		phase = fposmod(phase + delta * (Swim.STROKES * .85 if moving else Swim.STROKES_IDLE), 1.0)
		var player: Node2D = game.player
		var head := head_point()
		_bubble_timer -= delta
		if _bubble_timer <= 0.0 and _target > 0.0:
			_bubble_timer = .22 if moving else .45
			bubbles.append({"at": head + Vector2(randf_range(-3, 3), 0), "age": 0.0, "size": 1.0 if randf() < .7 else 2.0})
		for bubble: Dictionary in bubbles:
			bubble["age"] += delta
			bubble["at"] += Vector2(sin(bubble["age"] * 7.0 + bubble["size"]) * 6.0, -26.0) * delta
		bubbles = bubbles.filter(func(bubble: Dictionary) -> bool: return bubble["age"] < 1.6)
		_update_fish(delta)
		seabed.queue_redraw()
		top.queue_redraw()

	## Cardumes que vagam perto da câmera e fogem de Senu.
	func _update_fish(delta: float) -> void:
		var rect := view_rect()
		var player: Node2D = game.player
		if schools.is_empty():
			for index in range(4):
				schools.append(_new_school(rect, index))
		for index in range(schools.size()):
			var school: Dictionary = schools[index]
			var center: Vector2 = school["center"]
			var heading: float = school["heading"] + sin(clock * .5 + index * 2.0) * .6 * delta
			var speed := 16.0
			var away := center - player.global_position
			if away.length() < 64.0:
				heading = lerp_angle(heading, away.angle(), 4.0 * delta)
				speed = 55.0
			school["heading"] = heading
			center += Vector2(cos(heading), sin(heading) * .5) * speed * delta
			school["center"] = center
			if not rect.grow(220).has_point(center) or Depth.at_point(center) == 0:
				schools[index] = _new_school(rect, index + int(clock * 10.0))

	func _new_school(rect: Rect2, seed: int) -> Dictionary:
		var center := rect.get_center()
		for attempt in range(12):
			var side := posmod(seed + attempt, 4)
			var t := randf()
			center = [Vector2(rect.position.x - 40, rect.position.y + rect.size.y * t), Vector2(rect.end.x + 40, rect.position.y + rect.size.y * t), Vector2(rect.position.x + rect.size.x * t, rect.position.y - 30), Vector2(rect.position.x + rect.size.x * t, rect.end.y + 30)][side]
			if Depth.at_point(center) > 0:
				break
		var fish: Array[Vector2] = []
		for count in range(5 + posmod(seed, 5)):
			fish.append(Vector2(randf_range(-16, 16), randf_range(-8, 8)))
		return {"center": center, "heading": (rect.get_center() - center).angle() + randf_range(-.6, .6), "fish": fish}


## O leito, o chão do porto, as peças, os peixes e Senu, todos pelo shader da água.
class Seabed extends Node2D:
	var layer: DiveLayer
	var _material: ShaderMaterial

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		if ResourceLoader.exists(SHADER):
			_material = ShaderMaterial.new()
			_material.shader = load(SHADER)
			var depth: Texture2D = Depth.texture()
			if depth != null:
				_material.set_shader_parameter("depth_map", depth)
				_material.set_shader_parameter("depth_origin", Vector2(Depth.origin_tile()))
				_material.set_shader_parameter("depth_size", Vector2(Depth.size_tiles()))
			material = _material

	func _draw() -> void:
		var game = layer.game
		var dive: GDScript = layer.dive
		if game == null or dive == null or not dive.load_art():
			draw_rect(layer.view_rect(), Color("123238"))
			return
		var rect := layer.view_rect().grow(32)
		var corners := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		var uvs := PackedVector2Array()
		for corner in corners:
			uvs.append(corner / FLOOR_SIZE)
		draw_colored_polygon(corners, Color.WHITE, uvs, dive.floor_texture())
		var data: Dictionary = dive.scene(game)
		# Sombra dos píeres no leito.
		for center: Vector2 in data["shadows"]:
			if rect.grow(40).has_point(center):
				draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)]), Color(0, 0, 0, .3))
		var player: SenuPlayer = game.player
		draw_set_transform(player.global_position, 0, Vector2(1, .5))
		draw_circle(Vector2.ZERO, 9.0, Color(0, 0, 0, .28))
		draw_set_transform(Vector2.ZERO)
		var ys: PackedFloat32Array = data["ys"]
		var order: PackedInt32Array = data["order"]
		var items: Array = data["items"]
		var first := ys.bsearch(rect.position.y - 40.0)
		var last := ys.bsearch(rect.end.y + 120.0 + RISE, false)
		var senu_y := player.global_position.y
		var senu_drawn := false
		for index in range(first, mini(last, ys.size())):
			if not senu_drawn and ys[index] > senu_y:
				_draw_senu(player)
				senu_drawn = true
			var item: Array = items[order[index]]
			var at: Vector2 = item[1]
			if at.x < rect.position.x - 200.0 or at.x > rect.end.x + 200.0:
				continue
			match item[0]:
				"block":
					_draw_block(at, item[2], item[3], item[4])
				"post":
					_draw_post(at)
				"prop":
					var name: String = item[2]
					if name.begins_with("grass"):
						name += "_%d" % posmod(int(layer.clock * 2.5 + float(item[3])), 3)
					dive.draw_prop(self, name, at)
				"treasure":
					# A ânfora aberta já foi liberada: sem tipo, para checar antes de usar.
					var marker = item[2]
					if is_instance_valid(marker) and not marker.is_queued_for_deletion():
						dive.draw_prop(self, "amphora" if marker.kind == "dive_amphora" else "stela", at)
		if not senu_drawn:
			_draw_senu(player)
		_draw_fish()

	## Um tile do porto visto do fundo: um bloco que sobe do leito, com o mesmo piso
	## da superfície por cima, escurecido, e as faces de blocos (as do paredão)
	## viradas para a câmera. Liso e azul, o topo parecia água.
	func _draw_block(center: Vector2, open_x: bool, open_y: bool, theme: String) -> void:
		var top := center - Vector2(0, RISE)
		var corners := [Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]
		var diamond := PackedVector2Array()
		var top_uvs := PackedVector2Array()
		for corner: Vector2 in corners:
			diamond.append(top + corner)
			top_uvs.append((center + corner) / Layout.GROUND_SIZE)
		var ground: Texture2D = Layout.ground_texture(theme)
		if ground != null:
			draw_colored_polygon(diamond, Color(.5, .54, .52), top_uvs, ground)
		else:
			draw_colored_polygon(diamond, Color("4b5553"))
		for edge in [[open_x, Vector2(32, 0), Vector2(0, 16)], [open_y, Vector2(0, 16), Vector2(-32, 0)]]:
			if not edge[0]:
				continue
			var a: Vector2 = top + edge[1]
			var b: Vector2 = top + edge[2]
			var face := PackedVector2Array([a, b, b + Vector2(0, RISE), a + Vector2(0, RISE)])
			var texture: Texture2D = layer.dive.face_texture()
			if texture != null:
				var face_uvs := PackedVector2Array([Vector2(a.x / FACE_SIZE.x, 0), Vector2(b.x / FACE_SIZE.x, 0), Vector2(b.x / FACE_SIZE.x, RISE / FACE_SIZE.y), Vector2(a.x / FACE_SIZE.x, RISE / FACE_SIZE.y)])
				draw_colored_polygon(face, Color(.82, .86, .84), face_uvs, texture)
			else:
				draw_colored_polygon(face, Color("3c5659"))
			# Limo na quina de cima.
			draw_line(a, b, Color("609087"), 1)

	## Estaca de píer: sobe do leito e some na luz da superfície.
	func _draw_post(base: Vector2) -> void:
		var height := RISE + 18.0
		draw_rect(Rect2(base + Vector2(-2, -height), Vector2(4, height)), Color("4b3b2d"))
		draw_rect(Rect2(base + Vector2(-2, -height), Vector2(1, height)), Color("674d34"))
		draw_rect(Rect2(base + Vector2(-2, -7), Vector2(4, 7)), Color("5a623e"))
		draw_rect(Rect2(base + Vector2(-2, -height), Vector2(4, 3)), Color("8c9380"))

	func _draw_senu(player: SenuPlayer) -> void:
		# A água escurece tudo; Senu é clareado para continuar legível no fundo.
		var bright := Color(2.1, 1.55, 1.4) if float(player.get("_hurt_visual")) > 0.0 else Color(1.6, 1.32, 1.26)
		var stroke: Dictionary = Swim.pose("dive", player.facing, layer.phase)
		if not stroke.is_empty():
			draw_texture_rect_region(stroke["texture"], Rect2(player.global_position + stroke["offset"], stroke["size"]), stroke["region"], bright)
			return
		var bob := roundf(sin(layer.clock * (4.0 if layer.moving else 2.0)) * 1.5)
		var lift := Vector2(0, -FLOAT + bob)
		var supplied = player.get("_supplied_view")
		if supplied != null and supplied.has_method("sample"):
			var frame: Dictionary = supplied.sample(player)
			if not frame.is_empty():
				var size: Vector2 = frame["size"]
				var offset: Vector2 = frame["offset"]
				draw_texture_rect_region(frame["texture"], Rect2(player.global_position + offset + lift, size), frame["region"], bright)
				return
		draw_circle(player.global_position + lift + Vector2(0, -12), 5.0, Color("a27d50"))

	func _draw_fish() -> void:
		for school: Dictionary in layer.schools:
			var center: Vector2 = school["center"]
			var heading: float = school["heading"]
			var facing := 1.0 if cos(heading) >= 0.0 else -1.0
			for index in range(school["fish"].size()):
				var offset: Vector2 = school["fish"][index]
				var wobble := Vector2(0, roundf(sin(layer.clock * 3.0 + index) * 1.0))
				var at := (center + offset + wobble + Vector2(0, -14)).round()
				draw_rect(Rect2(at + Vector2(-2, 0), Vector2(5, 2)), Color("93b9b1"))
				draw_rect(Rect2(at + Vector2(-2, 0), Vector2(5, 1)), Color("456f6e"))
				draw_rect(Rect2(at + Vector2(-3.0 * facing - (1.0 if facing < 0 else 0.0), -1), Vector2(1, 4)), Color("6d8f8a"))
				draw_rect(Rect2(at + Vector2(2.0 * facing - (1.0 if facing < 0 else 0.0), 0), Vector2(1, 1)), Color("142629"))


## Acima de tudo e fora do shader: as silhuetas da superfície vistas de baixo
## (barco e crocodilos), as bolhas, o brilho dos tesouros e o fôlego de Senu.
class SurfaceView extends Node2D:
	var layer: DiveLayer

	func _draw() -> void:
		var game = layer.game
		if game == null:
			return
		var rect := layer.view_rect().grow(80)
		var shade := Color(.01, .05, .06, .42)
		if is_instance_valid(game.boat) and rect.has_point(game.boat.global_position):
			_hull(game.boat.global_position - Vector2(0, RISE + 14.0), float(game.boat.heading), 22.0, 6.0, shade)
		for beast in game.get_tree().get_nodes_in_group("sea_beasts"):
			if rect.has_point(beast.global_position):
				var big: bool = str(beast.get("kind")) == "sobek"
				_hull(beast.global_position - Vector2(0, RISE + 10.0), float(beast.get("heading")), 19.0 if big else 15.0, 4.0 if big else 3.0, shade)
		# Plâncton à deriva: um padrão de 640×360 preso ao mundo, com deriva lenta.
		var drift := Vector2(layer.clock * 3.0, sin(layer.clock * .4) * 4.0)
		var mote := Color(.72, .9, .85, .3)
		for index in range(90):
			var base := Vector2(_hash(index, 1, 31) * 640.0, _hash(index, 2, 31) * 360.0) + drift
			var x := base.x + ceilf((rect.position.x - base.x) / 640.0) * 640.0
			while x < rect.end.x:
				var y := base.y + ceilf((rect.position.y - base.y) / 360.0) * 360.0
				while y < rect.end.y:
					draw_rect(Rect2(Vector2(x, y).floor(), Vector2.ONE), mote)
					y += 360.0
				x += 640.0
		var nearest = game.nearest
		for marker in game.get_tree().get_nodes_in_group("dive_treasures"):
			if not rect.has_point(marker.global_position) or marker.is_queued_for_deletion():
				continue
			var lit: bool = marker == nearest
			var pulse := fposmod(layer.clock * .7 + marker.global_position.x * .01, 1.0)
			if lit or pulse < .25:
				var at: Vector2 = (marker.global_position + Vector2(-6, -16)).round()
				var glow := Color("f5cc76") if lit else Color("e0bd7e", .8)
				draw_rect(Rect2(at + Vector2(-1, 0), Vector2(3, 1)), glow)
				draw_rect(Rect2(at + Vector2(0, -1), Vector2(1, 3)), glow)
		for bubble: Dictionary in layer.bubbles:
			var age: float = bubble["age"]
			var color := Color(.86, .97, .95, .8 * (1.0 - age / 1.6))
			var at: Vector2 = (bubble["at"] as Vector2).round()
			if bubble["size"] > 1.5:
				draw_rect(Rect2(at + Vector2(-1, -1), Vector2(2, 2)), color)
			else:
				draw_rect(Rect2(at, Vector2(1, 1)), color)
		_draw_breath(game)

	func _hull(center: Vector2, heading: float, length: float, width: float, color: Color) -> void:
		var forward := Vector2(cos(heading), sin(heading) * .5)
		var side := Vector2(-sin(heading), cos(heading) * .5)
		draw_colored_polygon(PackedVector2Array([center + forward * length, center + side * width, center - forward * length * .9 + side * width * .6, center - forward * length * 1.15, center - forward * length * .9 - side * width * .6, center - side * width]), color)

	## O fôlego: bolhas cheias sobre a cabeça de Senu; no fim, piscam.
	func _draw_breath(game) -> void:
		var left: float = layer.dive.breath(game) / BREATH
		var full := ceili(left * BUBBLES)
		if left < .3 and posmod(int(layer.clock * 6.0), 2) == 0:
			full = 0
		# Logo acima da cabeça, deitado ou de pé, centrado em Senu.
		var top: float = layer.head_point().y - 12.0
		var head: Vector2 = Vector2(game.player.global_position.x - BUBBLES * 3.0, top).round()
		for index in range(BUBBLES):
			var at := head + Vector2(index * 6.0, 0)
			if index < full:
				draw_rect(Rect2(at + Vector2(0, -1), Vector2(4, 4)), Color(.86, .97, .95, .9))
				draw_rect(Rect2(at + Vector2(1, 0), Vector2(1, 1)), Color(1, 1, 1, .95))
			else:
				draw_rect(Rect2(at + Vector2(0, -1), Vector2(4, 4)), Color(.86, .97, .95, .2))

	func _hash(a: int, b: int, seed: int) -> float:
		var h: int = (a * 374761393 + b * 668265263 + seed * 1442695041) & 0x7fffffff
		h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
		h = h ^ (h >> 16)
		return float(h & 0xffff) / 65535.0
