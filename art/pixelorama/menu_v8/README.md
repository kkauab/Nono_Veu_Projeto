# Senu no menu — animação v8

O projeto editável `senu_menu_idle_v8.pxo` parte dos pixels do retrato v7, preservando rosto, roupa e escala. O Pixelorama 1.2.3 instalado exportou o atlas final `D:/Nono_Veu/assets/ui/senu_menu_idle_v8.png`, de 640×576.

São 12 cels de 160×192 em dois clips independentes: seis quadros de piscar e seis quadros da ponta solta da faixa. Os olhos abrem, fecham e voltam a abrir em 0,3 s a cada 5,2 s. A faixa desloca-se somente um pixel por pose a 5 fps. O corpo não cresce, diminui nem flutua. As alterações dos olhos foram colocadas nos cels do projeto, sem gerar um rosto diferente.

O menu inicial conserva a capa pixelada v7. `assets/shaders/menu_title_v8.gdshader` anima o rio/reflexos e dobras internas da capa/faixa com amostragem de um pixel, restrita às regiões e cores desses elementos. Não desloca a imagem inteira, a cidade ou o rosto. O movimento continua durante a pausa; os atores do jogo ficam parados.

Para editar, use `ABRIR_MENU_PIXELORAMA.cmd`, salve e execute `EXPORTAR_MENU.cmd`. Preparação reproduzível: `tools/pixelorama/build_menu_idle_v8.py`; exportação oficial: `tools/pixelorama/export_menu_idle_v8.ps1`. Registro: `qa/pixelorama_menu_idle_v8.log`.

A interface em `scripts/ui/game_hud_v6.gd` mantém o caminho anterior por compatibilidade. Os textos são rasterizados na resolução final da interface; somente o mundo utiliza um SubViewport em baixa resolução. Objetivos, interações e mensagens aceitam duas linhas com fundo de alto contraste. O HUD compacto tem alturas lógicas de 76 para vida, 112 para objetivo e 70 para arma, mantendo fontes nítidas.

Validação: HUD 19/19 e capturas de 1280×720 e 1920×1080. Os filmes de 56 quadros nos menus de início e pausa confirmaram relógio avançando e posição do jogador imóvel. A área do rio mudou em 42 quadros e a região da capa do Senu em 27. O retrato mostrou os estados independentes de piscar/faixa. Prévia: `qa/hud_v8_intro_animated.gif` e `qa/hud_v8_pause_animated.gif`. HUD compacto: `qa/hud_v8_compact_720p.png`.
