extends RefCounted

## Senu na água (docs/MUNDO_BARCO_ILHA.md): quando o casco cede, ele cai no mar e
## nada até uma escada (sea_ladders.gd). Os controles normais ficam desligados
## (sem golpe, esquiva nem selo) e este módulo move o próprio corpo de Senu com a
## colisão dele: as bordas dos tiles, que seguram o barco no mar, seguram também
## o nadador. Ele fica escondido; SwimView desenha o mesmo sprite de Senu cortado
## na altura do peito, com anéis e respingos. O estado é a meta "swimming" do port_demo.

const Sfx = preload("res://scripts/audio/sfx.gd")
## Mesma escala vertical do movimento de Senu (player.gd).
const ISO_Y := .70
## Px/s: bem mais lento que a pé (80) e que os crocodilos; Shift dá braçadas fortes.
const SPEED := 48.0
const STROKE := 1.35
## Até onde se nada: a mesma caixa do barco.
const BOUNDS := Rect2(-3600, -2000, 7200, 5200)
## Distância do ponto de nado de uma escada em que dá para subir.
const LADDER_REACH := 26.0
## Altura da linha d'água no corpo de Senu, em pixels do canvas do sprite, acima do pé.
## Só para o desenho de reserva, quando a folha de nado não existe.
const WATERLINE := 108.0
## Poses de nado (tools/pixelorama/build_senu_swim_v1.gd), do Senu real: "surface"
## tem a linha d'água no pivô; "dive", o ponto do leito sob Senu.
const POSES := "res://assets/sprites/senu_swim_v1_manifest.json"
const POSE_DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
## Ciclos de braçada por segundo: nadando, com braçada forte e boiando parado.
const STROKES := 1.5
const STROKES_STRONG := 2.0
const STROKES_IDLE := .55
static var _poses: Dictionary = {}
static var _pose_texture: Texture2D


## Um quadro do ciclo de nado (`phase` de 0 a 1) na direção de `facing`, ou {}.
## "lying" diz se o corpo está deitado (todas as direções menos cima e baixo).
static func pose(mode: String, facing: Vector2, phase: float) -> Dictionary:
	if _pose_texture == null:
		if not FileAccess.file_exists(POSES):
			return {}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(POSES))
		if not parsed is Dictionary or not ResourceLoader.exists(str(parsed.get("texture", ""))):
			return {}
		_poses = parsed
		_pose_texture = load(str(_poses["texture"])) as Texture2D
		if _pose_texture == null:
			return {}
	var index := posmod(roundi(facing.angle() / (PI / 4.0)), 8)
	var clip: Dictionary = _poses.get("sprites", {}).get(mode + "_" + POSE_DIRECTIONS[index], {})
	var frames: Array = clip.get("frames", [])
	if frames.is_empty():
		return {}
	var frame := int(frames[mini(frames.size() - 1, int(fposmod(phase, 1.0) * frames.size()))])
	var columns := int(_poses["columns"])
	var size := Vector2(float(_poses["canvas"][0]), float(_poses["canvas"][1]))
	return {"texture": _pose_texture, "region": Rect2(Vector2(frame % columns, frame / columns) * size, size),
		"size": size, "offset": -Vector2(float(_poses["pivot"][0]), float(_poses["pivot"][1])), "lying": index != 2 and index != 6}


static func active(game) -> bool:
	return bool(game.get_meta("swimming", false))


static func view(game) -> Node2D:
	return game.actors.get_node_or_null("SenuNadando")


static func start(game, at: Vector2) -> void:
	var player: SenuPlayer = game.player
	player.global_position = at
	player.velocity = Vector2.ZERO
	player.controls_enabled = false
	player.visible = false
	game.set_meta("swimming", true)
	game.nearest = null
	var swimmer := view(game)
	if swimmer == null:
		swimmer = SwimView.new()
		swimmer.name = "SenuNadando"
		game.actors.add_child(swimmer)
	swimmer.player = player
	swimmer.global_position = at
	swimmer.splash = 1.0
	swimmer.strong = false
	if Sfx.has_bank("water_splash"):
		Sfx.play(player, "water_splash", at, -6.0)


static func stop(game) -> void:
	game.set_meta("swimming", false)
	var swimmer := view(game)
	if swimmer != null:
		swimmer.queue_free()
	_light_ladders(game, null)


## Um quadro na água. Devolve a escada escolhida quando Senu aperta E ao pé dela.
static func update(game, delta: float) -> Node2D:
	var player: SenuPlayer = game.player
	if player.dead:
		game.nearest = null
		return null
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var strong := InputMap.has_action("sprint") and Input.is_action_pressed("sprint")
	swim_step(game, input, strong, delta)
	var ladder := ladder_in_reach(game)
	_light_ladders(game, ladder)
	game.nearest = ladder
	if ladder != null and Input.is_action_just_pressed("interact"):
		return ladder
	return null


## Uma braçada. Separada do teclado para os testes poderem nadar.
static func swim_step(game, input: Vector2, strong: bool, delta: float) -> void:
	var player: SenuPlayer = game.player
	var motion := Vector2(input.x, input.y * ISO_Y) * SPEED * (STROKE if strong else 1.0) * delta
	if motion.length_squared() > 0.0001:
		player.move_and_collide(motion)
		player.facing = input.normalized()
	player.global_position = player.global_position.clamp(BOUNDS.position, BOUNDS.end)
	var swimmer := view(game)
	if swimmer != null:
		swimmer.global_position = player.global_position
		swimmer.moving = motion.length_squared() > 0.0001
		swimmer.strong = strong
		swimmer.queue_redraw()


static func ladder_in_reach(game) -> Node2D:
	var player: SenuPlayer = game.player
	var best: Node2D = null
	var gap := LADDER_REACH
	for ladder in game.get_tree().get_nodes_in_group("sea_ladders"):
		var distance := player.global_position.distance_to(ladder.water)
		if distance < gap:
			gap = distance
			best = ladder
	return best


static func _light_ladders(game, chosen: Node2D) -> void:
	for ladder in game.get_tree().get_nodes_in_group("sea_ladders"):
		var near: bool = active(game) and ladder.global_position.distance_to(game.player.global_position) < 420.0
		var lit: bool = ladder == chosen
		if ladder.active != near or ladder.highlighted != lit:
			ladder.active = near
			ladder.highlighted = lit
			ladder.queue_redraw()


## Senu nadando: a braçada de peito da folha de nado (cabeça e ombros acima d'água);
## sem a folha, o sprite de verdade dele (senu_supplied_view) cortado no peito.
class SwimView extends Node2D:
	var player: SenuPlayer
	var moving := false
	var strong := false
	var splash := 0.0
	var phase := 0.0
	var _clock := 0.0
	## Este próprio módulo, para a classe chamar `pose`.
	var _module: GDScript

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_module = load("res://scripts/world/sea_swim.gd")

	func _process(delta: float) -> void:
		_clock += delta
		phase = fposmod(phase + delta * ((STROKES_STRONG if strong else STROKES) if moving else STROKES_IDLE), 1.0)
		splash = maxf(0.0, splash - delta)
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(player):
			return
		var bob := roundf(sin(_clock * (5.0 if moving else 2.4)))
		# Sombra do corpo sob a água e anéis em volta do peito.
		draw_set_transform(Vector2(0, 2), 0, Vector2(1, .5))
		draw_circle(Vector2.ZERO, 10.0, Color(.01, .05, .06, .35))
		for ring in range(2 if moving else 1):
			var grow := fposmod(_clock * (1.4 if moving else .7) + ring * .5, 1.0)
			draw_arc(Vector2.ZERO, 8.0 + grow * 10.0, 0, TAU, 20, Color(.86, .94, .9, .45 * (1.0 - grow)), 1)
		draw_set_transform(Vector2.ZERO)
		if player.dead:
			# Afunda: só a mão e as bolhas.
			draw_circle(Vector2(0, -3 + bob), 2.0, Color("dbcfaa"))
			return
		var drawn := false
		var tint := Color(1.6, 1.3, 1.1) if player.get("_hurt_visual") > 0.0 else Color.WHITE
		var stroke: Dictionary = _module.pose("surface", player.facing, phase)
		if not stroke.is_empty():
			draw_texture_rect_region(stroke["texture"], Rect2(stroke["offset"], stroke["size"]), stroke["region"], tint)
			drawn = true
			bob = 0.0
		var supplied = player.get("_supplied_view")
		if not drawn and supplied != null and supplied.has_method("sample"):
			var frame: Dictionary = supplied.sample(player)
			if not frame.is_empty():
				var region: Rect2 = frame["region"]
				var size: Vector2 = frame["size"]
				var offset: Vector2 = frame["offset"]
				var scale := size.y / region.size.y
				var foot := -offset.y / scale
				var keep := clampf(foot - WATERLINE, 0.0, region.size.y)
				var source := Rect2(region.position, Vector2(region.size.x, keep))
				var target := Rect2(Vector2(offset.x, -keep * scale + bob), Vector2(size.x, keep * scale))
				draw_texture_rect_region(frame["texture"], target, source, tint)
				drawn = true
		if not drawn:
			draw_circle(Vector2(0, -8 + bob), 4.0, Color("a27d50"))
		# Linha d'água sobre o peito e respingos das braçadas.
		draw_line(Vector2(-7, bob), Vector2(7, bob), Color(.86, .94, .9, .7), 1)
		if moving or splash > 0.0:
			for side in [-1.0, 1.0]:
				var lift := absf(sin(_clock * 6.0 + side)) * 3.0
				draw_rect(Rect2(Vector2(side * 9.0, -1.0 - lift + bob).floor(), Vector2(1, 1)), Color(.9, .97, .94, .8))
		if splash > 0.0:
			for drop in range(6):
				var angle := drop * TAU / 6.0
				var reach := (1.0 - splash) * 16.0
				draw_rect(Rect2((Vector2(cos(angle) * reach, sin(angle) * reach * .5 - splash * 8.0)).floor(), Vector2(1, 1)), Color(.9, .97, .94, splash))
