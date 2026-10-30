extends RefCounted

## Navegação (docs/MUNDO_BARCO_ILHA.md). Chamado pelo port_demo:
## - `build`, ao montar o mundo;
## - `update`, a cada quadro de física; devolve true enquanto Senu está no barco
##   ou saltando, e o port_demo pula o resto do quadro;
## - `activate`, para os postes de amarração;
## - `respawn`, quando Senu volta ao santuário.
## O estado fica no próprio port_demo: boat, at_sea, sea_busy e boat_dock.

const SenuBoatView = preload("res://scripts/actors/senu_boat_view.gd")
const Boat = preload("res://scripts/world/sea_boat.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const IsleStory = preload("res://scripts/world/isle_story.gd")
const FarIsles = preload("res://scripts/world/far_isles.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const Art = preload("res://scripts/world/port_art.gd")
const MOORED_SHADER = preload("res://assets/shaders/harbor_pixel_moored.gdshader")
static var _hull_texture: ImageTexture
const HOP := .48
const DOCK_REACH := 52.0
const DOCK_SPEED := 110.0
const AMPHORA_REACH := 26.0
const AMPHORA_COINS := 12
## "land" é a ponta do píer, onde Senu embarca; "water", onde o barco fica
## amarrado, com a proa ("heading") apontando para o mar.
const DOCKS := {
	"sabu": {"name": "Píer de Sabu", "land": Vector2(25.5, 38.1), "water": Vector2(25.5, 39.4), "heading": PI * .75, "side": "port"},
	"bennu": {"name": "Píer do Bennu", "land": Vector2(44.5, 59.1), "water": Vector2(44.5, 57.6), "heading": -PI * .25, "side": "isle"},
	# Ilhas além da baía (far_isles_layout.gd; docs/MUNDO_PROPOSTA_2026-10-30.md).
	"ibis": {"name": "Píer do Íbis", "land": Vector2(12.5, 64.1), "water": Vector2(12.5, 62.6), "heading": -PI * .25, "side": "far"},
	"wreck": {"name": "Píer do Recife", "land": Vector2(66.1, 66.5), "water": Vector2(64.6, 66.5), "heading": -PI * .75, "side": "far"},
}
## Ânforas de uma carga perdida, boiando na Baía das Garças.
## As três últimas são carga do navio encalhado e boiam em volta do recife e do Íbis.
const AMPHORAE := [Vector2(31, 47), Vector2(51, 51), Vector2(60, 62), Vector2(31, 68), Vector2(69, 61), Vector2(93, 68.5), Vector2(24.5, 70.5)]
## Rochedos para contornar no caminho.
## Os quatro últimos são o recife em volta do navio e as pedras da costa do Íbis.
const SEA_ROCKS := [Vector2(33, 50), Vector2(48, 55.5), Vector2(38.5, 58.5), Vector2(71, 59.5), Vector2(91.5, 62.5), Vector2(4, 66), Vector2(22.5, 81)]
const SEA_NAME := "Baía das Garças"


## Poste de amarração na ponta de um píer: embarcar em terra, atracar do barco.
class MoorPost extends PortInteractable:
	var dock := ""

	func _ready() -> void:
		super._ready()
		add_to_group("moor_posts")

	func _draw() -> void:
		if highlighted:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
			draw_arc(Vector2.ZERO, 21, 0, TAU, 24, Color("dcc28c"), 1)
			draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-4, -2, 8, 4), Color(.01, .025, .03, .28))
		draw_rect(Rect2(-2, -13, 5, 13), Color("4b3b2d"))
		draw_rect(Rect2(-2, -13, 2, 13), Color("674d34"))
		draw_rect(Rect2(-3, -15, 7, 2), Color("846443"))
		# A corda com o nó de três voltas de Sabu.
		draw_line(Vector2(-3, -8), Vector2(4, -6), Color("a27d50"), 1)
		draw_line(Vector2(-3, -6), Vector2(4, -4), Color("a27d50"), 1)
		if active:
			draw_line(Vector2(3, -5), Vector2(8, -1), Color("a27d50"), 1)


## Ânfora à deriva: boia e se recolhe passando de barco por cima.
class Amphora extends Node2D:
	var amphora_id := ""
	var _clock := 0.0

	func _ready() -> void:
		add_to_group("sea_amphorae")
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clock = fposmod(position.x * .03, 5.0)

	func _process(delta: float) -> void:
		_clock += delta
		queue_redraw()

	func _draw() -> void:
		var bob := roundf(sin(_clock * 1.7) * 1.5)
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 13.0 + sin(_clock * 1.7) * 1.5, 0, TAU, 24, Color(.84, .93, .88, .32), 1)
		draw_set_transform(Vector2.ZERO)
		if not SeaArt.draw(self, "isle_v1", "amphora", 0.0, Vector2(0, bob)):
			draw_circle(Vector2(0, bob - 3), 6.0, Color("be733a"))


## Rochedo no meio da água; o barco esbarra nele.
class SeaRock extends StaticBody2D:
	var _clock := 0.0

	func _ready() -> void:
		collision_layer = 1
		collision_mask = 0
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var shape := CircleShape2D.new()
		shape.radius = 15.0
		var body := CollisionShape2D.new()
		body.shape = shape
		add_child(body)
		_clock = fposmod(position.y * .02, 4.0)

	func _process(delta: float) -> void:
		_clock += delta
		if fmod(_clock, .15) < delta:
			queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 22.0 + sin(_clock * 1.3) * 2.0, 0, TAU, 28, Color(.84, .93, .88, .28), 1)
		draw_set_transform(Vector2.ZERO)
		if not SeaArt.draw(self, "isle_v1", "sea_rock"):
			draw_colored_polygon(PackedVector2Array([Vector2(-18, 2), Vector2(-8, -22), Vector2(10, -20), Vector2(18, 2)]), Color("4b5553"))


## Anéis na água em volta de um navio ancorado, desenhados por baixo do casco.
class ShipWater extends Node2D:
	var _clock := 0.0
	var _tick := 0.0

	func _ready() -> void:
		show_behind_parent = true
		_clock = fposmod(get_parent().position.x * .013, 4.0)

	func _process(delta: float) -> void:
		_clock += delta
		_tick += delta
		if _tick >= 1.0 / 12.0:
			_tick = 0.0
			queue_redraw()

	func _draw() -> void:
		for ring in range(2):
			var age := fposmod(_clock * .35 + ring * .5, 1.0)
			draw_set_transform(Vector2(0, -3), 0, Vector2(1, .38))
			draw_arc(Vector2.ZERO, roundf(42.0 + age * 16.0), 0, TAU, 40, Color(.84, .93, .88, .3 * (1.0 - age)), 1)
		draw_set_transform(Vector2.ZERO)


## Esteira do barco e anéis das remadas, por cima da água e por baixo do chão.
class Wake extends Node2D:
	var trail: Array = []
	var rings: Array = []
	var _last := Vector2.INF

	func feed(boat: Node2D) -> void:
		var velocity: Vector2 = boat.velocity
		if velocity.length() < 14.0:
			_last = Vector2.INF
			return
		if _last != Vector2.INF and boat.global_position.distance_to(_last) < 7.0:
			return
		_last = boat.global_position
		var stern: Vector2 = boat.global_position + boat.hull_point(-24.0, 0.0)
		trail.append({"at": stern, "across": boat.hull_point(0.0, 1.0).normalized(), "age": 0.0})

	func ring(points: PackedVector2Array) -> void:
		for point in points:
			rings.append({"at": point, "age": 0.0})

	func _process(delta: float) -> void:
		for item in trail:
			item["age"] += delta
		for item in rings:
			item["age"] += delta
		trail = trail.filter(func(item): return item["age"] < 1.6)
		rings = rings.filter(func(item): return item["age"] < .9)
		if not trail.is_empty() or not rings.is_empty():
			queue_redraw()

	func _draw() -> void:
		for item in trail:
			var age: float = item["age"]
			var spread := 3.0 + age * 14.0
			var foam := Color(.86, .94, .9, (1.0 - age / 1.6) * .5)
			for side in [-1.0, 1.0]:
				var point: Vector2 = item["at"] + item["across"] * spread * side
				draw_rect(Rect2(point.round(), Vector2(2, 1)), foam)
		for item in rings:
			var age: float = item["age"]
			draw_set_transform(item["at"], 0, Vector2(1, .5))
			draw_arc(Vector2.ZERO, 3.0 + age * 14.0, 0, TAU, 16, Color(.88, .95, .9, (1.0 - age / .9) * .55), 1)
		draw_set_transform(Vector2.ZERO)


static func build(game) -> void:
	game.at_sea = false
	game.sea_busy = false
	var wake := Wake.new()
	wake.name = "BoatWake"
	# Mesmo z da água, desenhada antes: fica sobre o mar e sob o chão.
	wake.z_index = -1
	game.layout.add_child(wake)
	var boat := Boat.new()
	boat.name = "BarcoDeSabu"
	boat.stroked.connect(wake.ring)
	game.boat = boat
	game.actors.add_child(boat)
	for id in DOCKS:
		var post := MoorPost.new()
		post.item_id = "moor_" + id
		post.kind = "boat_moor"
		post.dock = id
		post.label = "Embarcar · barco de Sabu"
		post.position = Layout.iso(DOCKS[id]["land"])
		game.actors.add_child(post)
	for index in range(AMPHORAE.size()):
		var id := "isle_amphora_%d" % (index + 1)
		if id in game.store.data["collected"]:
			continue
		var amphora := Amphora.new()
		amphora.amphora_id = id
		amphora.position = Layout.iso(AMPHORAE[index])
		game.actors.add_child(amphora)
	for tile in SEA_ROCKS:
		var rock := SeaRock.new()
		rock.position = Layout.iso(tile)
		game.actors.add_child(rock)
	seat_moored_ships(game)
	moor(game, dock_for_checkpoint(game))


## Os navios de cenário do porto (port_dressing.gd, peça "boat") ganham linha
## d'água, balanço e anéis; sem isso pareciam pairar sobre o mar.
static func seat_moored_ships(game) -> void:
	for prop in game.actors.get_children():
		if prop is PortProp and prop.kind == "boat":
			seat_ship(prop)


## Assenta na água um nó que desenha a arte "boat" do porto (Art.draw_prop) no
## pivô de sempre. Serve também para navios que chegam e partem (trade_ship.gd).
static func seat_ship(ship: Node2D) -> bool:
	var bottom := _hull_bottom()
	if bottom == null or ship.has_node("ShipWater"):
		return false
	var material := ShaderMaterial.new()
	material.shader = MOORED_SHADER
	material.set_shader_parameter("hull_bottom", bottom)
	material.set_shader_parameter("phase", fposmod(ship.position.x * .021 + ship.position.y * .017, TAU))
	ship.material = material
	var water := ShipWater.new()
	water.name = "ShipWater"
	ship.add_child(water)
	return true


## A quilha do navio em cada coluna da arte, numa textura de 192×1. A água é
## plana: a quilha é a reta que passa pelo fundo do meio do casco. Pelo pé de
## cada coluna, a água subiria pelas pontas curvas da proa e da popa, que ficam no ar.
static func _hull_bottom() -> ImageTexture:
	if _hull_texture != null:
		return _hull_texture
	var bottom := Art.art_bottom("boat")
	if bottom.size() != Art.CELL:
		return null
	var keel := keel_line(bottom)
	var image := Image.create_empty(Art.CELL, 1, false, Image.FORMAT_R8)
	for column in range(Art.CELL):
		var value := clampf(roundf(keel.x * column + keel.y) + 176.0, 0.0, 254.0)
		image.set_pixel(column, 0, Color(value / 255.0, 0, 0))
	_hull_texture = ImageTexture.create_from_image(image)
	return _hull_texture


## Reta (inclinação, altura na coluna 0) pelos fundos do meio do casco: as
## colunas entre 25% e 75% da largura desenhada, por mínimos quadrados.
static func keel_line(bottom: PackedFloat32Array) -> Vector2:
	var first := -1
	var last := -1
	for column in range(bottom.size()):
		if not is_nan(bottom[column]):
			first = column if first < 0 else first
			last = column
	if first < 0:
		return Vector2(0, 1000)
	var from := first + (last - first) / 4
	var to := last - (last - first) / 4
	var n := 0.0
	var sx := 0.0
	var sy := 0.0
	var sxx := 0.0
	var sxy := 0.0
	for column in range(from, to + 1):
		if is_nan(bottom[column]):
			continue
		n += 1.0
		sx += column
		sy += bottom[column]
		sxx += column * column
		sxy += column * bottom[column]
	var spread := n * sxx - sx * sx
	if n < 2.0 or is_zero_approx(spread):
		return Vector2(0, sy / maxf(n, 1.0))
	var slope := (n * sxy - sx * sy) / spread
	return Vector2(slope, (sy - slope * sx) / n)


## O barco espera no píer do lado do último santuário: ninguém fica preso na ilha.
static func dock_for_checkpoint(game) -> String:
	return "bennu" if str(game.store.data["checkpoint"]) == "isle_rest" else "sabu"


static func moor(game, dock: String) -> void:
	game.boat_dock = dock
	var boat: Node2D = game.boat
	boat.rider = null
	boat.transfer_locked = false
	boat.velocity = Vector2.ZERO
	boat.rowing = false
	boat.global_position = Layout.iso(DOCKS[dock]["water"])
	boat.heading = DOCKS[dock]["heading"]
	boat.queue_redraw()
	_refresh_posts(game)


static func _refresh_posts(game) -> void:
	for post in game.get_tree().get_nodes_in_group("moor_posts"):
		post.active = not game.at_sea and post.dock == game.boat_dock
		post.highlighted = false
		post.label = "Embarcar · barco de Sabu"
		post.queue_redraw()


static func update(game, _delta: float) -> bool:
	IsleStory.tick(game)
	if game.sea_busy:
		game.nearest = null
		return true
	if not game.at_sea:
		return false
	game.nearest = null
	var dock := dock_in_reach(game)
	for post in game.get_tree().get_nodes_in_group("moor_posts"):
		post.highlighted = post.dock == dock
		post.active = post.dock == dock
		if post.dock == dock:
			post.label = "Atracar · " + str(DOCKS[dock]["name"])
			game.nearest = post
	if dock != "" and Input.is_action_just_pressed("interact"):
		land(game, dock)
	_collect_amphorae(game)
	var wake: Node2D = game.layout.get_node_or_null("BoatWake")
	if wake != null:
		wake.feed(game.boat)
	return true


## O píer ao alcance do barco, devagar o bastante para atracar, ou "".
static func dock_in_reach(game) -> String:
	var boat: Node2D = game.boat
	if boat.velocity.length() > DOCK_SPEED:
		return ""
	for id in DOCKS:
		if boat.global_position.distance_to(Layout.iso(DOCKS[id]["water"])) <= DOCK_REACH:
			return id
	return ""


static func activate(game, item: PortInteractable) -> bool:
	if item.kind != "boat_moor" or game.at_sea:
		return false
	return board(game)


static func board(game) -> bool:
	var player: SenuPlayer = game.player
	if player.dead or game.sea_busy or game.at_sea or game.respawning:
		return false
	game.sea_busy = true
	game.nearest = null
	player.controls_enabled = false
	player.velocity = Vector2.ZERO
	# Sem colisão, Senu não empurra o barco nem é empurrado pela borda do píer.
	player.set_meta("sea_collision", [player.collision_layer, player.collision_mask])
	player.collision_layer = 0
	player.collision_mask = 0
	player.visible = false
	var boat: Node2D = game.boat
	var tween: Tween = game.create_tween()
	game.set_meta("sea_tween", tween)
	_hop(tween, player, player.global_position, boat.global_position, "board")
	tween.tween_callback(_seated.bind(game))
	_sound(boat, "water_splash", -12.0)
	return true


static func _seated(game) -> void:
	var player: SenuPlayer = game.player
	_clear_transfer(player)
	player.visible = false
	game.boat.rider = player
	game.at_sea = true
	game.sea_busy = false
	_refresh_posts(game)
	if "boat_sailed" not in game.store.data["collected"]:
		game.store.collect("boat_sailed", 0)
		game._save()
	game.hud.toast("Barco de Sabu · WASD rema, Shift rema forte, E atraca nos píeres", Color("e2c693"), 5)


static func land(game, dock: String) -> void:
	if game.sea_busy or not game.at_sea:
		return
	game.sea_busy = true
	game.nearest = null
	var boat: Node2D = game.boat
	var player: SenuPlayer = game.player
	boat.transfer_locked = true
	boat.velocity = Vector2.ZERO
	boat.rowing = false
	var mooring := Layout.iso(DOCKS[dock]["water"])
	var tween: Tween = game.create_tween()
	game.set_meta("sea_tween", tween)
	tween.tween_property(boat, "global_position", mooring, .3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_turn.bind(boat, boat.heading, float(DOCKS[dock]["heading"])), 0.0, 1.0, .3)
	tween.tween_callback(func() -> void:
		player.global_position = mooring
		boat.rider = null)
	_hop(tween, player, mooring, Layout.iso(DOCKS[dock]["land"]), "land")
	tween.tween_callback(_ashore.bind(game, dock))
	_sound(boat, "water_splash", -14.0)


static func _turn(progress: float, boat: Node2D, from: float, to: float) -> void:
	boat.heading = lerp_angle(from, to, progress)
	boat.queue_redraw()


static func _ashore(game, dock: String) -> void:
	game.boat.transfer_locked = false
	_release(game.player)
	game.at_sea = false
	game.sea_busy = false
	game.boat_dock = dock
	_refresh_posts(game)
	if DOCKS[dock]["side"] == "isle":
		IsleStory.on_landed(game)
	elif DOCKS[dock]["side"] == "far":
		FarIsles.on_landed(game, dock)


## Devolve a Senu o corpo, a colisão e os controles.
static func _release(player: SenuPlayer) -> void:
	_clear_transfer(player)
	player.visible = true
	player.controls_enabled = true
	if player.has_meta("sea_collision"):
		var saved: Array = player.get_meta("sea_collision")
		player.collision_layer = saved[0]
		player.collision_mask = saved[1]
		player.remove_meta("sea_collision")


## Pivô lógico no chão; a altura pertence só ao desenho do sprite transitório.
static func _hop(tween: Tween, body: Node2D, from: Vector2, to: Vector2, action: String) -> void:
	# A criação deve ocorrer na etapa certa do tween (após alinhar ao desembarcar).
	tween.tween_callback(_begin_transfer.bind(body, from, to, action))
	tween.tween_method(_transfer_step.bind(body, from, to), 0.0, 1.0, HOP)


static func _begin_transfer(body: Node2D, from: Vector2, to: Vector2, action: String) -> void:
	_clear_transfer(body)
	var view := SenuBoatView.new()
	view.name = "SenuSeaTransfer"
	view.actor = body
	view.state = action
	view.facing = (to - from).normalized()
	body.facing = view.facing
	body.get_parent().add_child(view)
	view.global_position = from
	body.set_meta("sea_transfer", view)
	body.visible = false


static func _transfer_step(phase: float, body: Node2D, from: Vector2, to: Vector2) -> void:
	body.global_position = from.lerp(to, smoothstep(0.0, 1.0, phase))
	var view: Node2D = body.get_meta("sea_transfer") if body.has_meta("sea_transfer") else null
	if is_instance_valid(view):
		view.progress = phase
		view.global_position = body.global_position
		view.queue_redraw()


static func _clear_transfer(body: Node2D) -> void:
	var view: Node2D = body.get_meta("sea_transfer") if body.has_meta("sea_transfer") else null
	if is_instance_valid(view):
		view.hide()
		view.queue_free()
	if body.has_meta("sea_transfer"):
		body.remove_meta("sea_transfer")


## Ao voltar ao santuário: Senu desce do barco e o barco vai para o píer do
## lado desse santuário.
static func respawn(game) -> void:
	if game.has_meta("sea_tween"):
		var tween: Tween = game.get_meta("sea_tween")
		if tween != null and tween.is_valid():
			tween.kill()
	if game.at_sea or game.sea_busy:
		_release(game.player)
	game.at_sea = false
	game.sea_busy = false
	moor(game, dock_for_checkpoint(game))


static func _collect_amphorae(game) -> void:
	var boat: Node2D = game.boat
	for amphora in game.get_tree().get_nodes_in_group("sea_amphorae"):
		if amphora.is_queued_for_deletion() or boat.global_position.distance_to(amphora.global_position) > AMPHORA_REACH:
			continue
		game.store.collect(amphora.amphora_id, 0)
		amphora.queue_free()
		game.collect_loot("coin", AMPHORA_COINS)
		var found := 0
		for index in range(AMPHORAE.size()):
			found += int("isle_amphora_%d" % (index + 1) in game.store.data["collected"])
		game.hud.toast("Ânfora à deriva · %d de %d" % [found, AMPHORAE.size()], Color("e2c693"), 3)
		_sound(boat, "water_plop", -8.0)


static func _sound(at: Node2D, bank: String, volume: float) -> void:
	if Sfx.has_bank(bank):
		Sfx.play(at, bank, at.global_position, volume)
