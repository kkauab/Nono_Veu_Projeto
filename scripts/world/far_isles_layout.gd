extends RefCounted

## Ilhas além da Baía das Garças (docs/MUNDO_PROPOSTA_2026-10-30.md), mais longe do
## porto que a Ilha do Bennu e só alcançáveis com o barco de Sabu:
## - "ibis": a Ilha do Íbis Afogado, a sudoeste, com um templo de escribas que afunda
##   na areia e o enigma das três estelas;
## - "wreck": o Recife do Navio Esquecido, a leste, com um navio mercante encalhado e
##   a carga espalhada pela areia.
## Mesmo contrato de isle_layout.gd: a costa é uma elipse com ondulações fixas, sem
## sorteio, e port_layout.gd lê os tiles daqui para as salas "ibis" e "wreck".

const ISLES := {
	"ibis": {
		"center": Vector2(12, 74), "radii": Vector2(9.6, 7.6),
		# [amplitude, frequência, fase] de cada ondulação da costa.
		"waves": [Vector3(.13, 3.0, 2.2), Vector3(.06, 5.0, .4)],
		"sand_from": .70, "inner": "garden",
		"rect": Rect2i(1, 63, 23, 20),
		"pier": Rect2i(12, 64, 2, 4),
		# Ponta do píer, onde Senu salta do barco (o "land" de Sea.DOCKS).
		"landing": Vector2(12.5, 64.1),
		# O pátio de lajes do templo e o lago sagrado no meio dele (sem piso).
		"plazas": [[Rect2i(6, 71, 8, 6), "crypt"]],
		"pools": [Rect2i(9, 73, 2, 2)],
	},
	"wreck": {
		"center": Vector2(80, 67), "radii": Vector2(10.5, 6.2),
		"waves": [Vector3(.10, 3.0, .7), Vector3(.08, 4.0, 2.9)],
		"sand_from": .58, "inner": "garden",
		"rect": Rect2i(65, 59, 27, 16),
		"pier": Rect2i(66, 66, 6, 2),
		"landing": Vector2(66.1, 66.5),
		"plazas": [],
		"pools": [],
	},
}
const COLORS := {
	"ibis": {"sand": Color("8a8270"), "garden": Color("56634d"), "crypt": Color("555a69"), "wood": Color("6f634a")},
	"wreck": {"sand": Color("988e74"), "garden": Color("5f6a4c"), "wood": Color("6a5e47")},
}

## Pontos, em tiles, das peças das missões (far_isles.gd).
const MARKERS := {
	"ibis_clue": Vector2(8.9, 72.2),
	"ibis_eye": Vector2(12.6, 72.4), "ibis_feather": Vector2(12.9, 75.9), "ibis_reed": Vector2(8.2, 76.4),
	"ibis_niche": Vector2(7.6, 75.0),
	"ibis_tablet": Vector2(10.6, 81.2),
	"wreck_log": Vector2(86.2, 70.4),
	"wreck_crate_1": Vector2(75.6, 62.6), "wreck_crate_2": Vector2(89.4, 67.4),
	"wreck_crate_3": Vector2(72.6, 69.4), "wreck_crate_4": Vector2(80.4, 71.4),
	"wreck_chest": Vector2(77.4, 66.4),
}

## Peças da folha isle_v1 (isle.gd as desenha, como na Ilha do Bennu): [peça, tile, sólida].
## A arquitetura de pedra (templo, estelas, muros, braseiros, caixas e o navio) vem
## da arte do porto e entra pelo gerador validado de port_dressing.gd (`PORT_PROPS`).
const PROPS := [
	# Ilha do Íbis Afogado.
	["column_broken", Vector2(15.4, 70.4), true], ["column_broken", Vector2(17.2, 74.6), true], ["column_broken", Vector2(15.0, 77.4), true],
	["rock_a", Vector2(4.6, 74.4), true], ["rock_b", Vector2(19.6, 70.4), true], ["rock_a", Vector2(8.8, 80.0), true],
	["rock_b", Vector2(11.6, 80.6), true], ["rock_b", Vector2(6.0, 69.0), true],
	["bush_a", Vector2(16.6, 72.4), true], ["bush_b", Vector2(18.6, 76.6), true], ["bush_a", Vector2(8.4, 78.4), true],
	["acacia", Vector2(17.8, 78.2), true],
	["reeds", Vector2(4.4, 71.4), false], ["reeds", Vector2(21.4, 73.6), false], ["reeds", Vector2(14.6, 68.0), false],
	["reeds", Vector2(9.4, 73.6), false], ["driftwood", Vector2(13.6, 81.4), false], ["driftwood", Vector2(5.6, 77.6), false],
	# Recife do Navio Esquecido.
	["rock_a", Vector2(74.4, 64.4), true], ["rock_b", Vector2(83.4, 62.6), true], ["rock_a", Vector2(87.6, 64.8), true],
	["rock_b", Vector2(88.4, 65.8), true], ["rock_a", Vector2(84.6, 71.6), true], ["rock_b", Vector2(71.4, 70.4), true],
	["bush_b", Vector2(80.4, 64.6), true], ["bush_a", Vector2(76.4, 69.6), true], ["bush_b", Vector2(84.4, 68.2), true],
	["bush_a", Vector2(82.6, 64.8), true], ["rock_a", Vector2(78.6, 70.6), true], ["acacia", Vector2(86.0, 66.4), true],
	["reeds", Vector2(73.6, 62.4), false], ["reeds", Vector2(88.4, 69.8), false], ["reeds", Vector2(77.4, 71.8), false],
	["driftwood", Vector2(82.6, 71.6), false], ["driftwood", Vector2(73.4, 67.8), false], ["driftwood", Vector2(87.4, 69.4), false],
	["amphora", Vector2(85.4, 71.2), false], ["net", Vector2(74.6, 70.6), false],
]
## Garças na água rasa.
const HERONS := [Vector2(2.6, 70.6), Vector2(21.6, 79.4), Vector2(91.2, 64.6)]


## Distância normalizada até a costa da ilha `id`: até 1.0 é terra.
static func coast(id: String, tile: Vector2) -> float:
	var isle: Dictionary = ISLES[id]
	var offset: Vector2 = (tile - isle["center"]) / isle["radii"]
	var reach := 1.0
	for wave: Vector3 in isle["waves"]:
		reach += wave.x * sin(wave.y * offset.angle() + wave.z)
	return offset.length() / reach


## Tema do chão no tile da ilha `id`, ou "" quando é água.
static func theme_at(id: String, tile: Vector2i) -> String:
	var isle: Dictionary = ISLES[id]
	if (isle["pier"] as Rect2i).has_point(tile):
		return "wood"
	for pool: Rect2i in isle["pools"]:
		if pool.has_point(tile):
			return ""
	var distance := coast(id, Vector2(tile))
	if distance > 1.0:
		return ""
	for plaza: Array in isle["plazas"]:
		if (plaza[0] as Rect2i).has_point(tile):
			return plaza[1]
	return "sand" if distance > float(isle["sand_from"]) else str(isle["inner"])


## Todos os tiles de chão da ilha `id`, com o tema de cada um.
static func tiles(id: String) -> Dictionary:
	var result := {}
	var rect: Rect2i = ISLES[id]["rect"]
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			var theme := theme_at(id, Vector2i(x, y))
			if theme != "":
				result[Vector2i(x, y)] = theme
	return result


## A ilha cujo retângulo contém o tile, ou "".
static func isle_at(tile: Vector2) -> String:
	for id in ISLES:
		if (ISLES[id]["rect"] as Rect2i).has_point(Vector2i(tile.round())):
			return id
	return ""


static func is_land(tile: Vector2) -> bool:
	var id := isle_at(tile)
	return id != "" and theme_at(id, Vector2i(tile.round())) != ""
