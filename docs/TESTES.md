# Verificações do protótipo

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
