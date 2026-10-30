class_name VeilAmbient
extends Node

## Coordenador de som ambiente e da luz de cada lugar de O Nono Véu.
## - Vento costeiro noturno do Porto dos Esquecidos (contínuo);
## - zumbido harmônico dos santuários, obeliscos e templos, por proximidade, só
##   nos lugares sagrados (antes vazava pela água para o cais e o mercado);
## - leito sonoro do lugar (ondas, murmúrio, fornalha, pingos, canais, grilos,
##   sinos), trocado com fusão ao atravessar de um setor para outro;
## - luz do lugar: um CanvasModulate no mundo, que muda devagar.
## Os perfis ficam em ambient_profiles.gd (docs/MUNDO_PROPOSTA_2026-10-30.md).
## Tudo no bus "Ambiente".

const Sfx = preload("res://scripts/audio/sfx.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Profiles = preload("res://scripts/audio/ambient_profiles.gd")

const WIND_STREAM: AudioStream = preload("res://assets/audio/ambient/harbor_wind_loop.wav")
const SANCTUARY_STREAM: AudioStream = preload("res://assets/audio/ambient/sanctuary_drone_loop.wav")

const WIND_BASE_DB := -18.0
const SANCTUARY_PEAK_DB := -13.0
const SANCTUARY_RADIUS := 320.0
const SANCTUARY_FALLOFF := 480.0
const SILENT_DB := -60.0
## Segundos, aproximados, de cada troca de lugar.
const BED_FADE := 1.6
const LIGHT_FADE := 1.2
## Sem terra a esta distância (em tiles), o barco está em mar aberto.
const OPEN_SEA_REACH := 7

static var _active_instance: VeilAmbient

var game: Node
var _wind: AudioStreamPlayer
var _sanctuary: AudioStreamPlayer
var _beds: Array[AudioStreamPlayer] = []
var _bed_names: Array[String] = ["", ""]
var _front := 0
var _hero: Node2D
var _sanctuary_points: Array[Vector2] = []
var _sanctuary_vol := -60.0
var _initialized := false
var _light: CanvasModulate
var _streams: Dictionary = {}
var _sea_tick := 0.0
var _open_sea := false
## Perfil em uso (ambient_profiles.gd): lido pelos testes e pela captura.
var current_profile := ""


## Instancia o coordenador e o ancora no nó principal do jogo.
static func build(game_node: Node) -> VeilAmbient:
	if is_instance_valid(_active_instance):
		_active_instance.queue_free()
	var ambient := VeilAmbient.new()
	ambient.name = "VeilAmbient"
	ambient.game = game_node
	ambient.process_mode = Node.PROCESS_MODE_ALWAYS
	game_node.add_child(ambient)
	_active_instance = ambient
	return ambient


func _ready() -> void:
	Sfx.ensure_buses()
	_setup_sanctuary_locations()
	_setup_players()
	_setup_light()
	_initialized = true


func _setup_sanctuary_locations() -> void:
	_sanctuary_points.clear()
	# Pontos de relevância sagrada no mapa
	var sacred_tiles: Array[Vector2] = [
		Vector2(0, 0),       # Santuário da Primeira Palavra
		Vector2(25, -26),    # Praça dos Três Sinos
		Vector2(5, -28),     # Arquivo dos Nomes Velados
		Vector2(81, 34),     # Observatório das Estrelas Mortas
		Vector2(-6, 38),     # Santuário Soterrado
		Vector2(46, 68),     # Ilha do Bennu / Altar do Fogo
		Vector2(-12, 6),     # Claustro dos Iniciados / Casa das Primeiras Palavras
		Vector2(9, 74),      # Ilha do Íbis Afogado / lago do templo
		Vector2(-20, 25),    # Catacumbas do Eco
	]
	for tile in sacred_tiles:
		_sanctuary_points.append(Layout.iso(tile))


func _setup_players() -> void:
	# 1. Vento noturno do porto (base contínua)
	_wind = AudioStreamPlayer.new()
	_wind.name = "HarborWind"
	_wind.stream = WIND_STREAM
	_wind.bus = "Ambiente"
	_wind.volume_db = WIND_BASE_DB
	_wind.autoplay = true
	add_child(_wind)
	if is_inside_tree():
		_wind.play()

	# 2. Ressonância harmônica de santuários (fade-in perto de locais sagrados)
	_sanctuary = AudioStreamPlayer.new()
	_sanctuary.name = "SanctuaryDrone"
	_sanctuary.stream = SANCTUARY_STREAM
	_sanctuary.bus = "Ambiente"
	_sanctuary.volume_db = -60.0
	_sanctuary.autoplay = true
	add_child(_sanctuary)
	if is_inside_tree():
		_sanctuary.play()

	# 3. Dois leitos do lugar, para fundir um no outro ao trocar de setor. Os laços
	# são carregados já aqui: carregar na hora da travessia travaria um quadro.
	for bed_name in Profiles.BEDS:
		_stream(bed_name)
	for index in range(2):
		var bed := AudioStreamPlayer.new()
		bed.name = "PlaceBed%s" % ["A", "B"][index]
		bed.bus = "Ambiente"
		bed.volume_db = SILENT_DB
		add_child(bed)
		_beds.append(bed)


func _setup_light() -> void:
	var stage: Variant = game.get("world_stage") if game != null else null
	if not stage is Node2D:
		return
	_light = CanvasModulate.new()
	_light.name = "SectorLight"
	_light.color = Color.WHITE
	(stage as Node2D).add_child(_light)


## O lugar onde Senu está, como nome de perfil de ambient_profiles.gd.
func location() -> String:
	var house_val: Variant = game.get("inside_house") if game != null else null
	if house_val != null and str(house_val) != "":
		return "house"
	if game != null and (game.get("at_sea") == true or game.get("sea_busy") == true):
		return "open_sea" if _open_sea else "sea"
	var room: Variant = game.get("current_room") if game != null else null
	if room == null and is_instance_valid(_hero):
		room = sector_at(_hero.global_position)
	if room == null or str(room) == "":
		return "sea"
	return Profiles.for_room(str(room))


## A sala sob um ponto do mundo, ou "" na água (port_layout.room_at devolve "p1").
static func sector_at(point: Vector2) -> String:
	var tile := Vector2i(Layout.unproject(point).round())
	for room in Layout.ROOMS:
		if room["rect"].has_point(tile):
			return room["id"]
	for connector in Layout.CONNECTORS + Layout.LANDINGS:
		if connector["rect"].has_point(tile):
			return connector["room"]
	return ""


func _process(delta: float) -> void:
	if not _initialized or _wind == null or _sanctuary == null or not is_inside_tree():
		return

	if not is_instance_valid(_hero):
		if game != null and "player" in game and is_instance_valid(game.player):
			_hero = game.player as Node2D
		elif game != null and game.has_meta("player"):
			_hero = game.get_meta("player") as Node2D
		elif is_inside_tree() and get_tree() != null:
			_hero = get_tree().get_first_node_in_group("player") as Node2D

	var paused: bool = get_tree().paused if get_tree() != null else false
	var opening_val: Variant = game.get("opening_active") if game != null else null
	var in_opening: bool = bool(opening_val) if opening_val != null else false
	var house_val: Variant = game.get("inside_house") if game != null else null
	var in_house: bool = str(house_val) != "" if house_val != null else false
	var duck_offset: float = -42.0 if in_opening else (-7.0 if paused else 0.0)

	_sea_tick -= delta
	if _sea_tick <= 0.0:
		_sea_tick = .5
		_open_sea = _far_from_land()
	current_profile = location()
	var place: Dictionary = Profiles.profile(current_profile)

	# Vento do lugar, com ducking em menus de caderno/pausa e abertura
	var wind_target: float = float(place["wind_db"]) + duck_offset
	_wind.volume_db = lerpf(_wind.volume_db, wind_target, minf(1.0, delta * 3.0))

	# Proximidade de santuários sagrados, só nos lugares sagrados
	var target_sanctuary_db := -60.0
	if not in_opening and not in_house and bool(place["sacred"]) and is_instance_valid(_hero) and not _sanctuary_points.is_empty():
		var hero_pos := _hero.global_position
		var min_dist := INF
		for pt in _sanctuary_points:
			var d := hero_pos.distance_to(pt)
			if d < min_dist:
				min_dist = d

		if min_dist <= SANCTUARY_RADIUS:
			target_sanctuary_db = SANCTUARY_PEAK_DB
		elif min_dist < SANCTUARY_FALLOFF:
			var factor := 1.0 - (min_dist - SANCTUARY_RADIUS) / (SANCTUARY_FALLOFF - SANCTUARY_RADIUS)
			target_sanctuary_db = lerpf(-60.0, SANCTUARY_PEAK_DB, factor)

	target_sanctuary_db += duck_offset
	_sanctuary_vol = lerpf(_sanctuary_vol, target_sanctuary_db, minf(1.0, delta * 2.2))
	_sanctuary.volume_db = _sanctuary_vol

	_update_beds(str(place["bed"]), float(place["bed_db"]) + duck_offset, delta)
	if _light != null and is_instance_valid(_light):
		_light.color = _light.color.lerp(place["light"], minf(1.0, delta / LIGHT_FADE * 2.5))


## O leito do lugar sobe num dos dois tocadores enquanto o do lugar anterior desce.
func _update_beds(bed: String, bed_db: float, delta: float) -> void:
	if _beds.size() < 2:
		return
	if bed != _bed_names[_front]:
		var back := 1 - _front
		if bed != _bed_names[back]:
			_bed_names[back] = bed
			var stream := _stream(bed)
			_beds[back].stop()
			_beds[back].stream = stream
			_beds[back].volume_db = SILENT_DB
			if stream != null and is_inside_tree():
				_beds[back].play()
		elif not _beds[back].playing and _beds[back].stream != null and is_inside_tree():
			# Voltou ao leito que acabara de calar: ele recomeça baixo e sobe.
			_beds[back].volume_db = SILENT_DB
			_beds[back].play()
		_front = back
	var step := minf(1.0, delta / BED_FADE * 3.0)
	for index in range(2):
		var target := bed_db if index == _front and _bed_names[index] != "" else SILENT_DB
		var player := _beds[index]
		player.volume_db = lerpf(player.volume_db, target, step)
		if index != _front and player.playing and player.volume_db < SILENT_DB + 2.0:
			player.stop()


func _stream(bed: String) -> AudioStream:
	if bed == "" or not Profiles.BEDS.has(bed):
		return null
	if not _streams.has(bed):
		var path: String = Profiles.BEDS[bed]
		var stream: AudioStream = load(path) as AudioStream if ResourceLoader.exists(path) else null
		if stream is AudioStreamWAV:
			# Os leitos são laços; o bloco smpl já marca, isto só garante.
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		_streams[bed] = stream
	return _streams[bed]


## Leito em uso (para testes): nome e volume do tocador da frente.
func bed_state() -> Dictionary:
	if _beds.size() < 2:
		return {"bed": "", "db": SILENT_DB, "back_bed": "", "back_db": SILENT_DB, "back_playing": false}
	var back := _beds[1 - _front]
	return {"bed": _bed_names[_front], "db": _beds[_front].volume_db, "back_bed": _bed_names[1 - _front], "back_db": back.volume_db, "back_playing": back.playing}


func light_color() -> Color:
	return _light.color if _light != null and is_instance_valid(_light) else Color.WHITE


func _far_from_land() -> bool:
	if game == null or game.get("at_sea") != true or not is_instance_valid(_hero):
		return false
	var layout: Variant = game.get("layout")
	if layout == null or not "tiles" in layout:
		return false
	var tiles: Dictionary = layout.tiles
	var at := Vector2i(Layout.unproject(_hero.global_position).round())
	for x in range(-OPEN_SEA_REACH, OPEN_SEA_REACH + 1, 2):
		for y in range(-OPEN_SEA_REACH, OPEN_SEA_REACH + 1, 2):
			if tiles.has(at + Vector2i(x, y)):
				return false
	return true
