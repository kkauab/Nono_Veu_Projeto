# Senu sentado no barco — arte v3

Refinamento da identidade visual: poses sentadas completas substituem o recorte da postura em pé e os braços desenhados como linhas da v2. A gola/pala azul-petróleo, o manto com acabamento dourado, as ombreiras, mangas claras, braçadeiras, faixa de cabelo e botas são mantidos juntos em cada desenho. Coxas, joelhos e quadril têm postura sentada própria.

A fonte `sources/rowing_generated.png` foi criada com a ferramenta integrada ImageGen usando `sources/senu_identity_reference.png` (extraída do corpo v6 do jogo) como referência. O prompt integral está em `sources/PROMPT.md`. São cinco vistas reais × oito poses; vistas à esquerda usam espelhamento. O `.png` gerado e sua transparência foram preservados sem sobrescrever os sprites antigos.

`tools/pixelorama/build_senu_boat_v3.py` seleciona as 40 silhuetas completas, aplica uma única escala nearest de 0,17 e posiciona o quadril no banco. `selection.json` registra recortes e âncoras de quadril/mãos escolhidas. Nenhuma normalização por altura de quadro é aplicada. O construtor não encolhe um corpo em pé nem pinta novos braços sobre ele.

Os remos usam `oar_grips.json`: pegadas revistas nos punhos e curtos cabos originais, em cinco vistas × oito fases. A transformação de cada pegada é a mesma do recorte/resize nearest do corpo, incluindo a escala efetiva e o arredondamento; um ajuste de até 1 px fixa a pegada no pixel sólido do punho. Nas costas, as âncoras ocultas são inferidas dos ombros e do ciclo frontal, e ficam atrás do manto.

A associação entre mão e remo é fixa por vista; não se troca de lado pelo punho que estiver mais perto do apoio em cada quadro. Cada cabo é reto da mão, pelo tolete, até a pá. Os dois cabos internos ficam atrás de mãos, braços e roupa; só a parte externa do remo próximo passa sobre a borda do casco. `oar_contacts.json` registra pegada, apoio e ponta por quadro/direção para revisão. O ajuste dos remos preservou byte a byte os 160 cels do corpo. Reconstruções limitadas a remos podem usar `--replace-generated --oars-only`; essa opção recusa qualquer diferença no corpo do PXO existente antes de gravar.

Botas e barra da roupa ficam ocultas pelo fundo do casco quando abaixo do piso; coxas e joelhos preservam a pose sentada. A borda próxima só cobre a parte realmente à frente do quadril; a ponta distante fica atrás da cabeça e do manto. Casco e bancos são preservados da fonte vazia v1. A densidade e as cores são conferidas no tamanho de jogo e em ampliação nearest.

`boat_v3.pxo` contém três camadas (casco/remo distante; Senu sentado; borda/remo próximo), 160 quadros e 16 tags de direção. Contrato preservado: célula 96×80, pivô (48,54), repouso 0, remadas 1..8, vazio 9. As transições de entrada/saída v2 permanecem separadas e compatíveis; não foram redesenhadas nesta revisão.

Para editar, abra o `.pxo` no Pixelorama e depois rode `tools/pixelorama/export_senu_boat_v3.ps1`. Esse exportador não reconstrói a arte. O construtor recusa sobrescrever um `.pxo` existente; `--replace-generated` só é apropriado para reconstrução intencional antes de edições manuais. Fontes v1/v2/v6 continuam preservadas.

QA visual: `qa/boat_senu_v3/bodies.png`, `rowing.png` e `senu_remando_v3.gif`. Testes: `senu_boat_animation_test.gd` e `boat_test.gd -- --qa`. Os números do STATUS correspondem à nova execução; testes não medem por si só a adequação artística.
