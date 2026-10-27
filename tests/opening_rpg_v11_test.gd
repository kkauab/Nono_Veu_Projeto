extends SceneTree
const Film = preload("res://scripts/ui/opening_cutscene.gd")
var checks := 0
var failures: Array[String] = []
var emitted := 0
func _initialize() -> void: call_deferred("_run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
func key(physical: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.pressed = down
	Input.parse_input_event(event)
	await process_frame
func press(physical: Key) -> void:
	await key(physical,true)
	await key(physical,false)
func _run() -> void:
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	var film := Film.new()
	root.add_child(film)
	film.finished.connect(func(): emitted += 1)
	paused = true
	film.begin()
	film.set_process(false)
	await process_frame
	check(film.active and film.process_mode==Node.PROCESS_MODE_ALWAYS,"The RPG scene can animate while actual gameplay is paused")
	check(not film._hero.is_in_group("player") and film._hero.collision_layer==0,"The staged Senu cannot replace or collide with the gameplay actor")
	film.seek(.5)
	var boat: Vector2 = film._stage.boat_position
	film.seek(1.5)
	check(boat.distance_to(film._stage.boat_position)>5,"The dedicated arrival boat moves toward its mooring")
	film.seek(2.1)
	var foot: Vector2 = film._hero.position
	film.seek(3.3)
	check(film._hero.position.distance_to(foot)>20 and film._hero.velocity.length()>8 and film._hero._supplied_view.current_state=="walk","Senu disembarks with actual walking frames")
	film.seek(Film.DIALOGUE_CUES[0]-.01)
	film._process(.02)
	check(film.dialogue_active and film.dialogue_index==0,"The first NPC dialogue stops the arrival sequence")
	var stopped := film.elapsed
	film._process(.1)
	check(film.elapsed==stopped and film.dialogue_visible_characters>0 and film.dialogue_visible_characters<film._dialogue_text().length(),"Text reveals gradually while the story timeline waits")
	await press(KEY_ENTER)
	check(film.dialogue_active and film.dialogue_index==0 and film.dialogue_visible_characters==film._dialogue_text().length(),"One Enter reveals the complete current line without advancing")
	await press(KEY_ENTER)
	film._process(Film.DIALOGUE_CUES[1]-film.elapsed+.01)
	check(film.dialogue_active and film.dialogue_index==1,"A second Enter continues to Senu's reply")
	for index in range(1,Film.DIALOGUE_COUNT):
		check(film.dialogue_active and film.dialogue_index==index,"The authored dialogue order reaches section %d" % index)
		await press(KEY_E)
		check(film.dialogue_visible_characters==film._dialogue_text().length(),"E also reveals the current section %d" % index)
		await press(KEY_E)
		if index<Film.DIALOGUE_COUNT-1: film._process(Film.DIALOGUE_CUES[index+1]-film.elapsed+.01)
	check(not film.dialogue_active and film.elapsed==12.0 and film.active,"Reading every dialogue resumes the departure walk rather than skipping the opening")
	film._process(1.0)
	var departed: Vector2 = film._hero.position
	film._process(2.0)
	check(film._hero.position.distance_to(departed)>50 and film._hero.velocity.length()>8,"The second automatic walk is played after the conversation")
	film.begin()
	film.seek(Film.DIALOGUE_CUES[0]-.01)
	film._process(.02)
	await press(KEY_ESCAPE)
	check(film.active and film.dialogue_index==0 and emitted==0,"Escape cannot skip the RPG opening or its dialogue")
	await key(KEY_SPACE,true)
	film._process(1.0)
	await key(KEY_SPACE,false)
	check(film.active and film.hold_elapsed==0,"Releasing Space cancels partial skip progress during dialogue")
	await key(KEY_SPACE,true)
	film._process(1.0)
	film._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	film._process(3.2)
	check(film.active and film.hold_elapsed==0 and emitted==0,"Losing focus cancels the skip hold even without a key-release event")
	film._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	await key(KEY_SPACE,false)
	await key(KEY_SPACE,true)
	film._process(2.9)
	check(film.active and emitted==0,"A 2.9-second hold does not skip while the story is stopped on dialogue")
	film._process(.11)
	await key(KEY_SPACE,false)
	check(not film.active and emitted==1,"A continuous three-second hold skips once, independently of dialogue timing")
	film._finish()
	check(emitted==1,"Repeated finish calls cannot emit twice")
	film.begin()
	film.seek(Film.DURATION-.05)
	film._process(.1)
	check(not film.active and emitted==2,"The final authored cue also finishes naturally")
	if ResourceLoader.exists(Film.ATLAS_PATH):
		check(film.resources_ready() and film._stage.atlas.resource_path==Film.ATLAS_PATH,"The staged map loads its dedicated original arrival atlas")
	paused = false
	film.queue_free()
	await process_frame
	print("OPENING RPG V11 CHECKS: ",checks," passed=",checks-failures.size()," failures=",failures)
	quit(0 if failures.is_empty() else 1)
