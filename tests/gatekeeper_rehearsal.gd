extends SceneTree
## Playable movement/art review on the actual map. Requires an isolated QA slot.
const Actor=preload("res://tests/gatekeeper_rehearsal_actor.gd")
const Data=preload("res://scripts/actors/gatekeeper_attack_data.gd")
var actor: VeilEnemy
var title: Label
var world: Node2D

func _initialize() -> void:_run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args() or DisplayServer.get_name()=="headless":
		push_error("Rehearsal requires a graphical Godot window and -- --qa")
		quit(1)
		return
	world=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	await process_frame
	if not world.qa_mode or not world.store.path.begins_with("user://qa/"):
		quit(1)
		return
	world.hud.show_overlay("")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.collision_layer=0
		enemy.collision_mask=0
	world.boss.visible=false
	actor=Actor.new()
	actor.position=world.boss.position
	actor.target=world.player
	world.actors.add_child(actor)
	world.player.reset_at(actor.position+Vector2(114,24))
	world.current_room="b1"
	var camera: Camera2D=world.player.get_node("IsometricCamera")
	camera.reset_smoothing()
	var layer:=CanvasLayer.new()
	root.add_child(layer)
	var panel:=PanelContainer.new()
	panel.position=Vector2(20,20)
	layer.add_child(panel)
	var column:=VBoxContainer.new()
	panel.add_child(column)
	title=Label.new()
	title.text="PORTEIRO / caminhada e nove golpes"
	column.add_child(title)
	var note:=Label.new()
	note.text="Mova Senu: o Porteiro acompanha pelo mapa.\n1-9: golpe especifico / Tab: alternar sequencia automatica\nVista-piloto: tres quartos. Estudo de arte, sem dano ou recompensas."
	note.add_theme_font_size_override("font_size",16)
	column.add_child(note)
	actor.clip_started.connect(func(id):title.text=Data.definition(id)["name"])
	print("GATEKEEPER REHEARSAL: live navigation, nine clips, isolated QA, no damage/rewards")
	if "--smoke" in OS.get_cmdline_user_args():
		for frame in range(180):await physics_frame
		world.queue_free()
		await process_frame
		quit()

func _input(event: InputEvent) -> void:
	if actor==null or not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode==KEY_TAB:
		actor.automatic=not actor.automatic
		title.text="Sequencia automatica: "+("ligada" if actor.automatic else "desligada")
	elif event.keycode>=KEY_1 and event.keycode<=KEY_9:
		actor.automatic=false
		actor.play_clip(str(Data.load_data()["order"][event.keycode-KEY_1]))
