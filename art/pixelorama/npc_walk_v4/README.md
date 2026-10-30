# Caminhada dos moradores — v4

Refina somente a locomoção dos 12 tipos de moradores/vendedores. Repouso, conversa, gestos, piscadas, trabalho e as fontes v3 permanecem intactos. Ankhet e os seis NPCs nomeados não receberam mudanças nesta etapa.

## Arte e execução

`npc_walk_v4.pxo` contém 192 cels completos: oito fases sem carga e oito com carga por aparência. Canvas64×64, pivô(32,58), oito colunas; tags por aparência e modo. O novo PNG/JSON fica em `assets/world/npc_walk_v4*`.

As fases são contato, descida, passagem e subida, alternadas entre os dois apoios. `npc_walk_art.gd` usa um ciclo a cada24pixels percorridos no plano do chão, com eixoY normalizado pelo mesmo fator do movimento. O tempo parado não avança a caminhada; a fase continua ao virar, mudar de carga ou velocidade. Sombras, colisões, rotinas e regras de missão/salvamento ficam no mesmo lugar.

Fontes novas criadas com a ferramenta integrada ImageGen em `sources/`, com prompts e referências de identidade extraídas dos sprites aprovados. `gait_pose_guide.png` orienta a articulação; as folhas carregadas específicas corrigem mãos/objetos e quadros cortados. Os `.source.json` registram grades irregulares e folhas separadas. Todos os quadros finais usam a pose completa, incluindo corpo, mãos e carga; não há blocos de tronco/carga congelados sobre pernas novas.

O preparo corrige o zoom acidental das folhas geradas: cada pose completa é amostrada em escalaXY uniforme para corpo43–45pixels, com deslocamento inteiro, cabeça alinhada horizontalmente e apoio no chão. Essa normalização acontece antes da exportação; o jogo desenha os pixels nativos, com filtro nearest e alpha binário. Não há redimensionamento por quadro em execução. A paleta é a mesma dos interiores. Registro de escala/origem por cel e hashes das fontes/arquivos preservados ficam no planoJSON. Algumas poses de locomoção têm vista mais lateral que o repouso.

## Manter e conferir

Edite `npc_walk_v4.pxo` no Pixelorama e execute `tools/pixelorama/export_npc_walk_v4.ps1`. O exportador só publica esse projetoPNG+JSON e importa no Godot. `build_npc_walk_v4.py` é produção inicial e recusa sobrescrever um projeto existente; `--probe nome` produz apenas diagnósticos. Não reconstrua sobre edições manuais.

- `tests/npc_walk_animation_test.gd`: deslocamento real, chegada curta, bloqueios, desvio, sono distante, parada, direção, carga e cadência.
- `tests/npc_walk_assets_test.gd`: cels/exportação, oito fases, transparência, plano do chão e preservação porhash dos dez recursos anteriores.
- `tests/port_life_test.gd -- --qa`: rotinas, comércio e convivência no mapa.
- `tests/npc_walk_preview.gd -- --qa`: comparação gráfica em rotas reais, slotQA exclusivo e nenhuma gravação de jornada. O modo anterior reproduz os9pixels por quadro; o refinado usa oito fases por24pixels.

Pranchas/GIF de conferência em `qa/npc_walk_v4/`. Arte gerada e montagem procedural não equivalem a desenho manual no aplicativo; a percepção final de fluidez continua sendo avaliada em movimento no jogo.
