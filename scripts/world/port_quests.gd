extends RefCounted
## Optional errands persist as unique collected IDs, compatible with old saves.
const Story = preload("res://scripts/world/port_story.gd")
const QUESTS := {
	"merit": {"name": "O perfume que ficou", "giver": "Merit", "place": "Empório de Merit · Armazém das Vozes", "reward": 30, "item": "quest_mirra", "tile": Vector2(22, 23), "target": "Jarro de mirra", "hint": "Recolha o jarro de mirra no Jardim Inundado e leve-o a Merit.", "intro": "MERIT — Cada frasco tem um cheiro. É assim que sei o que cura, mesmo quando esqueço os nomes. Meu último jarro de mirra ficou no Jardim Inundado, perto das comportas.\n\nSENU — Ainda precisa dele?\n\nMERIT — Para tratar os que voltarem. Procure um jarro de barro com uma faixa azul.", "ending": "Merit abre o jarro, respira fundo e sorri pela primeira vez.\n\nMERIT — É o cheiro do meu antigo pátio. Por um instante, lembrei até da voz de minha mãe. Guarde estes óbolos; você me devolveu mais que remédio."},
	"nakht": {"name": "Bronze que canta", "giver": "Nakht", "place": "Forja de Nakht · Fornos do Bronze", "reward": 40, "item": "quest_tenaz", "tile": Vector2(69, 5), "target": "Tenaz marcada de Nakht", "hint": "Busque a tenaz nos Fornos do Bronze e devolva-a a Nakht.", "intro": "NAKHT — Uma ferramenta não esquece a mão que a fez. Perdi minha tenaz junto aos fornos do distrito. Há uma espiral gravada no cabo.\n\nSENU — Sem ela a forja para?\n\nNAKHT — Continuo trabalhando. Mas era com aquela que eu ensinava meu aprendiz. Quero conservar alguma coisa que ainda conte essa história.", "ending": "Nakht alinha a espiral do cabo com uma cicatriz na palma da mão.\n\nNAKHT — Ele errou o primeiro rebite. Eu disse que todo bronze precisa aprender a cantar. Agora lembro por que dizia isso. Obrigado, Senu."},
	"adiam": {"name": "Cartografia das margens", "giver": "Adiam", "place": "Tenda de Adiam · Portão das Caravanas", "reward": 25, "rooms": ["aqueduct", "beacon"], "hint": "Explore o Aqueduto Silencioso e o Terraço do Farol Partido; depois fale com Adiam.", "intro": "ADIAM — Meus mapas continuam desenhando caminhos que já não existem. Preciso de olhos que tenham atravessado o Porto.\n\nSENU — Quais margens?\n\nADIAM — O Aqueduto Silencioso e o Terraço do Farol Partido. Vá aos dois e volte para contar o que viu. Se já passou por eles, suas lembranças também servem.", "ending": "Adiam prende dois nós novos no cordão e corrige as margens no mapa.\n\nADIAM — Agora posso indicar uma rota a quem ainda procura casa. Você não trouxe tinta, Senu. Trouxe um caminho que alguém realmente percorreu."},
	"tarek": {"name": "O último turno", "giver": "Tarek", "place": "Casa da Guarda · Guarita do Retorno", "reward": 35, "item": "quest_escala", "tile": Vector2(8, -33), "target": "Escala da guarda", "hint": "Encontre a escala no Arquivo dos Nomes Velados e devolva-a a Tarek na Casa da Guarda.", "intro": "TAREK — Faço a ronda e volto para uma cama que não sei se é minha. Os nomes do meu turno foram levados ao Arquivo dos Nomes Velados.\n\nSENU — Quer que eu procure o seu?\n\nTAREK — Procure todos. Um rolo preso por um selo de bronze. Não quero ser o único a lembrar que aquelas pessoas existiram.", "ending": "Tarek lê os nomes em voz baixa, um de cada vez.\n\nTAREK — Eu ia pedir para você encontrar meu nome. Mas este aqui… Nefru me cobria quando eu dormia de pé. Ainda posso lembrar deles. Já é um começo."}
}

static func build(game) -> void:
	for id in QUESTS:
		var quest: Dictionary = QUESTS[id]
		if not quest.has("item") or quest["item"] in game.store.data["collected"]: continue
		var item := PortInteractable.new()
		item.item_id = quest["item"]
		item.kind = "quest_object"
		item.figure = id
		item.label = "Recolher · " + quest["target"]
		item.position = PortLayout.iso(_clear_tile(game, quest["tile"]))
		game.actors.add_child(item)
	refresh(game)

static func _clear_tile(game, preferred: Vector2) -> Vector2:
	var catalog := PortLayout.tile_catalog()
	for radius in range(4):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var tile := preferred + Vector2(x, y)
				if not catalog.has(Vector2i(tile)): continue
				var point := PortLayout.iso(tile)
				var clear := true
				for node in game.actors.get_children():
					if node is PortProp and node.solid and node.blocks_ground_point(point, 10): clear = false
					if node is PortInteractable and node.position.distance_to(point) < 44: clear = false
				if clear: return tile
	return preferred

static func ready(data: Dictionary, id: String) -> bool:
	if not QUESTS.has(id): return false
	var quest: Dictionary = QUESTS[id]
	if quest.has("item"): return quest["item"] in data["collected"]
	for room in quest.get("rooms", []):
		if room not in data["visited"]: return false
	return true

static func talk(game, id: String) -> bool:
	if not QUESTS.has(id): return false
	var quest: Dictionary = QUESTS[id]
	var steps: Array = game.store.data["collected"]
	var text: String
	if "quest_done_" + id in steps:
		text = str(quest["giver"]) + " — O que você trouxe continua aqui. Algumas lembranças precisam de cuidado, não de pressa."
	elif "quest_started_" + id not in steps:
		game.store.collect("quest_started_" + id, 0)
		text = quest["intro"] + "\n\n◆ " + quest["hint"] + "\n[N] Consulte o Caderno de Missões."
	elif ready(game.store.data, id):
		game.store.collect("quest_done_" + id, 0)
		game.collect_loot("coin", int(quest["reward"]))
		game.player._fx.memory_restored(game.player.global_position)
		text = quest["ending"] + "\n\nMissão concluída · +%d óbolos." % quest["reward"]
	else:
		text = str(quest["giver"]) + " — " + quest["hint"] + "\n\nO seu caminho pode ser consultado em [N] Missões."
	game._save()
	refresh(game)
	game.hud.show_conversation(quest["name"], text, "missao_tarek" if id == "tarek" else "loja_" + id)
	return true

static func activate(game, item: PortInteractable) -> bool:
	if not game.store.collect(item.item_id, 0): return false
	item.active = false
	game._save()
	refresh(game)
	var quest: Dictionary = QUESTS[item.figure]
	game.player._fx.memory_restored(item.global_position)
	game.hud.show_dialog(quest["target"], "Senu guarda o objeto com cuidado.\n\n◆ Leve-o a %s.\n%s\n\nMesmo que você ainda não tenha recebido o pedido, o objeto permanecerá guardado." % [quest["giver"], quest["place"]])
	return true

static func refresh(game) -> void:
	for item in game.actors.get_children():
		if not item is PortInteractable: continue
		var id := str({"loja_merit": "merit", "loja_nakht": "nakht", "loja_adiam": "adiam", "missao_tarek": "tarek"}.get(item.item_id, ""))
		if id == "": continue
		item.puzzle_value = 0 if "quest_done_" + id in game.store.data["collected"] else (2 if ready(game.store.data, id) else (3 if "quest_started_" + id in game.store.data["collected"] else 1))
		item.queue_redraw()

static func entries(data: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var steps: Array = data["collected"]
	if "fisher_met" in steps or "fisher_brother_found" in steps:
		result.append({"name": "O nome que a maré guardou", "giver": "Hori e Sabu", "done": "fisher_done" in steps, "objective": Story.fisher_objective(data), "reward": "2 Fragmentos de Nous"})
	for id in QUESTS:
		if "quest_started_" + id not in steps and QUESTS[id].get("item", "") not in steps: continue
		var quest: Dictionary = QUESTS[id]
		var done: bool = "quest_done_" + id in steps
		var objective: String = "Concluída. " + quest["giver"] + " recebeu sua ajuda." if done else ("Volte a " + quest["giver"] + ". " + quest["place"] if ready(data, id) else quest["hint"])
		if not done and "quest_started_" + id not in steps: objective = "Você encontrou um objeto de " + quest["giver"] + ". " + quest["place"]
		result.append({"name": quest["name"], "giver": quest["giver"], "done": done, "objective": objective, "reward": "%d óbolos" % quest["reward"]})
	return result

static func journal_text(data: Dictionary) -> String:
	var list := entries(data)
	if list.is_empty(): return "Converse com Hori no Cais dos Esquecidos, com os lojistas nas casas do Porto ou com Tarek na Casa da Guarda.\n\nCada pedido ficará registrado aqui com seu próximo objetivo. Os objetos encontrados antes de receber um pedido também ficam guardados."
	var lines: Array[String] = []
	for entry in list:
		lines.append(("✓ " if entry["done"] else "◆ ") + entry["name"] + " — " + entry["giver"] + "\n" + entry["objective"] + "\nRecompensa: " + entry["reward"])
	return "\n\n".join(lines)
