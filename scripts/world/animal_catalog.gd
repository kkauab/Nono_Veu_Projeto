extends RefCounted

## Catálogo de Animais Terrestres do Porto dos Esquecidos (docs/MUNDO_VIDA.md).
## Cães (Tesem Real e Guarda Anúbis) e Gatos (Mau Egípcio e Sagrado de Bastet).
## Define raças, comportamentos, pontos de repouso e rotas no mundo.
## `scale` só muda a sombra: a arte é desenhada em escala 1 (pixels nítidos).
## `flee_dist` é o raio em que Senu andando assusta; correndo vale 1,5×,
## atacando 2,5× (animal_life.gd). A casa fica em chão livre, longe de
## alavancas e de quem se fala (tests/animals_test.gd confere).

const BREEDS := {
	"cat_black": {
		"name": "Gato de Bastet",
		"type": "cat",
		"row": 0,
		"scale": Vector2(0.95, 0.95),
		"walk_speed": 45.0,
		"run_speed": 110.0,
		"flee_dist": 65.0
	},
	"cat_mau": {
		"name": "Gato Mau Egípcio",
		"type": "cat",
		"row": 1,
		"scale": Vector2(0.95, 0.95),
		"walk_speed": 48.0,
		"run_speed": 115.0,
		"flee_dist": 60.0
	},
	"dog_tesem": {
		"name": "Cão Tesem Real",
		"type": "dog",
		"row": 2,
		"scale": Vector2(1.05, 1.05),
		"walk_speed": 55.0,
		"run_speed": 125.0,
		"flee_dist": 40.0
	},
	"dog_guard": {
		"name": "Cão de Guarda Anúbis",
		"type": "dog",
		"row": 3,
		"scale": Vector2(1.12, 1.12),
		"walk_speed": 50.0,
		"run_speed": 120.0,
		"flee_dist": 45.0
	}
}

## Animais posicionados pelo mundo
const ANIMALS := [
	# Gatos do Porto
	{
		"id": "cat_fishmonger",
		"breed": "cat_mau",
		"district": "p1",
		"home_tile": Vector2(9, 2),
		"default_state": "sit",
		"facing": 1.0,
		"wander_radius": 2.5
	},
	{
		"id": "cat_market",
		"breed": "cat_black",
		"district": "market",
		# Dorme ao lado dos caixotes: em (22, 3) ficava dentro do caixote e, em
		# (21, 2), escondido logo atrás dele.
		"home_tile": Vector2(21, 3.6),
		"default_state": "sleep",
		"facing": -1.0,
		"wander_radius": 2.0
	},
	{
		"id": "cat_sanctuary",
		"breed": "cat_black",
		"district": "hub",
		"home_tile": Vector2(-3, -2),
		"default_state": "sit",
		"facing": 1.0,
		"wander_radius": 3.0
	},
	{
		"id": "cat_garden",
		"breed": "cat_mau",
		"district": "garden",
		# Em (18, 24) ficava em cima da alavanca do aqueduto.
		"home_tile": Vector2(16, 27),
		"default_state": "walk",
		"facing": 1.0,
		"wander_radius": 3.5
	},

	# Cães do Porto
	{
		"id": "dog_caravan",
		"breed": "dog_tesem",
		"district": "caravan",
		"home_tile": Vector2(43, 2),
		"default_state": "sit",
		"facing": -1.0,
		"wander_radius": 3.0
	},
	{
		"id": "dog_warehouse",
		"breed": "dog_guard",
		"district": "p2",
		"home_tile": Vector2(32, 2),
		"default_state": "walk",
		"facing": 1.0,
		"wander_radius": 3.5
	},
	{
		"id": "dog_pier",
		"breed": "dog_tesem",
		"district": "p1",
		# Um passo atrás do pescador do cais, não colado nele.
		"home_tile": Vector2(13, 1),
		"default_state": "sleep",
		"facing": 1.0,
		"wander_radius": 2.0
	},
	{
		"id": "dog_sentry",
		"breed": "dog_guard",
		"district": "p4",
		# Em (5, 20) ficava em cima da alavanca da guarita.
		"home_tile": Vector2(4, 21),
		"default_state": "sit",
		"facing": -1.0,
		"wander_radius": 2.5
	},
	{
		"id": "cat_cloister",
		"breed": "cat_mau",
		"district": "cloister",
		# Gato Mau, guardião do templo dos iniciados, entre o muro e o lago sagrado.
		"home_tile": Vector2(-11.6, 9.6),
		"default_state": "sleep",
		"facing": 1.0,
		"wander_radius": 2.5
	}
]
