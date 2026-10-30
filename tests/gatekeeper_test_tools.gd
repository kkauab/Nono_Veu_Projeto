extends RefCounted
## Finish the same public sequences as E/hold-to-skip, for unrelated route tests.
static func defeat(game: Node2D) -> void:
	var boss=game.boss
	var encounter=game.gatekeeper_encounter
	game.hud.show_overlay("")
	if boss.mode==boss.Mode.DORMANT:boss.begin_intro()
	encounter._process(.016)
	if not encounter.sequence.is_empty():encounter.finish_sequence(true)
	boss.receive_hit(9999,game.player.position)
	encounter._process(.016)
	encounter.finish_sequence(true)
	boss.receive_hit(9999,game.player.position)
	encounter._process(.016)
	encounter.finish_sequence(true)
