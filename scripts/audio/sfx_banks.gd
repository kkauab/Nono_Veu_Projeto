extends RefCounted
## Gerado por tools/audio/build_combat_sfx.py; não edite à mão.

const BANKS := {
	"swing_sword": [preload("res://assets/audio/sfx/swing_sword_01.wav"), preload("res://assets/audio/sfx/swing_sword_02.wav"), preload("res://assets/audio/sfx/swing_sword_03.wav")],
	"swing_dagger": [preload("res://assets/audio/sfx/swing_dagger_01.wav"), preload("res://assets/audio/sfx/swing_dagger_02.wav"), preload("res://assets/audio/sfx/swing_dagger_03.wav")],
	"swing_heavy": [preload("res://assets/audio/sfx/swing_heavy_01.wav"), preload("res://assets/audio/sfx/swing_heavy_02.wav")],
	"swing_enemy": [preload("res://assets/audio/sfx/swing_enemy_01.wav"), preload("res://assets/audio/sfx/swing_enemy_02.wav"), preload("res://assets/audio/sfx/swing_enemy_03.wav")],
	"hit_light": [preload("res://assets/audio/sfx/hit_light_01.wav"), preload("res://assets/audio/sfx/hit_light_02.wav"), preload("res://assets/audio/sfx/hit_light_03.wav"), preload("res://assets/audio/sfx/hit_light_04.wav")],
	"hit_heavy": [preload("res://assets/audio/sfx/hit_heavy_01.wav"), preload("res://assets/audio/sfx/hit_heavy_02.wav"), preload("res://assets/audio/sfx/hit_heavy_03.wav")],
	"hit_kill": [preload("res://assets/audio/sfx/hit_kill_01.wav"), preload("res://assets/audio/sfx/hit_kill_02.wav")],
	"parry": [preload("res://assets/audio/sfx/parry_01.wav"), preload("res://assets/audio/sfx/parry_02.wav")],
	"hurt": [preload("res://assets/audio/sfx/hurt_01.wav"), preload("res://assets/audio/sfx/hurt_02.wav"), preload("res://assets/audio/sfx/hurt_03.wav")],
	"death": [preload("res://assets/audio/sfx/death.wav")],
	"dodge": [preload("res://assets/audio/sfx/dodge_01.wav"), preload("res://assets/audio/sfx/dodge_02.wav"), preload("res://assets/audio/sfx/dodge_03.wav")],
	"enemy_windup": [preload("res://assets/audio/sfx/enemy_windup_01.wav"), preload("res://assets/audio/sfx/enemy_windup_02.wav")],
	"power_riposte": [preload("res://assets/audio/sfx/power_riposte.wav")],
	"power_shadow": [preload("res://assets/audio/sfx/power_shadow.wav")],
	"water_splash": [preload("res://assets/audio/sfx/water_splash_01.wav"), preload("res://assets/audio/sfx/water_splash_02.wav"), preload("res://assets/audio/sfx/water_splash_03.wav")],
	"water_plop": [preload("res://assets/audio/sfx/water_plop_01.wav"), preload("res://assets/audio/sfx/water_plop_02.wav"), preload("res://assets/audio/sfx/water_plop_03.wav"), preload("res://assets/audio/sfx/water_plop_04.wav")],
	"water_bubble": [preload("res://assets/audio/sfx/water_bubble_01.wav"), preload("res://assets/audio/sfx/water_bubble_02.wav"), preload("res://assets/audio/sfx/water_bubble_03.wav")],
	"water_loop": [preload("res://assets/audio/sfx/water_loop.wav")],
	"pickup_coin": [preload("res://assets/audio/sfx/pickup_coin_01.wav"), preload("res://assets/audio/sfx/pickup_coin_02.wav"), preload("res://assets/audio/sfx/pickup_coin_03.wav")],
	"door_open": [preload("res://assets/audio/sfx/door_open_01.wav"), preload("res://assets/audio/sfx/door_open_02.wav")],
	"chest_open": [preload("res://assets/audio/sfx/chest_open_01.wav"), preload("res://assets/audio/sfx/chest_open_02.wav")]
}

const BUS := {
	"swing_sword": "SFX",
	"swing_dagger": "SFX",
	"swing_heavy": "SFX",
	"swing_enemy": "SFX",
	"hit_light": "SFX",
	"hit_heavy": "SFX",
	"hit_kill": "SFX",
	"parry": "SFX",
	"hurt": "SFX",
	"death": "SFX",
	"dodge": "SFX",
	"enemy_windup": "SFX",
	"power_riposte": "SFX",
	"power_shadow": "SFX",
	"water_splash": "Ambiente",
	"water_plop": "Ambiente",
	"water_bubble": "Ambiente",
	"water_loop": "Ambiente",
	"pickup_coin": "SFX",
	"door_open": "SFX",
	"chest_open": "SFX"
}

const VOLUME_DB := {
	"swing_sword": -9.0,
	"swing_dagger": -11.0,
	"swing_heavy": -7.0,
	"swing_enemy": -10.0,
	"hit_light": -4.0,
	"hit_heavy": -2.0,
	"hit_kill": -1.0,
	"parry": -3.0,
	"hurt": -3.0,
	"death": -2.0,
	"dodge": -13.0,
	"enemy_windup": -15.0,
	"power_riposte": -4.0,
	"power_shadow": -5.0,
	"water_splash": -12.0,
	"water_plop": -11.0,
	"water_bubble": -20.0,
	"water_loop": -16.0,
	"pickup_coin": -8.0,
	"door_open": -8.0,
	"chest_open": -7.0
}
