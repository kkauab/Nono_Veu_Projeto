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
