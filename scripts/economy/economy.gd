extends RefCounted

## Recompensas de combate. Fragmentos de Nous continuam vindo da exploração; os
## inimigos deixam XP, que sobe o nível de Senu, e óbolos, a moeda das lojas.
## Todas as funções trabalham sobre o dicionário do save (DemoSaveStore.data).

const CURRENCY := "óbolos"
const MAX_LEVEL := 20
const MAX_XP := 999999
const MAX_COINS := 999999
## XP fixo e faixa de óbolos por arquétipo de inimigo (ver enemy.gd).
const REWARDS := {
	"runner": {"xp": 8, "coins": [3, 5]},
	"guard": {"xp": 10, "coins": [4, 7]},
	"lancer": {"xp": 13, "coins": [5, 8]},
	"keeper": {"xp": 16, "coins": [6, 10]},
	"boss": {"xp": 120, "coins": [55, 65]}
}
const HEALTH_PER_LEVEL := 5
## Um ponto de dano a cada dois níveis.
const LEVELS_PER_DAMAGE := 2
## Valores das moedas no chão: bronze, prata e ouro.
const COIN_VALUES := [25, 5, 1]
const MAX_COIN_PIECES := 8
const MAX_XP_ORBS := 6

static func reward_for(enemy_id: String, archetype: String, is_boss: bool) -> Dictionary:
	var table: Dictionary = REWARDS["boss"] if is_boss else REWARDS.get(archetype, REWARDS["guard"])
	# A semente vem do id: o mesmo inimigo sempre deixa a mesma quantia, o que
	# mantém o balanço previsível e os testes reproduzíveis.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(enemy_id)
	return {"xp": int(table["xp"]), "coins": rng.randi_range(table["coins"][0], table["coins"][1])}

static func xp_to_next(level: int) -> int:
	return 20 + 20 * level

static func level_for(xp: int) -> int:
	var level := 1
	var remaining := xp
	while level < MAX_LEVEL and remaining >= xp_to_next(level):
		remaining -= xp_to_next(level)
		level += 1
	return level

## XP já acumulado dentro do nível atual (x) e o necessário para o próximo (y).
static func level_progress(xp: int) -> Vector2i:
	var level := 1
	var remaining := xp
	while level < MAX_LEVEL and remaining >= xp_to_next(level):
		remaining -= xp_to_next(level)
		level += 1
	if level >= MAX_LEVEL:
		return Vector2i(1, 1)
	return Vector2i(remaining, xp_to_next(level))

static func health_bonus(level: int) -> int:
	return (maxi(1, level) - 1) * HEALTH_PER_LEVEL

static func damage_bonus(level: int) -> int:
	return (maxi(1, level) - 1) / LEVELS_PER_DAMAGE

static func xp(data: Dictionary) -> int:
	return int(data.get("xp", 0))

static func coins(data: Dictionary) -> int:
	return int(data.get("coins", 0))

static func level(data: Dictionary) -> int:
	return level_for(xp(data))

## Soma XP e devolve quantos níveis foram ganhos.
static func grant_xp(data: Dictionary, amount: int) -> int:
	var before := level(data)
	data["xp"] = mini(MAX_XP, xp(data) + maxi(0, amount))
	return level(data) - before

static func add_coins(data: Dictionary, amount: int) -> void:
	data["coins"] = mini(MAX_COINS, coins(data) + maxi(0, amount))

static func can_afford(data: Dictionary, price: int) -> bool:
	return price >= 0 and coins(data) >= price

static func spend_coins(data: Dictionary, price: int) -> bool:
	if not can_afford(data, price):
		return false
	data["coins"] = coins(data) - price
	return true

## Divide uma quantia em moedas para espalhar no chão, das maiores para as menores.
static func coin_pieces(total: int) -> Array[int]:
	var pieces: Array[int] = []
	var remaining := maxi(0, total)
	for value in COIN_VALUES:
		while remaining >= value and pieces.size() < MAX_COIN_PIECES - 1:
			pieces.append(value)
			remaining -= value
	if remaining > 0:
		pieces.append(remaining)
	return pieces

## Divide o XP em orbes de cerca de 5 pontos, no máximo MAX_XP_ORBS.
static func xp_pieces(total: int) -> Array[int]:
	var pieces: Array[int] = []
	if total <= 0:
		return pieces
	var count := clampi(ceili(total / 5.0), 1, MAX_XP_ORBS)
	for index in range(count):
		pieces.append(total / count + (1 if index < total % count else 0))
	return pieces
