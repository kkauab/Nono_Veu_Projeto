extends SceneTree
## Contratos da árvore: dependências, débito atômico e leitura dos saves antigos.
## Usa somente um arquivo exclusivo em user://qa; nunca abre progress.json.

const Catalog = preload("res://scripts/progression/skill_catalog.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(Catalog.ORDER.size() == 13 and Catalog.NODES.size() == 13, "Thirteen nodes have stable IDs")
	_check(SaveStore.SKILLS == Catalog.NODES, "Legacy SKILLS alias uses the full catalog")
	var ordered: Array = []
	var cost := 0
	for id in Catalog.ORDER:
		_check(Catalog.requires_met(ordered, id), "Order follows prerequisite graph: " + id)
		ordered.append(id)
		cost += int(Catalog.NODES[id]["cost"])
	_check(cost == 28, "Entire tree costs 28 Nous")
	_check(Catalog.valid_owned(ordered), "Full graph is a valid saved build")
	_check(not Catalog.valid_owned(["vontade", "vontade"]), "Duplicate saved IDs are rejected")
	_check(not Catalog.valid_owned(["not_a_skill"]), "Unknown saved IDs are rejected")
	_check(not Catalog.valid_owned(["ritmo_lamina"]), "Missing saved prerequisites are rejected")
	_check(not Catalog.valid_owned(["vontade", 7]), "Malformed saved IDs are rejected")
	_check(Catalog.valid_owned(["intelecto", "materia", "vontade"]), "Old root-only builds remain valid in any order")
	var store := SaveStore.new("user://qa/skill_catalog_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	store.collect("qa_finite_supply", 22)
	var before: Dictionary = store.data.duplicate(true)
	_check(not store.purchase("convergencia_nous") and store.data == before, "Missing several prerequisites cannot spend Nous")
	_check(not store.purchase("unknown") and store.data == before, "Unknown purchase cannot mutate the save")
	_check(store.purchase("vontade") and store.data["fragments"] == 21, "Original Vontade price remains one")
	before = store.data.duplicate(true)
	_check(not store.purchase("vontade") and store.data == before, "Duplicate purchase leaves every field unchanged")
	_check(store.purchase("ritmo_lamina"), "First Vontade dependency unlocks")
	before = store.data.duplicate(true)
	_check(not store.purchase("contra_ataque_agil") and store.data == before, "A hybrid needs both branches, even when affordable")
	for id in ["materia", "intelecto", "passo_etereo", "selo_mercurio", "contra_ataque_agil", "reflexo_palavra", "esquiva_eterea", "convergencia_nous"]:
		_check(store.purchase(id), "Finite 22-Nous build can purchase " + id)
	_check(store.data["fragments"] == 2, "Convergence path costs 20 and leaves two of the 22 available")
	before = store.data.duplicate(true)
	_check(not store.purchase("pele_alabastro") and store.data == before, "Insufficient funds leaves every field unchanged")
	var baseline := Catalog.effects([])
	var final_effects := Catalog.effects(store.data["skills"])
	_check(baseline["damage_bonus"] == 0 and baseline["power_cooldown_scale"] == 1.0 and not baseline["mercury_unlocked"], "No skills preserve baseline statistics")
	_check(final_effects["damage_bonus"] == 4 and final_effects["health_bonus"] == 20 and is_equal_approx(final_effects["power_cooldown_scale"], .8), "Legacy base effects remain unchanged")
	_check(final_effects["mercury_pierce"] == 3 and is_equal_approx(final_effects["mercury_cooldown"], 6.0), "Convergence overrides the basic projectile")
	final_effects["damage_bonus"] = 999
	_check(Catalog.effects(store.data["skills"])["damage_bonus"] == 4, "Rebuilding effects cannot stack or modify catalog data")
	_check(store.save_progress(), "New dependency build writes an isolated save")
	var loaded := SaveStore.new(store.path)
	_check(loaded.load_progress() and loaded.data == JSON.parse_string(JSON.stringify(store.data)), "Full skill graph and balance survive JSON roundtrip")
	_check(not loaded.purchase("convergencia_nous") and loaded.data["fragments"] == 2, "Reload cannot rebuy the final skill")
	var old_save := SaveStore.fresh_data()
	old_save["skills"] = ["vontade", "materia", "intelecto"]
	old_save["fragments"] = 8
	_check(loaded._valid(old_save), "Old three-skill format is accepted without migration")
	old_save["skills"] = ["vontade", "ritmo_lamina", "contra_ataque_agil"]
	_check(not loaded._valid(old_save), "Save schema rejects a hybrid missing its other branch")
	print("SKILL_CATALOG_RESULT checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)
