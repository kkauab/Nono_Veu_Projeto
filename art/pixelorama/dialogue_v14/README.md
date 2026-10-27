# Retratos animados da conversa

Os dois bustos usam resolução nativa de160×192 pixels, escala fixa e transparência. Senu mantém a identidade do retrato já usado no menu, espelhado para olhar para o centro da conversa. O pescador tem um busto original guiado pelo mesmo estilo e pela roupa/rosto do NPC do cais.

## Arquivos

- `senu.pxo` e `fisherman.pxo`: fontes editáveis do Pixelorama,36cels por personagem e seis camadas: busto/vestes, sobrancelhas/expressão, olho próximo, olho distante, boca e lenço.
- `assets/ui/dialogue_v14/senu.png` e `fisherman.png`: PNGs de jogo exportados pelo Pixelorama,960×1152pixels, seis colunas e seis linhas.
- `export_plan.json`: contrato dos estados e índices.
- `sources/senu_base_original.png`: cópia preservada do retrato já existente.
- `sources/fisherman_generated.png`: nova imagem gerada com a ferramenta integrada, a partir de referências do retrato de Senu e do pescador v13. Prompt em `FISHERMAN_PROMPT.md`.
- `sources/fisherman_base.png`: seleção em160×192 para os retoques nativos.

## Estados e animação

Há quatro expressões: `neutral`, `concerned`, `sad`, `resolute`. Cada expressão contém três estados de olhos (`open`, `half`, `closed`) e três de boca (`closed`, `small`, `open`). O índice de cada cel é `expression*9 + eye*3 + mouth`.

Olhos e boca têm desenhos próprios e podem combinar-se independentemente. A animação não muda o tamanho nem a posição do busto. Partes fora dos traços faciais permanecem idênticas em todos os quadros. O texto da interface controla a boca; não há gravação de voz nem sincronização fonética com áudio.

## Acabamento das pálpebras e lábios

A revisão visual do usuário apontou uma faixa branca solta no estado half e apagamento da órbita no estado closed. A função `eyes()` do preparador foi refeita: preserva a sombra orbital, o contorno inferior, os cantos e a textura originais; retoca somente a abertura real do olho. A pálpebra usa quatro tons locais com pequenas variações de textura, a íris continua parcialmente visível no half e o closed não tem nenhum pixel de esclera. Nenhum polígono branco novo é usado para simular a abertura.

Os três estados de boca também foram retocados. A abertura é pequena e afunilada, com cantos, sombra interna, lábio inferior e no máximo dois pixels de dente. Não há uma faixa uniforme de dentes. O bigode e a barba do pescador permanecem idênticos fora da abertura da boca; bochechas e queixo não recebem retângulos de preenchimento.

As referências aprovadas antes de exportar estão em `qa/dialogue_eyes_reworked_v14.png` e `qa/dialogue_faces_reworked_v14.png`. A seleção e os retoques são determinísticos no preparador, em resolução nativa, e ficam separados nas seis camadas do projeto. Não houve uma nova geração da cabeça ou mudança de identidade nessa revisão.

## Reproduzir

`tools/pixelorama/prepare_dialogue_portrait_references_v14.py` preserva/prepara as referências. `tools/pixelorama/build_dialogue_portraits_v14.py` desenha os retoques dos olhos, pálpebras, sobrancelhas e lábios na resolução nativa e grava as camadas editáveis. As expressões não são quatro novas gerações independentes: assim, rosto, cabeça, roupas e iluminação conservam a mesma identidade.

`tools/pixelorama/export_dialogue_portraits_v14.ps1` chama o Pixelorama instalado para os dois PNGs, verifica saída0, atualização e log, publica o manifesto e importa no Godot. `tools/pixelorama/validate_dialogue_portraits_v14.py` compara alpha e todos os pixels visíveis dos 36 cels com a composição das seis camadas nativas, e verifica independência entre olho e boca e identidade fora do rosto. O resultado fica em `qa/dialogue_portraits_v14_validation.json`.

Prévias: `qa/dialogue_senu_expressions_v14.png`, `qa/dialogue_fisherman_expressions_v14.png` e `qa/dialogue_*_speaking_v14.gif`.
