extends SceneTree
const Opening = preload("res://scripts/ui/opening_cutscene.gd")

var checks := 0
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var path := "user://qa/migration_%d_%d/progress.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	# Fixture do mapa anterior, sem os campos novos da expansão.
	var legacy := DemoSaveStore.fresh_data()
	legacy.erase("world_revision")
	legacy["flags"] = {"shortcut": true, "boss": true, "complete": true}
	legacy["fragments"] = 3
	legacy["collected"] = ["nous_cais", "adagas"]
	legacy["weapons"].append(DemoSaveStore.WEAPONS[1])
	legacy["equipped"] = DemoSaveStore.WEAPONS[1]
	legacy["skills"] = ["vontade"]
	legacy["checkpoint"] = "s1"
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "Slot legado de teste pode ser escrito")
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(legacy))
	file.close()
	var store := DemoSaveStore.new(path)
	check(store.load_progress(), "Save anterior ao mapa ampliado continua válido")
	check(store.data["fragments"] == 3 and store.data["skills"] == ["vontade"], "Moeda e habilidade antigas foram preservadas")
	check(store.data["equipped"] == DemoSaveStore.WEAPONS[1] and "adagas" in store.data["collected"], "Equipamento e coletas antigas foram preservados")
	check(store.data["checkpoint"] == "s1" and store.data["flags"]["boss"], "Checkpoint e chefe antigo foram preservados")
	check(not store.data["flags"]["aqueduct"] and not store.data["flags"]["memory_market"], "Conteúdo novo começa fechado e sem memórias lidas")
	store.data["checkpoint"] = "market_rest"
	store.data["flags"]["aqueduct"] = true
	check(store.save_progress(), "Checkpoint novo pode ser salvo")
	var reopened := DemoSaveStore.new(path)
	check(reopened.load_progress() and reopened.data["checkpoint"] == "market_rest", "Checkpoint novo reabre em âncora nomeada")
	check(reopened.data["flags"]["aqueduct"], "Segundo atalho persiste")
	var previous: Variant = JSON.parse_string(JSON.stringify(reopened.data))
	check(reopened.archive_progress(), "Nova jornada consegue arquivar progresso atual")
	var archives := DirAccess.get_files_at(path.get_base_dir().path_join("archives"))
	check(archives.size() == 1, "Arquivo de segurança foi criado no slot isolado")
	if archives.size() == 1:
		var archived: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("archives").path_join(archives[0])))
		check(archived == previous, "Arquivo de segurança mantém o estado completo")
	reopened.data = DemoSaveStore.fresh_data()
	check(reopened.save_progress(), "Estado inicial da nova jornada é salvo")
	var fresh := DemoSaveStore.new(path)
	check(fresh.load_progress() and fresh.data["fragments"] == 0 and fresh.data["checkpoint"] == "hub", "Nova jornada reabre limpa no hub")
	if archives.size() == 1:
		var archived: Variant = JSON.parse_string(FileAccess.get_file_as_string(path.get_base_dir().path_join("archives").path_join(archives[0])))
		check(archived == previous, "Reiniciar não sobrescreve a cópia anterior")
	if "--qa" in OS.get_cmdline_user_args():
		await _test_optional_cache_and_restart(path.get_base_dir())
	print("MIGRATION CHECKS: %d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _test_optional_cache_and_restart(directory: String) -> void:
	var scene: PackedScene = load("res://scenes/boot/main.tscn")
	var world: Node2D = scene.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await physics_frame
	var isolated := DemoSaveStore.new(directory.path_join("puzzle.json"))
	world.set("store", isolated)
	var hero: SenuPlayer = world.get("player")
	var hud: Control = world.get("hud")
	var cache := _item(world, "cache")
	check(cache != null, "Relicário opcional existe no mundo")
	if cache == null:
		world.queue_free()
		await process_frame
		return
	hero.position = cache.position
	check(not world.call("activate", cache) and isolated.data["fragments"] == 0, "Relicário permanece fechado sem as memórias")
	hud.call("show_overlay", "")
	for id in ["memory_market", "memory_dock"]:
		var memory: PortInteractable = _item(world, id)
		check(memory != null, "Inscrição alcançável existe: " + id)
		if memory != null:
			hero.position = memory.position
			check(bool(world.call("activate", memory)) and isolated.data["flags"][id], "Leitura registra memória: " + id)
			hud.call("show_overlay", "")
	hero.position = cache.position
	check(bool(world.call("activate", cache)), "As duas memórias permitem abrir o relicário")
	check(cache.opened and isolated.data["fragments"] == 2, "Relicário abre visualmente e concede recompensa")
	check(not world.call("activate", cache) and isolated.data["fragments"] == 2, "Relicário não duplica a recompensa")
	check(not FileAccess.file_exists(isolated.path), "Relicário e pistas não criam autosave fora de uma torre")
	var tower := _item(world, "hub")
	hero.position = tower.position
	check(bool(world.call("activate", tower)), "Meditar na torre ancora o relicário e suas pistas")
	await process_frame
	await process_frame
	var saved := DemoSaveStore.new(isolated.path)
	check(saved.load_progress() and "cache" in saved.data["collected"] and saved.data["flags"]["memory_dock"], "Segredo opcional e pistas persistem juntos")
	isolated.loaded_existing = true
	hud.call("show_overlay", "intro")
	var new_button: Button
	for child in hud.get_children():
		if child is Button and child.text == "Nova jornada":
			new_button = child
	check(new_button != null, "Menu oferece nova jornada ao existir progresso")
	if new_button == null:
		paused = false
		world.queue_free()
		await process_frame
		return
	new_button.pressed.emit()
	check(hud.get("overlay") == "new_journey", "Nova jornada exige confirmação dentro do jogo")
	var confirm := hud.find_child("ConfirmNewJourney", true, false) as Button
	check(confirm != null, "Confirmação tem ação explícita")
	if confirm == null:
		paused = false
		world.queue_free()
		await process_frame
		return
	confirm.pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	var restarted: Node2D = current_scene
	var restarted_store: DemoSaveStore = restarted.get("store")
	check(restarted_store.data["fragments"] == 0 and not restarted_store.data["flags"]["boss"], "Menu realmente reinicia a jornada com estado novo")
	check(restarted.opening_active and paused, "Nova jornada exibe a abertura obrigatória antes do controle")
	if restarted.opening_active:
		restarted._opening_player.call("seek", Opening.DURATION)
		await process_frame
		await process_frame
	check(not paused and restarted.get("hud").get("overlay") == "", "Nova jornada entra no mundo sem ficar pausada")
	var archived_paths := DirAccess.get_files_at(directory.path_join("archives"))
	var found_puzzle := false
	for filename in archived_paths:
		var snapshot: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("archives").path_join(filename)))
		if snapshot is Dictionary and "cache" in snapshot.get("collected", []):
			found_puzzle = snapshot["fragments"] == 2 and snapshot["flags"].get("memory_market", false)
	check(found_puzzle, "Recomeçar pelo menu arquiva o progresso da partida anterior")
	restarted.queue_free()
	await process_frame

func _item(world: Node2D, id: String) -> PortInteractable:
	var actors: Node2D = world.get("actors")
	for child in actors.get_children():
		if child is PortInteractable and child.item_id == id:
			return child as PortInteractable
	return null
