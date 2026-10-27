# Pescador da abertura

O mesmo estilo de Senu orienta o novo civil: corpo adulto de 40 px, rosto pequeno, lenço de linho, túnica gasta, rede e cesto. A versão com chapéu grande não foi integrada. O jogo usa a mesma escala para todos os quadros.

- Fonte editável: `fisherman.pxo`, oito cels de 128×128, quatro colunas.
- PNG de jogo: `assets/cinematics/rpg_v12/fisherman.png`, 512×256.
- Apoio comum: `(64,112)`. A escala única vem do corpo parado, com âncoras de cabeça/cintura e chão selecionadas no original.
- Poses: parado, contato esquerdo, passagem esquerda, contato direito, passagem direita, conversa, escuta e despedida.
- Preparação: `tools/pixelorama/build_fisherman_v13.py`.
- Exportação real: `tools/pixelorama/export_fisherman_v13.ps1` ou `EXPORTAR_ABERTURA.cmd`.
- Abrir fonte: `ABRIR_PESCADOR_PIXELORAMA.cmd`.

A fonte gerada está preservada em `sources/fisherman_guided.png`; o prompt da ferramenta integrada está em `PROMPT.md`. O preparo faz seleção, escala fixa por vizinho mais próximo e redução a uma paleta comum sem pontilhamento. O Pixelorama instalado exporta o atlas final.
