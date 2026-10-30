extends PortInteractable

## Um morador do Porto (docs/MUNDO_VIDA.md). Segue a rotina do catálogo, parada
## a parada, pelos caminhos que port_life.gd calcula em volta do cenário. Senu
## esbarra nele (camada 4, a dos inimigos), mas a espada não o acerta: ele não
## está no grupo "enemies". Longe de Senu, a rotina pausa.
## `kind` é "townsfolk" (fala ao apertar E) ou "vendor" (vende na bancada).

const SHEET := "res://assets/world/townsfolk_v3.png"
const WalkArt = preload("res://scripts/world/npc_walk_art.gd")
const CELL := Vector2(64, 64)
const PIVOT := Vector2(32, 58)
const POSES := ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "talk", "carry_idle", "carry_1", "carry_2", "carry_3", "carry_4", "bend", "breathe", "blink", "carry_breathe", "carry_blink"]
## Mesma escala vertical do passo de Senu (player.gd).
const ISO_Y := .70
## Distância de Senu em que a rotina anda; além disso tudo para.
const AWAKE_RANGE := 1100.0
## Raio do corpo e quanto espaço à frente o morador espera Senu liberar.
const BODY_RADIUS := 5.0
const MAKE_WAY := 16.0
static var _sheet: Texture2D
static var _floor: Dictionary = {}

var look := 0
var title := ""
var lines: Array = []
var speed := 30.0
## Paradas: [{"at": Vector2 (px), "act": String, "time": float, "extra": Variant, "path": PackedVector2Array}].
var stops: Array = []
## Vendedor: o que vende, por quanto e quanto cura.
var goods: Dictionary = {}
## Navios por id, para os estivadores saberem quando há carga.
var ships: Dictionary = {}
var facing := 1.0
var carrying := false
var talks := 0
## Paradas cumpridas desde que o mundo montou.
var visits := 0
var _stop := 0
var _waypoint := 0
var _acting := false
var _clock := 0.0
var _walk_time := 0.0
var _walk_distance := 0.0
var _walking := false
var _gesture := 0.0
var _attend_clock := 0.0
var _pushed := 0.0
var _ghost := 0.0
var _hero: Node2D
var _body: AnimatableBody2D


func _ready() -> void:
	super._ready()
	add_to_group("townsfolk")
	if _sheet == null and ResourceLoader.exists(SHEET):
		_sheet = load(SHEET) as Texture2D
	_body = AnimatableBody2D.new()
	# Sincronizado com a física, o corpo ficava parado na origem em vez de seguir o morador.
	_body.sync_to_physics = false
	_body.collision_layer = 4
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS
	shape.shape = circle
	_body.add_child(shape)
	add_child(_body)
	if not stops.is_empty():
		position = stops[0]["at"]
		_begin_act()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_hero):
		_hero = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(_hero) and position.distance_squared_to(_hero.position) > AWAKE_RANGE * AWAKE_RANGE:
		if _walking:
			_walking = false
			queue_redraw()
		return
	advance(delta)


## Um passo da rotina. Separado de _physics_process para os testes avançarem o tempo.
func advance(delta: float) -> void:
	var previous := position
	var was_walking := _walking
	_walking = false
	_advance_route(delta)
	# Measure the displacement that actually happened, including the short final
	# waypoint step and making way for Senu. Time, speed and facing never reset it.
	var moved := position - previous
	var distance := Vector2(moved.x, moved.y / ISO_Y).length()
	if distance > .0001 and kind != "vendor":
		_walk_distance += distance
		_walk_time += distance / maxf(speed, .001)
		_walking = true
		if absf(moved.x) > .05:
			facing = signf(moved.x)
	if _walking or was_walking:
		queue_redraw()


## Ground distance is independent of facing, load, stops and rendering cadence.
func walk_distance() -> float:
	return _walk_distance


func is_walking() -> bool:
	return _walking


func _advance_route(delta: float) -> void:
	_gesture = maxf(0.0, _gesture - delta)
	if kind == "vendor":
		_attend(delta)
		return
	if stops.is_empty() or _make_way(delta):
		return
	if _acting:
		_act(delta)
		return
	var path: PackedVector2Array = stops[_stop]["path"]
	if _waypoint >= path.size():
		_begin_act()
		return
	var target := path[_waypoint]
	var offset := target - position
	# A conta é feita no plano do chão, como o passo de Senu.
	var ground := Vector2(offset.x, offset.y / ISO_Y)
	var step := speed * delta
	if ground.length() <= step:
		position = target
		_waypoint += 1
		return
	var direction := ground.normalized()
	var move := Vector2(direction.x, direction.y * ISO_Y) * step
	if _blocked_by_hero(move):
		return
	if absf(move.x) > .05:
		facing = signf(move.x)
	position += move


## Senu encostado: o morador dá um passo para o lado, para fora da linha do
## Senu. Encostado e travado, o Senu fica com velocidade zero; por isso conta o
## tempo de contato, não o empurrão. Sem chão livre por um segundo, o morador
## deixa de ser sólido um instante e o Senu passa. Ninguém tranca um corredor.
func _make_way(delta: float) -> bool:
	if _ghost > 0.0:
		_ghost -= delta
		if _ghost <= 0.0: _body.collision_layer = 4
	if not is_instance_valid(_hero):
		return false
	var away := position - _hero.position
	if away.length() > BODY_RADIUS + 8.0:
		_pushed = 0.0
		return false
	_pushed += delta
	if _pushed < .2:
		return false
	var push: Vector2 = _hero.velocity if "velocity" in _hero else Vector2.ZERO
	var line := push if push.length() > 10.0 else away
	var side := Vector2(-line.y, line.x).normalized()
	if side.dot(away) < 0.0: side = -side
	var step := speed * 1.2 * delta
	for direction in [side, -side, away.normalized()]:
		if _free(position + direction * step):
			position += direction * step
			return true
	if _pushed > 1.2 and _ghost <= 0.0:
		_ghost = 1.5
		_body.collision_layer = 0
	return true


## Chão sem cenário para o corpo, e dentro do piso.
func _free(point: Vector2) -> bool:
	if _floor.is_empty():
		_floor = PortLayout.tile_catalog()
	if not _floor.has(Vector2i((PortLayout.unproject(point) + Vector2(.5, .5)).floor())):
		return false
	var circle := CircleShape2D.new()
	circle.radius = BODY_RADIUS + 1.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0, point)
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _blocked_by_hero(move: Vector2) -> bool:
	if not is_instance_valid(_hero):
		return false
	var away := _hero.position - position
	return away.length() < MAKE_WAY and away.dot(move) > 0.0


func _begin_act() -> void:
	_acting = true
	_clock = 0.0
	var stop: Dictionary = stops[_stop]
	if stop.get("extra") is int:
		facing = float(stop["extra"])
	elif stop["act"] == "buy" and stop.get("vendor") != null:
		_face(stop["vendor"].position)
	elif stop["act"] == "chat":
		# Conversa com quem estiver mais perto, se houver alguém.
		var nearest: Node2D = null
		for other in get_tree().get_nodes_in_group("townsfolk"):
			if other != self and other.position.distance_to(position) < 70 and (nearest == null or other.position.distance_to(position) < nearest.position.distance_to(position)):
				nearest = other
		if nearest != null: _face(nearest.position)


func _face(point: Vector2) -> void:
	if absf(point.x - position.x) > 1.0:
		facing = signf(point.x - position.x)


## O vendedor gesticula enquanto algum freguês compra na bancada dele.
func _attend(delta: float) -> void:
	_attend_clock += delta
	if _attend_clock < .5:
		return
	_attend_clock = 0.0
	for other in get_tree().get_nodes_in_group("townsfolk"):
		if other.kind == "townsfolk" and other.is_buying_at(item_id):
			gesture(.6)
			_face(other.position)
			return


func _act(delta: float) -> void:
	var stop: Dictionary = stops[_stop]
	if stop["act"] == "ship":
		var ship: Node = ships.get(stop["extra"])
		# Sem navio atracado, o estivador espera olhando o mar.
		if ship == null or not ship.docked():
			_clock = 0.0
			return
	_clock += delta
	if _clock < float(stop["time"]):
		return
	match stop["act"]:
		"pick", "ship", "buy":
			carrying = true
		"drop":
			carrying = false
	_acting = false
	visits += 1
	_stop = (_stop + 1) % stops.size()
	_waypoint = 0


## A pose de agora: coluna da folha de arte.
func pose() -> int:
	if kind == "vendor":
		return 5 if _gesture > 0.0 and fmod(time, .6) < .4 else rest_pose()
	if is_walking():
		var frame := int(_walk_distance / 6.0) % 4
		return (7 if carrying else 1) + frame
	if not _acting:
		return rest_pose()
	var stop: Dictionary = stops[_stop]
	match stop["act"]:
		"pray":
			return 11
		"pick", "drop", "ship":
			return 11 if _clock > .2 or stop["act"] != "ship" else (6 if carrying else 0)
		"chat", "buy":
			return 5 if fmod(time + float(look) * .37, 1.6) < .8 else rest_pose()
	return rest_pose()

## Asynchronous rest cycle: short closed eyelid, slower chest lift, feet fixed.
func rest_pose() -> int:
	var clock := fposmod(time + float(look) * .37, 5.8)
	if clock >= 4.7 and clock < 4.825: return 15 if carrying else 13
	if (clock >= 1.1 and clock < 1.9) or (clock >= 3.1 and clock < 3.9):
		return 14 if carrying else 12
	return 6 if carrying else 0


## Freguês parado na bancada `vendor_id`: o vendedor gesticula para ele.
func is_buying_at(vendor_id: String) -> bool:
	return _acting and stops[_stop]["act"] == "buy" and stops[_stop].get("extra") == vendor_id


func gesture(seconds: float = 1.6) -> void:
	_gesture = seconds


func _draw() -> void:
	# Sombra de contato sob os pés; o corpo cobre o meio dela.
	draw_rect(Rect2(-7, -2, 14, 4), Color(.01, .025, .03, .22))
	draw_rect(Rect2(-5, -3, 10, 6), Color(.01, .025, .03, .14))
	if highlighted:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 17, 0, TAU, 24, Color("dcc28c"), 1)
		draw_set_transform(Vector2.ZERO)
	if _acting and stops[_stop]["act"] == "fish":
		_fishing_line()
	if _sheet == null:
		draw_rect(Rect2(-5, -36, 10, 36), Color("7d6a52"))
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	if is_walking() and WalkArt.draw(self, look, carrying, walk_distance()):
		draw_set_transform(Vector2.ZERO)
		return
	var region := Rect2(Vector2(pose(), look) * CELL, CELL)
	draw_texture_rect_region(_sheet, Rect2(-PIVOT, CELL), region)
	draw_set_transform(Vector2.ZERO)


func _fishing_line() -> void:
	var hand := Vector2(6 * facing, -27)
	var tip := Vector2(17 * facing, -40)
	# 40 px para o lado e 12 para baixo: a boia cai na água, além da borda.
	var float_at := Vector2(40 * facing, 12 + roundf(sin(time * 2.2) * 1.5))
	draw_line(hand, tip, Color("6b5132"), 1)
	draw_line(tip, float_at, Color(.86, .82, .7, .55), 1)
	draw_rect(Rect2(float_at - Vector2(1, 1), Vector2(2, 2)), Color("d7a35a"))
