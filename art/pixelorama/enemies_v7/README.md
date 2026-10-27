# Sentinelas — pixel art v7

Projeto editável: `port_enemies_v7.pxo`, 16 cels em canvas de 128 × 128, 8 fps. O PNG final foi exportado pelo **Pixelorama 1.2.3**, depois importado no Godot. A folha original `source_sheet.png` foi gerada com a ferramenta nativa ImageGen em uma etapa anterior; esta revisão não gerou imagens adicionais.

As quatro linhas representam guarda, corredor, lanceiro e guardião. Cada uma contém repouso, passo esquerdo, passo direito e golpe. São poses diferentes da fonte, com uma escala anatômica fixa por arquétipo: 46, 44, 48 e 48 pixels de altura em repouso. A altura reduzida de um golpe agachado é preservada. O jogo não aumenta nem diminui o desenho para simular passos.

Critérios de preparação: transparência binária, amostragem por vizinho mais próximo, paleta compartilhada com o porto v7 e três tons adicionais de tecido, apoio dos pés em `(64,112)`, sem normalizar individualmente a altura dos frames. Duas poses originalmente invertidas foram espelhadas antes da exportação para manter a orientação da sequência. O lanceiro foi extraído com uma seleção que preserva o topo do elmo fora da divisão regular das linhas.

A direção esquerda usa espelhamento horizontal. Esta folha contém quatro poses por arquétipo, sem desenhos de costas ou oito direções independentes. O chefe utiliza a silhueta do guardião em tamanho maior. Área de aviso, dano, colisões, navegação e barra de vida continuam sendo controlados pelo jogo.

Preparação reproduzível: `tools/pixelorama/build_enemy_pixel_v7.py`. Exportação nativa: `tools/pixelorama/export_enemy_pixel_v7.ps1`. Resultado: `assets/sprites/port_enemies_v7.png` (512 × 512) e seu manifesto. Registro: `qa/pixelorama_enemies_v7.log`. Prévia de poses: `qa/enemy_pixel_v7_preparation.png`.

Após integrar o desenho, o teste de combate aprovou 26/26 verificações e as capturas do Observatório, Cisterna e Caravanas foram produzidas sem erros. As mudanças anteriores de disposição também aprovaram 124/124 verificações do mundo e 121/121 da rota original.
