extends Node2D

const Layout = preload("res://scripts/world/port_layout.gd")
const Hud = preload("res://scripts/ui/game_hud_v6.gd")
const Inputs = preload("res://scripts/core/input_bindings.gd")
const Dressing = preload("res://scripts/world/port_dressing.gd")
const Opening = preload("res://scripts/ui/opening_cutscene.gd")
const LEVER_FLAGS := {"alavanca": "shortcut", "alavanca_aqueduct": "aqueduct", "alavanca_eco": "echo"}
var store: DemoSaveStore
var player: SenuPlayer
var actors: Node2D
var hud: Control
var shortcut: PortGate
var exit_gate: PortGate
var aqueduct_gate: PortGate
var boss_entry_gate: PortGate
var echo_gate: PortGate
var boss: VeilEnemy
var nearest: PortInteractable
var current_room := "hub"
var respawning := false
var qa_mode := false
var checkpoints: Dictionary = {}
var layout: PortLayout
var world_view: SubViewport
var world_container: SubViewportContainer
var world_stage: Node2D
var opening_active := false
var _opening_player: Control
var _opening_layer: CanvasLayer

func _ready() -> void:
	Inputs.install()
	qa_mode = "--qa" in OS.get_cmdline_user_args()
	store = DemoSaveStore.new("user://qa/run_%d.json" % Time.get_ticks_usec() if qa_mode else "user://progress.json")
	store.load_progress()
	checkpoints = {"hub": Layout.MARKERS["hub_spawn"], "s1": Layout.MARKERS["s1"], "market_rest": Layout.MARKERS["market_rest"], "caravan_rest": Layout.MARKERS["caravan_rest"], "cistern_rest": Layout.MARKERS["cistern_rest"]}
	get_tree().auto_accept_quit = false
	_build_world_view()
	layout = Layout.new()
	world_stage.add_child(layout)
	actors = Node2D.new()
	actors.name = "DepthSortedWorld"
	actors.y_sort_enabled = true
	world_stage.add_child(actors)
	_build_objects()
	player = SenuPlayer.new()
	player.name = "Senu"
	player.position = Layout.iso(checkpoints[store.data["checkpoint"]])
	actors.add_child(player)
	_apply_upgrades(true)
	player.weapon_unlocked[1] = DemoSaveStore.WEAPONS[1] in store.data["weapons"]
	player.equip_weapon(DemoSaveStore.WEAPONS.find(store.data["equipped"]))
	player.stats_changed.connect(_stats_changed)
	player.died.connect(_on_player_died)
	player.combat_feedback.connect(_feedback)
	var camera := Camera2D.new()
	camera.name = "IsometricCamera"
	camera.position = Vector2(0, -20)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.zoom = Vector2.ONE
	player.add_child(camera)
	for enemy_data in Layout.ENEMY_SPAWNS:
		_spawn_enemy(enemy_data["id"], enemy_data["tile"], enemy_data.get("boss", false), enemy_data.get("archetype", "guard"))
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "Interface"
	add_child(ui_layer)
	hud = Hud.new()
	hud.game = self
	ui_layer.add_child(hud)
	if get_tree().has_meta("nono_autostart"):
		get_tree().remove_meta("nono_autostart")
		start_journey()
	elif not qa_mode:
		hud.show_overlay("intro")
	for capture_mode in ["--capture", "--capture-menu", "--capture-tree", "--capture-arena", "--capture-cais", "--capture-market", "--capture-garden", "--capture-map", "--capture-daggers", "--capture-bells", "--capture-oracle", "--capture-cistern", "--capture-caravan", "--capture-echo"]:
		if qa_mode and capture_mode in OS.get_cmdline_user_args():
			hud.show_overlay("")
			if capture_mode == "--capture-menu":
				hud.show_overlay("intro")
			elif capture_mode == "--capture-tree":
				store.data["fragments"] = 3
				hud.show_overlay("tree")
			elif capture_mode == "--capture-arena":
				player.reset_at(Layout.iso(Layout.MARKERS["capture_arena"]))
				current_room = "b1"
				camera.reset_smoothing()
			elif capture_mode == "--capture-daggers":
				player.weapon_unlocked[1] = true
				player.equip_weapon(1)
				player.reset_at(Layout.iso(Layout.MARKERS["capture_market"]))
				current_room = Layout.room_at(player.position)
				camera.reset_smoothing()
			elif capture_mode in ["--capture-cais", "--capture-market", "--capture-garden", "--capture-bells", "--capture-oracle", "--capture-cistern", "--capture-caravan", "--capture-echo"]:
				var marker: String = capture_mode.trim_prefix("--").replace("-", "_")
				player.reset_at(Layout.iso(Layout.MARKERS.get(marker, Layout.MARKERS["alavanca_aqueduct"])))
				current_room = Layout.room_at(player.position)
				camera.reset_smoothing()
			elif capture_mode == "--capture-map":
				for room_data in Layout.ROOMS:
					if room_data["id"] not in store.data["visited"]:
						store.data["visited"].append(room_data["id"])
				store.data["flags"]["shortcut"] = true
				store.data["flags"]["aqueduct"] = true
				store.data["flags"]["echo"] = true
				hud.show_overlay("map")
			_capture.call_deferred(capture_mode.trim_prefix("--capture"))

func _build_world_view() -> void:
	# The world keeps its pixel grid; the HUD renders in the full-size window.
	world_container = SubViewportContainer.new()
	world_container.name = "PixelWorldContainer"
	world_container.stretch = true
	world_container.stretch_shrink = 2
	world_container.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world_container.focus_mode = Control.FOCUS_NONE
	world_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(world_container)
	world_view = SubViewport.new()
	world_view.name = "PixelWorld"
	world_view.size = Vector2i(640, 360)
	world_view.disable_3d = true
	world_view.world_2d = World2D.new()
	world_view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world_view.snap_2d_transforms_to_pixel = true
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_container.add_child(world_view)
	world_stage = Node2D.new()
	world_stage.name = "PortWorld"
	world_view.add_child(world_stage)
	get_viewport().size_changed.connect(_resize_world_view)
	_resize_world_view()

func _resize_world_view() -> void:
	if world_container != null:
		world_container.size = get_viewport_rect().size

func world_to_ui(point: Vector2) -> Vector2:
	if world_view == null or world_container == null: return point
	var canvas_point := world_view.get_canvas_transform() * point
	return world_container.position + canvas_point * world_container.size / Vector2(world_view.size)

func _build_objects() -> void:
	Dressing.populate(actors)
	for id in checkpoints:
		_add_item(id, "shrine", Layout.MARKERS[id], "Meditar · restaurar e salvar")
	_add_item("inscricao", "inscription", Layout.MARKERS["inscricao"], "Ler a inscrição de Iri")
	for id in ["nous_cais", "nous_patio", "nous_arena", "nous_market", "nous_garden", "nous_dock", "nous_aqueduct", "nous_archive", "nous_kilns", "nous_beacon", "nous_reservoir", "nous_buried"]:
		_add_item(id, "nous", Layout.MARKERS[id], "Recolher Fragmento de Nous")
	_add_item("adagas", "daggers", Layout.MARKERS["adagas"], "Encontrar Adagas do Reverso")
	_add_item("alavanca", "lever", Layout.MARKERS["alavanca"], "Abrir o retorno ao santuário")
	_add_item("alavanca_aqueduct", "lever", Layout.MARKERS["alavanca_aqueduct"], "Destravar o aqueduto do mercado")
	_add_item("alavanca_eco", "lever", Layout.MARKERS["alavanca_eco"], "Erguer a grade do santuário")
	_add_item("selo", "gate", Layout.MARKERS["selo"], "Examinar o selo das Catacumbas")
	_add_item("memory_market", "memory", Layout.MARKERS["memory_market"], "Ler o registro do mercador")
	_add_item("memory_dock", "memory", Layout.MARKERS["memory_dock"], "Ler a memória do barqueiro")
	_add_item("cache", "cache", Layout.MARKERS["cache"], "Examinar o relicário da alcova")
	for id in ["bells_clue", "water_clue", "stars_clue", "memory_pilgrim", "memory_copper"]:
		_add_item(id, "clue", Layout.MARKERS[id], "Ler a inscrição da ordem")
	for id in ["bell_moon", "bell_sun", "bell_star"]:
		_add_item(id, "bell", Layout.MARKERS[id], "Tocar o sino")
	for id in ["valve_two", "valve_three", "valve_drain", "valve_reset"]:
		_add_item(id, "valve", Layout.MARKERS[id], "Operar a comporta")
	_add_item("water_altar", "water_altar", Layout.MARKERS["water_altar"], "Oferecer a maré ao santuário")
	for id in ["star_sun", "star_moon", "star_eye"]:
		_add_item(id, "dial", Layout.MARKERS[id], "Girar o obelisco")
	_add_item("stars_altar", "stars_altar", Layout.MARKERS["stars_altar"], "Verificar o alinhamento")
	_add_item("sealed_entry", "boss_lock", Layout.MARKERS["sealed_entry"], "Examinar a Porta das Três Lembranças")
	shortcut = _make_gate("shortcut", "shortcut")
	aqueduct_gate = _make_gate("aqueduct", "aqueduct")
	exit_gate = _make_gate("boss", "boss")
	boss_entry_gate = _make_gate("boss_entry", "boss")
	echo_gate = _make_gate("echo", "echo")
	refresh_seals()

func _make_gate(gate_id: String, flag: String) -> PortGate:
	var definition: Dictionary = Layout.GATES[gate_id]
	var a := Layout.iso(definition["a"])
	var b := Layout.iso(definition["b"])
	var gate := PortGate.new()
	gate.position = (a + b) * .5
	gate.end_a = a - gate.position
	gate.end_b = b - gate.position
	gate.opened = store.data["flags"].get(flag, false)
	actors.add_child(gate)
	return gate

func _add_item(id: String, kind: String, tile: Vector2, label: String) -> void:
	if id in store.data["collected"] and kind != "cache":
		return
	if LEVER_FLAGS.has(id) and store.data["flags"].get(LEVER_FLAGS[id], false):
		return
	var item := PortInteractable.new()
	item.item_id = id
	item.kind = kind
	item.label = label
	item.position = Layout.iso(tile)
	if kind == "cache" and id in store.data["collected"]:
		item.active = false
		item.opened = true
	actors.add_child(item)

func _spawn_enemy(id: String, tile: Vector2, is_boss: bool = false, archetype: String = "guard") -> void:
	if id in store.data["defeated"] or (is_boss and store.data["flags"]["boss"]):
		return
	var enemy := VeilEnemy.new()
	enemy.enemy_id = id
	enemy.is_boss = is_boss
	enemy.archetype = archetype
	enemy.target = player
	enemy.position = Layout.iso(tile)
	enemy.defeated.connect(_on_enemy_defeated)
	actors.add_child(enemy)
	if is_boss:
		boss = enemy

func _physics_process(_delta: float) -> void:
	if player == null or hud == null or respawning:
		return
	var room := Layout.room_at(player.position)
	if room != current_room or room not in store.data["visited"]:
		current_room = room
		if room not in store.data["visited"]:
			store.data["visited"].append(room)
			_save()
		if room == "a02" and not store.data["flags"]["complete"]:
			store.data["flags"]["complete"] = true
			_save()
			hud.show_dialog("O eco se abre", "O Porteiro caiu. Além deste limiar, as vozes das Catacumbas esperam por Senu.\n\nNesta demonstração, as Catacumbas ainda são uma área de teste. Ao norte, uma galeria estreita sobe na direção do santuário.")
	nearest = null
	var distance := 43.0
	for item in get_tree().get_nodes_in_group("interactables"):
		item.highlighted = false
		if not item.active:
			continue
		var candidate: float = player.position.distance_to(item.position)
		if candidate < distance:
			distance = candidate
			nearest = item
	if nearest != null:
		nearest.highlighted = true
	if Input.is_action_just_pressed("interact") and nearest != null:
		activate(nearest)

func activate(item: PortInteractable) -> bool:
	if not is_instance_valid(item) or not item.active or player.position.distance_to(item.position) > 44:
		return false
	match item.kind:
		"clue", "bell", "valve", "water_altar", "dial", "stars_altar", "boss_lock":
			return _activate_puzzle(item)
		"shrine":
			store.data["checkpoint"] = item.item_id
			player.heal_full()
			if _save():
				hud.toast("Memória ancorada · vida restaurada · progresso salvo")
		"nous":
			if not store.collect(item.item_id):
				return false
			item.active = false
			_save()
			hud.toast("+1 Fragmento de Nous · [T] Árvore das Emanações")
		"daggers":
			if not store.collect(item.item_id, 0):
				return false
			store.data["weapons"].append(DemoSaveStore.WEAPONS[1])
			player.weapon_unlocked[1] = true
			item.active = false
			_save()
			hud.toast("Adagas do Reverso encontradas · [Tab] trocar arma")
		"lever":
			var flag: String = LEVER_FLAGS[item.item_id]
			store.data["flags"][flag] = true
			{"shortcut": shortcut, "aqueduct": aqueduct_gate, "echo": echo_gate}[flag].open()
			item.active = false
			_save()
			if flag == "echo":
				hud.show_dialog("A grade do Eco", "A grade cede. Do outro lado está o Santuário da Primeira Palavra, onde a jornada começou.\n\nAs vozes das Catacumbas e o santuário agora estão a poucos passos um do outro.")
			else:
				hud.toast("Aqueduto aberto · o jardim agora se liga ao mercado." if flag == "aqueduct" else "O portão cedeu. O caminho de volta sempre esteve aqui.")
		"memory":
			store.data["flags"][item.item_id] = true
			_save()
			if item.item_id == "memory_market":
				hud.show_dialog("O registro do mercador", "As cargas chegaram, mas ninguém lembrava quem as havia vendido. O relicário da ordem responde a duas testemunhas: o comércio e a travessia.\n\nO barqueiro deixou seu registro no píer inferior. A alcova esquecida fica além do pátio.\n\n— Memória fictícia do Porto")
			else:
				hud.show_dialog("A memória do barqueiro", "A água não levou a minha lembrança. Ela foi escondida entre as pedras da alcova, junto à memória do mercado. Duas marcas despertam o relicário.\n\nO jardim inundado guarda o mecanismo que devolve o caminho ao mercado.\n\n— Memória fictícia do Porto")
		"cache":
			var memories := int(store.data["flags"].get("memory_market", false)) + int(store.data["flags"].get("memory_dock", false))
			if memories < 2:
				hud.show_dialog("O relicário das testemunhas", "Duas marcas permanecem apagadas no bronze. Memórias reconhecidas: %d de 2.\n\nProcure o registro do mercador e a memória do barqueiro, no píer inferior. Este segredo é opcional; o caminho principal continua aberto." % memories)
				return false
			if not store.collect(item.item_id, 2):
				return false
			item.opened = true
			item.active = false
			_save()
			hud.toast("Relicário desperto · +2 Fragmentos de Nous", Color("e2c693"), 5)
		"inscription":
			hud.show_dialog("As últimas palavras de Iri", "“As pessoas do cais perderam mais que os nomes. Algo escreve por cima de suas memórias.\n\nSe eu não voltar, procura a guarita. A passagem antiga leva de volta à Primeira Palavra.”\n\n— Inscrição fictícia encontrada por Senu")
		"gate":
			hud.toast("O selo se desfez. Siga até as Catacumbas." if store.data["flags"]["boss"] else "O Porteiro Sem Nome sustenta este selo.")
	return true

func seals_found() -> int:
	var count := 0
	for id in ["seal_bells", "seal_water", "seal_stars"]:
		count += int(store.data["flags"].get(id, false))
	return count

func refresh_seals() -> void:
	if boss_entry_gate != null and (seals_found() == 3 or store.data["flags"]["boss"]):
		boss_entry_gate.open()
	var puzzles: Dictionary = store.data["puzzles"]
	for object in get_tree().get_nodes_in_group("interactables"):
		if object.get_parent() != actors:
			continue
		var id: String = object.item_id
		if object.kind == "bell":
			object.opened = store.data["flags"]["seal_bells"]
			object.active = not object.opened
			var note: String = id.trim_prefix("bell_")
			object.label = "Tocar sino da " + {"moon": "Lua", "sun": "Aurora", "star": "Estrela"}[note] + " · %d/3 notas" % puzzles["bells"].size()
		elif object.kind in ["valve", "water_altar"]:
			object.opened = store.data["flags"]["seal_water"]
			object.active = not object.opened
			object.puzzle_value = int(puzzles["water"])
			var verb: String = {"valve_two": "Fonte menor +2", "valve_three": "Fonte maior +3", "valve_drain": "Drenar uma marca", "valve_reset": "Recircular · zerar as fontes", "water_altar": "Conferir oferenda da maré"}[id]
			object.label = verb + " · nível %d/6" % int(puzzles["water"])
		elif object.kind == "dial":
			var index := ["star_sun", "star_moon", "star_eye"].find(id)
			object.puzzle_value = int(puzzles["stars"][index])
			object.opened = store.data["flags"]["seal_stars"]
			object.active = not object.opened
			object.label = "Girar " + ["Sol", "Lua", "Olho"][index] + " · " + ["Norte", "Leste", "Sul", "Oeste"][object.puzzle_value]
		elif object.kind == "stars_altar":
			object.opened = store.data["flags"]["seal_stars"]
			object.active = not object.opened
		elif object.kind == "boss_lock":
			object.opened = seals_found() == 3 or store.data["flags"]["boss"]
			object.label = "Porta das Três Lembranças · %d/3 selos" % seals_found()
		object.queue_redraw()

func _award_seal(flag: String, title: String) -> bool:
	if store.data["flags"][flag]:
		return false
	var required_clue: String = {"seal_bells": "bells_clue", "seal_water": "water_clue", "seal_stars": "stars_clue"}[flag]
	if not store.data["flags"][required_clue]:
		var place: String = {"bells_clue": "Arquivo dos Nomes Velados", "water_clue": "Cisterna das Duas Fontes", "stars_clue": "Terraço do Farol Partido"}[required_clue]
		hud.show_dialog("Uma lembrança ainda está ausente", "O mecanismo respondeu, mas Senu ainda não reconhece sua inscrição. Procure a memória escrita em: %s.\n\nA orientação fica guardada depois da leitura." % place)
		return false
	store.data["flags"][flag] = true
	store.collect("reward_" + flag, 1)
	refresh_seals()
	_save()
	hud.show_dialog(title, "Uma lembrança retorna ao bronze da guarita. Selos despertos: %d de 3.\n\n+1 Fragmento de Nous. Os mecanismos e esta descoberta ficam salvos.\n\n%s" % [seals_found(), "A Porta das Três Lembranças se abriu. O Porteiro espera." if seals_found() == 3 else "As outras marcas apontam para os Sinos ao norte, a Cisterna ao sul e o Observatório a leste."])
	return true

func _activate_puzzle(item: PortInteractable) -> bool:
	var id := item.item_id
	var puzzles: Dictionary = store.data["puzzles"]
	match item.kind:
		"clue":
			store.data["flags"][id] = true
			_save()
			match id:
				"bells_clue":
					hud.show_dialog("A liturgia das três vozes", "A noite escuta primeiro. A aurora responde. Só então a estrela guarda o nome.\n\nNa Praça dos Três Sinos, toque: LUA → AURORA → ESTRELA. Um som fora da ordem desfaz apenas a sequência atual.\n\nA praça fica a leste deste Arquivo, além da passagem estreita.")
				"water_clue":
					hud.show_dialog("As duas fontes", "A fonte menor oferece duas marcas; a maior, três. Cada fonte pode ser aberta uma vez. O dreno retira uma marca.\n\nO Santuário Soterrado, a oeste das Comportas, aceita QUATRO marcas, vindas das DUAS fontes.\n\nSe errar, use RECIRCULAR na válvula leste para zerar o nível e rearmar ambas as fontes. Drenar até zero também permite recomeçar.")
				"stars_clue":
					hud.show_dialog("O céu gravado no farol", "O Sol procura a aurora: LESTE. A Lua descansa no poente: OESTE. O Olho observa a margem inferior: SUL.\n\nNo Observatório ao sul do Farol, cada toque gira um obelisco: Norte → Leste → Sul → Oeste. Depois confira o altar no canto sudeste.")
				"memory_pilgrim":
					hud.show_dialog("A viagem que não acaba", "Entre o Arquivo e os Sinos existe um caminho de volta ao Santuário. Nenhuma ala é uma prisão.\n\nA porta do Porteiro exige três lembranças: Voz, Maré e Céu. As passagens de volta abreviam a viagem depois da descoberta.")
				"memory_copper":
					hud.show_dialog("A rota das ânforas", "As cargas davam a volta pelo Farol e voltavam pelo Reservatório. O velho cais liga este distrito ao Embarcadouro: procure a travessia a oeste.\n\nAs marcas dos obeliscos foram copiadas nas pedras do Farol.")
		"bell":
			if store.data["flags"]["seal_bells"]:
				return false
			var order := ["moon", "sun", "star"]
			var note := id.trim_prefix("bell_")
			var sequence: Array = puzzles["bells"]
			if sequence.size() >= order.size():
				sequence.clear()
			var broken: bool = note != order[sequence.size()]
			if broken:
				sequence.clear()
			if note == order[sequence.size()]:
				sequence.append(note)
			if sequence.size() == 3:
				return _award_seal("seal_bells", "A lembrança da Voz")
			refresh_seals()
			_save()
			# Only one toast is visible, so the warning replaces the progress line.
			if broken and sequence.is_empty():
				hud.toast("A harmonia se desfaz. Recomece pela Lua.", Color("d9ad8a"))
			elif broken:
				hud.toast("A harmonia se desfaz. A Lua recomeça a sequência · 1 de 3 notas.", Color("d9ad8a"))
			else:
				hud.toast("Sinos: %d de 3 notas reconhecidas." % sequence.size())
		"valve":
			var sources: Array = puzzles["water_sources"]
			if id == "valve_reset":
				puzzles["water"] = 0
				sources[0] = false
				sources[1] = false
			elif id == "valve_drain":
				puzzles["water"] = maxi(0, int(puzzles["water"]) - 1)
				if int(puzzles["water"]) == 0:
					sources[0] = false
					sources[1] = false
			else:
				var source_index := 0 if id == "valve_two" else 1
				if sources[source_index]:
					hud.toast("Esta fonte já foi aberta. Drene até zero para rearmar as duas.")
					return false
				sources[source_index] = true
				puzzles["water"] = mini(6, int(puzzles["water"]) + (2 if source_index == 0 else 3))
			refresh_seals()
			_save()
			hud.toast("Cisterna: %d marcas · duas fontes %s" % [int(puzzles["water"]), "abertas" if sources[0] and sources[1] else "incompletas"])
		"water_altar":
			if int(puzzles["water"]) == 4 and puzzles["water_sources"][0] and puzzles["water_sources"][1]:
				return _award_seal("seal_water", "A lembrança da Maré")
			hud.show_dialog("A oferenda incompleta", "O altar exige QUATRO marcas e a água das DUAS fontes. Nível atual: %d.\n\nA inscrição junto à Cisterna explica as válvulas. Se necessário, drene até zero para recomeçar." % int(puzzles["water"]))
			return false
		"dial":
			var index := ["star_sun", "star_moon", "star_eye"].find(id)
			puzzles["stars"][index] = (int(puzzles["stars"][index]) + 1) % 4
			refresh_seals()
			_save()
			hud.toast(item.label)
		"stars_altar":
			# A reopened save brings the positions back from JSON as floats.
			if puzzles["stars"].map(func(value): return int(value)) == [1, 3, 2]:
				return _award_seal("seal_stars", "A lembrança do Céu")
			hud.show_dialog("O céu ainda não responde", "Os três obeliscos não formam a orientação gravada no Farol.\n\nCada toque gira apenas um deles. As posições atuais ficam salvas; você pode corrigir qualquer orientação sem recomeçar a exploração.")
			return false
		"boss_lock":
			hud.show_dialog("A Porta das Três Lembranças", "Selos despertos: %d de 3.\n\nVOZ — Arquivo e Praça dos Sinos, ao norte.\nMARÉ — Cisterna e Santuário Soterrado, ao sul.\nCÉU — Farol e Observatório, no distrito leste.\n\n%s" % [seals_found(), "A passagem está aberta." if item.opened else "A porta só cederá quando as três lembranças retornarem."])
	return true

func buy_skill(id: String) -> bool:
	if not store.purchase(id):
		return false
	_apply_upgrades(false)
	_save()
	return true

func _apply_upgrades(restore_health: bool) -> void:
	var previous_max: int = player.max_health
	player.max_health = 120 if "materia" in store.data["skills"] else 100
	player.damage_bonus = 4 if "vontade" in store.data["skills"] else 0
	player.power_cooldown_scale = .8 if "intelecto" in store.data["skills"] else 1.0
	if restore_health:
		player.heal_full()
	else:
		player.health = mini(player.max_health, player.health + maxi(0, player.max_health - previous_max))

func _stats_changed() -> void:
	var equipped: String = player.equipped_weapon().id
	if equipped != store.data["equipped"]:
		store.data["equipped"] = equipped
		_save()

func _feedback(message: String, color: Color) -> void:
	if hud != null:
		hud.toast(message, color, 1.4)

func _on_enemy_defeated(id: String, is_boss: bool) -> void:
	if id not in store.data["defeated"]:
		store.data["defeated"].append(id)
	if is_boss:
		store.data["flags"]["boss"] = true
		exit_gate.open()
		hud.toast("PORTEIRO VENCIDO · O selo das Catacumbas se desfez.", Color("dfc38c"), 5)
	_save()

func _on_player_died() -> void:
	respawning = true
	hud.toast("A memória persiste. Retorne à última palavra.", Color("dfb5b0"), 2)
	await get_tree().create_timer(1.5).timeout
	player.reset_at(Layout.iso(checkpoints[store.data["checkpoint"]]))
	var camera: Camera2D = player.get_node("IsometricCamera")
	camera.reset_smoothing()
	respawning = false

func _save() -> bool:
	store.data["equipped"] = player.equipped_weapon().id if player != null else store.data["equipped"]
	var success := store.save_progress()
	if not success and hud != null:
		hud.toast(store.last_error, Color("e4aaa0"), 6)
	return success

func objective() -> String:
	if store.data["flags"]["complete"]:
		if store.data["flags"].get("echo", false):
			return "Grade do Eco aberta · explore o porto ou volte às Catacumbas."
		return "Suba pela Galeria do Eco e erga a grade do santuário."
	if store.data["flags"]["boss"]:
		return "Atravesse o limiar das Catacumbas."
	if seals_found() == 3:
		return "Enfrente o Porteiro Sem Nome."
	if not store.data["flags"]["seal_bells"]:
		return "Selos %d/3 · Explore o Arquivo e os Sinos ao norte." % seals_found()
	if not store.data["flags"]["seal_water"]:
		return "Selos %d/3 · Investigue a Cisterna ao sul do jardim." % seals_found()
	return "Selos %d/3 · Procure o Farol e o Observatório a leste." % seals_found()

func start_journey() -> void:
	_save()
	if not bool(store.data["flags"].get("opening_seen", false)):
		_play_opening()
		return
	_resume_journey()

func _resume_journey() -> void:
	hud.show_overlay("")
	hud.toast("Senu desperta à margem da Inversão. [E] interagir · [Esc] ajuda", Color("d8c9a8"), 5)

func _play_opening() -> void:
	if opening_active: return
	opening_active = true
	player.controls_enabled = false
	hud.set_process_unhandled_input(false)
	hud.hide()
	world_container.hide()
	world_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_opening_layer = CanvasLayer.new()
	_opening_layer.name = "OpeningCinematic"
	_opening_layer.layer = 80
	add_child(_opening_layer)
	_opening_player = Opening.new()
	_opening_player.connect("finished", _opening_finished)
	_opening_layer.add_child(_opening_player)
	get_tree().paused = true
	_opening_player.call("begin")

func _opening_finished() -> void:
	if not opening_active: return
	opening_active = false
	if is_instance_valid(_opening_layer): _opening_layer.queue_free()
	_opening_player = null
	_opening_layer = null
	world_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_container.show()
	player.controls_enabled = true
	hud.show()
	hud.set_process_unhandled_input(true)
	store.data["flags"]["opening_seen"] = true
	_save()
	_resume_journey()

func begin_new_journey() -> void:
	if not store.archive_progress():
		hud.toast("Não foi possível arquivar o progresso. A jornada atual foi preservada.", Color("e4aaa0"), 6)
		return
	var previous := store.data.duplicate(true)
	store.data = DemoSaveStore.fresh_data()
	if not store.save_progress():
		store.data = previous
		hud.toast(store.last_error, Color("e4aaa0"), 6)
		return
	get_tree().set_meta("nono_autostart", true)
	get_tree().paused = false
	get_tree().reload_current_scene()

func save_and_quit() -> void:
	if _save():
		get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and store != null:
		save_and_quit()

func _capture(suffix: String = "") -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://qa/porto_demo%s.png" % suffix
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa"))
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE_SAVED ", ProjectSettings.globalize_path(path))
	get_tree().quit()
