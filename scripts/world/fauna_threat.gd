extends RefCounted

## Como aves, cães e gatos leem Senu: parado, andando, correndo (ou esquivando)
## e atacando. Antes cada um lia uma propriedade `is_attacking` que o Senu não
## tem (o ataque nunca assustava ninguém) e tomava o passo normal (80 px/s) por
## corrida, porque o limite era 37 px/s.

enum { STILL, WALK, RUN, ATTACK }

## Abaixo disto Senu está parado (px/s).
const WALK_SPEED := 12.0
## Acima disto está correndo ou esquivando: o passo é 80 px/s, a corrida 136 e a esquiva 187.
const RUN_SPEED := 100.0


static func level(player: Node) -> int:
	if player == null or not is_instance_valid(player):
		return STILL
	var attack: Variant = player.get("attack_timer")
	if attack is float and attack > 0.0:
		return ATTACK
	var flag: Variant = player.get("is_attacking")
	if flag is bool and flag:
		return ATTACK
	var velocity: Variant = player.get("velocity")
	var speed := (velocity as Vector2).length() if velocity is Vector2 else 0.0
	var sprinting: Variant = player.get("is_sprinting")
	if speed > RUN_SPEED or (sprinting is bool and sprinting and speed > WALK_SPEED):
		return RUN
	if speed > WALK_SPEED:
		return WALK
	return STILL
