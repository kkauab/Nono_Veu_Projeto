extends Node
const Gatekeeper=preload("res://scripts/actors/nameless_gatekeeper.gd")
## Two original layers, on the existing Musica bus/preferences.
var boss: Node
var layers: Array[AudioStreamPlayer]=[]
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/audio/sfx.gd").ensure_buses()
	for path in ["res://assets/audio/music/gatekeeper_duty.wav","res://assets/audio/music/gatekeeper_despair.wav"]:
		var player:=AudioStreamPlayer.new()
		var stream: AudioStreamWAV=load(path).duplicate()
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
		player.stream=stream
		player.bus="Musica"
		player.volume_db=-80
		add_child(player)
		player.play()
		layers.append(player)
func _process(delta: float) -> void:
	if not is_instance_valid(boss):return
	var active:=bool(boss.encounter_active) or int(boss.mode)==Gatekeeper.Mode.INTRO
	var intense:=int(boss.phase)==2 or int(boss.mode)==Gatekeeper.Mode.TRANSITION
	for i in range(layers.size()):
		var target: float=(-23.0 if i==0 else (-21.0 if intense else -80.0)) if active else -80.0
		layers[i].volume_db=move_toward(layers[i].volume_db,target,delta*24)
