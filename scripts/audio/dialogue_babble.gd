class_name VeilDialogueBabble
extends Node
## Speech-like babble for VeilPortraitDialogue. Like the portraits, it follows the
## authored delivery: one syllable each time the speaker's mouth changes to an
## open pose. Text reveal, punctuation and reveal_all() never drive it.
signal syllable_played(speaker: String, expression: String, category: String, stream: AudioStream)

const Banks = preload("res://scripts/audio/dialogue_babble_banks.gd")
const VOICES := 3
const PITCH_SPREAD := .05
const EMPHASIS_CHANCE := .3
## The first opening inside this window closes the line with an ending syllable.
const ENDING_WINDOW := .4
## Shared with VeilSfx.ensure_buses(); whoever runs first creates it.
const BUS := "Vozes"

var dialogue: VeilPortraitDialogue
var volume_db := -8.0
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _line := ""
var _last_mouth := 0
var _last_remaining := 0.0
var _last_stream: AudioStream
var _ended := false
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count-1,BUS)
		AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	# Overlapping voices let each syllable's short room tail ring out.
	for index in range(VOICES):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = BUS
		add_child(player)
		_players.append(player)

func _process(_delta: float) -> void:
	listen()

## Reads the dialogue state once; tests call it right after the dialogue tick.
func listen() -> void:
	if not is_instance_valid(dialogue) or not dialogue.visible or not dialogue.is_speaking:
		_last_mouth = 0
		_last_remaining = 0
		return
	var speaker := dialogue.active_speaker
	var line := speaker+"\n"+dialogue.full_text
	# A new line, or the same line begun again, restarts the delivery.
	if line != _line or dialogue.delivery_remaining > _last_remaining+.05:
		_line = line
		_ended = false
		_last_mouth = 0
		_rng.seed = hash(line)
	_last_remaining = dialogue.delivery_remaining
	var state := dialogue.portrait_state(speaker)
	var mouth: int = state["speech_mouth"]
	if mouth != 0 and mouth != _last_mouth and not _ended:
		_speak(speaker,str(state["expression"]),mouth)
	_last_mouth = mouth

func _speak(speaker: String, expression: String, mouth: int) -> void:
	var bank: Dictionary = (Banks.BANKS.get(speaker,{}) as Dictionary).get(expression,{})
	if bank.is_empty(): return
	var category := "passage"
	if dialogue.delivery_remaining <= ENDING_WINDOW:
		category = "end_question" if dialogue.full_text.strip_edges().ends_with("?") else "end_statement"
		_ended = true
	elif mouth == 2 and _rng.randf() < EMPHASIS_CHANCE:
		category = "emphasis"
	# Never the same syllable twice in a row.
	var choices: Array = (bank[category] as Array).filter(func(stream): return stream != _last_stream)
	var stream: AudioStream = choices[_rng.randi_range(0,choices.size()-1)]
	_last_stream = stream
	var player := _players[_next_player]
	_next_player = (_next_player+1)%_players.size()
	player.stream = stream
	player.pitch_scale = 1.0+_rng.randf_range(-PITCH_SPREAD,PITCH_SPREAD)
	player.volume_db = volume_db
	player.play()
	syllable_played.emit(speaker,expression,category,stream)
