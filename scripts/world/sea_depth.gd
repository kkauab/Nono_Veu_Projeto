extends RefCounted

## Profundidade do mar (docs/MUNDO_BARCO_ILHA.md, "Mergulho"): para cada tile do
## mar, a distância em tiles até o chão mais próximo, até MAX_DEPTH. Serve a dois
## desenhos: a água da superfície clareia perto do cais (harbor_pixel_water) e o
## fundo visto no mergulho escurece longe dele (sea_dive.gd).
##
## Uma textura de um pixel por tile, sobre todos os tiles do SEA_RECT do layout;
## o chão vale 0 e o mar aberto, 255. Calculada uma vez, ao montar o mar, por uma
## busca em largura a partir do chão que para em MAX_DEPTH.

const Layout = preload("res://scripts/world/port_layout.gd")
const Art = preload("res://scripts/world/port_art.gd")
const MAX_DEPTH := 8

static var origin := Vector2i.ZERO
static var size := Vector2i.ZERO
static var _depths := PackedByteArray()
static var _texture: ImageTexture


static func build(layout) -> ImageTexture:
	var rect: Rect2 = Layout.SEA_RECT
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		var tile := Layout.unproject(corner)
		low = low.min(tile)
		high = high.max(tile)
	origin = Vector2i(floori(low.x), floori(low.y))
	size = Vector2i(ceili(high.x), ceili(high.y)) - origin + Vector2i.ONE
	_depths = PackedByteArray()
	_depths.resize(size.x * size.y)
	_depths.fill(MAX_DEPTH)
	var queue: Array[Vector2i] = []
	for tile: Vector2i in layout.tiles:
		var local := tile - origin
		if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
			continue
		_depths[local.y * size.x + local.x] = 0
		queue.append(local)
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		var next := _depths[cell.y * size.x + cell.x] + 1
		if next >= MAX_DEPTH:
			continue
		for y in range(-1, 2):
			for x in range(-1, 2):
				var near := cell + Vector2i(x, y)
				if near.x < 0 or near.y < 0 or near.x >= size.x or near.y >= size.y:
					continue
				var index := near.y * size.x + near.x
				if _depths[index] > next:
					_depths[index] = next
					queue.append(near)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_L8)
	var bytes := PackedByteArray()
	bytes.resize(_depths.size())
	for index in range(_depths.size()):
		bytes[index] = int(round(float(_depths[index]) / MAX_DEPTH * 255.0))
	image.set_data(size.x, size.y, false, Image.FORMAT_L8, bytes)
	_texture = ImageTexture.create_from_image(image)
	var water: ShaderMaterial = Art.water_material()
	water.set_shader_parameter("depth_map", _texture)
	water.set_shader_parameter("depth_origin", Vector2(origin))
	water.set_shader_parameter("depth_size", Vector2(size))
	return _texture


static func texture() -> ImageTexture:
	return _texture


## O primeiro tile da textura e quantos tiles ela cobre (para o shader do mergulho).
static func origin_tile() -> Vector2i:
	return origin


static func size_tiles() -> Vector2i:
	return size


## Distância em tiles até o chão (0 em terra, MAX_DEPTH longe dele).
static func at_tile(tile: Vector2i) -> int:
	var local := tile - origin
	if _depths.is_empty() or local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y:
		return MAX_DEPTH
	return _depths[local.y * size.x + local.x]


static func at_point(point: Vector2) -> int:
	return at_tile(Vector2i(Layout.unproject(point).round()))
