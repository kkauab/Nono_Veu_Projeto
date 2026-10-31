extends Node2D
class_name PortLayout
const Art = preload("res://scripts/world/port_art.gd")
const WaterLife = preload("res://scripts/world/water_life.gd")
const IsleLayout = preload("res://scripts/world/isle_layout.gd")
const CloisterLayout = preload("res://scripts/world/cloister_layout.gd")
const FarIslesLayout = preload("res://scripts/world/far_isles_layout.gd")
## Onde o mar é desenhado. Interiores ficam fora dele, sobre fundo próprio.
const SEA_RECT := Rect2(-4000, -2400, 8000, 6000)

const HALF_TILE := Vector2(32, 16)
const ROOMS := [
	{"id": "hub", "label": "Primeira Palavra", "name": "Santuário da Primeira Palavra", "rect": Rect2i(-5, -5, 9, 8), "color": Color("58645b"), "theme": "mosaic"},
	{"id": "p1", "label": "Cais dos Esquecidos", "name": "Cais dos Esquecidos", "rect": Rect2i(5, -2, 12, 5), "color": Color("77664c"), "theme": "wood"},
	{"id": "market", "label": "Mercado das Cinzas", "name": "Mercado das Cinzas", "rect": Rect2i(17, -5, 10, 10), "color": Color("6b6554"), "theme": "sand"},
	{"id": "p2", "label": "Armazém das Vozes", "name": "Armazém das Vozes", "rect": Rect2i(28, -2, 11, 11), "color": Color("565e59"), "theme": "stone"},
	{"id": "bridge", "label": "Ponte dos Barqueiros", "name": "Ponte dos Barqueiros", "rect": Rect2i(31, 9, 4, 10), "color": Color("6b5c45"), "theme": "wood"},
	{"id": "p3", "label": "Pátio das Memórias", "name": "Pátio das Memórias", "rect": Rect2i(24, 19, 15, 11), "color": Color("5e6557"), "theme": "mosaic"},
	{"id": "secret", "label": "Alcova do Escriba", "name": "Alcova do Escriba", "rect": Rect2i(39, 22, 7, 8), "color": Color("555563"), "theme": "crypt"},
	{"id": "lower_dock", "label": "Embarcadouro Velho", "name": "Embarcadouro Velho", "rect": Rect2i(24, 31, 13, 5), "color": Color("6f634a"), "theme": "wood"},
	{"id": "garden", "label": "Jardim Inundado", "name": "Jardim Inundado", "rect": Rect2i(12, 20, 11, 10), "color": Color("58634f"), "theme": "garden"},
	{"id": "p4", "label": "Guarita do Retorno", "name": "Guarita do Retorno", "rect": Rect2i(2, 17, 10, 12), "color": Color("646453"), "theme": "stone"},
	{"id": "b1", "label": "Guarita do Retorno", "name": "Guarita do Retorno", "rect": Rect2i(-12, 16, 13, 15), "color": Color("62544f"), "theme": "arena"},
	{"id": "a02", "label": "Catacumbas do Eco", "name": "Catacumbas do Eco · limiar", "rect": Rect2i(-25, 20, 10, 11), "color": Color("444854"), "theme": "crypt"},
	{"id": "aqueduct", "label": "Aqueduto Silencioso", "name": "Aqueduto Silencioso", "rect": Rect2i(20, 5, 2, 15), "color": Color("56635c"), "theme": "aqueduct"},
	{"id": "pilgrim", "label": "Peregrinos", "name": "Escadaria dos Peregrinos", "rect": Rect2i(16, -20, 18, 13), "color": Color("766c58"), "theme": "sand"},
	{"id": "bellcourt", "label": "Três Sinos", "name": "Praça dos Três Sinos", "rect": Rect2i(16, -36, 18, 15), "color": Color("707367"), "theme": "mosaic"},
	{"id": "archive", "label": "Arquivo Velado", "name": "Arquivo dos Nomes Velados", "rect": Rect2i(-4, -36, 19, 15), "color": Color("5a625d"), "theme": "crypt"},
	{"id": "scriptorium", "label": "Escribas", "name": "Pátio dos Escribas", "rect": Rect2i(-4, -20, 19, 13), "color": Color("747363"), "theme": "mosaic"},
	{"id": "caravan", "label": "Caravanas", "name": "Portão das Caravanas", "rect": Rect2i(40, -4, 16, 14), "color": Color("7a6c53"), "theme": "sand"},
	{"id": "kilns", "label": "Fornos de Bronze", "name": "Fornos do Bronze Esquecido", "rect": Rect2i(57, -4, 16, 14), "color": Color("77614c"), "theme": "stone"},
	{"id": "salt_road", "label": "Estrada do Sal", "name": "Estrada das Cargas de Sal", "rect": Rect2i(57, 11, 16, 15), "color": Color("8b8168"), "theme": "sand"},
	{"id": "beacon", "label": "Farol Partido", "name": "Terraço do Farol Partido", "rect": Rect2i(74, 11, 14, 15), "color": Color("747366"), "theme": "stone"},
	{"id": "oracle", "label": "Observatório", "name": "Observatório das Estrelas Mortas", "rect": Rect2i(74, 27, 14, 15), "color": Color("565b69"), "theme": "crypt"},
	{"id": "reservoir", "label": "Reservatório", "name": "Reservatório das Duas Margens", "rect": Rect2i(57, 27, 16, 15), "color": Color("586a62"), "theme": "aqueduct"},
	{"id": "copper_dock", "label": "Cais do Cobre", "name": "Cais do Cobre e das Ânforas", "rect": Rect2i(40, 31, 16, 12), "color": Color("75644e"), "theme": "wood"},
	{"id": "cistern", "label": "Cisterna", "name": "Cisterna das Duas Fontes", "rect": Rect2i(12, 31, 11, 14), "color": Color("5f7266"), "theme": "aqueduct"},
	{"id": "sluice", "label": "Comportas", "name": "Galeria das Comportas", "rect": Rect2i(0, 31, 11, 14), "color": Color("637266"), "theme": "stone"},
	{"id": "buried", "label": "Santuário Soterrado", "name": "Santuário Soterrado da Maré", "rect": Rect2i(-12, 32, 11, 13), "color": Color("53615d"), "theme": "crypt"},
	# The echo route is reached only from the Catacombs; its grate faces the sanctuary.
	{"id": "echo_descent", "label": "Descida do Eco", "name": "Descida do Eco", "rect": Rect2i(-19, 3, 3, 17), "color": Color("4b4f5c"), "theme": "crypt", "generated": false},
	{"id": "echo_gallery", "label": "Galeria do Eco", "name": "Galeria do Eco", "rect": Rect2i(-19, -4, 13, 7), "color": Color("4f5260"), "theme": "crypt", "generated": false},
	# Só se chega de barco (sea.gd). O chão segue a costa de isle_layout.gd, não o
	# retângulo; "outline" é o contorno desenhado no mapa.
	{"id": "isle", "label": "Ilha do Bennu", "name": "Ilha do Bennu", "rect": Rect2i(35, 59, 22, 19), "color": Color("5e6b4f"), "theme": "garden", "generated": false, "shape": "isle",
		"outline": [Vector2(57.2, 70.0), Vector2(55.8, 72.7), Vector2(53.2, 74.5), Vector2(50.9, 76.2), Vector2(48.1, 77.2), Vector2(45.0, 77.2), Vector2(41.8, 77.5), Vector2(37.9, 77.4), Vector2(35.2, 75.4), Vector2(35.4, 72.4), Vector2(36.2, 70.0), Vector2(35.8, 67.7), Vector2(36.2, 65.1), Vector2(38.5, 63.2), Vector2(41.6, 62.0), Vector2(44.0, 61.4), Vector2(44.0, 58.6), Vector2(46.0, 58.6), Vector2(46.0, 61.4), Vector2(48.3, 62.2), Vector2(50.3, 64.5), Vector2(52.2, 66.0), Vector2(55.3, 67.4)]},
	# Gustavo, 30/10/2026 (docs/MUNDO_PROPOSTA_2026-10-30.md). O claustro amplia o
	# santuário onde Senu desperta; o chão vem de cloister_layout.gd.
	{"id": "cloister", "label": "Iniciados", "name": "Claustro dos Iniciados", "rect": Rect2i(-14, 4, 13, 10), "color": Color("5f6b5c"), "theme": "mosaic", "generated": false, "shape": "cloister"},
	# Ilhas além da baía, só de barco; o chão segue far_isles_layout.gd.
	{"id": "ibis", "label": "Ilha do Íbis", "name": "Ilha do Íbis Afogado", "rect": Rect2i(1, 63, 23, 20), "color": Color("6a6a5c"), "theme": "sand", "generated": false, "shape": "ibis",
		"outline": [Vector2(22.8, 74.0), Vector2(22.1, 76.0), Vector2(20.1, 77.4), Vector2(18.0, 78.2), Vector2(16.5, 79.2), Vector2(15.2, 80.8), Vector2(13.3, 82.2), Vector2(10.7, 82.6), Vector2(8.3, 81.8), Vector2(6.4, 80.4), Vector2(4.9, 79.0), Vector2(3.8, 77.4), Vector2(3.5, 75.7), Vector2(3.6, 74.0), Vector2(3.5, 72.3), Vector2(3.1, 70.3), Vector2(3.6, 68.1), Vector2(5.6, 66.7), Vector2(8.4, 66.6), Vector2(11.5, 67.6), Vector2(11.5, 63.5), Vector2(13.5, 63.5), Vector2(13.5, 67.6), Vector2(15.1, 67.6), Vector2(17.3, 67.9), Vector2(19.2, 68.9), Vector2(20.8, 70.3), Vector2(22.1, 72.0)]},
	{"id": "wreck", "label": "Navio Esquecido", "name": "Recife do Navio Esquecido", "rect": Rect2i(65, 59, 27, 16), "color": Color("7a745e"), "theme": "sand", "generated": false, "shape": "wreck",
		"outline": [Vector2(91.4, 67.0), Vector2(90.7, 68.6), Vector2(89.3, 69.9), Vector2(87.8, 71.1), Vector2(85.9, 72.1), Vector2(83.7, 72.7), Vector2(81.2, 72.9), Vector2(78.8, 72.7), Vector2(76.5, 72.5), Vector2(73.9, 72.2), Vector2(71.4, 71.5), Vector2(69.5, 70.3), Vector2(71.0, 67.5), Vector2(65.5, 67.5), Vector2(65.5, 65.5), Vector2(71.0, 65.5), Vector2(72.2, 64.6), Vector2(72.6, 63.1), Vector2(73.5, 61.5), Vector2(75.6, 60.2), Vector2(78.5, 59.9), Vector2(81.3, 60.7), Vector2(83.4, 61.8), Vector2(85.1, 62.6), Vector2(87.1, 63.3), Vector2(89.3, 64.1), Vector2(90.9, 65.4)]}
]
const ROOM_LINKS := [
	["hub", "p1"], ["p1", "market"], ["market", "p2"], ["p2", "bridge"],
	["bridge", "p3"], ["p3", "garden"], ["garden", "p4"], ["p4", "b1"], ["b1", "a02"],
	["p3", "secret"], ["p3", "lower_dock"], ["market", "aqueduct"],
	["aqueduct", "garden", "aqueduct"], ["p4", "hub", "shortcut"],
	["market", "pilgrim"], ["pilgrim", "bellcourt"], ["bellcourt", "archive"],
	["archive", "scriptorium"], ["scriptorium", "hub"], ["scriptorium", "pilgrim"],
	["p2", "caravan"], ["caravan", "kilns"], ["kilns", "salt_road"],
	["salt_road", "beacon"], ["beacon", "oracle"], ["oracle", "reservoir"],
	["reservoir", "copper_dock"], ["copper_dock", "lower_dock"],
	["garden", "cistern"], ["cistern", "sluice"], ["sluice", "buried"],
	["a02", "echo_descent"], ["echo_descent", "echo_gallery"], ["echo_gallery", "hub", "echo"],
	["lower_dock", "isle", "sea_route"],
	["hub", "cloister"], ["lower_dock", "ibis", "sea_route"], ["isle", "wreck", "sea_route"]
]
const CONNECTORS := [
	{"rect": Rect2i(4, 0, 1, 2), "room": "p1", "theme": "stone", "color": Color("626456")},
	{"rect": Rect2i(27, 0, 1, 3), "room": "p2", "theme": "stone", "color": Color("5b6157")},
	{"rect": Rect2i(23, 23, 1, 3), "room": "garden", "theme": "garden", "color": Color("5b6655")},
	{"rect": Rect2i(29, 30, 3, 1), "room": "lower_dock", "theme": "wood", "color": Color("756449")},
	{"rect": Rect2i(1, 21, 1, 4), "room": "p4", "theme": "stone", "color": Color("676552")},
	{"rect": Rect2i(-15, 24, 3, 3), "room": "a02", "theme": "crypt", "color": Color("4e4d59")},
	{"rect": Rect2i(0, 3, 3, 14), "room": "hub", "theme": "aqueduct", "color": Color("566359")},
	{"rect": Rect2i(25, 36, 2, 3), "room": "lower_dock", "theme": "wood", "color": Color("6c6047")},
	{"rect": Rect2i(33, 36, 2, 3), "room": "lower_dock", "theme": "wood", "color": Color("71634a")},
	{"rect": Rect2i(20, -7, 3, 2), "room": "pilgrim", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(24, -21, 3, 1), "room": "bellcourt", "theme": "mosaic", "color": Color("777463")},
	{"rect": Rect2i(15, -30, 1, 4), "room": "archive", "theme": "crypt", "color": Color("646d65")},
	{"rect": Rect2i(4, -21, 3, 1), "room": "scriptorium", "theme": "mosaic", "color": Color("777463")},
	{"rect": Rect2i(15, -14, 1, 3), "room": "pilgrim", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(0, -7, 3, 2), "room": "hub", "theme": "stone", "color": Color("777463")},
	{"rect": Rect2i(39, 1, 1, 4), "room": "caravan", "theme": "sand", "color": Color("84775c")},
	{"rect": Rect2i(56, 2, 1, 4), "room": "kilns", "theme": "stone", "color": Color("766751")},
	{"rect": Rect2i(63, 10, 3, 1), "room": "salt_road", "theme": "sand", "color": Color("84775c")},
	{"rect": Rect2i(73, 18, 1, 4), "room": "beacon", "theme": "stone", "color": Color("766751")},
	{"rect": Rect2i(79, 26, 3, 1), "room": "oracle", "theme": "crypt", "color": Color("626575")},
	{"rect": Rect2i(73, 34, 1, 4), "room": "reservoir", "theme": "aqueduct", "color": Color("61736b")},
	{"rect": Rect2i(56, 34, 1, 4), "room": "copper_dock", "theme": "wood", "color": Color("77634c")},
	{"rect": Rect2i(37, 33, 3, 3), "room": "copper_dock", "theme": "wood", "color": Color("77634c")},
	{"rect": Rect2i(16, 30, 3, 1), "room": "cistern", "theme": "aqueduct", "color": Color("61736b")},
	{"rect": Rect2i(11, 37, 1, 3), "room": "sluice", "theme": "stone", "color": Color("61736b")},
	{"rect": Rect2i(-1, 37, 1, 3), "room": "buried", "theme": "crypt", "color": Color("61736b")},
	{"rect": Rect2i(-6, -1, 1, 2), "room": "echo_gallery", "theme": "crypt", "color": Color("4f5260")},
	# Boca do Claustro dos Iniciados, na borda sul do santuário (x -5..-2).
	{"rect": Rect2i(-5, 3, 4, 1), "room": "cloister", "theme": "mosaic", "color": Color("5f6b5c")}
]
## Broad, level thresholds support both feet of the entrance arches.
## They are away from the locked shortcut/boss corridors, preserving their seals.
const LANDINGS := [
	{"rect": Rect2i(3, -1, 3, 4), "room": "p1", "theme": "stone", "color": Color("626456")},
	{"rect": Rect2i(26, -1, 3, 5), "room": "p2", "theme": "stone", "color": Color("5b6157")}
]
const WATER_HOLES := [Rect2i(32, 3, 2, 2), Rect2i(30, 23, 3, 3), Rect2i(15, 22, 3, 3), Rect2i(20, 26, 2, 3), Rect2i(-1, 16, 2, 3), Rect2i(0, 31, 1, 1), Rect2i(15, 35, 4, 4), Rect2i(62, 33, 5, 4)]
const MARKERS := {
	"hub_spawn": Vector2(-1, -1), "hub": Vector2(-3, -3), "hub_shrine": Vector2(-3, -3),
	"s1": Vector2(7, 20), "market_rest": Vector2(24, -3), "inscricao": Vector2(-3, 0),
	"adagas": Vector2(42, 26), "alavanca": Vector2(5, 20), "alavanca_aqueduct": Vector2(18, 24),
	"selo": Vector2(-12, 25), "nous_cais": Vector2(14, -1), "nous_patio": Vector2(36, 27),
	"nous_arena": Vector2(-9, 28), "nous_market": Vector2(25, 3), "nous_garden": Vector2(13, 28),
	"nous_dock": Vector2(35, 34), "nous_aqueduct": Vector2(20, 12), "cache": Vector2(44, 28),
	"memory_market": Vector2(19, -3), "memory_dock": Vector2(26, 37),
	"capture_market": Vector2(23, 0), "capture_cais": Vector2(11, 0), "capture_arena": Vector2(-4, 25),
	"caravan_rest": Vector2(52, -1), "cistern_rest": Vector2(20, 33),
	"bells_clue": Vector2(5, -28), "bell_moon": Vector2(22, -30), "bell_sun": Vector2(27, -30), "bell_star": Vector2(25, -26),
	"water_clue": Vector2(18, 41), "valve_two": Vector2(3, 35), "valve_three": Vector2(7, 35), "valve_drain": Vector2(5, 41), "valve_reset": Vector2(9, 38), "water_altar": Vector2(-6, 38),
	"stars_clue": Vector2(80, 16), "star_sun": Vector2(78, 34), "star_moon": Vector2(83, 34), "star_eye": Vector2(80, 39), "stars_altar": Vector2(85, 39),
	"sealed_entry": Vector2(3, 23), "nous_archive": Vector2(-1, -33), "nous_kilns": Vector2(69, 7),
	"nous_beacon": Vector2(85, 13), "nous_reservoir": Vector2(60, 39), "nous_buried": Vector2(-10, 42),
	"memory_pilgrim": Vector2(30, -17), "memory_copper": Vector2(48, 40),
	"capture_bells": Vector2(25, -28), "capture_oracle": Vector2(80, 35), "capture_cistern": Vector2(20, 39), "capture_caravan": Vector2(47, 3),
	"alavanca_eco": Vector2(-8, -1), "capture_echo": Vector2(-9, 1)
}
const GATES := {
	"shortcut": {"a": Vector2(-.5, 3.5), "b": Vector2(2.5, 3.5)},
	"aqueduct": {"a": Vector2(19.5, 19.5), "b": Vector2(21.5, 19.5)},
	"boss": {"a": Vector2(-12.5, 23.5), "b": Vector2(-12.5, 26.5)},
	"boss_entry": {"a": Vector2(.5, 20.5), "b": Vector2(.5, 24.5)},
	"echo": {"a": Vector2(-5.5, -1.5), "b": Vector2(-5.5, .5)}
}
## A rota inicial (Cais, Mercado e Armazém) ensina com guardas, de golpe lento; daí
## em diante cada lugar tem o seu tipo: o lanceiro na ponte estreita, o guardião
## na alcova secreta das Adagas, o corredor errante no jardim e o lanceiro da
## guarita antes do Porteiro (docs/MUNDO_PROPOSTA_2026-10-30.md). Os ids não mudam.
const ENEMY_SPAWNS := [
	{"id": "marinheiro_01", "tile": Vector2(11, 1), "boss": false},
	{"id": "vigia_mercado", "tile": Vector2(22, 2), "boss": false},
	{"id": "carregador_armazem", "tile": Vector2(36, 5), "boss": false},
	{"id": "barqueiro_ponte", "tile": Vector2(33, 15), "boss": false, "archetype": "lancer"},
	{"id": "marinheiro_02", "tile": Vector2(36, 26), "boss": false},
	{"id": "copista_alcova", "tile": Vector2(42, 24), "boss": false, "archetype": "keeper"},
	{"id": "errante_jardim", "tile": Vector2(19, 28), "boss": false, "archetype": "runner"},
	{"id": "vigia_guarita", "tile": Vector2(9, 25), "boss": false, "archetype": "lancer"},
	{"id": "porteiro", "tile": Vector2(-6, 23), "boss": true},
	{"id": "errante_escriba_01", "tile": Vector2(5, -11), "archetype": "runner"},
	{"id": "errante_escriba_02", "tile": Vector2(11, -17), "archetype": "guard"},
	{"id": "guardiao_arquivo_01", "tile": Vector2(4, -29), "archetype": "keeper"},
	{"id": "guardiao_arquivo_02", "tile": Vector2(11, -24), "archetype": "guard"},
	{"id": "sentinela_sinos_01", "tile": Vector2(20, -33), "archetype": "lancer"},
	{"id": "sentinela_sinos_02", "tile": Vector2(31, -25), "archetype": "guard"},
	{"id": "peregrino_vazio_01", "tile": Vector2(21, -16), "archetype": "runner"},
	{"id": "peregrino_vazio_02", "tile": Vector2(30, -10), "archetype": "guard"},
	{"id": "caravaneiro_01", "tile": Vector2(45, 3), "archetype": "lancer"},
	{"id": "caravaneiro_02", "tile": Vector2(51, 7), "archetype": "guard"},
	{"id": "fundidor_01", "tile": Vector2(61, 1), "archetype": "keeper"},
	{"id": "fundidor_02", "tile": Vector2(68, 6), "archetype": "guard"},
	{"id": "corredor_sal_01", "tile": Vector2(62, 15), "archetype": "runner"},
	{"id": "corredor_sal_02", "tile": Vector2(69, 22), "archetype": "lancer"},
	{"id": "vigia_farol_01", "tile": Vector2(78, 14), "archetype": "lancer"},
	{"id": "vigia_farol_02", "tile": Vector2(84, 22), "archetype": "guard"},
	{"id": "oraculo_vazio_01", "tile": Vector2(77, 29), "archetype": "keeper"},
	{"id": "oraculo_vazio_02", "tile": Vector2(85, 37), "archetype": "runner"},
	{"id": "aguadeiro_01", "tile": Vector2(62, 31), "archetype": "guard"},
	{"id": "aguadeiro_02", "tile": Vector2(69, 39), "archetype": "lancer"},
	{"id": "cobreiro_01", "tile": Vector2(45, 35), "archetype": "guard"},
	{"id": "cobreiro_02", "tile": Vector2(52, 40), "archetype": "runner"},
	{"id": "cisterna_01", "tile": Vector2(14, 35), "archetype": "runner"},
	{"id": "cisterna_02", "tile": Vector2(20, 42), "archetype": "guard"},
	{"id": "comporta_01", "tile": Vector2(3, 39), "archetype": "keeper"},
	{"id": "comporta_02", "tile": Vector2(8, 42), "archetype": "lancer"},
	{"id": "soterrado_01", "tile": Vector2(-8, 34), "archetype": "keeper"},
	{"id": "soterrado_02", "tile": Vector2(-3, 42), "archetype": "guard"},
	{"id": "cais_patrol", "tile": Vector2(30, 33), "archetype": "guard"},
	# Ilha do Bennu: os três Esquecidos da missão de Ankhet (isle_story.gd).
	{"id": "esquecido_ilha_01", "tile": Vector2(39, 70.5), "archetype": "runner"},
	{"id": "esquecido_ilha_02", "tile": Vector2(48, 73), "archetype": "guard"},
	{"id": "esquecido_ilha_03", "tile": Vector2(49, 67.5), "archetype": "lancer"},
	# Ilha do Íbis Afogado: escribas vazios guardam o templo; Recife do Navio
	# Esquecido: saqueadores reviram a carga (far_isles.gd).
	{"id": "escriba_afogado_01", "tile": Vector2(15.5, 73.5), "archetype": "keeper"},
	{"id": "escriba_afogado_02", "tile": Vector2(10.5, 78.5), "archetype": "lancer"},
	{"id": "saqueador_recife_01", "tile": Vector2(78, 64.6), "archetype": "runner"},
	{"id": "saqueador_recife_02", "tile": Vector2(84, 69.4), "archetype": "guard"}
]
const MAIN_ROUTE_WAYPOINTS := [
	Vector2(-1, -1), Vector2(3, 0), Vector2(6, 0), Vector2(11, 0), Vector2(16, 0),
	Vector2(20, 0), Vector2(25, 1), Vector2(28, 1), Vector2(35, 1), Vector2(35, 6),
	Vector2(32, 7), Vector2(32, 11), Vector2(32, 16), Vector2(32, 20), Vector2(35, 20),
	Vector2(35, 27), Vector2(28, 27), Vector2(25, 24), Vector2(23, 24), Vector2(19, 24),
	Vector2(19, 26), Vector2(18, 27), Vector2(14, 27), Vector2(12, 26), Vector2(10, 26),
	Vector2(7, 24), Vector2(7, 20), Vector2(5, 20), Vector2(4, 22), Vector2(1, 22),
	Vector2(-3, 22), Vector2(-5, 26), Vector2(-10, 26), Vector2(-12, 25),
	Vector2(-14, 25), Vector2(-18, 25), Vector2(-21, 25)
]

var tiles: Dictionary = {}
var tile_themes: Dictionary = {}

static func iso(tile: Vector2) -> Vector2:
	return Vector2((tile.x - tile.y) * HALF_TILE.x, (tile.x + tile.y) * HALF_TILE.y)

static func unproject(point: Vector2) -> Vector2:
	return Vector2(point.x / 64.0 + point.y / 32.0, point.y / 32.0 - point.x / 64.0)

static func spawn_points() -> Dictionary:
	return MARKERS.duplicate()

static func room_at(point: Vector2) -> String:
	var tile := Vector2i(unproject(point).round())
	for room in ROOMS:
		if room["rect"].has_point(tile):
			return room["id"]
	for connector in CONNECTORS + LANDINGS:
		if connector["rect"].has_point(tile):
			return connector["room"]
	return "p1"

static func tile_catalog() -> Dictionary:
	var catalog: Dictionary = {}
	for region in ROOMS + CONNECTORS + LANDINGS:
		if region.has("shape"):
			continue
		var rect: Rect2i = region["rect"]
		for x in range(rect.position.x, rect.end.x):
			for y in range(rect.position.y, rect.end.y):
				catalog[Vector2i(x, y)] = {"color": region["color"], "theme": region["theme"]}
	for hole in WATER_HOLES:
		for x in range(hole.position.x, hole.end.x):
			for y in range(hole.position.y, hole.end.y):
				catalog.erase(Vector2i(x, y))
	var isle := IsleLayout.tiles()
	for tile in isle:
		catalog[tile] = {"color": IsleLayout.COLORS[isle[tile]], "theme": isle[tile]}
	# Salas com desenho próprio ("shape"): o claustro e as ilhas além da baía.
	var cloister := CloisterLayout.tiles()
	for tile in cloister:
		catalog[tile] = {"color": CloisterLayout.COLORS[cloister[tile]], "theme": cloister[tile]}
	for id in FarIslesLayout.ISLES:
		var ground := FarIslesLayout.tiles(id)
		for tile in ground:
			catalog[tile] = {"color": FarIslesLayout.COLORS[id][ground[tile]], "theme": ground[tile]}
	return catalog

## Tiles das ilhas que só se alcançam de barco (Bennu, Íbis e o recife), para os
## testes que andam pelo porto a pé.
static func sea_only_tiles() -> Dictionary:
	var result := IsleLayout.tiles()
	for id in FarIslesLayout.ISLES:
		result.merge(FarIslesLayout.tiles(id))
	return result

func _ready() -> void:
	z_index = -20
	var sea := HarborWater.new()
	sea.z_index = -1
	add_child(sea)
	var life := WaterLife.new()
	life.name = "WaterLife"
	life.layout = self
	add_child(life)
	var catalog := tile_catalog()
	for tile in catalog:
		tiles[tile] = catalog[tile]["color"]
		tile_themes[tile] = catalog[tile]["theme"]
	_build_boundaries()
	_build_floor_chunks()
	queue_redraw()

func _build_floor_chunks() -> void:
	# Each CanvasItem has a small real drawing bound: distant districts are culled.
	var groups: Dictionary = {}
	for tile: Vector2i in tiles:
		var key := Vector2i(floori(tile.x / 12.0), floori(tile.y / 12.0))
		if not groups.has(key): groups[key] = []
		groups[key].append(tile)
	for key in groups:
		var chunk := FloorChunk.new()
		chunk.name = "Ground_%s_%s" % [key.x, key.y]
		chunk.layout = self
		chunk.coordinates = groups[key]
		chunk.show_behind_parent = true
		# O chão v8 é uma textura contínua mapeada pelo mundo: repete sem emenda.
		chunk.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		chunk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(chunk)

## Chão v8 (tools/pixelorama/build_ground_v8.gd; docs/MUNDO_CHAO_V8.md): uma textura
## contínua por tema e as faces dos paredões, na paleta quente das construções.
## Sem os PNG, `_draw_tile` volta aos ladrilhos do Porto v7.
const GROUND_DIR := "res://assets/world/ground_v8/"
const GROUND_SIZE := Vector2(512, 256)
const FACE_SIZE := Vector2(128, 32)
## Quanto da cor do setor tinge o chão: distritos vizinhos do mesmo tema não ficam idênticos.
const GROUND_TINT := .22
static var _ground_textures: Dictionary = {}

static func ground_texture(name: String) -> Texture2D:
	if not _ground_textures.has(name):
		var path := GROUND_DIR + name + ".png"
		_ground_textures[name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _ground_textures[name]

## Tinta do setor sobre a textura: a cor dele clareada, misturada de leve ao branco.
static func ground_tint(base: Color) -> Color:
	var light := base.lightened(.5)
	return Color.WHITE.lerp(light / maxf(maxf(light.r, light.g), maxf(light.b, .001)), GROUND_TINT)

## Ordem dos temas no shader de transição (harbor_pixel_ground_blend.gdshader).
const GROUND_THEMES := ["stone", "sand", "wood", "mosaic", "garden", "crypt", "aqueduct", "arena"]
const GROUND_BLEND_SHADER := "res://assets/shaders/harbor_pixel_ground_blend.gdshader"
## Em volta de cada canto do tile, até onde (em tiles) o chão vizinho conta para a
## mistura. Com 0,75 entram só os quatro tiles do canto: meio a meio na borda e nada
## no canto seguinte, então a areia avança menos de um tile. Com 1,6 ela se espalhava
## por um tile e meio e virava chuvisco.
const BLEND_RADIUS := .75
static var _blend_material: ShaderMaterial

static func ground_blend_material() -> ShaderMaterial:
	if _blend_material == null and ResourceLoader.exists(GROUND_BLEND_SHADER):
		var material := ShaderMaterial.new()
		material.shader = load(GROUND_BLEND_SHADER)
		for theme in GROUND_THEMES:
			var texture := ground_texture(theme)
			if texture == null:
				return null
			material.set_shader_parameter("ground_" + theme, texture)
		material.set_shader_parameter("ground_size", GROUND_SIZE)
		_blend_material = material
	return _blend_material

## O chão vizinho que avança sobre este tile: [índice do tema, pesos nos quatro
## cantos (cima, direita, baixo, esquerda), tinta do vizinho], ou [] longe de bordas.
## Madeira não se mistura: o píer termina numa viga (`_draw_wood_trim`).
func ground_blend(tile: Vector2i) -> Array:
	var own: String = tile_themes[tile]
	if own == "wood":
		return []
	var corners := [Vector2(-.5, -.5), Vector2(.5, -.5), Vector2(.5, .5), Vector2(-.5, .5)]
	var shares: Array[Dictionary] = []
	var sums := {}
	var tints := {}
	for corner: Vector2 in corners:
		var at := Vector2(tile) + corner
		var counts := {}
		var total := 0
		for y in range(floori(at.y - BLEND_RADIUS), ceili(at.y + BLEND_RADIUS) + 1):
			for x in range(floori(at.x - BLEND_RADIUS), ceili(at.x + BLEND_RADIUS) + 1):
				var near := Vector2i(x, y)
				if not tiles.has(near) or Vector2(near).distance_to(at) > BLEND_RADIUS:
					continue
				var theme: String = tile_themes[near]
				if theme == "wood":
					continue
				counts[theme] = int(counts.get(theme, 0)) + 1
				total += 1
				if theme != own and not tints.has(theme):
					tints[theme] = tiles[near]
		var share := {}
		for theme in counts:
			share[theme] = float(counts[theme]) / maxf(total, 1)
			if theme != own:
				sums[theme] = float(sums.get(theme, 0.0)) + share[theme]
		shares.append(share)
	var other := ""
	for theme in sums:
		if other == "" or float(sums[theme]) > float(sums[other]):
			other = theme
	if other == "" or GROUND_THEMES.find(other) < 0:
		return []
	var weights := PackedFloat32Array()
	for share in shares:
		weights.append(float(share.get(other, 0.0)))
	return [GROUND_THEMES.find(other), weights, ground_tint(tints[other])]

func _build_boundaries() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	add_child(body)
	var edges := {Vector2i(1, 0): [Vector2(32, 0), Vector2(0, 16)], Vector2i(0, 1): [Vector2(0, 16), Vector2(-32, 0)], Vector2i(-1, 0): [Vector2(-32, 0), Vector2(0, -16)], Vector2i(0, -1): [Vector2(0, -16), Vector2(32, 0)]}
	for tile in tiles:
		for direction in edges:
			if tiles.has(tile + direction):
				continue
			var shape := SegmentShape2D.new()
			shape.a = iso(Vector2(tile)) + edges[direction][0]
			shape.b = iso(Vector2(tile)) + edges[direction][1]
			var collision := CollisionShape2D.new()
			collision.shape = shape
			body.add_child(collision)

func _draw() -> void:
	_draw_seal(MARKERS["hub_spawn"], 72, Color("9b966b"))
	_draw_seal(Vector2(-6, 23), 118, Color("ad8d66"))
	_draw_seal(Vector2(35, 22), 48, Color("7a9279"))
	_draw_seal(Vector2(43, 26), 39, Color("8e82a2"))
	_draw_seal(Vector2(25, -28), 83, Color("aa9b68"))
	_draw_seal(Vector2(81, 36), 92, Color("aa9b85"))
	_draw_seal(Vector2(-6, 38), 70, Color("7dbaab"))

func _draw_tile(tile: Vector2i, target: CanvasItem) -> void:
	var center := iso(Vector2(tile))
	var theme: String = tile_themes[tile]
	var base: Color = tiles[tile]
	var noise := posmod(tile.x * 29 + tile.y * 17, 11)
	var color := base.lightened(float(noise) / 180.0)
	var top := PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)])
	var depth := 20.0 if theme != "wood" else 11.0
	var floor_texture := ground_texture(theme)
	var face_texture := ground_texture("face_wood" if theme == "wood" else "face_stone")
	var tint := ground_tint(base)
	for edge in [Vector2i(1, 0), Vector2i(0, 1)]:
		if tiles.has(tile + edge):
			continue
		var a := center + (Vector2(32, 0) if edge.x == 1 else Vector2(0, 16))
		var b := center + (Vector2(0, 16) if edge.x == 1 else Vector2(-32, 0))
		var face := PackedVector2Array([a, b, b + Vector2(0, depth), a + Vector2(0, depth)])
		if face_texture != null:
			# Blocos do paredão em fiadas paralelas à borda: u segue x, v desce do topo.
			var uvs := PackedVector2Array([Vector2(a.x / FACE_SIZE.x, 0), Vector2(b.x / FACE_SIZE.x, 0), Vector2(b.x / FACE_SIZE.x, depth / FACE_SIZE.y), Vector2(a.x / FACE_SIZE.x, depth / FACE_SIZE.y)])
			target.draw_colored_polygon(face, tint, uvs, face_texture)
		else:
			target.draw_colored_polygon(face, base.darkened(.42))
		target.draw_line(a + Vector2(0, depth), b + Vector2(0, depth), Color("243e3e"), 2)
		if theme == "wood":
			target.draw_line(a + Vector2(-2, 3), a + Vector2(-2, 33), Color("443e32"), 4)
		elif face_texture == null:
			target.draw_line(a + Vector2(0, 8), b + Vector2(0, 8), base.darkened(.6), 1)
		if face_texture == null:
			target.draw_line(a, b, base.lightened(.18), 1)
	if floor_texture != null:
		var uvs := PackedVector2Array()
		for corner in top:
			uvs.append(corner / GROUND_SIZE)
		target.draw_colored_polygon(top, tint, uvs, floor_texture)
		if theme == "wood":
			_draw_wood_trim(tile, center, tint, target)
		return
	if Art.draw_tile(target, center, theme, tile):
		return
	target.draw_colored_polygon(top, color)
	if theme == "wood":
		for plank in range(1, 5):
			var t := plank / 5.0
			var a := center + Vector2(-32, 0).lerp(Vector2(0, -16), t)
			var b := center + Vector2(0, 16).lerp(Vector2(32, 0), t)
			target.draw_line(a, b, base.darkened(.28), 1)
		if noise % 3 == 0:
			target.draw_line(center + Vector2(-4, -4), center + Vector2(9, 2), base.lightened(.13), 1)
			target.draw_rect(Rect2(center + Vector2(-21, -1), Vector2(1, 1)), Color("b1a07a"))
	else:
		var seam := base.darkened(.22)
		target.draw_polyline(PackedVector2Array([top[0], top[1], top[2], top[3], top[0]]), seam, 1)
		if theme in ["sand", "garden"]:
			for speck in range(4):
				var x := float(posmod(noise * 7 + speck * 11, 31) - 15)
				var y := float(posmod(noise * 3 + speck * 5, 11) - 5)
				target.draw_rect(Rect2(center + Vector2(x, y), Vector2(2, 1)), base.darkened(.1 if speck % 2 == 0 else .28))
		if theme in ["mosaic", "crypt", "aqueduct"] and noise % 3 == 0:
			var inlay := Color("a9a077") if theme != "crypt" else Color("8e82a4")
			target.draw_colored_polygon(PackedVector2Array([center + Vector2(0, -3), center + Vector2(6, 0), center + Vector2(0, 3), center + Vector2(-6, 0)]), inlay.darkened(.15))
		if noise % 4 == 0:
			target.draw_polyline(PackedVector2Array([center + Vector2(-9, -5), center + Vector2(0, 0), center + Vector2(1, 5), center + Vector2(7, 7)]), base.darkened(.35), 1)
	if theme == "aqueduct":
		for side in [Vector2i(1, 0), Vector2i(0, 1)]:
			if not tiles.has(tile + side):
				var rail := center + Vector2(17 if side.x == 1 else -17, 8)
				target.draw_line(rail, rail - Vector2(0, 11), Color("7e8e7a"), 2)

## Viga de arremate onde as tábuas encontram outro chão: uma faixa escura de ~3 px
## com o fio de luz em cima. Madeira e pedra se encontram numa borda construída, não
## em pontilhado.
func _draw_wood_trim(tile: Vector2i, center: Vector2, tint: Color, target: CanvasItem) -> void:
	var edges := {Vector2i(1, 0): [Vector2(32, 0), Vector2(0, 16)], Vector2i(0, 1): [Vector2(0, 16), Vector2(-32, 0)], Vector2i(-1, 0): [Vector2(-32, 0), Vector2(0, -16)], Vector2i(0, -1): [Vector2(0, -16), Vector2(32, 0)]}
	for direction: Vector2i in edges:
		var near: Vector2i = tile + direction
		if not tile_themes.has(near) or tile_themes[near] == "wood":
			continue
		var a: Vector2 = center + edges[direction][0]
		var b: Vector2 = center + edges[direction][1]
		var inner_a := a.lerp(center, .2)
		var inner_b := b.lerp(center, .2)
		target.draw_colored_polygon(PackedVector2Array([a, b, inner_b, inner_a]), Color("4b3b2d") * tint)
		target.draw_line(inner_a, inner_b, Color("a27d50") * tint, 1)

func _draw_seal(tile: Vector2, radius: float, color: Color) -> void:
	draw_set_transform(iso(tile), 0, Vector2(1, .5))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, color.darkened(.08), 2)
	draw_arc(Vector2.ZERO, radius - 10, 0, TAU, 64, color.darkened(.25), 1)
	var star := PackedVector2Array()
	for point in range(16):
		var angle := point * TAU / 16.0
		var length := radius * (.61 if point % 2 == 0 else .27)
		star.append(Vector2(cos(angle), sin(angle)) * length)
	star.append(star[0])
	draw_polyline(star, color.darkened(.2), 1)
	draw_set_transform(Vector2.ZERO)

class FloorChunk:
	extends Node2D
	var layout: Node2D
	var coordinates: Array = []

	func _ready() -> void:
		coordinates.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
		var shore := ShoreFoam.new()
		shore.show_behind_parent = true
		for tile: Vector2i in coordinates:
			var center: Vector2 = layout.iso(Vector2(tile))
			var depth := 11.0 if layout.tile_themes[tile] == "wood" else 20.0
			for edge in [Vector2i(1, 0), Vector2i(0, 1)]:
				if layout.tiles.has(tile + edge): continue
				var a := center + (Vector2(32, 0) if edge.x == 1 else Vector2(0, 16))
				var b := center + (Vector2(0, 16) if edge.x == 1 else Vector2(-32, 0))
				shore.lines.append(a + Vector2(1, depth + 4))
				shore.lines.append(b + Vector2(-1, depth + 4))
		add_child(shore)

		# Bordas entre temas: o chão vizinho avança em pontilhado (GroundBlend).
		var material: ShaderMaterial = layout.ground_blend_material()
		if material != null:
			var blends := []
			for tile: Vector2i in coordinates:
				var blend: Array = layout.ground_blend(tile)
				if not blend.is_empty():
					blends.append([tile, blend[0], blend[1], blend[2]])
			if not blends.is_empty():
				var overlay := GroundBlend.new()
				overlay.name = "GroundBlend"
				overlay.layout = layout
				overlay.blends = blends
				overlay.material = material
				add_child(overlay)

	func _draw() -> void:
		for tile: Vector2i in coordinates:
			layout._draw_tile(tile, self)

## O chão vizinho sobre os tiles de borda, pelo shader de transição.
class GroundBlend:
	extends Node2D
	var layout: Node2D
	## [tile, índice do tema vizinho, pesos nos quatro cantos, tinta].
	var blends: Array = []

	func _draw() -> void:
		for entry: Array in blends:
			var center: Vector2 = layout.iso(Vector2(entry[0]))
			var weights: PackedFloat32Array = entry[2]
			var tint: Color = entry[3]
			var index := float(entry[1])
			var points := PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)])
			var uvs := PackedVector2Array([Vector2(index, weights[0]), Vector2(index, weights[1]), Vector2(index, weights[2]), Vector2(index, weights[3])])
			draw_polygon(points, PackedColorArray([tint, tint, tint, tint]), uvs)

class ShoreFoam:
	extends Node2D
	var lines := PackedVector2Array()

	func _ready() -> void:
		var effect := ShaderMaterial.new()
		effect.shader = preload("res://assets/shaders/harbor_pixel_foam.gdshader")
		material = effect

	func _draw() -> void:
		if not lines.is_empty():
			draw_multiline(lines, Color.WHITE, 2)

class HarborWater:
	extends Node2D

	func _draw() -> void:
		# TIME animates the shader without rebuilding the water drawing on the CPU.
		if not Art.draw_water(self, SEA_RECT, 0.0):
			draw_rect(SEA_RECT, Color("16343d"))
