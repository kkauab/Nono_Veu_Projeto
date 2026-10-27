# Novos retratos completos v15

Esta é a fonte atual dos retratos de conversa de Senu e do pescador. Cada personagem tem20sprites completos novos, criados pela ferramenta integrada de geração de imagens. As versões anteriores foram usadas somente como referência de identidade, roupa e estilo. Nenhum cel final reutiliza o rosto ou o corpo anterior.

## Desenhos e referências

- `sources/senu_generated.png` e `sources/fisherman_generated.png`: duas folhas novas com20bustos inteiros cada, cinco colunas e quatro linhas. Criação integrada com os prompts `SENU_PROMPT.md` e `FISHERMAN_PROMPT.md`.
- `sources/senu_half_generated.png`: revisão integrada da coluna de meia piscada. Somente os quatro retratos completos dessa coluna são importados; os outros16permanecem da primeira folha. Prompt `SENU_HALF_PROMPT.md`.
- `sources/fisherman_half_four_generated.png`: os quatro bustos completos finais de meia piscada, em uma folha2×2 para manter as proporções. Prompt `FISHERMAN_HALF_FOUR_PROMPT.md`. As tentativas em faixa vertical e na folha completa foram preservadas para rastreabilidade, mas não são usadas na exportação final.
- `sources/*_reference.png`: referências de identidade; não são cels finais.

O preparador `tools/pixelorama/build_dialogue_portraits_v15.py` faz apenas seleção do desenho inteiro, remoção de franjas saturadas externas, escala uniforme da folha, registro do busto inteiro e redução a uma paleta comum de128cores, sem pontilhamento. Ele **não desenha olhos, boca, sobrancelhas ou pele**, não usa borracha, não combina partes de outros retratos e não faz morph/escala pulsante. Todos os detalhes faciais já existem no desenho completo gerado.

## Fonte editável e contrato

`senu.pxo` e `fisherman.pxo` têm20cels completos de160×192pixels, com uma camada de desenho integral e grupos por expressão. Os PNGs de jogo são `assets/ui/dialogue_v15/{senu,fisherman}.png`,800×768pixels, cinco colunas e quatro linhas. O índice é `expression*5 + pose`.

| Linha | Expressão |
|---|---|
|0|neutral|
|1|concerned|
|2|sad|
|3|resolute|

| Coluna | Pose completa |
|---|---|
|0|Repouso, olhos abertos|
|1|Fala com boca discretamente entreaberta|
|2|Fala com abertura um pouco maior|
|3|Meia piscada, íris parcialmente visível|
|4|Piscada fechada, sem esclera visível|

Senu olha para a direita; o pescador olha para a esquerda. A boca é uma pequena cavidade orgânica, sem faixa uniforme de dentes. As piscadas preservam a órbita, as pálpebras e o volume da pele. Os gestos de fala no jogo têm cadência natural independente da digitação do texto.

O manifesto `export_plan.json` registra, para cada cel, a fonte completa, retângulo selecionado, fator único da folha, translação inteira e hash nativo. Também registra os retângulos faciais para QA, sem usá-los na criação dos sprites.

## Exportação e verificação

O Pixelorama instalado exporta os PNGs por `tools/pixelorama/export_dialogue_portraits_v15.ps1`; o script verifica encerramento sem erro, arquivo atualizado, log e importação no Godot. Os atalhos de retratos apontam para os projetos atuais.

`tools/pixelorama/validate_dialogue_portraits_v15.py` confere20cels distintos por personagem, transparência binária, dimensões e correspondência exata entre alpha/pixels visíveis dos PNGs exportados e a fonte Pixelorama. Resultado em `qa/dialogue_portraits_v15_validation.json`.

Prévias nativas aprovadas: `qa/dialogue_new_complete_faces_v15.png`, `qa/dialogue_{senu,fisherman}_complete_v15.png` e os GIFs equivalentes. Os PNGs usados pelo Godot são sempre os exportados pelo Pixelorama, não essas folhas de QA.
