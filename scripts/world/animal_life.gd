extends Node2D
class_name AnimalLife

## Vida Terrestre: Cães e Gatos do Porto dos Esquecidos (docs/MUNDO_VIDA.md).
## Gerencia o ciclo de vida, caminhada pelo piso, respiração no repouso,
## sombras de solo e reações orgânicas à presença do jogador.
##
## Cada animal é um nó na ordem por profundidade dos atores, com os pés na
## posição do nó. Anda só em chão livre (tile do piso e sem colisão de
## cenário), contorna quinas deslizando e, travado, desiste do destino.

const Catalog = preload("res://scripts/world/animal_catalog.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Threat = preload("res://scripts/world/fauna_threat.gd")

const TEXTURE_PATH := "res://assets/world/animals_v1.png"
const CELL_SIZE := Vector2(32, 32)
## Pés na célula 32 × 32 (manifesto): a última linha das patas é a 26, em todas as poses.
const PIVOT_OFFSET := Vector2(16, 26)
## Raio do corpo no chão (px).
const BODY_RADIUS := 4.5
## Pixels andados por quadro da caminhada: a pata acompanha o chão.
const STRIDE := 5.0

## Além disto (fora da tela, com folga) o animal não processa. Eram 850 px:
## com Senu no Cais, 6 dos 8 animais rodavam a lógica sem aparecer.
const CULL_DIST := 560.0

var game: Node2D
var animals: Array[AnimalActor] = []
var _animals_texture: Texture2D
var _player: Node2D
var _threat := Threat.STILL


class AnimalActor extends Node2D:
	enum State { SIT, SLEEP, WALK, REACT, FLEE }

	var animal_id: String
	var breed_id: String
	var breed_data: Dictionary
	var home_pos: Vector2
	var target_pos: Vector2
	var wander_radius_px: float = 80.0

	var state := State.SIT
	var facing: float = 1.0
	var anim_frame: int = 0
	var anim_timer: float = 0.0
	var state_timer: float = 4.0
	var walk_step: int = 0
	## Distância andada desde o último passo da animação.
	var stride_left: float = 0.0
	## Quanto tempo o animal está sem conseguir avançar.
	var stuck_time: float = 0.0
	var threat_pos := Vector2.INF
	var _settled := false
	var _goal := Vector2.INF
	var _best_gap := INF
	var _no_progress := 0.0

	var body_sprite: Sprite2D
	var shadow_node: Node2D
	var manager: Node2D

	func _ensure_visuals() -> void:
		if body_sprite != null:
			return
		# Um nó só na ordem por profundidade, ordenado pelos pés: com y_sort aqui
		# o corpo era ordenado 6 px acima deles e Senu atrás passava na frente.
		y_sort_enabled = false

		# Sombra elíptica 2:1 no chão
		shadow_node = Node2D.new()
		shadow_node.name = "GroundShadow"
		shadow_node.z_index = -1
		shadow_node.draw.connect(_draw_shadow)
		add_child(shadow_node)

		# Sprite do animal, pés no pivô da célula.
		body_sprite = Sprite2D.new()
		body_sprite.name = "AnimalBody"
		body_sprite.texture = manager._animals_texture
		body_sprite.region_enabled = true
		body_sprite.centered = false
		body_sprite.offset = -PIVOT_OFFSET
		body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(body_sprite)

	func _is_free(point: Vector2) -> bool:
		return manager != null and manager.is_floor_free(point)

	func _draw_shadow() -> void:
		var size_vec: Vector2 = breed_data.get("scale", Vector2.ONE)
		var is_cat: bool = breed_data.get("type", "cat") == "cat"
		var rx := (7.0 if is_cat else 10.0) * size_vec.x
		var ry := (3.5 if is_cat else 5.0) * size_vec.y

		var points := PackedVector2Array()
		for i in range(12):
			var a := (float(i) / 12.0) * TAU
			points.append(Vector2(cos(a) * rx, sin(a) * ry - 1.0))
		shadow_node.draw_colored_polygon(points, Color(0.06, 0.1, 0.12, 0.45))

	func _update_sprite() -> void:
		var row: int = breed_data["row"]
		body_sprite.region_rect = Rect2(anim_frame * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		# Escala inteira: pixel art nítida (a escala da raça só muda a sombra).
		body_sprite.scale = Vector2(facing, 1.0)

	func setup_animal(def: Dictionary) -> void:
		_ensure_visuals()
		animal_id = def["id"]
		breed_id = def["breed"]
		breed_data = Catalog.BREEDS[breed_id]
		home_pos = Layout.iso(def["home_tile"])
		position = home_pos
		target_pos = home_pos
		facing = def.get("facing", 1.0)
		wander_radius_px = float(def.get("wander_radius", 2.5)) * 32.0

		var def_state: String = def.get("default_state", "sit")
		match def_state:
			"sleep":
				state = State.SLEEP
				anim_frame = 1
			"walk":
				state = State.WALK
				anim_frame = 2
				_pick_new_wander_target()
			_:
				state = State.SIT
				anim_frame = 0

		state_timer = randf_range(3.0, 7.0)
		_update_sprite()
		shadow_node.queue_redraw()

	## A casa do catálogo pode cair dentro de uma peça do cenário (o cenário muda):
	## o animal começa no chão livre mais perto dela.
	func _settle() -> void:
		_settled = true
		if _is_free(home_pos):
			return
		for ring in range(1, 7):
			for i in range(ring * 8):
				var angle := TAU * i / (ring * 8)
				var candidate := home_pos + Vector2(cos(angle), sin(angle) * 0.5) * ring * 8.0
				if _is_free(candidate):
					home_pos = candidate
					position = candidate
					target_pos = candidate
					return

	func tick(delta: float, player: Node2D, threat: int = Threat.STILL) -> void:
		if player != null and position.distance_to(player.position) > CULL_DIST:
			return
		if not _settled:
			_settle()

		anim_timer += delta

		# Reatividade com Senu: o raio depende de como ele se move.
		if player != null and state != State.FLEE and state != State.REACT:
			var dist := position.distance_to(player.position)
			var flee_limit: float = breed_data["flee_dist"]
			var radius := 0.0
			match threat:
				Threat.ATTACK:
					radius = flee_limit * 2.5
				Threat.RUN:
					radius = flee_limit * 1.5
				Threat.WALK:
					radius = flee_limit
			if dist < radius:
				_trigger_reaction(player.position)
			elif state == State.SLEEP and dist < 24.0:
				# Senu parado ao lado acorda o animal, que só senta.
				state = State.SIT
				anim_frame = 0
				state_timer = randf_range(3.0, 6.0)

		match state:
			State.SIT:
				_tick_sit(delta)
			State.SLEEP:
				_tick_sleep(delta)
			State.WALK:
				_tick_walk(delta)
			State.REACT:
				_tick_react(delta)
			State.FLEE:
				_tick_flee(delta)

		_update_sprite()

	func _tick_sit(delta: float) -> void:
		anim_frame = 0
		state_timer -= delta
		if state_timer <= 0.0:
			if randf() < 0.4 or position.distance_to(home_pos) > wander_radius_px:
				# Decide andar um pouco (longe de casa, volta para perto dela)
				state = State.WALK
				_pick_new_wander_target()
			else:
				# Muda para deitado ou continua sentado
				state = State.SLEEP if randf() < 0.4 else State.SIT
				facing = -facing if randf() < 0.3 else facing
			state_timer = randf_range(4.0, 9.0)

	func _tick_sleep(delta: float) -> void:
		anim_frame = 1
		state_timer -= delta
		if state_timer <= 0.0:
			state = State.SIT
			state_timer = randf_range(3.0, 6.0)

	func _tick_walk(delta: float) -> void:
		if not _move_toward(target_pos, float(breed_data["walk_speed"]), delta, 3.0):
			# Chegou ao destino ou desistiu dele.
			state = State.SIT
			anim_frame = 0
			state_timer = randf_range(4.0, 8.0)

	func _tick_react(delta: float) -> void:
		anim_frame = 6 # react
		state_timer -= delta
		if state_timer <= 0.0:
			state = State.FLEE
			# Foge para longe de quem o assustou
			_pick_flee_target()
			state_timer = randf_range(2.0, 3.5)

	func _tick_flee(delta: float) -> void:
		if not _move_toward(target_pos, float(breed_data["run_speed"]), delta, 4.0):
			state = State.SIT
			anim_frame = 0
			state_timer = randf_range(5.0, 10.0)

	## Anda até `target`. Bate numa quina: tenta deslizar pelos lados. Devolve
	## false quando chegou, ficou travado por meio segundo ou passou mais de um
	## segundo e meio sem chegar mais perto (deslizando de um lado para o outro).
	func _move_toward(target: Vector2, speed: float, delta: float, arrive: float) -> bool:
		var dir := target - position
		if dir.length() <= arrive:
			_goal = Vector2.INF
			return false
		if target != _goal:
			_goal = target
			_best_gap = dir.length()
			_no_progress = 0.0
		if dir.length() < _best_gap - 2.0:
			_best_gap = dir.length()
			_no_progress = 0.0
		else:
			_no_progress += delta
			if _no_progress > 1.5:
				_goal = Vector2.INF
				return false
		var step := minf(speed * delta, dir.length())
		var heading := dir.normalized()
		var moved := false
		for turn in [0.0, PI * 0.25, -PI * 0.25, PI * 0.5, -PI * 0.5]:
			var attempt: Vector2 = heading.rotated(turn) * step
			if _is_free(position + attempt):
				position += attempt
				moved = true
				if absf(attempt.x) > 0.05:
					facing = signf(attempt.x)
				# A animação avança com o chão percorrido, nunca parada andando.
				stride_left -= attempt.length()
				if stride_left <= 0.0:
					stride_left += STRIDE
					walk_step = (walk_step + 1) % 4
				anim_frame = 2 + walk_step
				break
		if moved:
			stuck_time = 0.0
			return true
		stuck_time += delta
		if stuck_time > 0.5:
			stuck_time = 0.0
			_goal = Vector2.INF
			return false
		return true

	func _trigger_reaction(threat: Vector2) -> void:
		state = State.REACT
		anim_frame = 6
		threat_pos = threat
		facing = signf(threat.x - position.x) if absf(threat.x - position.x) > 0.5 else facing
		state_timer = randf_range(0.8, 1.4)

	func _pick_new_wander_target() -> void:
		for _attempt in range(10):
			var angle := randf() * TAU
			var radius := randf_range(16.0, wander_radius_px)
			var candidate := home_pos + Vector2(cos(angle) * radius, sin(angle) * (radius * 0.5))
			if _is_free(candidate) and manager.segment_free(position, candidate):
				target_pos = candidate
				return
		target_pos = home_pos

	func _pick_flee_target() -> void:
		# Para longe de Senu; sem ameaça conhecida, para longe da casa (como antes).
		var base_dir := (position - threat_pos) if threat_pos.is_finite() else (position - home_pos)
		if base_dir.length_squared() < 0.1:
			base_dir = Vector2(1.0, 0.0)
		base_dir = base_dir.normalized()
		for attempt in range(12):
			# Primeiro reto para longe; depois abrindo o ângulo dos dois lados.
			var angle_offset := floorf((attempt + 1) * 0.5) * 0.3 * (1.0 if attempt % 2 == 0 else -1.0)
			var dir := base_dir.rotated(angle_offset)
			var dist := randf_range(40.0, 85.0)
			var candidate := position + Vector2(dir.x, dir.y * 0.5) * dist
			if _is_free(candidate) and manager.segment_free(position, candidate):
				target_pos = candidate
				return
		target_pos = home_pos


static func build(game_instance: Node2D) -> AnimalLife:
	var instance := AnimalLife.new()
	instance.name = "AnimalLife"
	instance.game = game_instance
	var target_parent: Node = game_instance.actors if "actors" in game_instance else game_instance
	target_parent.add_child(instance)
	instance.setup()
	return instance


var _initialized := false
var _floor_catalog: Dictionary = {}
var _probe_shape: CircleShape2D
var _probe: PhysicsShapeQueryParameters2D

## Chão livre para o corpo inteiro: os quatro lados no piso (nada sobre a água)
## e nenhuma colisão de cenário.
func is_floor_free(point: Vector2) -> bool:
	if _floor_catalog.is_empty():
		_floor_catalog = Layout.tile_catalog()
	for side in [Vector2.ZERO, Vector2(BODY_RADIUS, 0), Vector2(-BODY_RADIUS, 0), Vector2(0, BODY_RADIUS * 0.5), Vector2(0, -BODY_RADIUS * 0.5)]:
		var tile := Vector2i((Layout.unproject(point + side) + Vector2(0.5, 0.5)).floor())
		if not _floor_catalog.has(tile):
			return false
	if is_inside_tree() and get_world_2d() != null:
		if _probe == null:
			_probe_shape = CircleShape2D.new()
			_probe_shape.radius = BODY_RADIUS
			_probe = PhysicsShapeQueryParameters2D.new()
			_probe.shape = _probe_shape
			_probe.collision_mask = 1
		_probe.transform = Transform2D(0.0, point)
		if not get_world_2d().direct_space_state.intersect_shape(_probe, 1).is_empty():
			return false
	return true


## O caminho reto inteiro em chão livre, a cada 6 px.
func segment_free(from: Vector2, to: Vector2) -> bool:
	var samples := maxi(1, ceili(from.distance_to(to) / 6.0))
	for index in range(1, samples + 1):
		if not is_floor_free(from.lerp(to, float(index) / samples)):
			return false
	return true

func setup() -> void:
	if _initialized:
		return
	_initialized = true
	y_sort_enabled = true
	_animals_texture = load(TEXTURE_PATH) as Texture2D
	_spawn_all_animals()


func _ready() -> void:
	setup()


func _spawn_all_animals() -> void:
	for definition in Catalog.ANIMALS:
		var animal := AnimalActor.new()
		animal.manager = self
		add_child(animal)
		animal.setup_animal(definition)
		animals.append(animal)


func _process(delta: float) -> void:
	_player = game.get("player") if game != null else null
	_threat = Threat.level(_player)
	for animal in animals:
		animal.tick(delta, _player, _threat)


## Quantos animais processaram no último quadro (perto de Senu). Para testes.
func awake_count() -> int:
	var count := 0
	for animal in animals:
		if _player == null or animal.position.distance_to(_player.position) <= CULL_DIST:
			count += 1
	return count
