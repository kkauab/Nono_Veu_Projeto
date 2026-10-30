# Mapa do Porto — análise e ampliação (30/10/2026)

Zona 3 (Mundo). Análise feita lendo o código e medindo o mapa no Godot 4.7.2 (`qa/mapa/analise.gd`: chão, cenário e vazios por setor; `qa/mapa/occupancy.gd`: mapa ASCII de ocupação). Capturas em `qa/mapa/` (pasta ignorada pelo Git).

## 1. Onde Senu começa

Depois da abertura (`opening_cutscene.gd`), `port_demo._opening_finished` só devolve o controle: Senu continua onde o save o pôs, no checkpoint `hub` = `MARKERS["hub_spawn"]` (-1, -1), no **Santuário da Primeira Palavra**. O santuário tinha 9 × 8 tiles, com o prédio, dois braseiros, quatro pilares, dois moradores e um gato. Saídas: leste (Cais, a rota principal), norte (Escribas), o atalho trancado ao sul e a grade do Eco a oeste.

## 2. Lugares vazios ou pobres

Medida: parte do chão a mais de 3 tiles de qualquer coisa (cenário, peça, morador) e o maior círculo vazio.

| Setor | Antes | Depois | O que era |
|---|---|---|---|
| Limiar das Catacumbas | 41 %, r 4 | 24 % | Área de teste, quatro peças |
| Estrada do Sal | 38 %, r 6 | 14 % | Uma palmeira e um armazém num campo de areia |
| Reservatório | 36 %, r 3 | 8 % | Um anel de pedra em volta do lago, sem nada |
| Fornos do Bronze | 29 %, r 5 | 15 % | Nenhuma fornalha |
| Terraço do Farol | 29 %, r 5 | 11 % | O farol e o molde comum |
| Escadaria dos Peregrinos | 28 %, r 6 | 12 % | Um vazio de 6 tiles no meio |
| Pátio dos Escribas | 28 %, r 4 | 16 % | Nenhuma marca de escriba |
| Arquivo / Praça dos Sinos | 21 % / 19 % | iguais | Têm templo e escada; ficaram para depois |
| Cais do Cobre | 20 % | 11 % | Pouca carga para um cais de navios |

- **Molde repetido:** os 14 distritos da expansão saem do mesmo gerador (pilar em cada canto, muro e tocha a cada 4 tiles na borda de cima, arco ou armazém, estátua, entulho). Cada um parecia o vizinho; já estava na lista de `MUNDO_EXPANSAO.md` (melhoria 1) e não tinha sido feito.
- **Becos e bordas:** a Descida do Eco (37 %) e o Aqueduto são corredores com motivo (atalhos). As bordas da frente dos distritos do leste davam para o mar sem nada. O mar entre o santuário, a Galeria do Eco e o corredor do atalho estava vazio.
- **Santuário pequeno:** o primeiro lugar do jogo era o menor setor jogável, e o HUD o conta junto com o corredor do atalho (bug 4 de `MUNDO_EXPANSAO.md`, ainda aberto).

## 3. Ambientação por local

**Como era (`ambient_audio.gd`):** dois sons globais. O vento tocava a −18 dB em todo lugar, só abaixado dentro das casas e na pausa. O zumbido sagrado subia pela distância em linha reta a seis pontos fixos (320 px cheio, some em 480 px), sem saber em que setor Senu está. Não havia luz por lugar (nenhum `CanvasModulate` ou `Light2D`); só o chão e as tochas mudavam.

**Onde a lógica falhava:**
1. **O zumbido vazava pela água.** No Cais (9, 1), a 350 px do santuário, ele soava quase cheio; o mesmo no Pátio dos Escribas e na Galeria do Eco.
2. **Nenhum lugar tinha som próprio.** O Mercado sem gente, os Fornos sem fogo, a Cisterna sem água; criptas e Catacumbas com o mesmo vento do cais. Só o mar de `water_life.gd` variava, pela água visível.
3. **No barco, o setor ficava parado.** `Sea.update` devolve antes da troca de setor no `port_demo`, e `current_room` continua o último píer. O HUD escreve "Baía das Garças" por conta própria. E `Layout.room_at` devolve "p1" para qualquer ponto fora das salas (água, interiores): quem ligasse o som a ela tocaria o Cais no mar.
4. **A Ilha do Bennu soava como o porto**, apesar de ter um ponto sagrado.
5. **Luz:** a Cripta, a Arena do Porteiro e as docas tinham a mesma luz.

**Como ficou:** `ambient_profiles.gd` dá a cada um dos 33 setores um perfil, com 20 perfis no total. O perfil define o leito sonoro, o vento, se o zumbido sagrado pode soar e a cor da luz.
- **Leitos:** ondas, murmúrio, fornalha, pingos de cripta, água de canal, grilos e sinos ao longe. São gerados em Python puro e determinístico por `tools/audio/build_ambient_places.py`, em laços de 12 s.
- **`ambient_audio.gd`:**
  - lê o setor do `port_demo`, ou `sea`/`open_sea` no barco (mar aberto quando não há terra a 7 tiles) e `house` dentro das casas;
  - funde o leito antigo no novo com dois tocadores;
  - só deixa o zumbido soar em lugar sagrado;
  - tinge o mundo com um `CanvasModulate` ("SectorLight") dentro da viewport de pixels, devagar: criptas azuladas e escuras, fornos alaranjados, arena avermelhada, ilha do Íbis violeta, casas quentes. O HUD não muda.
- **Dressing:** a identidade de cada distrito está na seção 5.

## 4. Inimigos por local

Tipos (`enemy.gd`, zona do Kauã): guarda (110 de vida, golpe lento), corredor (85, rápido), lanceiro (135, alcance) e guardião (160, forte e lento).

| Região | Antes | Avaliação | Depois (só dados de spawn) |
|---|---|---|---|
| Rota inicial: Cais, Mercado, Armazém | 3 guardas | Bom para aprender: golpe lento e telegrafado | igual |
| Ponte, Pátio, Alcova, Jardim, Guarita | 5 guardas iguais | Monótono, e os nomes não batiam com o tipo | Ponte: **lanceiro** (alcance numa ponte estreita). Alcova: **guardião** (protege as Adagas, conteúdo opcional). Jardim: **corredor** (o "errante"). Guarita: **lanceiro** (último teste antes do Porteiro). Pátio: guarda |
| Norte (Voz) | Escribas, Arquivo, Sinos, Escadaria: misto | Coerente | igual |
| Sul (Maré) | Cisterna, Comportas, Soterrado: dificuldade crescente | Coerente | igual |
| Leste (Céu, o mais distante) | Mais guardiões e lanceiros | Coerente com a distância | igual |
| Ilha do Bennu | corredor, guarda, lanceiro (missão de Ankhet) | Coerente | igual |
| Santuário, Claustro, Aqueduto, Eco, Catacumbas | nenhum | O santuário fica seguro; as Catacumbas vêm depois do chefe (A02 futura) | igual |
| Ilhas novas | — | — | Íbis: **guardião e lanceiro** (escribas vazios). Recife: **corredor e guarda** (saqueadores) |

Os ids não mudaram; o save é compatível. Balanço (`loot_economy_test`): eram 41 inimigos, 557 de XP (nível 7) e 288 óbolos; agora são 45 inimigos, 614 de XP (nível 7) e 311 óbolos, dentro das faixas do teste (níveis 5 a 8, 200 a 400 óbolos).

## 5. Melhorias, por prioridade

Feitas nesta entrega:
1. **Ambientação por setor**, com o vazamento do zumbido corrigido (seção 3).
2. **Área inicial ampliada:** o **Claustro dos Iniciados** (setor `cloister`), 125 tiles a sudoeste do santuário.
   - **Ligação:** uma boca de 4 tiles na borda sul do santuário. Um tile de água separa o claustro do corredor do atalho e da Galeria do Eco, então os portões continuam valendo.
   - **Cenário:** a Casa das Primeiras Palavras (templo), mestres de pedra, palmeiras, braseiros, muro e um lago sagrado com canteiro.
   - **Para descobrir:** três estelas com as lições de Iri, lidas em qualquer ordem, abrem a **Arca do Noviço** (30 óbolos e 25 de XP).
   - **Saída:** o **marco dos caminhos**, no santuário junto à saída leste, aponta Cais, Escribas e Claustro.
3. **Identidade dos lugares vazios:** 60 peças com a arte real nos distritos (96 contando o claustro e as ilhas), em `port_dressing.IDENTITY`:
   - Fornos: fornalhas, escória, lingotes;
   - Estrada do Sal: montes de sal, barraca do salineiro, carga, marco;
   - Escadaria: estelas votivas, toldo da aguadeira;
   - Escribas: toldo de cópia, fileira de estelas de registro;
   - Farol: braseiro de sinal, jarros, blocos caídos;
   - Reservatório: palmeiras, estátuas e juncos no lago;
   - Cais do Cobre: carga e cabeços;
   - Catacumbas: colunas e entulho.

   Cada peça passa pelo validador do gerador: base inteira no chão (`Art.footprint`), fora das bocas de passagem, longe de peças de missão, de inimigos e das paradas dos moradores. Se não couber, tenta um passo ao lado; se ainda não couber, fica de fora.
4. **Duas ilhas além do Bennu**, só de barco, com píer, nenhum Nous e a costa desenhada no mapa:
   - **Ilha do Íbis Afogado** (`ibis`, x 1..23, y 63..82, sudoeste). Um templo de escribas afundando, com um lago sagrado. Enigma: a inscrição dá a ordem (olho, pena, junco) para as três estelas e abre o nicho do Copista (70 óbolos e 50 de XP). Segredo: uma tabuleta enterrada na ponta sul (25 óbolos).
   - **Recife do Navio Esquecido** (`wreck`, x 65..91, y 59..74, leste). Um navio mercante encalhado, com a vela içada e a carga na areia. Coleta: quatro caixas lacradas (15 óbolos cada) e três ânforas no mar. O diário de bordo revela a arca do capitão junto à palmeira torta (60 óbolos e 40 de XP).

Pendentes:
5. **Nome do mar no HUD** por região ("Mar Aberto" fora da baía): `game_hud_v6.gd` fixa "Baía das Garças" (zona Interface).
6. **Bug 4:** o corredor do atalho é contado como "Santuário" no HUD e no som. Pede uma sala própria para o corredor, o que mexe em `visited`.
7. **Arte própria para a identidade:** fornalha, carroça, monte de sal, estante e casco partido. Hoje são composições de peças existentes; um conjunto v8 no Pixelorama daria mais leitura.
8. **Arquivo, Praça dos Sinos e Observatório** ainda seguem o molde comum.
9. **Moradores e fauna nas áreas novas** (outro agente; sugestões no relatório).
10. **Rota escondida Armazém → Guarita** prevista no GDD (linha 366), e as Catacumbas (A02).

## 6. Como foi feito

| Arquivo | Papel |
|---|---|
| `scripts/world/cloister_layout.gd`, `far_isles_layout.gd` | Chão (costa por fórmula fixa, sem sorteio), píeres, marcadores e plantas das áreas novas |
| `scripts/world/cloister.gd`, `far_isles.gd` | Lições, arca, marco, enigma do íbis, tabuleta, caixas, diário e arca do capitão |
| `scripts/world/extra_fixture.gd` | Peça interativa das áreas novas: base sólida atrás do pivô, desenho com a arte real |
| `scripts/world/port_layout.gd` | Salas novas no fim de `ROOMS` (`shape` próprio), conector do claustro, ligações do mapa, tipos de inimigo e 4 spawns novos, `sea_only_tiles()` |
| `scripts/world/port_dressing.gd` | `IDENTITY` e `_populate_identity` (validados); marcadores novos protegidos |
| `scripts/world/isle.gd`, `isle_story.gd`, `sea.gd` | Ganchos: plantas e peças das ilhas e do claustro em `Isle.build`; `Isle.activate` entrega as peças novas ao módulo delas; píeres `ibis` e `wreck`, ânforas e rochedos novos, `FarIsles.on_landed` |
| `scripts/audio/ambient_audio.gd`, `ambient_profiles.gd`, `tools/audio/build_ambient_places.py` | Ambientação por lugar e os sete leitos |

- **Sem tocar no `port_demo.gd`.** As peças novas usam o tipo `isle_altar`, que o `port_demo` já encaminha ao `Isle.activate`.
- **Save:** nenhum campo novo. O progresso fica em `collected`, com ids novos (`cloister_*`, `ibis_*`, `wreck_*`, `isle_amphora_5..7`), e a rota usa a flag `sea_route`, que já existia. Saves antigos abrem sem migração; só as torres gravam.
- **Testes novos:** `cloister_test`, `far_isles_test` (viagem real de barco até as duas ilhas e entre elas) e `ambience_places_test`.
- **Testes ajustados:** `world_v6_test` (contagens; ancora numa torre antes de reabrir o save, como manda a regra das torres; as duas falhas antigas sumiram) e `isle_test` (conta só as plantas do Bennu).

## Moradores e fauna sugeridos para as áreas novas (posições em tiles)
- **Claustro:** noviço (look "escriba"): (-6.6, 11.0) rezar 10 s → (-10.0, 11.6) parado 6 s → (-4.0, 7.2) parado 5 s. Gato Mau com casa em (-11.6, 9.6), raio 2,5. Falcão no templo em (-12.3, 5.7), altura ~60.
- **Ilha do Íbis:** escriba esquecido: (11.0, 77.6) rezar 12 s → (15.6, 75.0) parado 6 s. Garça no templo em (7.2, 73.6), altura ~70.
- **Recife:** náufrago (look "marinheiro"): (81.6, 69.6) parado 8 s sob o toldo → (75.2, 66.8) pegar → (80.4, 68.8) largar. Gaivotas no mastro (89.6, 71.8), altura ~22, e no cabeço (72.4, 65.6), altura 8.
- **Estrada do Sal:** caravaneiro: (60.0, 18.2) pegar → (63.6, 21.2) largar; a barraca em (61.6, 14.0) pode ganhar um vendedor de sal.
- **Fornos:** ferreiro: (69.6, 0.6) parado 6 s diante da fornalha → (66.0, 5.6) pegar → (70.6, 3.0) largar.
- **Reservatório:** aguadeira: (60.4, 33.0) pegar → (58.6, 30.4) parado. Garças nos juncos (62.0, 36.6) e (66.4, 32.8).
- **Farol:** falcão no braseiro de sinal (82.6, 13.0), altura ~40. **Cais do Cobre:** gaivotas nos cabeços (42.6, 42.4) e (51.6, 42.4).
- **Escadaria:** peregrina rezando nas estelas votivas em (31.0, -13.4).
- Poleiros novos precisam de `prop` real embaixo (regra em `bird_catalog.gd`); a ilha do Bennu ainda não tem nenhum.
