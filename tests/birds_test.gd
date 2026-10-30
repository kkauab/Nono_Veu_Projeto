extends SceneTree

const Catalog = preload("res://scripts/world/bird_catalog.gd")
const BirdLife = preload("res://scripts/world/bird_life.gd")
const Layout = preload("res://scripts/world/port_layout.gd")

var passed := 0
var failures: Array[String] = []


func _check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(message)
		push_error("FALHA: " + message)


func _init() -> void:
	print("--- TESTE DE AVES E PAPAGAIOS (O Nono Véu) ---")

	# 1. Espécies
	_check(Catalog.SPECIES.has("parrot"), "Espécie 'parrot' deve existir no catálogo")
	_check(Catalog.SPECIES.has("seagull"), "Espécie 'seagull' deve existir no catálogo")
	_check(Catalog.SPECIES.has("falcon"), "Espécie 'falcon' deve existir no catálogo")
	_check(Catalog.SPECIES.has("heron"), "Espécie 'heron' deve existir no catálogo")

	# 2. Textura gerada
	var tex := load("res://assets/world/birds_v1.png") as Texture2D
	_check(tex != null, "Textura 'birds_v1.png' deve carregar com sucesso")
	if tex != null:
		_check(tex.get_width() == 160 and tex.get_height() == 128, "Dimensões da folha devem ser 160x128 (5 colunas x 4 linhas de 32x32)")

	# 3. Validação dos Poleiros
	var known_districts := {}
	for room in Layout.ROOMS:
		known_districts[room["id"]] = true

	var perch_ids := {}
	for perch in Catalog.PERCHES:
		var pid: String = perch["id"]
		_check(not perch_ids.has(pid), "ID do poleiro deve ser único: " + pid)
		perch_ids[pid] = true
		_check(known_districts.has(perch["district"]), "Distrito do poleiro '%s' deve existir no Layout (%s)" % [pid, perch["district"]])
		_check(perch["alt"] >= 0.0, "Altitude do poleiro '%s' deve ser >= 0" % pid)
		_check(perch["species"].size() > 0, "Poleiro '%s' deve aceitar pelo menos uma espécie" % pid)

	# 4. Validação das Aves Catalogadas
	for b in Catalog.BIRDS:
		var bid: String = b["id"]
		var sp: String = b["species"]
		_check(Catalog.SPECIES.has(sp), "Ave '%s' deve ter espécie válida (%s)" % [bid, sp])
		_check(perch_ids.has(b["home_perch"]), "Ave '%s' deve apontar para home_perch existente (%s)" % [bid, b["home_perch"]])

	# 5. Instanciação e Simulação de Voo
	var mock_game := MockGame.new()
	root.add_child(mock_game)
	var mock_actors := Node2D.new()
	mock_actors.y_sort_enabled = true
	mock_game.add_child(mock_actors)
	mock_game.actors = mock_actors

	var mock_player := Node2D.new()
	mock_player.position = Vector2(9999, 9999) # Longe para não assustar durante inicialização
	mock_game.add_child(mock_player)
	mock_game.player = mock_player

	var bird_life := BirdLife.build(mock_game)
	_check(bird_life != null, "BirdLife deve instanciar com sucesso")
	_check(bird_life.birds.size() == Catalog.BIRDS.size(), "Deve instanciar exatamente %d aves" % Catalog.BIRDS.size())

	# Simular 30 ticks de física/processamento
	for frame in range(60):
		bird_life._process(0.016)

	# Forçar decolagem de um papagaio e checar transição de estados
	var test_parrot: BirdLife.BirdActor = null
	for bird in bird_life.birds:
		if bird.species == "parrot":
			test_parrot = bird
			break

	_check(test_parrot != null, "Deve haver pelo menos um papagaio instanciado")
	if test_parrot != null:
		test_parrot.takeoff()
		_check(test_parrot.state == BirdLife.BirdActor.State.TAKEOFF, "Papagaio deve entrar em estado TAKEOFF após comando de decolagem")

		# Avançar tempo de voo para cruzeiro e pouso
		for frame in range(120):
			bird_life._process(0.05)

		_check(test_parrot.state in [BirdLife.BirdActor.State.CRUISE, BirdLife.BirdActor.State.LANDING, BirdLife.BirdActor.State.PERCHED], "Papagaio deve evoluir na curva de voo")

	_check_art_and_depth(bird_life)
	_check_flight_smooth(bird_life)
	_check_no_stacking(bird_life, mock_game)
	_check_fleeing(bird_life, mock_game, mock_player)
	_check_return_home(bird_life)
	mock_game.free()
	_check_threat_levels()
	_check_catalog_ground()
	_check_anchoring()

	print("BIRD CHECKS: %d passed=%d failures=%s" % [passed + failures.size(), passed, str(failures)])
	quit(1 if failures.size() > 0 else 0)


class MockGame extends Node2D:
	var actors: Node2D
	var player: Node2D


## Jogador de mentira com as propriedades que a fauna lê do Senu (player.gd).
class MockPlayer extends Node2D:
	var velocity := Vector2.ZERO
	var attack_timer := 0.0
	var is_sprinting := false


const Threat = preload("res://scripts/world/fauna_threat.gd")


## Pivô nos pés, escala inteira e profundidade: pousada entra na ordem por y
## (antes ficava em z 5 acima de tudo, até de Senu na frente do poleiro); em voo
## fica acima dos telhados; a sombra fica no chão, abaixo dos atores.
func _check_art_and_depth(bird_life: BirdLife) -> void:
	_check(bird_life.y_sort_enabled and bird_life.z_index == 0, "Aves entram na ordem por profundidade dos atores (z 0, y_sort)")
	var image := Image.load_from_file(ProjectSettings.globalize_path(BirdLife.TEXTURE_PATH))
	image.convert(Image.FORMAT_RGBA8)
	var ink := Color("14252c")
	var pivot := Vector2i(BirdLife.PIVOT_OFFSET)
	for row in range(4):
		for column in [0, 1]:
			# Pés na linha do pivô e nada do corpo abaixo deles (a cauda pode pender ao lado).
			var foot := image.get_pixel(column * 32 + pivot.x, row * 32 + pivot.y)
			var below := image.get_pixel(column * 32 + pivot.x, row * 32 + pivot.y + 2)
			_check(foot.a8 > 0 and not foot.is_equal_approx(ink), "Pés da ave pousada (linha %d, pose %d) no pivô" % [row, column])
			_check(below.a8 == 0, "Nada da ave abaixo dos pés (linha %d, pose %d)" % [row, column])
	for bird in bird_life.birds:
		_check(not bird.y_sort_enabled, "%s é ordenada como um nó só (o corpo erguido não tem ordem própria)" % bird.bird_id)
		_check(not bird.body_sprite.centered and bird.body_sprite.offset == -BirdLife.PIVOT_OFFSET, "%s desenha os pés no pivô da célula" % bird.bird_id)
		_check(absf(bird.body_sprite.scale.x) == 1.0 and bird.body_sprite.scale.y == 1.0, "%s em escala inteira (pixels nítidos)" % bird.bird_id)
		_check(not bird.shadow_node.z_as_relative and bird.shadow_node.z_index == -1, "%s projeta a sombra no chão, sob os atores" % bird.bird_id)


func _settle_all(bird_life: BirdLife) -> void:
	for bird in bird_life.birds:
		var perch: Dictionary = bird.target_perch if not bird.target_perch.is_empty() else bird.current_perch
		bird.setup_perch(perch)
		bird.idle_timer = 999.0


## Voo sem saltos: altitude contínua, z de voo, e sem trocar de lado a cada quadro.
func _check_flight_smooth(bird_life: BirdLife) -> void:
	_settle_all(bird_life)
	for bird in bird_life.birds:
		bird.takeoff()
		_check(bird.z_index == BirdLife.FLY_Z, "%s voa acima dos telhados (z %d)" % [bird.bird_id, bird.z_index])
		var last_alt := bird.altitude
		var max_jump := 0.0
		var flicker := 0
		var last_facing := bird.facing
		var last_flip := -1.0
		var steps := 0
		while bird.state != BirdLife.BirdActor.State.PERCHED and steps < 4000:
			bird.tick(1.0 / 60.0, null, Threat.STILL)
			max_jump = maxf(max_jump, absf(bird.altitude - last_alt))
			last_alt = bird.altitude
			if bird.facing != last_facing:
				# Virar numa curva é natural; virar de novo em menos de 0,4 s é tremida.
				if last_flip >= 0.0 and steps / 60.0 - last_flip < 0.4:
					flicker += 1
				last_flip = steps / 60.0
				last_facing = bird.facing
			steps += 1
		_check(bird.state == BirdLife.BirdActor.State.PERCHED, "%s pousa ao fim do voo" % bird.bird_id)
		_check(max_jump < 4.0, "%s sobe e desce sem saltos de altitude (maior passo %.1f px)" % [bird.bird_id, max_jump])
		_check(flicker == 0, "%s não fica trocando de lado no voo (%d trocas seguidas)" % [bird.bird_id, flicker])
		_check(bird.z_index == 0 and is_equal_approx(bird.altitude, float(bird.current_perch["alt"])), "%s pousada volta à ordem por profundidade, na altura do poleiro" % bird.bird_id)


## Duas aves nunca no mesmo poleiro (pousadas ou a caminho dele).
func _check_no_stacking(bird_life: BirdLife, mock_game: Node) -> void:
	var keep: Node2D = mock_game.player
	mock_game.player = null
	var stacked := 0
	var takeoffs := 0
	for bird in bird_life.birds:
		bird.idle_timer = randf_range(0.0, 3.0)
	var was_perched := {}
	for bird in bird_life.birds:
		was_perched[bird] = true
	for frame in range(6000):
		bird_life._process(0.05)
		var held := {}
		for bird in bird_life.birds:
			var perched := bird.state == BirdLife.BirdActor.State.PERCHED
			if was_perched[bird] and not perched:
				takeoffs += 1
			was_perched[bird] = perched
			var perch: Dictionary = bird.current_perch if perched else bird.target_perch
			var id: String = perch.get("id", "")
			if held.has(id):
				stacked += 1
			held[id] = true
	_check(stacked == 0, "Nenhum poleiro com duas aves em 5 minutos de voos (%d empilhamentos)" % stacked)
	_check(takeoffs > 40, "Aves pousam e decolam sozinhas ao longo do tempo (%d decolagens)" % takeoffs)
	mock_game.player = keep


func _check_fleeing(bird_life: BirdLife, mock_game: Node, old_player: Node2D) -> void:
	_settle_all(bird_life)
	var hero := MockPlayer.new()
	mock_game.add_child(hero)
	mock_game.player = hero
	var parrot: BirdLife.BirdActor = null
	for bird in bird_life.birds:
		if bird.bird_id == "parrot_garden_1": parrot = bird
	parrot.setup_perch(bird_life.perches_by_id["garden_palm_1"])
	var base: Vector2 = parrot.ground_pos
	var calm := parrot.altitude * BirdLife.ALTITUDE_CALM
	# Parado a 15 px além do raio: não assusta; andando, assusta.
	hero.position = base + Vector2(BirdLife.DIST_IDLE_FLEE + 15.0 - calm, 0)
	hero.velocity = Vector2.ZERO
	bird_life._process(0.05)
	_check(parrot.state == BirdLife.BirdActor.State.PERCHED, "Senu parado fora do raio não espanta a ave")
	hero.velocity = Vector2(80, 0)
	bird_life._process(0.05)
	_check(parrot.state != BirdLife.BirdActor.State.PERCHED, "Senu andando perto espanta a ave")
	_check(parrot.flee_from.is_finite(), "A ave lembra de onde veio o susto")
	if not parrot.target_perch.is_empty() and parrot.target_perch.get("id") != parrot.current_perch.get("id"):
		_check(parrot.target_perch["ground"].distance_to(hero.position) >= BirdLife.SAFE_LANDING, "A ave foge para um poleiro longe de Senu")
	# Atacar a distância (antes `is_attacking` não existia no Senu e o golpe não assustava).
	_settle_all(bird_life)
	parrot.setup_perch(bird_life.perches_by_id["garden_palm_1"])
	hero.velocity = Vector2.ZERO
	hero.position = base + Vector2(BirdLife.DIST_ATTACK_FLEE - 20.0 - calm, 0)
	bird_life._process(0.05)
	_check(parrot.state == BirdLife.BirdActor.State.PERCHED, "Senu parado longe não espanta a ave")
	hero.attack_timer = 0.2
	bird_life._process(0.05)
	_check(parrot.state != BirdLife.BirdActor.State.PERCHED, "O golpe de Senu espanta a ave a %d px" % int(BirdLife.DIST_ATTACK_FLEE - 20.0))
	hero.attack_timer = 0.0
	mock_game.player = old_player
	hero.free()
	_settle_all(bird_life)


## Fora de casa, a ave tende a voltar para o distrito dela.
func _check_return_home(bird_life: BirdLife) -> void:
	_settle_all(bird_life)
	var parrot: BirdLife.BirdActor = null
	for bird in bird_life.birds:
		if bird.bird_id == "parrot_garden_1": parrot = bird
	parrot.setup_perch(bird_life.perches_by_id["market_warehouse_2"])
	var home := 0
	# Sorteio fixo: com a média perto de 230 de 400, o limite antigo de 240 falhava em parte das rodadas.
	seed(20261030)
	for i in range(400):
		var next: Dictionary = bird_life.pick_next_perch(parrot)
		if next.get("district") == parrot.home_district: home += 1
	randomize()
	_check(home > 200,"Papagaio do jardim, fora de casa, volta ao jardim na maioria dos voos (%d de 400)" % home)


func _check_threat_levels() -> void:
	var hero := MockPlayer.new()
	_check(Threat.level(hero) == Threat.STILL, "Senu parado é STILL")
	hero.velocity = Vector2(80, 0)
	_check(Threat.level(hero) == Threat.WALK, "Passo normal de Senu (80 px/s) é WALK, não corrida")
	hero.velocity = Vector2(136, 0)
	_check(Threat.level(hero) == Threat.RUN, "Corrida de Senu (136 px/s) é RUN")
	hero.attack_timer = 0.1
	_check(Threat.level(hero) == Threat.ATTACK, "Golpe de Senu (attack_timer) é ATTACK")
	hero.free()


## Ave no chão (alt 0) só em tile de piso; acima do chão, sempre presa a uma peça.
func _check_catalog_ground() -> void:
	var floor_tiles := Layout.tile_catalog()
	for perch in Catalog.PERCHES:
		if not perch.has("prop"):
			_check(perch["alt"] == 0.0, "Poleiro '%s' sem peça fica no chão (alt 0, não flutua)" % perch["id"])
			_check(floor_tiles.has(Vector2i((Vector2(perch["tile"]) + Vector2(.5, .5)).floor())), "Poleiro '%s' no chão fica em piso, não na água" % perch["id"])
		var species_ok := true
		for sp in perch["species"]:
			if perch["district"] not in Catalog.SPECIES[sp]["districts"]: species_ok = false
		_check(species_ok, "Poleiro '%s' fica num distrito que as suas espécies visitam" % perch["id"])


## Poleiro preso à peça real (posição exata da peça, mesmo deslocada no mapa);
## sem a peça, desligado.
func _check_anchoring() -> void:
	var game := MockGame.new()
	root.add_child(game)
	var actors := Node2D.new()
	game.add_child(actors)
	game.actors = actors
	var palm := PortProp.new()
	palm.kind = "palm"
	palm.position = Layout.iso(Vector2(12.2, 21.1))
	actors.add_child(palm)
	var life := BirdLife.build(game)
	var perch: Dictionary = life.perches_by_id["garden_palm_1"]
	_check(perch["enabled"] and perch["ground"] == palm.position + perch["offset"], "Poleiro da palmeira segue a palmeira real")
	_check(not life.perches_by_id["market_arch"]["enabled"], "Poleiro sem a sua peça no mapa fica desligado")
	_check(life.perches_by_id["garden_shore_1"]["enabled"], "Poleiro no chão não depende de peça")
	for bird in life.birds:
		_check(bird.current_perch.is_empty() or bird.current_perch["enabled"], "%s começa num poleiro ligado" % bird.bird_id)
	game.free()
