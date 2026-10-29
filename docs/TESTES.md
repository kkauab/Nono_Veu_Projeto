# Verificações do protótipo

## Inimigos renovados nos salvamentos manuais — 27/10/2026

Meditar em qualquer um dos cinco santuários agora salva o checkpoint, recarrega os frascos, restaura Senu e renova todos os inimigos comuns. Os vivos recuperam posição, vida e estado; os mortos e os já removidos são recriados uma única vez. O chefe derrotado permanece ausente. `Salvar e sair` grava o novo ciclo para o próximo carregamento. Autosaves de combate, loot, compras e exploração mantêm as derrotas do ciclo atual.

`tests/enemy_respawn_test.gd -- --qa`: **58/58**, saída 0, sem erros ou avisos. Cobre corpos recentes, removidos e com exclusão enfileirada; inimigos feridos ou atacando; descanso repetido; população sem duplicatas; XP e óbolos exatos por vida; preservação do loot anterior; autosaves sem renascimento; cancelamento de golpes e projéteis; chefe permanente; recarga do snapshot; falha de gravação sem alterar derrotas, checkpoint, frascos ou atores. As coletas únicas, habilidades e estados dos puzzles permanecem salvos.

Regressões aprovadas: progressão **123/123**, economia de loot **43/43**, loja da Merit **47/47**, puzzles e mundo **125/125**, percurso **137/137**. As duas suítes de navegação voltam a isolar o combate depois da meditação, pois o descanso agora recria corretamente os encontros. Todos os testes usam slots próprios em `user://qa/`.

## Árvore das Emanações ampliada — 27/10/2026

Treze habilidades compráveis, três trilhas, três híbridos e Convergência. Os IDs das três habilidades anteriores permanecem válidos. Testes com Godot 4.7.2, usando somente slots `user://qa/`:

| Suíte | Resultado | O que verifica |
|---|---:|---|
| `skill_catalog_test.gd` | 47/47 | Dependências, compras recusadas sem débito, saves antigos, custo total 28 e rota final de 20 dos 22 Nous. |
| `skill_combat_test.gd` | 44/44 | Combo, ascendente, contra-ataque, redução de dano, projétil, reflexão, perfuração e esquiva que respeita paredes. |
| `skill_world_test.gd -- --qa` | 63/63 | Aplicação das compras no mundo, atributos sem acumular, sandálias, percepção, salvamento e rota final com orçamento real. |
| `skill_tree_ui_test.gd` | 406/406 | Treze nós selecionáveis, compra explícita, dependências, foco e textos dentro da janela em 720p/1080p. |
| `progression_test.gd -- --qa` | 123/123 | Progressão, backup, eventos do mundo, morte/retorno e compras persistentes. |
| `save_migration_test.gd -- --qa` | 32/32 | Continuidade das jornadas anteriores. |
| `shop_forge_tent_test.gd -- --qa` | 37/37 | Bônus por arma, vida e esquiva das lojas em conjunto com o recálculo das habilidades. |
| `shop_merit_test.gd -- --qa` | 47/47 | Cura, cargas e compras da Merit. |
| `hud_v6_test.gd` | 19/19 | Demais menus e navegação do HUD. |
| `combat_test.gd` | 26/26 | Combate base e duas armas. |
| `combat_fx_test.gd` | 108/108 | Efeitos de combate existentes. |
| `senu_v5_movement_test.gd -- --physics-only` | 16/16 | Movimentação e esquiva base. |

Importação completa pelo editor e inicialização gráfica da cena principal aprovadas. Captura real do jogo: `qa/porto_demo-tree.png`; capturas de detalhe da UI: `qa/skill_tree_720p.png` e `qa/skill_tree_1080p.png`. Nenhum erro de script ou teste falhou na versão final. Algumas suítes ainda emitem os avisos preexistentes de recursos retidos ao encerrar o processo de QA.

Durante a integração foi corrigida uma regressão: configurar a lista de habilidades emitia um aviso de mudança de equipamento cedo demais, sobrescrevendo a arma salva antes de equipá-la. A configuração agora apenas reconstrói a lista; os eventos de equipamento continuam emitidos pelas ações reais. O teste da Forja confirma a restauração correta do bônus das Adagas.

## Primeira demonstração — 24/10/2026

Godot 4.7.2.stable.official.ed1daf0bf; Blender 5.2.3 LTS. Verificações realizadas durante a preparação da entrega de 24/10/2026.

- Importação do projeto no Godot concluída sem erros.
- Cena principal executada por 120 quadros sem erros de script.
- `combat_test.gd`: **26 verificações aprovadas** — ataques, alcance/arco, recuperação, duas armas, esquiva, parry, riposta, cooldowns, troca, morte e dois padrões do chefe.
- `route_test.gd`: **39 verificações aprovadas** — movimento real dirigido pelo mapa, colisões, portão fechado, coleta, arma alternativa, checkpoint, alavanca, retorno físico ao hub, compra, saída do chefe e reabertura do save.
- `progression_test.gd`: **111 verificações aprovadas**, sem erros de execução — arquivos reais em slots isolados, backup após corrupção, rejeição de schema inválido, compras sem duplicação, inventário/equipamento, flags, checkpoint e eventos de abertura dos portões.
- Menu, jogo, árvore e arena capturados pelo próprio Godot em OpenGL Compatibility na GTX 1060; imagens inspecionadas visualmente.
- Blender executou a verificação do script, criou o modelo e renderizou o atlas transparente de oito direções. Atlas inspecionado; oito quadros sem cortes. A cena independente `scenes/art/senu_preview.tscn` foi importada e executada sem erros no Godot.

A primeira demonstração somou **176 verificações automatizadas**. Os testes usam `user://qa/`; o progresso real não foi usado.

## Expansão do Porto — 25/10/2026

`route_test.gd` foi adaptado ao mapa ampliado e executado no projeto final `D:\Nono_Veu`, com Godot 4.7.2: **121 verificações aprovadas, zero falhas e saída 0**, sem erros de execução na rodada final.

O percurso confirma 1.287 células caminháveis e 13 setores, circula pelo mercado, armazém, ponte, pátio, alcova, embarcadouro, jardim, guarita, arena e entrada das Catacumbas. Verifica os dois atalhos bloqueados pela frente, as alavancas alcançadas pelo lado distante, a remoção das colisões, o retorno físico pelos caminhos abertos, a arma alternativa, o checkpoint, a compra de habilidade, o bloqueio/abertura da saída do chefe e a reabertura do salvamento.

A navegação usa as ações de movimento do jogador e os pontos de passagem do layout; não teleporta Senu pelo percurso. O comando empregou `--time-scale 4` para acelerar a simulação. Inimigos comuns foram removidos por dano de teste e a IA do chefe ficou parada, como na verificação anterior, para isolar a navegação. O save real não foi usado.

O combate foi novamente verificado com o novo personagem: **26/26**. Persistência e progressão: **111/111**, incluindo o estado ampliado. O teste `save_migration_test.gd` aprovou **31/31** casos de migração do save antigo, checkpoint do mercado, arquivo de segurança, relicário opcional e reinício pelo botão real do menu. A rodada atual soma **289 verificações**, todas aprovadas. Os casos do relicário e do menu exercitam os eventos do mundo diretamente; não representam uma partida humana do puzzle.

Capturas reais da versão ampliada foram conferidas em `qa/porto_demo.png`, `qa/porto_demo-cais.png`, `qa/porto_demo-market.png`, `qa/porto_demo-garden.png` e `qa/porto_demo-map.png`. O mapa com treze legendas cabe no painel sem sobreposição. Os arquivos de QA não entram no versionamento.

## Sprites Pixelorama v3 — 25/10/2026

O Pixelorama 1.2.3 abriu o projeto nativo e exportou PNG e JSON em OpenGL Compatibility. O importador do Godot gerou **124 quadros e 75 animações** no recurso `resources/characters/senu_v3_frames.tres`. Os originais das quatro folhas foram preservados. A limpeza de cores foi conferida com pixels de diagnóstico: os resíduos vermelhos, verdes e amarelos ficaram transparentes, enquanto as amostras de tecido verde-petróleo e bronze foram preservadas.

Após integrar a apresentação v3, `combat_test.gd` aprovou **26/26** verificações e `senu_animation_test.gd` aprovou **27/27**, com saída 0. Este último verifica carregamento do atlas, pivô, oito direções, avanço de caminhada e ataque, interrupção por dano, ataque forte, poder, direção comprometida da esquiva, parry, morte com último quadro retido e retorno ao checkpoint. Os testes desta etapa não usam o save real.

O Godot também capturou o personagem no Mercado das Cinzas e uma prancha com nove estados. Os recortes foram revisados para retirar fragmentos de desenhos vizinhos. A caminhada frontal continua com uma pose única, algumas vistas usam espelhamento ou aproximação e as Adagas mantêm a apresentação v2. Esta etapa verifica a integração visual, sem repetir o percurso e os testes de persistência documentados acima.

## Fluidez e Adagas v4 — 25/10/2026

O Pixelorama 1.2.3 exportou o projeto `senu_v4.pxo` com **603 quadros e 145 tags**, gerando um atlas RGBA de **6144 × 14592 pixels**. O Godot importou as duas variantes e gerou `resources/characters/senu_v4_frames.tres`. A validação do conteúdo exportado confirmou 603 quadros visíveis dentro das margens, integridade do projeto nativo, hashes das seis fontes preservadas e **12 imagens diferentes em cada um dos 16 ciclos de caminhada** (duas armas × oito direções).

Na versão final, os testes passaram com saída 0: combate **26/26**, animação anterior **27/27** e integração v4 **40/40**, somando **93 verificações** nesta rodada. Os novos casos exercitam a troca real de arma, a preservação da fase ao virar e trocar, os dois impactos das Adagas sem reiniciar o relógio, recuperação, Passo de Sombra, quadros finais de esquiva/dano/parry e os recursos editáveis de animação. As regras de dano, alcance, velocidade e colisão permaneceram as mesmas.

O próprio Godot capturou os nove estados das Adagas em `qa/senu_adagas_preview.png`, as Adagas no mercado em `qa/porto_demo-daggers.png` e 24 quadros de caminhada em `qa/walk_v4/`, usados para montar `qa/senu_caminhada_v4.gif`. Esses 24 quadros renderizados contêm 12 imagens diferentes, repetindo o ciclo. As capturas foram inspecionadas. Os testes e capturas não usam o progresso real.

As novas fontes das Adagas foram geradas com ImageGen e montadas em quadros nativos do Pixelorama. Os intermediários de caminhada usam deformação de regiões; não são todos desenhos feitos à mão. Algumas ações cardeais usam a diagonal mais próxima. A revisão automática e as capturas não substituem a avaliação humana da sensação de movimento ou do balanceamento.

## Reproduzir os testes

No PowerShell, na pasta do projeto:

```powershell
$demoGodot = "$env:USERPROFILE\Downloads\Godot_v4.7.2-stable_win64_console.exe"
& $demoGodot --headless --path . --editor --import --quit
& $demoGodot --headless --path . --script res://tests/combat_test.gd
& $demoGodot --headless --path . --script res://tests/senu_animation_test.gd
& $demoGodot --headless --path . --script res://tests/senu_v4_animation_test.gd
& $demoGodot --headless --path . --script res://tests/progression_test.gd -- --qa
& $demoGodot --headless --path . --time-scale 4 --script res://tests/route_test.gd -- --qa
& $demoGodot --headless --path . --script res://tests/save_migration_test.gd -- --qa
```

## Limites da verificação

O teste de percurso imobiliza a IA do chefe e remove os inimigos comuns por aplicação de dano para isolar navegação; a derrota do chefe nesse teste também é provocada por dano de teste. A lógica de combate é verificada separadamente. Isso não substitui uma partida humana nem valida o balanceamento final.

Os três nós atuais derivam da base e não possuem dependências entre si; um caso de pré-requisito ausente ainda não existe para ser exercitado. Não foram testados gamepad, campanha completa, arte definitiva ou executável independente. Os modelos de exportação do Godot não foram encontrados nem instalados nesta etapa.

## Mundo: puzzles depois de reabrir o jogo — 27/10/2026

Correções da zona Mundo (Gustavo) em `port_demo.gd`: o altar das estrelas aceita um alinhamento feito antes de fechar e reabrir o jogo, e um toque fora de ordem nos sinos mostra o próprio aviso. O novo `tests/puzzle_reload_test.gd` aprovou **8/8**; sem as correções, falha nos três casos dos bugs. Com Godot 4.7.2: percurso **121/121**, mundo **124/124**, progressão **111/111**, migração **32/32** e abertura **23/23**. Detalhes em `docs/MUNDO_EXPANSAO.md`.

```powershell
& $demoGodot --headless --path . --script res://tests/puzzle_reload_test.gd -- --qa
```

## Galeria do Eco — 27/10/2026

Novo atalho da zona Mundo (Gustavo): das Catacumbas ao santuário, por uma grade erguida pelo lado de trás. Com Godot 4.7.2: percurso **137/137**, agora com a subida física pela galeria, o bloqueio da grade fechada e o retorno ao santuário; mundo **125/125**, incluindo a garantia de que a galeria e as Catacumbas não são alcançadas pelo santuário antes da hora. Também aprovados: progressão **111/111**, migração **32/32**, puzzles **8/8**, navegação **8/8**, fundações **5/5**, cenário **65/65**, HUD **19/19** e abertura **23/23**. Capturas da galeria e do mapa com 29 setores conferidas em `qa/porto_demo-echo.png` e `qa/porto_demo-map.png`.

## Profundidade de portões e prédios — 27/10/2026

Achado jogando: Senu era desenhado atrás da grade do Eco e de armazéns, arcos, barracas, templo e farol, e esses objetos ficavam transparentes, como fantasmas. Correção só na zona Mundo (`port_gate.gd`, `world_prop.gd`, `port_art.gd` e `port_dressing.gd`): os objetos largos são desenhados em fatias de profundidade, e a barraca, o armazém e o farol ganharam base sólida do tamanho do desenho. Quatro muros que flutuavam sobre a água e um pilar dentro de um buraco d'água foram para a borda de pedra mais próxima.

O novo `tests/depth_sort_test.gd` aprovou **134/134**. Ele verifica os 5 portões dos dois lados e as 30 fachadas por todas as faces viradas para a câmera; o teste exige as fatias, então falha no código anterior. Com Godot 4.7.2, já com o merge da `main` que trouxe os retratos de diálogo do Kauã, as 25 suítes passaram, entre elas: percurso **137/137**, mundo **125/125**, cenário **75/75** (eram 65; entraram as barracas e o farol), progressão **111/111**, migração **32/32**, diálogo com retratos **196/196** e inimigos (movimento **28/28**, equilíbrio **56/56**, desempenho **6/6**). As capturas de antes e depois foram conferidas.

Observação: depois de um merge que traz um `class_name` novo, rode `--editor --import --quit` uma vez. Sem isso, o cache de classes do Godot fica velho e os testes da abertura falham com "Could not find type".

```powershell
& $demoGodot --headless --path . --script res://tests/depth_sort_test.gd -- --qa
```

## Trilha de Iri e o pescador — 27/10/2026

Conteúdo opcional da zona Mundo (Gustavo; detalhes em `docs/MUNDO_EXPANSAO.md`): quatro marcas de Iri que abrem um relicário no Santuário, e a missão de Hori e Sabu, do Cais ao Embarcadouro Velho. O novo `tests/side_story_test.gd` aprovou **55/55**. Ele verifica:

- as 7 posições: piso, espaço livre de objetos sólidos e de outras interações, e salas certas;
- o relicário fechado sem as quatro marcas;
- a contagem das marcas, sem contar duas vezes;
- cada passo da missão, incluindo o nome que só volta depois do Porteiro;
- as recompensas, sem repetição;
- o estado depois de reabrir o save.

As capturas dos personagens, das marcas e do relicário foram conferidas.

```powershell
& $demoGodot --headless --path . --script res://tests/side_story_test.gd -- --qa
```

## Balbucio dos diálogos — 27/10/2026

Sons de fala sintetizados para o diálogo com retratos (Gustavo; detalhes em `docs/AUDIO_BALBUCIO.md`). O novo `tests/dialogue_babble_test.gd` aprovou **49/49**. Ele verifica:

- os 32 bancos (2 personagens × 4 expressões × 4 categorias);
- o ritmo de fala;
- que só o falante soa;
- que o texto revelado com Enter não muda o som;
- que avançar a fala silencia;
- a sílaba final, que sobe só nas perguntas, nas 24 falas aprovadas;
- a ligação na abertura com o jogo pausado;
- o bus `Vozes`, único e ligado ao `Master`.

Com Godot 4.7.2, depois da ligação na abertura, também passaram: abertura RPG **64/64**, fluxo da abertura **23/23** e diálogo com retratos **196/196**. O teste não ouve o som. Uma prévia mixada a partir das sílabas que o jogo escolhe foi conferida por volume e espectrograma, mas não substitui ouvir no jogo.

```powershell
& $demoGodot --headless --path . --script res://tests/dialogue_babble_test.gd
```

## Economia de combate: XP e óbolos — 27/10/2026

Gustavo: os inimigos deixam orbes de XP e moedas (óbolos). Regras em `scripts/economy/economy.gd`, queda no chão em `scripts/world/loot_drop.gd`, ganchos curtos em `port_demo.gd`, campos `xp` e `coins` no save e painel do HUD com nível, barra de XP e moedas. Plano das casas e lojas em [MUNDO_CASAS_LOJAS.md](MUNDO_CASAS_LOJAS.md).

O novo `tests/loot_economy_test.gd` aprovou **43/43** com Godot 4.7.2: curva de nível, bônus, divisão das moedas e orbes, recusa de preço acima do saldo ou negativo, tetos, balanço do Porto inteiro (38 inimigos: 526 XP, nível 6, 274 óbolos), save e migração de saves sem os campos novos, valores inválidos rejeitados e, no mundo real, o marinheiro do cais derrubando XP e moedas que só contam ao tocar Senu, salvas em seguida, sem pagar duas vezes, com subida de nível aplicando vida e dano.

`route_test.gd` deixou de exigir dano exato 4 após comprar *Mão firme*: o XP recolhido no caminho já soma dano de nível. Agora o teste confere o acréscimo de +4. Também passaram: percurso **137/137**, progressão **111/111**, migração **32/32**, HUD **19/19**, combate **26/26**, puzzles **8/8**, mundo **125/125**, cenário **75/75** e equilíbrio dos inimigos **56/56**. As capturas `qa/porto_demo-market.png` e `qa/porto_demo-caravan.png` mostram o painel novo.

```powershell
& $demoGodot --headless --path . --time-scale 4 --script res://tests/loot_economy_test.gd -- --qa
```

## Impacto nos golpes, sons de combate e água viva — 27/10/2026

Gustavo: hitstop, tremor, clarão e faíscas nos golpes; 48 sons sintetizados (golpes, parry, dano, avisos dos inimigos, peixes, mar, moeda); cardumes, saltos e brilhos na água. Detalhes em [COMBATE_IMPACTO_AGUA.md](COMBATE_IMPACTO_AGUA.md).

O novo `tests/combat_fx_test.gd` aprovou **100/100** com Godot 4.7.2 (cinco rodadas seguidas, porque a água é aleatória). Na mesma pasta, com as mudanças das outras sessões, as **29 suítes** de `tests/` passaram com saída 0 e sem erro de script: **1.787 verificações** no total. Entre elas: combate 26/26, percurso 137/137, mundo 125/125, profundidade 134/134, cenário 75/75 e espada v8 118/118. Os testes não ouvem o som; o visual foi conferido em capturas do Godot (`qa/fx_*.png`).

```powershell
& $demoGodot --headless --path . --script res://tests/combat_fx_test.gd
```

Depois, para as casas: os bancos `door_open` e `chest_open` (4 sons novos, 52 no total) e a regra de que fora do mar desenhado (`PortLayout.SEA_RECT`) não há água nem som do mar. `combat_fx_test.gd` passou a **108/108**. Com os sons ligados, os testes das casas e lojas seguiram verdes: casas 54/54, arte dos interiores 13/13, têmperas 37/37 e méritos 47/47; mundo 125/125.

## Casas, fase 1: Casa da Guarda — 27/10/2026

Gustavo: porta diante do armazém da Guarita do Retorno, escurecimento, Casa da Guarda (sala 6 × 5 além do mar, em x ≥ 4400 px) com baú de 30 óbolos e bilhete. Código em `scripts/world/house_catalog.gd`, `house_interior.gd` e `houses.gd`, com 3 ganchos curtos em `port_demo.gd` e 2 no HUD. Plano em [MUNDO_CASAS_LOJAS.md](MUNDO_CASAS_LOJAS.md).

O novo `tests/house_interior_test.gd` aprovou **30/30**: a porta fica fora das fachadas sólidas e a mais de 40 px de outras interações; a sala não divide tile com o Porto; entrar e sair escurecem a tela, ignoram um segundo toque e não curam Senu; a câmera fica parada no centro da sala; os setores visitados não mudam; as paredes seguram Senu correndo nas quatro direções; nenhum inimigo entra; o baú paga uma vez e salva junto com as moedas; o bilhete abre o próprio texto; o mapa marca Senu na porta. Não cobre o baú aberto depois de reabrir o jogo.

Também passaram, com Godot 4.7.2: percurso **137/137**, mundo **125/125**, cenário **75/75**, profundidade **134/134**, história paralela **55/55**, HUD **19/19**, progressão **111/111**, migração **32/32**, economia **43/43**, viewport **9/9**, puzzles **8/8** e combate **26/26**. Capturas conferidas em `qa/casa_guarda_dentro.png` e `qa/casa_guarda_fora.png`.

```powershell
& $demoGodot --headless --path . --time-scale 4 --script res://tests/house_interior_test.gd -- --qa
```

## Casas, fase 2: Empório de Merit — 27/10/2026

Gustavo: Empório de Merit no armazém (30, −0.25) do Armazém das Vozes, painel de loja (`scripts/ui/shop_panel.gd`), regras em `scripts/economy/shop_catalog.gd`, campos `purchases` e `items` no save, tecla **R** (`use_item`) para o bálsamo e recarga ao meditar.

O novo `tests/shop_merit_test.gd` aprovou **47/47**: compras recusadas sem saldo, sem pré-requisito, além do limite e de item desconhecido; jarro novo vem cheio; mirra soma 15 à cura; compras e cargas sobrevivem ao recarregar e saves antigos abrem sem compras; 7 estados adulterados são recusados; no mundo real, a Merit é a interação mais próxima no balcão, o painel pausa o jogo, os botões de verdade compram e salvam na hora, "Esgotado" aparece, a tecla R cura 55, jarro vazio não cura, o santuário do Mercado recarrega e vida cheia não gasta carga. `house_interior_test.gd` passou a conferir as portas das duas casas: **38/38**.

Também passaram, com Godot 4.7.2: economia **43/43**, percurso **137/137**, mundo **125/125**, cenário **75/75**, profundidade **134/134**, história paralela **55/55**, HUD **19/19**, progressão **111/111**, migração **32/32**, viewport **9/9**, puzzles **8/8** e combate **26/26**. Capturas conferidas em `qa/loja_merit_painel.png` e `qa/loja_merit_dentro.png`.

```powershell
& $demoGodot --headless --path . --time-scale 4 --script res://tests/shop_merit_test.gd -- --qa
```

## Casas, fase 3: Forja de Nakht e Tenda de Adiam — 27/10/2026

Gustavo: Forja de Nakht nos Fornos do Bronze (pedra de amolar, têmpera do Khopesh, têmpera das Adagas) e Tenda de Adiam no Portão das Caravanas (mapa das rotas, amuleto de cornalina, sandálias de caravana). O dano por arma entra pelo `_apply_upgrades` do `port_demo.gd`, sem mexer no `player.gd`; o HUD desenha o contorno dos setores não visitados quando Senu tem o mapa.

O novo `tests/shop_forge_tent_test.gd` aprovou **37/37**: pré-requisitos das têmperas, pedra valendo para as duas armas e cada têmpera só para a sua, +10 de vida, esquiva 15% mais rápida, mapa das rotas, cada item pago uma vez e salvo; no mundo real, os botões aplicam o dano na hora, trocar de arma troca o bônus, uma jornada reaberta com as Adagas já começa com o bônus delas e o mapa abre com os contornos. `house_interior_test.gd` passou a conferir as 4 casas: **52/52**.

Também passaram, com Godot 4.7.2: loja da Merit **47/47**, economia **43/43**, percurso **137/137**, mundo **125/125**, cenário **75/75**, profundidade **134/134**, história paralela **55/55**, HUD **19/19**, progressão **111/111**, migração **32/32**, viewport **9/9**, puzzles **8/8**, combate **26/26** e efeitos de combate **100/100**. Capturas conferidas em `qa/loja_nakht_dentro.png`, `qa/loja_nakht_painel.png`, `qa/loja_adiam_dentro.png`, `qa/loja_adiam_painel.png` e `qa/mapa_rotas.png`.

```powershell
& $demoGodot --headless --path . --time-scale 4 --script res://tests/shop_forge_tent_test.gd -- --qa
```

## Casas, fase 4: arte dos interiores em Pixelorama — 27/10/2026

Gustavo: móveis e lojistas das quatro casas em `art/pixelorama/interiors_v1/interiors_v1.pxo` (30 quadros de 128 × 144, paleta do Porto v7), gerado por `tools/pixelorama/build_interiors_v1.gd` e exportado pelo próprio Pixelorama 1.2.3 com `EXPORTAR_INTERIORES.cmd`. O jogo lê a folha por `scripts/world/interior_art.gd`; balcão, prateleiras, forno, armeiro, cordões e baú de troca são desenhados em fatias de profundidade.

O novo `tests/interiors_art_test.gd` aprovou **13/13**: formato 7 com uma tag por peça, cada cel com largura × altura × 4 bytes, folha exportada pelo Pixelorama idêntica ao projeto nativo pixel a pixel, só as 33 cores da paleta do Porto com alfa binário, arte para todo móvel das casas e animação dos lojistas, do forno e do carvão. `house_interior_test.gd` passou a **54/54**: Senu atrás do balcão e do baú de troca fica coberto em todo o comprimento, e na frente não.

Também passaram, com Godot 4.7.2: loja da Merit **47/47**, Forja e Tenda **37/37**, economia **43/43**, percurso **137/137**, mundo **125/125**, cenário **75/75**, profundidade **134/134**, história paralela **55/55**, HUD **19/19**, progressão **111/111**, migração **32/32**, viewport **9/9**, puzzles **8/8**, combate **26/26** e efeitos de combate **100/100**. Capturas das quatro salas conferidas em `qa/`.

Achado: `Start-Process` do PowerShell 5.1 não põe aspas nos argumentos. Na pasta `A:\nono veu`, com espaço, o Pixelorama nem abria. `export_interiors_v1.ps1` já passa os caminhos entre aspas; os outros `export_*.ps1` ainda têm o defeito.

```powershell
& $demoGodot --headless --path . --script res://tests/interiors_art_test.gd
```
# NPCs e interiores v2 — 28/10/2026

Conferência final no Godot 4.7.2 com `--qa`, separada do progresso normal:

- Arte dos interiores: 19/19, incluindo correspondência entre o Pixelorama e o atlas final de 45 quadros.
- Missões dos NPCs: 70/70, incluindo estados antigos, coleta antecipada, reencontro dos irmãos e recompensas únicas.
- Empório: 47/47; forja e tenda: 37/37.
- Efeitos de combate: 108/108; economia e coleta: 43/43.

Os testes de empório, combate e economia ainda relatam recursos em uso ao encerrar a execução de teste; as verificações funcionais passaram. Capturas dos quatro interiores e do caderno ficam em `qa/npc_v2_*.png`. A gravação de referência da morte e moedas fica em `art/animation_reference/death_loot.gif`.

## Tela preta em "Nova jornada" — 27/10/2026

Gustavo (relato de quem jogou pelo `JOGAR.cmd`): o menu abria, mas "Nova jornada" deixava a tela preta. Reproduzido num clone com o cache de classes do Godot desatualizado (`.godot/global_script_class_cache.cfg` sem a `VeilDialogueBabble` de hoje). A abertura não compilava (`Could not find type "VeilDialogueBabble"`), e `_play_opening` já tinha escondido o mundo e o HUD. Rodado direto, sem o editor, o Godot não atualiza esse cache nem as importações; o clone limpo, sem `.godot`, nem chega ao menu.

Correções:
- `JOGAR.cmd`: fica a versão do Kauã (commit `78bd2a9`), que roda `--headless --editor --import --quit` antes de toda partida e grava o resultado em `qa/startup_import.log`. Ao juntar a `main` na `gustavo/dev`, ganhou só a busca dos dois executáveis do Godot (normal e console) também em `A:\Ferramentas\godot`, onde eles ficam no PC do Gustavo. A primeira versão do Gustavo, que só reimportava quando o commit mudava, foi descartada.
- `port_demo.gd`: se o script da abertura não compila, o jogo segue sem ela, com erro no log, em vez de travar. Conferido no clone: com o cache estragado, o jogo vai ao Santuário.

Depois da junção, uma cópia do `JOGAR.cmd` que não abre o jogo achou o Godot em `A:\Ferramentas`, importou em 11 s, e o cache passou a ter a nova `MercuryProjectile`. Com a `main` e essas mudanças juntas passaram:
- abertura: fluxo **23/23** e RPG **64/64**;
- casas e lojas: casas **54/54**, arte dos interiores **13/13**, Empório **47/47**, Forja e Tenda **37/37**;
- inimigos e habilidades: loot **43/43**, renascimento **58/58**, habilidades no mundo **63/63**, árvore na interface **406/406**;
- base: HUD **19/19**, migração **32/32**, progressão **123/123** e percurso **137/137**.

## Barco de Sabu e Ilha do Bennu — 27/10/2026

Pedido do Gustavo: navegação, um barco com animações e uma ilha para explorar, com missões. O plano e os arquivos estão em [MUNDO_BARCO_ILHA.md](MUNDO_BARCO_ILHA.md). Godot 4.7.2, slots `user://qa/`:

| Suíte | Resultado | O que verifica |
|---|---:|---|
| `boat_test.gd -- --qa` | 56/56 | Píeres em terra e amarrações na água, embarque com salto, remada com inércia e curva, câmera e esteira, costa sólida, ânfora paga uma vez, travessia remando até o píer do Bennu (~7 s), atracação, e o barco voltando ao píer do lado do último santuário. |
| `isle_test.gd -- --qa` | 58/58 | 273 tiles de chão, todos alcançáveis a pé a partir do píer e separados do porto pela água; vegetação sobre a terra sem tampar as peças; garças na água; Ankhet e os 3 Esquecidos (a vitória sobrevive ao renascimento), as três chamas na ordem, o altar com a Pena do Bennu, a rede de Hori, o save que volta a carregar e o contorno da ilha no mapa. |

Capturas com janela (`--capture-boat`, `--capture-isle`): `qa/barco_pier.png`, `qa/barco_remando.png`, `qa/barco_ilha.png`, `qa/ilha_bennu.png` e `qa/ilha_mapa.png`. Na janela recém-aberta, a suavização da câmera passava do ponto depois de um teleporte; o teste agora chama `reset_smoothing()`, como o jogo já faz.

Regressões com tudo junto:
- todas passaram: ilha **58/58**, barco **56/56**, histórias do porto **55/55**, casas **54/54**, Empório **47/47**, Forja e Tenda **37/37**, loot **43/43**, renascimento **58/58**, catálogo de habilidades **47/47**, habilidades no mundo **63/63**, HUD **19/19**, progressão **123/123**, migração **32/32**, fluxo da abertura **23/23**, navegação **8/8**, chão do mapa **1488/1488**, mundo **128/128** e percurso **138/138**.
- No meio do trabalho, o mundo e o percurso chegaram a falhar no altar das estrelas e no santuário s1, que ganharam colisão no trabalho da sessão do Mundo. Ela ajustou o caminho dos testes até a frente desses objetos.

Correções feitas durante o trabalho:
- a flag `sea_route` entrou no save novo, porque o carregamento completa as flags opcionais e a ida e a volta deixavam de bater;
- o HUD lê `at_sea` sem `bool(null)`.

## Colisão, chão e passagens das construções — 27/10/2026

Achado jogando: Senu atravessava muros, braseiros e os objetos dos puzzles; pilares e caixotes o deixavam entrar pela metade de trás; algumas peças pareciam flutuar; e o gerador de bairros punha construções na boca das passagens. Correção da zona Mundo (`port_art.gd`, `world_prop.gd`, `interactable.gd` e `port_dressing.gd`; detalhes nos bugs 8 e 9 de `docs/MUNDO_EXPANSAO.md`). A base de cada desenho é medida na arte e vira colisão e sombra; só juncos e barcos são atravessáveis; o gerador valida chão, sobreposição, marcadores e bocas de passagem antes de pôr cada peça.

O novo `tests/map_ground_test.gd` aprovou **1488/1488**. Ele anda pelo Porto inteiro com o corpo de 6 px do Senu, num reticulado de 1/4 de tile, com todos os portões abertos. Confere que:
- toda peça e todo objeto interativo sólido tem a base inteira sobre a pedra e a colisão cobre a base pintada, sem parede invisível na frente;
- nenhuma base encosta em outra;
- as peças geradas ficam fora da boca das passagens;
- toda sala é alcançável, cada passagem tem pelo menos 45% livre, a rota principal passa e dá para parar na frente de cada objeto interativo;
- nenhum trecho de chão livre fica isolado.

O que nem sem cenário se alcança a pé (interiores das casas e a ilha, só por mar) fica fora da cobrança. O teste pega de volta um muro sobre a água, uma sobreposição e muros sem colisão.

Dois testes de percurso foram ajustados, porque mandavam o Senu pisar no ponto exato de objetos que agora são sólidos. No `route_test`, o Senu contorna o santuário da Guarita e para na frente dele. No `world_v6_test`, o `use_item` vai até a frente do objeto, e o mapa de caminhos do teste desvia dos objetos sólidos.

Resultados: percurso **138/138**, mundo **128/128**, cenário **529/529**, profundidade **260/260** e história paralela **55/55**. As 41 suítes passaram com Godot 4.7.2, já com o barco e a ilha da sessão de XP na pasta.

```powershell
& $demoGodot --headless --path . --script res://tests/map_ground_test.gd -- --qa
```

## Fluidez do mar e navios ancorados — 27/10/2026

Medido com o jogo em janela, num monitor de 165 Hz, remando em linha reta. Antes: 60 quadros por segundo com o limite ligado por padrão, cada quadro durando 2 ou 3 atualizações da tela, alternando. Depois: 165 quadros e 165 passos de física (um por quadro desenhado); a tela rola 0 ou 1 px por quadro, em ritmo regular, e o barco fica parado no centro. Detalhes em [MUNDO_BARCO_ILHA.md](MUNDO_BARCO_ILHA.md), seção "Fluidez".

`boat_test.gd -- --qa`: **62/62**. Novos itens:
- a física segue o monitor sem o limite (165 → 165, 144 → 144, 59,94 → 60);
- o limite, monitores desconhecidos e monitores muito rápidos ficam entre 60 e 240;
- o limite vem desligado;
- todo navio ancorado recebe a linha d'água e os anéis;
- a quilha é a reta pelo meio do casco, não pelas pontas;
- a folha tem 8 quadros de remada, todos vistos ao remar.

Capturas de antes e depois no Cais dos Esquecidos: o casco agora entra na água, com espuma, e a sombra de chão sumiu.

Regressões: ilha **58/58**, HUD **19/19**, mundo **128/128** e efeitos de combate **108/108**. Nenhum código de movimento conta passos de física sem usar o tempo.

## A vida no Porto — 27/10/2026

Moradores, bancadas e navios mercantes (zona Mundo; detalhes em `docs/MUNDO_VIDA.md`). O novo `tests/port_life_test.gd` aprovou **250/250**. Confere que:
- cada bancada tem vendedor junto da barraca;
- toda parada de rotina fica em chão livre e fora da boca das passagens;
- o caminho entre paradas passa longe do cenário;
- quem compra para ao alcance do vendedor;
- em 4 minutos simulados cada morador cumpre a rotina inteira, inclusive os estivadores, que esperam o navio;
- os dois navios fazem o ciclo completo (chegar, atracar na vaga, recuar quando é o caso, partir e voltar), só pela água e com a proa para a frente;
- comprar cobra o preço e cura, e não cobra com a vida cheia ou sem óbolos;
- falar abre o diálogo e avança a fala;
- o Senu esbarra nos moradores, a espada não os acerta, e o morador dá um passo para o lado quando o Senu encosta;
- longe do Senu, a rotina pausa.

Os testes de percurso (`route_test` **138/138** e `world_v6_test` **128/128**) passam com os moradores andando. O `map_ground_test` (**1489/1489**) deixou de cobrar "parar na frente" de quem anda. As 42 suítes passaram com Godot 4.7.2.

```powershell
& $demoGodot --headless --path . --time-scale 4 --script res://tests/port_life_test.gd -- --qa
```
