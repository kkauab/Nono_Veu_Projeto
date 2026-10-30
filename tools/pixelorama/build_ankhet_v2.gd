extends "res://tools/pixelorama/build_sea_v1.gd"
## Separate editable project: existing sea_v1 art is never regenerated.
const NPC_DIR := "res://art/pixelorama/npcs_v2"

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(NPC_DIR))
	var sheet := _new_sheet("ankhet_v2", Vector2i(128, 144), Vector2i(64, 112), 4)
	for pose in range(4):
		_begin()
		_ankhet(-1 if pose == 1 else 0, pose == 2)
		if pose == 3:
			# Her free hand opens toward the herons; staff and hem remain planted.
			_line(Vector2(-6, -22), Vector2(-12, -18), "teal_dark")
			_line(Vector2(-12, -18), Vector2(-17, -23), "tan")
			_line(Vector2(-12, -17), Vector2(-17, -22), "gold_dark")
			_rect(-19, -25, 3, 3, "tan")
		_outline()
		_end("ankhet")
	sheet.sprites["ankhet"]["authored_poses"] = ["rest", "breathe", "blink", "gesture"]
	sheet.sprites["ankhet"]["fps"] = 8.0
	sheet.sprites["ankhet"]["sequence"] = [0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,2,0,0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0]
	# Reuse the native writer, then move only this newly created project/plan.
	_write_pxo(sheet)
	_write_plan(sheet)
	var old_native := "%s/ankhet_v2.pxo" % OUT_DIR
	var old_plan := "%s/ankhet_v2_export_plan.json" % OUT_DIR
	assert(DirAccess.rename_absolute(ProjectSettings.globalize_path(old_native), ProjectSettings.globalize_path(NPC_DIR + "/ankhet_v2.pxo")) == OK)
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_plan))
	plan["version"] = 2
	plan["source"] = NPC_DIR + "/ankhet_v2.pxo"
	FileAccess.open(NPC_DIR + "/ankhet_v2_export_plan.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	FileAccess.open("res://assets/world/ankhet_v2_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(plan, "\t"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_plan))
	print("ANKHET_V2 poses=4 pivot=(64,112)")
	quit()
