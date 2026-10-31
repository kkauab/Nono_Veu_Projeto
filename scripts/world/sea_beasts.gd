extends RefCounted

## Bichos do mar (docs/MUNDO_BARCO_ILHA.md): crocodilos do Nilo e o maior deles,
## o crocodilo de Sobek. Espreitam perto de casa, quase submersos; quando Senu
## passa de barco ou cai na água, vão atrás, dão o bote e mordem: no barco, o casco
## (sea_boat.gd `damage`, que avisa quando cede); na água, o próprio Senu.
## Não sobem em terra (colidem com as bordas dos tiles, como o barco), não entram
## na água em volta dos píeres e desistem longe de casa ou quando Senu sai do mar.
## Não são inimigos do porto: não estão no grupo "enemies" nem tocam enemy.gd.

const Swim = preload("res://scripts/world/sea_swim.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const SeaArt = preload("res://scripts/world/sea_art.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const SHEET := "sea_beasts_v1"
## Casas em tiles, em mar aberto: longe das bordas, dos píeres e das rotas do porto.
## O de Sobek fica entre o recife e o Íbis, onde o mar já é de ninguém.
const HOMES := [
	{"id": "croc_baia", "kind": "croc", "home": Vector2(36, 52)},
	{"id": "croc_rochedos", "kind": "croc", "home": Vector2(57, 55)},
	{"id": "croc_bennu", "kind": "croc", "home": Vector2(30, 62)},
	{"id": "croc_leste", "kind": "croc", "home": Vector2(76, 53)},
	{"id": "croc_ibis", "kind": "croc", "home": Vector2(18, 58)},
	{"id": "sobek_mar_aberto", "kind": "sobek", "home": Vector2(60, 76)},
]
const STATS := {
	"croc": {"name": "Crocodilo do Nilo", "stalk": 88.0, "burst": 150.0, "hull": 20, "bite": 10, "aggro": 210.0, "radius": 7.0},
	"sobek": {"name": "Crocodilo de Sobek", "stalk": 82.0, "burst": 142.0, "hull": 34, "bite": 16, "aggro": 250.0, "radius": 9.0},
}
## Longe de Senu além disto, o bicho dorme (não processa).
const WAKE := 1150.0
## Corrente de casa: além disto, desiste e volta.
const LEASH := 620.0
## A água em volta de cada píer é segura: dá para embarcar e atracar.
const SAFE := 130.0
## Distância do bote: à lateral do casco (HULL_SIDE do centro do barco) e ao nadador.
const REACH_BOAT := 14.0
const HULL_SIDE := 24.0
const REACH_SWIMMER := 18.0
const COOLDOWN := 2.3
const BITE_TIME := .5
const BITE_HIT := .28
const RETREAT := 1.1
const BURST_TIME := .8
const TURN_RATE := 5.0


static func build(game, safe_points: PackedVector2Array) -> void:
	for definition in HOMES:
		var beast := Beast.new()
		beast.name = definition["id"]
		beast.beast_id = definition["id"]
		beast.kind = definition["kind"]
		beast.game = game
		beast.home = Layout.iso(definition["home"])
		beast.safe_points = safe_points
		beast.position = beast.home
		beast.add_to_group("sea_beasts")
		game.actors.add_child(beast)


## Todos voltam para casa (Senu voltou ao santuário).
static func reset(game) -> void:
	for beast in game.get_tree().get_nodes_in_group("sea_beasts"):
		beast.go_home()


class Beast extends CharacterBody2D:
	var beast_id := ""
	var kind := "croc"
	var game: Node
	var home := Vector2.ZERO
	var safe_points := PackedVector2Array()
	var state := "lurk"
	## Proa no plano do chão (0 aponta para a direita da tela), como sea_boat.gd.
	var heading := 0.0
	var cooldown := 0.0
	var bite_time := 0.0
	var bitten := false
	var retreat_time := 0.0
	var burst_time := 0.0
	var _clock := 0.0
	var _draw_tick := 0.0

	func _ready() -> void:
		collision_layer = 0
		collision_mask = 1
		motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var shape := CircleShape2D.new()
		shape.radius = float(STATS[kind]["radius"])
		var body := CollisionShape2D.new()
		body.shape = shape
		add_child(body)
		_clock = fposmod(position.x * .013 + position.y * .007, 6.0)
		heading = fposmod(position.x * .021, TAU)

	func go_home() -> void:
		position = home
		velocity = Vector2.ZERO
		state = "lurk"
		cooldown = 0.0
		burst_time = 0.0

	## O alvo: o barco com Senu remando, ou Senu nadando; com o que mede o bote.
	func target() -> Array:
		if not is_instance_valid(game):
			return []
		if game.at_sea and not game.sea_busy and is_instance_valid(game.boat) and game.boat.rider != null:
			return [game.boat, REACH_BOAT, "boat"]
		# Mergulhado (sea_dive.gd), Senu some do faro deles.
		if Swim.active(game) and not game.sea_busy and not game.player.dead and not bool(game.get_meta("diving", false)):
			return [game.player, REACH_SWIMMER, "swimmer"]
		return []

	func is_safe(point: Vector2) -> bool:
		for safe in safe_points:
			if point.distance_to(safe) < SAFE:
				return true
		return false

	func _physics_process(delta: float) -> void:
		_clock += delta
		cooldown = maxf(0.0, cooldown - delta)
		if is_instance_valid(game) and game.player != null and global_position.distance_to(game.player.global_position) > WAKE and state == "lurk":
			_draw_tick += delta
			if _draw_tick >= .25:
				_draw_tick = 0.0
				queue_redraw()
			return
		think(delta)

	## Um passo do bicho. Separado de _physics_process para os testes avançarem o tempo.
	func think(delta: float) -> void:
		var stats: Dictionary = STATS[kind]
		var aim := target()
		var prey: Node2D = aim[0] if not aim.is_empty() else null
		# No barco, o bicho vai à lateral do casco, do lado em que está, e não ao centro.
		var spot := Vector2.ZERO
		if prey != null:
			spot = prey.global_position
			if aim[2] == "boat":
				spot += (global_position - prey.global_position).normalized() * HULL_SIDE
		var gap := global_position.distance_to(spot) if prey != null else INF
		var wanted := Vector2.ZERO
		match state:
			"lurk":
				# Ronda devagar um círculo em volta de casa.
				var around := home + Vector2(cos(_clock * .18), sin(_clock * .18) * .5) * 46.0
				wanted = (around - global_position).limit_length(1.0) * 20.0
				if prey != null and gap < float(stats["aggro"]) and not is_safe(prey.global_position) and global_position.distance_to(home) < LEASH:
					state = "stalk"
			"stalk":
				if prey == null or is_safe(prey.global_position) or global_position.distance_to(home) > LEASH:
					state = "return"
				else:
					burst_time = maxf(0.0, burst_time - delta) if gap > 80.0 else burst_time + delta
					var speed: float = stats["burst"] if gap < 80.0 and burst_time < BURST_TIME else stats["stalk"]
					wanted = (spot - global_position).normalized() * speed
					if gap < float(aim[1]) and cooldown <= 0.0:
						state = "bite"
						bite_time = 0.0
						bitten = false
			"bite":
				bite_time += delta
				if prey != null and bite_time < BITE_HIT:
					wanted = (spot - global_position).normalized() * float(stats["burst"])
				if not bitten and bite_time >= BITE_HIT:
					bitten = true
					if prey != null and gap < float(aim[1]) * 1.5:
						_bite(aim, stats)
				if bite_time >= BITE_TIME:
					state = "retreat"
					retreat_time = RETREAT
					cooldown = COOLDOWN
					burst_time = 0.0
			"retreat":
				retreat_time -= delta
				if prey != null:
					wanted = (global_position - prey.global_position).normalized() * float(stats["stalk"]) * .7
				if retreat_time <= 0.0:
					state = "stalk" if prey != null else "return"
			"return":
				wanted = (home - global_position).limit_length(1.0) * 70.0
				if global_position.distance_to(home) < 24.0:
					state = "lurk"
				elif prey != null and gap < float(stats["aggro"]) * .6 and not is_safe(prey.global_position) and global_position.distance_to(home) < LEASH * .8:
					state = "stalk"
		# No bote, a boca aparece por cima da borda do barco.
		z_index = 1 if state == "bite" else 0
		# Só se dá ré no recuo; no resto o corpo segue a proa.
		velocity = velocity.move_toward(Vector2(wanted.x, wanted.y * .7), 420.0 * delta)
		move_and_slide()
		if velocity.length() > 8.0 and state != "retreat":
			heading = rotate_toward(heading, atan2(velocity.y * 2.0, velocity.x), TURN_RATE * delta)
		queue_redraw()

	func _bite(aim: Array, stats: Dictionary) -> void:
		var prey: Node2D = aim[0]
		if aim[2] == "boat":
			prey.damage(int(stats["hull"]), global_position)
		else:
			prey.receive_hit(int(stats["bite"]), global_position)
		if Sfx.has_bank("water_splash"):
			Sfx.play(self, "water_splash", global_position, -8.0, randf_range(.8, .95))

	func pose() -> String:
		match state:
			"bite":
				return "bite"
			"lurk":
				return "lurk"
		return "swim"

	func _draw() -> void:
		var moving := velocity.length() > 10.0
		# Corpo escuro sob a água, ao longo da proa, e o rastro em V quando nada.
		var length := 22.0 if kind == "croc" else 28.0
		var outline := PackedVector2Array()
		for step in range(16):
			var angle := step * TAU / 16.0
			var u := cos(angle) * length
			var v := sin(angle) * 6.0
			outline.append(Vector2(u * cos(heading) - v * sin(heading), (u * sin(heading) + v * cos(heading)) * .5 + 2.0))
		draw_colored_polygon(outline, Color(.01, .05, .06, .38 if state != "lurk" else .22))
		if moving:
			var back := Vector2(-cos(heading), -sin(heading) * .5)
			var side := Vector2(-sin(heading), cos(heading) * .5)
			for wave in range(3):
				var age := fposmod(_clock * 1.6 + wave * .33, 1.0)
				var tail := back * (length * .6 + age * 18.0)
				var spread := side * (4.0 + age * 10.0)
				var tint := Color(.86, .94, .9, .4 * (1.0 - age))
				draw_line(tail + spread, tail + spread * .3 + back * 4.0, tint, 1)
				draw_line(tail - spread, tail - spread * .3 + back * 4.0, tint, 1)
		var direction := posmod(roundi(heading / (TAU / 8.0)), 8)
		var name := "%s_%s_%d" % [kind, pose(), direction]
		var frame := 0
		if state == "bite":
			frame = 0 if bite_time < BITE_HIT else 1
		else:
			frame = int(_clock * (6.0 if pose() == "swim" else 2.0))
		var bob := roundf(sin(_clock * 1.9 + position.x * .01) * .6)
		if not SeaArt.draw_frame(self, SHEET, name, frame % maxi(1, SeaArt.frame_count(SHEET, name)), Vector2(0, bob)):
			draw_circle(Vector2.ZERO, 5.0, Color("5a623e"))
		if state == "bite" and bite_time >= BITE_HIT and bite_time < BITE_HIT + .15:
			# Água espirrando no estalo da mordida.
			var head := Vector2(cos(heading), sin(heading) * .5) * length * .8
			for drop in range(7):
				var angle := drop * TAU / 7.0
				draw_rect(Rect2((head + Vector2(cos(angle) * 7.0, sin(angle) * 3.5 - 4.0)).floor(), Vector2(1, 1)), Color(.9, .97, .94, .85))
