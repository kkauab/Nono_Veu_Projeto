extends SceneTree

## Moradores v3 extra (O Nono Véu): sacerdote, alquimista, sentinela e mercadora
## no estilo da folha v3 do Kauã (64 × 64, 16 poses, pivô 32,58).
##
## Cada aparência parte de uma linha pronta da v3 (corpo, pés, pivô, respiração e
## piscada intactos) e troca só cores de roupa, dentro da mesma paleta de 33
## cores da v3; a sentinela ganha uma lança. As cores seguem os retratos de
## assets/ui/dialogue_v15. A folha v3 do Kauã é só lida, nunca escrita.
##
## Execução:
## & "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/pixelorama/build_townsfolk_v3_extra.gd

const SOURCE := "res://assets/world/townsfolk_v3.png"
const SOURCE_MANIFEST := "res://assets/world/townsfolk_v3_manifest.json"
const OUT := "res://assets/world/townsfolk_v3_extra.png"
const MANIFEST := "res://assets/world/townsfolk_v3_extra_manifest.json"
const CELL := Vector2i(64, 64)
const PIVOT := Vector2i(32, 58)
const POSES := ["idle", "walk_1", "walk_2", "walk_3", "walk_4", "talk", "carry_idle", "carry_1", "carry_2", "carry_3", "carry_4", "bend", "breathe", "blink", "carry_breathe", "carry_blink"]
## Poses sem carga e sem curvar: as que mostram a lança.
const UPRIGHT := [0, 1, 2, 3, 4, 5, 12, 13]
## Poses paradas: a lança fica na mão da pose de repouso, não pula com o gesto.
const STILL := [0, 5, 12, 13]

## `body`: troca de cores no corpo todo; `head`: troca nas `head_rows` linhas de
## cima da figura (cabelo, pano de cabeça), com prioridade sobre `body`.
const LOOKS := [
	{
		"name": "sacerdote", "base": "escriba",
		# Estola dourada no lugar da faixa azul do escriba; linho branco mantido.
		"body": {"1e343a": "674d34", "1f444b": "846443", "2b4449": "846443", "2c5b61": "be733a", "3c5659": "a27d50", "3e7373": "e69d4a", "526765": "c39e65", "609087": "f5cc76"},
		"head": {}, "head_rows": 0, "spear": false
	},
	{
		"name": "alquimista", "base": "velho",
		# Capuz e manto azul-petróleo do retrato, no lugar do verde-oliva do velho.
		"body": {"5a623e": "1f444b", "7d8051": "2c5b61", "a49e66": "3e7373", "343b38": "1e343a", "4b5553": "2b4449", "646b60": "3c5659", "81816e": "526765", "a09a7e": "6d7b70", "bdad89": "8c9380"},
		"head": {}, "head_rows": 0, "spear": false
	},
	{
		"name": "sentinela", "base": "marinheiro",
		# Túnica verde-oliva, correias de couro, elmo de bronze e lança.
		"body": {"eee0ba": "a49e66", "dbcfaa": "7d8051", "b4b298": "5a623e", "8c9380": "7d8051", "6d7b70": "5a623e",
			"1e343a": "332e28", "1f444b": "4b3b2d", "2b4449": "4b3b2d", "2c5b61": "674d34", "3c5659": "674d34", "3e7373": "846443", "526765": "846443", "609087": "a27d50"},
		"head": {"1e343a": "674d34", "1f444b": "a27d50", "2b4449": "846443", "2c5b61": "be733a", "3c5659": "a27d50", "3e7373": "e69d4a", "526765": "c39e65", "609087": "f5cc76",
			"eee0ba": "eee0ba", "dbcfaa": "dbcfaa", "b4b298": "b4b298", "8c9380": "8c9380", "6d7b70": "6d7b70"},
		"head_rows": 9, "spear": true
	},
	{
		"name": "mercadora", "base": "padeira",
		# Vestido azul-petróleo, avental dourado e turbante branco do retrato.
		"body": {"5a623e": "1f444b", "7d8051": "2c5b61", "a49e66": "3e7373", "646b60": "2b4449", "81816e": "3c5659",
			"eee0ba": "f5cc76", "dbcfaa": "e0bd7e", "b4b298": "c39e65"},
		"head": {"332e28": "b4b298", "4b3b2d": "dbcfaa", "674d34": "eee0ba", "eee0ba": "eee0ba", "dbcfaa": "dbcfaa", "b4b298": "b4b298"},
		"head_rows": 6, "spear": false
	}
]

const INK := "14252c"
const WOOD := "846443"
const WOOD_DARK := "674d34"
const BRONZE := ["be733a", "e69d4a", "f5cc76"]


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	source.convert(Image.FORMAT_RGBA8)
	var base_manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE_MANIFEST))
	var base_looks: Array = base_manifest["looks"]
	var palette: Array = base_manifest["palette"]
	var sheet := Image.create(CELL.x * POSES.size(), CELL.y * LOOKS.size(), false, Image.FORMAT_RGBA8)
	var sprites := {}
	for row in range(LOOKS.size()):
		var look: Dictionary = LOOKS[row]
		var base_row := base_looks.find(look["base"])
		assert(base_row >= 0, "linha base inexistente: " + str(look["base"]))
		var spear_x := -1
		var frames: Array = []
		for pose in range(POSES.size()):
			var cel := source.get_region(Rect2i(Vector2i(pose, base_row) * CELL, CELL))
			_recolor(cel, look)
			if look["spear"] and pose in UPRIGHT:
				var hand := _front_hand(cel)
				# Um pixel para dentro: a mão fica sobre a haste.
				if pose == 0: spear_x = hand - 1
				_spear(cel, spear_x if pose in STILL else hand - 1)
			sheet.blit_rect(cel, Rect2i(Vector2i.ZERO, CELL), Vector2i(pose, row) * CELL)
			frames.append(row * POSES.size() + pose)
		sprites[look["name"]] = {"frames": frames, "authored_poses": POSES, "base": look["base"]}
	sheet.save_png(ProjectSettings.globalize_path(OUT))

	var names: Array = []
	for look in LOOKS: names.append(look["name"])
	var manifest := {
		"version": 1,
		"pixel_art": true,
		"runtime_scale": 1,
		"texture": OUT,
		"source": "res://tools/pixelorama/build_townsfolk_v3_extra.gd",
		"derived_from": SOURCE,
		"canvas": [CELL.x, CELL.y],
		"cell": [CELL.x, CELL.y],
		"pivot": [PIVOT.x, PIVOT.y],
		"columns": POSES.size(),
		"frames": LOOKS.size() * POSES.size(),
		"palette": palette,
		"looks": names,
		"poses": POSES,
		"sprites": sprites
	}
	var file := FileAccess.open(ProjectSettings.globalize_path(MANIFEST), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("TOWNSFOLK_V3_EXTRA looks=%d poses=%d sheet=%s" % [LOOKS.size(), POSES.size(), ProjectSettings.globalize_path(OUT)])
	quit()


func _recolor(cel: Image, look: Dictionary) -> void:
	var body: Dictionary = look["body"]
	var head: Dictionary = look["head"]
	var top := cel.get_used_rect().position.y
	var head_end := top + int(look["head_rows"])
	for y in range(CELL.y):
		for x in range(CELL.x):
			var color := cel.get_pixel(x, y)
			if color.a8 == 0:
				continue
			var hex := color.to_html(false)
			var target := ""
			if y < head_end and head.has(hex):
				target = head[hex]
			elif body.has(hex):
				target = body[hex]
			if target != "":
				cel.set_pixel(x, y, Color(target))


## Coluna mais à direita do tronco (a mão da frente): a figura olha para a direita.
func _front_hand(cel: Image) -> int:
	var used := cel.get_used_rect()
	var best := used.position.x + used.size.x / 2
	for y in range(used.position.y + 14, mini(used.position.y + 27, CELL.y)):
		for x in range(used.end.x - 1, used.position.x, -1):
			if cel.get_pixel(x, y).a8 > 0:
				best = maxi(best, x)
				break
	return best


## Lança de pé ao lado da mão da frente: haste de madeira com contorno e ponta de
## bronze acima da cabeça. Só ocupa pixels vazios (a mão fica por cima da haste).
func _spear(cel: Image, x: int) -> void:
	var used := cel.get_used_rect()
	var tip := maxi(1, used.position.y - 7)
	var foot := PIVOT.y - 1
	# Ponta: losango de bronze, 3 px de largura.
	_put(cel, x, tip, BRONZE[2])
	for y in [tip + 1, tip + 2]:
		_put(cel, x - 1, y, BRONZE[0])
		_put(cel, x, y, BRONZE[2] if y == tip + 1 else BRONZE[1])
		_put(cel, x + 1, y, BRONZE[0])
	_put(cel, x, tip + 3, BRONZE[0])
	for y in range(tip + 4, foot + 1):
		_put(cel, x, y, WOOD if (y / 3) % 2 == 0 else WOOD_DARK)
	# Contorno escuro, como o resto da arte v3.
	for y in range(tip - 1, foot + 2):
		for dx in [-2, -1, 1, 2]:
			var px: int = x + dx
			if px < 0 or px >= CELL.x or y < 0 or y >= CELL.y:
				continue
			if cel.get_pixel(px, y).a8 == 0 and _touches_spear(cel, px, y, x, tip, foot):
				cel.set_pixel(px, y, Color(INK))
	if tip - 1 >= 0 and cel.get_pixel(x, tip - 1).a8 == 0:
		cel.set_pixel(x, tip - 1, Color(INK))


func _touches_spear(cel: Image, px: int, y: int, x: int, tip: int, foot: int) -> bool:
	for dx in [-1, 0, 1]:
		var nx: int = px + dx
		if nx == x and y >= tip and y <= foot:
			return true
		if absi(nx - x) == 1 and (y == tip + 1 or y == tip + 2):
			return true
	return false


func _put(cel: Image, x: int, y: int, hex: String) -> void:
	if x < 0 or y < 0 or x >= CELL.x or y >= CELL.y:
		return
	if cel.get_pixel(x, y).a8 == 0:
		cel.set_pixel(x, y, Color(hex))
