extends SceneTree

# Ambientação por lugar (docs/MUNDO_PROPOSTA_2026-10-30.md): cada setor tem leito
# sonoro, vento, zumbido sagrado e luz próprios (ambient_profiles.gd), e a troca
# acontece ao atravessar de um para outro, também no mar, em mar aberto, nas ilhas
# e dentro das casas. Precisa do mundo real: -- --qa.
const MainScene = preload("res://scenes/boot/main.tscn")
const Layout = preload("res://scripts/world/port_layout.gd")
const Profiles = preload("res://scripts/audio/ambient_profiles.gd")
const Sea = preload("res://scripts/world/sea.gd")

var checks := 0
var failures: Array[String] = []
var world: Node2D
var ambient: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(150.0).timeout.connect(_on_timeout)
	if not "--qa" in OS.get_cmdline_user_args():
		print("NOTE ambience test needs the real world; append -- --qa")
		quit(1)
		return
	_test_catalog()
	world = MainScene.instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	world.hud.show_overlay("")
	var session_dir := "user://qa/ambience_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(session_dir))
	world.store.path = session_dir + "/world.json"
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	ambient = world.get_node_or_null("VeilAmbient")
	_check(ambient != null and ambient.has_method("bed_state"), "the ambience coordinator runs in the world")
	var light: Node = world.world_stage.get_node_or_null("SectorLight")
	_check(light is CanvasModulate, "the world has a sector light (CanvasModulate) inside the pixel viewport")
	await _test_crossing()
	await _test_sacred()
	await _test_sea()
	await _test_house_and_pause()
	print("AMBIENCE RESULT checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)


func _test_catalog() -> void:
	var missing := []
	for room in Layout.ROOMS:
		if not Profiles.ROOM_PROFILE.has(room["id"]):
			missing.append(room["id"])
	_check(missing.is_empty(), "every sector has an ambience profile (missing: %s)" % str(missing))
	var used := {}
	for room_id in Profiles.ROOM_PROFILE:
		used[Profiles.ROOM_PROFILE[room_id]] = true
		_check(Profiles.PROFILES.has(Profiles.ROOM_PROFILE[room_id]), "profile exists for " + room_id)
	_check(used.size() >= 12, "sectors do not all share one ambience (%d profiles in use)" % used.size())
	for name in Profiles.PROFILES:
		var place: Dictionary = Profiles.PROFILES[name]
		_check(place.has("bed") and place.has("bed_db") and place.has("wind_db") and place.has("sacred") and place["light"] is Color, "profile is complete: " + name)
	for bed in Profiles.BEDS:
		var stream := load(Profiles.BEDS[bed]) as AudioStreamWAV
		_check(stream != null and stream.get_length() > 8.0 and stream.mix_rate == 22050, "bed loop loads: %s (%.1f s)" % [bed, stream.get_length() if stream != null else 0.0])


func _test_crossing() -> void:
	# Um passeio pelos lugares; em cada um, o leito, o vento e a luz do lugar.
	for stop in [["hub", Vector2(-1, -1)], ["cloister", Vector2(-4, 8)], ["p1", Vector2(10, 0)], ["market", Vector2(22, -1)],
			["kilns", Vector2(64, 3)], ["archive", Vector2(5, -28)], ["garden", Vector2(17, 25)], ["cistern", Vector2(18, 38)],
			["bellcourt", Vector2(21, -25)], ["oracle", Vector2(80, 30)], ["b1", Vector2(-5, 25)], ["isle", Vector2(42, 70)],
			["ibis", Vector2(15, 74)], ["wreck", Vector2(80, 67)]]:
		world.player.reset_at(Layout.iso(stop[1]))
		await _settle(3.0)
		var expected := Profiles.for_room(stop[0])
		var place := Profiles.profile(expected)
		var bed: Dictionary = ambient.bed_state()
		_check(world.current_room == stop[0] and ambient.current_profile == expected, "%s uses the %s ambience (%s)" % [stop[0], expected, ambient.current_profile])
		_check(bed["bed"] == place["bed"] and (place["bed"] == "" or absf(bed["db"] - float(place["bed_db"])) < 2.5), "%s plays its bed '%s' (%s at %.1f dB)" % [stop[0], place["bed"], bed["bed"], bed["db"]])
		var wind: AudioStreamPlayer = ambient.get_node("HarborWind")
		_check(absf(wind.volume_db - float(place["wind_db"])) < 2.5, "%s sets its wind (%.1f dB, wants %.1f)" % [stop[0], wind.volume_db, place["wind_db"]])
		var color: Color = ambient.light_color()
		var wanted: Color = place["light"]
		_check(Vector3(color.r - wanted.r, color.g - wanted.g, color.b - wanted.b).length() < .04, "%s lights the world its own way" % stop[0])
	# Atravessar do santuário ao cais troca o leito com fusão, sem corte seco.
	world.player.reset_at(Layout.iso(Vector2(-1, -1)))
	await _settle(1.4)
	var before: Dictionary = ambient.bed_state()
	world.player.reset_at(Layout.iso(Vector2(10, 0)))
	# Quadro a quadro: o mar sobe e a noite do santuário desce, sem corte seco.
	var rising := 0
	var falling := 0
	var swapped := false
	var until := Time.get_ticks_msec() + int(2500.0 / Engine.time_scale)
	while Time.get_ticks_msec() < until:
		await process_frame
		var now: Dictionary = ambient.bed_state()
		if "--verbose-beds" in OS.get_cmdline_user_args():
			print("BEDS ", now)
		swapped = now["bed"] == "surf"
		if now["db"] > -55.0 and now["db"] < -20.5:
			rising += 1
		if now["back_bed"] == "night" and now["back_playing"] and now["back_db"] < -31.0 and now["back_db"] > -55.0:
			falling += 1
	_check(before["bed"] == "night" and swapped and rising >= 4, "crossing into the Cais fades the surf in over %d frames" % rising)
	_check(falling >= 3, "while the sanctuary night fades out over %d frames" % falling)


func _test_sacred() -> void:
	var drone: AudioStreamPlayer = ambient.get_node("SanctuaryDrone")
	world.player.reset_at(Layout.iso(Vector2(-1, -1)))
	await _settle(1.4)
	var at_hub := drone.volume_db
	# O Cais fica a menos de 480 px do santuário: antes o zumbido vazava para lá.
	world.player.reset_at(Layout.iso(Vector2(9, 1)))
	await _settle(2.0)
	_check(at_hub > -25.0 and drone.volume_db < -40.0, "the sanctuary hum stays in sacred places (santuário %.1f dB, cais %.1f dB)" % [at_hub, drone.volume_db])


func _test_sea() -> void:
	world.player.reset_at(Layout.iso(Sea.DOCKS["sabu"]["land"]))
	await physics_frame
	_check(Sea.board(world), "Senu boards to test the sea")
	await create_timer(1.0).timeout
	await _settle(1.0)
	_check(ambient.current_profile == "sea", "rowing in the bay uses the sea ambience (%s)" % ambient.current_profile)
	world.boat.global_position = Layout.iso(Vector2(40, 90))
	await _settle(1.6)
	_check(ambient.current_profile == "open_sea", "far from any shore the boat is in open sea (%s)" % ambient.current_profile)
	world.boat.global_position = Layout.iso(Sea.DOCKS["sabu"]["water"])
	await _settle(1.0)
	_check(ambient.current_profile == "sea", "back by the pier it is the bay again")
	Sea.respawn(world)
	await physics_frame


func _test_house_and_pause() -> void:
	world.player.reset_at(Layout.iso(Vector2(29, 1)))
	await _settle(1.0)
	world.inside_house = "merit"
	await _settle(1.4)
	var wind: AudioStreamPlayer = ambient.get_node("HarborWind")
	_check(ambient.current_profile == "house" and wind.volume_db < -28.0, "inside a house the wind falls away (%.1f dB)" % wind.volume_db)
	world.inside_house = ""
	await _settle(1.4)
	var open_wind := wind.volume_db
	paused = true
	for frame in range(30):
		await process_frame
	_check(wind.volume_db < open_wind - 4.0, "the notebook pause ducks the place (%.1f → %.1f dB)" % [open_wind, wind.volume_db])
	paused = false


func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0 / Engine.time_scale)
	while Time.get_ticks_msec() < until:
		await physics_frame
	await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS ", label)
	else:
		failures.append(label)
		push_error("FAIL " + label)


func _on_timeout() -> void:
	push_error("Ambience test timed out before completion")
	quit(1)
