# Chão v8 do Porto (Gustavo, 30/10/2026)

Jogadores comentaram que as construções não combinavam com o chão. A análise:

| Problema | Causa |
|---|---|
| Cores de mundos diferentes | As construções do Porto v7 usam a família quente da paleta: madeiras (`4b3b2d`, `846443`), arenito ocre e oliva (`a27d50`, `a49e66`, `7d8051`), areia e dourado, com faixas verde-azuladas. Os ladrilhos usavam os cinzas frios (`646b60`, `4b5553`, `6d7b70`), que quase não aparecem nelas. |
| Tabuleiro | Cada losango era uma cor chapada, com cruz de juntas e borda clara de 1 px: o chão inteiro virava uma grade repetida. |
| Paredão chapado | A face vertical do cais era a cor do setor escurecida, sem blocos. |

## O que mudou

- **Texturas contínuas por tema** (`assets/world/ground_v8/<tema>.png`, 512×256): cada uma repete a cada 8 tiles nos dois eixos do chão, que na tela dá um retângulo que fecha sem emenda.
  - O `port_layout.gd` desenha cada tile como um polígono com UV = posição no mundo ÷ tamanho, com repetição ligada no `FloorChunk`. O piso atravessa os tiles sem a borda de cada losango.
  - Um pixel da textura é um pixel do mundo.
- **Lajotas** desencontradas, com junta de 1 px e chanfro de luz em cima e à esquerda, na mesma direção da luz das construções. Rachaduras raras e grão discreto. Manchas em grãos agrupados (Bayer em blocos de 2×2 mais sorteio por célula de 4×2), não em chuvisco.
- **O chão recua atrás das figuras:** os tons vizinhos têm quase o mesmo valor e mudam por manchas de cerca de 2 tiles (ruído no centro da lajota), não lajota a lajota; as tábuas continuam variando uma a uma. A junta fica um degrau abaixo da pedra, longe do escuro dos contornos. Faixa de luminância p5–p95 das texturas: 56–72 (era 83–115); no jogo, a pedra dos Fornos foi de 100 para 56 e a cripta de 79 para 52.
- **Cada tema:**
  - **pedra:** arenito greige e oliva em manchas, com areia nas juntas (sem lajotas ocre, que formavam faixas laranja);
  - **areia:** terra batida com lajes aflorando e marcas de vento só em parte da praça, em duas direções e em traços curtos;
  - **madeira:** tábuas com veio e pregos;
  - **mosaico:** lajes de 1 tile desencontradas, rosáceas verde-azuladas e douradas a cada 4 tiles e uma faixa de pedrinhas, como nos templos;
  - **jardim:** musgo nas juntas; onde falta uma lajota inteira, terra clara com capim, seguindo o contorno das vizinhas (antes eram ovais escuros que pareciam buracos);
  - **cripta:** lajes frias de 2×1 desencontradas (a grade de losangos sumiu), poucos glifos gravados em tom baixo e poeira;
  - **aqueduto:** pedra molhada com canaletas d'água;
  - **arena:** lajes de calcário claro e frio, com marcas de arrasto.
- **Paredões:** a pedra tem capa clara, duas fiadas de blocos e faixa molhada com limo; a madeira tem a viga com veios. A textura segue a inclinação da borda: u = x do mundo, v = profundidade.
- **Transições entre temas:** onde dois chãos se encontram, o vizinho avança em grãos agrupados. Fica meio a meio na borda e some dentro do tile, sem troca seca nem meio-tom borrado. Com o raio antigo (1,6 tile) e o Bayer pixel a pixel, a borda píer → mercado parecia chuvisco.
  - `port_layout.ground_blend` calcula, em cada canto do tile, a fração do tema vizinho num raio de 0,75 tile (`BLEND_RADIUS`): só os quatro tiles do canto.
  - O `GroundBlend` de cada pedaço desenha o losango com esses pesos pelo `assets/shaders/harbor_pixel_ground_blend.gdshader`.
  - **Madeira não se mistura:** onde as tábuas encontram outro chão, `_draw_wood_trim` desenha uma viga de arremate (faixa escura de ~3 px com fio de luz). Píer e pedra se encontram numa borda construída.
- **Arena do Porteiro** em calcário claro e frio (`lichen`, `sage`), sem marrom. O Porteiro é marrom-avermelhado escuro (matiz 0,02–0,11, saturação ~0,5) e sumia na terra ocre da primeira versão.
- **Cor do setor:** tinge o chão em 22% (`GROUND_TINT`), para distritos vizinhos do mesmo tema não ficarem idênticos.
- **Reserva:** sem os PNG, `_draw_tile` volta aos ladrilhos do Porto v7. Os interiores das casas continuam com a arte deles.

## Arquivos

- Gerador: `tools/pixelorama/build_ground_v8.gd`. Ele grava `art/pixelorama/ground_v8/ground_v8.pxo` (um quadro por tema), `ground_faces_v8.pxo`, os PNG e o manifesto. Para ajustar, mude `STYLE`/`_color` e rode de novo; com `-- --preview` ele grava `qa/ground_v8_preview.png`.
- Desenho: `scripts/world/port_layout.gd` (`ground_texture`, `ground_tint`, `ground_blend`, `_draw_tile`, `_build_floor_chunks`, `GroundBlend`) e `assets/shaders/harbor_pixel_ground_blend.gdshader`.
- Capturas antes e depois de nove lugares (um por tipo de piso): `qa/chao/antes_*.png` e `qa/chao/depois_*.png` (`qa/chao/chao_preview.gd`). Bordas entre setores e a arena com o Porteiro: `qa/chao/novo_*.png` (`qa/chao/bordas_preview.gd`).
- Ajuste de contraste e bordas (30/10, noite): antes e depois em zoom inteiro (1× e 2×) em `qa/chao_ajuste/`; a versão anterior do gerador, do shader e dos PNG está em `qa/chao_v8_backup/`.
