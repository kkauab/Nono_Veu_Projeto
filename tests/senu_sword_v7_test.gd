extends SceneTree
const View = preload("res://scripts/actors/senu_supplied_view.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	Inputs.install()
	var actor := SenuPlayer.new()
	root.add_child(actor)
	actor.set_physics_process(false)
	actor.weapon_unlocked[1] = true
	for i in range(8):
		for heavy in [false, true]:
			actor.reset_at(Vector2.ZERO)
			actor.equip_weapon(0)
			actor.facing = Vector2.DOWN.rotated(-i * PI / 4)
			var view := View.new()
			var idle := view.sample(actor)
			actor.try_attack(heavy)
			var start := view.sample(actor)
			var impact := .24 if heavy else .12
			actor._physics_process(impact)
			var contact := view.sample(actor)
			var name: String = ("heavy/" if heavy else "light/") + str(View.DIRECTIONS[i])
			check(bool(contact.get("embedded_equipment", false)) and view.equipment_pose(actor, contact).is_empty(), name + ": wrist and blade are one authored cut; modular blade is not drawn twice")
			check(contact.get("cut_pose") == "contato" and contact["frame"] != start["frame"], name + ": visible cut reaches contact at the existing damage time")
			check(contact["direction"] == View.DIRECTIONS[i] and start["size"] == contact["size"] and start["offset"] == contact["offset"], name + ": committed direction, canvas and foot pivot stay fixed")
			var image: Image = (contact["texture"] as Texture2D).get_image()
			var r: Rect2 = contact["region"]
			var used := image.get_region(Rect2i(r)).get_used_rect()
			check(used.has_area() and used.position.x > 0 and used.end.x < r.size.x and used.position.y > 0 and used.end.y < r.size.y, name + ": no limb or slash is clipped by the compact atlas")
			actor._physics_process(.17)
			var follow := view.sample(actor)
			check(follow["frame_position"] == int(follow["frame_count"]) - 1, name + ": cut follows through into its drawn recovery")
			actor._physics_process(1.0)
			var settled := view.sample(actor)
			check(settled["texture_path"] == idle["texture_path"] and settled["region"] == idle["region"], name + ": original shared body returns after the cut")
	actor.reset_at(Vector2.ZERO)
	actor.equip_weapon(1)
	var dagger_view := View.new()
	dagger_view.sample(actor)
	actor.try_attack()
	var dagger := dagger_view.sample(actor)
	check(bool(dagger.get("modular_equipment", false)) and not bool(dagger.get("embedded_equipment", false)), "Daggers retain their own double-strike body and equipment")
	actor.queue_free()
	await process_frame
	print("SENU SWORD V7 CHECKS: ", checks, " passed=", checks - failures.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)
