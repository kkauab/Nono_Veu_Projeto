extends SceneTree
## Real new-game integration, using only the QA save slot.
const Opening = preload("res://scripts/ui/opening_cutscene.gd")
const Story = preload("res://resources/dialogue/opening_fisherman.gd")
const Dialogue = preload("res://scripts/ui/portrait_dialogue.gd")
var checks := 0
var failures: Array[String] = []
var world: Node2D
var film: Control

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func press(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.global_position = at
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func find_button(caption: String) -> Button:
	for child in world.hud.get_children():
		if child is Button and child.text == caption: return child
	return null

func physical_rect(snapshot: Dictionary, key: String) -> Rect2:
	return snapshot[key] as Rect2

func window_rect(snapshot: Dictionary, key: String) -> Rect2:
	var rect := physical_rect(snapshot,key)
	var stretch: Vector2 = snapshot.get("viewport_scale",Vector2.ONE)
	return Rect2(rect.position*stretch,rect.size*stretch)

func check_delivery_independence() -> void:
	# Two real components receive equal performance time but deliberately very
	# different texts. Text reveal must never become the face animation clock.
	var first := Dialogue.new()
	var second := Dialogue.new()
	root.add_child(first)
	root.add_child(second)
	first.set_process(false)
	second.set_process(false)
	first.begin_line("PESCADOR","Fique. Preciso falar com você.","neutral","neutral",8.0)
	second.begin_line("PESCADOR",". ".repeat(80)+"Ainda não terminei de escrever.","neutral","neutral",8.0)
	var same_trajectory := true
	var varied_mouths := {}
	var listener_frames := {}
	var active_eyes := {}
	var reveal_kept_delivery := false
	for sample in range(325):
		if sample == 6:
			var before: Dictionary = first.portrait_state("PESCADOR")
			first.reveal_all()
			var after: Dictionary = first.portrait_state("PESCADOR")
			reveal_kept_delivery = first.is_speaking and before["speech_mouth"] == after["speech_mouth"] and is_equal_approx(float(before["delivery_remaining"]),float(after["delivery_remaining"]))
		first.tick(.025)
		second.tick(.025)
		var a: Dictionary = first.portrait_state("PESCADOR")
		var b: Dictionary = second.portrait_state("PESCADOR")
		varied_mouths[a["speech_mouth"]] = true
		listener_frames[first.portrait_state("SENU")["frame"]] = true
		active_eyes[a["eye"]] = true
		same_trajectory = same_trajectory and a["pose"] == b["pose"] and a["speech_mouth"] == b["speech_mouth"] and a["is_speaking"] == b["is_speaking"] and is_equal_approx(float(a["delivery_remaining"]),float(b["delivery_remaining"]))
	check(reveal_kept_delivery,"Instant text reveal preserves the independent speaking phase and its remaining time")
	check(same_trajectory,"Different words, punctuation and reveal counts produce the same face performance at equal delivery time")
	check(varied_mouths.size()==3,"The natural speaking cycle contains rest, a small opening and an open mouth")
	check(listener_frames.size()==1,"The inactive character keeps one complete drawing throughout the other character's delivery")
	check(active_eyes.has(2) and active_eyes.size()>1,"The current speaker still blinks while delivering the line")
	check(not first.is_speaking and not second.is_speaking and second.is_typing,"The delivery can finish on its own while deliberately slow text is still being typed")
	first.begin_line("SENU","Uma nova fala.","concerned","sad",4.0)
	first.tick(.6)
	first.stop_talking()
	check(not first.is_speaking and int(first.portrait_state("SENU")["mouth"])==0 and float(first.portrait_state("SENU")["delivery_remaining"])==0,"Stopping the performance resets its delivery and leaves a resting mouth")
	first.free()
	second.free()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	check_delivery_independence()
	world = load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	check(world.store.path.begins_with("user://qa/"), "The portrait integration uses an isolated progress file")
	world.hud.show_overlay("intro")
	await process_frame
	var start := find_button("Nova jornada")
	check(start != null, "The production new-game button is available")
	if start == null:
		quit(1)
		return
	start.pressed.emit()
	await process_frame
	film = world._opening_player
	check(world.opening_active and paused and film != null, "New game automatically opens the portrait cutscene")
	if film == null:
		quit(1)
		return
	film.set_process(false)
	film._has_focus = false
	var ui: Control = film._dialogue_view
	check(Opening.DIALOGUE_COUNT == 24 and Opening.DIALOGUE_COUNT == Story.LINES.size(), "All twenty-four approved speeches are integrated")
	check(film.resources_ready(), "The game loads the complete scenery and both final portrait atlases")
	for speaker in Dialogue.PORTRAIT_PATHS:
		var path: String = Dialogue.PORTRAIT_PATHS[speaker]
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			check(texture != null and texture.get_size() == Vector2(800,768), "The %s portrait uses the new twenty-full-pose atlas" % speaker)
			if texture != null and texture.get_size() == Vector2(800,768):
				var atlas := texture.get_image()
				var drawings := {}
				for pose in range(20):
					drawings[hash(atlas.get_region(Rect2i(pose%5*160,pose/5*192,160,192)).get_data())] = true
				check(drawings.size() == 20, "The %s atlas contains twenty distinct complete raster drawings" % speaker)
	film.seek(Opening.DIALOGUE_CUES[0]-.01)
	film._process(.02)
	check(film.dialogue_active and film.dialogue_index == 0 and ui.active_speaker == "PESCADOR", "The fisherman speaks before Senu disembarks")
	check(film._hero.position.distance_to(film._stage.boat_position+Opening.BOAT_STANDING)<2, "The invitation to disembark is spoken while Senu is still inside the boat")
	var player_at: Vector2 = world.player.position
	var story_at: float = film.elapsed
	var spoken_mouths := {}
	var silent_listener := true
	var previous_count: int = ui.visible_characters
	var revealed_gradually := false
	for frame in range(35):
		film._process(.02)
		var speaker_state: Dictionary = ui.portrait_state("PESCADOR")
		var listener_state: Dictionary = ui.portrait_state("SENU")
		spoken_mouths[int(speaker_state["mouth"])] = true
		silent_listener = silent_listener and int(listener_state["mouth"]) == 0
		if ui.visible_characters>previous_count and ui.visible_characters<ui.full_text.length(): revealed_gradually = true
		previous_count = ui.visible_characters
	check(revealed_gradually and film.dialogue_visible_characters == ui.visible_characters, "Visible text is typed by the portrait system and mirrored by the cutscene")
	check(spoken_mouths.size()>1 and silent_listener, "The current speaker performs naturally while the listening character stays quiet")
	check(film.elapsed == story_at and world.player.position == player_at, "Reading keeps the story and the protected gameplay actor still")
	var speaking_before_reveal: Dictionary = ui.portrait_state("PESCADOR")
	await press(KEY_ENTER)
	check(film.dialogue_active and film.dialogue_index == 0 and ui.is_revealed(), "The first Enter reveals the current speech without advancing it")
	check(not ui.is_typing and ui.is_speaking and int(ui.portrait_state("PESCADOR")["speech_mouth"]) == int(speaking_before_reveal["speech_mouth"]), "Instant reveal completes only the text and preserves the ongoing speaking performance")
	var waiting_listener_frames := {}
	for frame in range(240):
		film._process(.05)
		waiting_listener_frames[int(ui.portrait_state("SENU")["frame"])] = true
	check(waiting_listener_frames.size()==1 and int(ui.portrait_state("SENU")["eye"])==0, "The listening portrait remains completely still, including its eyes, while the other character owns the line")
	check(not ui.is_speaking and int(ui.portrait_state("PESCADOR")["mouth"]) == 0 and int(ui.portrait_state("SENU")["mouth"]) == 0, "Both mouths rest after the independent delivery finishes")
	var layout: Dictionary = ui.layout_snapshot()
	await click(physical_rect(layout,"text").get_center())
	check(not film.dialogue_active and film.active, "Clicking the finished dialogue continues without skipping the cutscene")
	film._process(.8)
	check(film._hero.velocity.length()>0 and not film.dialogue_active, "Senu walks off the boat after the fisherman's invitation")
	film._process(maxf(.01,Opening.DIALOGUE_CUES[1]-film.elapsed+.01))
	check(film.dialogue_active and film.dialogue_index == 1 and ui.active_speaker == "SENU", "Senu's reply begins only after the landing walk")
	var smallest_720: Dictionary = {}
	var last_owned_expressions := {"SENU":"neutral","PESCADOR":"neutral"}
	for index in range(1,Opening.DIALOGUE_COUNT):
		check(film.dialogue_active and film.dialogue_index == index, "The production conversation reaches approved speech %d" % index)
		check(ui.full_text == Story.LINES[index]["text"] and ui.active_speaker == Story.LINES[index]["speaker"], "Portrait text and speaker match the approved speech %d" % index)
		var active_state: Dictionary = ui.portrait_state(ui.active_speaker)
		check(active_state["expression"] == Story.LINES[index]["expression"], "The expression follows the context of speech %d" % index)
		var listener_name := "PESCADOR" if ui.active_speaker=="SENU" else "SENU"
		var listener_before: Dictionary = ui.portrait_state(listener_name)
		var active_frames := {active_state["frame"]:true}
		var frozen: bool = listener_before["expression"] == last_owned_expressions[listener_name]
		for sample in range(5):
			film._process(.05)
			var still: Dictionary = ui.portrait_state(listener_name)
			frozen = frozen and still["frame"] == listener_before["frame"] and int(still["eye"])==0 and int(still["mouth"])==0
			active_frames[ui.portrait_state(ui.active_speaker)["frame"]] = true
		check(frozen and active_frames.size()>1,"Speech %d animates only its speaker and freezes the listener in their own last expression" % index)
		last_owned_expressions[ui.active_speaker] = Story.LINES[index]["expression"]
		await process_frame
		layout = ui.layout_snapshot()
		check(float(layout["content_height"]) <= physical_rect(layout,"text").size.y+1, "Approved speech %d fits the dialogue box at720p" % index)
		if index == 7: smallest_720 = layout.duplicate()
		await press(KEY_E)
		check(film.dialogue_index == index and ui.is_revealed(), "E reveals speech %d without losing its ending" % index)
		await press(KEY_E)
		check(not ui.is_speaking,"Continuing from approved speech %d stops its old performance" % index)
		if index<Opening.DIALOGUE_COUNT-1: film._process(maxf(.01,Opening.DIALOGUE_CUES[index+1]-film.elapsed+.01))
	check(not film.dialogue_active and film.elapsed>=12 and film.active, "Reading the whole approved conversation resumes the final walk")
	# A long approved speech is checked again at a genuinely larger root window.
	film.seek(Opening.DIALOGUE_CUES[7]-.01)
	film._process(.02)
	root.size = Vector2i(1920,1080)
	await process_frame
	await process_frame
	film._process(.001)
	await process_frame
	layout = ui.layout_snapshot()
	var viewport_rect := Rect2(Vector2.ZERO,Vector2(1920,1080))
	check(viewport_rect.encloses(window_rect(layout,"left_portrait")) and viewport_rect.encloses(window_rect(layout,"right_portrait")) and viewport_rect.encloses(window_rect(layout,"box")), "Both portraits and the bottom box remain inside the1080p viewport")
	check(physical_rect(layout,"left_portrait").get_center().x<physical_rect(layout,"right_portrait").get_center().x, "Senu stays on the left and the fisherman on the right")
	check(float(layout["content_height"])<=physical_rect(layout,"text").size.y+1, "The longest approved speech also fits at1080p")
	if not smallest_720.is_empty():
		check(absf(window_rect(layout,"box").size.x/window_rect(smallest_720,"box").size.x-1.5)<.02, "The dialogue geometry follows the actual720p to1080p window scale")
	root.size = Vector2i(1280,720)
	film.seek(Opening.DURATION-.01)
	film._process(.02)
	await process_frame
	check(not world.opening_active and not paused and world.player.controls_enabled and world.hud.visible and world.world_container.visible, "The natural ending restores gameplay, HUD and rendering together")
	check(bool(world.store.data["flags"].get("opening_seen",false)), "The approved opening records completion in the isolated journey")
	print("PORTRAIT DIALOGUE INTEGRATION CHECKS: %d passed=%d failures=%s" % [checks,checks-failures.size(),failures])
	paused = false
	quit(0 if failures.is_empty() else 1)
