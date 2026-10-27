class_name WeaponDefinition
extends Resource
## Immutable equipment data. Discovery and equipment belong to the save/player.

@export var id: String = ""
@export var display_name: String = ""
@export_enum("leve", "espada", "pesada") var category: String = "espada"
@export var damage: int = 22
@export var attack_interval: float = 0.42
@export var range_px: float = 40.0
@export var arc_degrees: float = 135.0
@export var color: Color = Color("e8bd75")
@export var power_id: String = "riposta_hermetica"
@export var power_name: String = "Riposta hermética"
@export var power_cooldown: float = 5.0
@export var power_cost: int = 0
@export_multiline var description: String = ""
