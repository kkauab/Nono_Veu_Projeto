extends SceneTree

const Sfx = preload("res://scripts/audio/sfx.gd")
const Banks = preload("res://scripts/audio/sfx_banks.gd")
const Ambient = preload("res://scripts/audio/ambient_audio.gd")
const Catalog = preload("res://scripts/world/port_life_catalog.gd")
const Life = preload("res://scripts/world/port_life.gd")
const Townsperson = preload("res://scripts/world/townsfolk.gd")
const Layout = preload("res://scripts/world/port_layout.gd")

var passed := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("--- TESTES DE SOM AMBIENTE E MENDIGO MÚSICO ---")
	_test_audio_assets()
	_test_audio_buses()
	_test_ambient_system()
	_test_beggar_npc()
	_test_beggar_interaction()

	print("\nAMBIENT & BEGGAR CHECKS: %d passed=%d failures=%s" % [passed + failures.size(), passed, str(failures)])
	quit(1 if not failures.is_empty() else 0)


func check(condition: bool, description: String) -> void:
	if condition:
		passed += 1
	else:
		failures.append(description)
		printerr("FALHA: ", description)


func _test_audio_assets() -> void:
	var paths := [
		"res://assets/audio/ambient/harbor_wind_loop.wav",
		"res://assets/audio/ambient/sanctuary_drone_loop.wav",
		"res://assets/audio/music/beggar_oud_melody.wav",
		"res://assets/audio/music/beggar_oud_riff.wav"
	]
	for path in paths:
		check(ResourceLoader.exists(path), "Arquivo de áudio existe: %s" % path)
		var stream := load(path) as AudioStream
		check(stream != null, "Stream carregável pelo Godot: %s" % path)
		if stream != null:
			check(stream.get_length() > 0.0, "Stream tem duração válida (> 0s): %s (%.2fs)" % [path, stream.get_length()])

	# Verifica presença no sfx_banks
	check(Banks.BANKS.has("beggar_blessing"), "Banco 'beggar_blessing' registrado em sfx_banks")
	check(Banks.BUS.get("beggar_blessing") == "Musica", "Banco 'beggar_blessing' mapeado para bus 'Musica'")


func _test_audio_buses() -> void:
	Sfx.ensure_buses()
	check(AudioServer.get_bus_index("SFX") >= 0, "Bus SFX existe no AudioServer")
	check(AudioServer.get_bus_index("Ambiente") >= 0, "Bus Ambiente existe no AudioServer")
	check(AudioServer.get_bus_index("Vozes") >= 0, "Bus Vozes existe no AudioServer")
	check(AudioServer.get_bus_index("Musica") >= 0, "Bus Musica existe no AudioServer")


func _test_ambient_system() -> void:
	var dummy_game := Node2D.new()
	var dummy_hero := Node2D.new()
	dummy_hero.name = "Player"
	dummy_hero.add_to_group("player")
	dummy_game.add_child(dummy_hero)
	dummy_game.set_meta("player", dummy_hero)

	root.add_child(dummy_game)
	var ambient := Ambient.build(dummy_game)
	if ambient.get_node_or_null("HarborWind") == null:
		ambient._ready()

	check(ambient != null, "VeilAmbient instanciado com sucesso")
	check(ambient.get_node_or_null("HarborWind") != null, "Player HarborWind criado")
	check(ambient.get_node_or_null("SanctuaryDrone") != null, "Player SanctuaryDrone criado")

	# Teste de distância: herói no Santuário da Primeira Palavra (0, 0)
	dummy_hero.position = Layout.iso(Vector2(0, 0))
	for _i in range(30):
		ambient._process(0.1)

	var sanctuary_player := ambient.get_node_or_null("SanctuaryDrone") as AudioStreamPlayer
	if sanctuary_player != null:
		check(sanctuary_player.volume_db > -30.0, "SanctuaryDrone sobe de volume perto do santuário (%.1f dB)" % sanctuary_player.volume_db)

	# Teste de distância: herói longe no mar / cais distante
	dummy_hero.position = Layout.iso(Vector2(80, 80))
	for _i in range(40):
		ambient._process(0.1)

	if sanctuary_player != null:
		check(sanctuary_player.volume_db < -40.0, "SanctuaryDrone atenua longe de templos (%.1f dB)" % sanctuary_player.volume_db)

	# Teste de atenuação em interiores e abertura
	var house_game := Node2D.new()
	house_game.set_script(load("res://scripts/world/port_demo.gd"))
	ambient.game = house_game
	house_game.inside_house = "merit"
	for _i in range(30):
		ambient._process(0.1)
	var wind_player := ambient.get_node_or_null("HarborWind") as AudioStreamPlayer
	if wind_player != null:
		check(wind_player.volume_db < -28.0, "HarborWind atenua dentro de interiores (%.1f dB)" % wind_player.volume_db)
	house_game.free()

	dummy_game.queue_free()


func _test_beggar_npc() -> void:
	# Verifica catálogo
	var beggar_def: Dictionary = {}
	for def in Catalog.TOWNSFOLK:
		if def.get("id") == "mendigo_alaude":
			beggar_def = def
			break

	check(not beggar_def.is_empty(), "Mendigo das Cordas catalogado em TOWNSFOLK")
	check(beggar_def.get("title") == "Mendigo das Cordas", "Título correto do mendigo")
	check(beggar_def.get("lines", []).size() >= 4, "Mendigo possui pelo menos 4 falas temáticas de história")

	# Instancia o mendigo como Townsfolk com paradas configuradas ANTES de entrar na árvore
	var beggar := Townsperson.new()
	beggar.item_id = beggar_def["id"]
	beggar.kind = "townsfolk"
	beggar.look = Catalog.LOOKS.find(beggar_def["look"])
	beggar.title = beggar_def["title"]
	beggar.lines = beggar_def["lines"]

	var route: Array = beggar_def["route"]
	for stop in route:
		beggar.stops.append({"at": Layout.iso(stop[0]), "act": stop[1], "time": float(stop[2])})

	root.add_child(beggar)
	if not beggar.is_node_ready():
		beggar._ready()

	# Corpo v3: toca de pé, na pose de repouso (respira e pisca); a 11 é curvar-se até o chão.
	check(beggar.is_playing(), "Mendigo começa a rotina tocando o alaúde")
	check(beggar.pose() in [0, 12, 13], "Pose do mendigo tocando é a de repouso v3 (pose %d)" % beggar.pose())
	var poses_seen := {}
	for step in range(60):
		beggar.time = step * .1
		poses_seen[beggar.pose()] = true
	check(poses_seen.has(0) and poses_seen.has(12) and poses_seen.has(13), "Mendigo respira e pisca enquanto toca")
	# Bojo do alaúde à altura das mãos do corpo v3 (pivô 32,58, ~44 px), na frente da barriga.
	var oud: Vector2 = Townsperson.OUD_CENTER
	check(oud.y <= -16.0 and oud.y >= -26.0 and oud.x >= 0.0 and oud.x <= 10.0, "Alaúde no colo do corpo v3 (%s)" % str(oud))
	check(Townsperson.PIVOT == Vector2(32, 58), "Mendigo usa o pivô da folha v3")
	check(beggar.get_node_or_null("OudMusic2D") != null, "Mendigo possui player 2D de alaúde OudMusic2D")

	var oud_player := beggar.get_node_or_null("OudMusic2D") as AudioStreamPlayer2D
	if oud_player != null:
		check(oud_player.bus == "Musica", "OudMusic2D configurado no bus Musica")
		check(oud_player.max_distance > 300.0, "OudMusic2D possui alcance sonoro posicional (%.1f px)" % oud_player.max_distance)
		check(oud_player.process_mode == Node.PROCESS_MODE_PAUSABLE, "OudMusic2D respeita pausa e abertura cinemática")

	beggar.queue_free()


func _test_beggar_interaction() -> void:
	var hud_script = preload("res://scripts/ui/game_hud_v6.gd")
	var hud := hud_script.new()
	var portrait: Texture2D = hud._find_npc_portrait("Mendigo das Cordas")
	check(portrait != null, "Retrato de diálogo para 'Mendigo das Cordas' encontrado com sucesso")
	hud.free()
