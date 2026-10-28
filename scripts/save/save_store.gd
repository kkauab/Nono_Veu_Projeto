extends RefCounted
class_name DemoSaveStore

const VERSION := 1
## "isle_rest" é a estela da Ilha do Bennu (scripts/world/isle.gd).
const CHECKPOINTS := ["hub", "s1", "market_rest", "caravan_rest", "cistern_rest", "isle_rest"]
## "sea_route": a rota de barco até a ilha já aparece no mapa.
const OPTIONAL_FLAGS := ["aqueduct", "memory_market", "memory_dock", "seal_bells", "seal_water", "seal_stars", "bells_clue", "water_clue", "stars_clue", "memory_pilgrim", "memory_copper", "opening_seen", "echo", "sea_route"]
const WEAPONS := ["e01_khopesh_discipulo", "l01_adagas_reverso"]
## Contadores da economia de combate (scripts/economy/economy.gd): XP e óbolos.
const COUNTERS := ["xp", "coins"]
## Compras e cargas das lojas (scripts/economy/shop_catalog.gd).
const ShopCatalog = preload("res://scripts/economy/shop_catalog.gd")
const SkillCatalog = preload("res://scripts/progression/skill_catalog.gd")
const SKILLS := SkillCatalog.NODES
var data: Dictionary
var path: String
var loaded_existing := false
var last_error := ""

func _init(save_path: String = "user://progress.json") -> void:
	path = save_path
	data = fresh_data()

static func fresh_data() -> Dictionary:
	return {"version": VERSION, "world_revision": 3, "fragments": 0, "collected": [], "skills": [], "weapons": [WEAPONS[0]], "equipped": WEAPONS[0], "defeated": [], "visited": [], "checkpoint": "hub", "flags": {"shortcut": false, "boss": false, "complete": false, "aqueduct": false, "memory_market": false, "memory_dock": false, "seal_bells": false, "seal_water": false, "seal_stars": false, "bells_clue": false, "water_clue": false, "stars_clue": false, "memory_pilgrim": false, "memory_copper": false, "opening_seen": false, "echo": false, "sea_route": false}, "puzzles": {"bells": [], "water": 0, "water_sources": [false, false], "stars": [0, 0, 0]}, "xp": 0, "coins": 0, "purchases": {}, "items": {}}

func load_progress() -> bool:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var parsed: Variant = parser.data
		if not _valid(parsed):
			continue
		data = parsed
		# Existing journeys predate the opening. Their progress resumes directly.
		if not data["flags"].has("opening_seen"):
			data["flags"]["opening_seen"] = true
		for optional_flag in OPTIONAL_FLAGS:
			if not data["flags"].has(optional_flag):
				data["flags"][optional_flag] = false
		if not data.has("puzzles"):
			data["puzzles"] = {"bells": [], "water": 0, "water_sources": [false, false], "stars": [0, 0, 0]}
		if not data["puzzles"].has("water_sources"):
			data["puzzles"]["water_sources"] = [false, false]
		# Saves anteriores à economia de combate começam sem XP nem óbolos.
		for counter in COUNTERS:
			if not data.has(counter):
				data[counter] = 0
		# E sem compras nas lojas das casas.
		for shelf in ["purchases", "items"]:
			if not data.has(shelf):
				data[shelf] = {}
		data["world_revision"] = 3.0
		loaded_existing = true
		return true
	return false

func _valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var version_value: Variant = value.get("version")
	if not (version_value is int or version_value is float) or float(version_value) != VERSION:
		return false
	for field in ["collected", "skills", "weapons", "defeated", "visited"]:
		if not value.get(field) is Array or value[field].size() > 256:
			return false
		for item in value[field]:
			if not item is String:
				return false
	if not value.get("flags") is Dictionary:
		return false
	if not (value.get("fragments") is float or value.get("fragments") is int):
		return false
	if float(value["fragments"]) < 0 or float(value["fragments"]) > 9999:
		return false
	for counter in COUNTERS:
		if value.has(counter):
			var amount: Variant = value[counter]
			if not (amount is float or amount is int) or float(amount) != floorf(float(amount)) or amount < 0 or amount > 999999:
				return false
	if (value.has("purchases") or value.has("items")) and not ShopCatalog.valid_state(value.get("purchases", {}), value.get("items", {})):
		return false
	if value.get("checkpoint") not in CHECKPOINTS or value.get("equipped") not in WEAPONS:
		return false
	if not WEAPONS[0] in value["weapons"] or not value["equipped"] in value["weapons"]:
		return false
	if not SkillCatalog.valid_owned(value["skills"]):
		return false
	for flag in ["shortcut", "boss", "complete"]:
		if not value["flags"].get(flag) is bool:
			return false
	for optional_flag in OPTIONAL_FLAGS:
		if value["flags"].has(optional_flag) and not value["flags"][optional_flag] is bool:
			return false
	if value.has("puzzles"):
		var puzzles: Variant = value["puzzles"]
		if not puzzles is Dictionary or not puzzles.get("bells") is Array or puzzles["bells"].size() > 3:
			return false
		for note in puzzles["bells"]:
			if note not in ["moon", "sun", "star"]:
				return false
		var water: Variant = puzzles.get("water")
		if not (water is float or water is int) or float(water) != floorf(float(water)) or water < 0 or water > 6:
			return false
		if not puzzles.get("stars") is Array or puzzles["stars"].size() != 3:
			return false
		if puzzles.has("water_sources"):
			if not puzzles["water_sources"] is Array or puzzles["water_sources"].size() != 2:
				return false
			for source in puzzles["water_sources"]:
				if not source is bool:
					return false
		for state in puzzles["stars"]:
			if not (state is float or state is int) or float(state) != floorf(float(state)) or state < 0 or state > 3:
				return false
	return true

func archive_progress() -> bool:
	if not FileAccess.file_exists(path):
		return true
	var directory := ProjectSettings.globalize_path(path.get_base_dir().path_join("archives"))
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return false
	var name := "progress_%d_%d.json" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
	var archive := FileAccess.open(directory.path_join(name), FileAccess.WRITE)
	if archive == null:
		return false
	archive.store_string(JSON.stringify(data, "\t"))
	archive.flush()
	var success := archive.get_error() == OK
	archive.close()
	return success

func save_progress() -> bool:
	last_error = ""
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		last_error = "Não foi possível criar a pasta do salvamento."
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Não foi possível escrever o salvamento."
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(absolute + ".bak")
		error = DirAccess.rename_absolute(absolute, absolute + ".bak")
		if error != OK:
			last_error = "Não foi possível preservar o backup."
			return false
	error = DirAccess.rename_absolute(absolute + ".tmp", absolute)
	if error != OK:
		last_error = "Falha ao concluir o salvamento; o backup foi preservado."
		return false
	return true

func collect(id: String, amount: int = 1) -> bool:
	if id in data["collected"]:
		return false
	data["collected"].append(id)
	data["fragments"] += maxi(0, amount)
	return true

func purchase(skill_id: String) -> bool:
	if SkillCatalog.blocker(data, skill_id) != "":
		return false
	var definition: Dictionary = SKILLS[skill_id]
	data["fragments"] -= definition["cost"]
	data["skills"].append(skill_id)
	return true
