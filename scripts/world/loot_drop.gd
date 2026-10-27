extends Node2D
class_name PortLoot

## Recompensa deixada por um inimigo vencido. Os orbes de XP voam sozinhos até
## Senu; as moedas saltam, assentam no chão e são atraídas quando ele passa perto.
## A recompensa só conta ao tocar Senu, pelo `collector` (port_demo.collect_loot).

const GRAVITY := 340.0
const MAGNET_RADIUS := 56.0
const COLLECT_RADIUS := 8.0
const XP_DELAY := .45
## Um orbe que não alcança Senu (morte, porta, menu) é creditado mesmo assim.
const XP_TIMEOUT := 4.0
const MAX_SPEED := 300.0
const Sfx = preload("res://scripts/audio/sfx.gd")

var kind := "coin"
var value := 1
var target: Node2D
var collector: Callable
var _slide := Vector2.ZERO
var _height := 0.0
var _rise := 0.0
var _age := 0.0
var _speed := 0.0
var _homing := false
var _collected := false
var _spin := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("loot")
	# Um pequeno salto em direção aleatória, achatado como o chão isométrico.
	var angle := randf() * TAU
	var push := randf_range(26.0, 48.0) if kind == "coin" else randf_range(10.0, 22.0)
	_slide = Vector2(cos(angle), sin(angle) * .5) * push
	_rise = randf_range(70.0, 105.0) if kind == "coin" else randf_range(35.0, 55.0)
	_height = 6.0
	_spin = randf() * TAU

func _process(delta: float) -> void:
	_age += delta
	_spin += delta * 9.0
	if _collected:
		return
	if not _homing:
		position += _slide * delta
		_slide = _slide.move_toward(Vector2.ZERO, delta * 90.0)
		_rise -= GRAVITY * delta
		_height = maxf(0.0, _height + _rise * delta)
		if _height <= 0.0 and _rise < 0.0:
			# Quica uma vez e assenta.
			_rise = -_rise * .3 if absf(_rise) > 40.0 else 0.0
		if kind == "xp":
			_height = maxf(_height, 10.0 + sin(_age * 6.0) * 2.0)
		_homing = _wants_target()
	else:
		_chase(delta)
	if kind == "xp" and _age > XP_TIMEOUT:
		_collect()
	queue_redraw()

func _wants_target() -> bool:
	if not is_instance_valid(target) or bool(target.get("dead")):
		return false
	if kind == "xp":
		return _age >= XP_DELAY
	return _height <= 0.0 and position.distance_to(target.position) < MAGNET_RADIUS

func _chase(delta: float) -> void:
	if not is_instance_valid(target) or bool(target.get("dead")):
		_homing = false
		_speed = 0.0
		return
	_speed = minf(MAX_SPEED, _speed + delta * (520.0 if kind == "xp" else 380.0))
	var goal := target.position
	position = position.move_toward(goal, _speed * delta)
	# Sobe até a altura do peito de Senu enquanto se aproxima.
	_height = move_toward(_height, 14.0, delta * 40.0)
	if position.distance_to(goal) <= COLLECT_RADIUS:
		_collect()

func _collect() -> void:
	if _collected:
		return
	_collected = true
	if kind == "coin":
		# Moedas maiores soam um pouco mais graves.
		Sfx.play(self, "pickup_coin", global_position, 0.0, {25: .86, 5: .93}.get(value, 1.0))
	if collector.is_valid():
		collector.call(kind, value)
	queue_free()

func _draw() -> void:
	var lift := Vector2(0, -roundf(_height))
	# A sombra fica no chão e encolhe com a altura.
	var shadow := clampf(1.0 - _height / 30.0, .35, 1.0)
	draw_rect(Rect2(Vector2(-3, -1) * shadow, Vector2(6, 2) * shadow), Color(.01, .025, .03, .3))
	if kind == "xp":
		draw_circle(lift, 6, Color(.62, .9, .82, .12))
		draw_circle(lift, 3, Color("8fd6c2"))
		draw_rect(Rect2(lift + Vector2(-1, -1), Vector2(2, 2)), Color("f1fff6"))
		return
	var face: Color = {25: Color("e8c25c"), 5: Color("c9cfc8")}.get(value, Color("c48a4e"))
	var radius := 4.0 if value >= 25 else (3.0 if value >= 5 else 2.0)
	# A largura oscila para a moeda parecer girar no ar; no chão ela deita.
	var width := maxf(1.0, roundf(absf(cos(_spin)) * radius)) if _height > 0.0 or _homing else radius
	var height := radius if _height > 0.0 or _homing else maxf(1.0, radius * .5)
	draw_rect(Rect2(lift + Vector2(-width, -height * 2), Vector2(width * 2, height * 2)), face.darkened(.35))
	draw_rect(Rect2(lift + Vector2(-width + 1, -height * 2), Vector2(maxf(1, width * 2 - 2), maxf(1, height * 2 - 1))), face)
	draw_rect(Rect2(lift + Vector2(-width + 1, -height * 2), Vector2(1, 1)), face.lightened(.45))
