extends RefCounted
## Bundled pixel typography: identical on every machine, including Portuguese.
const SOURCE = preload("res://assets/fonts/PixelOperatorHB.ttf")
const TITLE_SOURCE = preload("res://assets/fonts/PixelOperator-Bold.ttf")
static var _body: FontFile
static var _title: FontFile

static func body() -> Font:
	if _body == null:
		_body = SOURCE.duplicate() as FontFile
		_body.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_body.hinting = TextServer.HINTING_NONE
		_body.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_body.multichannel_signed_distance_field = false
		_body.generate_mipmaps = false
	return _body

static func title() -> Font:
	if _title == null:
		_title = TITLE_SOURCE.duplicate() as FontFile
		_title.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		_title.hinting = TextServer.HINTING_NONE
		_title.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_title.multichannel_signed_distance_field = false
		_title.generate_mipmaps = false
	return _title

static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = body()
	result.default_font_size = 16
	return result
