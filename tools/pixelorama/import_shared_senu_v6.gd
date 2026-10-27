extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var path := "res://assets/sprites/senu_shared_v6_manifest.json"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var texture := load(data["texture"]) as Texture2D
	if texture == null:
		push_error("Shared Senu atlas was not imported")
		quit(1)
		return
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for category in data["weapon_variants"]:
		var clips: Dictionary = data["weapon_variants"][category]["clips"]
		for state in clips:
			var clip: Dictionary = clips[state]
			for direction in clip["directions"]:
				var name: String = category + "_" + state + "_" + direction
				frames.add_animation(name)
				frames.set_animation_speed(name, float(clip["fps"]))
				frames.set_animation_loop(name, bool(clip["loop"]))
				for index in clip["directions"][direction]:
					var r: Array = data["frame_regions"][int(index)]
					var atlas := AtlasTexture.new()
					atlas.atlas = texture
					atlas.region = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
					atlas.filter_clip = true
					frames.add_frame(name, atlas)
	var error := ResourceSaver.save(frames, "res://resources/characters/senu_shared_v6_frames.tres")
	print("SHARED_SENU_V6_IMPORT ", error_string(error), " animations=", frames.get_animation_names().size())
	quit(0 if error == OK else 1)
