extends PortInteractable

## Peça interativa do Claustro dos Iniciados e das ilhas além da baía
## (cloister.gd, far_isles.gd; docs/MUNDO_PROPOSTA_2026-10-30.md).
## O port_demo encaminha o tipo "isle_altar" para Isle.activate, que entrega a peça
## ao módulo dono dela (`handler`) por `extra_activate`. Assim nenhuma linha nova
## entra no meio do port_demo.gd.
## Como no resto do cenário, o pivô é a quina da frente da base: a base sólida fica
## toda atrás dele, e as folhas de pivô centrado são desenhadas com deslocamento.

const SeaArt = preload("res://scripts/world/sea_art.gd")
## Desenho e base de cada peça. "stand" usa a arte do porto (port_pixel_v7) na escala dada.
const STAND_SCALE := {"stele": .46, "lesson": .44, "sign": .5, "crate": .62, "log": .5}

## "stele", "lesson", "sign", "chest", "niche", "crate", "log" ou "tablet".
var piece := ""
## Símbolo gravado: "eye", "feather", "reed" (estelas do íbis) ou as setas do marco.
var symbol := ""
## Módulo que trata a interação: um script com `activate(game, item) -> bool`.
var handler: Script


func _ready() -> void:
	kind = "isle_altar"
	super._ready()


func extra_activate(game) -> bool:
	if handler == null:
		return false
	return handler.activate(game, self)


## Base sólida, atrás do pivô. A plaqueta enterrada do íbis é atravessável.
func footprint() -> PackedVector2Array:
	var base := PackedVector2Array()
	match piece:
		"stele", "lesson", "sign":
			base = Art.footprint("pillar")
			for index in range(base.size()): base[index] *= STAND_SCALE[piece]
		"crate", "log":
			base = Art.footprint("crate")
			for index in range(base.size()): base[index] *= STAND_SCALE[piece]
		"chest":
			# A base do baú de interiors_v4, levada para a quina da frente.
			base = PackedVector2Array([Vector2(-13, -15.5), Vector2(9, -4.5), Vector2(0, 0), Vector2(-22, -11)])
		"niche":
			base = PackedVector2Array([Vector2(-27, -14), Vector2(0, -27), Vector2(27, -14), Vector2(0, 0)])
	return base


func _draw() -> void:
	var gold := Color("dcc28c")
	var teal := Color("8ac5b2")
	for polygon in _ground_shade:
		draw_colored_polygon(polygon, Color(.01, .025, .03, .24))
	if highlighted:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, .5))
		draw_arc(Vector2.ZERO, 23, 0, TAU, 24, gold, 1)
		draw_set_transform(Vector2.ZERO)
	match piece:
		"stele":
			_stand("pillar", STAND_SCALE[piece])
			draw_rect(Rect2(-5, -27, 10, 12), Color("243f40"))
			_glyph(Vector2(0, -21), teal if opened else gold)
		"lesson":
			_stand("pillar", STAND_SCALE[piece])
			draw_rect(Rect2(-5, -24, 10, 15), Color("243f40"))
			for row in range(3):
				draw_line(Vector2(-3, -21 + row * 4), Vector2(3 - row, -21 + row * 4), teal if opened else gold, 1)
		"sign":
			_stand("pillar", STAND_SCALE[piece])
			draw_rect(Rect2(-6, -28, 12, 17), Color("243f40"))
			# Três setas: leste, norte e sudoeste, como as saídas do santuário.
			draw_line(Vector2(-3, -25), Vector2(3, -22), gold, 1)
			draw_line(Vector2(3, -22), Vector2(1, -24), gold, 1)
			draw_line(Vector2(-3, -17), Vector2(3, -20), gold, 1)
			draw_line(Vector2(3, -20), Vector2(1, -20), gold, 1)
			draw_line(Vector2(3, -15), Vector2(-3, -13), gold, 1)
			draw_line(Vector2(-3, -13), Vector2(-1, -15), gold, 1)
		"chest":
			draw_set_transform(Vector2(-6.5, -7.75))
			if not ResidentArt.draw(self, "chest_open" if opened else "chest_closed"):
				draw_set_transform(Vector2.ZERO)
				draw_colored_polygon(PackedVector2Array([Vector2(-15, -10), Vector2(0, -2), Vector2(9, -7), Vector2(9, -18), Vector2(-15, -21)]), Color("6d5a44"))
			draw_set_transform(Vector2.ZERO)
			if not opened and active:
				draw_line(Vector2(-4, -16), Vector2(-4, -8), gold, 1)
		"niche":
			if not SeaArt.draw(self, "isle_v1", "altar_open" if opened else "altar_closed", 0.0, Vector2(0, -15)):
				draw_rect(Rect2(-18, -28, 36, 24), Color("bdad89"))
			if not opened:
				# Um íbis gravado na tampa.
				draw_line(Vector2(-4, -36), Vector2(3, -39), gold, 1)
				draw_line(Vector2(3, -39), Vector2(6, -35), gold, 1)
		"crate", "log":
			_stand("crate", STAND_SCALE[piece])
			if piece == "crate":
				# O lacre de cera, com um íbis raspado.
				draw_rect(Rect2(-2, -12, 4, 4), Color("8e3b2c") if not opened else Color("4a3a30"))
			else:
				var bob := roundf(sin(time * 2.0))
				draw_colored_polygon(PackedVector2Array([Vector2(-8, -17 + bob), Vector2(0, -21 + bob), Vector2(8, -17 + bob), Vector2(0, -13 + bob)]), Color("cbbd96"))
				draw_line(Vector2(0, -21 + bob), Vector2(0, -13 + bob), Color("7d6a52"), 1)
				draw_line(Vector2(-5, -17 + bob), Vector2(-2, -16 + bob), Color("5a4a38"), 1)
				draw_line(Vector2(2, -18 + bob), Vector2(5, -17 + bob), Color("5a4a38"), 1)
		"tablet":
			if opened:
				return
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -2), Vector2(1, -6), Vector2(9, -2), Vector2(-1, 2)]), Color("9a7b58"))
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -2), Vector2(-1, 2), Vector2(-1, 3), Vector2(-9, -1)]), Color("6d5640"))
			draw_line(Vector2(-5, -2), Vector2(1, -4), Color("5a4532"), 1)
			draw_line(Vector2(-3, 0), Vector2(4, -3), Color("5a4532"), 1)
			if active:
				var glint := Color(gold, .5 + .3 * sin(time * 3.0))
				draw_rect(Rect2(Vector2(2, -5), Vector2(1, 1)), glint)


func _stand(art: String, scale: float) -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale)
	var drawn := Art.draw_prop(self, art)
	draw_set_transform(Vector2.ZERO)
	if not drawn:
		draw_rect(Rect2(-8, -26, 16, 25), Color("69786f"))


## Os símbolos das estelas do íbis, em poucos pixels.
func _glyph(at: Vector2, color: Color) -> void:
	match symbol:
		"eye":
			draw_polyline(PackedVector2Array([at + Vector2(-4, 0), at + Vector2(0, -2), at + Vector2(4, 0), at + Vector2(0, 2), at + Vector2(-4, 0)]), color, 1)
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), color)
			draw_line(at + Vector2(-1, 2), at + Vector2(-2, 5), color, 1)
		"feather":
			draw_line(at + Vector2(0, -5), at + Vector2(0, 5), color, 1)
			draw_line(at + Vector2(0, -4), at + Vector2(3, -1), color, 1)
			draw_line(at + Vector2(0, -1), at + Vector2(3, 2), color, 1)
			draw_line(at + Vector2(0, -4), at + Vector2(-2, -2), color, 1)
		"reed":
			draw_line(at + Vector2(-2, 5), at + Vector2(1, -5), color, 1)
			draw_line(at + Vector2(1, -5), at + Vector2(3, -3), color, 1)
			draw_line(at + Vector2(2, 5), at + Vector2(3, -1), color, 1)
