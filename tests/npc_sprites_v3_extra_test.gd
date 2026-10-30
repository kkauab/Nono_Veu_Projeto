extends SceneTree
## Folha v3 extra (sacerdote, alquimista, sentinela, mercadora): mesmo contrato
## da v3 do Kauã (64 × 64, 16 poses, pivô 32,58, paleta de 33 cores), pés e
## barra da roupa iguais aos da linha base, aparência própria, e o morador a usa
## em vez da v1. Não abre o mundo nem lê save.
const People = preload("res://scripts/world/townsfolk.gd")
const Catalog = preload("res://scripts/world/port_life_catalog.gd")
const V3_MANIFEST := "res://assets/world/townsfolk_v3_manifest.json"
const MANIFEST := "res://assets/world/townsfolk_v3_extra_manifest.json"
const LOOKS := ["sacerdote", "alquimista", "sentinela", "mercadora"]
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	# A árvore precisa estar montada para o morador entrar nela (_ready carrega as folhas).
	_run.call_deferred()


func _run() -> void:
	var v3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(V3_MANIFEST))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	check(Array(Catalog.LOOKS).slice(v3.looks.size()) == LOOKS, "As 4 aparências novas vêm logo depois das 12 da v3, na ordem da folha extra")
	check(data.looks == LOOKS, "Manifesto lista as 4 aparências na ordem do catálogo")
	check(data.poses == v3.poses and Array(People.POSES) == data.poses, "Mesma ordem de poses da v3 e de townsfolk.gd")
	check(Vector2i(data.cell[0], data.cell[1]) == Vector2i(64, 64) and Vector2i(data.pivot[0], data.pivot[1]) == Vector2i(32, 58), "Célula 64 × 64 e pivô 32,58")
	check(int(data.runtime_scale) == 1 and data.pixel_art, "Pixel art em escala 1")
	check(data.texture == People.EXTRA_SHEET, "townsfolk.gd desenha a folha extra do manifesto")
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(data.texture))
	var base_sheet := Image.load_from_file(ProjectSettings.globalize_path(v3.texture))
	check(sheet != null and base_sheet != null, "Folhas carregam")
	if sheet == null or base_sheet == null:
		_finish()
		return
	sheet.convert(Image.FORMAT_RGBA8)
	base_sheet.convert(Image.FORMAT_RGBA8)
	check(sheet.get_size() == Vector2i(16 * 64, LOOKS.size() * 64), "Atlas 1024 × 256")
	var palette := {}
	for color in v3.palette:
		palette[Color(color).to_rgba32()] = true
	var idle_hashes := {}
	for row in range(LOOKS.size()):
		var look: String = LOOKS[row]
		var base: String = data.sprites[look]["base"]
		var base_row: int = v3.looks.find(base)
		check(base_row >= 0, "%s parte de uma linha da v3 (%s)" % [look, base])
		for pose in range(16):
			var frame := sheet.get_region(Rect2i(Vector2i(pose, row) * 64, Vector2i(64, 64)))
			var base_frame := base_sheet.get_region(Rect2i(Vector2i(pose, base_row) * 64, Vector2i(64, 64)))
			var binary := true
			var allowed := true
			var bytes := frame.get_data()
			for i in range(0, bytes.size(), 4):
				if bytes[i + 3] not in [0, 255]: binary = false
				if bytes[i + 3] == 255:
					var rgba := (int(bytes[i]) << 24) | (int(bytes[i + 1]) << 16) | (int(bytes[i + 2]) << 8) | 255
					if not palette.has(rgba): allowed = false
			check(binary, "%s/%s alfa binário" % [look, People.POSES[pose]])
			check(allowed, "%s/%s só com a paleta da v3" % [look, People.POSES[pose]])
			var used := frame.get_used_rect()
			check(used.size.y > 20 and used.end.y <= 59, "%s/%s personagem inteiro, de pé no chão" % [look, People.POSES[pose]])
			# Pés e barra: mesmo contorno da linha base (só cores podem mudar), sem arrastar o pivô.
			var feet_same := true
			for y in range(58 - 6, 64):
				for x in range(64):
					var lance := look == "sentinela" and absi(x - 40) <= 12
					if lance: continue
					if (frame.get_pixel(x, y).a8 > 0) != (base_frame.get_pixel(x, y).a8 > 0): feet_same = false
			check(feet_same, "%s/%s pés no mesmo lugar da %s" % [look, People.POSES[pose], base])
			if pose == 0:
				var hash := frame.get_data().hex_encode().sha256_text()
				check(not idle_hashes.has(hash), "%s tem aparência própria" % look)
				idle_hashes[hash] = true
				check(frame.get_data() != base_frame.get_data(), "%s não é cópia da %s" % [look, base])
	_check_runtime(v3.looks.size())
	_finish()


func _check_runtime(v3_rows: int) -> void:
	for look in range(Catalog.LOOKS.size()):
		var person := People.new()
		person.look = look
		person.kind = "vendor"
		root.add_child(person)
		var expected := "v3" if look < v3_rows else "v3_extra"
		check(person.sheet_kind() == expected, "%s desenha a folha %s (não a v1)" % [Catalog.LOOKS[look], expected])
		if look >= v3_rows:
			person.time = 1.3 - look * .37
			check(person.pose() == 12, "%s respira" % Catalog.LOOKS[look])
			person.time = 4.75 - look * .37
			check(person.pose() == 13, "%s pisca" % Catalog.LOOKS[look])
		person.free()
	# Pescador: pose de braço estendido segurando a vara.
	var fisher := People.new()
	fisher.look = Catalog.LOOKS.find("remador")
	fisher.stops = [{"at": Vector2.ZERO, "act": "fish", "time": 10.0, "extra": -1, "path": PackedVector2Array()}]
	root.add_child(fisher)
	check(fisher.pose() == 5, "Pescador segura a vara com o braço estendido (pose 5)")
	check(fisher.facing == -1.0, "Pescador olha para a água (extra -1)")
	fisher.free()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error(message)


func _finish() -> void:
	print("NPC SPRITES V3 EXTRA checks=%d passed=%d failures=%s" % [checks, checks - failures.size(), failures])
	quit(0 if failures.is_empty() else 1)
