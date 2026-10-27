# Impacto nos golpes, sons de combate e água viva — 27/10/2026

Gustavo pediu mais sensação de impacto nas lutas, sons (o jogo não tinha nenhum efeito sonoro) e uma água que não pareça parada, com peixes pulando. Tudo foi feito sem mudar regras de dano, alcance, tempo de ataque ou colisão.

## Impacto dos golpes

`scripts/actors/combat_fx.gd` é um filho de Senu (`CombatFx`, `top_level`, fora da ordenação de profundidade). `player.gd` só chama as funções dele nos momentos certos; `enemy.gd` (zona do Kauã) **não foi alterado**.

| Momento | Congelamento (hitstop) | Tremor | Visual | Som |
|---|---|---|---|---|
| Golpe leve | 45 ms (adagas 28 ms) | leve | clarão branco no inimigo, 5 faíscas | `hit_light` |
| Golpe que atordoa (forte, 3º do combo, poderes) | 75 ms | médio | clarão, 9 faíscas, poeira | `hit_heavy` |
| Golpe final | 100 ms (Porteiro 260 ms) | forte | clarão, faíscas, fragmentos do véu subindo, anel no chão | `hit_kill` |
| Parry | 110 ms | médio | faíscas douradas em leque, estrela, anel | `parry` |
| Senu ferido / morto | 70 / 200 ms | forte | faíscas avermelhadas, anel | `hurt` / `death` |
| Ataque, esquiva, poderes | — | — | poeira na esquiva, anel na riposta | `swing_*`, `dodge`, `power_*` |

- **Hitstop:** reduz `Engine.time_scale` a 3% do valor anterior e restaura em tempo real. Respeita `--time-scale 4` dos testes, nunca vai a zero e é desfeito se a cena for liberada no meio. Testes que medem tempo de jogo podem usar `CombatFx.hitstop_enabled = false`.
- **Tremor:** deslocamento da câmera (`Camera2D.offset`) em pixels inteiros, com um empurrão na direção do golpe.
- **Clarão:** um `ShaderMaterial` aplicado ao inimigo por alguns quadros; só os pixels opacos clareiam (sombra e aviso de ataque ficam como estão).
- **Golpe em corpo caído** não gera efeito.
- **Aviso sonoro dos inimigos:** o efeito observa `state` dos inimigos a até 300 px de Senu. Ao entrar na preparação (`WINDUP`) toca `enemy_windup`; no golpe (`STRIKE`), `swing_enemy`. O Porteiro usa as mesmas amostras mais graves e mais altas. Assim o ataque pode ser ouvido antes de ser visto.

## Sons

52 arquivos em `assets/audio/sfx/`, sintetizados por `tools/audio/build_combat_sfx.py` (só biblioteca padrão do Python; sem gravação, sem serviço externo e sem licença de terceiros). O script também gera `scripts/audio/sfx_banks.gd`. Rodar de novo reescreve arquivos idênticos.

```powershell
A:\Ferramentas\python315\python.exe tools/audio/build_combat_sfx.py
```

`scripts/audio/sfx.gd` (`class_name VeilSfx`) toca os bancos com variação de tom, sem repetir o mesmo arquivo duas vezes seguidas:

```gdscript
VeilSfx.play(self, "hit_light", enemy.global_position)   # posicional
VeilSfx.play(self, "pickup_coin")                        # sem posição
```

- Vozes posicionais ficam na viewport do mundo, que passa a ser a ouvinte 2D (`audio_listener_enable_2d`), então o som tem pan e distância em relação à câmera.
- Buses criados em tempo de execução, se ainda não existirem: `SFX` (com limitador), `Ambiente` e `Vozes`, todos enviando para `Master`. O balbucio dos diálogos usa `Vozes`; as moedas de `loot_drop.gd` usam `pickup_coin`; as casas (`houses.gd`) usam `door_open` (rangido de dobradiça e trinco) e `chest_open` (estalo da tampa e baque).
- Volume e bus de cada banco ficam em `sfx_banks.gd` (gerado). Para ajustar, mude a tabela `recipes()` do script Python e gere de novo.

## Água viva

`scripts/world/water_life.gd` é um filho de `PortLayout` criado logo depois do mar, na mesma faixa de profundidade (z −21): fica abaixo dos pisos, dos atores e das sombras das fachadas. Não tem colisão, não entra em `world_obstacles` nem em `DepthSortedWorld`.

- **Água aberta:** nada aparece sobre piso, face de pedra, estacas ou espuma (38 px de folga abaixo das bordas; 62 px para saltos).
- **Cardumes:** até 18 peixes-sombra perto da câmera, em grupos de 1 a 5 que seguem um guia, sobem do fundo e voltam a afundar. Desviam das margens olhando adiante.
- **Saltos:** um peixe à vista salta em arco a cada 1,6–4,4 s, com respingos, gotas, anéis e som (`water_splash` na saída, `water_plop` na volta). Às vezes o cardume salta em sequência.
- **Reação a Senu:** peixes a menos de 44 px fogem em arrancada; o raio sobe para 76 px quando ele corre, ataca ou esquiva. Um em cinco foge saltando para longe dele.
- **Superfície:** brilhos em traços horizontais (como as linhas de onda da textura), anéis de peixes beijando a superfície, bolhas.
- **Ritmo:** dois ciclos lentos e desencontrados (47 s e 19 s) alternam água agitada e calma.
- **Lótus e troncos:** fixos no mapa, à deriva perto das margens; lótus perto de jardins, aquedutos e mosaicos; troncos perto dos cais.
- **Som do mar:** laço de 8 s (`water_loop`, com bloco `smpl` para o Godot importar em laço) no bus `Ambiente`. O volume acompanha quanto da tela é água: mais alto no cais, quase mudo nas criptas.
- **Interiores:** fora de `PortLayout.SEA_RECT` (o retângulo onde o mar é desenhado) tudo conta como terra seca. As casas, em x ≥ 4400, não têm peixes e o mar fica mudo lá dentro.

## Arquivos

| Arquivo | Tipo |
|---|---|
| `scripts/actors/combat_fx.gd` | novo |
| `scripts/actors/player.gd` | ganchos (9 linhas) |
| `scripts/audio/sfx.gd`, `scripts/audio/sfx_banks.gd` | novos (o segundo é gerado) |
| `scripts/world/water_life.gd` | novo |
| `scripts/world/port_layout.gd` | 5 linhas no `_ready` e a constante `SEA_RECT` |
| `tools/audio/build_combat_sfx.py`, `assets/audio/sfx/` | novos |
| `tests/combat_fx_test.gd` | novo |

## Verificação

`tests/combat_fx_test.gd` (108 verificações) cobre bancos e buses (inclusive porta e baú), o laço do mar, hitstop e restauração do tempo, clarão, faíscas, som do impacto, corpo caído sem efeito, golpe final mais longo, hitstop desligável, parry, dano em Senu, liberação da cena no meio do congelamento, aviso sonoro da preparação do inimigo e, na água: nada sobre piso ou pedra, lótus só na água, cardumes, saltos, brilhos e anéis, fuga dos peixes, volume do mar menor longe da água e interiores sem água e sem som do mar.

```powershell
& $demoGodot --headless --path . --script res://tests/combat_fx_test.gd
```

Em testes headless o driver de áudio Dummy não libera as reproduções; quem toca som termina com avisos de "ObjectDB instances leaked" e "resources still in use". O código de saída continua 0.

Os testes não ouvem o som. Os arquivos foram conferidos por pico, volume e duração, e o visual por capturas do próprio Godot (`qa/fx_*.png`, fora do Git). Volume, duração do congelamento e intensidade do tremor ainda precisam ser avaliados jogando.
