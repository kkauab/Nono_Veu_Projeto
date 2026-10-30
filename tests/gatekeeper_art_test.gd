extends SceneTree
## Art contracts only; this is not a test of the future boss combat.
const View = preload("res://scripts/actors/nameless_gatekeeper_view.gd")
const PILOT := "down_right"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var idle := View.sample("idle", PILOT)
	check(not idle.is_empty(), "Imported atlas can actually be loaded")
	if idle.is_empty():
		quit(1)
		return
	check(idle["texture"].get_width() == 1600 and idle["texture"].get_height() == 1600, "Pixelorama exported the complete nine-attack atlas")
	check(not View.sample("idle", PILOT).is_empty(), "Three-quarter authored idle exists")
	check(View.sample("walk", "left", 0, 10, true).is_empty(), "Missing facing cannot mirror the key-spear into the other hand")
	check(View.sample("unknown", PILOT).is_empty(), "Unknown clips fail visibly instead of silently drawing a different action")
	var cycle: Array[int] = []
	for step in range(16): cycle.append(View.sample("walk", PILOT, 0, step * 22.0/16 + .01, true)["pose"])
	check(cycle == [4,5,6,7,8,9,10,11,12,13,14,15,0,1,2,3], "Sixteen poses follow ground travel, beginning with a compact passing pose")
	check(View.sample("walk", PILOT, 999, 9, false)["frame"] == idle["frame"], "Stopped or blocked movement returns to planted idle despite elapsed time")
	check(View.sample("walk", PILOT, 100, 9, true)["frame"] == View.sample("walk", PILOT, 0, 9, true)["frame"], "Elapsed time cannot slide the feet independently of displacement")
	check(View.sample("walk", PILOT, 0, 22.01, true)["pose"] == 4, "Gait wraps only after the refined full stride")
	check(not View.sample("thrust", PILOT, .999)["contact_pose"], "Body loading cannot display contact early")
	check(View.sample("thrust", PILOT, 1.001)["contact_pose"], "Contact cel begins only after grip, load and acceleration")
	check(not View.sample("thrust", PILOT, 1.10)["contact_pose"], "Follow-through leaves the contact cel")
	check(View.sample("thrust", PILOT, 100)["pose"] == 8, "A completed attack returns to guard without looping")
	for clip in ["idle", "walk", "thrust"]:
		var frame := View.sample(clip, PILOT, 1.01, 6.01, true)
		check(frame["offset"] == Vector2(-80,-140), "All action cels share the same ground pivot: " + clip)
	print("GATEKEEPER ART checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)
