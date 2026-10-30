extends Node
## One viewport-wide UI sound pool and non-invasive native-button presentation.
const SOUND := preload("res://assets/audio/ui/menu_select.wav")
const Sfx := preload("res://scripts/audio/sfx.gd")
const POOL_KEY := "VeilUiButtonFeedback"
const ATTACHED_KEY := "veil_button_feedback"
const SCREEN_KEY := "ui_feedback_screen"
# The same short bronze tick, voiced slightly differently for each screen.
# The title keeps the original sound approved by the player.
const SOUND_PROFILES := {
	"intro":Vector2(1.0,-8.0), "pause":Vector2(.94,-8.0),
	"inventory":Vector2(1.08,-8.5), "map":Vector2(.88,-8.0),
	"tree":Vector2(1.16,-9.0), "journal":Vector2(1.02,-8.5),
	"settings":Vector2(.96,-8.5), "controls":Vector2(1.05,-8.5),
	"exit":Vector2(.84,-9.0), "dialog":Vector2(1.11,-9.0),
	"shop":Vector2(1.06,-8.0), "new_journey":Vector2(.90,-8.5)
}
signal sounded
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var play_count := 0
var last_screen := ""
var last_pitch := 1.0

static func install(context: Node) -> Node:
	if context == null or not context.is_inside_tree(): return null
	var viewport := context.get_viewport()
	var stored: Variant = viewport.get_meta(POOL_KEY) if viewport.has_meta(POOL_KEY) else null
	if is_instance_valid(stored): return stored
	var pool := new()
	pool.name = POOL_KEY
	viewport.set_meta(POOL_KEY, pool)
	viewport.add_child.call_deferred(pool)
	return pool

static func play(context: Node) -> void:
	var pool := install(context)
	if pool == null: return
	var screen := screen_for(context)
	if pool.is_node_ready(): pool.play_tick(screen)
	else: pool.play_tick.call_deferred(screen)

static func screen_for(context: Node) -> String:
	var node := context
	while node != null:
		if node.has_meta(SCREEN_KEY): return str(node.get_meta(SCREEN_KEY))
		node = node.get_parent()
	return "intro"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Sfx.ensure_buses()
	for index in range(4):
		var voice := AudioStreamPlayer.new()
		voice.name = "UiVoice%d" % index
		voice.bus = "SFX"
		voice.stream = SOUND
		voice.volume_db = -8.0
		add_child(voice)
		_voices.append(voice)
	get_tree().node_added.connect(_node_added)
	_scan(get_viewport())

func play_tick(screen: String = "intro") -> void:
	if _voices.is_empty(): return
	var profile: Vector2 = SOUND_PROFILES.get(screen, SOUND_PROFILES["intro"])
	_voices[_next_voice].pitch_scale = profile.x
	_voices[_next_voice].volume_db = profile.y
	_voices[_next_voice].play()
	_next_voice = (_next_voice + 1) % _voices.size()
	play_count += 1
	last_screen = screen
	last_pitch = profile.x
	sounded.emit()

func _scan(node: Node) -> void:
	_node_added(node)
	for child in node.get_children(): _scan(child)

func _node_added(node: Node) -> void:
	if node is BaseButton and node.get_viewport() == get_viewport():
		_attach_when_alive.call_deferred(weakref(node))

func _attach_when_alive(reference: WeakRef) -> void:
	var button=reference.get_ref()
	if is_instance_valid(button) and button is BaseButton:_attach(button)

func _attach(button: BaseButton) -> void:
	if not is_instance_valid(button) or not button.is_inside_tree(): return
	if button.has_meta(ATTACHED_KEY) or button.get_meta("title_menu_presentation", false): return
	button.set_meta(ATTACHED_KEY, true)
	var feedback := ButtonGlow.new()
	feedback.name = "PixelButtonFeedback"
	feedback.button = button
	feedback.pool = self
	button.add_child(feedback)

func _exit_tree() -> void:
	for voice in _voices: voice.stop()

class ButtonGlow extends Control:
	const GOLD := Color("cfac70")
	var button: BaseButton
	var pool: Node
	var _hover := false
	var _amount := 0.0
	var _pulse := 1.0
	var clicks := 0
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.mouse_entered.connect(func(): _hover = true)
		button.mouse_exited.connect(func(): _hover = false)
		button.button_down.connect(_down)
	func _down() -> void:
		if button.disabled: return
		_pulse = 0.0
		clicks += 1
		pool.play_tick(pool.screen_for(button))
	func _process(delta: float) -> void:
		var target := 1.0 if not button.disabled and (_hover or button.has_focus()) else 0.0
		_amount = lerpf(_amount, target, 1.0 - exp(-delta * 13.0))
		_pulse = minf(1.0, _pulse + delta / .28)
		queue_redraw()
	func _draw() -> void:
		if button.disabled: return
		var pulse := sin(_pulse * PI) if _pulse < 1.0 else 0.0
		var strength := maxf(_amount * .65, pulse)
		if strength < .01: return
		var unit := maxf(1.0, roundf(get_viewport_rect().size.y / 540.0))
		var inset := minf(3 * unit, size.y * .14)
		var reach := minf(9 * unit, size.x * .15)
		var tint := Color(GOLD, strength * .85)
		for corner in [Vector2(inset,inset),Vector2(size.x-inset,inset),Vector2(inset,size.y-inset),Vector2(size.x-inset,size.y-inset)]:
			var direction := Vector2(1 if corner.x < size.x*.5 else -1,1 if corner.y < size.y*.5 else -1)
			draw_line(corner.round(), (corner+Vector2(direction.x*reach,0)).round(), tint, unit)
			draw_line(corner.round(), (corner+Vector2(0,direction.y*minf(reach,5*unit))).round(), tint, unit)
		if _pulse < 1.0:
			var x := roundf(lerpf(inset, size.x-inset, _pulse))
			draw_rect(Rect2(x,inset,unit*2,maxf(0,size.y-inset*2)),Color(GOLD,pulse*.10))
			draw_line(Vector2(inset,size.y-inset).round(),Vector2(x,size.y-inset).round(),Color(GOLD,pulse*.65),unit)
