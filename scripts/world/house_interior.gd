extends Node2D

## Piso, paredes e colisão de uma casa. Fica abaixo dos atores, como o piso do
## Porto; os móveis são nós `Furniture` no mundo ordenado por profundidade.
## As paredes do fundo (lados de x e y menores) sobem inteiras; as da frente são
## só um rebordo baixo, para não esconder Senu.

const Art = preload("res://scripts/world/port_art.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Catalog = preload("res://scripts/world/house_catalog.gd")
const WALL_HEIGHT := 62.0
const LIP_HEIGHT := 7.0
## O fundo escuro passa da metade da tela em volta da sala: a câmera fica parada no centro.
const BACKDROP_MARGIN := 420.0

var house_id := ""
var house: Dictionary = {}

## Ponto onde a câmera fica parada; sobe um pouco para mostrar as paredes.
static func camera_point(data: Dictionary) -> Vector2:
	var origin := Vector2(data["origin"])
	return Layout.iso(origin + (Vector2(data["size"]) - Vector2.ONE) * .5) + Vector2(0, -22)

func _ready() -> void:
	name = "Interior_" + house_id
	z_index = -15
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_collision()
	queue_redraw()

func _build_collision() -> void:
	# Mesmo método de port_layout._build_boundaries: um segmento por borda sem vizinho.
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 6
	add_child(body)
	var tiles := Catalog.tiles_of(house)
	var edges := {Vector2i(1, 0): [Vector2(32, 0), Vector2(0, 16)], Vector2i(0, 1): [Vector2(0, 16), Vector2(-32, 0)], Vector2i(-1, 0): [Vector2(-32, 0), Vector2(0, -16)], Vector2i(0, -1): [Vector2(0, -16), Vector2(32, 0)]}
	for tile in tiles:
		for direction in edges:
			if tiles.has(tile + direction):
				continue
			var shape := SegmentShape2D.new()
			shape.a = Layout.iso(Vector2(tile)) + edges[direction][0]
			shape.b = Layout.iso(Vector2(tile)) + edges[direction][1]
			var collision := CollisionShape2D.new()
			collision.shape = shape
			body.add_child(collision)

func _draw() -> void:
	var tiles := Catalog.tiles_of(house)
	var origin: Vector2i = house["origin"]
	var last: Vector2i = origin + house["size"] - Vector2i.ONE
	var exit_tile := Vector2i(Vector2(house["exit"]).round())
	var bounds := Rect2(Layout.iso(Vector2(origin)), Vector2.ZERO)
	for tile in tiles:
		bounds = bounds.expand(Layout.iso(Vector2(tile)))
	draw_rect(bounds.grow(BACKDROP_MARGIN), Color("070d10"))
	var floor_color: Color = house["color"]
	tiles.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	for tile in tiles:
		var center := Layout.iso(Vector2(tile))
		if not Art.draw_tile(self, center, house["theme"], tile):
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)]), floor_color)
		# Penumbra: o piso escurece longe do braseiro do fundo.
		var shade := clampf(float((tile.x - origin.x) + (tile.y - origin.y)) / float(house["size"].x + house["size"].y) * .28, 0, .28)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0, -16), center + Vector2(32, 0), center + Vector2(0, 16), center + Vector2(-32, 0)]), Color(.02, .03, .035, shade))
	for rug in house.get("rugs", []):
		_rug(rug[0], rug[1], rug[2])
	var wall: Color = house["wall"]
	for tile in tiles:
		var center := Layout.iso(Vector2(tile))
		if tile.x == origin.x:
			_wall(center + Vector2(-32, 0), center + Vector2(0, -16), wall.darkened(.28), tile.y)
		if tile.y == origin.y:
			_wall(center + Vector2(0, -16), center + Vector2(32, 0), wall, tile.x)
	for tile in tiles:
		var center := Layout.iso(Vector2(tile))
		if tile.y == last.y and tile != exit_tile:
			_lip(center + Vector2(0, 16), center + Vector2(-32, 0), wall.darkened(.45))
		if tile.x == last.x:
			_lip(center + Vector2(32, 0), center + Vector2(0, 16), wall.darkened(.35))
	# Soleira: uma faixa de luz do dia entra pela porta.
	var door := Layout.iso(Vector2(exit_tile))
	draw_colored_polygon(PackedVector2Array([door + Vector2(0, 16), door + Vector2(-32, 0), door + Vector2(-26, -3), door + Vector2(6, 13)]), Color("8c7b58"))
	draw_colored_polygon(PackedVector2Array([door + Vector2(-26, -3), door + Vector2(6, 13), door + Vector2(18, 7), door + Vector2(-14, -9)]), Color(.96, .86, .6, .1))

func _rug(center: Vector2, size: Vector2, color: Color) -> void:
	var half := size * .5
	var corners := PackedVector2Array([Layout.iso(center - half), Layout.iso(center + Vector2(half.x, -half.y)), Layout.iso(center + half), Layout.iso(center + Vector2(-half.x, half.y))])
	draw_colored_polygon(corners, color)
	var border := corners.duplicate()
	border.append(corners[0])
	draw_polyline(border, color.lightened(.35), 2)
	# Losango central, como nos tapetes de caravana.
	var middle := PackedVector2Array()
	for index in range(4):
		middle.append(corners[index].lerp(corners[(index + 1) % 4], .5))
	middle.append(middle[0])
	draw_polyline(middle, Color("c9a25a"), 1)

func _wall(a: Vector2, b: Vector2, color: Color, seed: int) -> void:
	var up := Vector2(0, -WALL_HEIGHT)
	draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), color)
	if str(house.get("wall_style", "stone")) == "fabric":
		# Lona listrada presa a uma vara no alto.
		for stripe in range(1, 4):
			var foot := a.lerp(b, stripe / 4.0)
			draw_line(foot, foot + up, Color("c9a25a").darkened(.25), 3)
		draw_line(a + up, b + up, Color("5a4630"), 3)
		draw_line(a + Vector2(0, -1), b + Vector2(0, -1), color.darkened(.35), 2)
		return
	# Fiadas de pedra, rodapé e topo, no mesmo grão de pixel do Porto.
	for row in range(1, 6):
		var lift := Vector2(0, -row * WALL_HEIGHT / 6.0).round()
		draw_line(a + lift, b + lift, color.darkened(.18), 1)
		var offset := .25 if (row + seed) % 2 == 0 else .75
		var joint := a.lerp(b, offset) + lift
		draw_line(joint, joint + Vector2(0, WALL_HEIGHT / 6.0).round(), color.darkened(.22), 1)
	draw_line(a + Vector2(0, -1), b + Vector2(0, -1), color.darkened(.4), 2)
	draw_line(a + up, b + up, color.lightened(.22), 2)

func _lip(a: Vector2, b: Vector2, color: Color) -> void:
	var up := Vector2(0, -LIP_HEIGHT)
	draw_colored_polygon(PackedVector2Array([a, b, b + up, a + up]), color)
	draw_line(a + up, b + up, color.lightened(.3), 1)


## Móvel de interior. Ordenado com os atores e com uma base sólida pequena.
class Furniture extends Node2D:
	const Art = preload("res://scripts/world/port_art.gd")
	const Layout = preload("res://scripts/world/port_layout.gd")
	## Móveis longos medidos em tiles (comprimento em x, em y, altura em px):
	## o desenho e a base sólida saem da mesma caixa isométrica.
	const BOXES := {"counter": Vector3(2.4, .6, 14), "shelf": Vector3(1.5, .3, 40), "furnace": Vector3(2.0, .9, 46), "rack": Vector3(1.4, .25, 34), "cords": Vector3(1.4, .25, 38), "trade_chest": Vector3(1.6, .55, 12)}
	const ANIMATED := ["brazier", "merit", "furnace", "nakht", "adiam", "coal"]
	const InteriorArt = preload("res://scripts/world/interior_art.gd")
	## Largura de cada fatia de profundidade das caixas, em pixels.
	const SLICE_WIDTH := 4
	var kind := "crate"
	var _time := 0.0
	var _slices: Array[Node2D] = []

	## Fatia vertical de uma caixa longa, ordenada pela borda da frente naquela
	## coluna: Senu atrás da ponta do balcão já não é desenhado por cima dele.
	class ArtSlice extends Node2D:
		var furniture: Node2D
		var from := 0
		var to := 0

		func _draw() -> void:
			furniture.draw_slice(self)

	## Clarão do forno no chão: abaixo de todos os atores.
	class FloorGlow extends Node2D:
		var furniture: Node2D

		func _draw() -> void:
			furniture.draw_glow(self)

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_to_group("house_furniture")
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 6
		var shape := CollisionPolygon2D.new()
		if BOXES.has(kind):
			shape.polygon = _footprint()
		else:
			var half: Vector2 = {"bed": Vector2(26, 11), "table": Vector2(20, 9), "brazier": Vector2(9, 4), "amphora": Vector2(7, 4), "merit": Vector2(6, 3), "nakht": Vector2(6, 3), "adiam": Vector2(6, 3), "anvil": Vector2(11, 5), "tub": Vector2(12, 6), "coal": Vector2(13, 5), "easel": Vector2(8, 4), "saddle": Vector2(13, 5)}.get(kind, Vector2(12, 6))
			shape.polygon = PackedVector2Array([Vector2(-half.x, -half.y * .2), Vector2(0, half.y * .8), Vector2(half.x, -half.y * .2), Vector2(0, -half.y * 1.2)])
		body.add_child(shape)
		add_child(body)
		if BOXES.has(kind) and InteriorArt.has(_art_name()):
			_slice_art()

	func _slice_art() -> void:
		y_sort_enabled = true
		var base := _footprint()
		for column in range(floori(base[3].x) - 2, ceili(base[1].x) + 2, SLICE_WIDTH):
			var slice := ArtSlice.new()
			slice.furniture = self
			slice.from = column
			slice.to = column + SLICE_WIDTH
			slice.position = Vector2(column + SLICE_WIDTH * .5, _front_edge(base, column + SLICE_WIDTH * .5)).round()
			add_child(slice)
			_slices.append(slice)
		if kind == "furnace":
			var glow := FloorGlow.new()
			glow.furniture = self
			glow.z_index = -1
			add_child(glow)
			_slices.append(glow)

	## Altura do chão na borda da frente da caixa (esquerda→frente→direita) na coluna x.
	func _front_edge(base: PackedVector2Array, x: float) -> float:
		var left: Vector2 = base[3]
		var front: Vector2 = base[2]
		var right: Vector2 = base[1]
		if x <= front.x:
			return lerpf(left.y, front.y, clampf((x - left.x) / maxf(1.0, front.x - left.x), 0, 1))
		return lerpf(front.y, right.y, clampf((x - front.x) / maxf(1.0, right.x - front.x), 0, 1))

	func draw_slice(slice: ArtSlice) -> void:
		InteriorArt.draw_columns(slice, _art_name(), _time, slice.from, slice.to, slice.position)

	func draw_glow(canvas: Node2D) -> void:
		var base := _footprint()
		canvas.draw_circle(base[3].lerp(base[2], .5) + Vector2(0, 2), 34, Color(1, .5, .18, .1 + sin(_time * 11.0) * .04))

	func _process(delta: float) -> void:
		if kind not in ANIMATED: return
		_time += delta
		queue_redraw()
		for slice in _slices:
			slice.queue_redraw()

	func _art_name() -> String:
		# As prateleiras alternam frascos e rolos.
		if kind == "shelf":
			return "shelf_b" if posmod(roundi(position.x / 54.0), 2) == 1 else "shelf_a"
		return kind

	func _footprint() -> PackedVector2Array:
		var box: Vector3 = BOXES[kind]
		var half := Vector2(box.x, box.y) * .5
		return PackedVector2Array([Layout.iso(Vector2(-half.x, -half.y)), Layout.iso(Vector2(half.x, -half.y)), Layout.iso(half), Layout.iso(Vector2(-half.x, half.y))])

	## Caixa isométrica: topo e as duas faces viradas para a câmera.
	func _box(top: Color, left: Color, right: Color) -> PackedVector2Array:
		var base := _footprint()
		var up := Vector2(0, -BOXES[kind].z)
		draw_colored_polygon(PackedVector2Array([base[3], base[2], base[2] + up, base[3] + up]), left)
		draw_colored_polygon(PackedVector2Array([base[1], base[2], base[2] + up, base[1] + up]), right)
		var lid := PackedVector2Array([base[0] + up, base[1] + up, base[2] + up, base[3] + up])
		draw_colored_polygon(lid, top)
		return lid

	func _draw() -> void:
		if not _slices.is_empty():
			return
		if not BOXES.has(kind):
			draw_rect(Rect2(-14, -2, 28, 4), Color(.01, .025, .03, .28))
		if kind == "furnace":
			# O clarão do fogo cai no chão diante da boca, por baixo da arte.
			var base := _footprint()
			draw_circle(base[3].lerp(base[2], .5) + Vector2(0, 2), 34, Color(1, .5, .18, .1 + sin(_time * 11.0) * .04))
		# Arte do Pixelorama (interiors_v1); o desenho abaixo é a reserva sem a folha exportada.
		if InteriorArt.draw(self, _art_name(), _time):
			return
		match kind:
			"furnace":
				var lid := _box(Color("5a4e44"), Color("4a3f37"), Color("3a312b"))
				var base := _footprint()
				var mouth: Vector2 = base[3].lerp(base[2], .5) + Vector2(0, -6)
				var flicker := sin(_time * 11.0) * .08 + sin(_time * 3.7) * .05
				draw_circle(mouth + Vector2(0, 8), 34, Color(1, .5, .18, .1 + flicker * .5))
				draw_colored_polygon(PackedVector2Array([mouth + Vector2(-11, 0), mouth + Vector2(11, 0), mouth + Vector2(11, -12), mouth + Vector2(6, -18), mouth + Vector2(-6, -18), mouth + Vector2(-11, -12)]), Color("1c1410"))
				draw_colored_polygon(PackedVector2Array([mouth + Vector2(-8, 0), mouth + Vector2(8, 0), mouth + Vector2(8, -9), mouth + Vector2(-8, -9)]), Color(1, .55 + flicker, .2, .95))
				draw_rect(Rect2(mouth + Vector2(-5, -5), Vector2(10, 3)), Color("ffe08a"))
				# Chaminé sobre o tampo.
				var top := (lid[0] + lid[2]) * .5
				draw_rect(Rect2(top + Vector2(-6, -26), Vector2(12, 26)), Color("4a3f37"))
				draw_rect(Rect2(top + Vector2(-6, -26), Vector2(4, 26)), Color("5a4e44"))
			"rack":
				_box(Color("6d553a"), Color("5a4630"), Color("46362a"))
				var base := _footprint()
				for blade in range(4):
					var foot: Vector2 = base[3].lerp(base[2], .18 + blade * .21) + Vector2(0, -6)
					draw_line(foot, foot + Vector2(0, -22), Color("b8bcc0"), 2)
					draw_line(foot + Vector2(-3, -5), foot + Vector2(3, -5), Color("c9a25a"), 1)
			"cords":
				_box(Color("8a6a46"), Color("6d553a"), Color("5a4630"))
				var base := _footprint()
				var colors := ["c9a25a", "7a3a2c", "d8cfb8", "3f6c68", "a5683f"]
				for cord in range(5):
					var top: Vector2 = base[3].lerp(base[2], .12 + cord * .19) + Vector2(0, -34)
					var tint := Color(colors[cord])
					draw_line(top, top + Vector2(0, 26 - cord % 2 * 6), tint, 1)
					for knot in range(1 + cord % 3):
						draw_rect(Rect2(top + Vector2(-1, 6 + knot * 7), Vector2(3, 2)), tint.lightened(.2))
			"trade_chest":
				var lid := _box(Color("7a5236"), Color("5e3e28"), Color("4b311f"))
				var front := _footprint()
				draw_line(front[3] + Vector2(0, -6), front[2] + Vector2(0, -6), Color("c9a25a"), 1)
				var center := (lid[0] + lid[2]) * .5
				# Um rolo de pano e um saquinho de especiarias sobre o baú.
				draw_rect(Rect2(center + Vector2(-14, -4), Vector2(12, 4)), Color("d8cfb8"))
				draw_line(center + Vector2(-14, -2), center + Vector2(-2, -2), Color("7a3a2c"), 1)
				draw_circle(center + Vector2(8, -3), 3, Color("a5683f"))
			"anvil":
				draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(4, -8), Vector2(-4, -8)]), Color("3a3d40"))
				draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(8, -8), Vector2(14, -11), Vector2(8, -14), Vector2(-10, -14)]), Color("4a4e52"))
				draw_line(Vector2(-10, -14), Vector2(8, -14), Color("8a8e90"), 1)
			"tub":
				draw_colored_polygon(PackedVector2Array([Vector2(-11, -2), Vector2(0, 3), Vector2(11, -2), Vector2(11, -10), Vector2(0, -5), Vector2(-11, -10)]), Color("6b4f34"))
				draw_colored_polygon(PackedVector2Array([Vector2(-11, -10), Vector2(0, -5), Vector2(11, -10), Vector2(0, -15)]), Color("3f6f78"))
				draw_line(Vector2(-4, -11), Vector2(3, -9), Color("8fbcc0"), 1)
			"coal":
				draw_colored_polygon(PackedVector2Array([Vector2(-13, 0), Vector2(13, 0), Vector2(8, -6), Vector2(1, -9), Vector2(-7, -6)]), Color("2a2622"))
				for ember in [Vector2(-4, -4), Vector2(3, -6), Vector2(7, -2)]:
					draw_rect(Rect2(ember, Vector2(2, 1)), Color("c8642a"))
			"easel":
				draw_line(Vector2(-6, 0), Vector2(-2, -26), Color("5a4630"), 2)
				draw_line(Vector2(6, 0), Vector2(2, -26), Color("5a4630"), 2)
				draw_line(Vector2(0, 2), Vector2(0, -20), Color("46362a"), 1)
				draw_colored_polygon(PackedVector2Array([Vector2(-9, -12), Vector2(9, -14), Vector2(9, -30), Vector2(-9, -28)]), Color("c8b78a"))
				draw_polyline(PackedVector2Array([Vector2(-6, -15), Vector2(-2, -22), Vector2(3, -19), Vector2(6, -27)]), Color("7a3a2c"), 1)
				draw_rect(Rect2(Vector2(5, -28), Vector2(2, 2)), Color("3f6c68"))
			"saddle":
				draw_colored_polygon(PackedVector2Array([Vector2(-12, -2), Vector2(0, 3), Vector2(12, -2), Vector2(10, -8), Vector2(0, -4), Vector2(-10, -8)]), Color("7a4a2c"))
				draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(0, -4), Vector2(10, -8), Vector2(6, -12), Vector2(-6, -12)]), Color("9a6038"))
				draw_line(Vector2(-6, -12), Vector2(6, -12), Color("c9a25a"), 1)
			"nakht":
				# Nakht: avental de couro sobre a túnica, cabeça raspada, martelo na mão.
				var breath := roundf(sin(_time * 1.6) * .6)
				draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(8, -25 + breath), Vector2(-8, -25 + breath)]), Color("8a6a4a"))
				draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(6, 0), Vector2(5, -19 + breath), Vector2(-5, -19 + breath)]), Color("5a3e2a"))
				draw_line(Vector2(-8, -23 + breath), Vector2(-11, -11), Color("7a4c30"), 3)
				draw_line(Vector2(8, -23 + breath), Vector2(12, -14), Color("7a4c30"), 3)
				draw_line(Vector2(12, -14), Vector2(15, -24), Color("5a4630"), 2)
				draw_rect(Rect2(Vector2(12, -27), Vector2(6, 4)), Color("6a6e72"))
				draw_rect(Rect2(-2, -28 + breath, 4, 3), Color("7a4c30"))
				draw_circle(Vector2(0, -33 + breath), 5, Color("7a4c30"))
				draw_line(Vector2(-3, -29 + breath), Vector2(3, -29 + breath), Color("2a1e16"), 2)
				draw_rect(Rect2(-2, -34 + breath, 1, 1), Color("1f1a17"))
				draw_rect(Rect2(2, -34 + breath, 1, 1), Color("1f1a17"))
			"adiam":
				# Adiam: algodão branco com barra colorida e um xale sobre a cabeça.
				var breath := roundf(sin(_time * 1.7) * .6)
				draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(7, -24 + breath), Vector2(-7, -24 + breath)]), Color("d8cfb8"))
				draw_colored_polygon(PackedVector2Array([Vector2(2, 0), Vector2(9, 0), Vector2(7, -24 + breath), Vector2(2, -24 + breath)]), Color("c2b89e"))
				draw_line(Vector2(-9, -2), Vector2(9, -2), Color("3f6c68"), 2)
				draw_line(Vector2(-9, -4), Vector2(9, -4), Color("c9a25a"), 1)
				draw_line(Vector2(-7, -22 + breath), Vector2(-9, -12), Color("6e4630"), 2)
				draw_line(Vector2(7, -22 + breath), Vector2(9, -12), Color("6e4630"), 2)
				draw_circle(Vector2(0, -31 + breath), 5, Color("6e4630"))
				draw_colored_polygon(PackedVector2Array([Vector2(-7, -30 + breath), Vector2(-5, -38 + breath), Vector2(0, -40 + breath), Vector2(5, -38 + breath), Vector2(7, -30 + breath), Vector2(8, -22 + breath), Vector2(4, -33 + breath), Vector2(-4, -33 + breath), Vector2(-8, -22 + breath)]), Color("ece4d0"))
				draw_line(Vector2(-7, -31 + breath), Vector2(-8, -23 + breath), Color("3f6c68"), 1)
				draw_rect(Rect2(-2, -31 + breath, 1, 1), Color("1f1a17"))
				draw_rect(Rect2(2, -31 + breath, 1, 1), Color("1f1a17"))
			"counter":
				var lid := _box(Color("8a6a46"), Color("5e4630"), Color("4b3826"))
				var front := _footprint()
				draw_line(front[3] + Vector2(0, -4), front[2] + Vector2(0, -4), Color("a68a55"), 1)
				# Balança de pratos e frascos sobre o tampo.
				var center := (lid[0] + lid[2]) * .5
				draw_line(center + Vector2(-14, -2), center + Vector2(-14, -12), Color("c9a25a"), 1)
				draw_line(center + Vector2(-20, -11), center + Vector2(-8, -11), Color("c9a25a"), 1)
				draw_rect(Rect2(center + Vector2(-22, -10), Vector2(5, 2)), Color("c9a25a"))
				draw_rect(Rect2(center + Vector2(-11, -10), Vector2(5, 2)), Color("c9a25a"))
				for jar in [[Vector2(6, -6), "7fa59a"], [Vector2(12, -3), "b47a4a"], [Vector2(18, -7), "c8b78a"]]:
					draw_rect(Rect2(center + jar[0], Vector2(4, 6)), Color(jar[1]))
					draw_rect(Rect2(center + jar[0] + Vector2(1, -2), Vector2(2, 2)), Color(jar[1]).darkened(.3))
			"shelf":
				_box(Color("6d553a"), Color("5a4630"), Color("46362a"))
				var base := _footprint()
				# Três tábuas e frascos de cores que Merit só reconhece pelo cheiro.
				var colors := ["7fa59a", "b47a4a", "c8b78a", "8e6a8a", "a8a46a"]
				for board in range(3):
					var lift := Vector2(0, -6 - board * 12)
					draw_line(base[3] + lift, base[2] + lift, Color("8a6a46"), 2)
					for slot in range(4):
						var spot: Vector2 = base[3].lerp(base[2], .14 + slot * .22) + lift
						var tint := Color(colors[(slot + board * 2 + int(position.x)) % colors.size()])
						draw_rect(Rect2(spot + Vector2(-2, -7), Vector2(4, 6)), tint)
						draw_rect(Rect2(spot + Vector2(-1, -9), Vector2(2, 2)), tint.darkened(.35))
			"amphora":
				draw_colored_polygon(PackedVector2Array([Vector2(-2, 0), Vector2(2, 0), Vector2(6, -6), Vector2(6, -13), Vector2(3, -18), Vector2(-3, -18), Vector2(-6, -13), Vector2(-6, -6)]), Color("a5683f"))
				draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(2, 0), Vector2(6, -6), Vector2(6, -13), Vector2(3, -18), Vector2(0, -18)]), Color("8a5332"))
				draw_rect(Rect2(-2, -22, 4, 4), Color("8a5332"))
				draw_line(Vector2(-3, -21), Vector2(-6, -15), Color("6d4128"), 1)
				draw_line(Vector2(3, -21), Vector2(6, -15), Color("6d4128"), 1)
				draw_line(Vector2(-5, -11), Vector2(5, -11), Color("d0a070"), 1)
			"merit":
				# Merit, atrás do balcão: túnica verde-petróleo, faixa dourada, cabelo preso.
				var breath := roundf(sin(_time * 1.8) * .6)
				draw_colored_polygon(PackedVector2Array([Vector2(-8, 0), Vector2(8, 0), Vector2(7, -24 + breath), Vector2(-7, -24 + breath)]), Color("3f6c68"))
				draw_colored_polygon(PackedVector2Array([Vector2(1, 0), Vector2(8, 0), Vector2(7, -24 + breath), Vector2(1, -24 + breath)]), Color("335955"))
				draw_line(Vector2(-7, -17 + breath), Vector2(7, -17 + breath), Color("c9a25a"), 1)
				draw_line(Vector2(-7, -22 + breath), Vector2(-9, -12), Color("9a6a48"), 2)
				draw_line(Vector2(7, -22 + breath), Vector2(9, -12), Color("9a6a48"), 2)
				draw_rect(Rect2(-2, -27 + breath, 4, 3), Color("9a6a48"))
				draw_circle(Vector2(0, -32 + breath), 5, Color("a8754f"))
				draw_colored_polygon(PackedVector2Array([Vector2(-6, -32 + breath), Vector2(-5, -37 + breath), Vector2(0, -39 + breath), Vector2(5, -37 + breath), Vector2(6, -32 + breath), Vector2(6, -27 + breath), Vector2(3, -33 + breath), Vector2(-3, -33 + breath), Vector2(-6, -27 + breath)]), Color("1f1a17"))
				draw_line(Vector2(-5, -35 + breath), Vector2(5, -35 + breath), Color("c9a25a"), 1)
				draw_rect(Rect2(-2, -32 + breath, 1, 1), Color("1f1a17"))
				draw_rect(Rect2(2, -32 + breath, 1, 1), Color("1f1a17"))
				draw_rect(Rect2(-6, -30 + breath, 1, 2), Color("e2c27a"))
			"bed":
				# Catre de madeira com manta.
				draw_colored_polygon(PackedVector2Array([Vector2(-28, -4), Vector2(0, 10), Vector2(26, -3), Vector2(0, -17)]), Color("5e4a35"))
				draw_colored_polygon(PackedVector2Array([Vector2(-28, -4), Vector2(0, 10), Vector2(0, 14), Vector2(-28, 0)]), Color("3f3225"))
				draw_colored_polygon(PackedVector2Array([Vector2(-22, -6), Vector2(2, 6), Vector2(20, -3), Vector2(-4, -15)]), Color("6e7a6c"))
				draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(20, -3), Vector2(10, -8), Vector2(-1, -5)]), Color("b8ab8a"))
			"table":
				draw_line(Vector2(-14, -2), Vector2(-14, -12), Color("3f3225"), 2)
				draw_line(Vector2(14, -2), Vector2(14, -12), Color("3f3225"), 2)
				draw_line(Vector2(0, 5), Vector2(0, -6), Color("3f3225"), 2)
				draw_colored_polygon(PackedVector2Array([Vector2(-20, -12), Vector2(0, -2), Vector2(20, -12), Vector2(0, -22)]), Color("7a6044"))
				# Lamparina apagada e uma tigela.
				draw_rect(Rect2(-4, -21, 6, 3), Color("a98a5a"))
				draw_rect(Rect2(6, -16, 5, 2), Color("8a7a66"))
			"barrel":
				draw_rect(Rect2(-7, -18, 14, 18), Color("6b4f34"))
				draw_rect(Rect2(-7, -18, 14, 3), Color("8a6a46"))
				draw_line(Vector2(-7, -6), Vector2(6, -6), Color("3e3a33"), 1)
				draw_line(Vector2(-7, -13), Vector2(6, -13), Color("3e3a33"), 1)
			"brazier":
				if not Art.draw_prop(self, "torch"):
					draw_rect(Rect2(-6, -12, 12, 12), Color("6c6556"))
				var flicker := sin(_time * 9.0) * .04
				draw_circle(Vector2(0, -26), 30, Color(1, .62, .26, .07 + flicker))
			_:
				draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * .7)
				if not Art.draw_prop(self, "crate"):
					draw_rect(Rect2(-12, -16, 24, 16), Color("806343"))
				draw_set_transform(Vector2.ZERO)
