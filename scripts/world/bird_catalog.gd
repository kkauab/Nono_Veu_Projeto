extends RefCounted

## Catálogo de Aves e Poleiros do Porto dos Esquecidos (docs/MUNDO_VIDA.md).
## Define espécies, poleiros presos a peças reais do cenário e as aves do mundo.
##
## Poleiro: `tile` diz onde fica; `prop` é a peça do cenário em que a ave pousa
## (a mais próxima desse tipo, a até 1,2 tile) e `offset` desloca os pés em
## pixels a partir do pivô da peça (espelhado com ela). `alt` é a altura dos pés
## acima do chão, medida no topo da arte (tools: qa/fauna_moradores/prop_tops.gd).
## Sem `prop`, a ave fica no chão (`alt` 0): só garças, na beira da água.
## Se a peça não estiver no mapa, o poleiro fica desligado.

const SPECIES := {
	"parrot": {
		"name": "Papagaio Esmeralda",
		"row": 0,
		# Só a sombra usa o tamanho: a arte é desenhada em escala 1, pixel por pixel.
		"size": Vector2(1.0, 1.0),
		"cruise_speed": 115.0,
		"cruise_alt": 62.0,
		"wing_rate": 8.0,
		"glide": 0.0,
		"districts": ["garden", "market", "p3"]
	},
	"seagull": {
		"name": "Gaivota do Porto",
		"row": 1,
		"size": Vector2(1.1, 1.1),
		"cruise_speed": 130.0,
		"cruise_alt": 78.0,
		"wing_rate": 5.5,
		"glide": 0.45,
		"districts": ["p1", "lower_dock", "copper_dock", "bridge", "wreck"]
	},
	"falcon": {
		"name": "Falcão de Hórus",
		"row": 2,
		"size": Vector2(1.2, 1.2),
		"cruise_speed": 150.0,
		"cruise_alt": 125.0,
		"wing_rate": 3.8,
		"glide": 0.6,
		"districts": ["hub", "beacon", "oracle", "bellcourt", "cloister"]
	},
	"heron": {
		"name": "Garça do Bennu",
		"row": 3,
		"size": Vector2(1.25, 1.25),
		"cruise_speed": 90.0,
		"cruise_alt": 50.0,
		"wing_rate": 4.0,
		"glide": 0.3,
		"districts": ["garden", "cistern", "reservoir"]
	}
}

## Poleiros catalogados vinculados a elementos reais do cenário
const PERCHES := [
	# --- JARDIM INUNDADO (copas das palmeiras e juncos do lago) ---
	{"id": "garden_palm_1", "district": "garden", "tile": Vector2(12, 21), "prop": "palm", "offset": Vector2(2, 0), "alt": 70.0, "species": ["parrot"], "facing": 1.0},
	{"id": "garden_palm_2", "district": "garden", "tile": Vector2(12, 29), "prop": "palm", "offset": Vector2(2, 0), "alt": 70.0, "species": ["parrot"], "facing": -1.0},
	{"id": "garden_palm_3", "district": "garden", "tile": Vector2(18, 28), "prop": "palm", "offset": Vector2(2, 0), "alt": 70.0, "species": ["parrot"], "facing": 1.0},
	{"id": "garden_palm_4", "district": "garden", "tile": Vector2(21, 21), "prop": "palm", "offset": Vector2(2, 0), "alt": 70.0, "species": ["parrot"], "facing": -1.0},
	{"id": "garden_palm_5", "district": "p3", "tile": Vector2(25, 28), "prop": "palm", "offset": Vector2(2, 0), "alt": 70.0, "species": ["parrot"], "facing": 1.0},
	# Papagaio agarrado aos caules do junco, acima da água.
	{"id": "garden_reeds_1", "district": "garden", "tile": Vector2(15, 23), "prop": "reeds", "offset": Vector2(2, 0), "alt": 10.0, "species": ["parrot"], "facing": 1.0},
	{"id": "garden_reeds_2", "district": "garden", "tile": Vector2(20, 27), "prop": "reeds", "offset": Vector2(2, 0), "alt": 10.0, "species": ["parrot"], "facing": -1.0},
	# Garças em pé no chão, na margem do lago (o junco fica na água, ao lado).
	{"id": "garden_shore_1", "district": "garden", "tile": Vector2(14.25, 23), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "garden_shore_2", "district": "garden", "tile": Vector2(19.25, 27), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "bennu_perch_sacred", "district": "garden", "tile": Vector2(17, 25), "alt": 0.0, "species": ["heron"], "facing": 1.0},

	# --- MERCADO DAS CINZAS (toldos, arco e telhados dos armazéns) ---
	{"id": "market_stall_north", "district": "market", "tile": Vector2(18, -1), "prop": "stall", "offset": Vector2(-4, 0), "alt": 62.0, "species": ["parrot"], "facing": 1.0},
	{"id": "market_stall_south", "district": "market", "tile": Vector2(24, 3.5), "prop": "stall", "offset": Vector2(-4, 0), "alt": 62.0, "species": ["parrot"], "facing": -1.0},
	{"id": "market_arch", "district": "market", "tile": Vector2(27, 1), "prop": "arch", "offset": Vector2(-4, 0), "alt": 82.0, "species": ["parrot"], "facing": 1.0},
	{"id": "market_warehouse", "district": "market", "tile": Vector2(20, -3.5), "prop": "warehouse", "offset": Vector2(0, 0), "alt": 108.0, "species": ["parrot"], "facing": -1.0},
	{"id": "market_warehouse_2", "district": "market", "tile": Vector2(25, -3.5), "prop": "warehouse", "offset": Vector2(0, 0), "alt": 108.0, "species": ["parrot"], "facing": 1.0},

	# --- CAIS DOS ESQUECIDOS (topo dos mastros e cabeços de amarração) ---
	{"id": "cais_mast_1", "district": "p1", "tile": Vector2(8, 5), "prop": "boat", "offset": Vector2(7, 0), "alt": 109.0, "species": ["seagull"], "facing": 1.0},
	{"id": "cais_mast_2", "district": "p1", "tile": Vector2(15, 5.5), "prop": "boat", "offset": Vector2(7, 0), "alt": 109.0, "species": ["seagull"], "facing": -1.0},
	{"id": "cais_bollard_1", "district": "p1", "tile": Vector2(6, 2), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},
	{"id": "cais_bollard_2", "district": "p1", "tile": Vector2(10, 2), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": -1.0},
	{"id": "cais_bollard_3", "district": "p1", "tile": Vector2(14, 2), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},

	# --- PONTE DOS BARQUEIROS ---
	{"id": "bridge_bollard_1", "district": "bridge", "tile": Vector2(31, 11), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},
	{"id": "bridge_bollard_2", "district": "bridge", "tile": Vector2(34, 16), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": -1.0},
	{"id": "bridge_mast", "district": "bridge", "tile": Vector2(37, 13), "prop": "boat", "offset": Vector2(7, 0), "alt": 109.0, "species": ["seagull"], "facing": -1.0},

	# --- EMBARCADOURO VELHO E CAIS DO COBRE ---
	{"id": "lower_bollard_1", "district": "lower_dock", "tile": Vector2(25, 32), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},
	{"id": "lower_bollard_2", "district": "lower_dock", "tile": Vector2(34, 32), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": -1.0},
	{"id": "lower_mast_1", "district": "lower_dock", "tile": Vector2(38, 39), "prop": "boat", "offset": Vector2(7, 0), "alt": 109.0, "species": ["seagull"], "facing": 1.0},
	{"id": "copper_warehouse", "district": "copper_dock", "tile": Vector2(48, 32.25), "prop": "warehouse", "offset": Vector2(0, 0), "alt": 108.0, "species": ["seagull"], "facing": -1.0},

	# --- CISTERNA E RESERVATÓRIO (garças no chão, junto ao junco da margem) ---
	{"id": "bennu_shore_1", "district": "cistern", "tile": Vector2(22, 34), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "cistern_reeds_2", "district": "cistern", "tile": Vector2(22, 37), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "bennu_shore_2", "district": "reservoir", "tile": Vector2(72, 33), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": -1.0},
	{"id": "reservoir_reeds_2", "district": "reservoir", "tile": Vector2(72, 30), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "reservoir_reeds_3", "district": "reservoir", "tile": Vector2(62, 36.6), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": 1.0},
	{"id": "reservoir_reeds_4", "district": "reservoir", "tile": Vector2(66.4, 32.8), "prop": "reeds", "offset": Vector2(-3, 0), "alt": 0.0, "species": ["heron"], "facing": -1.0},

	# --- RECIFE DO NAVIO ESQUECIDO (mastro do navio encalhado e cabeço do píer) ---
	{"id": "wreck_mast", "district": "wreck", "tile": Vector2(89.6, 71.8), "prop": "boat", "offset": Vector2(7, 0), "alt": 109.0, "species": ["seagull"], "facing": -1.0},
	{"id": "wreck_bollard", "district": "wreck", "tile": Vector2(72.8, 65.6), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},
	{"id": "copper_bollard_1", "district": "copper_dock", "tile": Vector2(42.6, 42.0), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": 1.0},
	{"id": "copper_bollard_2", "district": "copper_dock", "tile": Vector2(51.6, 42.0), "prop": "bollard", "alt": 12.0, "species": ["seagull"], "facing": -1.0},

	# --- ALTURAS SAGRADAS (Falcão de Hórus: pontas dos obeliscos e cúpula do farol) ---
	{"id": "hub_obelisk", "district": "hub", "tile": Vector2(-5, -4), "prop": "pillar", "alt": 66.0, "species": ["falcon"], "facing": -1.0},
	{"id": "beacon_pinnacle", "district": "beacon", "tile": Vector2(85, 24), "prop": "lighthouse", "alt": 130.0, "species": ["falcon"], "facing": 1.0},
	{"id": "oracle_obelisk", "district": "oracle", "tile": Vector2(75, 28), "prop": "pillar", "alt": 66.0, "species": ["falcon"], "facing": 1.0},
	{"id": "bellcourt_obelisk", "district": "bellcourt", "tile": Vector2(17, -35), "prop": "pillar", "alt": 66.0, "species": ["falcon"], "facing": 1.0},
	# Telhado do templo do Claustro (topo da arte a 105 px) e arco do braseiro de sinal do Farol.
	{"id": "cloister_temple", "district": "cloister", "tile": Vector2(-12.3, 5.7), "prop": "temple", "offset": Vector2(-4, 0), "alt": 105.0, "species": ["falcon"], "facing": 1.0},
	{"id": "beacon_arch", "district": "beacon", "tile": Vector2(81.4, 12.4), "prop": "arch", "offset": Vector2(-4, 0), "alt": 82.0, "species": ["falcon"], "facing": -1.0}
]

## Aves ativas no mundo
const BIRDS := [
	# Bando de Papagaios do Jardim Inundado
	{"id": "parrot_garden_1", "species": "parrot", "district": "garden", "home_perch": "garden_palm_1", "idle_range": Vector2(6.0, 12.0)},
	{"id": "parrot_garden_2", "species": "parrot", "district": "garden", "home_perch": "garden_palm_2", "idle_range": Vector2(5.0, 10.0)},
	{"id": "parrot_garden_3", "species": "parrot", "district": "garden", "home_perch": "garden_palm_4", "idle_range": Vector2(8.0, 14.0)},
	{"id": "parrot_market_1", "species": "parrot", "district": "market", "home_perch": "market_stall_north", "idle_range": Vector2(6.0, 11.0)},
	{"id": "parrot_market_2", "species": "parrot", "district": "market", "home_perch": "market_arch", "idle_range": Vector2(7.0, 13.0)},

	# Gaivotas do Cais e Marítimas
	{"id": "gull_cais_1", "species": "seagull", "district": "p1", "home_perch": "cais_mast_1", "idle_range": Vector2(5.0, 10.0)},
	{"id": "gull_cais_2", "species": "seagull", "district": "p1", "home_perch": "cais_bollard_2", "idle_range": Vector2(7.0, 12.0)},
	{"id": "gull_lower_1", "species": "seagull", "district": "lower_dock", "home_perch": "lower_bollard_1", "idle_range": Vector2(6.0, 11.0)},
	{"id": "gull_lower_2", "species": "seagull", "district": "lower_dock", "home_perch": "lower_mast_1", "idle_range": Vector2(8.0, 14.0)},
	{"id": "gull_copper", "species": "seagull", "district": "copper_dock", "home_perch": "copper_bollard_1", "idle_range": Vector2(6.0, 12.0)},
	{"id": "gull_wreck_1", "species": "seagull", "district": "wreck", "home_perch": "wreck_mast", "idle_range": Vector2(6.0, 12.0)},
	{"id": "gull_wreck_2", "species": "seagull", "district": "wreck", "home_perch": "wreck_bollard", "idle_range": Vector2(7.0, 13.0)},

	# Falcão Sagrado de Hórus (Guardião do Céu)
	{"id": "falcon_horus", "species": "falcon", "district": "hub", "home_perch": "hub_obelisk", "idle_range": Vector2(10.0, 18.0)},
	{"id": "falcon_cloister", "species": "falcon", "district": "cloister", "home_perch": "cloister_temple", "idle_range": Vector2(12.0, 20.0)},

	# Garças das Águas Internas (Cisterna e Jardim)
	{"id": "heron_bennu_1", "species": "heron", "district": "cistern", "home_perch": "bennu_shore_1", "idle_range": Vector2(8.0, 15.0)},
	{"id": "heron_bennu_2", "species": "heron", "district": "garden", "home_perch": "bennu_perch_sacred", "idle_range": Vector2(9.0, 16.0)},
	{"id": "heron_reservoir", "species": "heron", "district": "reservoir", "home_perch": "reservoir_reeds_3", "idle_range": Vector2(9.0, 16.0)}
]
