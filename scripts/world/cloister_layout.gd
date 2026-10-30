extends RefCounted

## Claustro dos Iniciados: a ampliação do Santuário da Primeira Palavra, onde Senu
## desperta depois da abertura (docs/MUNDO_PROPOSTA_2026-10-30.md). Fica a sudoeste
## do santuário e só se liga a ele, pela borda sul (conector de port_layout.gd).
## Um tile de água separa o claustro do corredor do atalho, em x = -1, e da Galeria
## do Eco, em y = 3: nada aqui fura os portões do atalho e da grade do Eco.
## O chão é mosaico, com um canteiro em volta do lago sagrado; o lago fica sem piso
## e mostra o mar por baixo, como o Reservatório.

const RECT := Rect2i(-14, 4, 13, 10)
const POOL := Rect2i(-9, 7, 3, 3)
const COLORS := {"mosaic": Color("5f6b5c"), "garden": Color("58634f")}

## Pontos, em tiles, das peças de cloister.gd. O marco dos caminhos fica no
## santuário, ao lado da saída leste.
const MARKERS := {
	"lesson_name": Vector2(-11.4, 11.2),
	"lesson_copy": Vector2(-4.4, 9.0),
	"lesson_return": Vector2(-8.6, 5.4),
	"novice_chest": Vector2(-10.8, 6.9),
	"crossroads": Vector2(1.5, .8),
}


## Tema do chão no tile, ou "" fora do claustro e no lago.
static func theme_at(tile: Vector2i) -> String:
	if not RECT.has_point(tile) or POOL.has_point(tile):
		return ""
	return "garden" if POOL.grow(1).has_point(tile) else "mosaic"


static func tiles() -> Dictionary:
	var result := {}
	for x in range(RECT.position.x, RECT.end.x):
		for y in range(RECT.position.y, RECT.end.y):
			var theme := theme_at(Vector2i(x, y))
			if theme != "":
				result[Vector2i(x, y)] = theme
	return result
