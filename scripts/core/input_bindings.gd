extends RefCounted

static func install() -> void:
	var bindings := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"sprint": [KEY_SHIFT],
		"attack": [KEY_J], "heavy_attack": [KEY_F], "dodge": [KEY_SPACE],
		"parry": [KEY_K], "weapon_power": [KEY_Q], "cast_seal": [KEY_C], "switch_weapon": [KEY_TAB],
		"interact": [KEY_E], "skill_tree": [KEY_T], "world_map": [KEY_M],
		"pause_game": [KEY_ESCAPE],
		# Bálsamo comprado no Empório de Merit (Gustavo, 27/10/2026).
		"use_item": [KEY_R]
	}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["parry", MOUSE_BUTTON_RIGHT]]:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = pair[1]
		if not InputMap.action_has_event(pair[0], mouse):
			InputMap.action_add_event(pair[0], mouse)
