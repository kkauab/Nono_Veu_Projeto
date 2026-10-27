extends Node2D
## A água do porto viva: cardumes sob a superfície, peixes que saltam,
## ondulações, bolhas, brilhos, lótus e troncos à deriva, e o som do mar.
## Tudo acontece perto da câmera e só sobre água aberta, longe das faces de
## pedra e das estacas. Os peixes fogem de Senu, e com mais pressa quando ele
## corre ou luta. O ritmo oscila em ondas lentas para a água nunca bater como
## um relógio. Fora do mar desenhado (interiores das casas) não há água.

const Sfx = preload("res://scripts/audio/sfx.gd")
const Banks = preload("res://scripts/audio/sfx_banks.gd")

## Faces dos pisos, estacas e espuma descem até ~36 px abaixo da borda.
const CLIFF_CLEARANCE := 38.0
const JUMP_CLEARANCE := 62.0
const VIEW_MARGIN := 40.0
const DESPAWN_MARGIN := 140.0
const MAX_FISH := 18
const FLEE_RADIUS := 44.0
const FLEE_RADIUS_LOUD := 76.0
const WATER_ISO := .5
const AMBIENT_BASE_DB := -14.0

const SHADOW_COLOR := Color(.012, .055, .07, .72)
const RIPPLE_COLOR := Color("7fa59c")
const GLINT_COLOR := Color("c3e2d9")
const DROP_COLOR := Color("d6ebe4")
const FISH_BACK := Color("456f6e")
const FISH_SIDE := Color("93b9b1")
const FISH_BELLY := Color("e1ece5")
const FISH_EYE := Color("142629")
## Espessura do corpo, da cabeça à cauda; esticada ao comprimento do peixe.
const FISH_PROFILE := [2, 3, 3, 3, 3, 2, 2, 1, 1]

var layout: Node2D
var rng := RandomNumberGenerator.new()

var _tiles: Dictionary = {}
var _themes: Dictionary = {}
var _fish: Array[Fish] = []
var _jumps: Array[Jump] = []
var _ripples: Array[Dictionary] = []
var _drops: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _bubbles: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _clock := 0.0
var _next_jump := 2.0
var _next_glint := 0.0
var _next_rise := 3.0
var _next_bubbles := 6.0
var _next_spawn := 0.0
var _next_school := 0
var _coverage := 1.0
var _ambient: AudioStreamPlayer


class Fish:
	var position: Vector2
	var heading: float
	var speed: float
	var cruise: float
	var length: int
	var alpha := 0.0
	var delay := 0.0
	var life: float
	var age := 0.0
	var school: int
	var leader: Fish
	var slot: Vector2
	var startled := 0.0
	var think := 0.0
	var hidden := false


class Jump:
	var fish: Fish
	var origin: Vector2
	var travel: Vector2
	var height: float
	var duration: float
	var time := 0.0
	var length: int
	var trail := 0.0

	func point(progress: float) -> Vector2:
		return origin + travel * progress - Vector2(0, height * 4.0 * progress * (1.0 - progress))

	func slope(progress: float) -> Vector2:
		return (travel - Vector2(0, height * 4.0 * (1.0 - 2.0 * progress))).normalized()


func _ready() -> void:
	z_index = -1
	if rng.seed == 0:
		rng.randomize()
	if layout != null:
		_tiles = layout.get("tiles")
		_themes = layout.get("tile_themes")
	else:
		var catalog := PortLayout.tile_catalog()
		for tile in catalog:
			_tiles[tile] = catalog[tile]["color"]
			_themes[tile] = catalog[tile]["theme"]
	# O layout ainda está montando os pisos quando este nó entra na árvore.
	_place_floaters.call_deferred()
	_ambient = AudioStreamPlayer.new()
	_ambient.name = "SeaAmbience"
	_ambient.stream = _looping(Banks.BANKS["water_loop"][0])
	_ambient.bus = "Ambiente"
	_ambient.volume_db = AMBIENT_BASE_DB
	Sfx.ensure_buses()
	add_child(_ambient)
	_ambient.play()


func _process(delta: float) -> void:
	_clock += delta
	var view := view_rect()
	_coverage = lerpf(_coverage, _water_coverage(view), minf(1.0, delta * 1.5))
	if _ambient != null:
		# Sem água à vista (interiores), o mar silencia de vez.
		var amount := lerpf(.1, 1.0, _coverage) * clampf(_coverage * 10.0, 0.0, 1.0)
		_ambient.volume_db = AMBIENT_BASE_DB + linear_to_db(maxf(amount, .0001))
	_populate(view, delta)
	_update_fish(view, delta)
	_update_jumps(delta)
	_update_surface(view, delta)
	queue_redraw()


## Ponto de mar onde a superfície aparece sem nenhum piso, face de pedra ou estaca por cima.
func is_open_water(point: Vector2, clearance: float = CLIFF_CLEARANCE, half_width: float = 7.0) -> bool:
	var step := 0.0
	while step <= clearance:
		for dx: float in [-half_width, 0.0, half_width]:
			if _is_dry(point + Vector2(dx, -step)):
				return false
		step += 6.0
	return true


func view_rect() -> Rect2:
	if not is_inside_tree():
		return Rect2(-320, -180, 640, 360)
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	var top_left := inverse * Vector2.ZERO
	return Rect2(top_left, inverse * size - top_left)


func fish_count() -> int:
	return _fish.size()


func jump_count() -> int:
	return _jumps.size()


## Peixes nadando à vista (sem os que estão no ar ou ainda no fundo).
func fish_positions() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for fish in _fish:
		if not fish.hidden and fish.delay <= 0.0:
			points.append(fish.position)
	return points


## Faz um peixe visível saltar agora. Devolve false se nenhum tiver espaço.
func leap(away_from: Vector2 = Vector2.INF) -> bool:
	var view := view_rect()
	var candidates: Array[Fish] = []
	for fish in _fish:
		if not fish.hidden and fish.alpha > .5 and view.has_point(fish.position):
			candidates.append(fish)
	while not candidates.is_empty():
		var fish: Fish = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		if _start_jump(fish, away_from):
			return true
	return false


# --- população e cardumes ------------------------------------------------------

func _populate(view: Rect2, delta: float) -> void:
	var outer := view.grow(DESPAWN_MARGIN)
	for index in range(_fish.size() - 1, -1, -1):
		var fish := _fish[index]
		if fish.delay > 0.0:
			fish.delay -= delta
			continue
		fish.age += delta
		var fading := fish.age > fish.life
		fish.alpha = clampf(fish.alpha + delta * (-.7 if fading else .6), 0.0, 1.0)
		if not fish.hidden and (not outer.has_point(fish.position) or (fading and fish.alpha <= 0.0)):
			_fish.remove_at(index)
	_next_spawn -= delta
	var wanted := roundi(MAX_FISH * clampf(_coverage * 1.2, 0.0, 1.0))
	if _next_spawn > 0.0 or _fish.size() >= wanted:
		return
	_next_spawn = rng.randf_range(.4, 1.4)
	var spawn_area := view.grow(VIEW_MARGIN)
	for attempt in range(8):
		var point := Vector2(rng.randf_range(spawn_area.position.x, spawn_area.end.x), rng.randf_range(spawn_area.position.y, spawn_area.end.y))
		if not is_open_water(point) or _near_player(point, 60.0):
			continue
		_spawn_school(point, mini(wanted - _fish.size(), [1, 1, 2, 3, 3, 4, 5][rng.randi_range(0, 6)]))
		return


func _spawn_school(point: Vector2, size: int) -> void:
	_next_school += 1
	var heading := rng.randf_range(0.0, TAU)
	var leader: Fish
	for index in range(size):
		var fish := Fish.new()
		fish.school = _next_school
		fish.heading = heading
		fish.cruise = rng.randf_range(9.0, 17.0)
		fish.speed = fish.cruise
		fish.length = rng.randi_range(6, 10)
		fish.life = rng.randf_range(9.0, 24.0)
		# Cada peixe aparece com um pequeno atraso, como se subisse do fundo.
		fish.delay = rng.randf_range(0.0, .9)
		if leader == null:
			leader = fish
			fish.position = point
		else:
			fish.leader = leader
			fish.slot = Vector2(-rng.randf_range(6.0, 14.0), rng.randf_range(-9.0, 9.0))
			fish.position = point + _to_screen(fish.slot.rotated(heading))
		_fish.append(fish)


func _update_fish(view: Rect2, delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	var loud := false
	if player != null:
		loud = bool(player.get("is_sprinting")) or float(player.get("attack_timer")) > 0.0 or float(player.get("_dodge_timer")) > 0.0
	for fish in _fish:
		if fish.hidden:
			continue
		fish.startled = maxf(0.0, fish.startled - delta)
		fish.think -= delta
		if player != null and fish.startled <= 0.0:
			var away := _to_metric(fish.position - player.global_position)
			if away.length() < (FLEE_RADIUS_LOUD if loud else FLEE_RADIUS):
				_startle(fish, away, view)
				continue
		if fish.think <= 0.0:
			fish.think = rng.randf_range(.12, .24)
			_steer(fish)
		var target_speed := fish.cruise * (3.2 if fish.startled > 0.0 else 1.0)
		fish.speed = lerpf(fish.speed, target_speed, minf(1.0, delta * 3.0))
		var next := fish.position + _to_screen(Vector2.from_angle(fish.heading)) * fish.speed * delta
		if is_open_water(next, CLIFF_CLEARANCE - 6.0, 4.0):
			fish.position = next
		else:
			fish.heading += PI * .5 * (1.0 if rng.randf() < .5 else -1.0)


func _steer(fish: Fish) -> void:
	if fish.leader != null and fish.leader in _fish and not fish.leader.hidden:
		# Seguidores mantêm o lugar no cardume, atrás e ao lado do guia.
		var goal := fish.leader.position + _to_screen(fish.slot.rotated(fish.leader.heading))
		var offset := _to_metric(goal - fish.position)
		fish.heading = lerp_angle(fish.heading, offset.angle(), .45)
		fish.cruise = clampf(fish.leader.speed * (1.0 + offset.length() / 30.0), 6.0, 40.0)
		return
	fish.leader = null
	fish.heading += rng.randf_range(-.35, .35)
	# Olha adiante; perto da pedra, procura a direção livre mais próxima.
	var ahead := fish.position + _to_screen(Vector2.from_angle(fish.heading)) * 22.0
	if is_open_water(ahead):
		return
	for turn: float in [.6, -.6, 1.2, -1.2, 2.0, -2.0, PI]:
		var probe := fish.position + _to_screen(Vector2.from_angle(fish.heading + turn)) * 22.0
		if is_open_water(probe):
			fish.heading += turn
			return


func _startle(fish: Fish, away: Vector2, view: Rect2) -> void:
	fish.heading = away.angle() + rng.randf_range(-.45, .45)
	fish.startled = rng.randf_range(.9, 1.5)
	# Arrancada: o peixe dispara e depois desacelera até o nado de fuga.
	fish.speed = fish.cruise * 4.5
	_ripple(fish.position, 1.0, 6.0, .5, .7)
	# Às vezes o susto vira salto, sempre para longe de Senu.
	if rng.randf() < .22 and view.has_point(fish.position):
		var player := get_tree().get_first_node_in_group("player") as Node2D
		_start_jump(fish, player.global_position if player != null else Vector2.INF)


func _near_player(point: Vector2, radius: float) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D if is_inside_tree() else null
	return player != null and _to_metric(point - player.global_position).length() < radius


# --- saltos --------------------------------------------------------------------

func _start_jump(fish: Fish, away_from: Vector2 = Vector2.INF) -> bool:
	var heading := fish.heading
	if away_from != Vector2.INF:
		heading = _to_metric(fish.position - away_from).angle()
	var distance := rng.randf_range(14.0, 30.0)
	var travel := _to_screen(Vector2.from_angle(heading)) * distance
	if not is_open_water(fish.position, JUMP_CLEARANCE, 9.0) or not is_open_water(fish.position + travel, JUMP_CLEARANCE, 9.0):
		return false
	var jump := Jump.new()
	jump.fish = fish
	jump.origin = fish.position
	jump.travel = travel
	jump.height = rng.randf_range(12.0, 24.0)
	jump.duration = rng.randf_range(.55, .82)
	jump.length = clampi(fish.length + 1, 8, 11)
	fish.hidden = true
	_jumps.append(jump)
	_splash(jump.origin, 3, .7)
	Sfx.play(self, "water_splash", jump.origin, -2.0, rng.randf_range(.9, 1.15))
	return true


func _update_jumps(delta: float) -> void:
	for index in range(_jumps.size() - 1, -1, -1):
		var jump := _jumps[index]
		jump.time += delta
		var progress := jump.time / jump.duration
		jump.trail -= delta
		if jump.trail <= 0.0 and progress < .85:
			jump.trail = .07
			var tail := jump.point(progress) - jump.slope(progress) * float(jump.length)
			_drop(tail, Vector2(rng.randf_range(-8.0, 8.0), 0), 0.0, rng.randf_range(-6.0, 4.0))
		if progress < 1.0:
			continue
		var landing := jump.origin + jump.travel
		_splash(landing, rng.randi_range(5, 7), 1.0)
		Sfx.play(self, "water_plop", landing, 0.0, rng.randf_range(.85, 1.15) * (1.1 if jump.length < 6 else .92))
		var fish := jump.fish
		fish.position = landing
		fish.hidden = false
		fish.alpha = .25
		fish.heading = _to_metric(jump.travel).angle()
		_jumps.remove_at(index)


func _splash(at: Vector2, drops: int, strength: float) -> void:
	_ripple(at, 1.0, 9.0 * strength + 3.0, .7, 1.0)
	_ripple(at, 1.0, 5.0 * strength + 2.0, .45, .8, .12)
	for i in range(drops):
		var angle := rng.randf_range(0.0, TAU)
		var speed := rng.randf_range(8.0, 26.0) * strength
		_drop(at, _to_screen(Vector2.from_angle(angle)) * speed, 0.0, rng.randf_range(28.0, 52.0) * strength)


# --- superfície ----------------------------------------------------------------

func _update_surface(view: Rect2, delta: float) -> void:
	var activity := _activity()
	_next_jump -= delta * activity
	if _next_jump <= 0.0:
		_next_jump = rng.randf_range(1.6, 4.4)
		if leap():
			# Um cardume comendo: outros peixes do grupo saltam logo depois.
			if rng.randf() < .25:
				_next_jump = rng.randf_range(.25, .6)
	_next_glint -= delta
	while _next_glint <= 0.0:
		_next_glint += rng.randf_range(.025, .09) / maxf(.2, _coverage * activity)
		var point := _random_point(view)
		if is_open_water(point, 30.0, 2.0):
			_glints.append({"p": point.round(), "life": rng.randf_range(.3, .7), "max": 0.0, "width": rng.randi_range(2, 5), "big": rng.randf() < .25})
			_glints[-1]["max"] = _glints[-1]["life"]
	_next_rise -= delta * activity
	if _next_rise <= 0.0:
		_next_rise = rng.randf_range(1.2, 3.5)
		# Um peixe beija a superfície por baixo: só o anel.
		for fish in _fish:
			if not fish.hidden and fish.alpha > .6 and view.has_point(fish.position) and rng.randf() < .35:
				_ripple(fish.position, 1.0, rng.randf_range(5.0, 8.0), .9, .8)
				break
	_next_bubbles -= delta
	if _next_bubbles <= 0.0:
		_next_bubbles = rng.randf_range(3.0, 8.0)
		var point := _random_point(view)
		if is_open_water(point, 30.0, 4.0):
			for i in range(rng.randi_range(2, 4)):
				_bubbles.append({"p": (point + Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-2.0, 2.0))).round(), "delay": i * rng.randf_range(.15, .35), "life": .5})
			if _near_player(point, 120.0):
				Sfx.play(self, "water_bubble", point)
	_age(_ripples, delta)
	_age(_glints, delta)
	for index in range(_bubbles.size() - 1, -1, -1):
		var bubble := _bubbles[index]
		bubble["delay"] = float(bubble["delay"]) - delta
		if float(bubble["delay"]) < 0.0:
			bubble["life"] = float(bubble["life"]) - delta
			if float(bubble["life"]) <= 0.0:
				_ripple(bubble["p"], 1.0, 3.0, .3, .6)
				_bubbles.remove_at(index)
	for index in range(_drops.size() - 1, -1, -1):
		var drop := _drops[index]
		drop["vz"] = float(drop["vz"]) - 170.0 * delta
		drop["z"] = float(drop["z"]) + float(drop["vz"]) * delta
		drop["p"] = (drop["p"] as Vector2) + (drop["v"] as Vector2) * delta
		if float(drop["z"]) <= 0.0 and float(drop["vz"]) < 0.0:
			if rng.randf() < .5:
				_ripple(drop["p"], 0.0, 2.0, .25, .5)
			_drops.remove_at(index)


func _activity() -> float:
	# Dois ciclos lentos e desencontrados: momentos de água agitada e de calma.
	return .7 + .45 * sin(_clock * TAU / 47.0) * sin(_clock * TAU / 19.0 + 1.3)


func _water_coverage(view: Rect2) -> float:
	var open := 0
	for y in range(4):
		for x in range(6):
			var point := view.position + view.size * Vector2((x + .5) / 6.0, (y + .5) / 4.0)
			if is_open_water(point, 0.0, 0.0):
				open += 1
	return float(open) / 24.0


func _place_floaters() -> void:
	# Fixos no mapa: o mesmo lótus continua no mesmo canto a cada visita.
	for tile: Vector2i in _tiles:
		for edge: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			if _tiles.has(tile + edge):
				continue
			var theme := str(_themes.get(tile, "stone"))
			var chance := posmod(tile.x * 92821 + tile.y * 68917 + edge.x * 7919, 100)
			var kind := ""
			if theme in ["garden", "aqueduct", "mosaic"] and chance < 14:
				kind = "lotus"
			elif theme == "wood" and chance < 10:
				kind = "driftwood"
			elif chance < 3:
				kind = "driftwood"
			if kind.is_empty():
				continue
			var center := PortLayout.iso(Vector2(tile))
			var edge_middle := center + (Vector2(16, 8) if edge.x == 1 else Vector2(-16, 8))
			var point := edge_middle + Vector2(float(posmod(chance * 37, 17) - 8), 46.0 + float(posmod(chance * 13, 20)))
			if not is_open_water(point, CLIFF_CLEARANCE, 6.0):
				continue
			_floaters.append({"anchor": point, "kind": kind, "phase": float(chance) * .37, "flower": chance % 3 == 0, "size": 4 + chance % 3})


# --- desenho -------------------------------------------------------------------

func _draw() -> void:
	var view := view_rect().grow(16.0)
	for fish in _fish:
		if fish.hidden or fish.alpha <= 0.0 or not view.has_point(fish.position):
			continue
		_draw_shadow_fish(fish)
	for floater in _floaters:
		var anchor: Vector2 = floater["anchor"]
		if view.has_point(anchor):
			_draw_floater(floater)
	for ripple in _ripples:
		var progress := 1.0 - float(ripple["life"]) / float(ripple["max"])
		if progress < 0.0:
			continue
		var radius := lerpf(float(ripple["r0"]), float(ripple["r1"]), 1.0 - pow(1.0 - progress, 2.0))
		var color := RIPPLE_COLOR
		color.a = float(ripple["alpha"]) * (1.0 - progress)
		_draw_pixel_ellipse(ripple["p"], radius, color)
	for glint in _glints:
		# Traços horizontais, como as linhas de onda da própria textura.
		var progress := 1.0 - float(glint["life"]) / float(glint["max"])
		var swell := sin(progress * PI)
		var width := 1 + roundi(swell * float(int(glint["width"]) - 1))
		var center: Vector2 = glint["p"]
		var color := GLINT_COLOR
		color.a = swell
		draw_rect(Rect2(center - Vector2(floorf(width * .5), 0), Vector2(width, 1)), color)
		if bool(glint["big"]) and swell > .7:
			draw_rect(Rect2(center, Vector2.ONE), Color(1, 1, 1, swell))
			draw_rect(Rect2(center + Vector2(0, -1), Vector2(1, 1)), Color(1, 1, 1, swell * .5))
	for bubble in _bubbles:
		if float(bubble["delay"]) < 0.0:
			var color := DROP_COLOR
			color.a = .75
			draw_rect(Rect2(bubble["p"], Vector2.ONE * (2.0 if float(bubble["life"]) < .3 else 1.0)), color)
	for jump in _jumps:
		_draw_jump(jump)
	for drop in _drops:
		var at: Vector2 = (drop["p"] as Vector2) - Vector2(0, float(drop["z"]))
		draw_rect(Rect2(at.round(), Vector2.ONE), DROP_COLOR)


func _draw_shadow_fish(fish: Fish) -> void:
	var direction := _to_screen(Vector2.from_angle(fish.heading)).normalized()
	var color := SHADOW_COLOR
	color.a *= clampf(fish.alpha, 0.0, 1.0)
	var wiggle := sin(fish.age * (16.0 if fish.startled > 0.0 else 7.0) + float(fish.school)) * 1.4
	_draw_fish(fish.position, direction, fish.length, wiggle, color, color, color)


func _draw_jump(jump: Jump) -> void:
	var progress := clampf(jump.time / jump.duration, 0.0, 1.0)
	var head := jump.point(progress)
	# Sombra na água sob o peixe, mais fraca quanto mais alto ele está.
	var surface := jump.origin + jump.travel * progress
	var lift := clampf((surface.y - head.y) / maxf(1.0, jump.height), 0.0, 1.0)
	var shadow := SHADOW_COLOR
	shadow.a *= 1.0 - lift * .6
	draw_rect(Rect2((surface - Vector2(2, 0)).round(), Vector2(5, 1)), shadow)
	var wiggle := sin(jump.time * 30.0) * 1.0
	_draw_fish(head, jump.slope(progress), jump.length, wiggle, FISH_BACK, FISH_SIDE, FISH_BELLY)
	var direction := jump.slope(progress)
	var up := _upper_side(direction)
	draw_rect(Rect2((head - direction * 1.5 + up * .5).round(), Vector2.ONE), FISH_EYE)


## Um peixe em pixels: perfil de corpo, dorso escuro, ventre claro e cauda aberta.
## Cada pixel é desenhado uma vez, para a sombra translúcida não manchar.
func _draw_fish(head: Vector2, direction: Vector2, length: int, wiggle: float, back: Color, side_color: Color, belly: Color) -> void:
	var up := _upper_side(direction)
	var pixels := {}
	# Meio pixel por passo: na diagonal o corpo não afina nem fura.
	for step in range(length * 2 - 1):
		var along := float(step) / float(maxi(1, length * 2 - 2))
		var thickness: int = FISH_PROFILE[roundi(along * float(FISH_PROFILE.size() - 1))]
		var center := head - direction * float(step) * .5 + up * wiggle * along * along
		var half := float(thickness - 1) * .5
		var offset := -half
		while offset <= half + .01:
			var pixel := (center + up * offset).round()
			if not pixels.has(pixel):
				pixels[pixel] = back if offset > .4 else (belly if offset < -.4 else side_color)
			offset += .5
	var tail := head - direction * float(length) + up * wiggle
	for fin in [tail + up * 1.2, tail - up * 1.2, tail - direction + up * 2.0, tail - direction - up * 2.0]:
		var pixel: Vector2 = (fin as Vector2).round()
		if not pixels.has(pixel):
			pixels[pixel] = back
	for pixel: Vector2 in pixels:
		draw_rect(Rect2(pixel, Vector2.ONE), pixels[pixel])


## Lado do corpo voltado para cima na tela: o dorso.
func _upper_side(direction: Vector2) -> Vector2:
	var side := Vector2(-direction.y, direction.x)
	return -side if side.y > 0.0 else side


func _draw_floater(floater: Dictionary) -> void:
	var phase := float(floater["phase"])
	var anchor: Vector2 = floater["anchor"]
	var at := (anchor + Vector2(sin(_clock * .31 + phase) * 3.0, cos(_clock * .23 + phase) * 1.5)).round()
	var size := int(floater["size"])
	if floater["kind"] == "lotus":
		var pad := Color("2f5a43")
		for x in range(-size, size + 1):
			var half := maxi(0, roundi((1.0 - pow(float(x) / float(size), 2.0)) * size * .5))
			draw_rect(Rect2(at + Vector2(x, -half), Vector2(1, half * 2 + 1)), pad)
		draw_rect(Rect2(at + Vector2(size - 1, 0), Vector2(1, 1)), Color("16343d"))
		draw_rect(Rect2(at + Vector2(-size + 1, -1), Vector2(size, 1)), Color("4b7d55"))
		if floater["flower"]:
			draw_rect(Rect2(at + Vector2(-1, -2), Vector2(3, 2)), Color("e9c7d3"))
			draw_rect(Rect2(at + Vector2(0, -3), Vector2(1, 1)), Color("f6ece0"))
			draw_rect(Rect2(at + Vector2(0, -2), Vector2(1, 1)), Color("e8c45c"))
	else:
		var bob := roundf(sin(_clock * 1.7 + phase) * .6)
		draw_rect(Rect2(at + Vector2(-size, bob), Vector2(size * 2, 1)), Color("5a4733"))
		draw_rect(Rect2(at + Vector2(-size + 1, bob - 1), Vector2(size * 2 - 2, 1)), Color("7b6346"))
		draw_rect(Rect2(at + Vector2(-size - 1, bob + 1), Vector2(size * 2 + 2, 1)), Color(.03, .1, .12, .35))


func _draw_pixel_ellipse(center: Vector2, radius: float, color: Color) -> void:
	if radius < 1.0:
		draw_rect(Rect2(center.round(), Vector2.ONE), color)
		return
	# Pontos suficientes para o anel não sair pontilhado.
	var points := maxi(10, ceili(TAU * radius * 1.2))
	var drawn := {}
	for i in range(points):
		var angle := TAU * float(i) / float(points)
		var pixel := (center + Vector2(cos(angle) * radius, sin(angle) * radius * WATER_ISO)).round()
		if drawn.has(pixel):
			continue
		drawn[pixel] = true
		draw_rect(Rect2(pixel, Vector2.ONE), color)


# --- utilidades ----------------------------------------------------------------

func _ripple(at: Vector2, from_radius: float, to_radius: float, life: float, alpha: float, delay: float = 0.0) -> void:
	_ripples.append({"p": at, "r0": from_radius, "r1": to_radius, "life": life + delay, "max": life, "alpha": alpha})


func _drop(at: Vector2, velocity: Vector2, height: float, rise: float) -> void:
	_drops.append({"p": at, "v": velocity, "z": height, "vz": rise})


func _age(items: Array[Dictionary], delta: float) -> void:
	for index in range(items.size() - 1, -1, -1):
		items[index]["life"] = float(items[index]["life"]) - delta
		if float(items[index]["life"]) <= 0.0:
			items.remove_at(index)


func _random_point(view: Rect2) -> Vector2:
	return Vector2(rng.randf_range(view.position.x, view.end.x), rng.randf_range(view.position.y, view.end.y))


func _is_dry(point: Vector2) -> bool:
	return not PortLayout.SEA_RECT.has_point(point) or _tiles.has(Vector2i(PortLayout.unproject(point).round()))


## Direção no plano da água (circular) para a tela (achatada).
func _to_screen(vector: Vector2) -> Vector2:
	return Vector2(vector.x, vector.y * WATER_ISO)


func _to_metric(vector: Vector2) -> Vector2:
	return Vector2(vector.x, vector.y / WATER_ISO)


func _looping(stream: AudioStream) -> AudioStream:
	var wav := stream as AudioStreamWAV
	if wav == null or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return stream
	# O WAV traz o laço no bloco smpl; isto cobre uma importação sem ele.
	wav = wav.duplicate()
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = int(wav.get_length() * wav.mix_rate)
	return wav
