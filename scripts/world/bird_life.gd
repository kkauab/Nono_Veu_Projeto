extends Node2D
class_name BirdLife

## Sistema de Aves e Papagaios do Porto dos Esquecidos (docs/MUNDO_VIDA.md).
## Gerencia o ciclo de vida, voos pseudo-3D isométricos, sombras projetadas,
## pousos em poleiros catalogados e revoadas reativas ao Senu.
##
## Profundidade: pousada, a ave entra na ordem por profundidade dos atores (o
## nó fica no chão, sob o poleiro, e o desenho sobe `altitude` px); em voo ela
## passa para FLY_Z, acima de telhados e fachadas. A sombra fica sempre no chão,
## abaixo dos atores.

const Catalog = preload("res://scripts/world/bird_catalog.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Threat = preload("res://scripts/world/fauna_threat.gd")

const TEXTURE_PATH := "res://assets/world/birds_v1.png"
const CELL_SIZE := Vector2(32, 32)
## Pés da ave pousada (e centro do corpo em voo) na célula 32 × 32.
const PIVOT_OFFSET := Vector2(16, 20)

## Raio de percepção do jogador, por como ele se move (fauna_threat.gd).
const DIST_IDLE_FLEE := 55.0
const DIST_WALK_FLEE := 80.0
const DIST_RUN_FLEE := 105.0
const DIST_ATTACK_FLEE := 160.0
## Cada pixel de altura conta como esta fração de distância: no telhado a ave se assusta menos.
const ALTITUDE_CALM := 0.4
## A ave não escolhe pousar a menos disto de Senu (nem de quem a assustou).
const SAFE_LANDING := 150.0
## Pousada além disto (fora da tela, com folga) a ave não processa; em voo, sempre.
const CULL_DISTANCE := 640.0
## Em voo, acima de telhados e construções.
const FLY_Z := 8
## Pousada, a ave ordena um pouco à frente da peça em que está.
const PERCH_SORT_BIAS := 2.0
## A peça de um poleiro fica a até esta distância (tiles) do tile do catálogo.
const ANCHOR_RANGE := 1.2
## Partes do voo: subida até CLIMB e descida a partir de DESCEND (fração do caminho).
const CLIMB := 0.3
const DESCEND := 0.72
## Velocidade vertical média na subida e na descida (px/s): do cabeço ao topo do
## mastro a ave leva o tempo de subir, sem saltar de altura.
const VERTICAL_SPEED := 80.0

var game: Node2D
var birds: Array[BirdActor] = []
var perches_by_id: Dictionary = {}
var perches_by_district: Dictionary = {}
var _birds_texture: Texture2D
var _player: Node2D
var _threat := Threat.STILL


class BirdActor extends Node2D:
	enum State { PERCHED, TAKEOFF, CRUISE, LANDING }

	var bird_id: String
	var species: String
	var spec_data: Dictionary
	var home_district: String
	var state := State.PERCHED

	var current_perch: Dictionary
	var target_perch: Dictionary

	# Coordenadas no mundo pseudo-3D
	var ground_pos: Vector2
	var altitude: float = 0.0
	var target_altitude: float = 0.0

	# Trajetória de voo (curva de Bézier cúbica no chão)
	var flight_start: Vector2
	var flight_target: Vector2
	var flight_control_1: Vector2
	var flight_control_2: Vector2
	var flight_progress: float = 0.0
	var flight_duration: float = 2.0
	var start_altitude: float = 0.0
	var dest_altitude: float = 0.0

	var idle_timer: float = 5.0
	var look_timer: float = 2.0
	var wing_timer: float = 0.0
	var flock_alert_timer: float = 0.0
	var anim_frame: int = 0
	var facing: float = 1.0
	## Quem fez a ave levantar voo (Vector2.INF quando saiu por conta própria).
	var flee_from := Vector2.INF
	var _replan_timer := 0.0
	var _sort_bias := 0.0
	var _shadow_key := -1

	var body_sprite: Sprite2D
	var shadow_node: Node2D
	var manager: Node2D

	func _ensure_visuals() -> void:
		if body_sprite != null:
			return
		# Um nó só na ordem por profundidade: sem y_sort aqui, o corpo erguido
		# não é ordenado pela própria altura (sumia atrás da peça do poleiro).
		y_sort_enabled = false

		# Sombra desenhada no chão, sob os atores, mesmo com a ave em voo.
		shadow_node = Node2D.new()
		shadow_node.name = "GroundShadow"
		shadow_node.z_as_relative = false
		shadow_node.z_index = -1
		shadow_node.draw.connect(_draw_shadow)
		add_child(shadow_node)

		# Sprite da ave, com os pés (ou o corpo em voo) no pivô da célula.
		body_sprite = Sprite2D.new()
		body_sprite.name = "BirdBody"
		body_sprite.texture = manager._birds_texture
		body_sprite.region_enabled = true
		body_sprite.centered = false
		body_sprite.offset = -PIVOT_OFFSET
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(body_sprite)

	func _ready() -> void:
		_ensure_visuals()
		_update_region()

	func is_perched() -> bool:
		return state == State.PERCHED

	func _draw_shadow() -> void:
		# Pousada numa peça, a sombra é a da peça; só no chão ou em voo a ave tem a sua.
		if state == State.PERCHED and altitude > 4.0:
			return
		# Quanto mais alto o voo, mais translúcida e suave a sombra
		var alpha := clampf(0.55 - altitude * 0.0035, 0.12, 0.55)
		var scale_factor := clampf(1.0 - altitude * 0.003, 0.5, 1.0)
		var shadow_col := Color(0.06, 0.1, 0.12, alpha)

		# Elipse isométrica 2:1
		var size_vec: Vector2 = spec_data["size"]
		var radius_x: float = 6.0 * scale_factor * size_vec.x
		var radius_y: float = 3.0 * scale_factor * size_vec.y
		var points := PackedVector2Array()
		for i in range(12):
			var angle := (float(i) / 12.0) * TAU
			points.append(Vector2(cos(angle) * radius_x, sin(angle) * radius_y - _sort_bias))
		shadow_node.draw_colored_polygon(points, shadow_col)

	func _update_region() -> void:
		var row: int = spec_data["row"]
		body_sprite.region_rect = Rect2(anim_frame * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		# Escala inteira: pixel art nítida (o tamanho da espécie só muda a sombra).
		body_sprite.scale = Vector2(facing, 1.0)
		body_sprite.position = Vector2(0, -roundf(altitude) - _sort_bias)
		position = ground_pos + Vector2(0, _sort_bias)
		var key := int(roundf(altitude)) * 4 + state
		if key != _shadow_key:
			_shadow_key = key
			shadow_node.queue_redraw()

	func setup_perch(perch: Dictionary) -> void:
		_ensure_visuals()
		current_perch = perch
		target_perch = {}
		ground_pos = perch.get("ground", Layout.iso(perch["tile"]))
		altitude = perch["alt"]
		target_altitude = altitude
		facing = perch.get("facing", 1.0)
		state = State.PERCHED
		flee_from = Vector2.INF
		flock_alert_timer = 0.0
		anim_frame = 0
		look_timer = randf_range(1.5, 4.0)
		z_index = 0
		_sort_bias = PERCH_SORT_BIAS
		_update_region()

	func tick(delta: float, player: Node2D, threat: int) -> void:
		# Longe do jogador, a ave pousada fica parada; em voo, termina o voo.
		if state == State.PERCHED and player != null and ground_pos.distance_to(player.position) > CULL_DISTANCE:
			return

		match state:
			State.PERCHED:
				_tick_perched(delta, player, threat)
			_:
				_tick_flight(delta, player)

		_update_region()

	func _tick_perched(delta: float, player: Node2D, threat: int) -> void:
		if flock_alert_timer > 0.0:
			flock_alert_timer -= delta
			anim_frame = 1 # perch_look
			if flock_alert_timer <= 0.0:
				takeoff(flee_from)
			return

		idle_timer -= delta
		look_timer -= delta

		# Olha para cima por um instante e volta à pose de repouso.
		if look_timer <= 0.0:
			if anim_frame == 0:
				anim_frame = 1
				look_timer = randf_range(0.5, 1.1)
			else:
				anim_frame = 0
				look_timer = randf_range(2.0, 4.5)

		# Reação à proximidade, à corrida e ao ataque de Senu
		if player != null:
			var dist := ground_pos.distance_to(player.position) + altitude * ALTITUDE_CALM
			if dist < manager.flee_radius(threat):
				takeoff(player.position)
				return

		if idle_timer <= 0.0:
			takeoff()

	## Levanta voo para outro poleiro. `threat` é de onde veio o susto.
	func takeoff(threat: Vector2 = Vector2.INF) -> void:
		if state != State.PERCHED:
			return
		flee_from = threat
		flock_alert_timer = 0.0
		var next: Dictionary = manager.pick_next_perch(self, threat)
		state = State.TAKEOFF
		anim_frame = 4 # fly_up
		z_index = FLY_Z # Voa acima de telhados e construções
		_sort_bias = 0.0
		manager.notify_flock_takeoff(self, ground_pos, threat)
		_plan_flight(next)

	## Traça o voo do ponto atual (no chão e no ar) até o poleiro `next`.
	func _plan_flight(next: Dictionary) -> void:
		target_perch = next
		flight_start = ground_pos
		start_altitude = altitude
		flight_target = next.get("ground", Layout.iso(next["tile"])) if not next.is_empty() else ground_pos
		dest_altitude = float(next.get("alt", 0.0)) if not next.is_empty() else 0.0
		target_altitude = maxf(float(spec_data["cruise_alt"]) + randf_range(-10.0, 15.0), maxf(start_altitude, dest_altitude) + 14.0)

		var span := flight_target - flight_start
		if span.length() < 24.0:
			# Volta ao mesmo poleiro: uma volta no ar, para longe do susto.
			var away := (flight_start - flee_from).normalized() if flee_from.is_finite() else Vector2.RIGHT.rotated(randf() * TAU)
			if away == Vector2.ZERO:
				away = Vector2.RIGHT
			away = Vector2(away.x, away.y * 0.5).normalized()
			var side := Vector2(-away.y, away.x) * 70.0
			flight_control_1 = flight_start + away * 150.0 + side
			flight_control_2 = flight_target + away * 150.0 - side
		else:
			# Pontos de controle curvos para trajetórias de voo orgânicas
			var mid := (flight_start + flight_target) * 0.5
			var dir := span.normalized()
			var perp := Vector2(-dir.y, dir.x) * randf_range(-60.0, 60.0)
			flight_control_1 = flight_start.lerp(mid, 0.5) + perp
			flight_control_2 = mid.lerp(flight_target, 0.5) + perp * 0.8

		var length := 0.0
		var previous := flight_start
		for i in range(1, 13):
			var point := _bezier_cubic(flight_start, flight_control_1, flight_control_2, flight_target, i / 12.0)
			length += previous.distance_to(point)
			previous = point
		# A curva começa e termina devagar (decolagem e pouso): a média fica abaixo do cruzeiro.
		flight_duration = maxf(2.2, length / float(spec_data["cruise_speed"]) * 1.25)
		var climb := (target_altitude - start_altitude) / (CLIMB * VERTICAL_SPEED)
		var descent := (target_altitude - dest_altitude) / ((1.0 - DESCEND) * VERTICAL_SPEED)
		flight_duration = maxf(flight_duration, maxf(climb, descent))
		flight_progress = 0.0
		_replan_timer = 0.5

	func _tick_flight(delta: float, player: Node2D) -> void:
		flight_progress = minf(1.0, flight_progress + delta / flight_duration)
		var t := flight_progress
		# Arranca e chega devagar: na decolagem a ave sobe quase no lugar, no pouso desce no poleiro.
		var along := t * t * (3.0 - 2.0 * t)
		var previous := ground_pos
		ground_pos = _bezier_cubic(flight_start, flight_control_1, flight_control_2, flight_target, along)

		if t < CLIMB:
			state = State.TAKEOFF
			var rise := t / CLIMB
			altitude = lerpf(start_altitude, target_altitude, 1.0 - (1.0 - rise) * (1.0 - rise))
		elif t < DESCEND:
			state = State.CRUISE
			var cruise := (t - CLIMB) / (DESCEND - CLIMB)
			# Leve oscilação de altitude no cruzeiro, nula nas pontas (sem salto de altura).
			altitude = target_altitude + sin(cruise * TAU) * 6.0 * sin(cruise * PI)
		else:
			state = State.LANDING
			var fall := (t - DESCEND) / (1.0 - DESCEND)
			altitude = lerpf(target_altitude, dest_altitude, fall * fall * (3.0 - 2.0 * fall))

		# Vira só com velocidade lateral clara: sem trocar de lado a cada quadro.
		var velocity := (ground_pos - previous) / maxf(delta, 0.0001)
		if absf(velocity.x) > 6.0 and absf(velocity.x) > velocity.length() * 0.25 and signf(velocity.x) != facing:
			facing = signf(velocity.x)

		_animate_wings(delta)

		# Senu chegou perto do poleiro escolhido: escolhe outro antes de descer.
		_replan_timer -= delta
		if state == State.CRUISE and _replan_timer <= 0.0 and player != null and not target_perch.is_empty():
			_replan_timer = 0.5
			if flight_target.distance_to(player.position) < SAFE_LANDING * 0.6:
				var other: Dictionary = manager.pick_next_perch(self, player.position)
				if not other.is_empty() and other.get("id") != target_perch.get("id"):
					flee_from = player.position
					_plan_flight(other)
					return

		if flight_progress >= 1.0:
			# Pousou!
			if not target_perch.is_empty():
				setup_perch(target_perch)
			else:
				state = State.PERCHED
				altitude = dest_altitude
				anim_frame = 0
				z_index = 0
			idle_timer = randf_range(spec_data.get("idle_min", 6.0), spec_data.get("idle_max", 14.0))

	func _animate_wings(delta: float) -> void:
		wing_timer += delta * float(spec_data["wing_rate"])
		# No cruzeiro, gaivotas, falcões e garças planam parte do tempo.
		var glide: float = spec_data.get("glide", 0.0)
		if state == State.CRUISE and glide > 0.0 and fposmod(wing_timer / 12.0, 1.0) < glide:
			anim_frame = 3 # fly_glide
			return
		var cycle := fposmod(wing_timer, 4.0)
		if cycle < 1.0:
			anim_frame = 2 # fly_down
		elif cycle < 2.0:
			anim_frame = 3 # fly_glide
		elif cycle < 3.0:
			anim_frame = 4 # fly_up
		else:
			anim_frame = 3 # fly_glide

	func _bezier_cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
		var u := 1.0 - t
		var tt := t * t
		var uu := u * u
		var uuu := uu * u
		var ttt := tt * t
		return uuu * p0 + 3.0 * uu * t * p1 + 3.0 * u * tt * p2 + ttt * p3


static func build(game_instance: Node2D) -> BirdLife:
	var instance := BirdLife.new()
	instance.name = "BirdLife"
	instance.game = game_instance
	var target_parent: Node = game_instance.actors if "actors" in game_instance else game_instance
	target_parent.add_child(instance)
	instance.setup()
	return instance


var _initialized := false

func setup() -> void:
	if _initialized:
		return
	_initialized = true
	# As aves pousadas entram na mesma ordem por profundidade que Senu e o cenário.
	z_index = 0
	y_sort_enabled = true
	_birds_texture = load(TEXTURE_PATH) as Texture2D
	_index_perches()
	_spawn_all_birds()


func _ready() -> void:
	setup()


## Prende cada poleiro à peça do cenário que ele representa.
func _index_perches() -> void:
	var props := _scenery_props()
	for source in Catalog.PERCHES:
		var perch: Dictionary = source.duplicate()
		var id: String = perch["id"]
		var district: String = perch["district"]
		var ground := Layout.iso(perch["tile"])
		perch["enabled"] = true
		var kind: String = perch.get("prop", "")
		# Sem cenário nenhum (testes isolados) vale o tile do catálogo.
		if kind != "" and not props.is_empty():
			var prop := _nearest_prop(props, kind, perch["tile"])
			if prop == null:
				perch["enabled"] = false
			else:
				var offset: Vector2 = perch.get("offset", Vector2.ZERO)
				if bool(prop.get("mirror")):
					offset.x = -offset.x
				ground = prop.position + offset
		perch["ground"] = ground
		perches_by_id[id] = perch
		if not perch["enabled"]:
			continue
		if not perches_by_district.has(district):
			perches_by_district[district] = []
		perches_by_district[district].append(perch)


func _scenery_props() -> Array:
	var result: Array = []
	var parent := get_parent()
	if parent == null:
		return result
	for node in parent.get_children():
		if node is PortProp:
			result.append(node)
	return result


func _nearest_prop(props: Array, kind: String, tile: Vector2) -> Node2D:
	var best: Node2D = null
	var best_gap := ANCHOR_RANGE
	for prop in props:
		if prop.kind != kind:
			continue
		var gap := Layout.unproject(prop.position).distance_to(tile)
		if gap < best_gap:
			best_gap = gap
			best = prop
	return best


func _spawn_all_birds() -> void:
	for definition in Catalog.BIRDS:
		var species: String = definition["species"]
		var spec_data: Dictionary = Catalog.SPECIES[species].duplicate()
		var bird := BirdActor.new()
		bird.bird_id = definition["id"]
		bird.species = species
		bird.spec_data = spec_data
		bird.home_district = definition["district"]
		bird.manager = self

		var idle_range: Vector2 = definition.get("idle_range", Vector2(6.0, 12.0))
		spec_data["idle_min"] = idle_range.x
		spec_data["idle_max"] = idle_range.y

		var start_perch: Dictionary = perches_by_id.get(definition.get("home_perch", ""), {})
		if start_perch.is_empty() or not start_perch["enabled"] or is_taken(start_perch, bird):
			start_perch = _find_fallback_perch(bird)

		add_child(bird)
		if not start_perch.is_empty():
			bird.setup_perch(start_perch)
		bird.idle_timer = randf_range(idle_range.x, idle_range.y)
		birds.append(bird)


func _process(delta: float) -> void:
	_player = game.get("player") if game != null else null
	_threat = Threat.level(_player)
	for bird in birds:
		bird.tick(delta, _player, _threat)


## Raio em que Senu espanta uma ave, por como ele se move.
func flee_radius(threat: int) -> float:
	match threat:
		Threat.ATTACK:
			return DIST_ATTACK_FLEE
		Threat.RUN:
			return DIST_RUN_FLEE
		Threat.WALK:
			return DIST_WALK_FLEE
	return DIST_IDLE_FLEE


func notify_flock_takeoff(initiator: BirdActor, pos: Vector2, threat: Vector2 = Vector2.INF) -> void:
	for other in birds:
		if other != initiator and other.state == BirdActor.State.PERCHED and other.species == initiator.species:
			var d := other.ground_pos.distance_to(pos)
			if d < 140.0 and other.flock_alert_timer <= 0.0:
				other.flock_alert_timer = randf_range(0.12, 0.38)
				other.flee_from = threat


## Poleiro ocupado por outra ave, pousada nele ou a caminho dele.
func is_taken(perch: Dictionary, asking: BirdActor = null) -> bool:
	var id: String = perch.get("id", "")
	for other in birds:
		if other == asking:
			continue
		var holding: Dictionary = other.current_perch if other.state == BirdActor.State.PERCHED else other.target_perch
		if holding.get("id", "") == id:
			return true
	return false


## Próximo poleiro: livre, longe de Senu e do susto, de preferência no distrito de casa.
func pick_next_perch(bird: BirdActor, threat: Vector2 = Vector2.INF) -> Dictionary:
	var allowed_districts: Array = bird.spec_data["districts"]
	var candidates: Array = []
	var weights: Array = []
	var total := 0.0

	for dist in allowed_districts:
		for p in perches_by_district.get(dist, []):
			var species_list: Array = p.get("species", [])
			if bird.species not in species_list or p["id"] == bird.current_perch.get("id", ""):
				continue
			if is_taken(p, bird):
				continue
			var ground: Vector2 = p["ground"]
			if _player != null and ground.distance_to(_player.position) < SAFE_LANDING:
				continue
			if threat.is_finite() and ground.distance_to(threat) < SAFE_LANDING:
				continue
			# Volta para casa com mais frequência; voos muito longos são raros.
			var weight := 4.0 if p["district"] == bird.home_district else 1.0
			if ground.distance_to(bird.ground_pos) > 900.0:
				weight *= 0.35
			candidates.append(p)
			weights.append(weight)
			total += weight

	if candidates.is_empty():
		# Nenhum livre: dá uma volta no ar e retorna ao mesmo poleiro.
		return bird.current_perch

	var roll := randf() * total
	for index in range(candidates.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates[candidates.size() - 1]


func _find_fallback_perch(bird: BirdActor) -> Dictionary:
	var districts: Array = [bird.home_district]
	districts.append_array(bird.spec_data["districts"])
	for district in districts:
		for p in perches_by_district.get(district, []):
			if bird.species in p.get("species", []) and not is_taken(p, bird):
				return p
	return {}
