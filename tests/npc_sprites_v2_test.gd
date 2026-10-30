extends SceneTree
## Asset contract and pose selection; no world or journey is loaded.
const People = preload("res://scripts/world/townsfolk.gd")
const Catalog = preload("res://scripts/world/port_life_catalog.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	var old := Image.load_from_file("res://assets/world/townsfolk_v1.png")
	var sheet := Image.load_from_file("res://assets/world/townsfolk_v2.png")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/townsfolk_v2_manifest.json"))
	check(sheet != null and sheet.get_size() == Vector2i(512, 624), "Resident atlas has all 12 appearances and 16 poses")
	check(manifest["looks"] == Catalog.LOOKS, "Catalog appearances retain their original indices")
	check(Vector2(manifest["pivot"][0], manifest["pivot"][1]) == Vector2(16,49), "Resident foot pivot remains unchanged")
	for row in range(12):
		for pose in range(12):
			check(cel(old, row, pose).get_data() == cel(sheet, row, pose).get_data(), "%s original %s preserved" % [Catalog.LOOKS[row], People.POSES[pose]])
		for pair in [[0,12], [0,13], [6,14], [6,15]]:
			var base := cel(sheet, row, pair[0])
			var new := cel(sheet, row, pair[1])
			check(base.get_region(Rect2i(0,44,32,8)).get_data() == new.get_region(Rect2i(0,44,32,8)).get_data(), "%s %s feet anchored" % [Catalog.LOOKS[row], People.POSES[pair[1]]])
			check(base.get_data() != new.get_data(), "%s %s is a painted pose" % [Catalog.LOOKS[row], People.POSES[pair[1]]])
		var person := People.new()
		person.look = row
		person.kind = "vendor"
		person.time = 1.3 - row * .37
		check(person.pose() == 12, "%s breathes while resting" % Catalog.LOOKS[row])
		person.time = 4.75 - row * .37
		check(person.pose() == 13, "%s has a brief closed eyelid" % Catalog.LOOKS[row])
		person.carrying = true
		check(person.rest_pose() == 15, "%s keeps the load while blinking" % Catalog.LOOKS[row])
		person.free()
	var ankhet := Image.load_from_file("res://assets/world/ankhet_v2.png")
	var ankhet_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/ankhet_v2_manifest.json"))
	check(ankhet.get_size() == Vector2i(512,144), "Ankhet has four complete poses")
	check(Vector2(ankhet_plan["pivot"][0], ankhet_plan["pivot"][1]) == Vector2(64,112), "Ankhet keeps the island pivot")
	for index in range(1,4):
		check(ankhet.get_region(Rect2i(0,108,128,36)).get_data() == ankhet.get_region(Rect2i(index*128,108,128,36)).get_data(), "Ankhet hem and staff stay planted in pose %d" % index)
	for image in [sheet, ankhet]:
		var bytes: PackedByteArray = image.get_data()
		var binary := true
		for index in range(3,bytes.size(),4):
			if bytes[index] != 0 and bytes[index] != 255: binary = false
		check(binary, "Atlas alpha is binary for crisp pixels")
	preview(sheet, ankhet)
	print("NPC SPRITES V2 checks=%d passed=%d failures=%s" % [checks, checks-failures.size(),failures])
	quit(0 if failures.is_empty() else 1)

func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures.append(text)
		push_error(text)

func cel(sheet: Image, row: int, pose: int) -> Image:
	return sheet.get_region(Rect2i(pose*32,row*52,32,52))

func preview(sheet: Image, ankhet: Image) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://qa/npcs_v2"))
	var poses := [0,12,13,5,6,14,15,11]
	for group in range(2):
		var board := Image.create_empty(32*8,52*6,false,Image.FORMAT_RGBA8)
		board.fill(Color("20383d"))
		for row in range(6):
			for column in range(8):
				board.blend_rect(cel(sheet,row+group*6,poses[column]),Rect2i(0,0,32,52),Vector2i(column*32,row*52))
		board.resize(board.get_width()*4,board.get_height()*4,Image.INTERPOLATE_NEAREST)
		board.save_png("res://qa/npcs_v2/residents_%d.png" % (group+1))
	var board := Image.create_empty(128*4,144,false,Image.FORMAT_RGBA8)
	board.fill(Color("20383d"))
	board.blend_rect(ankhet,Rect2i(0,0,512,144),Vector2i.ZERO)
	board.resize(1536,432,Image.INTERPOLATE_NEAREST)
	board.save_png("res://qa/npcs_v2/ankhet.png")
