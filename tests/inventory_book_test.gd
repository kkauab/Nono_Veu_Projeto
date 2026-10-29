extends SceneTree
const Catalog = preload("res://scripts/economy/inventory_catalog.gd")
const Page = preload("res://scripts/ui/inventory_book_page.gd")
const Weapons := [preload("res://resources/weapons/khopesh.tres"), preload("res://resources/weapons/daggers.tres")]
var checks := 0
var failures: Array[String] = []

func _init() -> void: _run.call_deferred()

func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():
		quit(1)
		return
	var data := {"weapons": ["e01_khopesh_discipulo"], "equipped": "e01_khopesh_discipulo", "purchases": {}, "items": {}, "collected": [], "fragments": 0, "skills": [], "xp": 0, "coins": 0, "flags": {}}
	var initial := Catalog.entries(data, Weapons)
	_check(initial.size() == 1 and initial[0]["id"] == "e01_khopesh_discipulo", "A new inventory contains only the actually discovered weapon")
	_check(initial[0]["damage"] == 22 and is_equal_approx(initial[0]["interval"], .43) and initial[0]["range"] == 42, "Preview uses the real Khopesh tuning")
	_check(initial[0]["stats"].size() == 3, "Damage, interval and range each have a readable stat row")
	_check(initial[0]["equipped"], "Equipped state comes from the player's saved choice")
	data["purchases"] = {"pedra_amolar": 1, "tempera_khopesh": 1, "jarro_balsamo": 2, "mirra": 1}
	data["items"] = {"balsamo": 1}
	data["skills"] = ["vontade"]
	data["xp"] = 40
	var improved := Catalog.entries(data, Weapons)
	var upgraded := _entry(improved, "e01_khopesh_discipulo")
	var expected := 22 + int(preload("res://scripts/progression/skill_catalog.gd").effects(data["skills"])["damage_bonus"]) + 5
	_check(upgraded["damage"] == expected, "Weapon damage includes the actual skill and purchased sharpening bonuses")
	_check(_entry(improved, "jarro_balsamo")["stats"][0] == "Cargas: 1 / 2", "Balm preview reflects current charges, not purchased quantity alone")
	_check(_entry(improved, "jarro_balsamo")["stats"][1] == "Cura por carga: 55 de vida", "Myrrh healing is included in the actual balm stats")
	data["weapons"].append("l01_adagas_reverso")
	data["equipped"] = "l01_adagas_reverso"
	var both := Catalog.entries(data, Weapons)
	_check(Catalog.filtered(both, "Armas").size() == 2 and _entry(both, "l01_adagas_reverso")["equipped"], "Discovered daggers occupy a slot and can be the equipped preview")
	_check(_entry(both, "l01_adagas_reverso")["damage"] == 10 + int(preload("res://scripts/progression/skill_catalog.gd").effects(data["skills"])["damage_bonus"]) + 2, "Khopesh tempering is not incorrectly added to dagger damage")
	data["fragments"] = 3
	data["collected"] = ["quest_mirra", "quest_tenaz", "fisher_knot"]
	data["flags"] = {"seal_bells": true}
	var discoveries := Catalog.entries(data, Weapons)
	_check(Catalog.filtered(discoveries, "Fragmentos").size() == 1 and _entry(discoveries, "nous")["count"] == 3, "Only currently available Nous is shown as a counted resource")
	_check(Catalog.filtered(discoveries, "Chaves").size() == 4, "Only found quest objects and awakened seals become key slots")
	data["collected"].append_array(["quest_done_merit", "fisher_knot_shown"])
	var delivered := Catalog.entries(data, Weapons)
	_check(_entry(delivered, "quest_mirra").is_empty() and _entry(delivered, "fisher_knot").is_empty(), "Delivered quest objects no longer pretend to be carried")
	var before := JSON.stringify(data)
	Catalog.filtered(Catalog.entries(data, Weapons), "Itens")
	_check(JSON.stringify(data) == before, "Reading and filtering inventory never mutates progress or grants items")
	for icon in ["khopesh", "daggers", "jar", "tool", "chest", "map", "scroll", "cord", "fragment", "seal"]:
		var texture := Page.icon_texture(icon)
		_check(texture != null and texture.get_width() > 0, icon + " has a real game sprite or an existing HUD symbol")
	var sword := Page.icon_texture("khopesh") as AtlasTexture
	var daggers := Page.icon_texture("daggers") as AtlasTexture
	_check(sword != null and sword.atlas.resource_path == "res://assets/sprites/senu_shared_v6.png", "The sword preview reuses Senu's actual isolated equipment cel")
	_check(daggers != null and daggers.atlas.resource_path == "res://assets/sprites/senu_shared_v6.png", "The dagger preview reuses Senu's actual isolated equipment cel")
	_check(sword.region.size.x <= 384 and sword.region.size.y <= 384 and not sword.region.intersects(daggers.region), "Weapon previews crop only their distinct native alpha bounds")
	print("INVENTORY BOOK checks=%d failures=%d %s" % [checks, failures.size(), failures])
	quit(0 if failures.is_empty() else 1)

func _entry(items: Array[Dictionary], id: String) -> Dictionary:
	for item in items:
		if item["id"] == id: return item
	return {}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error(label)
