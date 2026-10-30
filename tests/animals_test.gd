extends SceneTree

const Catalog = preload("res://scripts/world/animal_catalog.gd")
const AnimalLife = preload("res://scripts/world/animal_life.gd")
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
	print("--- TESTE DE ANIMAIS (CÃES E GATOS DO NONO VÉU) ---")

	# 1. Raças
	_check(Catalog.BREEDS.has("cat_black"), "Raça 'cat_black' deve existir no catálogo")
	_check(Catalog.BREEDS.has("cat_mau"), "Raça 'cat_mau' deve existir no catálogo")
	_check(Catalog.BREEDS.has("dog_tesem"), "Raça 'dog_tesem' deve existir no catálogo")
	_check(Catalog.BREEDS.has("dog_guard"), "Raça 'dog_guard' deve existir no catálogo")

	# 2. Textura gerada
	var tex := load("res://assets/world/animals_v1.png") as Texture2D
	_check(tex != null, "Textura 'animals_v1.png' deve carregar com sucesso")
	if tex != null:
		_check(tex.get_width() == 224 and tex.get_height() == 128, "Dimensões da folha devem ser 224x128 (7 poses x 4 raças de 32x32)")

	# 3. Validação dos Animais Catalogados
	var known_districts := {}
	for room in Layout.ROOMS:
		known_districts[room["id"]] = true

	var animal_ids := {}
	for a in Catalog.ANIMALS:
		var aid: String = a["id"]
		var breed: String = a["breed"]
		_check(not animal_ids.has(aid), "ID de animal deve ser único: " + aid)
		animal_ids[aid] = true
		_check(Catalog.BREEDS.has(breed), "Animal '%s' deve ter raça válida (%s)" % [aid, breed])
		_check(known_districts.has(a["district"]), "Distrito do animal '%s' deve existir no Layout (%s)" % [aid, a["district"]])

	# 4. Instanciação e Simulação
	var mock_game := MockGame.new()
	root.add_child(mock_game)
	var mock_actors := Node2D.new()
	mock_actors.y_sort_enabled = true
	mock_game.add_child(mock_actors)
	mock_game.actors = mock_actors

	var mock_player := Node2D.new()
	mock_player.position = Vector2(9999, 9999) # Longe
	mock_game.add_child(mock_player)
	mock_game.player = mock_player

	var animal_life := AnimalLife.build(mock_game)
	_check(animal_life != null, "AnimalLife deve instanciar com sucesso")
	_check(animal_life.animals.size() == Catalog.ANIMALS.size(), "Deve instanciar exatamente %d animais" % Catalog.ANIMALS.size())

	# Simular 60 quadros
	for f in range(60):
		animal_life._process(0.016)

	# Testar reação de um gato ao perigo
	var test_cat: AnimalLife.AnimalActor = null
	var test_dog: AnimalLife.AnimalActor = null
	for a in animal_life.animals:
		if a.breed_data["type"] == "cat" and test_cat == null:
			test_cat = a
		elif a.breed_data["type"] == "dog" and test_dog == null:
			test_dog = a

	_check(test_cat != null, "Deve haver pelo menos um gato instanciado")
	_check(test_dog != null, "Deve haver pelo menos um cão instanciado")

	if test_cat != null:
		test_cat._trigger_reaction(test_cat.position + Vector2(20, 0))
		_check(test_cat.state == AnimalLife.AnimalActor.State.REACT, "Gato deve entrar em estado REACT sob ameaça")

	# 5. Garantir que todos os animais ficam sempre em tiles válidos de chão (inclusive em fuga)
	var floor_catalog := Layout.tile_catalog()
	var all_on_ground := true
	for a in animal_life.animals:
		var home_tile := Vector2i((Layout.unproject(a.home_pos) + Vector2(0.5, 0.5)).floor())
		_check(floor_catalog.has(home_tile), "Posição inicial do animal '%s' deve estar em chão válido" % a.animal_id)
		a._trigger_reaction(a.position + Vector2(-18, 0))
		for _step in range(120):
			a.tick(0.05, null)
			var cur_tile := Vector2i((Layout.unproject(a.position) + Vector2(0.5, 0.5)).floor())
			if not floor_catalog.has(cur_tile):
				all_on_ground = false
	_check(all_on_ground, "Nenhum animal sai do chão válido durante caminhada ou fuga")

	_check_depth_and_pivot(animal_life)
	_check_threat_radius(animal_life, mock_game)
	_check_flee_direction(animal_life)
	_check_walk_animation(animal_life)
	_check_gives_up(animal_life)
	_check_culling(animal_life, mock_game)
	mock_game.free()

	print("ANIMAL CHECKS: %d passed=%d failures=%s" % [passed + failures.size(), passed, str(failures)])
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


func _find(life: AnimalLife, id: String) -> AnimalLife.AnimalActor:
	for a in life.animals:
		if a.animal_id == id: return a
	return null


## Ordenado pelos pés (antes o y_sort do próprio animal ordenava o corpo 6 px
## acima deles), pivô nos pés e escala inteira.
func _check_depth_and_pivot(life: AnimalLife) -> void:
	var image := Image.load_from_file(ProjectSettings.globalize_path(AnimalLife.TEXTURE_PATH))
	image.convert(Image.FORMAT_RGBA8)
	for row in range(4):
		for column in range(7):
			# Última linha colorida das patas no pivô (antes o gato sentado e o cão
			# deitado flutuavam 1 px); o contorno escuro logo abaixo.
			var lowest := -1
			var lowest_any := -1
			for y in range(32):
				for x in range(32):
					var c := image.get_pixel(column * 32 + x, row * 32 + y)
					if c.a8 > 0:
						lowest_any = y
						if not c.is_equal_approx(Color("14252c")): lowest = y
			_check(lowest == int(AnimalLife.PIVOT_OFFSET.y) and lowest_any <= int(AnimalLife.PIVOT_OFFSET.y) + 1, "Patas no pivô em todas as poses, sem flutuar (raça %d, pose %d: última linha %d/%d)" % [row, column, lowest, lowest_any])
	for a in life.animals:
		_check(not a.y_sort_enabled, "%s é ordenado como um nó só, pelos pés" % a.animal_id)
		_check(not a.body_sprite.centered and a.body_sprite.offset == -AnimalLife.PIVOT_OFFSET and a.body_sprite.position == Vector2.ZERO, "%s desenha as patas na posição do nó" % a.animal_id)
		_check(absf(a.body_sprite.scale.x) == 1.0 and a.body_sprite.scale.y == 1.0, "%s em escala inteira (pixels nítidos)" % a.animal_id)


## O raio de susto depende de como Senu se move; golpe longe não assusta ninguém.
func _check_threat_radius(life: AnimalLife, game: Node) -> void:
	var hero := MockPlayer.new()
	game.add_child(hero)
	var keep: Node2D = game.player
	game.player = hero
	var cat := _find(life, "cat_garden")
	var dog := _find(life, "dog_caravan")
	for a in [cat, dog]:
		a.state = AnimalLife.AnimalActor.State.SIT
		a.state_timer = 99.0
		a.position = a.home_pos
	# Golpe a 400 px: antes qualquer golpe a até 850 px fazia todos fugirem (e o
	# `is_attacking` lido nem existe no Senu, então na prática ninguém reagia).
	hero.position = cat.position + Vector2(400, 0)
	hero.attack_timer = 0.2
	life._process(0.05)
	_check(cat.state == AnimalLife.AnimalActor.State.SIT, "Golpe longe não assusta o gato")
	hero.position = cat.position + Vector2(60, 0)
	life._process(0.05)
	_check(cat.state == AnimalLife.AnimalActor.State.REACT, "Golpe perto assusta o gato")
	hero.attack_timer = 0.0
	# Andando a 50 px: o gato (65 px) se assusta, o cão (40 px) não.
	cat.state = AnimalLife.AnimalActor.State.SIT
	hero.velocity = Vector2(80, 0)
	hero.position = cat.position + Vector2(50, 0)
	life._process(0.05)
	_check(cat.state == AnimalLife.AnimalActor.State.REACT, "Senu andando a 50 px assusta o gato")
	hero.position = dog.position + Vector2(50, 0)
	life._process(0.05)
	_check(dog.state == AnimalLife.AnimalActor.State.SIT, "Senu andando a 50 px não assusta o cão")
	hero.velocity = Vector2.ZERO
	hero.position = dog.position + Vector2(20, 0)
	life._process(0.05)
	_check(dog.state == AnimalLife.AnimalActor.State.SIT, "Senu parado ao lado não assusta o cão")
	game.player = keep
	hero.free()


## Foge para longe de Senu (antes fugia para longe da casa, às vezes na direção dele).
func _check_flee_direction(life: AnimalLife) -> void:
	var cat := _find(life, "cat_garden")
	for side in [-1.0, 1.0]:
		cat.position = cat.home_pos
		cat._trigger_reaction(cat.position + Vector2(30.0 * side, 0))
		cat._pick_flee_target()
		_check(signf(cat.target_pos.x - cat.position.x) == -side, "Gato foge para o lado oposto ao de Senu (Senu à %s)" % ("direita" if side > 0 else "esquerda"))


## A pata acompanha o chão: andando, os quadros 2–5 se alternam; parado, não.
func _check_walk_animation(life: AnimalLife) -> void:
	var dog := _find(life, "dog_warehouse")
	dog.position = dog.home_pos
	dog.state = AnimalLife.AnimalActor.State.WALK
	var target := Vector2.INF
	for angle in range(0, 360, 30):
		var candidate: Vector2 = dog.home_pos + Vector2.RIGHT.rotated(deg_to_rad(angle)) * Vector2(1, .5) * 60.0
		if life.segment_free(dog.position, candidate):
			target = candidate
			break
	_check(target.is_finite(), "Há um passeio livre perto do cão do armazém")
	if not target.is_finite(): return
	dog.target_pos = target
	var frames := {}
	var frozen := 0
	for step in range(30):
		var before := dog.position
		var frame_before := dog.anim_frame
		dog.tick(0.05, null)
		if dog.state != AnimalLife.AnimalActor.State.WALK: break
		frames[dog.anim_frame] = true
		if dog.position.distance_to(before) > 0.1 and step > 3 and dog.anim_frame == frame_before and dog.stride_left > AnimalLife.STRIDE - dog.position.distance_to(before):
			frozen += 1
	_check(frames.size() >= 3, "Cão andando mostra a caminhada inteira (%d quadros)" % frames.size())
	_check(frames.keys().all(func(f): return f >= 2 and f <= 5), "Andando, só quadros de caminhada")


## Travado (destino do outro lado da água), desiste em vez de tremer na borda.
func _check_gives_up(life: AnimalLife) -> void:
	var cat := _find(life, "cat_fishmonger")
	cat.position = cat.home_pos
	cat.state = AnimalLife.AnimalActor.State.WALK
	cat.target_pos = cat.home_pos + Layout.iso(Vector2(0, 4)) - Layout.iso(Vector2.ZERO)
	var walked := 0
	for step in range(80):
		cat.tick(0.05, null)
		if cat.state != AnimalLife.AnimalActor.State.WALK: break
		walked += 1
	_check(cat.state == AnimalLife.AnimalActor.State.SIT, "Gato desiste do destino sobre a água (%d passos)" % walked)
	_check(walked < 80, "Desiste em menos de 4 s (%d passos de 0,05 s)" % walked)
	var floor_tiles := Layout.tile_catalog()
	_check(floor_tiles.has(Vector2i((Layout.unproject(cat.position) + Vector2(.5, .5)).floor())), "Gato continua no cais, fora da água")


## Longe de Senu nenhum animal processa; perto, só os do raio.
func _check_culling(life: AnimalLife, game: Node) -> void:
	var hero := MockPlayer.new()
	game.add_child(hero)
	var keep: Node2D = game.player
	game.player = hero
	hero.position = Layout.iso(Vector2(85, 13))
	var before := {}
	for a in life.animals:
		before[a] = [a.position, a.state, a.state_timer]
	for step in range(40):
		life._process(0.05)
	var frozen := true
	for a in life.animals:
		if before[a] != [a.position, a.state, a.state_timer]: frozen = false
	_check(frozen and life.awake_count() == 0, "Senu longe: nenhum animal processa (%d acordados)" % life.awake_count())
	hero.position = Layout.iso(Vector2(10, 1))
	life._process(0.05)
	_check(life.awake_count() > 0 and life.awake_count() < life.animals.size(), "Senu no cais: só os animais por perto processam (%d)" % life.awake_count())
	game.player = keep
	hero.free()
