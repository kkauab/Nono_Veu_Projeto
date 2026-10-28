extends RefCounted

## Forma da Ilha do Bennu e onde fica cada coisa nela (docs/MUNDO_BARCO_ILHA.md).
## A costa é uma elipse com duas ondulações fixas, sem sorteio: o mesmo desenho em
## todas as jornadas. port_layout.gd lê os tiles daqui para a sala "isle".

const CENTER := Vector2(45, 70)
const RADII := Vector2(10.5, 8.0)
## Tudo o que a ilha pode ocupar, o píer incluído (o "rect" da sala).
const RECT := Rect2i(35, 59, 22, 19)
## Da fração SAND_FROM da costa para fora é praia; para dentro, campo.
const SAND_FROM := .72
const PIER := Rect2i(44, 59, 2, 3)
const RUINS := Rect2i(50, 66, 4, 4)
const COLORS := {"sand": Color("8b8168"), "garden": Color("5e6b4f"), "wood": Color("6f634a"), "mosaic": Color("6a6a5a")}

## Pontos, em tiles, das peças das missões (isle_story.gd).
const MARKERS := {
	"isle_rest": Vector2(46, 64.6), "ankhet": Vector2(42.5, 68.5), "bennu_altar": Vector2(51.6, 67.6),
	"brazier_east": Vector2(54, 70.6), "brazier_north": Vector2(41, 64.2), "brazier_west": Vector2(37.7, 72),
	"hori_net": Vector2(46, 76.2),
}
## [peça, tile, sólida]. As tamareiras usam a arte do porto ("palm"); o resto vem de isle_v1.
const PROPS := [
	["palm", Vector2(40, 63.6), true], ["palm", Vector2(49.2, 63.8), true], ["palm", Vector2(38.4, 69.2), true],
	["palm", Vector2(38.6, 75.4), true], ["palm", Vector2(51.6, 75), true], ["palm", Vector2(55.4, 70.9), true],
	["palm", Vector2(42.6, 76.4), true],
	["acacia", Vector2(43.4, 66.2), true], ["acacia", Vector2(48.6, 72.2), true], ["acacia", Vector2(40.4, 73.6), true],
	["sycamore", Vector2(46.4, 70.4), true],
	["bush_a", Vector2(47.6, 66.4), true], ["bush_a", Vector2(38.6, 67.2), true], ["bush_a", Vector2(45.6, 74.6), true],
	["bush_b", Vector2(50.2, 71.6), true], ["bush_b", Vector2(53, 73.2), true], ["bush_b", Vector2(41.6, 70.6), true],
	["rock_a", Vector2(36.2, 73.6), true], ["rock_a", Vector2(55, 68.6), true],
	["rock_b", Vector2(47.4, 62.6), true], ["rock_b", Vector2(48.8, 76.4), true],
	["reeds", Vector2(37.2, 66.8), false], ["reeds", Vector2(53.8, 74.2), false], ["reeds", Vector2(41.8, 62.6), false],
	["reeds", Vector2(37.3, 71.3), false], ["driftwood", Vector2(39.2, 76.2), false],
	["column_broken", Vector2(50.2, 66.2), true], ["column_broken", Vector2(53.4, 66.4), true], ["column_broken", Vector2(53.4, 69.4), true],
]
## Garças de pé na água rasa, perto da costa.
const HERONS := [Vector2(36.2, 76.6), Vector2(57.2, 74.2), Vector2(34.6, 64.2)]

## Distância normalizada até a costa: até 1.0 é terra.
static func coast(tile: Vector2) -> float:
	var offset := (tile - CENTER) / RADII
	var reach := 1.0 + .12 * sin(3.0 * offset.angle() + 1.0) + .07 * sin(5.0 * offset.angle() + 2.0)
	return offset.length() / reach

## Tema do chão no tile, ou "" quando é água.
static func theme_at(tile: Vector2i) -> String:
	if PIER.has_point(tile):
		return "wood"
	if RUINS.has_point(tile):
		return "mosaic"
	var distance := coast(Vector2(tile))
	if distance > 1.0:
		return ""
	return "sand" if distance > SAND_FROM else "garden"

## Todos os tiles de chão da ilha, com o tema de cada um.
static func tiles() -> Dictionary:
	var result := {}
	for x in range(RECT.position.x, RECT.end.x):
		for y in range(RECT.position.y, RECT.end.y):
			var theme := theme_at(Vector2i(x, y))
			if theme != "":
				result[Vector2i(x, y)] = theme
	return result

static func is_land(tile: Vector2) -> bool:
	return theme_at(Vector2i(tile.round())) != ""
