extends SceneTree
## Babble follows the portrait delivery, never the text; one bank per speaker and expression.
const Dialogue = preload("res://scripts/ui/portrait_dialogue.gd")
const Babble = preload("res://scripts/audio/dialogue_babble.gd")
const Banks = preload("res://scripts/audio/dialogue_babble_banks.gd")
const Story = preload("res://resources/dialogue/opening_fisherman.gd")
const Opening = preload("res://scripts/ui/opening_cutscene.gd")
const CATEGORIES := ["passage","emphasis","end_statement","end_question"]
var checks := 0
var failures: Array[String] = []
var heard: Array[Dictionary] = []

func _initialize() -> void: call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func hear(speaker: String, expression: String, category: String, stream: AudioStream) -> void:
	heard.append({"speaker":speaker,"expression":expression,"category":category,"stream":stream})

func perform(view: VeilPortraitDialogue, babble: VeilDialogueBabble, seconds: float, step: float = .02) -> void:
	for frame in range(roundi(seconds/step)):
		view.tick(step)
		babble.listen()

func count(category: String) -> int:
	return heard.filter(func(entry: Dictionary): return entry["category"] == category).size()

func check_banks() -> void:
	for speaker in Banks.BANKS:
		for expression in Dialogue.EXPRESSIONS:
			var bank: Dictionary = (Banks.BANKS[speaker] as Dictionary).get(expression,{})
			for category in CATEGORIES:
				var streams: Array = bank.get(category,[])
				var valid := streams.size() >= 3
				for stream in streams:
					valid = valid and stream is AudioStreamWAV and stream.get_length() > .08 and stream.get_length() < .3
				check(valid,"%s %s has at least three short %s syllables" % [speaker,expression,category])
	var covered := true
	for line in Story.LINES:
		covered = covered and Banks.BANKS.has(line["speaker"]) and (Banks.BANKS[line["speaker"]] as Dictionary).has(line["expression"])
	check(covered,"Every speaker and expression of the approved conversation has a bank")

func check_delivery() -> void:
	var view := Dialogue.new()
	var babble := Babble.new()
	root.add_child(view)
	babble.dialogue = view
	root.add_child(babble)
	view.set_process(false)
	babble.set_process(false)
	babble.syllable_played.connect(hear)
	view.begin_line("PESCADOR","Andava devagar. Não vi sangue. Você esperava encontrá-lo aqui?","concerned","concerned",4.4)
	perform(view,babble,4.6)
	check(heard.size() >= 10 and heard.size() <= 26,"A 4.4 s delivery babbles at a speaking pace (%d syllables)" % heard.size())
	check(heard.all(func(entry: Dictionary): return entry["speaker"] == "PESCADOR" and entry["expression"] == "concerned"),"Only the speaker babbles, in the expression of the line")
	check(count("end_question") == 1 and heard[-1]["category"] == "end_question" and count("end_statement") == 0,"A question closes with one rising ending")
	check(count("emphasis") > 0,"Wide mouth openings sometimes carry emphasis")
	var repeated := false
	for index in range(1,heard.size()): repeated = repeated or heard[index]["stream"] == heard[index-1]["stream"]
	check(not repeated,"The same syllable never plays twice in a row")
	var total := heard.size()
	perform(view,babble,1.0)
	check(not view.is_speaking and heard.size() == total,"Babble stops when the authored delivery ends")
	# Equal delivery time, very different texts: the mouth, and so the babble, is the same.
	heard.clear()
	view.begin_line("SENU","Sim.","neutral","neutral",3.0)
	perform(view,babble,3.2)
	var short_count := heard.size()
	heard.clear()
	view.begin_line("SENU",". ".repeat(60)+"Uma fala bem mais longa, com vírgulas, pausas e pontos.","neutral","neutral",3.0)
	perform(view,babble,.3)
	view.reveal_all()
	perform(view,babble,2.9)
	check(short_count > 0 and heard.size() == short_count,"Text length, punctuation and instant reveal do not change the babble (%d/%d)" % [short_count,heard.size()])
	# A delivery that ends inside the breath pause has no late opening, so it closes without an ending.
	var endings := 0
	var placed := true
	for index in range(Story.LINES.size()):
		heard.clear()
		var line: Dictionary = Story.LINES[index]
		view.begin_line(line["speaker"],line["text"],line["expression"],line["listener_expression"],Story.DELIVERY_SECONDS[index])
		perform(view,babble,Story.DELIVERY_SECONDS[index]+.2)
		var expected := "end_question" if str(line["text"]).ends_with("?") else "end_statement"
		var closing := count("end_question")+count("end_statement")
		endings += closing
		placed = placed and closing <= 1 and (closing == 0 or heard[-1]["category"] == expected)
	check(placed,"Each approved speech has at most one ending, always last, rising only for questions")
	check(endings >= Story.LINES.size()/2,"Most approved speeches close with an ending syllable (%d/%d)" % [endings,Story.LINES.size()])
	heard.clear()
	view.begin_line("SENU","Eu volto para contar o que encontrar.","resolute","sad",2.8)
	perform(view,babble,.8)
	var early := heard.size()
	view.stop_talking()
	perform(view,babble,1.0)
	check(early > 0 and heard.size() == early and count("end_statement") == 0,"Continuing early silences the line without a late ending")
	view.begin_line("SENU","Eu volto para contar o que encontrar.","resolute","sad",2.8)
	perform(view,babble,.8)
	check(heard.size() > early,"Beginning the same line again babbles again")
	view.clear()
	var hidden := heard.size()
	perform(view,babble,.5)
	check(heard.size() == hidden,"A hidden dialogue stays silent")
	view.free()
	babble.free()

func check_opening() -> void:
	var film := Opening.new()
	root.add_child(film)
	paused = true
	film.begin()
	film.set_process(false)
	var babble := film.get_node_or_null("DialogueBabble") as VeilDialogueBabble
	check(babble != null and babble.dialogue == film._dialogue_view,"The opening wires the babble to its portrait dialogue")
	if babble == null:
		film.free()
		return
	check(babble.can_process(),"The babble keeps working while the opening pauses the game")
	var voice_buses := 0
	for index in range(AudioServer.bus_count): if AudioServer.get_bus_name(index) == Babble.BUS: voice_buses += 1
	var voices_on_bus := babble.get_children().all(func(player: Node): return player is AudioStreamPlayer and player.bus == Babble.BUS)
	check(voice_buses == 1 and voices_on_bus and AudioServer.get_bus_send(AudioServer.get_bus_index(Babble.BUS)) == &"Master","Every babble shares one Vozes bus that feeds Master")
	babble.set_process(false)
	heard.clear()
	babble.syllable_played.connect(hear)
	film.seek(Opening.DIALOGUE_CUES[0]-.01)
	for frame in range(150):
		film._process(.02)
		babble.listen()
	check(film.dialogue_index == 0 and heard.size() > 0 and heard.all(func(entry: Dictionary): return entry["speaker"] == "PESCADOR" and entry["expression"] == Story.LINES[0]["expression"]),"The fisherman's first line babbles in his own voice")
	paused = false
	film.free()

func _run() -> void:
	check_banks()
	check_delivery()
	check_opening()
	heard.clear()
	await process_frame
	print("DIALOGUE BABBLE CHECKS: %d passed=%d failures=%s" % [checks,checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)
