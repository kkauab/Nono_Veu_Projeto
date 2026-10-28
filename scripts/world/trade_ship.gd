extends Node2D

## Navio mercante (docs/MUNDO_VIDA.md). Ciclo sem sorteio: chega de proa pela
## rota `arrive`, fica atracado `dock_time` segundos enquanto os estivadores
## descarregam, recua de ré por `astern` (se houver), sai de proa por `leave`
## e passa `away_time` segundos longe, fora da vista, antes de voltar.
## A arte só tem a proa para longe da câmera (nordeste; espelhada, noroeste),
## por isso o navio chega de frente e sai de ré antes de virar.
## Não tem corpo de colisão: um corpo andando empurraria o barco de Sabu.

const Art = preload("res://scripts/world/port_art.gd")
const Sea = preload("res://scripts/world/sea.gd")
const SAIL_SPEED := 30.0
const ASTERN_SPEED := 14.0
## Ao chegar ou partir, o navio surge e some no mar ao longo destes pixels.
const FADE_DISTANCE := 260.0

var ship_id := ""
var title := ""
var tint := Color.WHITE
## Rotas em pixels do mundo.
var arrive := PackedVector2Array()
var astern := PackedVector2Array()
var leave := PackedVector2Array()
var dock_time := 40.0
var away_time := 25.0
## Segundos já passados no ciclo ao montar o mundo.
var phase := 0.0
var state := "away"
var mirror := false
var _route := PackedVector2Array()
var _point := 0
var _clock := 0.0
var _time := 0.0
var _redraw := 0.0
var _wake: Wake


## Espuma atrás do casco, num nó à parte: o shader da linha d'água do navio
## (Sea.seat_ship) só sabe lidar com a arte do casco.
class Wake extends Node2D:
	var ship: Node2D

	func _draw() -> void:
		if not ship.state in ["arriving", "astern", "leaving"]:
			return
		var side := -1.0 if ship.mirror else 1.0
		var back := Vector2(-34 * side, 8)
		for index in range(3):
			var drift := float(index) * 7.0 + fmod(ship._time * 9.0, 7.0)
			draw_rect(Rect2(back + Vector2(-drift * side, drift * .5), Vector2(5, 1)), Color(.86, .93, .9, .35 - index * .1))


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("trade_ships")
	self_modulate = tint
	_wake = Wake.new()
	_wake.ship = self
	_wake.show_behind_parent = true
	add_child(_wake)
	position = arrive[0]
	_set_state("away")
	advance(phase)
	Sea.seat_ship(self)


func _physics_process(delta: float) -> void:
	advance(delta)


func docked() -> bool:
	return state == "docked"


## Avança o ciclo; dividido em passos pequenos para os testes poderem pular minutos.
func advance(delta: float) -> void:
	var left := delta
	while left > 0.0:
		var step := minf(left, .1)
		left -= step
		_step(step)
	_time += delta
	modulate.a = _fade()
	_redraw += delta
	if _redraw >= .1:
		_redraw = 0.0
		queue_redraw()
		_wake.queue_redraw()


func _step(delta: float) -> void:
	_clock += delta
	match state:
		"away":
			if _clock >= away_time: _set_state("arriving")
		"docked":
			if _clock >= dock_time: _set_state("astern" if not astern.is_empty() else "leaving")
		"arriving", "astern", "leaving":
			var speed := ASTERN_SPEED if state == "astern" else SAIL_SPEED
			var target := _route[_point]
			var offset := target - position
			var travel := speed * delta
			if offset.length() <= travel:
				position = target
				_point += 1
				if _point >= _route.size():
					_set_state({"arriving": "docked", "astern": "leaving", "leaving": "away"}[state])
				return
			var move := offset.normalized() * travel
			# A proa aponta para onde o navio vai, exceto de ré.
			if state != "astern" and absf(move.x) > .01:
				mirror = move.x < 0.0
			position += move


func _set_state(next: String) -> void:
	state = next
	_clock = 0.0
	_point = 0
	match next:
		"away":
			position = arrive[0]
			mirror = arrive[1].x < arrive[0].x
		"arriving":
			_route = arrive.slice(1)
		"astern":
			_route = astern
		"leaving":
			_route = leave
	visible = next != "away"


## Opacidade ao surgir e sumir no mar aberto, longe do cais.
func _fade() -> float:
	if state == "arriving":
		return clampf(position.distance_to(arrive[0]) / FADE_DISTANCE, 0.0, 1.0)
	if state == "leaving":
		return clampf(position.distance_to(leave[leave.size() - 1]) / FADE_DISTANCE, 0.0, 1.0)
	return 1.0


func _draw() -> void:
	# O balanço de 1 px vem do shader da linha d'água.
	draw_set_transform(Vector2.ZERO, 0, Vector2(-1 if mirror else 1, 1))
	Art.draw_prop(self, "boat")
	draw_set_transform(Vector2.ZERO)
