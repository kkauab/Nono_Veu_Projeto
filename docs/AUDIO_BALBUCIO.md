# Balbucio dos diálogos

Gustavo, 27/10/2026. Sons "tipo fala", sem palavras, no estilo de Animal Crossing e Celeste, para acompanhar o diálogo com retratos (`docs/SISTEMA_DIALOGO_RETRATOS.md`). Os sons são sintetizados, sem voz gravada e sem serviço externo. Por isso não há licença a pagar nem crédito a dar.

## Como funciona no jogo

`scripts/audio/dialogue_babble.gd` (`VeilDialogueBabble`) observa um `VeilPortraitDialogue` e toca uma sílaba cada vez que a boca do personagem da vez muda para uma pose aberta (entreaberta ou aberta). O resultado são grupos de três sílabas, uma pausa curta e uma respiração, sincronizados com o desenho.

Segue a mesma regra dos retratos: **o som acompanha a interpretação (`DELIVERY_SECONDS`), nunca o texto.** Revelar o texto com Enter não acelera nem corta o som. Avançar para a próxima fala (`stop_talking()`) silencia na hora. O ouvinte nunca faz som.

- **Banco:** cada personagem tem um banco por expressão do retrato (`neutral`, `concerned`, `sad`, `resolute`). Na tristeza a voz fica mais grave, lenta e soprada; na determinação, mais firme.
- **Ênfase:** quando a boca abre por inteiro, 30% das vezes toca uma sílaba de ênfase, mais forte e mais aguda.
- **Final:** a primeira abertura nos últimos 0,4 s da fala toca uma sílaba de final. Ela cai no ponto e sobe na pergunta (`?`).
  - Se a fala termina durante a respiração, ela fecha sem sílaba de final, e a pausa já encerra a frase. Na abertura isso acontece em 2 das 24 falas.
- **Variedade:** a mesma sílaba nunca toca duas vezes seguidas, e o tom varia ±5% (`pitch_scale`).
- **Volume:** −8 dB no bus `Vozes`, que envia para o `Master`. São três vozes que se sobrepõem para o eco curto de cada sílaba soar até o fim.
  - O bus é criado em tempo de execução, se ainda não existir. `VeilSfx.ensure_buses()` (sons de combate) cria o mesmo bus com o mesmo nome, e quem rodar primeiro cria; nunca fica duplicado.

Na abertura, `opening_cutscene.gd` cria o nó `DialogueBabble` logo depois do diálogo. Para dar voz a outra conversa:

```gdscript
var babble := VeilDialogueBabble.new()
babble.dialogue = minha_caixa_de_dialogo   # um VeilPortraitDialogue
add_child(babble)
```

## Bancos de sílabas

`tools/audio/build_dialogue_babble.py` gera tudo, só com a biblioteca padrão do Python (sem pacotes e sem ffmpeg). A saída é sempre igual: rodar de novo não muda nenhum byte.

| | |
|---|---|
| Personagens | SENU e PESCADOR |
| Expressões | as 4 dos retratos |
| Categorias | passagem (10), ênfase (4), final de ponto (3), final de pergunta (3) |
| Total | 160 WAV mono, 22050 Hz, 0,12 a 0,28 s, 1,2 MB |
| Arquivos | `assets/audio/dialogue_babble/<personagem>_<expressão>_<categoria>_NN.wav` |
| Índice | `scripts/audio/dialogue_babble_banks.gd` (gerado, não editar à mão) |

A síntese usa um pulso glotal de Rosenberg e quatro ressonadores de formantes das vogais (a, e, i, o, u). As consoantes viram estalo, chiado ou murmúrio nasal. Cada personagem tem tom, tamanho do trato vocal, ritmo, aspereza e sopro próprios.

Para mudar uma voz ou acrescentar um personagem, edite `SPEAKERS` ou `EXPRESSIONS` no script e rode:

```powershell
python tools/audio/build_dialogue_babble.py
& $demoGodot --headless --path . --editor --import --quit
```

O nome em `SPEAKERS` precisa ser o mesmo usado em `begin_line` (ex.: `"PESCADOR"`). Personagem sem banco fica em silêncio.

## Arquivos

Novos, da área de áudio (Gustavo): `tools/audio/build_dialogue_babble.py`, `assets/audio/dialogue_babble/`, `scripts/audio/dialogue_babble.gd`, `scripts/audio/dialogue_babble_banks.gd`, `tests/dialogue_babble_test.gd` e este documento.

Fora da área: `scripts/ui/opening_cutscene.gd` (zona 4, livre) ganhou só a criação do nó, no `_ready`. `scripts/ui/portrait_dialogue.gd` não foi alterado.

Proposta para combinar com o Kauã: criar a zona **5. Áudio** em `docs/COLABORACAO.md`, com `tools/audio/`, `assets/audio/`, `scripts/audio/` e `tests/dialogue_babble_test.gd`.
