extends SceneTree
## Atualiza os recursos do Godot a partir da exportação nativa do Pixelorama.

const VARIANTS := {"espada": "sword", "leve": "daggers"}
const MAX_TEXTURE_SIDE := 16384
const CANVAS := Vector2i(384, 384)
const PIVOT := Vector2i(192, 280)
const STATES := ["idle", "walk", "attack_light", "attack_heavy", "dodge", "parry", "hurt", "death", "power"]
const DIRECTIONS := ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]

var _invalid := false
var _version := 4
var _native_json := "res://assets/sprites/senu_v4.json"
var _texture_path := "res://assets/sprites/senu_v4.png"
var _manifest_path := "res://assets/sprites/senu_v4_manifest.json"
var _plan_path := "res://art/pixelorama/senu/export_plan_v4.json"
var _frames_path := "res://resources/characters/senu_v4_frames.tres"
var _states: Array = STATES


func _initialize() -> void:
	call_deferred("_run")


func _reject(message: String) -> void:
	_invalid = true
	push_error("SENU_PIXELORAMA_IMPORT: " + message)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_reject("Arquivo ausente: " + path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		_reject("JSON inválido: " + path)
		return {}
	return parser.data


func _profile_int(profile: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = profile.get(key, str(fallback))
	var string := str(value).strip_edges()
	if not string.is_valid_int():
		_reject("Opção de exportação inválida: " + key)
		return fallback
	return int(string)


func _run() -> void:
	# Movimento tem uma folha independente; combate mantém a versão anterior.
	if "--motion-v5" in OS.get_cmdline_user_args():
		_version = 5
		_native_json = "res://assets/sprites/senu_motion_v5.json"
		_texture_path = "res://assets/sprites/senu_motion_v5.png"
		_manifest_path = "res://assets/sprites/senu_motion_v5_manifest.json"
		_plan_path = "res://art/pixelorama/senu/export_plan_motion_v5.json"
		_frames_path = "res://resources/characters/senu_motion_v5_frames.tres"
		_states = ["walk", "run", "dodge"]
	elif not FileAccess.file_exists(_native_json):
		_version = 3
		_native_json = "res://assets/sprites/senu_v3.json"
		_texture_path = "res://assets/sprites/senu_v3.png"
		_manifest_path = "res://assets/sprites/senu_v3_manifest.json"
		_plan_path = "res://art/pixelorama/senu/export_plan.json"
		_frames_path = "res://resources/characters/senu_v3_frames.tres"
	var native := _read_json(_native_json)
	var base_path := _manifest_path if FileAccess.file_exists(_manifest_path) else _plan_path
	var manifest := _read_json(base_path)
	if _invalid:
		quit(1)
		return
	if int(native.get("size_x", 0)) != CANVAS.x or int(native.get("size_y", 0)) != CANVAS.y:
		_reject("Mantenha a tela do Pixelorama em 384 × 384 para preservar o alinhamento dos pés.")
	var profile_value: Variant = native.get("export_profile")
	if not profile_value is Dictionary:
		_reject("Perfil de exportação nativo ausente.")
		quit(1)
		return
	var profile: Dictionary = profile_value
	var orientation := _profile_int(profile, "orientation", 1)
	if orientation not in [0, 1]:
		_reject("Orientação da folha não reconhecida.")
	if _profile_int(profile, "resize", 100) != 100 or _profile_int(profile, "crop_mode", 0) != 0:
		_reject("Exporte em 100%, sem recortar a tela transparente dos quadros.")
	if _profile_int(profile, "frame_current_tag", 0) != 0:
		_reject("Exporte todos os quadros, sem limitar a uma tag.")
	if _profile_int(profile, "direction", 0) != 0:
		_reject("Use a ordem normal dos quadros na exportação.")
	var frames_value: Variant = native.get("frames")
	var tags_value: Variant = native.get("tags")
	if not frames_value is Array or frames_value.is_empty() or not tags_value is Array or tags_value.is_empty():
		_reject("A exportação precisa conter quadros e tags.")
		quit(1)
		return
	var frames: Array = frames_value
	var tags: Array = tags_value
	var native_fps := float(native.get("fps", 0))
	if not is_finite(native_fps) or native_fps <= 0:
		_reject("Velocidade da linha do tempo inválida.")
		quit(1)
		return
	var texture := load(_texture_path) as Texture2D
	if texture == null:
		_reject("O atlas precisa ser importado pelo Godot antes deste comando.")
		quit(1)
		return
	var texture_size := Vector2i(texture.get_size())
	if texture_size.x > MAX_TEXTURE_SIDE or texture_size.y > MAX_TEXTURE_SIDE:
		_reject("O atlas excede 16384 pixels por lado. Ajuste o número de colunas no Pixelorama.")
		quit(1)
		return
	if texture_size.x % CANVAS.x != 0 or texture_size.y % CANVAS.y != 0:
		_reject("O atlas não contém células inteiras de 384 × 384.")
		quit(1)
		return
	var columns := texture_size.x / CANVAS.x
	var rows := texture_size.y / CANVAS.y
	if columns * rows < frames.size():
		_reject("A imagem exportada tem menos células que a linha do tempo.")
	var lines := _profile_int(profile, "lines_count", 8)
	if lines < 1 or (orientation == 1 and columns != lines) or (orientation == 0 and rows != lines):
		_reject("A disposição do atlas não corresponde ao perfil exportado.")
	var regions: Array = []
	var duration_seconds: Array = []
	var duration_scalars: Array = []
	var atlas_frames: Array[AtlasTexture] = []
	for index in range(frames.size()):
		var frame: Variant = frames[index]
		if not frame is Dictionary:
			_reject("Quadro nativo inválido: " + str(index + 1))
			continue
		var duration := float(frame.get("duration", 1.0))
		if not is_finite(duration) or duration <= 0:
			_reject("Duração inválida no quadro " + str(index + 1))
			continue
		var x := (index % columns) * CANVAS.x if orientation == 1 else (index / rows) * CANVAS.x
		var y := (index / columns) * CANVAS.y if orientation == 1 else (index % rows) * CANVAS.y
		if x + CANVAS.x > texture_size.x or y + CANVAS.y > texture_size.y:
			_reject("Quadro fora da imagem exportada: " + str(index + 1))
			continue
		regions.append([x, y, CANVAS.x, CANVAS.y])
		duration_seconds.append(duration / native_fps)
		duration_scalars.append(duration)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(x, y, CANVAS.x, CANVAS.y)
		atlas.filter_clip = true
		atlas_frames.append(atlas)
	if _invalid:
		quit(1)
		return
	var sequences: Dictionary = {}
	for tag_value in tags:
		if not tag_value is Dictionary:
			_reject("Tag inválida na linha do tempo.")
			continue
		var tag: Dictionary = tag_value
		var name := str(tag.get("name", "")).strip_edges()
		var start := int(tag.get("from", 0)) - 1
		var end := int(tag.get("to", 0)) - 1
		if name.is_empty() or sequences.has(name) or start < 0 or end < start or end >= frames.size():
			_reject("Nome ou intervalo de tag inválido: " + name)
			continue
		var indices: Array = []
		for index in range(start, end + 1):
			indices.append(index)
		sequences[name] = indices
	var extras := sequences.duplicate(true)
	var weapon_variants: Dictionary = {}
	if _version >= 4:
		for category in VARIANTS:
			var variant_clips := _build_clips(VARIANTS[category] + "_", sequences, extras, duration_seconds)
			weapon_variants[category] = {"clips": variant_clips}
	else:
		weapon_variants["espada"] = {"clips": _build_clips("", sequences, extras, duration_seconds)}
	if _invalid:
		quit(1)
		return
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.resource_name = "Senu — Pixelorama v%d" % _version
	for name in sequences:
		sprite_frames.add_animation(name)
		sprite_frames.set_animation_speed(name, native_fps)
		sprite_frames.set_animation_loop(name, name.begins_with("idle_") or name.begins_with("walk_") or "_idle_" in name or "_walk_" in name or "_run_" in name)
		for index in sequences[name]:
			sprite_frames.add_frame(name, atlas_frames[index], float(duration_scalars[index]))
	manifest["version"] = _version
	manifest["canvas"] = [CANVAS.x, CANVAS.y]
	manifest["pivot"] = [PIVOT.x, PIVOT.y]
	manifest["texture"] = _texture_path
	manifest["frame_count"] = frames.size()
	manifest["frame_regions"] = regions
	manifest["frame_durations"] = duration_seconds
	manifest["native_fps"] = native_fps
	manifest["texture_size"] = [texture_size.x, texture_size.y]
	manifest["clips"] = weapon_variants["espada"]["clips"]
	if _version >= 4:
		manifest["weapon_variants"] = weapon_variants
	manifest["extras"] = extras
	manifest["exported_by"] = "Pixelorama " + str(native.get("pixelorama_version", "")) + " (official CLI)"
	manifest["sprite_frames"] = _frames_path
	var folder_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_frames_path.get_base_dir()))
	if folder_error != OK and folder_error != ERR_ALREADY_EXISTS:
		_reject("Não foi possível criar a pasta de animações: " + error_string(folder_error))
		quit(1)
		return
	var save_error := ResourceSaver.save(sprite_frames, _frames_path)
	if save_error != OK:
		_reject("Não foi possível salvar SpriteFrames: " + error_string(save_error))
		quit(1)
		return
	var output := FileAccess.open(_manifest_path, FileAccess.WRITE)
	if output == null:
		_reject("Não foi possível salvar o manifesto: " + error_string(FileAccess.get_open_error()))
		quit(1)
		return
	output.store_string(JSON.stringify(manifest, "\t", false) + "\n")
	output.close()
	print("SENU_PIXELORAMA_IMPORT_OK version=%d frames=%d animations=%d variants=%d canvas=%dx%d texture=%dx%d fps=%s" % [_version, frames.size(), sequences.size(), weapon_variants.size(), CANVAS.x, CANVAS.y, texture_size.x, texture_size.y, native_fps])
	quit(0)


func _build_clips(prefix: String, sequences: Dictionary, extras: Dictionary, durations: Array) -> Dictionary:
	var clips: Dictionary = {}
	for state in _states:
		var directions: Dictionary = {}
		var total_duration := 0.0
		var total_frames := 0
		for direction in DIRECTIONS:
			var name: String = prefix + state + "_" + direction
			if not sequences.has(name):
				_reject("Tag necessária ausente: " + name)
				continue
			var indices: Array = sequences[name]
			directions[direction] = indices
			extras.erase(name)
			for index in indices:
				total_duration += float(durations[index])
				total_frames += 1
		clips[state] = {"fps": total_frames / maxf(.0001, total_duration), "loop": state in ["idle", "walk"], "directions": directions}
	return clips
