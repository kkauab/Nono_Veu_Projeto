extends RefCounted

## Quem vive no Porto (docs/MUNDO_VIDA.md). Os moradores perderam o nome como
## todos aqui: repetem a rotina sem lembrar por quê. Posições em tiles.
##
## Paradas de uma rotina: [tile, ação, segundos, extra]. Ações:
## - "go": só passa;
## - "idle": fica parado; "chat": conversa; "pray": reza curvado;
## - "fish": pesca com linha na água, de frente para `extra` (1 direita, -1 esquerda);
## - "buy": compra na bancada `extra` e sai levando a carga da aparência;
## - "pick": abaixa e pega a carga; "drop": abaixa e larga;
## - "ship": espera o navio `extra` atracar e pega a carga dele.

## Mesma ordem das linhas de assets/world/townsfolk_v1.png.
const LOOKS := ["estivador", "carregador", "peixeira", "mercador", "marinheiro", "remador", "escriba", "peregrina", "velho", "aguadeira", "padeira", "caravaneiro"]

## Bancadas: quem vende atrás de cada barraca do cenário (`stall` é o tile dela),
## o quê, por quantos óbolos e quanto cura. Comida cura na hora.
const VENDORS := [
	{"id": "peixeira", "look": "peixeira", "stall": Vector2(18, -1), "title": "Peixeira sem nome", "goods": "peixe seco", "price": 8, "heal": 25,
		"lines": ["Peixe do mar que ninguém lembra de ter pescado. Ainda assim, alimenta.", "Seco ao sol do cais. O sol, pelo menos, não esquece de nascer."]},
	{"id": "tamareiro", "look": "mercador", "stall": Vector2(24, 3.5), "title": "Vendedor de tâmaras", "goods": "tâmaras do Faium", "price": 5, "heal": 15,
		"lines": ["Tâmaras do Faium. Dizem que lá as pessoas viram estátuas. As tâmaras, não.", "Doces como uma lembrança boa. Leva duas."]},
	{"id": "padeira", "look": "padeira", "stall": Vector2(43, 1), "title": "Padeira das caravanas", "goods": "pão de cevada", "price": 6, "heal": 20,
		"lines": ["Pão de cevada com cominho. Para a estrada e para lembrar que ainda se tem fome.", "Asso antes do sol. Ninguém lembra de ter pedido, mas ninguém deixa de comer."]},
	{"id": "cervejeiro", "look": "caravaneiro", "stall": Vector2(53, 1), "title": "Cervejeiro do deserto", "goods": "cerveja de cevada", "price": 4, "heal": 10,
		"lines": ["Cerveja grossa, como a do Delta. Não cura a memória, mas cura a sede.", "Os camelos lembram o caminho melhor do que nós. Por isso eles vão na frente."]}
]

## Navios mercantes. Chegam de proa (`arrive`), ficam `dock` segundos atracados,
## recuam de ré pelos pontos de `astern` (o que atraca de proa no cais precisa)
## e saem de proa por `leave`. Somem no mar por `away` segundos. `phase`
## desencontra os dois navios.
const SHIPS := [
	{"id": "embarcadouro", "name": "Navio do Embarcadouro", "arrive": [Vector2(29.5, 66), Vector2(29.5, 48), Vector2(29.5, 39.6)], "astern": [Vector2(29.5, 47.5)], "leave": [Vector2(-28, 47.5)], "dock": 46.0, "away": 24.0, "phase": 0.0, "tint": "f2e8d6"},
	{"id": "cobre", "name": "Navio do Cobre", "arrive": [Vector2(86, 45.2), Vector2(47.5, 45.2)], "astern": [], "leave": [Vector2(-28, 45.2)], "dock": 52.0, "away": 30.0, "phase": 38.0, "tint": "e2d8c8"}
]

const TOWNSFOLK := [
	# Santuário da Primeira Palavra: uma peregrina reza junto ao santuário.
	{"id": "peregrina_santuario", "look": "peregrina", "title": "Peregrina", "speed": 26.0, "route": [[Vector2(-2.4, -2.2), "pray", 14.0], [Vector2(-1.6, 1.4), "idle", 5.0], [Vector2(.8, -2.6), "idle", 4.0]],
		"lines": ["Venho rezar aqui todo dia. Não sei a quem. O santuário parece saber.", "A Primeira Palavra... eu a sabia de cor. Agora só lembro que era curta."]},
	# Cais dos Esquecidos.
	{"id": "pescador_cais", "look": "remador", "title": "Pescador do cais", "speed": 28.0, "route": [[Vector2(8.6, 2.2), "fish", 22.0, -1], [Vector2(7.2, -.4), "idle", 4.0]],
		"lines": ["Os peixes mordem a isca e esquecem. Eu puxo a linha e esqueço também.", "Hori pesca mais adiante. Ele ainda lembra do irmão; eu já não lembro de ter um."]},
	{"id": "marinheiro_cais", "look": "marinheiro", "title": "Marinheiro sem navio", "speed": 34.0, "route": [[Vector2(6.4, .6), "idle", 3.0], [Vector2(14.6, .4), "chat", 5.0], [Vector2(11, -1.6), "go"]],
		"lines": ["Desembarquei hoje... ou ontem? O mar apaga os dias como apaga pegadas.", "Tinha um navio. Ou o navio me tinha. Agora tenho este cais."]},
	# Mercado das Cinzas.
	{"id": "carregador_mercado", "look": "carregador", "title": "Carregador", "speed": 32.0, "route": [[Vector2(21.2, -2.3), "pick", 1.0], [Vector2(23.6, 2.0), "drop", 1.0], [Vector2(22.8, -.6), "go"]],
		"lines": ["O saco pesa menos do que a dúvida. Do armazém à bancada, da bancada ao armazém.", "Alguém pagou por isto? Ninguém lembra. Mas o mercado precisa estar cheio."]},
	{"id": "aguadeira_mercado", "look": "aguadeira", "title": "Aguadeira", "speed": 30.0, "route": [[Vector2(18.9, .4), "buy", 4.0, "peixeira"], [Vector2(20.8, 1.6), "chat", 6.0], [Vector2(23.2, 2.6), "buy", 4.0, "tamareiro"], [Vector2(19.8, 1.6), "drop", 1.0]],
		"lines": ["Compro peixe para alguém. Para quem? A mão sabe, a cabeça não.", "A água da cisterna é fresca e não guarda lembrança. Por isso é boa."]},
	{"id": "velho_mercado", "look": "velho", "title": "Velho das cinzas", "speed": 20.0, "route": [[Vector2(20.4, .8), "idle", 8.0], [Vector2(22.6, -1.8), "chat", 6.0], [Vector2(21.4, 2.2), "idle", 5.0]],
		"lines": ["Antes havia festa neste mercado. Agora só há o barulho das caixas.", "O Porteiro guarda a saída, dizem. Guarda também o que esquecemos."]},
	# Armazém das Vozes.
	{"id": "estivador_armazem", "look": "estivador", "title": "Estivador", "speed": 34.0, "route": [[Vector2(36.4, 6.2), "pick", 1.0], [Vector2(35.6, 1.5), "drop", 1.0]],
		"lines": ["Carrego estas caixas desde antes de lembrar o meu nome. Elas nunca acabam.", "Merit vende bálsamo aqui do lado. Eu não compro: esqueço onde ponho os jarros."]},
	# Pátio das Memórias.
	{"id": "velho_patio", "look": "velho", "title": "Velho do pátio", "speed": 18.0, "route": [[Vector2(33.4, 24.4), "pray", 12.0], [Vector2(30.6, 26.4), "idle", 6.0], [Vector2(27.6, 23.6), "idle", 5.0]],
		"lines": ["Este pátio guardava as lembranças da cidade. Agora guarda só o pátio.", "Rezo diante da estátua. Ela também não lembra quem foi."]},
	# Embarcadouro Velho: estivadores do navio e um pescador no píer leste.
	{"id": "estivador_embarcadouro_1", "look": "estivador", "title": "Estivador do navio", "speed": 36.0, "route": [[Vector2(29.2, 35.1), "ship", 1.0, "embarcadouro"], [Vector2(27.6, 32.4), "drop", 1.0]],
		"lines": ["O navio chega, descarregamos, ele vai. Ninguém nunca pergunta de onde.", "Cobre, linho, ânforas. As marcas nas caixas estão raspadas."]},
	{"id": "estivador_embarcadouro_2", "look": "marinheiro", "title": "Marinheiro do navio", "speed": 33.0, "route": [[Vector2(30, 35.1), "ship", 1.0, "embarcadouro"], [Vector2(31.6, 32.6), "drop", 1.0]],
		"lines": ["O capitão diz que este é o último porto antes do fim do mapa.", "Já descarreguei esta mesma caixa. Tenho certeza. Ou quase."]},
	{"id": "pescador_pier", "look": "remador", "title": "Pescador do píer", "speed": 26.0, "route": [[Vector2(33.6, 38), "fish", 26.0, 1], [Vector2(33.4, 36.4), "idle", 4.0]],
		"lines": ["Daqui vejo os navios chegarem. Sempre os mesmos, sempre com outra carga.", "Sabu amarrava o barco no outro píer. Ele voltou a lembrar, dizem."]},
	# Cais do Cobre.
	{"id": "estivador_cobre_1", "look": "estivador", "title": "Estivador do cobre", "speed": 35.0, "route": [[Vector2(46.8, 42.1), "ship", 1.0, "cobre"], [Vector2(48.6, 33.6), "drop", 1.0]],
		"lines": ["Cobre de Axum, dizem as marcas. Ou diziam, antes de alguém raspar.", "O armazém come tudo o que o navio traz. E pede mais."]},
	{"id": "carregador_cobre", "look": "carregador", "title": "Carregador do cobre", "speed": 31.0, "route": [[Vector2(48.4, 42.1), "ship", 1.0, "cobre"], [Vector2(46.2, 34.2), "drop", 1.0]],
		"lines": ["Ânforas de vinho e de óleo. Eu levo, eu largo, eu volto.", "Quando o navio parte, fico olhando o mar. É o único descanso."]},
	# Portão das Caravanas.
	{"id": "caravaneiro_portao", "look": "caravaneiro", "title": "Caravaneiro", "speed": 30.0, "route": [[Vector2(44.6, 5.6), "idle", 5.0], [Vector2(43.6, 2.5), "buy", 4.0, "padeira"], [Vector2(51.4, 6.4), "chat", 6.0], [Vector2(52.6, 2.5), "buy", 4.0, "cervejeiro"]],
		"lines": ["A caravana chegou do deserto. Os camelos lembram o caminho melhor do que nós.", "Sal, cobre e incenso. Trocamos tudo por pão e esquecimento."]},
	{"id": "carregador_caravana", "look": "carregador", "title": "Carregador da caravana", "speed": 32.0, "route": [[Vector2(43.6, 6.8), "pick", 1.0], [Vector2(49.6, -.4), "drop", 1.0]],
		"lines": ["Do portão ao armazém, do armazém ao portão. O caminho eu nunca esqueço.", "Adiam tem uma tenda aqui. Vende mapas a quem ainda lembra para onde vai."]},
	# Fornos do Bronze Esquecido.
	{"id": "remador_fornos", "look": "remador", "title": "Ajudante dos fornos", "speed": 32.0, "route": [[Vector2(60.6, 6.4), "pick", 1.0], [Vector2(67.4, 2.4), "drop", 1.0], [Vector2(63.4, 4.4), "go"]],
		"lines": ["Carvão para os fornos de Nakht. O bronze lembra a forma que lhe dão.", "O fogo nunca apaga. Eu é que apago, de vez em quando."]},
	# Escadaria dos Peregrinos e Praça dos Três Sinos.
	{"id": "peregrina_escadaria", "look": "peregrina", "title": "Peregrina da escadaria", "speed": 24.0, "route": [[Vector2(21.4, -9.6), "idle", 4.0], [Vector2(28.2, -18.4), "pray", 8.0], [Vector2(28.6, -14.4), "idle", 4.0]],
		"lines": ["Subo a escadaria todos os dias. Lá em cima há três sinos, e nunca lembro qual toquei.", "A Lua primeiro, depois o Sol... ou era a Estrela? Os sinos sabem."]},
	{"id": "aguadeira_escadaria", "look": "aguadeira", "title": "Aguadeira da escadaria", "speed": 28.0, "route": [[Vector2(18.6, -12.4), "chat", 6.0], [Vector2(26.6, -10.4), "idle", 5.0], [Vector2(24.4, -16.4), "idle", 4.0]],
		"lines": ["Levo água aos que sobem. Eles bebem e esquecem que tinham sede.", "Lá em cima o vento fala com os sinos."]},
	# Pátio dos Escribas e Arquivo dos Nomes Velados.
	{"id": "escriba_patio", "look": "escriba", "title": "Escriba", "speed": 27.0, "route": [[Vector2(5.4, -12.6), "idle", 6.0], [Vector2(5.4, -23.6), "idle", 6.0], [Vector2(8.6, -28.4), "pray", 5.0]],
		"lines": ["Copio os nomes do Arquivo. Quando volto ao começo, a tinta já mudou.", "Alguém reescreve os nomes à noite. Eu só copio o que encontro de manhã."]},
	{"id": "escriba_arquivo", "look": "escriba", "title": "Escriba do arquivo", "speed": 25.0, "route": [[Vector2(1.6, -27.4), "idle", 7.0], [Vector2(10.6, -25.4), "chat", 6.0], [Vector2(6.6, -30.6), "idle", 5.0]],
		"lines": ["Este arquivo guarda nomes velados. Velados por quem? Isso não está escrito.", "Se achares o teu nome aqui, não o leias em voz alta."]},
	# Cisterna das Duas Fontes.
	{"id": "aguadeira_cisterna", "look": "aguadeira", "title": "Aguadeira da cisterna", "speed": 28.0, "route": [[Vector2(16.4, 33.8), "pick", 2.0], [Vector2(19.4, 32.6), "drop", 1.0], [Vector2(20.6, 36.4), "idle", 4.0]],
		"lines": ["Encho a ânfora na cisterna e esqueço para quem.", "Duas fontes: uma para beber, outra para lembrar. Ninguém sabe qual é qual."]},
	# Jardim Inundado.
	{"id": "padeira_jardim", "look": "padeira", "title": "Moça do jardim", "speed": 26.0, "route": [[Vector2(13.6, 24.6), "idle", 6.0], [Vector2(19.6, 22.4), "idle", 5.0], [Vector2(16.4, 27.6), "chat", 5.0]],
		"lines": ["O jardim inundou no dia em que todos esqueceram. A água ficou.", "Colho junco para cestos. O junco cresce mesmo sem ninguém lembrar dele."]}
]
