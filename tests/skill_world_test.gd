extends SceneTree

const Main = preload("res://scenes/boot/main.tscn")
const Skills = preload("res://scripts/progression/skill_catalog.gd")
const Shop = preload("res://scripts/economy/shop_catalog.gd")
var checks := 0
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	create_timer(25).timeout.connect(func(): quit(1))
	if "--qa" not in OS.get_cmdline_user_args():
		push_error("Use -- --qa: this suite never opens the normal save.")
		quit(1)
		return
	var world = Main.instantiate()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	await process_frame
	var player: SenuPlayer = world.player
	check(world.store.path.begins_with("user://qa/"), "World integration uses an isolated QA save")
	check(InputMap.has_action("cast_seal"), "C action is installed by the real game")
	check(not player.try_seal(), "New journey has no free spell before learning it")
	world.store.data["fragments"] = 28
	check(not world.buy_skill("convergencia_nous"), "Final ability is blocked before prerequisites")
	check(world.store.data["fragments"] == 28, "Blocked world purchase spends no Nous")
	player.health = 70
	for id in Skills.ORDER:
		check(world.buy_skill(id), "Real purchase applies " + id)
		check(player.has_skill(id), "Runtime receives ownership of " + id)
	check(world.store.data["fragments"] == 0, "All thirteen nodes cost exactly 28 Nous")
	check(player.max_health == 120 and player.health == 90, "Body upgrade grants only its new twenty life points")
	check(player.damage_bonus == 4, "Legacy damage improvement is applied once")
	check(is_equal_approx(player.power_cooldown_scale, .8), "Legacy weapon-power cooldown is preserved")
	check(is_equal_approx(player.dodge_cooldown, .66 * .8), "Passo Etéreo affects the actual dodge cooldown")
	check(is_equal_approx(player.dodge_invulnerability, .34), "Passo Etéreo adds six hundredths of protection")
	world.store.data["coins"] = 55
	check(Shop.purchase(world.store.data, "sandalias_caravana"), "Existing shop sandals remain purchasable")
	world._apply_upgrades(false)
	var health_before := player.health
	for i in range(5):
		world._apply_upgrades(false)
	check(player.health == health_before and player.max_health == 120, "Recalculating upgrades cannot heal or stack maximum life")
	check(is_equal_approx(player.dodge_cooldown, .66 * .8 * .85), "Skill and shop dodge improvements combine without stacking repeatedly")
	check(is_equal_approx(player.dodge_invulnerability, .34), "Repeated configuration preserves iframe duration")
	check(player.try_seal(), "Learned seal can be cast in the actual world")
	check(is_equal_approx(player.seal_cooldown_remaining, 6), "Convergence changes the active spell to a six-second cooldown")
	check(not player.try_seal(), "Spell cooldown prevents immediate repeated casts")
	var spell
	for projectile in get_nodes_in_group("mercury_projectiles"):
		spell = projectile
	check(spell != null and spell.max_targets == 3, "Convergence configures piercing in the spawned projectile")
	var pickup: PortInteractable
	var remote: PortInteractable
	for item in get_nodes_in_group("interactables"):
		if item.item_id == "nous_cais": pickup = item
		if item.item_id == "nous_beacon": remote = item
	player.position = pickup.position - Vector2(100, 0)
	world._update_skill_perception()
	check(pickup.perceived and not remote.perceived, "Olho do Escriba marks nearby discoveries only")
	check(pickup.active and "nous_cais" not in world.store.data["collected"], "Perception does not collect or solve the object")
	pickup.active = false
	world._update_skill_perception()
	check(not pickup.perceived, "Collected discoveries stop glowing")
	check(world.store.save_progress(), "Expanded build saves successfully")
	var restored := DemoSaveStore.new(world.store.path)
	check(restored.load_progress(), "Expanded build reloads from its real saved file")
	check(restored.data["skills"].size() == 13 and restored.data["purchases"].get("sandalias_caravana") == 1, "Skills coexist with saved shop purchases")
	world.store.data = DemoSaveStore.fresh_data()
	world.store.data["fragments"] = 22
	world._apply_upgrades(true)
	for id in Skills.ORDER:
		if id not in ["lamina_ascendente", "pele_alabastro", "olho_escriba"]:
			check(world.buy_skill(id), "Twenty-two-point exploration budget supports final route: " + id)
	check(player.has_skill("convergencia_nous") and world.store.data["fragments"] == 2, "Current-world budget reaches Convergence with two Nous remaining")
	check(world.buy_skill("olho_escriba") and world.store.data["fragments"] == 0, "The remaining points can purchase optional perception")
	for projectile in get_nodes_in_group("mercury_projectiles"):
		projectile.queue_free()
	world.queue_free()
	await process_frame
	print("SKILL_WORLD ", checks - failures.size(), "/", checks)
	quit(0 if failures.is_empty() else 1)
