extends RefCounted

## O que fazer nas ilhas além da baía (docs/MUNDO_PROPOSTA_2026-10-30.md):
## - Ilha do Íbis Afogado: a inscrição do templo dá a ordem das três estelas (olho,
##   pena, junco); acesas na ordem, abrem o nicho do Copista. Uma tabuleta enterrada
##   na ponta sul é o segredo da ilha.
## - Recife do Navio Esquecido: quatro caixas lacradas na areia (coleta), o diário de
##   bordo do capitão e, depois dele, a arca escondida junto à palmeira torta.
## O progresso fica em "collected" (sem migração de save) e as recompensas são
## óbolos e experiência: nenhum Nous, o orçamento da árvore é do Kauã.
## Chamado por isle.gd (`build`), sea.gd (`on_landed`) e extra_fixture.gd (`activate`).

const Fixture = preload("res://scripts/world/extra_fixture.gd")
const FarLayout = preload("res://scripts/world/far_isles_layout.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const SCRIPT_PATH := "res://scripts/world/far_isles.gd"
## A ordem gravada no templo: “Antes de escrever, pesa. Antes de pesar, olha.”
const STELE_ORDER := ["ibis_eye", "ibis_feather", "ibis_reed"]
const STELE_NAMES := {"ibis_eye": "do Olho", "ibis_feather": "da Pena", "ibis_reed": "do Junco"}
const CRATES := ["wreck_crate_1", "wreck_crate_2", "wreck_crate_3", "wreck_crate_4"]
const NICHE_COINS := 70
const NICHE_XP := 50
const TABLET_COINS := 25
const CRATE_COINS := 15
const CHEST_COINS := 60
const CHEST_XP := 40
const NOTE := Color("e2c693")


static func build(game) -> void:
	var handler: Script = load(SCRIPT_PATH)
	_fixture(game, handler, "ibis_clue", "lesson")
	for id in STELE_ORDER:
		var stele := _fixture(game, handler, id, "stele")
		stele.symbol = id.trim_prefix("ibis_")
	_fixture(game, handler, "ibis_niche", "niche")
	if not _has(game, "ibis_tablet"):
		_fixture(game, handler, "ibis_tablet", "tablet")
	_fixture(game, handler, "wreck_log", "log")
	for id in CRATES:
		_fixture(game, handler, id, "crate")
	if _has(game, "wreck_log"):
		_fixture(game, handler, "wreck_chest", "chest")
	refresh(game)


static func _fixture(game, handler: Script, id: String, piece: String) -> Node2D:
	var item := Fixture.new()
	item.item_id = id
	item.piece = piece
	item.handler = handler
	item.position = Layout.iso(FarLayout.MARKERS[id])
	game.actors.add_child(item)
	return item


## Primeira chegada a cada ilha: a rota pela baía passa a aparecer no mapa.
static func on_landed(game, dock: String) -> void:
	game.store.data["flags"]["sea_route"] = true
	var id := dock + "_landed"
	if _has(game, id):
		return
	_advance(game, id)
	if dock == "ibis":
		_say(game, "Ilha do Íbis Afogado", "O píer termina numa praia de pedras lisas. Mais adiante, um templo pequeno afunda devagar na areia, e estelas inclinadas saem do chão como dentes.\n\nNa fachada, um íbis de bico longo segura um cálamo: o pássaro que escreve. Era aqui que a ordem ensinava os escribas a copiar nomes.", "Ilha do Íbis Afogado: a rota aparece no mapa.")
	else:
		_say(game, "Recife do Navio Esquecido", "O casco de um navio mercante descansa sobre o recife, com a vela ainda içada. Ninguém a bordo.\n\nCaixas lacradas se espalham pela areia, como se a maré tivesse esvaziado o porão sem pressa.", "Recife do Navio Esquecido: a rota aparece no mapa.")


static func refresh(game) -> void:
	var lit := _has(game, "ibis_steles")
	for item in game.get_tree().get_nodes_in_group("interactables"):
		if not item.has_method("extra_activate"):
			continue
		var id: String = item.item_id
		match id:
			"ibis_clue":
				item.label = "Ler a inscrição do íbis"
			"ibis_eye", "ibis_feather", "ibis_reed":
				if lit:
					item.opened = true
				item.label = ("A estela %s brilha" if item.opened else "Tocar a estela %s") % STELE_NAMES[id]
			"ibis_niche":
				item.opened = _has(game, "ibis_niche")
				item.active = not item.opened
				item.label = "Abrir o nicho do Copista" if lit else "Examinar o nicho do íbis"
			"ibis_tablet":
				item.active = not _has(game, "ibis_tablet")
				item.label = "Desenterrar a tabuleta"
			"wreck_log":
				item.label = "Ler o diário de bordo"
			"wreck_chest":
				item.opened = _has(game, "wreck_chest")
				item.active = not item.opened
				item.label = "Abrir a arca do capitão"
			_:
				if id in CRATES:
					item.opened = _has(game, id)
					item.active = not item.opened
					item.label = "Abrir a caixa lacrada · %d/%d" % [crates_found(game), CRATES.size()]
		item.queue_redraw()


static func crates_found(game) -> int:
	var count := 0
	for id in CRATES:
		count += int(_has(game, id))
	return count


static func activate(game, item) -> bool:
	var id: String = item.item_id
	if id in STELE_ORDER:
		return _touch_stele(game, item)
	if id in CRATES:
		return _open_crate(game, item)
	match id:
		"ibis_clue":
			game.hud.show_dialog("A ordem do íbis", "Sob o íbis da fachada, uma inscrição gasta:\n\n“Antes de escrever, pesa. Antes de pesar, olha.”\n\nTrês estelas cercam o lago sagrado: a do Olho, a da Pena e a do Junco.")
			return true
		"ibis_niche":
			return _open_niche(game, item)
		"ibis_tablet":
			if _has(game, "ibis_tablet"):
				return false
			_advance(game, "ibis_tablet")
			item.active = false
			item.opened = true
			game.collect_loot("coin", TABLET_COINS)
			_sound(item, "pickup_coin", -6.0)
			_say(game, "A tabuleta enterrada", "Sob a areia da ponta sul, uma tabuleta de argila com a lista dos noviços de um ano antigo. Os nomes foram riscados um por um, com o mesmo traço firme.\n\nO último ainda se lê pela metade: “Se…”. Ao lado da tabuleta, alguém enterrou também uma bolsa de óbolos, como quem paga uma dívida.", "Segredo da ilha: +%d óbolos." % TABLET_COINS)
			return true
		"wreck_log":
			var first := not _has(game, "wreck_log")
			if first:
				_advance(game, "wreck_log")
				_fixture(game, load(SCRIPT_PATH), "wreck_chest", "chest")
				refresh(game)
			_say(game, "O diário de bordo", "A letra começa firme e termina tremida.\n\n“Dia 1 — Saímos de Axum com cobre e incenso. Doze homens.”\n“Dia 4 — Onze homens. Ninguém lembra do décimo segundo, mas a rede dele continua no convés.”\n“Dia 9 — O timoneiro perguntou o meu nome. Eu disse. Ele perguntou de novo.”\n“Último dia — Enterrei a arca junto à palmeira torta, antes que eu esqueça que ela é minha.”", "Missão: encontre a arca do capitão junto à palmeira torta." if first else "")
			return true
		"wreck_chest":
			if _has(game, "wreck_chest"):
				return false
			_advance(game, "wreck_chest")
			item.opened = true
			item.active = false
			game.collect_loot("coin", CHEST_COINS)
			game.collect_loot("xp", CHEST_XP)
			_sound(item, "chest_open", -4.0)
			_say(game, "A arca do capitão", "Dentro, um sextante de bronze sem marcas, um punhado de óbolos de muitos portos e um retalho de vela bordado com doze nomes.\n\nSó um ainda se lê: o do capitão. Os outros onze foram desfeitos ponto por ponto.", "Arca do capitão: +%d óbolos e +%d de experiência." % [CHEST_COINS, CHEST_XP])
			return true
	return false


static func _steles(game) -> Array:
	var list := []
	for item in game.get_tree().get_nodes_in_group("interactables"):
		if item.has_method("extra_activate") and str(item.item_id) in STELE_ORDER:
			list.append(item)
	return list


static func _touch_stele(game, item) -> bool:
	if _has(game, "ibis_steles"):
		game.hud.toast("As três estelas brilham.", NOTE, 3)
		return true
	if item.opened:
		game.hud.toast("Esta estela já brilha.", NOTE, 2)
		return false
	var lit := 0
	for stele in _steles(game):
		lit += int(stele.opened)
	if STELE_ORDER[lit] != item.item_id:
		for stele in _steles(game):
			stele.opened = false
		refresh(game)
		_sound(item, "water_bubble", -6.0)
		game.hud.toast("As marcas se apagam. O íbis não escreve nessa ordem." if lit > 0 else "A estela continua apagada. Talvez não seja por ela que o íbis começa.", Color("dfb5b0"), 4)
		return true
	item.opened = true
	_sound(item, "dodge", -8.0)
	if lit + 1 < STELE_ORDER.size():
		refresh(game)
		game.hud.toast("A estela %s se acende: %d de 3." % [STELE_NAMES[item.item_id], lit + 1], NOTE, 3)
		return true
	_advance(game, "ibis_steles")
	_say(game, "As três estelas", "Olho, pena e junco brilham juntos. No templo, a tampa do nicho do íbis range e se solta.", "As três estelas brilham: o nicho do Copista se abriu.")
	return true


static func _open_niche(game, item) -> bool:
	if _has(game, "ibis_niche"):
		return false
	if not _has(game, "ibis_steles"):
		game.hud.show_dialog("O nicho do íbis", "Uma tampa de pedra com um íbis gravado, presa por três encaixes vazios. Cada encaixe tem o desenho de uma das estelas do lago.\n\nA inscrição na fachada do templo diz em que ordem o íbis trabalha.")
		return false
	_advance(game, "ibis_niche")
	item.opened = true
	item.active = false
	game.collect_loot("coin", NICHE_COINS)
	game.collect_loot("xp", NICHE_XP)
	_sound(item, "chest_open", -4.0)
	_say(game, "O nicho do Copista", "Dentro do nicho, uma paleta de escriba com dois godês secos, um de tinta preta e outro vermelho, e uma bolsa de óbolos antigos.\n\nNa madeira da paleta, alguém gravou: “Aqui aprendi a corrigir nomes. Depois aprendi a trocá-los.” Não há assinatura; só um íbis desenhado ao contrário.", "Nicho do Copista: +%d óbolos e +%d de experiência." % [NICHE_COINS, NICHE_XP])
	return true


static func _open_crate(game, item) -> bool:
	var id: String = item.item_id
	if _has(game, id):
		return false
	_advance(game, id)
	item.opened = true
	item.active = false
	game.collect_loot("coin", CRATE_COINS)
	_sound(item, "chest_open", -8.0)
	var found := crates_found(game)
	game.hud.toast("Caixa lacrada: cobre e incenso de Axum · %d de %d" % [found, CRATES.size()], NOTE, 3)
	refresh(game)
	return true


static func _advance(game, step: String) -> void:
	game.store.collect(step, 0)
	game._save()


## Como em port_story.gd: o aviso de progresso também fecha o diálogo.
static func _say(game, title: String, text: String, note: String = "") -> void:
	game.hud.show_dialog(title, text + ("\n\n◆ " + note if note != "" else ""))
	if note != "":
		game.hud.toast(note, NOTE, 5)


static func _sound(at: Node2D, bank: String, volume: float) -> void:
	if Sfx.has_bank(bank):
		Sfx.play(at, bank, at.global_position, volume)


static func _has(game, id: String) -> bool:
	return id in game.store.data["collected"]
