extends RefCounted

## Missões da Ilha do Bennu (docs/MUNDO_BARCO_ILHA.md). Como port_story.gd, o
## progresso fica na lista "collected" do save, e jornadas antigas carregam sem
## migração. `game` é a cena do porto (port_demo.gd).

const Shop = preload("res://scripts/economy/shop_catalog.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const FOES := ["esquecido_ilha_01", "esquecido_ilha_02", "esquecido_ilha_03"]
## A ordem do voo do Bennu: desperta onde o sol nasce, abre as asas ao norte,
## repousa no poente.
const FLAME_ORDER := ["brazier_east", "brazier_north", "brazier_west"]
const FOES_COINS := 50
const FOES_XP := 40
const ALTAR_COINS := 60
const NET_COINS := 40
const NET_XP := 30
const NOTE := Color("e2c693")


static func on_landed(game) -> void:
	if _has(game, "isle_landed"):
		return
	game.store.data["flags"]["sea_route"] = true
	_advance(game, "isle_landed")
	_say(game, "Ilha do Bennu", "O píer range sob os pés de Senu. A ilha cheira a sal e a tâmaras maduras; entre as palmeiras, colunas quebradas apontam para o céu.\n\nNo alto de uma pedra, uma garça cinzenta observa Senu sem medo.", "Ilha do Bennu: a rota pela baía agora aparece no mapa.")


## Chamado a cada quadro de física: registra os Esquecidos da ilha já vencidos,
## para que a missão de Ankhet sobreviva ao renascimento dos inimigos.
static func tick(game) -> void:
	if Engine.get_physics_frames() % 20 != 0:
		return
	var changed := false
	for id in FOES:
		if id in game.store.data["defeated"] and not _has(game, "isle_foe_" + id):
			game.store.collect("isle_foe_" + id, 0)
			changed = true
	if changed:
		game._save_soon()


static func foes_cleared(game) -> int:
	var count := 0
	for id in FOES:
		count += int(_has(game, "isle_foe_" + id) or id in game.store.data["defeated"])
	return count


static func refresh(game) -> void:
	for item in game.get_tree().get_nodes_in_group("interactables"):
		if not item is PortInteractable or not str(item.kind).begins_with("isle_") or item.has_method("extra_activate"):
			continue
		match item.kind:
			"isle_npc":
				item.label = "Falar com Ankhet" if _has(game, "isle_ankhet_met") else "Falar com a guardiã das garças"
			"isle_brazier":
				if _has(game, "isle_flames"):
					item.opened = true
				item.label = "Acender o braseiro" if not item.opened else "Uma chama arde"
			"isle_altar":
				item.opened = _has(game, "isle_chest")
				item.label = "Examinar o altar do Bennu" if not _has(game, "isle_flames") else ("Abrir o altar do Bennu" if not item.opened else "O altar vazio")
			"isle_net":
				item.active = not _has(game, "isle_net")
				item.label = "Examinar a rede enroscada"
		item.queue_redraw()


static func activate(game, item: PortInteractable) -> bool:
	match item.kind:
		"isle_npc":
			return _talk_to_ankhet(game)
		"isle_brazier":
			return _light(game, item)
		"isle_altar":
			return _open_altar(game, item)
		"isle_net":
			return _take_net(game, item)
	return false


static func _talk_to_ankhet(game) -> bool:
	if not _has(game, "isle_ankhet_met"):
		_advance(game, "isle_ankhet_met")
		_say(game, "A guardiã das garças", "Uma mulher idosa, apoiada num cajado de junco, observa as aves. O xale azul está desbotado de sol.\n\nMULHER — Barco de Sabu, remo de outro. Faz tempo que ninguém atravessa a baía.\n\nSENU — Sou Senu. Procuro meu mestre, Iri.\n\nMULHER — Eu sou Ankhet. Guardo as garças desta ilha… ou guardava. Três Esquecidos vieram do porto e não deixam as aves pousar. Desde então elas não cantam. Afaste-os, e eu lhe conto o que as garças viram passar por esta água.", "Missão: afaste os três Esquecidos da Ilha do Bennu.", "isle_ankhet")
		return true
	if not _has(game, "isle_foes_done"):
		var left := FOES.size() - foes_cleared(game)
		if left > 0:
			game.hud.show_conversation("Ankhet", "ANKHET — Ainda ouço %s. Eles andam entre as palmeiras e perto das ruínas, onde as garças faziam ninho." % ("um deles" if left == 1 else "%d deles" % left), "isle_ankhet")
			return true
		_advance(game, "isle_foes_done")
		game.collect_loot("coin", FOES_COINS)
		game.collect_loot("xp", FOES_XP)
		_say(game, "As garças voltam", "ANKHET — Ouça… Estão cantando de novo.\n\nAnkhet tira da bolsa um punhado de óbolos amarrados num pano.\n\nANKHET — Os pescadores deixavam isto como oferenda. As garças não gastam dinheiro.\n\nANKHET — E sobre o seu mestre: um homem de manto escuro passou por aqui antes da última cheia. Olhou para o altar do Bennu como quem procura um nome perdido. Depois remou de volta ao porto, na direção das Catacumbas.", "Missão concluída: as garças sem voz.", "isle_ankhet")
		return true
	var lines := []
	if not _has(game, "isle_flames"):
		lines.append("ANKHET — O Bennu é a garça que renasce do fogo. No altar das ruínas, os antigos acendiam três chamas na ordem do voo dela: onde o sol nasce, ela desperta; ao norte, abre as asas; no poente, repousa.")
	elif not _has(game, "isle_chest"):
		lines.append("ANKHET — As três chamas ardem de novo. O altar das ruínas espera por você.")
	else:
		lines.append("ANKHET — Fazia uma geração que eu não via as três chamas acesas. Guarde a pena; o Bennu não dá duas.")
	if not _has(game, "isle_net"):
		lines.append("ANKHET — Na praia do sul ficou presa uma rede de pescador. Tem um nó estranho, de três voltas.")
	game.hud.show_conversation("Ankhet", "\n\n".join(lines), "isle_ankhet")
	return true


static func _braziers(game) -> Array:
	var list := []
	for item in game.get_tree().get_nodes_in_group("interactables"):
		if item is PortInteractable and item.kind == "isle_brazier":
			list.append(item)
	return list


static func _light(game, item: PortInteractable) -> bool:
	if _has(game, "isle_flames"):
		game.hud.toast("As três chamas do Bennu ardem.", NOTE, 3)
		return true
	if item.opened:
		game.hud.toast("Esta chama já arde.", NOTE, 2)
		return false
	var lit := 0
	for brazier in _braziers(game):
		lit += int(brazier.opened)
	if FLAME_ORDER[lit] != item.item_id:
		var any_lit := lit > 0
		for brazier in _braziers(game):
			brazier.opened = false
		refresh(game)
		_sound(item, "water_bubble", -6.0)
		game.hud.toast("As chamas se apagam. O Bennu não voa nessa ordem." if any_lit else "A chama não pega. Talvez não seja por aqui que o Bennu desperta.", Color("dfb5b0"), 4)
		return true
	item.opened = true
	_sound(item, "dodge", -8.0)
	if lit + 1 < FLAME_ORDER.size():
		refresh(game)
		game.hud.toast("Uma chama acende: %d de 3." % (lit + 1), NOTE, 3)
		return true
	_advance(game, "isle_flames")
	_say(game, "As três chamas do Bennu", "A última chama se ergue e as três ardem juntas. Nas ruínas, a pedra do altar range e desliza alguns dedos.", "As três chamas ardem: o altar das ruínas se abriu.")
	return true


static func _open_altar(game, item: PortInteractable) -> bool:
	if _has(game, "isle_chest"):
		game.hud.show_dialog("O altar do Bennu", "O altar está vazio. No fundo, as três chamas se refletem na pedra polida.")
		return true
	if not _has(game, "isle_flames"):
		game.hud.show_dialog("O altar do Bennu", "Uma garça de pé, com o disco do sol sobre a cabeça, está talhada na pedra. Embaixo, uma inscrição gasta:\n\n“Onde o sol nasce, o Bennu desperta. Ao norte, abre as asas. No poente, repousa. Acende o caminho do seu voo.”\n\nHá três braseiros apagados pela ilha.")
		return true
	Shop.grant(game.store.data, "pena_bennu")
	_advance(game, "isle_chest")
	item.opened = true
	game.collect_loot("coin", ALTAR_COINS)
	game.hud.queue_redraw()
	_sound(item, "chest_open", -4.0)
	_say(game, "A Pena do Bennu", "Dentro do altar, sobre um pano de linho, há uma pena dourada e uma bolsa de óbolos antigos.\n\nA pena está morna, como se o fogo ainda morasse nela.\n\n+1 carga de bálsamo (tecla R), que volta cheia nos santuários.", "Recompensa: a Pena do Bennu.")
	return true


static func _take_net(game, item: PortInteractable) -> bool:
	if _has(game, "isle_net"):
		return false
	_advance(game, "isle_net")
	item.active = false
	var knows_hori := _has(game, "fisher_met")
	_say(game, "A rede enroscada", "Uma rede de pesca presa entre as pedras da praia, com bóias de cortiça e algas secas. Num canto, alguém deu um nó de três voltas.\n\n" + ("É o mesmo nó do cordão de Hori." if knows_hori else "Um nó assim tem dono. Alguém no cais deve reconhecê-lo."), "Missão: leve a rede a Hori, no Cais dos Esquecidos." if knows_hori else "Missão: descubra no cais de quem é este nó.")
	return true


## Gancho em port_story.gd: com a rede na mão, Hori fala dela primeiro.
static func return_net(game) -> bool:
	if not _has(game, "isle_net") or _has(game, "isle_net_done"):
		return false
	_advance(game, "isle_net_done")
	game.collect_loot("coin", NET_COINS)
	game.collect_loot("xp", NET_XP)
	_say(game, "A rede de Hori", "Hori pega a rede e procura o nó com os dedos antes de olhar para Senu.\n\nHORI — É a minha. A tempestade a levou no ano em que Sabu se perdeu… Achei que o mar tinha ficado com ela, como ficou com tantas coisas.\n\nHORI — Leve isto. É pouco, mas hoje o mar me devolveu mais do que eu esperava.", "Missão concluída: a rede de Hori.", "npc_fisher")
	return true


static func _advance(game, step: String) -> void:
	game.store.collect(step, 0)
	game._save()
	refresh(game)


## Como em port_story.gd: o aviso de progresso também fecha o diálogo.
static func _say(game, title: String, text: String, note: String = "", npc_id: String = "") -> void:
	if npc_id.is_empty():
		game.hud.show_dialog(title, text + ("\n\n◆ " + note if note != "" else ""))
	else:
		game.hud.show_conversation(title, text + ("\n\n◆ " + note if note != "" else ""), npc_id)
	if note != "":
		game.hud.toast(note, NOTE, 5)


static func _sound(at: Node2D, bank: String, volume: float) -> void:
	if Sfx.has_bank(bank):
		Sfx.play(at, bank, at.global_position, volume)


static func _has(game, id: String) -> bool:
	return id in game.store.data["collected"]
