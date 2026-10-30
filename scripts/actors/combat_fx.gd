extends Node2D
## Peso dos golpes: congelamento curto (hitstop), tremor da câmera, clarão no
## alvo, faíscas e sons. Senu chama as funções públicas nos momentos do golpe;
## os avisos sonoros dos inimigos vêm da observação dos seus estados.

const Sfx = preload("res://scripts/audio/sfx.gd")

enum Kind { SPARK, ASH, DUST, RING, STAR, STONE }
signal ground_impacted(at: Vector2, strength: float)

## Testes que medem tempo de jogo podem desligar o congelamento.
static var hitstop_enabled := true

## O tempo de jogo não para de todo: divisões por delta continuam seguras.
const HITSTOP_SCALE := .03
const SHAKE_PIXELS := 5.0
const ENEMY_LISTEN_RADIUS := 300.0
const MAX_HIT_SOUNDS_PER_FRAME := 2
const FLASH_SHADER := """shader_type canvas_item;
uniform vec4 flash_color : source_color = vec4(1.0, 0.97, 0.86, 1.0);
void fragment() {
	// Só o corpo opaco clareia; sombra e aviso de ataque mantêm a cor.
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, step(0.8, COLOR.a));
}"""

static var _base_time_scale := 1.0
static var _hitstop_until := 0

var _particles: Array[Dictionary] = []
var _flashes := {}
var _enemy_states := {}
var _flash_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _trauma := 0.0
var _kick := Vector2.ZERO
var _shake_clock := 0.0
var _applied_offset := Vector2.ZERO
var _shaken_camera: Camera2D
var _last_real := 0
var _sound_frame := -1
var _sounds_this_frame := 0


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	z_index = 4
	# Restaura o tempo e a câmera mesmo com o jogo pausado por um menu.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_last_real = Time.get_ticks_usec()
	var shader := Shader.new()
	shader.code = FLASH_SHADER
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = shader
	Sfx.pool_for(self)


func _exit_tree() -> void:
	end_hitstop()
	for id in _flashes.keys():
		_restore_flash(id)
	if is_instance_valid(_shaken_camera):
		_shaken_camera.offset -= _applied_offset
	_applied_offset = Vector2.ZERO


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var real_delta := minf(.1, float(now - _last_real) / 1000000.0)
	_last_real = now
	if _hitstop_until > 0 and now >= _hitstop_until:
		end_hitstop()
	for id in _flashes.keys():
		if not is_instance_valid(_flashes[id][0]) or now >= int(_flashes[id][2]):
			_restore_flash(id)
	_update_camera(real_delta)
	if get_tree().paused or _particles.is_empty():
		return
	_update_particles(delta)
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not get_tree().paused:
		_listen_to_enemies()


# --- eventos do combate --------------------------------------------------------

func swing(category: String, heavy: bool) -> void:
	if not is_inside_tree():
		return
	var bank := "swing_heavy" if heavy else ("swing_dagger" if category == "leve" else "swing_sword")
	Sfx.play(self, bank, _owner_position())


## Senu atingiu um inimigo vivo. `heavy` para golpes que atordoam.
func enemy_hit(enemy: Node2D, heavy: bool, killed: bool, quick: bool = false) -> void:
	if not is_inside_tree():
		return
	var boss := bool(enemy.get("is_boss"))
	var direction := (enemy.global_position - _owner_position()).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var contact := enemy.global_position + Vector2(0, -20.0 if boss else -15.0) - direction * 4.0
	# Dourado: aparece tanto no clarão branco do alvo quanto no piso.
	var spark := Color("ffc861")
	if killed:
		hitstop(.26 if boss else .1)
		shake(.8 if boss else .45, direction)
		flash(enemy, .09)
		_play_hit("hit_kill", contact, 3.0 if boss else 0.0, .85 if boss else 1.0)
		_burst(contact, direction, 12, spark, 1.0)
		_veil_fragments(enemy.global_position + Vector2(0, -14), 26 if boss else 16)
		_ring(enemy.global_position, 6.0, 30.0 if boss else 22.0, .32, Color("d9c9a3"))
		_dust(enemy.global_position, 6)
	elif heavy:
		hitstop(.075)
		shake(.32, direction)
		flash(enemy, .07)
		_play_hit("hit_heavy", contact)
		_burst(contact, direction, 9, spark, .9)
		_veil_fragments(contact, 4)
		_dust(enemy.global_position, 4)
	else:
		hitstop(.028 if quick else .045)
		shake(.16, direction)
		flash(enemy, .05)
		_play_hit("hit_light", contact, -1.5 if quick else 0.0, 1.08 if quick else 1.0)
		_burst(contact, direction, 5, spark, .7)
		_veil_fragments(contact, 2)
	_star(contact, 1.3 if heavy or killed else 1.0)


func parry(from_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var origin := _owner_position()
	var direction := (from_position - origin).normalized()
	var contact := origin + direction * 9.0 + Vector2(0, -16)
	hitstop(.11)
	shake(.3, -direction)
	Sfx.play(self, "parry", contact)
	_burst(contact, direction, 14, Color("ffe7a3"), 1.1, 1.9)
	_star(contact, 1.6)
	_ring(contact + Vector2(0, 16), 4.0, 26.0, .24, Color("f8d794"))


func player_hurt(from_position: Vector2, fatal: bool) -> void:
	if not is_inside_tree():
		return
	var origin := _owner_position()
	var direction := (origin - from_position).normalized()
	var contact := origin + Vector2(0, -15)
	hitstop(.2 if fatal else .07)
	shake(.85 if fatal else .5, direction)
	Sfx.play(self, "death" if fatal else "hurt", origin)
	_burst(contact, direction, 8, Color("d6806a"), .8)
	_ring(origin, 5.0, 18.0, .22, Color("c8705c"))


func dodge() -> void:
	if not is_inside_tree():
		return
	Sfx.play(self, "dodge", _owner_position())
	_dust(_owner_position(), 4)


func power(power_id: String) -> void:
	if not is_inside_tree():
		return
	var origin := _owner_position()
	if power_id == "passo_sombra":
		Sfx.play(self, "power_shadow", origin)
		_veil_fragments(origin + Vector2(0, -12), 10, Color("aaa9f0"))
	else:
		Sfx.play(self, "power_riposte", origin)
		_ring(origin, 8.0, 46.0, .3, Color("e8bd75"))

## Reuses the approved death/loot visual language for discoveries, without
## hitstop, camera shake, combat damage or reward logic.
func memory_restored(at: Vector2) -> void:
	if not is_inside_tree(): return
	_ring(at, 4.0, 28.0, .5, Color("dfc38c"))
	_veil_fragments(at + Vector2(0, -12), 10, Color("dfc38c"))
	_star(at + Vector2(0, -18), 1.0)

## Ground-contact extension of the approved impact/loot language. Ground
## position, projected shadow and ballistic height are kept separate.
func ground_impact(at: Vector2, strength: float = 1.0, direction: Vector2 = Vector2.RIGHT, source_id: int=0) -> void:
	if not is_inside_tree(): return
	var first:=_particles.size()
	var force := clampf(strength, .15, 2.0)
	var stone_count := 0
	for existing in _particles:
		if int(existing["kind"]) == Kind.STONE: stone_count += 1
	var count := mini(maxi(0, 72 - stone_count), roundi(7 + force * 11))
	for index in range(count):
		var angle := _rng.randf_range(0, TAU)
		var ground_speed := _rng.randf_range(12, 43) * (.7 + force * .4)
		var tint: Color = [Color("30332f"),Color("676557"),Color("a2987b"),Color("d6c6a5")][index % 4]
		var chip := _add(Kind.STONE, at, Vector2(cos(angle),sin(angle)*.5) * ground_speed,
			_rng.randf_range(.50,.90), tint, 3.0 if force >= 1 and index % 5 == 0 else (2.0 if index % 2 == 0 else 1.0))
		chip["height"] = 1.0
		chip["height_velocity"] = _rng.randf_range(58,110) * (.8 + force*.25)
		chip["bounced"] = false
	_dust(at, roundi(5 + force * 5))
	# Low, dense earth puffs make the contact read against the pale stone;
	# the small airborne chips remain separate from their ground shadows.
	for index in range(roundi(3 + force * 3)):
		var drift := Vector2.from_angle(_rng.randf_range(0,TAU))
		_add(Kind.DUST,at+Vector2(0,-1),Vector2(drift.x,drift.y*.5)*_rng.randf_range(18,40),
			_rng.randf_range(.22,.38),Color("514a3d",.65),3.0 if index%2 else 4.0)
	_ring(at, 3, 14 + force * 9, .18 + force * .04, Color("b6a17b", .6))
	if force >= .8:
		hitstop(.025 + force * .025)
		shake(.10 + force * .12, direction)
		_play_hit("hit_heavy", at, -2.0, .9)
	if source_id!=0:
		for i in range(first,_particles.size()):_particles[i]["source_id"]=source_id
	ground_impacted.emit(at, force)

func ground_dust(at: Vector2, count: int = 3, source_id: int=0) -> void:
	if not is_inside_tree():return
	var first:=_particles.size()
	_dust(at,clampi(count,0,16))
	if source_id!=0:
		for i in range(first,_particles.size()):_particles[i]["source_id"]=source_id

func clear_source(source_id: int) -> void:
	_particles=_particles.filter(func(p):return int(p.get("source_id",0))!=source_id)
	queue_redraw()


# --- ferramentas ---------------------------------------------------------------

func hitstop(seconds: float) -> void:
	if not hitstop_enabled or seconds <= 0.0:
		return
	var now := Time.get_ticks_usec()
	if _hitstop_until == 0:
		_base_time_scale = Engine.time_scale
	_hitstop_until = maxi(_hitstop_until, now + int(seconds * 1000000.0))
	Engine.time_scale = _base_time_scale * HITSTOP_SCALE


static func end_hitstop() -> void:
	if _hitstop_until == 0:
		return
	_hitstop_until = 0
	Engine.time_scale = _base_time_scale


static func is_hitstopping() -> bool:
	return _hitstop_until > 0


func shake(trauma: float, direction: Vector2 = Vector2.ZERO) -> void:
	_trauma = clampf(maxf(_trauma, trauma) + trauma * .15, 0.0, 1.0)
	_kick += direction.normalized() * trauma * 3.5


## O alvo fica branco por alguns instantes de tempo real.
func flash(target: CanvasItem, seconds: float) -> void:
	if not is_instance_valid(target):
		return
	var id := target.get_instance_id()
	if not _flashes.has(id):
		_flashes[id] = [target, target.material, 0]
		target.material = _flash_material
	_flashes[id][2] = maxi(int(_flashes[id][2]), Time.get_ticks_usec() + int(seconds * 1000000.0))


func particle_count() -> int:
	return _particles.size()


func _restore_flash(id: int) -> void:
	var entry: Array = _flashes[id]
	if is_instance_valid(entry[0]) and (entry[0] as CanvasItem).material == _flash_material:
		(entry[0] as CanvasItem).material = entry[1]
	_flashes.erase(id)


func _owner_position() -> Vector2:
	var owner_node := get_parent() as Node2D
	return owner_node.global_position if owner_node != null else global_position


func _play_hit(bank: String, at: Vector2, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	# Um golpe em grupo não vira uma parede de som.
	var frame := Engine.get_physics_frames()
	if frame != _sound_frame:
		_sound_frame = frame
		_sounds_this_frame = 0
	_sounds_this_frame += 1
	if _sounds_this_frame <= MAX_HIT_SOUNDS_PER_FRAME:
		Sfx.play(self, bank, at, volume_db, pitch)


func _listen_to_enemies() -> void:
	var listener := _owner_position()
	var states := {}
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Node2D:
			continue
		var id := enemy.get_instance_id()
		var state := int(enemy.get("state"))
		states[id] = state
		if enemy.has_meta("owns_attack_audio"):continue
		if state == int(_enemy_states.get(id, state)):
			continue
		var body := enemy as Node2D
		if body.global_position.distance_to(listener) > ENEMY_LISTEN_RADIUS:
			continue
		var boss := bool(enemy.get("is_boss"))
		# A preparação tem som próprio: o golpe pode ser ouvido antes de visto.
		if state == VeilEnemy.State.WINDUP:
			Sfx.play(self, "enemy_windup", body.global_position, 4.0 if boss else 0.0, .78 if boss else 1.0)
		elif state == VeilEnemy.State.STRIKE:
			Sfx.play(self, "swing_enemy", body.global_position, 4.0 if boss else 0.0, .72 if boss else 1.0)
	_enemy_states = states


func _update_camera(real_delta: float) -> void:
	var camera := get_viewport().get_camera_2d() if is_inside_tree() else null
	if camera != _shaken_camera:
		if is_instance_valid(_shaken_camera):
			_shaken_camera.offset -= _applied_offset
		_applied_offset = Vector2.ZERO
		_shaken_camera = camera
	if camera == null:
		return
	_trauma = maxf(0.0, _trauma - real_delta * 2.4)
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-real_delta * 16.0))
	_shake_clock += real_delta
	var amount := _trauma * _trauma * SHAKE_PIXELS
	var jitter := Vector2(sin(_shake_clock * 71.0) + sin(_shake_clock * 43.0) * .5, cos(_shake_clock * 59.0) + cos(_shake_clock * 37.0) * .5) * amount / 1.5
	# A pixel arte só desloca a câmera em pixels inteiros.
	var offset := (jitter + _kick).round()
	if offset != _applied_offset:
		camera.offset += offset - _applied_offset
		_applied_offset = offset


func _update_particles(delta: float) -> void:
	for index in range(_particles.size() - 1, -1, -1):
		var particle := _particles[index]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			_particles.remove_at(index)
			continue
		var velocity: Vector2 = particle["v"]
		match int(particle["kind"]):
			Kind.SPARK:
				velocity.y += 340.0 * delta
				velocity *= 1.0 - minf(1.0, 3.5 * delta)
			Kind.ASH:
				velocity.x += sin(float(particle["life"]) * 9.0 + float(particle["seed"])) * 40.0 * delta
				velocity *= 1.0 - minf(1.0, 1.2 * delta)
			Kind.DUST:
				velocity *= 1.0 - minf(1.0, 5.0 * delta)
			Kind.STONE:
				particle["height_velocity"] = float(particle["height_velocity"]) - 340.0 * delta
				particle["height"] = float(particle["height"]) + float(particle["height_velocity"]) * delta
				if float(particle["height"]) < 0:
					particle["height"] = 0.0
					if not bool(particle["bounced"]):
						particle["height_velocity"] = absf(float(particle["height_velocity"])) * .22
						particle["bounced"] = true
					else:
						particle["height_velocity"] = 0.0
					velocity *= .7
				velocity *= 1.0 - minf(1.0, 1.6 * delta)
		particle["v"] = velocity
		particle["p"] = (particle["p"] as Vector2) + velocity * delta


func _draw() -> void:
	for particle in _particles:
		var life := float(particle["life"]) / float(particle["max"])
		var color: Color = particle["color"]
		var at: Vector2 = particle["p"]
		match int(particle["kind"]):
			Kind.STONE:
				var height := float(particle["height"])
				color.a *= clampf(life * 2.0, 0.0, 1.0)
				draw_rect(Rect2(at.round(),Vector2(2,1)),Color(0,0,0,color.a*.24))
				var raised := (at + Vector2(0,-height)).round()
				draw_rect(Rect2(raised,Vector2.ONE * float(particle["size"])),color)
			Kind.SPARK:
				color.a *= clampf(life * 1.6, 0.0, 1.0)
				var velocity: Vector2 = particle["v"]
				if velocity.length() > 60.0:
					draw_line(at.round(), (at - velocity * .025).round(), color, 1.0)
				draw_rect(Rect2(at.round(), Vector2.ONE * float(particle["size"])), color)
			Kind.ASH, Kind.DUST:
				color.a *= clampf(life * 1.8, 0.0, 1.0)
				draw_rect(Rect2(at.round(), Vector2.ONE * float(particle["size"])), color)
			Kind.RING:
				var progress := 1.0 - life
				var radius := lerpf(float(particle["r0"]), float(particle["r1"]), 1.0 - pow(1.0 - progress, 3.0))
				color.a *= life
				draw_set_transform(at.round(), 0.0, Vector2(1, .5))
				draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, color, 1.0)
				draw_set_transform(Vector2.ZERO)
			Kind.STAR:
				var arm := roundf(float(particle["size"]) * (2.0 + 4.0 * life))
				var center := at.round()
				draw_line(center - Vector2(arm, 0), center + Vector2(arm, 0), color, 1.0)
				draw_line(center - Vector2(0, arm * .7), center + Vector2(0, arm * .7), color, 1.0)
				draw_rect(Rect2(center - Vector2.ONE, Vector2(3, 3)), Color.WHITE)


func _add(kind: Kind, at: Vector2, velocity: Vector2, life: float, color: Color, size: float = 1.0) -> Dictionary:
	var particle := {"kind": kind, "p": at, "v": velocity, "life": life, "max": life, "color": color, "size": size, "seed": _rng.randf() * TAU}
	_particles.append(particle)
	queue_redraw()
	return particle


func _burst(at: Vector2, direction: Vector2, count: int, color: Color, force: float, spread: float = 1.0) -> void:
	for i in range(count):
		var angle := direction.angle() + _rng.randf_range(-.85, .85) * spread
		var speed := _rng.randf_range(70.0, 170.0) * force
		var velocity := Vector2(cos(angle), sin(angle) * .7) * speed + Vector2(0, -_rng.randf_range(15.0, 55.0))
		var tint := color if i % 3 else Color.WHITE
		_add(Kind.SPARK, at, velocity, _rng.randf_range(.16, .32), tint, 2.0 if i < 2 else 1.0)


func _veil_fragments(at: Vector2, count: int, color: Color = Color("8e82a2")) -> void:
	for i in range(count):
		var velocity := Vector2(_rng.randf_range(-28.0, 28.0), -_rng.randf_range(12.0, 42.0))
		var tint: Color = [color, color.lightened(.45), color.darkened(.35)][i % 3]
		_add(Kind.ASH, at + Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-8.0, 6.0)), velocity, _rng.randf_range(.45, 1.0), tint, 2.0 if i % 4 == 0 else 1.0)


func _dust(at: Vector2, count: int) -> void:
	for i in range(count):
		var angle := _rng.randf_range(0.0, TAU)
		var velocity := Vector2(cos(angle), sin(angle) * .5) * _rng.randf_range(25.0, 55.0)
		_add(Kind.DUST, at + Vector2(0, -1), velocity, _rng.randf_range(.25, .45), Color(.55, .49, .4, .55), 2.0)


func _ring(at: Vector2, from_radius: float, to_radius: float, life: float, color: Color) -> void:
	var ring := _add(Kind.RING, at, Vector2.ZERO, life, color)
	ring["r0"] = from_radius
	ring["r1"] = to_radius


func _star(at: Vector2, size: float) -> void:
	_add(Kind.STAR, at, Vector2.ZERO, .07, Color("fffbe8"), size)
