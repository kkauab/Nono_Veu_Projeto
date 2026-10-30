extends CharacterBody2D

## O barco de Sabu (docs/MUNDO_BARCO_ILHA.md). Atracado, só balança. Com Senu a
## bordo (`rider`), lê as mesmas teclas de movimento e rema com inércia: acelera,
## desliza quando se solta a tecla e vira a proa aos poucos. Colide só com o
## ambiente (camada 1), então as bordas do chão o seguram na água.

const SeaArt = preload("res://scripts/world/sea_art.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
## Mesma escala vertical do movimento de Senu (player.gd).
const ISO_Y := .70
const CRUISE := 118.0
const SPRINT := 172.0
const ACCELERATION := 150.0
const DRAG := 90.0
## Radianos por segundo, no plano do chão.
const TURN_RATE := 3.4
const RADIUS := 11.0
const DIRECTIONS := 16
## Quadros de cada direção em boat_v4: parado, oito de remada e vazio.
const FRAME_IDLE := 0
const ROW_FRAMES := 8
const FRAME_EMPTY := 9
## Até onde se rema: longe das casas, que ficam além de x = 4400.
const BOUNDS := Rect2(-3600, -2000, 7200, 5200)

## Uma remada terminou; `blades` são as pontas dos dois remos, na tela.
signal stroked(blades: PackedVector2Array)
## O casco cedeu às mordidas (sea_beasts.gd): Senu cai na água (sea.gd `capsize`).
signal wrecked

## Casco: as mordidas tiram; atracado num píer, é remendado (sea.gd).
const HULL_MAX := 100
var hull := HULL_MAX
var _shake := 0.0

## Ângulo da proa no plano do chão (0 aponta para a direita da tela).
var heading := PI * .75
var rider: Node2D
## Mantém Senu sentado durante o encaixe sem aceitar outra remada.
var transfer_locked := false
var rowing := false
## Fase da remada, de 0 a 1.
var stroke := 0.0
var _clock := 0.0
var _draw_tick := 0.0


func _ready() -> void:
	add_to_group("boat")
	collision_layer = 0
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var body := CollisionShape2D.new()
	body.shape = shape
	add_child(body)
	_clock = fposmod(position.x * .011, 6.0)


func _physics_process(delta: float) -> void:
	_clock += delta
	_shake = maxf(0.0, _shake - delta)
	if rider == null or transfer_locked:
		velocity = Vector2.ZERO
		rowing = false
		_draw_tick += delta
		if _draw_tick >= .1:
			_draw_tick = 0.0
			queue_redraw()
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	drive(input, InputMap.has_action("sprint") and Input.is_action_pressed("sprint"), delta)


## Uma etapa de remo. Separada do teclado para os testes poderem remar.
func drive(input: Vector2, sprint: bool, delta: float) -> void:
	var target := Vector2(input.x, input.y * ISO_Y) * (SPRINT if sprint else CRUISE)
	var pulling := input.length_squared() > .01
	velocity = velocity.move_toward(target, (ACCELERATION if pulling else DRAG) * delta)
	move_and_slide()
	var inside := global_position.clamp(BOUNDS.position, BOUNDS.end)
	if inside != global_position:
		global_position = inside
		velocity = Vector2.ZERO
	if velocity.length() > 6.0:
		heading = rotate_toward(heading, ground_angle(velocity), TURN_RATE * delta)
	rowing = pulling
	if rowing:
		var before := stroke
		stroke = fposmod(stroke + delta * (1.5 if sprint else 1.05), 1.0)
		if stroke < before:
			_splash()
	if is_instance_valid(rider):
		rider.global_position = global_position
	queue_redraw()


## Direção de um vetor da tela no plano do chão (a tela achata o chão pela metade).
static func ground_angle(screen: Vector2) -> float:
	return atan2(screen.y * 2.0, screen.x)


func direction() -> int:
	return posmod(roundi(heading / (TAU / DIRECTIONS)), DIRECTIONS)


## Um ponto do barco (u para a proa, v para estibordo) na tela, relativo ao centro.
func hull_point(u: float, v: float) -> Vector2:
	return Vector2(u * cos(heading) - v * sin(heading), (u * sin(heading) + v * cos(heading)) * .5)


## Uma mordida no casco, vinda de `from`. Devolve false se não havia o que morder.
func damage(amount: int, from: Vector2) -> bool:
	if rider == null or transfer_locked or hull <= 0:
		return false
	hull = maxi(0, hull - amount)
	_shake = .35
	if Sfx.has_bank("water_splash"):
		Sfx.play(self, "water_splash", global_position, -6.0, randf_range(.7, .85))
	queue_redraw()
	if hull <= 0:
		wrecked.emit()
	return true


func repair() -> void:
	hull = HULL_MAX
	_shake = 0.0
	queue_redraw()


func frame() -> int:
	if rider == null:
		return FRAME_EMPTY
	return 1 + int(stroke * ROW_FRAMES) % ROW_FRAMES if rowing else FRAME_IDLE


func _splash() -> void:
	var blades := PackedVector2Array([global_position + hull_point(-2.0, 26.0), global_position + hull_point(-2.0, -26.0)])
	stroked.emit(blades)
	if Sfx.has_bank("water_plop"):
		Sfx.play(self, "water_plop", global_position, -16.0, randf_range(.9, 1.1))


func _draw() -> void:
	var bob := roundf(sin(_clock * 2.2))
	var shake := Vector2(roundf(sin(_clock * 70.0) * 2.0 * _shake / .35), 0)
	# Sombra na água e uma linha de espuma em volta do casco.
	var hull := PackedVector2Array()
	for step in range(18):
		var angle := step * TAU / 18.0
		hull.append(hull_point(cos(angle) * 27.0, sin(angle) * 10.0) + Vector2(0, 2))
	draw_colored_polygon(hull, Color(.01, .05, .06, .32))
	hull.append(hull[0])
	draw_polyline(hull, Color(.83, .93, .88, .22 + (.12 if rowing else 0.0)), 1.0)
	if SeaArt.draw_frame(self, "boat_v4", "boat_%02d" % direction(), frame(), Vector2(0, bob) + shake):
		_draw_hull()
		return
	# Reserva sem a folha exportada: casco, bancos e Senu como manchas.
	var shape := PackedVector2Array()
	for step in range(18):
		var angle := step * TAU / 18.0
		shape.append(hull_point(cos(angle) * 25.0, sin(angle) * 8.0) + Vector2(0, bob - 4))
	draw_colored_polygon(shape, Color("674d34"))
	shape.append(shape[0])
	draw_polyline(shape, Color("a27d50"), 1.0)
	if rider != null:
		draw_circle(Vector2(0, bob - 14), 4.0, Color("dbcfaa"))
		draw_circle(Vector2(0, bob - 20), 3.0, Color("a27d50"))


## Barrinha do casco sobre o barco, só depois da primeira mordida.
func _draw_hull() -> void:
	if hull >= HULL_MAX or rider == null:
		return
	var width := 28.0
	var fill := roundf(width * float(hull) / HULL_MAX)
	var tint := Color("e0bd7e") if hull > HULL_MAX * .4 else Color("be733a")
	draw_rect(Rect2(-width * .5 - 1, -49, width + 2, 4), Color("14252c"))
	draw_rect(Rect2(-width * .5, -48, fill, 2), tint)
	if _shake > 0.0:
		draw_rect(Rect2(-width * .5, -48, width, 2), Color(1, .95, .8, _shake))
