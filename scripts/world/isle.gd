extends RefCounted

## Ilha do Bennu: santuário, vegetação, garças e as peças das missões
## (isle_story.gd). Chamado pelo port_demo: `build` ao montar o mundo e
## `activate` para as peças "isle_*". O chão vem de isle_layout.gd, pela sala
## "isle" de port_layout.gd.

const IsleLayout = preload("res://scripts/world/isle_layout.gd")
const IsleStory = preload("res://scripts/world/isle_story.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")
const NpcArt = preload("res://scripts/world/npc_art.gd")
const Art = preload("res://scripts/world/port_art.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const KINDS := ["isle_npc", "isle_brazier", "isle_altar", "isle_net"]
## Raio do tronco ou da base que bloqueia Senu, em pixels.
const SOLID_RADIUS := {"palm": 7.0, "acacia": 5.0, "sycamore": 9.0, "bush_a": 8.0, "bush_b": 8.0, "rock_a": 12.0, "rock_b": 9.0, "column_broken": 7.0}
## Copas que ficam transparentes quando escondem Senu: altura e meia largura.
const CANOPY := {"palm": Vector2(98, 40), "acacia": Vector2(60, 30), "sycamore": Vector2(82, 40)}


## Árvore, arbusto, rocha ou ruína da ilha.
class IsleProp extends Node2D:
	var kind := ""
	var solid := true
	var _clock := 0.0
	var _tick := 0.0
	var _hero: Node2D
	var _fade := 1.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_clock = fposmod(position.x * .017 + position.y * .009, 3.0)
		if solid and SOLID_RADIUS.has(kind):
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			var shape := CircleShape2D.new()
			shape.radius = SOLID_RADIUS[kind]
			var collider := CollisionShape2D.new()
			collider.shape = shape
			body.add_child(collider)
			add_child(body)
		set_process(CANOPY.has(kind))

	## Copas altas somem pela metade quando Senu passa atrás delas.
	func _process(delta: float) -> void:
		_tick += delta
		if _tick < .1:
			return
		_tick = 0.0
		if not is_instance_valid(_hero):
			_hero = get_tree().get_first_node_in_group("player") as Node2D
		var fade := 1.0
		if is_instance_valid(_hero) and _hero.visible:
			var offset := _hero.global_position - global_position
			var canopy: Vector2 = CANOPY[kind]
			if offset.y < 0 and offset.y > -canopy.x and absf(offset.x) < canopy.y:
				fade = .45
		if fade != _fade:
			_fade = fade
			modulate.a = fade

	func _draw() -> void:
		if kind == "palm":
			draw_rect(Rect2(-12, -2, 24, 4), Color(.01, .025, .03, .22))
			if Art.draw_prop(self, "palm"):
				return
		elif kind not in ["reeds", "driftwood"]:
			draw_rect(Rect2(-10, -2, 20, 4), Color(.01, .025, .03, .2))
		if SeaArt.draw(self, "isle_v1", kind, _clock):
			return
		# Reserva sem a folha: um tronco e uma copa redonda, ou uma pedra.
		if kind in ["rock_a", "rock_b", "column_broken"]:
			draw_colored_polygon(PackedVector2Array([Vector2(-10, 0), Vector2(-6, -12), Vector2(6, -12), Vector2(10, 0)]), Color("646b60"))
		else:
			draw_rect(Rect2(-2, -24, 4, 24), Color("4b3b2d"))
			draw_circle(Vector2(0, -30), 12.0, Color("7d8051"))


## Garça na água rasa. Levanta voo quando Senu chega perto e volta depois.
class Heron extends Node2D:
	const SCARE := 70.0
	const AWAY := 22.0
	var home := Vector2.ZERO
	var _clock := 0.0
	var _flying := 0.0
	var _hero: Node2D

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		home = position
		_clock = fposmod(position.x * .021, 6.0)

	func _process(delta: float) -> void:
		_clock += delta
		if not is_instance_valid(_hero):
			_hero = get_tree().get_first_node_in_group("player") as Node2D
		if _flying > 0.0:
			_flying += delta
			position = home + Vector2(-70, -120) * minf(_flying / 2.5, 1.0)
			modulate.a = clampf(1.0 - (_flying - 1.5), 0.0, 1.0)
			if _flying > AWAY:
				_flying = 0.0
				position = home
				modulate.a = 1.0
		elif is_instance_valid(_hero) and _hero.global_position.distance_to(global_position) < SCARE:
			_flying = .01
		queue_redraw()

	func flying() -> bool:
		return _flying > 0.0

	func _draw() -> void:
		if _flying > 0.0:
			if not SeaArt.draw(self, "isle_v1", "heron_fly", _clock):
				draw_line(Vector2(-8, -30), Vector2(8, -30), Color("b4b298"), 2)
			return
		draw_set_transform(Vector2(0, 1), 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 7.0 + sin(_clock * 1.6), 0, TAU, 16, Color(.84, .93, .88, .3), 1)
		draw_set_transform(Vector2.ZERO)
		if not SeaArt.draw(self, "isle_v1", "heron", _clock):
			draw_line(Vector2(0, 0), Vector2(0, -20), Color("b4b298"), 2)


## Ankhet, os braseiros, o altar e a rede: peças das missões, com desenho próprio.
class IsleFixture extends PortInteractable:
	func _draw() -> void:
		if not active and kind == "isle_net":
			return
		if highlighted:
			draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
			draw_arc(Vector2.ZERO, 21, 0, TAU, 24, Color("dcc28c"), 1)
			draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(-10, -2, 20, 4), Color(.01, .025, .03, .24))
		var piece: String = {"isle_npc": "ankhet", "isle_net": "net"}.get(kind, "")
		match kind:
			"isle_brazier":
				piece = "brazier_on" if opened else "brazier_off"
			"isle_altar":
				piece = "altar_open" if opened else "altar_closed"
		if kind == "isle_npc" and NpcArt.draw(self, "ankhet", time):
			return
		if SeaArt.draw(self, "isle_v1", piece, time):
			return
		match kind:
			"isle_npc":
				draw_rect(Rect2(-6, -30, 12, 30), Color("dbcfaa"))
				draw_circle(Vector2(0, -34), 5.0, Color("a27d50"))
			"isle_brazier":
				draw_rect(Rect2(-6, -18, 12, 18), Color("81816e"))
				if opened:
					draw_colored_polygon(PackedVector2Array([Vector2(-5, -18), Vector2(0, -32), Vector2(5, -18)]), Color("e69d4a"))
			"isle_altar":
				draw_rect(Rect2(-18, -18, 36, 18), Color("bdad89"))
			"isle_net":
				draw_rect(Rect2(-14, -6, 28, 6), Color("846443"))


static func build(game) -> void:
	var rest: Vector2 = IsleLayout.MARKERS["isle_rest"]
	game.checkpoints["isle_rest"] = rest
	game._add_item("isle_rest", "shrine", rest, "Meditar · salvar e renovar inimigos")
	for piece in IsleLayout.PROPS:
		var prop := IsleProp.new()
		prop.kind = piece[0]
		prop.solid = piece[2]
		prop.position = Layout.iso(piece[1])
		game.actors.add_child(prop)
	for tile in IsleLayout.HERONS:
		var heron := Heron.new()
		heron.position = Layout.iso(tile)
		game.actors.add_child(heron)
	_fixture(game, "isle_ankhet", "isle_npc", "ankhet")
	for id in IsleStory.FLAME_ORDER:
		_fixture(game, id, "isle_brazier", id)
	_fixture(game, "bennu_altar", "isle_altar", "bennu_altar")
	if "isle_net" not in game.store.data["collected"]:
		_fixture(game, "hori_net", "isle_net", "hori_net")
	IsleStory.refresh(game)


static func _fixture(game, id: String, kind: String, marker: String) -> PortInteractable:
	var item := IsleFixture.new()
	item.item_id = id
	item.kind = kind
	item.position = Layout.iso(IsleLayout.MARKERS[marker])
	game.actors.add_child(item)
	return item


static func activate(game, item: PortInteractable) -> bool:
	return IsleStory.activate(game, item)
