extends RefCounted
## Apresentação dos sprites fornecidos pelo usuário. Não aplica dano ou movimento.

const MANIFEST_PATH := "res://assets/sprites/senu_v3_manifest.json"
const V4_MANIFEST_PATH := "res://assets/sprites/senu_v4_manifest.json"
const MOTION_MANIFEST_PATH := "res://assets/sprites/senu_motion_v5_manifest.json"
const SHARED_MANIFEST_PATH := "res://assets/sprites/senu_shared_v6_manifest.json"
const SwordView := preload("res://scripts/actors/senu_sword_view.gd")
const PixelMotion := preload("res://scripts/actors/actor_pixel_motion.gd")
const DIRECTIONS := ["down", "down_right", "right", "up_right", "up", "up_left", "left", "down_left"]

var current_state := "idle"
var current_clip := "idle"
var current_direction := "right"
var current_frame := -1
var current_weapon := "espada"
var gait_phase := 0.0
var load_error := "Sprites ainda não exportados."
var motion_load_error := ""

var _texture: Texture2D
var _shared_body := false
var _frame_hands: Array = []
var _equipment: Dictionary = {}
var _motion_texture: Texture2D
var _motion_regions: Array = []
var _motion_durations: Array = []
var _motion_variants: Dictionary = {}
var _motion_texture_path := ""
var _next_motion_load_check := 0
var _asset_manifest_path := ""
var _base_clips: Dictionary = {}
var _weapon_variants: Dictionary = {}
var _clips: Dictionary = {}
var _regions: Array = []
var _extras: Dictionary = {}
var _durations: Array = []
var _canvas := Vector2(384, 384)
var _pivot := Vector2(192, 280)
var _scale := .26
var _walk_cycle_duration := .5
var _action_duration := .2
var _attack_duration := .4
var _dodge_window := .2
var _shadow_power := false
var _previous_weapon := ""
var _next_load_check := 0
var _owner_id := 0
var _last_time := -1.0
var _state_started := 0.0
var _death_started := 0.0
var _hurt_started := 0.0
var _dodge_started := 0.0
var _parry_started := 0.0
var _attack_started := 0.0
var _attack_visual_length := .19
var _attack_state := "attack_light"
var _attack_active := false
var _attack_interrupted := false
var _previous_dead := false
var _previous_hurt := 0.0
var _previous_dodge := 0.0
var _previous_parry := 0.0
var _previous_attack := 0.0
var _last_distance := 0.0


func draw(actor: Node2D) -> bool:
	var frame := sample(actor)
	if frame.is_empty():
		return false
	var frame_texture: Texture2D = frame["texture"]
	var shadow := PackedVector2Array()
	for i in range(24):
		var angle := TAU * float(i) / 24.0
		shadow.append(Vector2(cos(angle) * (17.0 if current_state == "death" else 11.0), sin(angle) * 4.5))
	actor.draw_colored_polygon(shadow, Color(.01, .015, .02, .45))
	if current_weapon == "leve" and current_state == "power" and _shadow_power:
		var dodge_direction: Vector2 = actor.get("_dodge_direction")
		var trail_direction := Vector2(dodge_direction.x, dodge_direction.y * .7)
		for i in range(3):
			var distance := float(3 - i) * 6.0
			var alpha: float = [.08, .12, .18][i]
			var offset: Vector2 = frame["offset"] - trail_direction * distance
			actor.draw_texture_rect_region(frame_texture, Rect2(offset, frame["size"]), frame["region"], Color(.58, .51, .92, alpha))
	var equipment_behind := current_direction in ["up", "up_left", "up_right"]
	if _shared_body and bool(frame.get("modular_equipment", false)) and equipment_behind:
		_draw_equipment(actor, frame)
	# O corpo v6 é exatamente o mesmo nas duas armas; lâminas são camadas próprias.
	var motion: Dictionary = frame["motion"]
	PixelMotion.draw_frame(actor, frame_texture, frame["offset"], frame["size"], frame["region"], frame["tint"], motion["upper_offset"], motion["middle_offset"])
	if _shared_body and bool(frame.get("modular_equipment", false)) and not equipment_behind:
		_draw_equipment(actor, frame)
	# A pose do poder não contém arco: usa o efeito dourado da quarta folha.
	var power_elapsed := float(frame["elapsed"])
	var effects: Array = _extras.get("slash_fx", [])
	if current_weapon == "espada" and current_state == "power" and power_elapsed >= .07 and power_elapsed < .34 and not effects.is_empty():
		var effect_index := int(effects[mini(effects.size() - 1, int((power_elapsed - .07) * 22.0))])
		if effect_index >= 0 and effect_index < _regions.size():
			var values: Array = _regions[effect_index]
			var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
			actor.draw_texture_rect_region(_texture, Rect2(-_pivot * _scale, _canvas * _scale), region, Color(1, 1, 1, .9))
	return true


## Também permite verificar a seleção visual sem chamar métodos de desenho.
func sample(actor: Node2D) -> Dictionary:
	var now := float(actor.get("_time"))
	var distance := float(actor.get("_visual_distance"))
	var dead := bool(actor.get("dead"))
	var hurt := float(actor.get("_hurt_visual"))
	var dodge := float(actor.get("_dodge_timer"))
	var parry := float(actor.get("parry_timer"))
	var attack_visual := float(actor.get("_attack_visual"))
	var attack_timer := float(actor.get("attack_timer"))
	var weapon: Resource = actor.call("equipped_weapon")
	var category := str(weapon.get("category"))
	if _owner_id != actor.get_instance_id() or now < _last_time:
		_reset_observer(actor.get_instance_id(), now)
		_last_distance = distance
	if _previous_dead and not dead:
		_reset_observer(actor.get_instance_id(), now)
	if not _previous_weapon.is_empty() and category != _previous_weapon:
		# A troca conserva o passo, mas nunca retoma um golpe da outra arma.
		_attack_active = false
		_attack_interrupted = false
		_previous_attack = 0
	current_weapon = category
	_previous_weapon = category
	if attack_visual > _previous_attack + .0001:
		# O segundo contato das Adagas renova o brilho por .12 s. É parte do
		# mesmo golpe: reiniciar aqui fazia a animação saltar para a antecipação.
		var second_dagger_hit := current_weapon == "leve" and _attack_active and not _attack_interrupted and _attack_state == "attack_light" and attack_visual <= .1201 and now - _attack_started >= .12
		if not second_dagger_hit:
			_attack_state = "attack_light"
			_attack_visual_length = .19
			if attack_visual > .27:
				var power_active := current_weapon == "espada" and float(actor.get("_power_visual")) > 0 and float(actor.get("power_cooldown_remaining")) > 0
				_attack_state = "power" if power_active else "attack_heavy"
				_attack_visual_length = .34 if power_active else .36
			_attack_started = now - maxf(0, _attack_visual_length - attack_visual)
			_attack_duration = maxf(_attack_visual_length, attack_timer + now - _attack_started)
			_attack_active = true
			_attack_interrupted = false
	if hurt > _previous_hurt + .0001:
		_hurt_started = now - maxf(0, .22 - hurt)
		_attack_interrupted = true
	if dead and not _previous_dead:
		_death_started = now - maxf(0, .22 - hurt)
		_attack_interrupted = true
	if dodge > _previous_dodge + .0001:
		_dodge_window = float(actor.get("dodge_duration"))
		if bool(actor.get("_shadow_finish")):
			_dodge_window *= 1.4
		_dodge_started = now - maxf(0, _dodge_window - dodge)
	if parry > _previous_parry + .0001:
		_parry_started = now - maxf(0, float(actor.get("parry_window")) - parry)
	if attack_timer <= 0:
		_attack_active = false

	var state := "idle"
	var elapsed := 0.0
	_shadow_power = false
	_action_duration = .2
	var heading: Vector2 = actor.get("facing")
	if dead:
		state = "death"
		elapsed = now - _death_started
	elif hurt > 0:
		state = "hurt"
		elapsed = now - _hurt_started
		_action_duration = .22
	elif dodge > 0:
		_shadow_power = current_weapon == "leve" and bool(actor.get("_shadow_finish"))
		state = "power" if _shadow_power else "dodge"
		elapsed = now - _dodge_started
		_action_duration = _dodge_window
		heading = actor.get("_dodge_direction")
	elif parry > 0 or (float(actor.get("_power_visual")) > 0 and float(actor.get("_riposte_timer")) > 0 and attack_visual <= 0):
		state = "parry"
		elapsed = now - _parry_started
		_action_duration = float(actor.get("parry_window"))
	elif _attack_active and not _attack_interrupted:
		state = _attack_state
		elapsed = now - _attack_started
		heading = actor.get("_attack_direction")
	elif float(actor.get("_visual_speed")) > 8:
		state = "run" if bool(actor.get("is_sprinting")) else "walk"
	var previous_state := current_state
	if state != previous_state:
		_state_started = now
	current_state = state
	if state in ["idle", "walk", "run"]:
		elapsed = now - _state_started
	if not _ensure_assets() or not _select_weapon_variant():
		_last_time = now
		return {}
	_ensure_motion_assets()
	_previous_dead = dead
	_previous_hurt = hurt
	_previous_dodge = dodge
	_previous_parry = parry
	_previous_attack = attack_visual
	current_frame = -1

	var requested := _direction_name(heading)
	var clip := _resolve_clip(state, requested)
	if clip.is_empty():
		load_error = "Nenhum quadro válido para " + state + "."
		return {}
	var sequence: Array = clip["sequence"]
	var frame_durations: Array = clip.get("durations", _durations)
	if state in ["walk", "run"]:
		if previous_state not in ["walk", "run"]:
			gait_phase = 0
		# Post-collision travel keeps the stride grounded even while sliding along
		# a wall. Drawing twice in the same tick cannot advance the supporting leg.
		var reference_speed := 112.0 if state == "run" else 64.0
		var cycle_duration := maxf(.1, float(clip.get("cycle_duration", _sequence_duration(sequence, clip["fps"], frame_durations))))
		gait_phase = fposmod(gait_phase + maxf(0, distance - _last_distance) / (reference_speed * cycle_duration), 1.0)
	_last_distance = distance
	_last_time = now
	var frame_position := _sequence_position(state, sequence, maxf(0, elapsed), clip["fps"], clip["loop"], frame_durations)
	var frame_value: Variant = sequence[frame_position]
	if not (frame_value is int or frame_value is float):
		load_error = "Índice de quadro inválido."
		return {}
	current_frame = int(frame_value)
	var frame_regions: Array = clip.get("regions", _regions)
	if current_frame < 0 or current_frame >= frame_regions.size():
		load_error = "Quadro fora do atlas."
		current_frame = -1
		return {}
	var values: Array = frame_regions[current_frame]
	var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
	var alpha := 1.0
	if not dead and hurt <= 0 and float(actor.get("invulnerability_timer")) > 0 and fmod(now, .16) < .065:
		alpha = .62
	var tint := Color(1, 1, 1, alpha)
	if hurt > 0 and not dead:
		tint = Color(1.3, 1.1, .95, alpha)
	load_error = ""
	var frame := {"frame": current_frame, "state": state, "clip": current_clip, "direction": current_direction, "weapon": current_weapon, "region": region, "offset": -_pivot * _scale, "size": _canvas * _scale, "tint": tint, "elapsed": elapsed, "gait_phase": gait_phase, "frame_position": frame_position, "frame_count": sequence.size(), "texture": clip.get("texture", _texture), "texture_path": clip.get("texture_path", _texture.resource_path), "body_model_id": "senu_shared_body_v6" if _shared_body else "legacy", "modular_equipment": _shared_body}
	var selected := SwordView.sample(frame, _attack_duration) if _shared_body else frame
	selected["motion"] = _motion_sample(actor, state, maxf(0, elapsed))
	current_frame = int(selected["frame"])
	return selected


## Only the drawn upper body moves. Feet, shadow and physics remain at zero.
func _motion_sample(actor: Node2D, state: String, elapsed: float) -> Dictionary:
	var upper := Vector2.ZERO
	var middle := Vector2.ZERO
	var now := float(actor.get("_time"))
	if state == "idle":
		# A long exhale and a quiet pause, instead of a continuous floating bob.
		var breath := pow((sin(now * 1.8 - PI * .5) + 1.0) * .5, 1.4)
		upper.y = -roundf(breath * .8)
	elif state in ["walk", "run"]:
		var heading: Vector2 = actor.get("facing")
		var side := Vector2(-heading.y, heading.x * .7)
		var counterstep := sin(gait_phase * TAU)
		upper = (side * counterstep * (.85 if state == "walk" else 1.1)).round()
		middle = (side * -counterstep * .35).round()
	elif state == "hurt":
		var away: Vector2 = actor.get("_hurt_direction")
		var t := clampf(elapsed / .22, 0, 1)
		# Fast give at contact, then a slower return, independent of knockback.
		var recoil := (1.0 - t) * (1.0 - t)
		upper = (away * (2.0 * recoil)).round()
		middle = (away * (.7 * recoil)).round()
	elif state in ["attack_light", "attack_heavy", "power"] and not _shadow_power:
		var direction: Vector2 = actor.get("_attack_direction")
		direction = Vector2(direction.x, direction.y * .7)
		var impact := .075 if current_weapon == "leve" else .12
		if state == "attack_heavy": impact = .24
		if state == "power": impact = .15
		var weight := 1.4 if state == "attack_light" else 2.0
		var push := _attack_weight(elapsed, impact, _attack_duration, weight)
		if current_weapon == "leve" and state == "attack_light" and elapsed >= .11:
			push = _attack_weight(elapsed - .11, .06, _attack_duration - .11, 1.2)
		upper = (direction * push).round()
		middle = (direction * push * .3).round()
	return {"upper_offset": upper, "middle_offset": middle, "feet_offset": Vector2.ZERO}


func _attack_weight(elapsed: float, impact: float, duration: float, weight: float) -> float:
	var release := impact * .6
	if elapsed < release:
		return -smoothstep(0.0, release, elapsed) * .85
	if elapsed < impact:
		var t := clampf((elapsed - release) / maxf(.001, impact - release), 0, 1)
		return lerpf(-.85, weight, t * t)
	var settle := clampf((elapsed - impact) / maxf(.001, duration - impact), 0, 1)
	return weight * (1.0 - smoothstep(0.0, 1.0, settle))


func _reset_observer(owner_id: int, now: float) -> void:
	_owner_id = owner_id
	current_state = "idle"
	_state_started = now
	_death_started = now
	_hurt_started = now
	_dodge_started = now
	_parry_started = now
	_attack_started = now
	_attack_active = false
	_attack_interrupted = false
	_previous_dead = false
	_previous_hurt = 0
	_previous_dodge = 0
	_previous_parry = 0
	_previous_attack = 0
	_previous_weapon = ""
	gait_phase = 0
	_last_distance = 0
	_last_time = now


func _select_weapon_variant() -> bool:
	if _weapon_variants.is_empty():
		if current_weapon != "espada":
			load_error = "Variação das Adagas ainda não exportada."
			return false
		_clips = _base_clips
		_walk_cycle_duration = .5
		return true
	var variant: Variant = _weapon_variants.get(current_weapon)
	if not variant is Dictionary or not variant.get("clips") is Dictionary:
		load_error = "Variação visual ausente: " + current_weapon
		return false
	_clips = variant["clips"]
	var walk: Dictionary = _clips.get("walk", {})
	var directions: Dictionary = walk.get("directions", {})
	var sequence: Array = directions.get("down", [])
	_walk_cycle_duration = maxf(.1, float(walk.get("cycle_duration", _sequence_duration(sequence, maxf(.1, float(walk.get("fps", 16)))))))
	return true


func _direction_name(vector: Vector2) -> String:
	if vector.length_squared() < .001:
		return "down"
	return DIRECTIONS[posmod(roundi((PI * .5 - vector.angle()) / (PI * .25)), 8)]


func _resolve_clip(state: String, requested: String) -> Dictionary:
	var candidates: Array[String] = [state]
	if state == "power" and _shadow_power:
		candidates.push_front("dodge")
	elif state == "power":
		candidates.append("attack_heavy")
		candidates.append("attack_light")
	elif state == "death":
		candidates.append("hurt")
	elif state == "dodge":
		candidates.append("walk")
	elif state == "run":
		candidates.append("walk")
	if state != "idle":
		candidates.append("idle")
	for candidate in candidates:
		var definition: Variant = _clips.get(candidate)
		var motion := false
		if not _shared_body and candidate in ["walk", "run", "dodge"] and _motion_texture != null:
			var variant: Dictionary = _motion_variants.get(current_weapon, {})
			var motion_clips: Dictionary = variant.get("clips", {})
			if motion_clips.get(candidate) is Dictionary:
				definition = motion_clips[candidate]
				motion = true
		if not definition is Dictionary:
			continue
		var directions: Variant = definition.get("directions")
		if not directions is Dictionary:
			continue
		var direction := requested
		var sequence: Variant = directions.get(direction)
		if not sequence is Array or sequence.is_empty():
			var nearest_distance := 99
			var requested_index := DIRECTIONS.find(requested)
			for possible in DIRECTIONS:
				var available: Variant = directions.get(possible)
				if not available is Array or available.is_empty():
					continue
				var distance := absi(DIRECTIONS.find(possible) - requested_index)
				distance = mini(distance, 8 - distance)
				if distance < nearest_distance:
					nearest_distance = distance
					direction = possible
					sequence = available
		if not sequence is Array or sequence.is_empty():
			continue
		current_clip = candidate
		current_direction = direction
		var resolved := {"sequence": sequence, "fps": maxf(.1, float(definition.get("fps", 8))), "loop": bool(definition.get("loop", false))}
		if definition.has("cycle_duration"):
			resolved["cycle_duration"] = definition["cycle_duration"]
		if motion:
			resolved["texture"] = _motion_texture
			resolved["texture_path"] = _motion_texture_path
			resolved["regions"] = _motion_regions
			resolved["durations"] = _motion_durations
		return resolved
	return {}


func _sequence_position(state: String, sequence: Array, elapsed: float, fps: float, looping: bool, source_durations: Array = []) -> int:
	var count := sequence.size()
	if count <= 1:
		return 0
	if state in ["attack_light", "attack_heavy", "power"]:
		if not _shadow_power:
			var recovery_end := _attack_duration - minf(.04, _attack_duration * .14)
			if current_weapon == "leve" and state == "attack_light" and count >= 4:
				var first_contact := clampi(roundi((count - 1) * .3), 1, count - 2)
				var second_contact := clampi(roundi((count - 1) * .7), first_contact + 1, count - 1)
				return _anchored_frame(elapsed, [0.0, .075, .17, maxf(.18, recovery_end)], [0, first_contact, second_contact, count - 1])
			var impact := .075 if state == "attack_light" else (.24 if state == "attack_heavy" else .15)
			var contact := clampi(roundi((count - 1) * .65), 1, count - 1)
			return _anchored_frame(elapsed, [0.0, impact, maxf(impact + .01, recovery_end)], [0, contact, count - 1])
	# Alterações de duração feitas na linha do tempo do Pixelorama são preservadas.
	var durations: Array[float] = []
	var total := 0.0
	var available_durations := _durations if source_durations.is_empty() else source_durations
	for index in sequence:
		var duration := 1.0 / fps
		if int(index) >= 0 and int(index) < available_durations.size():
			duration = maxf(.001, float(available_durations[int(index)]))
		durations.append(duration)
		total += duration
	var cursor := fmod(elapsed, total) if looping and state == "idle" else elapsed
	if state in ["walk", "run"]:
		cursor = gait_phase * total
	elif state in ["dodge", "hurt", "parry"] or _shadow_power:
		cursor = elapsed / maxf(.001, _action_duration) * total
	for i in range(count):
		if cursor < durations[i]:
			return i
		cursor -= durations[i]
	return count - 1


func _sequence_duration(sequence: Array, fps: float, source_durations: Array = []) -> float:
	var total := 0.0
	var available_durations := _durations if source_durations.is_empty() else source_durations
	for index in sequence:
		total += maxf(.001, float(available_durations[int(index)])) if int(index) >= 0 and int(index) < available_durations.size() else 1.0 / fps
	return maxf(.001, total)


func _anchored_frame(elapsed: float, times: Array, positions: Array) -> int:
	for i in range(1, times.size()):
		if elapsed < float(times[i]):
			var ratio := clampf((elapsed - float(times[i - 1])) / maxf(.001, float(times[i]) - float(times[i - 1])), 0, 1)
			return int(floor(lerpf(float(positions[i - 1]), float(positions[i]), ratio)))
	return int(positions.back())


func _ensure_motion_assets() -> bool:
	if _shared_body:
		return false
	if _motion_texture != null:
		return true
	var now := Time.get_ticks_msec()
	if now < _next_motion_load_check:
		return false
	_next_motion_load_check = now + 750
	if not FileAccess.file_exists(MOTION_MANIFEST_PATH):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(MOTION_MANIFEST_PATH)) != OK or not parser.data is Dictionary:
		motion_load_error = "Manifesto de movimento inválido."
		return false
	var manifest: Dictionary = parser.data
	var canvas: Variant = manifest.get("canvas")
	var pivot: Variant = manifest.get("pivot")
	var regions: Variant = manifest.get("frame_regions")
	var durations: Variant = manifest.get("frame_durations", [])
	var variants: Variant = manifest.get("weapon_variants")
	if not canvas is Array or canvas.size() != 2 or not pivot is Array or pivot.size() != 2 or not regions is Array or regions.is_empty() or not durations is Array or not variants is Dictionary:
		motion_load_error = "Dados de movimento incompletos."
		return false
	if Vector2(float(canvas[0]), float(canvas[1])) != _canvas or Vector2(float(pivot[0]), float(pivot[1])) != _pivot or not is_equal_approx(float(manifest.get("game_scale", .26)), _scale):
		motion_load_error = "O movimento deve manter o canvas, o pivô e a escala do personagem."
		return false
	var path := str(manifest.get("texture", ""))
	if not path.begins_with("res://assets/sprites/") or path.contains("..") or not path.ends_with(".png") or not ResourceLoader.exists(path):
		motion_load_error = "Atlas de movimento ainda não importado."
		return false
	var texture := load(path) as Texture2D
	if texture == null:
		motion_load_error = "Não foi possível carregar o atlas de movimento."
		return false
	var size := texture.get_size()
	for region in regions:
		if not region is Array or region.size() != 4:
			motion_load_error = "Região de movimento inválida."
			return false
		if float(region[0]) < 0 or float(region[1]) < 0 or float(region[2]) <= 0 or float(region[3]) <= 0 or float(region[0]) + float(region[2]) > size.x or float(region[1]) + float(region[3]) > size.y:
			motion_load_error = "Quadro de movimento fora do atlas."
			return false
	for category in ["espada", "leve"]:
		var variant: Variant = variants.get(category)
		if not variant is Dictionary or not variant.get("clips") is Dictionary:
			motion_load_error = "Movimento ausente para " + category + "."
			return false
		for state in ["walk", "run", "dodge"]:
			var clip: Variant = variant["clips"].get(state)
			if not clip is Dictionary or not clip.get("directions") is Dictionary:
				motion_load_error = "Sequência de movimento ausente: " + category + "/" + state + "."
				return false
			for direction in DIRECTIONS:
				var sequence: Variant = clip["directions"].get(direction)
				if not sequence is Array or sequence.is_empty():
					motion_load_error = "Direção de movimento ausente."
					return false
				for index in sequence:
					if int(index) < 0 or int(index) >= regions.size():
						motion_load_error = "Índice de movimento fora do atlas."
						return false
	_motion_texture = texture
	_motion_texture_path = path
	_motion_regions = regions
	_motion_durations = durations
	_motion_variants = variants
	motion_load_error = ""
	return true


func _ensure_assets() -> bool:
	# O atlas compartilhado é a versão preferida. Depois de validado, cada
	# quadro reutiliza os dados em memória sem consultar o disco novamente.
	if _asset_manifest_path == SHARED_MANIFEST_PATH and _texture != null and not _base_clips.is_empty() and not _regions.is_empty():
		return true
	var manifest_path := SHARED_MANIFEST_PATH if FileAccess.file_exists(SHARED_MANIFEST_PATH) else (V4_MANIFEST_PATH if FileAccess.file_exists(V4_MANIFEST_PATH) else MANIFEST_PATH)
	if _texture != null and _asset_manifest_path == manifest_path and not _base_clips.is_empty() and not _regions.is_empty():
		return true
	var now := Time.get_ticks_msec()
	if now < _next_load_check:
		return false
	_next_load_check = now + 750
	if not FileAccess.file_exists(manifest_path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(manifest_path)) != OK or not parser.data is Dictionary:
		load_error = "Manifesto dos sprites inválido."
		return false
	var manifest: Dictionary = parser.data
	var path: String = manifest.get("texture", "res://assets/sprites/senu_v3.png")
	if not path.begins_with("res://assets/sprites/") or path.contains("..") or not path.ends_with(".png"):
		load_error = "Caminho do atlas inválido."
		return false
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return false
	var canvas: Variant = manifest.get("canvas")
	var pivot: Variant = manifest.get("pivot")
	var regions: Variant = manifest.get("frame_regions")
	var clips: Variant = manifest.get("clips")
	if not canvas is Array or canvas.size() != 2 or not pivot is Array or pivot.size() != 2 or not regions is Array or regions.is_empty() or not clips is Dictionary:
		load_error = "Dimensões ou sequências do atlas inválidas."
		return false
	var texture := load(path) as Texture2D
	if texture == null:
		load_error = "Atlas ainda não importado pelo Godot."
		return false
	var texture_size := texture.get_size()
	for region in regions:
		if not region is Array or region.size() != 4:
			load_error = "Região inválida no atlas."
			return false
		if float(region[0]) < 0 or float(region[1]) < 0 or float(region[2]) <= 0 or float(region[3]) <= 0 or float(region[0]) + float(region[2]) > texture_size.x or float(region[1]) + float(region[3]) > texture_size.y:
			load_error = "Região fora da imagem exportada."
			return false
	_canvas = Vector2(float(canvas[0]), float(canvas[1]))
	_pivot = Vector2(float(pivot[0]), float(pivot[1]))
	_scale = float(manifest.get("game_scale", .26))
	if _canvas.x <= 0 or _canvas.y <= 0 or _scale <= 0:
		load_error = "Escala inválida no atlas."
		return false
	_texture = texture
	_asset_manifest_path = manifest_path
	_regions = regions
	_base_clips = clips
	_weapon_variants = manifest.get("weapon_variants", {})
	_extras = manifest.get("extras", {})
	_durations = manifest.get("frame_durations", [])
	_shared_body = bool(manifest.get("modular_equipment", false))
	_frame_hands = manifest.get("frame_hands", [])
	_equipment = manifest.get("equipment", {})
	load_error = ""
	return true


func equipment_pose(actor: Node2D, frame: Dictionary, side: String = "right") -> Dictionary:
	if bool(frame.get("embedded_equipment", false)):
		return {}
	if not _shared_body or current_frame < 0 or current_frame >= _frame_hands.size() or current_state == "death":
		return {}
	var hands: Dictionary = _frame_hands[current_frame]
	var committed_attack := current_state in ["attack_light", "attack_heavy", "power"] and not _shadow_power
	if bool(hands.get("hidden_during_tuck", false)) or (not bool(hands.get(side + "_visible", false)) and not committed_attack):
		return {}
	if current_weapon == "espada" and side == "left":
		return {}
	var values: Array = hands.get(side, [192, 220])
	var hand := (Vector2(float(values[0]), float(values[1])) - _pivot) * _scale
	var motion: Dictionary = frame.get("motion", {})
	hand += PixelMotion.offset_at(hand.y, motion.get("upper_offset", Vector2.ZERO), motion.get("middle_offset", Vector2.ZERO))
	var direction: Vector2 = actor.get("_attack_direction") if current_state in ["attack_light", "attack_heavy", "power"] and not _shadow_power else actor.get("facing")
	var heading := Vector2(direction.x, direction.y * .7).angle()
	var angle := atan2(.9, direction.x * .45)
	if current_weapon == "espada":
		var carry_x := signf(direction.x - direction.y)
		if is_zero_approx(carry_x):
			carry_x = 1 if direction.x >= 0 else -1
		angle = atan2(.15 if current_state == "dodge" else .6, carry_x * .9)
	var elapsed := float(frame.get("elapsed", 0))
	if current_state in ["attack_light", "attack_heavy", "power"] and not _shadow_power:
		var impact := .075 if current_state == "attack_light" else (.24 if current_state == "attack_heavy" else .15)
		if current_weapon == "leve" and side == "left" and current_state == "attack_light":
			impact = .17
		var lead := clampf((elapsed - impact) / .1, -1, 1)
		angle = heading + lead * .72
	elif current_state == "parry":
		angle = heading + (-.35 if side == "right" else .35)
	var equipment: Dictionary = _equipment.get(current_weapon, {})
	return {"hand": hand, "angle": angle, "frame": int(equipment.get("frame", -1)), "base_angle": float(equipment.get("base_angle", 0)), "direction": direction}


func _draw_equipment(actor: Node2D, frame: Dictionary) -> void:
	for side in ["right", "left"]:
		var pose := equipment_pose(actor, frame, side)
		if pose.is_empty():
			continue
		var index := int(pose["frame"])
		if index < 0 or index >= _regions.size():
			continue
		var values: Array = _regions[index]
		var region := Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		actor.draw_set_transform(pose["hand"], float(pose["angle"]) - float(pose["base_angle"]), Vector2.ONE)
		actor.draw_texture_rect_region(_texture, Rect2(-_pivot * _scale, _canvas * _scale), region, frame["tint"])
		actor.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
