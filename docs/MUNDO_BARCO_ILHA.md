# Barco de Sabu e Ilha do Bennu — 27/10/2026

Pedido do Gustavo: lógica de navegação, um barco navegável com animações e uma ilha para explorar, com terra, árvores e missões. Tudo fica na zona 3 (Mundo). Há ganchos pequenos nos arquivos compartilhados.

## Onde fica

| Lugar | Tiles | Observação |
|---|---|---|
| Píer de Sabu | ponta do píer oeste do Embarcadouro Velho, (25.5, 38) | O barco fica amarrado em (25.5, 39.6). Sabu já dizia "Eu tinha um barco". |
| Baía das Garças | mar aberto entre o porto e a ilha | 4 ânforas à deriva e 3 rochedos para contornar. |
| Ilha do Bennu | x 35..56, y 59..77 (sala `isle`) | Fica cerca de 650 px abaixo do píer, uns 4 s de remo. O píer da ilha aponta para o porto. |

O mar já cobre tudo fora do chão (`SEA_RECT`), e as bordas de cada tile já têm colisão. O barco é um corpo que só colide com essas bordas, então navega na água e encosta na costa sem entrar na terra. Senu desembarca só nos píeres. Desembarcar em qualquer praia deixaria pular portões e selos do porto.

## Barco (`scripts/world/sea.gd`, `sea_boat.gd`)

- **Embarcar:** E na ponta do píer. Senu salta para o barco, some, e o barco passa a desenhar Senu sentado remando. A câmera continua presa ao Senu, que acompanha o barco.
- **Remar:** WASD dá a direção, com inércia (aceleração, arrasto e curva suave). Shift é a remada forte. As remadas têm som de água e deixam esteira e anéis.
- **Atracar:** perto de um píer aparece "E · Atracar"; o barco encaixa e Senu salta para a terra.
- **Sem ficar preso:** ao morrer ou carregar o jogo, o barco volta ao píer do mesmo lado do último santuário. Se Senu meditou na ilha, ele fica na ilha; senão, no porto.
- Inimigos em terra não acertam Senu no barco: o golpe deles exige linha livre, e a borda da costa bloqueia.

## Ilha do Bennu (`scripts/world/isle_layout.gd`, `isle.gd`, `isle_story.gd`)

- **Terreno:** praia de areia em volta, campo no meio, um platô de mosaico com as ruínas do Bennu a leste e um píer de madeira ao norte. A costa é irregular, desenhada por uma fórmula fixa (sem sorteio).
- **Vegetação:** tamareiras (a mesma arte do porto), acácias, sicômoro, arbustos, juncos, rochas e garças nas águas rasas.
- **Santuário:** a estela do Bennu (`isle_rest`) é um ponto de meditação novo.

## Missões

| Missão | Como | Recompensa |
|---|---|---|
| Ânforas à deriva | Passar de barco por cima das 4 ânforas. | 12 óbolos cada |
| As garças sem voz | Ankhet, a guardiã das garças, pede para afastar os 3 Esquecidos da ilha. | 50 óbolos e 40 XP |
| As três chamas do Bennu | Acender os braseiros na ordem do voo do Bennu: leste, norte, oeste. A ordem errada apaga todos. O altar das ruínas se abre. | Baú com 60 óbolos e a **Pena do Bennu** (+1 carga de bálsamo) |
| A rede de Hori | Achar na praia sul a rede com o nó de três voltas e devolvê-la a Hori, no cais. | 40 óbolos e 30 XP |

As missões não dão Nous, para não mexer no orçamento da árvore do Kauã (22 Nous). O estado fica na lista `collected` do save, como nas outras histórias.

## Arte

`tools/pixelorama/build_sea_v1.gd` gera dois projetos do Pixelorama com a paleta do Porto v7:

- `art/pixelorama/sea_v1/boat_v1.pxo`: barco de papiro com proa e popa curvas, em 16 direções, com Senu remando em 4 quadros e um quadro parado;
- `art/pixelorama/sea_v1/isle_v1.pxo`: árvores, rochas, braseiros apagados e acesos, Ankhet, garça, rede, ânfora e altar.

O Pixelorama exporta as folhas para `assets/world/boat_v1.png` e `isle_v1.png` (`EXPORTAR_MAR.cmd`). `ABRIR_MAR_PIXELORAMA.cmd` abre os dois projetos para editar à mão. Depois de editar, rode só o `EXPORTAR_MAR.cmd`: rodar o gerador de novo sobrescreve os `.pxo`.

O barco tem 6 quadros por direção: parado, pegada (com respingo), puxada (pá escura dentro d'água), saída, volta (pá no ar) e vazio. O vazio é o barco amarrado, com os remos recolhidos. Senu rema de costas para a proa, como um remador de verdade: em metade das direções aparece o manto, na outra metade o rosto.

## Arquivos

| Arquivo | O quê |
|---|---|
| `scripts/world/sea_boat.gd` | O barco: inércia, curva, remada, esteira e som. `drive()` dá para os testes remarem sem teclado. |
| `scripts/world/sea.gd` | Píeres, embarque e atracação com salto, ânforas, rochedos, esteira e o barco voltando ao píer certo. |
| `scripts/world/sea_art.gd` | Leitor das duas folhas (mesmo contrato de `interior_art.gd`). |
| `scripts/world/isle_layout.gd` | A costa, os temas do chão e onde fica cada peça. |
| `scripts/world/isle.gd` | Vegetação (copas ficam transparentes atrás de Senu), garças que voam quando Senu chega perto, as peças das missões e a estela. |
| `scripts/world/isle_story.gd` | As missões e os textos. |
| `tools/pixelorama/build_sea_v1.gd`, `export_sea_v1.ps1` | Gerador dos `.pxo` e exportador. |

Ganchos nos arquivos compartilhados, todos por acréscimo:
- `port_demo.gd`: `Isle.build` e `Sea.build`, `Sea.update` no laço, os kinds novos em `activate`, `Sea.respawn` ao reaparecer e as variáveis no fim do arquivo.
- `port_layout.gd`: a sala `isle`, o chão vindo da máscara, a rota `sea_route` e os 3 inimigos.
- `game_hud_v6.gd`: o nome "Baía das Garças" no mar e o contorno próprio da ilha no mapa.
- `save_store.gd`: o checkpoint `isle_rest` e a flag `sea_route`.
- `shop_catalog.gd`: a `pena_bennu`, que não se vende, e `grant`.
- `port_story.gd`: Hori recebe a rede, e Sabu comenta o barco.

## Testes

- `tests/boat_test.gd`: píeres, embarque, remada, costa sólida, ânfora, travessia real até o píer do Bennu (cerca de 7 s de remo), atracação e o barco voltando ao píer certo depois de morrer. Com `--capture-boat`, salva capturas.
- `tests/isle_test.gd`: chão contínuo a partir do píer, ilha separada do porto, vegetação sobre a terra, garças na água e as quatro missões sem recompensa dobrada. Com `--capture-isle`, salva capturas.

## Fluidez e navios ancorados — 27/10/2026

O Gustavo achou o mar "meio travado" e os navios ancorados flutuando. Medido com o jogo em janela, num monitor de **165 Hz**:

| O que travava | Causa | Correção |
|---|---|---|
| Tudo que anda: barco, Senu, a rolagem da tela | O limite de 60 quadros vinha ligado por padrão. A 165 Hz, cada quadro ficava 2 ou 3 atualizações na tela, alternando, e a rolagem andava 1 px por quadro nesse ritmo torto. | `scripts/core/frame_pacing.gd`: sem limite por padrão. O jogo segue o monitor (vsync), e a física roda na mesma taxa (165 passos por segundo, de 60 a 240). A opção "Limite de 60 quadros" continua nas Configurações; ligada, volta a 60. A preferência ganhou chave nova (`limit_fps_60`), porque a antiga era gravada ligada sem o jogador escolher. |
| A água | A deriva do desenho dava 1 px a cada meio segundo em x e a cada ~1 s em y: um tranco visível, ampliado 2×. | `harbor_pixel_water.gdshader`: 1 px a cada 2 trocas de quadro em x e a cada 5 em y, junto com a troca de quadro da água. |
| A remada | Eram 4 quadros por remada, cerca de 4 por segundo. | 8 quadros, de uma curva contínua de remada: pegada com respingo, puxada com a pá dentro d'água, volta com a pá subindo em arco. |
| Navios ancorados | O casco aparecia inteiro, contornado, com uma sombra de chão embaixo, como se pairasse. | `harbor_pixel_moored.gdshader`, aplicado por `Sea.seat_ship`: afunda 7 px do casco numa linha d'água reta que ondula, com espuma, 1 px de balanço em pixels inteiros e anéis na água. A linha passa pelo fundo do meio do casco, então a proa e a popa curvas ficam no ar. |

Medida depois: 165 quadros e 165 passos de física por segundo, um passo por quadro desenhado. A tela rola 0 ou 1 px por quadro, regular, e o barco fica parado no centro. Antes eram 60 quadros num ritmo torto, com saltos de 1 px a cada quadro.

## Bichos do mar, naufrágio, nado e escadas (Gustavo, 30/10/2026)

O mar deixou de ser calmo. Crocodilos do Nilo espreitam em mar aberto, mordem o casco do barco e, se ele ceder, Senu cai na água e precisa nadar até uma escada.

| Peça | Onde | Como funciona |
|---|---|---|
| Crocodilos | `scripts/world/sea_beasts.gd` | 5 crocodilos comuns e 1 de Sobek (maior, escuro, colar dourado), cada um com casa em mar aberto (`HOMES`). Espreitam quase submersos; a até 210 px (Sobek 250) de um barco com Senu ou de Senu nadando, caçam a 88 px/s e dão bote a 150 por 0,8 s. A mordida tira 20 de casco (Sobek 34) ou 10 de vida de Senu (Sobek 16); depois recuam 1,1 s e esperam 2,3 s. Desistem a 620 px de casa, em terra ou perto dos píeres (130 px em volta da água de cada píer é segura). Colidem só com a camada 1, então ficam no mar como o barco. Não são inimigos do porto: nem o grupo "enemies" nem `enemy.gd`. |
| Casco | `scripts/world/sea_boat.gd` | `hull` de 100, barrinha sobre o barco depois da primeira mordida, tremor e respingo. Atracar remenda. Em 0 emite `wrecked`. |
| Naufrágio | `sea.gd` `capsize` | O barco emborca e afunda onde estava (`SinkingBoat`, 2,6 s); Sabu o recupera inteiro no píer do último santuário; Senu passa a nadar no mesmo ponto. |
| Nado | `scripts/world/sea_swim.gd` | Controles de Senu desligados (sem golpe, esquiva nem selo); o módulo move o corpo dele com `move_and_collide` a 48 px/s (Shift 65), e as bordas dos tiles seguram o nadador no mar. `SwimView` desenha a braçada de peito da folha de nado (ver "Mergulho"), com anéis e respingos; sem a folha, o sprite real de Senu (`senu_supplied_view`) cortado no peito. O estado é a meta "swimming" do `port_demo`; o HUD mostra "Baía das Garças". Morrer na água leva ao santuário como sempre. |
| Escadas | `scripts/world/sea_ladders.gd` | Calculadas ao montar o mundo: faces visíveis do paredão (+x e +y) que dão para o mar ligado aos píeres, em chão alcançável **com todos os portões fechados** a partir do santuário e de cada píer, uma a cada 7 tiles, longe dos postes e de peças. Desenho num nó só junto do chão; cada uma tem um ponto de subida (`sea_ladder`, inativo em terra). Nadando, as próximas acendem anéis no pé; E ao pé sobe com a mesma animação do desembarque. Subindo num chão com píer, a correnteza leva o barco a esse píer, para ninguém ficar preso numa ilha. |
| Arte | `tools/pixelorama/build_sea_v2.gd` | Gera `art/pixelorama/sea_v2/sea_beasts_v1.pxo` e a folha `assets/world/sea_beasts_v1.png` com manifesto (`sea_art.gd`): crocodilo e Sobek em 8 direções (nadando 4 quadros, à espreita 2, mordendo 2) e escadas de madeira para paredão de pedra (20 px) e píer (11 px). Paleta do Porto v7. |

Teste: `tests/sea_beasts_test.gd` (355 verificações: casas em mar aberto, escadas fora de áreas com portão, mordidas no casco até ceder, nado preso ao mar, mordida no nadador, subida, barco levado ao píer do Íbis, bichos desistindo em terra e morte na água). Capturas: `qa/mar/` (`qa/mar/mar_preview.gd`).

## Mergulho e água rasa (Gustavo, 30/10/2026)

Pedido: um sistema de mergulho para ver o interior do mar, e melhorias no mar.

| Peça | Onde | Como funciona |
|---|---|---|
| Entrar na água | `sea.gd` `leap` | Com o barco parado e longe de um píer, **Espaço** faz Senu saltar na água. O barco fica vazio onde estava, e os crocodilos não ligam para barco vazio. Nadando a até 34 px dele, **E · Subir no barco** (`reboard`) usa o mesmo salto do píer. |
| Mergulhar | `scripts/world/sea_dive.gd` | Nadando, **Espaço** leva Senu ao fundo e **Espaço** o traz de volta. O corpo é o de Senu, movido como no nado (40 px/s, Shift 54), preso ao mar pelas mesmas bordas. Estado: a meta `diving`, que só existe junto do nado. |
| Fôlego | `sea_dive.gd` | 22 s, mostrados em 6 bolhas sobre a cabeça (piscam no fim). Sem fôlego, Senu volta sozinho à tona e perde 15 de vida. Mergulhado, ele some do faro dos crocodilos (`sea_beasts.gd`, `target`). |
| O fundo | `DiveLayer` em `world_stage` (a SubViewport de pixel), z 4000 | Leito de areia contínuo, algas e pedras por sorteio fixo por tile (mais algas no raso), o chão do porto como blocos que sobem 24 px do leito (o mesmo piso escurecido por cima e as faces do paredão), estacas e sombra sob os píeres, cardumes que fogem de Senu, bolhas, plâncton e as silhuetas do barco e dos crocodilos vistas de baixo. Tudo o que não se move é ordenado uma vez pela base e desenhado de trás para a frente com Senu no meio. Som do mar e golpes abafados (passa-baixa nos buses Ambiente e SFX). |
| Luz e cor | `assets/shaders/harbor_pixel_underwater.gdshader` | A água come o vermelho, puxa as cores para o verde-azulado e escurece com a distância do chão, em faixas de grão agrupado. Cáusticas: a rede de linhas entre células de Voronoi que andam devagar, em blocos de 2 px e a 8 quadros por segundo. |
| Tesouros | `sea_dive.gd` `TREASURES` | 5 ânforas do fundo (15 óbolos cada, IDs `dive_amphora_1..5` em `collected`) e a estela do porto afundado, com texto. Ruínas fixas (`LANDMARKS`): cabeça colossal, colunas, tambores, âncoras de pedra e o casco junto ao Recife. Os marcadores são `PortInteractable` inativos: o laço da superfície não os vê. |
| Profundidade | `scripts/world/sea_depth.gd` | Um pixel por tile do `SEA_RECT`: a distância até o chão, até 8 tiles, por busca em largura ao montar o mar. Serve à água rasa e ao fundo. |
| Água da superfície | `harbor_pixel_water.gdshader` | O recorte de 128 px do quadro da água não fechava nas bordas e deixava emendas retas; agora ele se espelha a cada repetição. Perto do chão a água fica mais clara e esverdeada, em duas faixas de grão agrupado (até ~2 e ~3,5 tiles). |
| Nado animado | `tools/pixelorama/build_senu_swim_v1.gd`, `sea_swim.gd` `pose` | Folha `assets/sprites/senu_swim_v1.png` (fonte `art/pixelorama/senu/swim_v1/senu_swim_v1.pxo`), no formato do `senu_boat_v2`: canvas 96×96, pivô 48,76, 8 direções × 6 quadros. Feita como as poses do barco: o quadro parado de `senu_shared_v6` reduzido uma vez a .26 e articulado, com braços desenhados no estilo dos braços do remo. **surface**: cabeça e ombros acima da linha d'água (o pivô), braçada de peito. **dive**: para os lados, o perfil girado 90° exatos, com as pernas ondulando e a capa colada às costas que escorre para trás; para cima e para baixo, o corpo de pé com a pernada aberta. A braçada anda a 1,5 ciclo/s (Shift 2, boiando 0,55). Sem a folha, volta o desenho antigo. Prévia: `-- --preview` → `qa/senu_swim_v1_preview.png` e `_zoom.png`. |
| Arte | `tools/pixelorama/build_seabed_v1.gd` | Gera `art/pixelorama/seabed_v1/seabed_floor_v1.pxo` e `seabed_props_v1.pxo`, mais `assets/world/seabed_v1/floor.png`, `props.png` e o manifesto (retângulo e pivô de cada peça). Paleta do Porto v7; a cor de água vem do shader. Prévia: `-- --preview` → `qa/seabed_v1_preview.png`. |

Teste: `tests/sea_dive_test.gd` (82 verificações: profundidade e água rasa, tesouros em água livre, a folha de nado completa e sem corpo abaixo da linha d'água, salto do barco, mergulho, crocodilos sem faro, fôlego, ânfora que paga uma vez, estela, subir de volta no barco, reaparecer desfazendo o mergulho). Com janela e `--capture-dive`, grava `qa/mar_mergulho/nado_*.png` e `fundo_*.png`.

## Ainda não feito

- Entrar na água pelo píer (hoje só pelo barco ou no naufrágio).
- Desembarcar fora dos píeres: de propósito, para não pular os portões do porto.
- Um terceiro píer, por exemplo no Cais do Cobre, para viagens mais longas.
