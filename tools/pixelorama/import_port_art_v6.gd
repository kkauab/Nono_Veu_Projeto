extends SceneTree
## Confere a exportação real do Pixelorama e publica os recortes do cenário.

const FOLDER := "res://assets/world/"
const CELL := 512

func _initialize() -> void:
	call_deferred("_run")

func reject(message: String) -> void:
	push_error("PORT_ART_IMPORT: " + message)
	quit(1)

func _run() -> void:
	var native: Variant = JSON.parse_string(FileAccess.get_file_as_string(FOLDER + "port_art_v6.json"))
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://art/pixelorama/port_v6/export_plan.json"))
	if not native is Dictionary or not plan is Dictionary:
		reject("Metadados ausentes ou inválidos.")
		return
	var profile: Dictionary = native.get("export_profile", {})
	if int(native.get("size_x", 0)) != CELL or int(native.get("size_y", 0)) != CELL or int(str(profile.get("orientation", "1"))) != 1 or int(str(profile.get("lines_count", "4"))) != 4 or int(str(profile.get("resize", "100"))) != 100 or int(str(profile.get("crop_mode", "0"))) != 0:
		reject("Use células 512 × 512, quatro colunas, escala 100% e sem recorte.")
		return
	var texture := load(FOLDER + "port_art_v6.png") as Texture2D
	if texture == null:
		reject("A imagem exportada precisa ser importada primeiro.")
		return
	var count := (native.get("frames", []) as Array).size()
	var expected := Vector2i(4 * CELL, ceili(float(count) / 4) * CELL)
	if Vector2i(texture.get_size()) != expected:
		reject("Dimensões da imagem não correspondem à linha do tempo.")
		return
	var tags: Dictionary = {}
	for tag in native.get("tags", []):
		if int(tag.get("from", 0)) != int(tag.get("to", -1)):
			reject("Cada material/objeto deve ter uma tag de um quadro.")
			return
		tags[str(tag["name"])] = int(tag["from"]) - 1
	var materials: Array = plan["materials"]
	for index in range(materials.size()):
		if int(tags.get("floor_" + materials[index], -1)) != index:
			reject("Mantenha os oito materiais nas primeiras oito células, na ordem original.")
			return
	var image := texture.get_image()
	for name in plan["props"]:
		var index := int(tags.get("prop_" + name, -1))
		if index < 8 or index >= count:
			reject("Tag do objeto ausente: " + name)
			return
		var region := Rect2i((index % 4) * CELL, (index / 4) * CELL, CELL, CELL)
		var bounds := image.get_region(region).get_used_rect()
		if not bounds.has_area():
			reject("Objeto vazio: " + name)
			return
		plan["props"][name]["frame"] = index
		plan["props"][name]["content_size"] = [bounds.size.x, bounds.size.y]
	plan["texture_size"] = [expected.x, expected.y]
	plan["frame_count"] = count
	plan["exported_by"] = "Pixelorama " + str(native.get("pixelorama_version", ""))
	var output := FileAccess.open(FOLDER + "port_art_v6_manifest.json", FileAccess.WRITE)
	if output == null:
		reject("Não foi possível salvar os recortes do cenário.")
		return
	output.store_string(JSON.stringify(plan, "\t") + "\n")
	output.close()
	print("PORT_ART_IMPORT_OK frames=", count, " materials=", materials.size(), " props=", plan["props"].size())
	quit()
