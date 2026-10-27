# Casas, interiores e lojas — plano (Gustavo, 27/10/2026)

Zona 3 (Mundo). Este plano parte da economia de combate já implementada (seção 1). O resto é proposta: nomes, preços e números ficam **[PROPOSTA]** até o Gustavo e o Kauã aprovarem.

## 1. O que já está no jogo: XP e óbolos dos inimigos

| Peça | Arquivo | O que faz |
|---|---|---|
| Regras | `scripts/economy/economy.gd` | Tabela por arquétipo, curva de nível, bônus, divisão em moedas e orbes. Funções puras sobre `store.data`. |
| Queda no chão | `scripts/world/loot_drop.gd` | Orbes de XP voam sozinhos até Senu (creditados em 4 s mesmo se não chegarem). Moedas saltam, assentam e são atraídas a 56 px. |
| Ganchos | `scripts/world/port_demo.gd` | `_drop_loot` ligado ao sinal `defeated` antes de `_on_enemy_defeated`; `collect_loot`; salvamento 1 s depois da última coleta; bônus de nível em `_apply_upgrades`. |
| Save | `scripts/save/save_store.gd` | Campos novos `xp` e `coins` (inteiros, 0 a 999999). Saves antigos abrem com zero. |
| HUD | `scripts/ui/game_hud_v6.gd` | "NV n", barra fina de XP sob a vida, moedas ao lado do Nous, linha "+10 XP +7 óbolos" sob o painel, total no inventário. |
| Teste | `tests/loot_economy_test.gd` | 43 verificações: regras, balanço, save, migração e a queda real no mundo (`-- --qa`). |

| Arquétipo | Vida | XP | Óbolos |
|---|---:|---:|---|
| runner | 85 | 8 | 3–5 |
| guard | 110 | 10 | 4–7 |
| lancer | 135 | 13 | 5–8 |
| keeper | 160 | 16 | 6–10 |
| Porteiro (chefe) | 400 | 120 | 55–65 |

- Nível: passar do nível *n* custa `20 + 20·n` XP (40, 60, 80…). Cada nível dá +5 de vida máxima; a cada dois níveis, +1 de dano.
- A quantia de cada inimigo vem de uma semente do seu id: o mesmo inimigo sempre paga o mesmo valor.
- Limpar o Porto inteiro (38 inimigos, que não renascem) dá **526 XP → nível 6** e **274 óbolos**. Os preços da seção 5 foram feitos para esse total: dá para comprar mais ou menos metade das lojas, então o jogador escolhe.
- Um inimigo já registrado em `defeated` nunca paga de novo.
- Fragmentos de Nous continuam vindo só da exploração, como o GDD decide. XP e óbolos são trilhas separadas.

## 2. Casas escolhidas

Os armazéns (`warehouse`) já têm uma porta aberta sob o toldo, na face da frente-esquerda (ver `qa/porto_demo-market.png`). Eles viram as entradas. Nenhuma arte nova é necessária para a fachada.

| Casa | Distrito | Fachada (tile) | Quem está dentro | Função |
|---|---|---|---|---|
| **Casa da Guarda** | Guarita do Retorno (`p4`) | `warehouse` em (9, 18.5) | ninguém | Ensina que casas podem ser abertas. Baú com 30 óbolos e uma inscrição sobre a guarda que esqueceu o turno. |
| **Empório de Merit** | Armazém das Vozes (`p2`), colado ao Mercado | `warehouse` em (30, −0.25) | Merit, vendedora de bálsamos | Cura: cargas de bálsamo e potência. Os dois armazéns do Mercado têm o santuário e a estela do mercador a ~17 px da porta, por isso o empório ficou no vizinho. |
| **Forja de Nakht** | Fornos do Bronze (`kilns`) | `warehouse` em (65, −2.75) | Nakht, fundidor | Melhorias de arma. Sala 8 × 6 com forno aceso, armeiro, bigorna, tina e carvão. |
| **Tenda de Adiam** | Portão das Caravanas (`caravan`) | `warehouse` em (48, −2.75) | Adiam, caravaneira de Axum | Mapa, amuleto e sandálias. Sala 7 × 5 com paredes de lona listrada, tapete, cavalete com mapa, baú de troca e cordões com nós. |

O armazém do santuário (−3, −3.9) fica reservado para uma futura casa de Iri, ligada às missões de `port_story.gd`.

O tema de perda de memória do Porto entra nos lojistas: Merit esqueceu o nome dos próprios frascos e os reconhece pelo cheiro; Nakht não lembra como apagar o forno; Adiam guarda as rotas em cordões com nós porque não confia na própria memória.

## 3. Como o jogador entra, compra e sai

```
Porto ──[E] na porta──► escurece 0,25 s ──► Senu aparece na soleira de dentro
                                              │  HUD mostra o nome da casa
                                              ▼
                         [E] no lojista ──► fala curta ──► painel da loja (pausa o jogo)
                                              │  Comprar · Voltar
                                              ▼
                         [E] na soleira ──► escurece ──► Senu de volta diante da porta, virado para a rua
```

Regras:

1. A porta é um `PortInteractable` novo, `kind = "door"`, com rótulo "Entrar · Empório de Merit". Fica no chão diante do vão da fachada.
2. Durante a transição, `player.controls_enabled = false`; volta a `true` no fim. Inimigos continuam do lado de fora.
3. Dentro, a câmera fica parada no centro da sala, como nos interiores de Zelda. A sala inteira cabe na tela (640 × 360 do mundo).
4. A saída é a soleira de dentro (`kind = "door"` também, rótulo "Sair para o Mercado"). Senu volta a um ponto um pouco à frente da porta de fora (`outside` no catálogo). A porta só reage ao E, então ele não reentra sem querer. A posição muda sem `reset_at`, que curaria Senu a cada porta.
5. Posição não vai para o save, como hoje. Se o jogo for fechado dentro da casa, Senu reabre no último santuário.
6. Não há combate dentro. Os inimigos não entram: a navegação deles (`AStar2D` em `enemy.gd`) só conhece os tiles do Porto, e o raio de detecção (155 px) nunca alcança uma casa, que fica a milhares de pixels.
7. Menu, mapa e árvore funcionam dentro. O mapa marca Senu na porta de fora, não na posição real da sala.

### Painel da loja

- Abre como os outros painéis do HUD (`show_overlay("shop")`), pausando o mundo.
- Topo: nome do lojista e bolsa ("74 óbolos").
- Uma linha por item: nome, descrição curta, preço, "2/3" quando há limite. Botão "Comprar · 35" desativado sem saldo, esgotado ou sem pré-requisito, com o motivo na descrição ("Precisa das Adagas do Reverso").
- Compra: valida → debita → aplica o efeito → salva na hora → atualiza o painel. A mesma ordem do GDD para a Árvore das Emanações.
- Sem venda de itens nesta fase.

## 4. Arquitetura

### Opção escolhida: interiores como bolsões no mesmo mundo

Cada casa é uma sala montada longe do Porto (tiles com x ≥ 140), dentro do mesmo `DepthSortedWorld`. Reaproveita Senu, câmera, colisão, ordenação por profundidade, HUD e salvamento. Não troca de cena.

A alternativa (uma cena ou SubViewport separada por casa) isola melhor, mas obriga a esconder o Porto, mover Senu entre árvores de nós e duplicar câmera e HUD. Fica descartada para a demo.

### Arquivos novos (zona Mundo, salvo indicação)

| Arquivo | Conteúdo |
|---|---|
| `scripts/world/house_catalog.gd` | Dados de cada casa: nome, distrito, tile da porta de fora, tile de saída, origem e tamanho da sala, tema do piso, móveis, lojista e loja. |
| `scripts/world/house_interior.gd` | `Node2D` que desenha piso (com `Art.draw_tile`), paredes do fundo, recorte das paredes da frente e um fundo escuro em volta; cria a colisão das bordas pelo mesmo método de `port_layout._build_boundaries`. |
| `scripts/world/houses.gd` | Lógica estática chamada pelo `port_demo`: `build(game)`, `activate(game, item)`, `inside(game)`, `map_position(game)`. Também a subclasse `HouseFixture` (de `PortInteractable`), que desenha portas, baús e bilhetes sem mexer em `interactable.gd`. |
| `scripts/economy/shop_catalog.gd` | Itens, preços, limites, pré-requisitos e efeitos; lojas como listas de ids. |
| `scripts/ui/shop_panel.gd` | Monta os botões do painel usando os ajudantes do HUD. Zona 4 (livre). |
| `tests/house_interior_test.gd` | Ver seção 6. |

### Ganchos em arquivos compartilhados (avisar antes)

| Arquivo | Mudança |
|---|---|
| `port_demo.gd` | **Feito na fase 1:** `Houses.build(self)` depois de `Story.build(self)`; caso `"door", "house_chest", "house_note": return Houses.activate(self, item)` em `activate`; em `_physics_process`, dentro de uma casa o setor continua sendo `current_room` (hoje `Layout.room_at` devolve `"p1"` para qualquer tile fora do mapa); variáveis `inside_house` e `house_busy` e a função `map_position()` no fim. **Feito na fase 2:** caso `"shopkeeper"` junto das portas em `activate`; `Shop.refill(store.data)` no santuário, antes de salvar; tecla `use_item` em `_physics_process`, logo depois do `interact`; `buy_item(id)` e `use_balm()` no fim. **Feito na fase 3:** em `_apply_upgrades`, `Shop.health_bonus` na vida máxima, `Shop.damage_bonus(store.data, equipped)` no dano e `_apply_shop_dodge()`; em `_stats_changed`, `_apply_upgrades(false)` quando a arma muda; `buy_item` aplica o efeito na hora. |
| `save_store.gd` | **Feito na fase 2:** campos `purchases` (id → quantidade comprada) e `items` (carga → quantidade), vazios em saves antigos. `ShopCatalog.valid_state` recusa id desconhecido, quantidade fracionária, negativa ou acima do limite e cargas acima dos jarros comprados. O baú da fase 1 usa `collect(id, 0)`, que marca a coleta sem dar Nous. |
| `game_hud_v6.gd` | **Feito na fase 1:** nome da casa no painel de área (lido de `game.inside_house`, porque `current_room` continua sendo o distrito e a casa não entra em `visited`) e Senu na porta de fora no mapa (`game.map_position()`). **Feito na fase 2:** caso `"shop"` em `_build_controls` e `_draw_modal` (o desenho fica em `scripts/ui/shop_panel.gd`), `show_shop(título, loja, saudação)`, cargas de bálsamo acima do painel da arma e "R · Usar bálsamo" na tela de controles (agora em colunas de 7). **Feito na fase 3:** com o Mapa das rotas, `_draw_map` desenha o contorno dos setores não visitados (menos `MAP_HIDDEN`: a Alcova do Escriba e as duas salas do Eco, para não estragar o atalho) e os inclui no enquadramento. |
| `interactable.gd` | **Não foi preciso na fase 2:** a Merit é um móvel desenhado em `house_interior.gd` (atrás do balcão) e a conversa é um `HouseFixture` de `kind = "shopkeeper"` na frente do balcão, porque o raio de interação (43 px) não alcança quem está atrás dele. Para a arte da fase 4, os lojistas podem reaproveitar o `kind = "npc"` e o campo `figure` criados em `port_story.gd`, com figuras novas `"merit"`, `"nakht"`, `"adiam"` (um ramo cada em `_draw_figure()`). Em `activate`, encadear: `"iri_mark", "iri_relic", "npc": return Story.activate(self, item) or Houses.activate(self, item)`, já que `Story.activate` devolve `false` para ids que não são dele. O nome "Sabu" já é do irmão do pescador. |
| `input_bindings.gd` | **Feito na fase 2:** ação `use_item` na tecla **R**. Avisar o Kauã. |
| `player.gd` (zona 2) | **Não foi preciso na fase 3:** o dano por arma entra em `damage_bonus` pelo `_apply_upgrades`, calculado para a arma salva como equipada, e `_stats_changed` o recalcula quando Senu troca de arma (o sinal `stats_changed` já sai de `equip_weapon`). As Sandálias mudam `player.dodge_cooldown` a partir do valor original, guardado na primeira chamada. |

### Plantas dos interiores

Vista de cima, norte no alto. As paredes do fundo (norte e oeste) são desenhadas altas; as da frente ficam em recorte baixo para não esconder Senu. `·` piso, `▓` parede, `S` soleira (entrada e saída).

**Casa da Guarda** — 6 × 5, piso de pedra

```
▓ ▓ ▓ ▓ ▓ ▓
▓ c · · I ▓    c  catre       I  inscrição na parede
▓ · · · · ▓    B  baú (30 óbolos, uma vez)
▓ B · · m ▓    m  mesa com lamparina
▓ ▓ S ▓ ▓ ▓
```

**Empório de Merit** — 7 × 6, piso de mosaico

```
▓ ▓ ▓ ▓ ▓ ▓ ▓
▓ p p p p p ▓    p  prateleiras com jarros (parede do fundo)
▓ · M · · · ▓    M  Merit, atrás do balcão
▓ b b b · a ▓    b  balcão     a  ânforas
▓ · · · · a ▓
▓ ▓ ▓ S ▓ ▓ ▓
```

**Forja de Nakht** — 8 × 6, piso de pedra escurecida

```
▓ ▓ ▓ ▓ ▓ ▓ ▓ ▓
▓ F F · · r r ▓    F  forno (2 tiles, brilho alaranjado)
▓ · N · · · · ▓    N  Nakht    r  armas penduradas
▓ · · g · · t ▓    g  bigorna  t  tina de têmpera
▓ x · · · · · ▓    x  carvão
▓ ▓ ▓ ▓ S ▓ ▓ ▓
```

**Tenda de Adiam** — 7 × 5, piso de areia com tapete

```
▓ ▓ ▓ ▓ ▓ ▓ ▓
▓ m · A · k ▓    m  mapa aberto sobre cavalete    A  Adiam
▓ · t t t · ▓    t  tapete     k  cordões com nós
▓ s · · · c ▓    s  selas      c  caixotes
▓ ▓ ▓ S ▓ ▓ ▓
```

**Arte (fase 4):** `art/pixelorama/interiors_v1/interiors_v1.pxo`, gerado por `tools/pixelorama/build_interiors_v1.gd` (script do Godot, porque o Python da máquina não tem PIL) e exportado pelo próprio Pixelorama com `EXPORTAR_INTERIORES.cmd` (`tools/pixelorama/export_interiors_v1.ps1`). São 30 quadros de 128 × 144 com pivô (64, 112): Merit, Nakht e Adiam (parado, inspirando, piscando), forno (3 quadros de fogo), carvão (2 brasas), balcão, duas prateleiras, armeiro, cordões, baú de troca, bigorna, tina, cavalete, sela, ânfora, catre, mesa, barril e o baú da guarda aberto e fechado. O jogo lê a folha por `scripts/world/interior_art.gd`; sem ela, os desenhos de reserva em GDScript continuam valendo. Braseiro e caixote usam a arte do Porto. Para editar à mão: `ABRIR_INTERIORES_PIXELORAMA.cmd`, salvar e rodar `EXPORTAR_INTERIORES.cmd`. Rodar o gerador de novo sobrescreve o `.pxo`.

## 5. O que cada loja vende [PROPOSTA]

Os bálsamos funcionam como cargas recarregáveis: voltam cheios ao meditar num santuário. Assim o dinheiro, que é finito porque os inimigos não renascem, compra capacidade e não consumo.

| Loja | Item | Efeito | Preço | Limite | Requer |
|---|---|---|---:|---:|---|
| Merit | Jarro de bálsamo | +1 carga de cura (40 de vida, tecla R) | 35 | 3 | — |
| Merit | Mirra concentrada | Cada carga cura +15 | 50 | 1 | 1 jarro |
| Nakht | Pedra de amolar | +2 de dano em todas as armas | 45 | 1 | — |
| Nakht | Têmpera do Khopesh | +3 de dano com o Khopesh | 70 | 1 | Pedra de amolar |
| Nakht | Têmpera das Adagas | +2 de dano por golpe das Adagas | 60 | 1 | Adagas do Reverso |
| Adiam | Mapa das rotas | O mapa mostra o contorno dos setores ainda não visitados | 30 | 1 | — |
| Adiam | Amuleto de cornalina | +10 de vida máxima | 70 | 1 | — |
| Adiam | Sandálias de caravana | Esquiva recarrega 15% mais rápido | 55 | 1 | — |

Somando tudo: 105 + 50 + 175 + 155 = **485 óbolos**, contra 274 dos inimigos e 30 do baú da Casa da Guarda. As têmperas por arma ficaram no `port_demo.gd`, sem mexer no `player.gd` (seção 4).

## 6. Fases de implementação e testes

| Fase | Entrega | Teste |
|---|---|---|
| 1 ✅ | Porta, transição e a Casa da Guarda com o baú (27/10) | `tests/house_interior_test.gd` **30/30**: porta fora de fachadas e a 40 px de outras interações; sala além do mar; entrar e sair com escurecimento, sem curar; segundo toque ignorado; câmera parada; setores visitados intactos; paredes seguram Senu correndo nas quatro direções; nenhum inimigo entra; baú paga 30 uma vez e salva junto; bilhete abre o próprio texto; mapa marca a porta. Não cobre: o baú aberto depois de reabrir o jogo (o código lê `collected`, mas o teste não reinicia o mundo). |
| 2 ✅ | Empório de Merit, painel da loja, `purchases` e `items`, tecla R, recarga nos santuários (27/10) | `tests/shop_merit_test.gd` **47/47**: compra recusada sem saldo, sem o jarro, além do limite e de item desconhecido; jarro novo vem cheio; mirra soma 15; compras e cargas sobrevivem ao recarregar; 7 estados adulterados recusados; no mundo, a Merit é a interação mais próxima no balcão, o painel pausa o jogo, os botões reais compram e salvam na hora, "Esgotado" aparece, R de verdade cura 55, jarro vazio não cura, o santuário do Mercado recarrega e vida cheia não gasta carga. `house_interior_test` passou a conferir as portas das duas casas (38/38). |
| 3 ✅ | Forja de Nakht e Tenda de Adiam (27/10) | `tests/shop_forge_tent_test.gd` **37/37**: pré-requisitos (pedra antes da têmpera do Khopesh, Adagas antes da têmpera delas); pedra vale para as duas armas e cada têmpera só para a sua; amuleto +10 de vida (e de vida atual), sandálias −15% na recarga da esquiva, mapa das rotas; tudo pago uma vez e salvo; no mundo, os botões reais aplicam o dano na hora, trocar de arma troca o bônus, uma jornada reaberta com as Adagas já começa com o bônus delas, o mapa abre com os contornos. `house_interior_test` passou a conferir as 4 casas (52/52), incluindo que o fundo escuro de uma sala não cobre outra. |
| 4 ✅ | Arte dos interiores e dos lojistas em Pixelorama (27/10) | `tests/interiors_art_test.gd` **13/13**: `.pxo` no formato 7 com uma tag por peça; a folha exportada pelo próprio Pixelorama é idêntica, pixel a pixel, ao projeto nativo; só as 33 cores da paleta do Porto v7, com alfa binário; todo móvel das casas tem arte; lojistas, forno e carvão animados. `house_interior_test` **54/54**: balcão e baú de troca são desenhados em fatias de profundidade, e Senu atrás deles fica coberto em todo o comprimento (no teste das casas, não no `depth_sort_test`, que é da outra sessão). |
| 5 | Decisões em aberto (seção 7) | Conforme a decisão. |

Cada fase é um PR `gustavo/dev → develop`. Antes do PR: `loot_economy_test`, o teste da fase, `route_test`, `progression_test`, `save_migration_test` e `hud_v6_test`.

## 7. Decisões em aberto

1. **Nome da moeda.** Proposta: *óbolos*, a moeda paga ao barqueiro, que combina com o Porto dos Esquecidos e com os barqueiros do mapa. Alternativa histórica egípcia: *débens* de cobre. Trocar é só mudar `Economy.CURRENCY`.
2. **Inimigos renascem ao meditar?** Hoje não (o GDD deixa em aberto). Se renascerem, o dinheiro fica infinito e os bálsamos poderiam virar consumíveis comprados um a um.
3. **Perder óbolos ao morrer?** Hoje não se perde nada. Opção: deixar metade no local da morte, recuperável ao tocar, como o "óbolo do barqueiro".
4. **Tecla do bálsamo:** R.
5. **Zona nova "Economia e lojas"** (`scripts/economy/`, `shop_panel.gd`, testes da economia) na tabela de `COLABORACAO.md`. O arquivo só muda com acordo dos dois.
