extends RefCounted

## Lojas e itens. Como economy.gd, funções puras sobre o dicionário do save:
## `purchases` guarda quantas vezes cada item foi comprado e `items`, as cargas
## que Senu carrega agora. Ver docs/MUNDO_CASAS_LOJAS.md.

const Economy = preload("res://scripts/economy/economy.gd")

const ITEMS := {
	"jarro_balsamo": {"name": "Jarro de bálsamo", "description": "Mais uma carga de cura (tecla R). As cargas voltam cheias ao meditar num santuário.", "price": 35, "limit": 3, "requires": []},
	"mirra": {"name": "Mirra concentrada", "description": "Cada carga de bálsamo cura 15 de vida a mais.", "price": 50, "limit": 1, "requires": ["jarro_balsamo"]},
	# Forja de Nakht: dano. "weapon" limita o bônus à arma equipada.
	"pedra_amolar": {"name": "Pedra de amolar", "description": "+2 de dano em todos os golpes, com qualquer arma.", "price": 45, "limit": 1, "requires": [], "damage": 2},
	"tempera_khopesh": {"name": "Têmpera do Khopesh", "description": "+3 de dano com o Khopesh do Discípulo.", "price": 70, "limit": 1, "requires": ["pedra_amolar"], "damage": 3, "weapon": "e01_khopesh_discipulo"},
	"tempera_adagas": {"name": "Têmpera das Adagas", "description": "+2 de dano em cada golpe das Adagas do Reverso.", "price": 60, "limit": 1, "requires": [], "requires_weapon": "l01_adagas_reverso", "damage": 2, "weapon": "l01_adagas_reverso"},
	# Tenda de Adiam: exploração e corpo.
	"mapa_rotas": {"name": "Mapa das rotas", "description": "O mapa passa a mostrar o contorno dos setores ainda não visitados.", "price": 30, "limit": 1, "requires": []},
	"amuleto_cornalina": {"name": "Amuleto de cornalina", "description": "+10 de vida máxima.", "price": 70, "limit": 1, "requires": [], "health": 10},
	"sandalias_caravana": {"name": "Sandálias de caravana", "description": "A esquiva recarrega 15% mais rápido.", "price": 55, "limit": 1, "requires": [], "dodge_scale": .85},
	# Não se vende: vem do altar da Ilha do Bennu (isle_story.gd), por `grant`.
	"pena_bennu": {"name": "Pena do Bennu", "description": "Mais uma carga de bálsamo (tecla R), que volta cheia nos santuários.", "price": 0, "limit": 1, "requires": [], "charge_bonus": "balsamo"}
}
const SHOPS := {
	"merit": ["jarro_balsamo", "mirra"],
	"nakht": ["pedra_amolar", "tempera_khopesh", "tempera_adagas"],
	"adiam": ["mapa_rotas", "amuleto_cornalina", "sandalias_caravana"]
}
const WEAPON_NAMES := {"l01_adagas_reverso": "das Adagas do Reverso"}
## Setores que o Mapa das rotas não entrega: segredos e o atalho do Eco.
const MAP_HIDDEN := ["secret", "echo_descent", "echo_gallery"]
## Itens que se gastam e voltam cheios no santuário, com o item que dá a capacidade.
const CHARGES := {"balsamo": "jarro_balsamo"}
const BALM_HEAL := 40
const MYRRH_BONUS := 15

static func owned(data: Dictionary, id: String) -> int:
	return int((data.get("purchases", {}) as Dictionary).get(id, 0))

## Motivo de a compra estar fechada, ou "" quando pode comprar.
static func blocker(data: Dictionary, id: String) -> String:
	if not ITEMS.has(id):
		return "Item desconhecido"
	var item: Dictionary = ITEMS[id]
	if owned(data, id) >= int(item["limit"]):
		return "Esgotado"
	for required in item["requires"]:
		if owned(data, required) <= 0:
			return "Precisa de: " + str(ITEMS[required]["name"])
	if item.has("requires_weapon") and not item["requires_weapon"] in data.get("weapons", []):
		return "Precisa " + str(WEAPON_NAMES.get(item["requires_weapon"], "da arma"))
	if not Economy.can_afford(data, int(item["price"])):
		return "Faltam %d %s" % [int(item["price"]) - Economy.coins(data), Economy.CURRENCY]
	return ""

## Valida, debita, registra a compra e entrega o efeito que mora no save.
static func purchase(data: Dictionary, id: String) -> bool:
	if blocker(data, id) != "":
		return false
	if not Economy.spend_coins(data, int(ITEMS[id]["price"])):
		return false
	if not data.get("purchases") is Dictionary:
		data["purchases"] = {}
	data["purchases"][id] = owned(data, id) + 1
	# Um jarro novo já vem cheio.
	for charge in CHARGES:
		if CHARGES[charge] == id:
			_set_charges(data, charge, charges(data, charge) + 1)
	return true

## Entrega um item sem cobrar (recompensa de missão), com a carga que ele traz.
static func grant(data: Dictionary, id: String) -> bool:
	if not ITEMS.has(id) or owned(data, id) >= int(ITEMS[id]["limit"]):
		return false
	if not data.get("purchases") is Dictionary:
		data["purchases"] = {}
	data["purchases"][id] = owned(data, id) + 1
	var charge := str(ITEMS[id].get("charge_bonus", ""))
	if CHARGES.has(charge):
		_set_charges(data, charge, charges(data, charge) + 1)
	return true

## Jarros comprados mais os itens que somam uma carga (a Pena do Bennu).
static func capacity(data: Dictionary, charge: String) -> int:
	var total := owned(data, CHARGES.get(charge, ""))
	for id in ITEMS:
		if str(ITEMS[id].get("charge_bonus", "")) == charge:
			total += owned(data, id)
	return total

static func charges(data: Dictionary, charge: String) -> int:
	return int((data.get("items", {}) as Dictionary).get(charge, 0))

static func balm_heal(data: Dictionary) -> int:
	return BALM_HEAL + (MYRRH_BONUS if owned(data, "mirra") > 0 else 0)

## Dano somado pelas melhorias compradas, para a arma equipada.
static func damage_bonus(data: Dictionary, weapon_id: String) -> int:
	var total := 0
	for id in ITEMS:
		var item: Dictionary = ITEMS[id]
		if owned(data, id) > 0 and item.has("damage") and str(item.get("weapon", weapon_id)) == weapon_id:
			total += int(item["damage"])
	return total

static func health_bonus(data: Dictionary) -> int:
	var total := 0
	for id in ITEMS:
		if owned(data, id) > 0: total += int(ITEMS[id].get("health", 0))
	return total

static func dodge_scale(data: Dictionary) -> float:
	var scale := 1.0
	for id in ITEMS:
		if owned(data, id) > 0: scale *= float(ITEMS[id].get("dodge_scale", 1.0))
	return scale

static func reveals_map(data: Dictionary) -> bool:
	return owned(data, "mapa_rotas") > 0

## Gasta uma carga, se houver.
static func spend_charge(data: Dictionary, charge: String) -> bool:
	if charges(data, charge) <= 0:
		return false
	_set_charges(data, charge, charges(data, charge) - 1)
	return true

## Santuário: todas as cargas voltam ao máximo comprado.
static func refill(data: Dictionary) -> void:
	for charge in CHARGES:
		_set_charges(data, charge, capacity(data, charge))

static func _set_charges(data: Dictionary, charge: String, amount: int) -> void:
	if not data.get("items") is Dictionary:
		data["items"] = {}
	data["items"][charge] = clampi(amount, 0, capacity(data, charge))

## Usado pelo save_store para recusar arquivos adulterados.
static func valid_state(purchases: Variant, items: Variant) -> bool:
	if not purchases is Dictionary or not items is Dictionary:
		return false
	for id in purchases:
		if not ITEMS.has(id) or not _whole(purchases[id]) or purchases[id] < 0 or purchases[id] > ITEMS[id]["limit"]:
			return false
	for charge in items:
		if not CHARGES.has(charge) or not _whole(items[charge]) or items[charge] < 0:
			return false
		if items[charge] > capacity({"purchases": purchases}, charge):
			return false
	return true

static func _whole(value: Variant) -> bool:
	return (value is int or value is float) and float(value) == floorf(float(value))
