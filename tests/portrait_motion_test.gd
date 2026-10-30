extends SceneTree
const Dialogue = preload("res://scripts/ui/portrait_dialogue.gd")
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description)
func _run() -> void:
	var view := Dialogue.new()
	root.add_child(view)
	view.set_process(false)
	view.begin_line("SENU","O que o senhor viu no mar?","concerned","neutral",4)
	view.tick(.02)
	var start := view.portrait_motion("SENU")
	check(start["energy"] > 0 and start["energy"] < .2,"Gesture eases in instead of jumping with the first mouth frame")
	for sample in range(60): view.tick(.02)
	var before := view.delivery_remaining
	var sample := view.portrait_motion("SENU")
	for i in range(20): view.portrait_motion("SENU")
	check(view.delivery_remaining == before,"Drawing motion cannot advance the dialogue clock")
	check(absf(sample["head_x"]) <= .85 and absf(sample["head_y"]) <= .65,"Head motion stays below one source pixel per axis")
	check(view.portrait_motion("PESCADOR")["energy"] == 0,"Listener does not perform the speaker gesture")
	view.stop_talking()
	check(view.portrait_motion("SENU")["energy"] == sample["energy"],"Stopping speech preserves the pose for a smooth recovery")
	view.tick(.2)
	check(view.portrait_motion("SENU")["energy"] < sample["energy"],"Gesture settles after delivery ends")
	view.tick(2)
	check(view.portrait_motion("SENU")["energy"] < .001,"Recovery reaches rest")
	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280,720)
		Engine.max_fps = 30
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/portrait_motion"))
		for frame in range(150):
			if frame == 0: view.begin_line("SENU","O mar também guarda o que esquecemos?","concerned","neutral",2.1)
			if frame == 75: view.begin_line("PESCADOR","Às vezes devolve. Às vezes, espera que alguém procure.","sad","neutral",2.1)
			if frame == 0: view._blink_due[0] = .4
			if frame == 75: view._blink_due[1] = .4
			view.tick(1.0/30)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://qa/portrait_motion/frame_%03d.png" % frame)
	view.free()
	print("PORTRAIT MOTION checks=%d failures=%s" % [checks,failures])
	quit(0 if failures.is_empty() else 1)
