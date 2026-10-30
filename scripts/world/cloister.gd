extends RefCounted

## Claustro dos Iniciados (docs/MUNDO_PROPOSTA_2026-10-30.md): a ampliação do
## santuário onde Senu desperta. Três estelas guardam as lições que Iri dava aos
## noviços; lidas as três, em qualquer ordem, abre-se a Arca do Noviço. No
## santuário, o marco dos caminhos aponta as saídas para o resto do porto.
## Como em port_story.gd, o progresso fica em "collected" e saves antigos abrem
## sem migração. Nenhum Nous: o orçamento da árvore é do Kauã.
## Chamado por isle.gd: `build` ao montar o mundo; as peças chegam a `activate`
## pelo `extra_activate` de extra_fixture.gd.

const Fixture = preload("res://scripts/world/extra_fixture.gd")
const CloisterLayout = preload("res://scripts/world/cloister_layout.gd")
const Layout = preload("res://scripts/world/port_layout.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
const SCRIPT_PATH := "res://scripts/world/cloister.gd"
const LESSONS := ["lesson_name", "lesson_copy", "lesson_return"]
const CHEST_COINS := 30
const CHEST_XP := 25
const NOTE := Color("e2c693")

const TEXTS := {
	"lesson_name": ["A primeira lição", "Gravado com a letra miúda dos noviços:\n\n“O nome não é a pessoa. Mas quem perde o nome perde o caminho de volta para si.”\n\nSenu lembra de copiar esta frase até o fim da primeira noite no santuário. Iri corrigia cada traço torto sem dizer nada."],
	"lesson_copy": ["A segunda lição", "“Quem copia sem entender multiplica o erro. Lê primeiro; escreve depois.”\n\nAlguém riscou a palavra “depois” e escreveu por cima, com outra tinta, mais escura: “sempre”."],
	"lesson_return": ["A terceira lição", "“Volta sempre pelo caminho que conheces. É assim que se descobre o que mudou.”\n\nIri dizia isso ao fim de cada viagem. Desta vez, foi ele quem não voltou."],
}


static func build(game) -> void:
	var handler: Script = load(SCRIPT_PATH)
	for id in LESSONS:
		_fixture(game, handler, "cloister_" + id, "lesson", id)
	_fixture(game, handler, "cloister_chest", "chest", "novice_chest")
	_fixture(game, handler, "cloister_sign", "sign", "crossroads")
	refresh(game)


static func _fixture(game, handler: Script, id: String, piece: String, marker: String) -> void:
	var item := Fixture.new()
	item.item_id = id
	item.piece = piece
	item.handler = handler
	item.position = Layout.iso(CloisterLayout.MARKERS[marker])
	game.actors.add_child(item)


static func lessons_read(game) -> int:
	var count := 0
	for id in LESSONS:
		count += int(_has(game, "cloister_" + id))
	return count


static func refresh(game) -> void:
	for item in game.get_tree().get_nodes_in_group("interactables"):
		if not item.has_method("extra_activate") or not str(item.item_id).begins_with("cloister_"):
			continue
		match item.piece:
			"lesson":
				item.opened = _has(game, item.item_id)
				item.label = "Reler a lição de Iri" if item.opened else "Ler a lição gravada"
			"chest":
				item.opened = _has(game, "cloister_chest")
				item.active = not item.opened
				item.label = "Abrir a Arca do Noviço · %d/3 lições" % lessons_read(game)
			"sign":
				item.label = "Ler o marco dos caminhos"
		item.queue_redraw()


static func activate(game, item) -> bool:
	match item.piece:
		"lesson":
			var lesson: String = str(item.item_id).trim_prefix("cloister_")
			var first := not _has(game, item.item_id)
			if first:
				game.store.collect(item.item_id, 0)
				game._save()
			var count := lessons_read(game)
			var note := ""
			if first:
				note = "Lições de Iri: %d de 3." % count + (" A Arca do Noviço, diante da Casa das Primeiras Palavras, pode ser aberta." if count == 3 else "")
			_say(game, TEXTS[lesson][0], TEXTS[lesson][1], note)
			refresh(game)
			return true
		"chest":
			if _has(game, "cloister_chest"):
				return false
			var count := lessons_read(game)
			if count < LESSONS.size():
				game.hud.show_dialog("A Arca do Noviço", "Uma arca de cedro com o selo da ordem. Cada noviço deixava aqui o que trouxe de casa e só levava de volta depois de aprender as três primeiras lições.\n\nAs lições ficam gravadas nas estelas do claustro. Lições lembradas: %d de 3." % count)
				return false
			game.store.collect("cloister_chest", 0)
			game._save()
			item.opened = true
			item.active = false
			game.collect_loot("coin", CHEST_COINS)
			game.collect_loot("xp", CHEST_XP)
			_sound(item, "chest_open", -4.0)
			_say(game, "A Arca do Noviço", "Dentro, embrulhado em linho, está o primeiro cálamo de Senu, roído na ponta, e a bolsa de óbolos que todo noviço recebia para a viagem de volta.\n\nNo fundo da arca, com a letra de Iri: “Para quando precisares voltar.”", "Arca do Noviço: +%d óbolos e +%d de experiência." % [CHEST_COINS, CHEST_XP])
			refresh(game)
			return true
		"sign":
			game.hud.show_dialog("O marco dos caminhos", "LESTE — o Cais dos Esquecidos e o caminho dos armazéns, por onde o pescador viu Iri passar.\n\nNORTE — o Pátio dos Escribas e, além dele, o Arquivo dos Nomes Velados.\n\nSUDOESTE — o Claustro dos Iniciados, onde os noviços aprendiam as primeiras lições.")
			return true
	return false


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
