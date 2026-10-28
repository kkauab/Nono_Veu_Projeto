extends RefCounted
## Dados da Árvore das Emanações. IDs e os três primeiros nós continuam
## compatíveis com as jornadas anteriores. Efeitos são reconstruídos do zero
## a partir dos IDs comprados, sem empilhar bônus ao carregar ou trocar armas.

const ORDER := [
	"vontade", "materia", "intelecto",
	"ritmo_lamina", "passo_etereo", "selo_mercurio",
	"lamina_ascendente", "pele_alabastro", "olho_escriba",
	"contra_ataque_agil", "reflexo_palavra", "esquiva_eterea",
	"convergencia_nous"
]

## ui_position usa a área do grafo normalizada de 0 a 1; a interface decide
## a escala. Nenhum nó opcional é requisito para a rota principal do mundo.
const NODES := {
	"vontade": {
		"name": "Mão firme", "branch": "Vontade", "branch_id": "vontade",
		"cost": 1, "requires": [], "effect": "damage_bonus",
		"description": "+4 de dano em todos os golpes.",
		"effects": {"damage_bonus": 4}, "ui_position": Vector2(.1, .9)
	},
	"materia": {
		"name": "Fôlego da pedra", "branch": "Matéria", "branch_id": "materia",
		"cost": 1, "requires": [], "effect": "health_bonus",
		"description": "+20 de vida máxima.",
		"effects": {"health_bonus": 20}, "ui_position": Vector2(.5, .9)
	},
	"intelecto": {
		"name": "Memória do éter", "branch": "Intelecto", "branch_id": "intelecto",
		"cost": 2, "requires": [], "effect": "power_cooldown",
		"description": "Poder da arma recarrega 20% mais rápido.",
		"effects": {"power_cooldown_scale": .8}, "ui_position": Vector2(.9, .9)
	},
	"ritmo_lamina": {
		"name": "Ritmo da lâmina", "branch": "Vontade", "branch_id": "vontade",
		"cost": 2, "requires": ["vontade"], "effect": "combo_rhythm",
		"description": "O terceiro golpe leve do combo causa +8 de dano. A janela entre golpes passa a 1,15 s.",
		"effects": {"combo_finisher_bonus": 8, "combo_window": 1.15}, "ui_position": Vector2(.1, .62)
	},
	"passo_etereo": {
		"name": "Passo Etéreo", "branch": "Matéria", "branch_id": "materia",
		"cost": 2, "requires": ["materia"], "effect": "dodge_training",
		"description": "A esquiva recarrega 20% mais rápido e protege por mais 0,06 s.",
		"effects": {"dodge_cooldown_scale": .8, "dodge_iframe_bonus": .06}, "ui_position": Vector2(.5, .62)
	},
	"selo_mercurio": {
		"name": "Selo de Mercúrio", "branch": "Intelecto", "branch_id": "intelecto",
		"cost": 3, "requires": ["intelecto"], "effect": "mercury_projectile",
		"description": "[C] Dispara um selo alquímico de 32 de dano. Recarga: 8 s.",
		"effects": {"mercury_unlocked": true, "mercury_damage": 32, "mercury_cooldown": 8.0}, "ui_position": Vector2(.9, .62)
	},
	"lamina_ascendente": {
		"name": "Lâmina Ascendente", "branch": "Vontade", "branch_id": "vontade",
		"cost": 3, "requires": ["ritmo_lamina"], "effect": "ascending_slash",
		"description": "[F] O golpe pesado do Khopesh torna-se ascendente: +20 de dano e +14 de alcance.",
		"effects": {"ascending_damage_bonus": 20, "ascending_range_bonus": 14}, "ui_position": Vector2(.02, .3)
	},
	"pele_alabastro": {
		"name": "Pele de alabastro", "branch": "Matéria", "branch_id": "materia",
		"cost": 3, "requires": ["passo_etereo"], "effect": "damage_reduction",
		"description": "Reduz em 15% o dano recebido.",
		"effects": {"damage_reduction": .15}, "ui_position": Vector2(.5, .34)
	},
	"olho_escriba": {
		"name": "Olho do escriba", "branch": "Intelecto", "branch_id": "intelecto",
		"cost": 2, "requires": ["selo_mercurio"], "effect": "optional_perception",
		"description": "Destaca coletas e pistas opcionais próximas enquanto você explora.",
		"effects": {"reveal_optional": true}, "ui_position": Vector2(.98, .3)
	},
	"contra_ataque_agil": {
		"name": "Contra-ataque ágil", "branch": "Vontade + Matéria", "branch_id": "hibrido",
		"cost": 2, "requires": ["ritmo_lamina", "passo_etereo"], "effect": "agile_counter",
		"description": "Aparar recarrega a esquiva e fortalece o próximo ataque leve em +12 de dano.",
		"effects": {"agile_counter": true, "riposte_bonus": 12}, "ui_position": Vector2(.27, .24)
	},
	"reflexo_palavra": {
		"name": "Reflexo da Palavra", "branch": "Vontade + Intelecto", "branch_id": "hibrido",
		"cost": 2, "requires": ["ritmo_lamina", "selo_mercurio"], "effect": "word_reflection",
		"description": "Aparar devolve uma palavra de 24 de dano ao agressor.",
		"effects": {"reflect_damage": 24}, "ui_position": Vector2(.5, .16)
	},
	"esquiva_eterea": {
		"name": "Esquiva etérea", "branch": "Matéria + Intelecto", "branch_id": "hibrido",
		"cost": 2, "requires": ["passo_etereo", "selo_mercurio"], "effect": "phase_dodge",
		"description": "Durante a esquiva, Senu atravessa inimigos. Paredes e portões continuam sólidos.",
		"effects": {"phase_dodge": true}, "ui_position": Vector2(.73, .24)
	},
	"convergencia_nous": {
		"name": "Convergência do Nous", "branch": "Convergência", "branch_id": "convergencia",
		"cost": 3, "requires": ["contra_ataque_agil", "reflexo_palavra", "esquiva_eterea"], "effect": "nous_convergence",
		"description": "[C] O Selo de Mercúrio atravessa até 3 inimigos e recarrega em 6 s.",
		"effects": {"mercury_pierce": 3, "mercury_cooldown": 6.0}, "ui_position": Vector2(.5, .0)
	}
}

static func has(owned: Array, id: String) -> bool:
	return NODES.has(id) and id in owned

static func requires_met(owned: Array, id: String) -> bool:
	if not NODES.has(id):
		return false
	for prerequisite in NODES[id]["requires"]:
		if prerequisite not in owned:
			return false
	return true

## O mesmo motivo alimenta a compra e a interface. Recusar nunca debita saldo.
static func blocker(data: Dictionary, id: String) -> String:
	if not NODES.has(id):
		return "Habilidade desconhecida"
	var owned: Array = data.get("skills", [])
	if id in owned:
		return "Já aprendida"
	var missing: Array[String] = []
	for prerequisite in NODES[id]["requires"]:
		if prerequisite not in owned:
			missing.append(str(NODES[prerequisite]["name"]))
	if not missing.is_empty():
		return "Precisa de: " + ", ".join(missing)
	var shortfall: int = int(NODES[id]["cost"]) - int(data.get("fragments", 0))
	if shortfall > 0:
		return "Faltam %d Fragmentos de Nous" % shortfall
	return ""

static func valid_owned(owned: Variant) -> bool:
	if not owned is Array or owned.size() > ORDER.size():
		return false
	var seen := {}
	for id in owned:
		if not id is String or not NODES.has(id) or seen.has(id):
			return false
		seen[id] = true
	for id in owned:
		if not requires_met(owned, id):
			return false
	return true

## A ordem explícita garante que Convergência substitua a recarga básica.
static func effects(owned: Array) -> Dictionary:
	var result := {
		"damage_bonus": 0, "health_bonus": 0, "power_cooldown_scale": 1.0,
		"combo_finisher_bonus": 0, "combo_window": 0.0,
		"ascending_damage_bonus": 0, "ascending_range_bonus": 0,
		"dodge_cooldown_scale": 1.0, "dodge_iframe_bonus": 0.0,
		"damage_reduction": 0.0, "mercury_unlocked": false,
		"mercury_damage": 32, "mercury_cooldown": 8.0, "mercury_pierce": 1,
		"reveal_optional": false, "agile_counter": false, "riposte_bonus": 0,
		"reflect_damage": 0, "phase_dodge": false
	}
	for id in ORDER:
		if id in owned:
			result.merge(NODES[id]["effects"], true)
	return result
