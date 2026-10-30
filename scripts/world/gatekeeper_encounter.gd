extends Node
## Coordinates the existing HUD/dialogue, gates, tower-only save and boss actor.
const Boss=preload("res://scripts/actors/nameless_gatekeeper.gd")
const Dialogue=preload("res://resources/dialogue/gatekeeper_dialogue.gd")
const Layout=preload("res://scripts/world/port_layout.gd")
const Record=preload("res://scripts/world/gatekeeper_record.gd")
var game: Node2D
var gate_locked:=false
var sequence:=""
var _pending:=""
var _camera_state: Dictionary={}
var _previous_controls:=true
var _hold:=0.0
var _focused:=true
var _skip_label: Label
var _sequence_time:=0.0
var _narrative_stage:=""
var _reveal_left:=0.0
var _reveal_from:=Vector2.ZERO

func setup(owner_game: Node2D) -> void:
	game=owner_game
	process_mode=Node.PROCESS_MODE_ALWAYS
	preload("res://scripts/world/gatekeeper_dressing.gd").build(game)
	if "porteiro" in game.store.data["defeated"]:game.store.data["flags"]["boss"]=true
	if game.store.data["flags"]["boss"]:
		game.exit_gate.open()
		game.boss_entry_gate.open()
		if not is_instance_valid(game.boss):
			var corpse:=Boss.new()
			corpse.enemy_id="porteiro"
			corpse.target=game.player
			corpse.position=Layout.iso(Vector2(-6,23))
			game.actors.add_child(corpse)
			corpse.set_loaded_defeat()
			game.boss=corpse
	if game.boss is Boss:game.boss.sequence_requested.connect(_request)
	var music:=preload("res://scripts/audio/gatekeeper_music.gd").new()
	music.boss=game.boss
	add_child(music)
	game.player.died.connect(_on_player_died)
	for record in Dialogue.RECORDS:
		var item:=Record.new()
		item.item_id=record["id"]
		item.kind="gatekeeper_record"
		item.label="Ler registro do porto"
		item.position=Layout.iso(record["tile"])
		game.actors.add_child(item)
	var remains:=Record.new()
	remains.item_id="gatekeeper_remains"
	remains.kind="gatekeeper_remains"
	remains.label="Examinar os pertences do Porteiro"
	remains.position=Layout.iso(Vector2(-6,23))+Vector2(15,0)
	remains.active=bool(game.store.data["flags"]["boss"])
	game.actors.add_child(remains)

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.boss) or not (game.boss is Boss):return
	var boss: Boss=game.boss
	if _reveal_left>0:
		_reveal_left=maxf(0,_reveal_left-delta)
		var camera: Camera2D=game.player.get_node("IsometricCamera")
		var fraction:=1-_reveal_left/1.2
		camera.global_position=_reveal_from.lerp(game.exit_gate.global_position+Vector2(65,-36),smoothstep(0,1,fraction))
		camera.force_update_scroll()
		if _reveal_left<=0:finish_reveal()
		return
	if boss.mode==Boss.Mode.DORMANT and gate_locked:_unlock_gate()
	if not sequence.is_empty():
		_sequence_time+=delta
		var bubble=game.hud.get_node_or_null("NpcSpeechBubble")
		var page:=int(bubble.page_index) if bubble!=null else 0
		var stage:=sequence
		if sequence=="intro":stage="kneel" if page==0 and _sequence_time<.7 else ("rise" if page<7 else "idle_desperate")
		elif sequence=="phase":stage="despair" if page<2 else "rise"
		elif sequence=="defeat":stage="defeat"
		if stage!=_narrative_stage:
			if sequence=="phase" and stage=="rise":boss.play_vocal("scream")
			if sequence=="intro" and stage=="idle_desperate":boss.play_vocal("nervous_laugh")
			_narrative_stage=stage
			boss.narrative_clip=stage
			boss.narrative_elapsed=0
		boss.advance_narrative(delta)
		if sequence=="phase" and page<2:boss.narrative_elapsed=minf(boss.narrative_elapsed,1.7)
		if sequence=="defeat" and page==0:boss.narrative_elapsed=minf(boss.narrative_elapsed,1.9)
		if _focused and Input.is_key_pressed(KEY_SPACE):_hold+=delta
		else:_hold=0
		if is_instance_valid(_skip_label):_skip_label.text="Segure Espaço por 3 s para pular"+(" · %d%%"%mini(100,roundi(_hold/3*100)) if _hold>0 else "")
		if game.hud.overlay!="dialog" or _hold>=3:finish_sequence(_hold>=3)
		return
	if not _pending.is_empty() and game.hud.overlay=="":
		_start_sequence(_pending)
		return
	if boss.mode==Boss.Mode.DORMANT and not game.respawning and not game.opening_active and game.hud.overlay=="" and not game.player.dead:
		if Layout.room_at(game.player.position)=="b1" and game.seals_found()==3:
			if "gatekeeper_intro_seen" in game.store.data["collected"]:
				boss.start_fight()
				_lock_gate()
			else:boss.begin_intro()

func _request(kind: String) -> void:
	_pending=kind

func _start_sequence(kind: String) -> void:
	_pending=""
	sequence=kind
	_sequence_time=0
	_narrative_stage=""
	_hold=0
	_previous_controls=game.player.controls_enabled
	game.player.cancel_actions()
	for projectile in get_tree().get_nodes_in_group("mercury_projectiles"):
		if projectile.get_parent()==game.actors:
			projectile.set_physics_process(false)
			projectile.queue_free()
	game.player.controls_enabled=false
	var camera: Camera2D=game.player.get_node("IsometricCamera")
	_camera_state={"position":camera.position,"global":camera.global_position,"top_level":camera.top_level,"zoom":camera.zoom}
	camera.top_level=true
	camera.global_position=game.boss.global_position+Vector2(0,-22)
	camera.reset_smoothing()
	camera.force_update_scroll()
	var text: String={"intro":Dialogue.INTRO,"phase":Dialogue.PHASE,"defeat":Dialogue.DEFEAT}[kind]
	game.hud.show_conversation("O Porteiro Sem Nome",text,"porteiro")
	var floor_names=game.layout.get_node_or_null("GatekeeperFloorNames")
	if floor_names!=null:floor_names.queue_redraw()
	_skip_label=Label.new()
	_skip_label.name="GatekeeperSkip"
	_skip_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_label.offset_top=-28
	_skip_label.offset_bottom=-6
	_skip_label.offset_right=0
	_skip_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.add_theme_font_override("font",game.hud.font)
	_skip_label.add_theme_font_size_override("font_size",14)
	_skip_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(_skip_label)

func finish_sequence(skip_reveal: bool=false) -> void:
	if sequence.is_empty():return
	var finished:=sequence
	sequence=""
	if finished=="intro":
		game.store.collect("gatekeeper_intro_seen",0)
		game.boss.start_fight()
		_lock_gate()
		game.hud.toast("O PORTEIRO SEM NOME",Color("dfc38c"),4)
	elif finished=="phase":game.boss.resume_phase_two()
	elif finished=="defeat":
		game.boss.confirm_defeat()
		if not skip_reveal:
			game.hud.show_overlay("")
			game.hud.set_process_unhandled_input(false)
			get_tree().paused=true
			_reveal_left=1.2
			_reveal_from=game.player.get_node("IsometricCamera").global_position
			return
	_restore()

func finish_reveal() -> void:
	_reveal_left=0
	_restore()
	if is_instance_valid(game) and is_instance_valid(game.hud):
		game.hud.set_process_unhandled_input(true)
		get_tree().paused=game.hud.overlay!=""

func _restore() -> void:
	if not is_instance_valid(game):return
	if is_instance_valid(_skip_label):_skip_label.queue_free()
	if is_instance_valid(game.player):
		game.player.controls_enabled=_previous_controls
		var camera: Camera2D=game.player.get_node_or_null("IsometricCamera")
		if camera!=null and not _camera_state.is_empty():
			camera.top_level=bool(_camera_state["top_level"])
			camera.zoom=_camera_state["zoom"]
			camera.position=_camera_state["position"]
			if camera.top_level:camera.global_position=_camera_state["global"]
			camera.reset_smoothing()
			camera.force_update_scroll()
	_camera_state.clear()
	if not game.is_queued_for_deletion() and is_instance_valid(game.hud) and game.hud.overlay=="dialog":game.hud.show_overlay("")

func _lock_gate() -> void:
	gate_locked=true
	game.boss_entry_gate.close()

func _unlock_gate() -> void:
	gate_locked=false
	if game.seals_found()==3 or game.store.data["flags"]["boss"]:game.boss_entry_gate.open()

func _on_player_died() -> void:
	_pending=""
	sequence=""
	_reveal_left=0
	_restore()
	_unlock_gate()
	if is_instance_valid(game.boss) and game.boss is Boss and not game.store.data["flags"]["boss"]:game.boss.reset_enemy()

func award_victory() -> void:
	game.store.collect("gatekeeper_reward",2)
	game.store.collect("gatekeeper_key_spear",0)
	_unlock_gate()
	for item in get_tree().get_nodes_in_group("interactables"):
		if item.item_id=="gatekeeper_remains":
			item.active=true
			item.global_position=game.boss.global_position+Vector2(15,0)

func activate(item: PortInteractable) -> bool:
	if item.kind=="gatekeeper_record":
		for record in Dialogue.RECORDS:
			if item.item_id==record["id"]:
				game.store.collect(item.item_id,0)
				game.hud.show_dialog(record["title"],record["text"])
				return true
	if item.kind=="gatekeeper_remains" and game.store.data["flags"]["boss"]:
		award_victory() # Explicit recovery for a legacy victory, once per marker.
		game.hud.show_dialog("A Chave-Lança do Porteiro","Uma antiga arma cerimonial utilizada por um guarda de Alexandria. Pequenos sinos pendem de sua haste. Seus registros foram apagados, mas os golpes ainda conservam a memória de quem os executava.\n\nA chave-lança foi guardada no inventário.")
		return true
	return false

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:_focused=false;_hold=0
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:_focused=true

func _exit_tree() -> void:
	if not sequence.is_empty() or _reveal_left>0:
		_restore()
		if get_tree()!=null:get_tree().paused=false
