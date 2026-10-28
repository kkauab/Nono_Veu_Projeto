extends RefCounted
## Side stories of the Port: Iri's trail and the fisherman's brother.
## Their progress lives in the save's "collected" list, so older journeys load
## without a migration. `game` is the port scene (port_demo.gd).

const MARKS := {
	"iri_mark_archive": {
		"tile": Vector2(10, -31),
		"title": "Marca de Iri · Arquivo",
		"text": "Um sinal de Hermes riscado às pressas na pedra: o círculo, o bastão e as duas asas. Só os discípulos da ordem o reconhecem.\n\n“Os nomes deste arquivo foram reescritos pela mesma mão. A tinta é nova, mas as letras imitam as antigas. Senu, se chegaste até aqui, não confies no que está escrito. Confia no que é lembrado.”",
	},
	"iri_mark_oracle": {
		"tile": Vector2(85, 30.5),
		"title": "Marca de Iri · Observatório",
		"text": "“O céu é o único registro que ninguém consegue copiar. Quando eras menino, contavas as estrelas para não dormir na vigília. Conta outra vez: elas ainda estão no lugar.”\n\nAo lado do sinal, uma seta gravada aponta para o oeste, na direção do santuário.",
	},
	"iri_mark_buried": {
		"tile": Vector2(-4, 35.5),
		"title": "Marca de Iri · Santuário Soterrado",
		"text": "A marca está meio coberta de lodo, mas o traço ainda brilha.\n\n“A água guarda o que as pessoas esquecem. Lembra-te da primeira lição: um nome não é o que te chamam, é aquilo a que respondes. Enquanto responderes ao teu, ninguém o escreve por cima.”",
	},
	"iri_mark_guard": {
		"tile": Vector2(5, 27.5),
		"title": "Marca de Iri · Guarita",
		"text": "“Preparei o caminho de volta, como fazíamos nas viagens: sempre uma porta atrás de nós. Deixei algo para ti onde tudo começa, na Primeira Palavra. Só se abre para quem seguiu as quatro marcas.”",
	},
}
const RELIC_TILE := Vector2(1, -3.5)
const RELIC_REWARD := 3
const FISHER_TILE := Vector2(12.6, 1.6)
## Sabu works the ropes at the old pier until he remembers; then he waits by his brother.
const BROTHER_DOCK_TILE := Vector2(27, 32.5)
const BROTHER_HOME_TILE := Vector2(13.6, 1.2)
const FISHER_REWARD := 2
const IsleStory = preload("res://scripts/world/isle_story.gd")

static func build(game) -> void:
	for id in MARKS:
		_add(game, id, "iri_mark", MARKS[id]["tile"])
	_add(game, "iri_relic", "iri_relic", RELIC_TILE)
	_add(game, "npc_fisher", "npc", FISHER_TILE).figure = "fisher"
	_add(game, "npc_brother", "npc", BROTHER_HOME_TILE if _has(game, "fisher_done") else BROTHER_DOCK_TILE).figure = "brother"
	refresh(game)

static func marks_read(game) -> int:
	var count := 0
	for id in MARKS:
		count += int(_has(game, id))
	return count

static func refresh(game) -> void:
	for item in game.actors.get_children():
		if not item is PortInteractable:
			continue
		match item.item_id:
			"iri_relic":
				item.puzzle_value = marks_read(game)
				item.opened = _has(game, "iri_relic")
				item.active = not item.opened
				item.label = "Relicário de Iri · %d/4 marcas" % item.puzzle_value
			"npc_fisher":
				item.label = "Falar com Hori" if _has(game, "fisher_met") else "Falar com o pescador"
			"npc_brother":
				# Until Sabu remembers, Kauã's fisherman sheet is drawn in faded colors.
				item.opened = _has(game, "fisher_named")
				item.label = "Falar com Sabu" if _has(game, "fisher_brother_found") else "Falar com o homem das cordas"
			_:
				if MARKS.has(item.item_id):
					item.opened = _has(game, item.item_id)
					item.label = ("Reler" if item.opened else "Examinar") + " a marca de Iri"
		item.queue_redraw()

static func activate(game, item: PortInteractable) -> bool:
	match item.kind:
		"iri_mark":
			return _read_mark(game, item.item_id)
		"iri_relic":
			return _open_relic(game)
		"npc":
			# Other people of the port (shopkeepers, for instance) answer elsewhere.
			match item.item_id:
				"npc_fisher":
					return _talk_to_fisher(game)
				"npc_brother":
					return _talk_to_brother(game)
	return false

static func _read_mark(game, id: String) -> bool:
	var note := ""
	if not _has(game, id):
		_advance(game, id)
		var count := marks_read(game)
		note = "As quatro marcas de Iri apontam para o Santuário da Primeira Palavra." if count == 4 else "Marcas de Iri: %d de 4." % count
	_say(game, MARKS[id]["title"], MARKS[id]["text"], note)
	return true

static func _open_relic(game) -> bool:
	if _has(game, "iri_relic"):
		return false
	var count := marks_read(game)
	if count < 4:
		game.hud.show_dialog("O relicário de Iri", "Uma caixa de cedro presa ao altar, com o sinal de Hermes na tampa. Quatro sulcos rodeiam o sinal; %d deles brilham.\n\nIri deixou marcas pelo porto. Procure-as no Arquivo, no Observatório, no Santuário Soterrado e na Guarita." % count)
		return false
	game.store.collect("iri_relic", RELIC_REWARD)
	game._save()
	refresh(game)
	game.hud.show_dialog("O que Iri deixou", "Dentro, embrulhado no mesmo pano escuro dos livros, está o cordão de contas que Iri usava para contar as respirações nas lições.\n\nNo pano, um último recado: “Desci às Catacumbas atrás de quem reescreve os nomes. Não me sigas antes de estares pronto. Se me seguires, leva isto.”\n\n+%d Fragmentos de Nous." % RELIC_REWARD)
	return true

static func _talk_to_fisher(game) -> bool:
	# Com a rede achada na Ilha do Bennu, Hori fala dela primeiro.
	if IsleStory.return_net(game):
		return true
	if not _has(game, "fisher_met"):
		_advance(game, "fisher_met")
		_say(game, "O pescador do cais", "PESCADOR — Você voltou. Achou seu mestre?\n\nSENU — Ainda não. Mas sigo o rastro dele.\n\nPESCADOR — Eu sou Hori. Não disse meu nome naquela manhã… hoje parece importante dizer. Meu irmão, Sabu, não voltou ao cais. Um carregador viu um homem enrolando cordas sozinho no Embarcadouro Velho, ao sul do Pátio das Memórias. Se for ele…\n\nSENU — Vou procurá-lo.", "Missão: procure Sabu, o irmão de Hori, no Embarcadouro Velho.")
	elif not _has(game, "fisher_brother_found"):
		game.hud.show_dialog("Hori", "HORI — O Embarcadouro Velho fica ao sul do Pátio das Memórias. Sabu sempre gostou daquele píer; dizia que lá a água era mais calma.")
	elif not _has(game, "fisher_knot"):
		_advance(game, "fisher_knot")
		_say(game, "Hori", "HORI — Ele está vivo… e ainda faz os nós.\n\nHori tira do bolso um cordão com um nó de três voltas.\n\nHORI — Foi o primeiro nó que ele me ensinou, quando éramos meninos. Leve. Se alguma coisa ainda lembra dentro dele, vai lembrar disso.", "Missão: leve o nó de Hori a Sabu, no Embarcadouro Velho.")
	elif not _has(game, "fisher_named"):
		game.hud.show_dialog("Hori", "HORI — Ele reconheceu o nó, mas não o meu nome? Então ainda há caminho.\n\nDizem que os nomes de quem esquece ficam presos além do Porteiro, perto das Catacumbas.")
	elif not _has(game, "fisher_done"):
		game.store.collect("fisher_done", FISHER_REWARD)
		game._save()
		_move_brother_home(game)
		refresh(game)
		_say(game, "O nome de Hori", "Antes que Senu termine de contar, Hori já está olhando para o fim do cais.\n\nHORI — Ele disse meu nome? … Então eu espero. Esperar eu sei.\n\nHori põe na mão de Senu dois fragmentos que guardava na rede.\n\nHORI — Vieram no fundo da rede, dias atrás. Brilham como as coisas da sua ordem. São seus.\n\n+%d Fragmentos de Nous." % FISHER_REWARD, "Missão concluída: o nome de Hori voltou.")
	else:
		game.hud.show_dialog("Hori", "HORI — Sabu chegou ao entardecer. Ainda confunde as coisas de ontem, mas sabe meu nome. Se encontrar seu mestre, Senu, traga-o aqui. Temos água para os dois.")
	return true

static func _talk_to_brother(game) -> bool:
	if _has(game, "fisher_done"):
		game.hud.show_dialog("Sabu", "SABU — Hori diz que fui eu que ensinei esse nó. Eu digo que foi ele. Vamos discutir isso pelo resto da vida." + ("\n\nSABU — Vi o meu barco atravessar a baía. Rema melhor do que eu remava. Cuide dele." if _has(game, "boat_sailed") else ""))
	elif _has(game, "fisher_named"):
		game.hud.show_dialog("Sabu", "SABU — Vá na frente e diga a ele. Eu conheço o caminho até o cais. Sempre conheci.")
	elif _has(game, "fisher_knot"):
		if not game.store.data["flags"]["boss"]:
			game.hud.show_dialog("Sabu", "Sabu segura o cordão de Hori e passa os dedos pelas três voltas.\n\nSABU — Este nó é meu. Eu sei que é meu. Mas o nome que vem com ele… está atrás de uma porta. Ouço alguém chamando do outro lado do limiar.\n\nTalvez quem guarda o limiar guarde também os nomes.")
		else:
			_advance(game, "fisher_named")
			_say(game, "Sabu", "Sabu aperta o cordão. Os olhos dele param de procurar.\n\nSABU — Hori. O nome dele é Hori. Ele me esperava no cais… todos os dias, não é?\n\nSENU — Todos os dias.\n\nSABU — Então eu também tenho um caminho até lá.", "Missão: volte ao cais e conte a Hori.")
	elif _has(game, "fisher_brother_found"):
		game.hud.show_dialog("Sabu", "O homem continua a desfazer e refazer o mesmo nó.\n\nSABU — Irmão… Você disse que eu tenho um irmão. A palavra é boa, mas não traz rosto nenhum.")
	elif _has(game, "fisher_met"):
		_advance(game, "fisher_brother_found")
		_say(game, "O homem das cordas", "O homem enrola a mesma corda, desfaz o nó e começa de novo.\n\nSENU — Você é Sabu? Seu irmão, Hori, espera você no cais.\n\nHOMEM — Irmão? Eu… conheço este nó. Alguém me ensinou. Não, fui eu que ensinei. Mas a quem?\n\nEle não reconhece o nome. Talvez Hori saiba como alcançá-lo.", "Missão: conte a Hori o que viu no Embarcadouro.")
	else:
		game.hud.show_dialog("O homem das cordas", "O homem enrola e desenrola a mesma corda, sem pressa.\n\nHOMEM — Quanto você quer pela rede? Eu pago bem. Ou… eu já paguei?\n\n%s" % _brother_echo(game.seals_found()))
	return true

## While no one asked for him, Sabu's lines drift as the seals return.
static func _brother_echo(seals: int) -> String:
	return [
		"Ele não parece ver Senu.",
		"HOMEM — Eu tinha um barco. Ou era de alguém?",
		"HOMEM — Alguém me esperava num cais. Todos os dias, eu acho.",
		"HOMEM — Há uma porta que guarda os nomes. Às vezes ouço o meu do outro lado.",
	][clampi(seals, 0, 3)]

static func _advance(game, step: String) -> void:
	game.store.collect(step, 0)
	game._save()
	refresh(game)

## The HUD toast keeps counting while a dialog pauses the game, so the progress
## line also closes the dialog itself.
static func _say(game, title: String, text: String, note: String = "") -> void:
	game.hud.show_dialog(title, text + ("\n\n◆ " + note if note != "" else ""))
	if note != "":
		game.hud.toast(note, Color("e2c693"), 5)

static func _move_brother_home(game) -> void:
	for item in game.actors.get_children():
		if item is PortInteractable and item.item_id == "npc_brother":
			item.position = PortLayout.iso(BROTHER_HOME_TILE)

static func _has(game, id: String) -> bool:
	return id in game.store.data["collected"]

static func _add(game, id: String, kind: String, tile: Vector2) -> PortInteractable:
	var item := PortInteractable.new()
	item.item_id = id
	item.kind = kind
	item.position = PortLayout.iso(tile)
	game.actors.add_child(item)
	return item
