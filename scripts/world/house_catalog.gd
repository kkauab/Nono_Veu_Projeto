extends RefCounted

## Casas que Senu pode abrir. Cada interior é uma sala montada longe do Porto,
## no mesmo mundo, e só se chega a ela pela porta (docs/MUNDO_CASAS_LOJAS.md).
## Posições em tiles do mapa, como em port_layout.gd.

## Todo interior fica à direita desta linha, em pixels do mundo, além do mar
## desenhado pelo HarborWater (que vai até x = 4000).
const INTERIOR_MIN_X := 4400.0

const HOUSES := {
	"casa_guarda": {
		"name": "Casa da Guarda",
		"keeper": "Tarek",
		"rugs": [[Vector2(152.6, -8.1), Vector2(2.6, 1.5), Color("294b50")]],
		"district": "p4",
		# Exterior: o vão sob o toldo do armazém da Guarita, em (9, 18.5).
		"door": Vector2(8.6, 19.3),
		"outside": Vector2(8.2, 20.0),
		# Interior: 6 × 5 tiles; a soleira fica na parede de baixo à esquerda.
		"origin": Vector2i(150, -10),
		"size": Vector2i(6, 5),
		"theme": "stone",
		"color": Color("646453"),
		"wall": Color("6b6a58"),
		"exit": Vector2(152, -6),
		"spawn": Vector2(152, -6.75),
		"furniture": [
			["bed", Vector2(150.15, -9.0)],
			["tarek", Vector2(153.0, -9.0)],
			["table", Vector2(154.2, -7.7)],
			["crate", Vector2(155.0, -9.6)],
			["barrel", Vector2(154.9, -6.3)],
			["brazier", Vector2(152.6, -9.7)]
		],
		"fixtures": [
			["house_chest", "bau_guarda", Vector2(150.25, -7.0)],
			["house_note", "nota_guarda", Vector2(151.4, -9.65)],
			["questgiver", "missao_tarek", Vector2(153.0, -8.1)]
		]
	},
	"emporio_merit": {
		"name": "Empório de Merit",
		"rugs": [[Vector2(193.0, -6.6), Vector2(3.8, 1.4), Color("35534d")]],
		# Os dois armazéns do Mercado têm o santuário e a estela do mercador diante
		# da porta; o empório usa o armazém vizinho, em (30, -0.25).
		"district": "p2",
		"door": Vector2(29.6, 0.55),
		"outside": Vector2(29.2, 1.25),
		"origin": Vector2i(190, -10),
		"size": Vector2i(7, 6),
		"theme": "mosaic",
		"color": Color("5e6557"),
		"wall": Color("7d725b"),
		"exit": Vector2(193, -5),
		"spawn": Vector2(193, -5.75),
		"furniture": [
			["shelf", Vector2(191.3, -10.3)],
			["shelf", Vector2(193.0, -10.3)],
			["shelf", Vector2(194.7, -10.3)],
			["merit", Vector2(193.4, -8.45)],
			["counter", Vector2(193.0, -8.0)],
			["brazier", Vector2(190.35, -9.6)],
			["amphora", Vector2(196.05, -8.6)],
			["amphora", Vector2(196.1, -7.7)],
			["amphora", Vector2(195.4, -9.4)],
			["crate", Vector2(190.5, -5.6)]
		],
		"fixtures": [
			["shopkeeper", "loja_merit", Vector2(193.0, -7.45)]
		],
		"shop": "merit",
		"keeper": "Merit",
		"greeting": "Não lembro o nome destes frascos, mas reconheço cada um pelo cheiro. O bálsamo fecha feridas; a mirra o deixa mais forte."
	},
	"forja_nakht": {
		"name": "Forja de Nakht",
		"rugs": [[Vector2(235.3, -6.4), Vector2(2.8, 1.1), Color("493b2b")]],
		"district": "kilns",
		# O armazém do centro dos Fornos, em (65, -2.75).
		"door": Vector2(64.6, -1.95),
		"outside": Vector2(64.2, -1.25),
		"origin": Vector2i(232, -10),
		"size": Vector2i(8, 6),
		"theme": "stone",
		"color": Color("4f4a42"),
		"wall": Color("5f564a"),
		"exit": Vector2(235, -5),
		"spawn": Vector2(235, -5.75),
		"furniture": [
			["furnace", Vector2(233.5, -10.0)],
			["rack", Vector2(237.6, -10.3)],
			["nakht", Vector2(235.1, -8.7)],
			["anvil", Vector2(235.0, -7.8)],
			["tub", Vector2(238.5, -7.4)],
			["coal", Vector2(232.5, -6.4)],
			["barrel", Vector2(238.6, -5.6)]
		],
		"fixtures": [
			["shopkeeper", "loja_nakht", Vector2(235.0, -7.1)]
		],
		"shop": "nakht",
		"keeper": "Nakht",
		"greeting": "O forno não apaga desde que eu cheguei, e não lembro como apagá-lo. Pelo menos o bronze ainda me obedece."
	},
	"tenda_adiam": {
		"name": "Tenda de Adiam",
		"district": "caravan",
		# O armazém do Portão das Caravanas, em (48, -2.75).
		"door": Vector2(47.6, -1.95),
		"outside": Vector2(47.2, -1.25),
		"origin": Vector2i(276, -10),
		"size": Vector2i(7, 5),
		"theme": "sand",
		"color": Color("7a6c53"),
		"wall": Color("8a5a3a"),
		"wall_style": "fabric",
		"rugs": [[Vector2(279, -7.6), Vector2(3.2, 1.8), Color("7a3a2c")]],
		"exit": Vector2(278, -6),
		"spawn": Vector2(278, -6.75),
		"furniture": [
			["easel", Vector2(277.0, -8.9)],
			["adiam", Vector2(278.92, -8.87)],
			["trade_chest", Vector2(279.0, -8.2)],
			["cords", Vector2(281.4, -10.3)],
			["saddle", Vector2(276.5, -6.5)],
			["crate", Vector2(281.9, -6.5)],
			["brazier", Vector2(276.35, -9.6)]
		],
		"fixtures": [
			["shopkeeper", "loja_adiam", Vector2(279.0, -7.55)]
		],
		"shop": "adiam",
		"keeper": "Adiam",
		"greeting": "Cada nó destes cordões é uma rota. Não confio na minha memória, então confio nos nós."
	}
}

const CHEST_REWARDS := {"bau_guarda": 30}
const NOTES := {
	"nota_guarda": ["O turno esquecido", "Rondei a guarita três vezes antes de lembrar por quê. Deixo escrito para não perder de novo: o soldo da guarda está no baú do canto.\n\nSe eu não voltar para buscar, é porque já não sei que ele é meu.\n\n— Bilhete fictício preso à parede"]
}

static func is_interior_point(point: Vector2) -> bool:
	return point.x >= INTERIOR_MIN_X

static func tiles_of(house: Dictionary) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var origin: Vector2i = house["origin"]
	var size: Vector2i = house["size"]
	for x in range(origin.x, origin.x + size.x):
		for y in range(origin.y, origin.y + size.y):
			tiles.append(Vector2i(x, y))
	return tiles
