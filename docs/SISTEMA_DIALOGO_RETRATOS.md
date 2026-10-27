# Diálogo com retratos

`scenes/ui/portrait_dialogue.tscn` e `scripts/ui/portrait_dialogue.gd` fornecem a apresentação reutilizável da conversa. A história e o avanço pertencem ao chamador; o componente não lê teclas nem altera salvamentos ou o estado do jogo.

## Apresentação

Os bustos ficam à esquerda e à direita, acima da caixa inferior, como recortes RGBA transparentes. Não há cartão, retângulo, fundo, borda ou selo geométrico atrás dos personagens. O participante ativo conserva as cores; o ouvinte recebe um escurecimento discreto e permanece inteiramente parado. A moldura da caixa de texto conserva azul-petróleo, preto, marfim, bronze e selos geométricos. O texto usa fonte legível, com quebra de palavras e ajuste de 26 para 24/22 pontos quando necessário. Todo o conjunto se adapta à janela mantendo a proporção 1280×720; o texto é rasterizado no tamanho de exibição.

## Interface

```gdscript
var dialogue = preload("res://scenes/ui/portrait_dialogue.tscn").instantiate()
add_child(dialogue)
dialogue.advance_requested.connect(_on_dialogue_interaction)
dialogue.begin_line("SENU", "Eu volto para contar o que encontrar.", "resolute", "sad", 4.2)
```

- `begin_line(speaker, text, expression, listener_expression, delivery_seconds = 4.2)`: inicia uma fala, muda a expressão do falante e recebe a duração autorada de sua interpretação visual. `listener_expression` permanece aceito por compatibilidade, mas não é aplicado: o ouvinte conserva a expressão de sua última fala própria.
- `tick(delta)`: atualiza os relógios independentes da escrita, interpretação e piscadas. Por padrão é chamado pelo `_process`; a cutscene desativa o processo próprio e fornece a passagem do tempo.
- `is_revealed()`: informa se a fala terminou de ser escrita.
- `reveal_all()`: revela apenas o texto restante, sem alterar a interpretação dos retratos.
- `is_speaking` e `delivery_remaining`: estado da interpretação, independente de `is_typing`.
- `stop_talking()`: encerra a interpretação e fecha a boca, usado pelo chamador ao avançar para outra fala.
- `clear()`: oculta o painel e encerra escrita e interpretação.
- `line_revealed`: emitido uma vez ao terminar ou revelar a fala.
- `advance_requested`: clique/toque na caixa ou retratos. O chamador decide se revela ou avança.
- `portrait_state(speaker)` e `layout_snapshot()`: estado observável para testes/capturas. Os retângulos do snapshot estão em coordenadas locais do Control, com seu fator de layout já aplicado. A escala do viewport também é informada; no modo `canvas_items`, a janela pode ser maior que as coordenadas lógicas da interface.

As falas aprovadas cabem em até três linhas. Para falas maiores, divida a passagem em entradas narrativas antes de chamar `begin_line`; a API trata uma entrada inteira, sem páginas ocultas ou avanço automático. Teclado e regra de segurar Espaço por três segundos continuam sob o controle da abertura.

## Animação

A boca não acompanha letras, vogais, pontuação ou a revelação do texto. A interpretação visual usa uma duração atribuída ao roteiro e uma sequência natural de repouso, boca entreaberta e boca aberta, com tempos variados entre aproximadamente 0,10 e 0,20 segundo e pequenas pausas de respiração entre 0,29 e 0,47 segundo. Essas pausas ocorrem a cada um a dois segundos. O ouvinte mantém a boca relaxada.

Revelar todo o texto de uma vez não acelera, reinicia nem encerra essa sequência. O retrato continua sua interpretação até a duração autorada terminar ou até o chamador usar `stop_talking()` ao avançar. A pontuação conserva suas pausas apenas no relógio de digitação.

Somente o personagem da vez movimenta a boca e pisca. Cada piscada passa por olhos semicerrados, fechados e semicerrados. Ao trocar o turno, o novo ouvinte assume a pose de repouso, com olhos abertos e boca fechada, e conserva a expressão de sua última fala própria. Seus relógios de animação não avançam durante a fala alheia. As expressões aceitas são `neutral`, `concerned`, `sad` e `resolute`.

Cada retrato novo tem 20 cels completos de 160×192 em cinco colunas e quatro linhas, com o índice:

```text
expressão × 5 + pose
```

Poses: 0 repouso com olhos abertos, 1 boca entreaberta, 2 boca aberta, 3 piscada parcial com boca relaxada, 4 olhos fechados com boca relaxada. Cada pose é um desenho completo; o runtime não monta olhos, boca e rosto de quadros diferentes. As piscadas interrompem a pose exibida durante 0,18 segundo, mas o relógio da interpretação continua. As texturas atuais são `assets/ui/dialogue_v15/senu.png` e `fisherman.png`. A posição e o tamanho dos retratos permanecem fixos durante a fala.
