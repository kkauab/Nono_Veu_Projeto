extends SceneTree
## Shortcut into the actual encounter, with starter Senu and isolated progress.
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	if "--qa" not in OS.get_cmdline_user_args():quit(1);return
	var game=load("res://scenes/boot/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	await process_frame
	for id in ["seal_bells","seal_water","seal_stars"]:game.store.data["flags"][id]=true
	game.store.data["checkpoint"]="s1"
	preload("res://scripts/economy/shop_catalog.gd").refill(game.store.data)
	game.refresh_seals()
	game.hud.show_overlay("")
	game.player.reset_at(PortLayout.iso(Vector2(-2,23)))
	game.current_room="b1"
	game.player.get_node("IsometricCamera").reset_smoothing()
	DisplayServer.window_set_title("O Nono Véu — Porteiro · teste com progresso separado")
