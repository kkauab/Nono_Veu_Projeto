extends Node2D
## Read-only visual actor. Uses the exact runtime sprite renderer and equipped
## weapon, but has no physics body, player group, damage or gameplay callbacks.
const View = preload("res://scripts/actors/senu_supplied_view.gd")
var source: SenuPlayer
var _view := View.new()
var _time := 0.0
var _tick := 0.0
var facing := Vector2(.7, 1).normalized()
var velocity := Vector2.ZERO
var _visual_distance := 0.0
var _visual_speed := 0.0
var _hurt_direction := Vector2.ZERO
var dead := false
var is_sprinting := false
var _hurt_visual := 0.0
var _dodge_timer := 0.0
var _dodge_direction := Vector2(.7, 1).normalized()
var _attack_direction := Vector2(.7, 1).normalized()
var _attack_visual := 0.0
var attack_timer := 0.0
var _power_visual := 0.0
var _riposte_timer := 0.0
var _shadow_finish := false
var parry_timer := 0.0
var parry_window := .25
var dodge_duration := .48
var power_cooldown_remaining := 0.0
var invulnerability_timer := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func equipped_weapon() -> Resource:
	return source.equipped_weapon()

func demonstrate(action: String) -> void:
	_attack_visual = 0
	attack_timer = 0
	parry_timer = 0
	_dodge_timer = 0
	match action:
		"attack":
			_attack_visual = .19
			attack_timer = .42
		"dodge": _dodge_timer = dodge_duration
		"parry": parry_timer = parry_window
	queue_redraw()

func _process(delta: float) -> void:
	_time += delta
	_tick += delta
	_attack_visual = maxf(0, _attack_visual - delta)
	attack_timer = maxf(0, attack_timer - delta)
	parry_timer = maxf(0, parry_timer - delta)
	_dodge_timer = maxf(0, _dodge_timer - delta)
	if _tick >= 1.0 / 20.0:
		_tick = 0
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source): return
	var frame := _view.sample(self)
	if frame.is_empty(): return
	# Same runtime body and equipment layers, without painting the world's
	# contact shadow onto the notebook paper.
	var behind: bool = _view.current_direction in ["up", "up_left", "up_right"]
	if frame.get("modular_equipment", false) and behind: _view._draw_equipment(self, frame)
	var motion: Dictionary = frame["motion"]
	View.PixelMotion.draw_frame(self, frame["texture"], frame["offset"], frame["size"], frame["region"], frame["tint"], motion["upper_offset"], motion["middle_offset"])
	if frame.get("modular_equipment", false) and not behind: _view._draw_equipment(self, frame)
