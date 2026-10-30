extends SceneTree
const Typography = preload("res://scripts/ui/ui_typography.gd")
func _initialize() -> void:
	var failures: Array[String] = []
	var glyphs := 0
	var body := Typography.body() as FontFile
	var title := Typography.title() as FontFile
	for face in [body,title]:
		if face == null or face.antialiasing != TextServer.FONT_ANTIALIASING_NONE:
			failures.append("Pixel font must rasterize without antialiasing")
		for character in "ÁÀÂÃÉÊÍÓÔÕÚÜÇáàâãéêíóôõúüç0123456789":
			glyphs += 1
			if not face.has_char(character.unicode_at(0)): failures.append(character)
		if face.subpixel_positioning != TextServer.SUBPIXEL_POSITIONING_DISABLED:
			failures.append("Subpixel positioning must remain disabled")
	if Typography.make_theme().default_font != body: failures.append("Native controls must inherit the same bundled font")
	print("PIXEL FONT glyphs=",glyphs," failures=",failures)
	quit(0 if failures.is_empty() else 1)
