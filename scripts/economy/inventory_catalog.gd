extends RefCounted
## A read-only projection of discovered equipment and carried possessions.
## Shop upgrades stay passive; quest objects disappear after their delivery.
const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Economy = preload("res://scripts/economy/economy.gd")
const Skills = preload("res://scripts/progression/skill_catalog.gd")
const KHOPESH = preload("res://resources/weapons/khopesh.tres")
const DAGGERS = preload("res://resources/weapons/daggers.tres")
const KEY_SPEAR = preload("res://resources/weapons/gatekeeper_key_spear.tres")
const FILTERS := ["Todos", "Armas", "Itens", "Fragmentos", "Chaves"]
const QUEST_OBJECTS := {
	"quest_mirra": ["Jarro de mirra", "Merit espera este jarro recuperado no Jardim Inundado.", "quest_done_merit", "jar"],
	"quest_tenaz": ["Tenaz marcada", "A espiral no cabo pertence à ferramenta perdida de Nakht.", "quest_done_nakht", "tool"],
	"quest_escala": ["Escala da guarda", "O rolo conserva os nomes do turno de Tarek. Leve-o à Casa da Guarda.", "quest_done_tarek", "scroll"],
	"fisher_knot": ["Cordão dos irmãos", "Um nó capaz de devolver a Sabu a lembrança do irmão.", "fisher_knot_shown", "cord"],
	"isle_net": ["Rede de Hori", "Uma rede antiga recuperada na Ilha do Bennu. Hori ainda pode reconhecer os nós.", "isle_net_done", "cord"]
}

static func entries(data: Dictionary, weapons: Array = []) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var definitions: Array = weapons if not weapons.is_empty() else [KHOPESH, DAGGERS]
	for index in range(definitions.size()):
		var weapon: Resource = definitions[index]
		if str(weapon.id) not in data.get("weapons", []): continue
		result.append(_weapon(data, weapon, index))
	for id in Shop.ITEMS:
		var count := Shop.owned(data, id)
		if count <= 0: continue
		var item: Dictionary = Shop.ITEMS[id]
		var icon := "jar"
		var stats: Array[String] = ["Quantidade adquirida: %d" % count]
		if id == "jarro_balsamo":
			stats = ["Cargas: %d / %d" % [Shop.charges(data, "balsamo"), Shop.capacity(data, "balsamo")], "Cura por carga: %d de vida" % Shop.balm_heal(data)]
		elif item.has("damage"):
			icon = "tool"
			stats = ["Bônus de dano: +%d" % int(item["damage"]), "Efeito já aplicado aos golpes"]
		elif item.has("health"):
			icon = "amulet"
			stats = ["Vida máxima: +%d" % int(item["health"]), "Melhoria permanente"]
		elif item.has("dodge_scale"):
			icon = "sandals"
			stats = ["Recarga da esquiva: −15%", "Melhoria permanente"]
		elif id == "mapa_rotas":
			icon = "map"
			stats = ["Revela contornos de setores", "Segredos continuam ocultos"]
		elif id == "mirra":
			stats = ["Cura adicional: +15 por carga", "Efeito já aplicado ao bálsamo"]
		elif id == "pena_bennu":
			icon = "feather"
			stats = ["Capacidade de bálsamo: +1", "Recompensa da Ilha do Bennu"]
		result.append({"id": id, "name": item["name"], "description": item["description"], "category": "Itens", "kind": "upgrade", "icon": icon, "count": count, "stats": stats, "note": "Melhoria ativa"})
	var collected: Array = data.get("collected", [])
	if "gatekeeper_key_spear" in collected:
		result.append({"id":"gatekeeper_key_spear","name":KEY_SPEAR.display_name,"description":KEY_SPEAR.description,"category":"Armas","kind":"heirloom","icon":"key_spear","count":1,"stats":["Arma pesada · haste cerimonial","Poder latente: Último Chamado"],"note":"Guardada entre os pertences de Senu"})
	for id in QUEST_OBJECTS:
		var item: Array = QUEST_OBJECTS[id]
		if id not in collected or item[2] in collected: continue
		result.append({"id": id, "name": item[0], "description": item[1], "category": "Chaves", "kind": "quest", "icon": item[3], "count": 1, "stats": ["Objeto de missão", "Permanece até ser entregue"], "note": "Leve-o ao morador indicado"})
	var flags: Dictionary = data.get("flags", {})
	for pair in [["seal_bells", "Selo da Voz"], ["seal_water", "Selo da Maré"], ["seal_stars", "Selo do Céu"]]:
		if not bool(flags.get(pair[0], false)): continue
		result.append({"id": pair[0], "name": pair[1], "description": "Uma lembrança despertada. Integra a passagem das Três Lembranças.", "category": "Chaves", "kind": "key", "icon": "seal", "count": 1, "stats": ["Selo despertado", "Acesso à Porta das Três Lembranças"], "note": "Registrado na travessia"})
	var fragments := int(data.get("fragments", 0))
	if fragments > 0:
		result.append({"id": "nous", "name": "Fragmentos de Nous", "description": "Lembranças da exploração que podem despertar capacidades na Árvore das Emanações.", "category": "Fragmentos", "kind": "resource", "icon": "fragment", "count": fragments, "stats": ["Disponíveis: %d" % fragments, "Usados para aprender emanações"], "note": "Consulte a Árvore das Emanações"})
	return result

static func filtered(items: Array[Dictionary], category: String) -> Array[Dictionary]:
	if category == "Todos" or category not in FILTERS: return items
	var result: Array[Dictionary] = []
	for entry in items:
		if entry["category"] == category: result.append(entry)
	return result

static func _weapon(data: Dictionary, weapon: Resource, index: int) -> Dictionary:
	var effects := Skills.effects(data.get("skills", []))
	var bonus := int(effects["damage_bonus"]) + Economy.damage_bonus(Economy.level(data)) + Shop.damage_bonus(data, str(weapon.id))
	var cooldown := float(weapon.power_cooldown) * float(effects["power_cooldown_scale"])
	var stats: Array[String] = ["Dano por golpe: %d" % (int(weapon.damage) + bonus), "Intervalo entre golpes: %.2f s" % float(weapon.attack_interval), "Alcance: %d px" % int(weapon.range_px)]
	return {"id": weapon.id, "name": weapon.display_name, "description": weapon.description, "category": "Armas", "kind": "weapon", "icon": "daggers" if weapon.category == "leve" else "khopesh", "count": 1, "weapon_index": index, "stats": stats, "damage": int(weapon.damage) + bonus, "interval": weapon.attack_interval, "range": weapon.range_px, "power": "%s · %.1f s" % [weapon.power_name, cooldown], "equipped": str(data.get("equipped", "")) == str(weapon.id)}
