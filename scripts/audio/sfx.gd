class_name VeilSfx
extends Node
## Efeitos sonoros curtos, com variação de tom e sem repetir o mesmo arquivo
## duas vezes seguidas. Um conjunto fixo de vozes fica em cada viewport.
##
##     VeilSfx.play(self, "hit_light", enemy.global_position)
##
## Com `at`, o som é posicional (pan e distância relativos à câmera do mundo);
## sem `at`, toca sem posição. Os bancos estão em sfx_banks.gd, gerado por
## tools/audio/build_combat_sfx.py.

const Banks = preload("res://scripts/audio/sfx_banks.gd")
const BUSES := ["SFX", "Ambiente", "Vozes"]
const POOL_NAME := "VeilSfx"
const POSITIONAL_VOICES := 12
const FLAT_VOICES := 4
const PITCH_SPREAD := .06
## Distância, em pixels do mundo, em que um som posicional deixa de ser ouvido.
const HEARING_DISTANCE := 460.0

var _positional: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _next_positional := 0
var _next_flat := 0
var _last_stream := {}
var _rng := RandomNumberGenerator.new()


## Cria os buses de efeitos, ambiente e vozes, se ainda não existirem.
static func ensure_buses() -> void:
	for bus_name: String in BUSES:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
		if bus_name == "SFX":
			# Golpes simultâneos somam picos; o limitador evita a distorção.
			AudioServer.add_bus_effect(index, AudioEffectHardLimiter.new())


## Toca uma variação do banco. Devolve o player usado, ou null.
static func play(context: Node, bank: String, at: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch: float = 1.0) -> Node:
	var pool := pool_for(context)
	if pool == null:
		return null
	return pool.play_bank(bank, at, volume_db, pitch)


static func pool_for(context: Node) -> VeilSfx:
	if context == null or not context.is_inside_tree():
		return null
	var viewport := context.get_viewport()
	var stored: Variant = viewport.get_meta(POOL_NAME) if viewport.has_meta(POOL_NAME) else null
	var pool: VeilSfx = stored if is_instance_valid(stored) else null
	if pool == null:
		pool = VeilSfx.new()
		pool.name = POOL_NAME
		viewport.set_meta(POOL_NAME, pool)
		# Durante o _ready de outro nó a viewport ainda está montando os filhos.
		viewport.add_child.call_deferred(pool)
	return pool if pool.is_inside_tree() else null


static func has_bank(bank: String) -> bool:
	return Banks.BANKS.has(bank)


func _ready() -> void:
	ensure_buses()
	_rng.randomize()
	# Mundos em SubViewport só ouvem sons 2D se a viewport for a ouvinte.
	get_viewport().audio_listener_enable_2d = true
	for index in range(POSITIONAL_VOICES):
		var voice := AudioStreamPlayer2D.new()
		voice.name = "Positional%d" % index
		voice.max_distance = HEARING_DISTANCE
		voice.attenuation = 1.4
		add_child(voice)
		_positional.append(voice)
	for index in range(FLAT_VOICES):
		var voice := AudioStreamPlayer.new()
		voice.name = "Flat%d" % index
		add_child(voice)
		_flat.append(voice)


func _exit_tree() -> void:
	# Ao fechar o jogo no meio de um som, o servidor de áudio solta a reprodução.
	for voice in _positional:
		voice.stop()
	for voice in _flat:
		voice.stop()


func play_bank(bank: String, at: Vector2 = Vector2.INF, volume_db: float = 0.0, pitch: float = 1.0) -> Node:
	var streams: Array = Banks.BANKS.get(bank, [])
	if streams.is_empty() or _positional.is_empty():
		return null
	var choices := streams.filter(func(stream): return stream != _last_stream.get(bank))
	if choices.is_empty():
		choices = streams
	var stream: AudioStream = choices[_rng.randi_range(0, choices.size() - 1)]
	_last_stream[bank] = stream
	var voice: Node
	if at == Vector2.INF:
		voice = _flat[_next_flat]
		_next_flat = (_next_flat + 1) % _flat.size()
	else:
		voice = _positional[_next_positional]
		_next_positional = (_next_positional + 1) % _positional.size()
		(voice as AudioStreamPlayer2D).global_position = at
	voice.set("stream", stream)
	voice.set("bus", Banks.BUS.get(bank, "SFX"))
	voice.set("volume_db", float(Banks.VOLUME_DB.get(bank, 0.0)) + volume_db)
	voice.set("pitch_scale", pitch * (1.0 + _rng.randf_range(-PITCH_SPREAD, PITCH_SPREAD)))
	voice.call("play")
	return voice
