# Estado atual — O Nono Véu
Atualizado em 2026-10-29; base: versão principal `D:\Nono_Veu`.

## Funcionalidades existentes
- Demo do Porto dos Esquecidos: exploração isométrica, setores conectados, atalhos, três puzzles de selos, chefe e entrada demonstrativa das Catacumbas.
- Senu: oito direções, caminhada/corrida, esquiva, ataques leves/fortes, parry, riposta; Khopesh e Adagas com sprites compartilhados e poderes próprios.
- Inimigos animados, combate com efeitos/sons, XP, níveis, óbolos e coleta física de drops; 13 habilidades na Árvore das Emanações.
- Água animada, moradores, comércio, quatro interiores e NPCs com poses; móveis v4 com bases/colisões/sombras alinhadas ao piso.
- Missão de Hori/Sabu concluível sem chefe; missões de Merit, Nakht, Adiam e Tarek; marcas de Iri, barco navegável e Ilha do Bennu com conteúdo próprio.
- Nova jornada preserva encenação no cais e retratos pixelados; Espaço por 3 s pula a abertura. Conversas na exploração usam balões no falante, com até quatro linhas por trecho.
- HUD minimalista sem objetivos fixos; caderno com jornada principal e pedidos secundários, mapa descoberto, inventário, habilidades, configurações e saída.
- Controles dentro de Configurações; aprender habilidade exige segurar 1,5 s, com cancelamento e cobrança única.
- Somente torres salvam, restauram vida/cargas e renovam inimigos comuns; chefes vencidos permanecem no estado salvo. Sair/fechar não grava.

## Últimas entregas — Senu no barco, NPCs e interface
- Casco v4: comprimento-base 74 (antes 50), boca 28 (antes 17), madeira escura com veios, emendas, pregos e amarras inspirados no navio do porto; bancos e interior mais espaçosos. Senu v3 e remos preservados, sem mudar física/navegação. Fonte em `art/pixelorama/sea_v4/`; canvas/pivô maiores são apenas margens, sem escala do personagem.
- Embarque/desembarque: seis poses por ação em oito vistas, sem loop; pivô físico no chão, altura só no desenho. Pausa congela o movimento; reaparecer limpa o sprite e restaura controles/colisões nos dois píeres. Sem alterar navegação ou salvamento.
- NPCs v3: reimaginadas as 12 aparências de moradores/vendedores e Ankhet no estilo detalhado dos nomeados, com 196 poses completas (PNG+JSON e `.pxo` em `art/pixelorama/npcs_v3/`). Pés/pernas estáveis no repouso, corpo de ~44 px e margens para gestos/cargas; colisões, rotinas, IDs e seis nomeados v4 preservados. Remador magro, cabelo curto e sem barba, distinto do ferreiro. QA: sprites 2468/2468, anteriores 286/286, rotinas 250/250 e ilha 59/59; seis capturas reais, pranchas/GIF em `qa/npcs_v3/`. Fontes/prompts preservados; teste de arte emite avisos de leitura de PNG bruto, sem falhas.
- QA do casco v4: preservação/tamanho 482/482 (160 cels do corpo e 320 dos remos idênticos no mundo), atlas 683/683 e barco gráfico 62/62; importação sem erros. Pranchas/GIF/comparação em `qa/boat_hull/`. Base anterior: remos 700/700, transições 85/85, NPCs 286/286, rotinas 250/250 e ilha 59/59. PNG+JSON exportados pelo Pixelorama, `.pxo` em cinco camadas.
- Menu inicial tem seleção procedural em pixels; cliques em todos os botões da interface usam brilho curto e o toque aprovado, com pequenas variações por tela. Som continua durante pausa/troca de página; opções desabilitadas ficam silenciosas. QA: áudio/animação 592/592, menu 25/25; HUD 20/20, inventário 26/26, habilidades 13/13 + integração 16/16 e layout 7968/7968. Prévia em `qa/title_menu/`.
- Interface usa Pixel Operator HB/Bold incluída no projeto (licença CC0 em `assets/fonts/`), com acentos e traços nítidos; balões, HUD, abertura e menus compartilham `ui_typography.gd`.
- História/Estilo de Combate fluem pela altura real e têm rolagem antes dos botões; foco da lista de missões mantém o título inteiro visível. Fonte Pixelify descartada.
- QA atual: layout 7968/7968 (540p/720p, texto ampliado e rolagem), caderno 21/21, navegação 16/16, missões 39/39, HUD 20/20, balões 57/57 e abertura com bustos 196/196; 72 glifos acentuados/números conferidos. Capturas em `qa/pixel_font/`.
- Bustos: ombros estáveis, olhos/boca independentes, respiração e cabeça com entrada/retorno suaves; atlas e ritmo preservados. QA: integração 196/196, sílabas 49/49, movimento 7/7; 150 quadros em `qa/portrait_motion/`, incluindo piscadas na fala. Avisos preexistentes de recursos retidos em integração/áudio.
- Atores: respiração de 1 px, contrapasso, peso no tronco e impactos visuais de até 2 px; base/sombra, regras de combate e física preservadas. Passadas de Senu seguem distância real após colisão, param na parede e conservam fase ao virar/trocar arma.
- `actor_pixel_motion.gd` usa faixas nearest e base fixa, com equipamento nas mãos; abertura/caderno compartilham o contrato. Godot 4.7.2 importou; pranchas de Senu/Adagas/cinco inimigos e cais real em `qa/actor_motion/`.
- QA: movimento procedural 48/48; Senu base 27/27, v4 40/40, v5 74/74, v6 58/58 e Khopesh v8 118/118; combate 26/26 e habilidades de combate 44/44.
- QA: inimigos movimento 28/28, equilíbrio 56/56 e desempenho 7/7; profundidade 260/260, efeitos 108/108, loot 45/45, caderno 21/21 e abertura 24/24.
- Interface anterior preservada: caderno revisado, N/M/Esc e abas funcionais, balões seguem os falantes (`qa/notebook_v8_*.png`, `qa/speech_*.png`).
- Algumas suítes mantêm avisos de recursos retidos ao encerrar. Mundo executado somente com `-- --qa` e slots `user://qa/`; nenhum progresso real usado. Sem commit/push/merge.

## Pendências
- Revalidar o bloqueio na subida da Galeria do Eco: último registro de `route_test.gd` teve 108/109 verificações; causa ainda não confirmada.
- Conferir com o jogador o conforto de leitura dos balões e do caderno; apoios dos móveis não foram revalidados nesta tarefa.
- README e registros antigos ainda contêm regras superadas de autosave e saída; usar as decisões atuais até uma revisão documental específica.
- Campanha completa, arsenal completo, relíquias, gamepad e exportação independente não estão entregues; o GDD descreve também planos futuros.

## Próximos passos
1. Reproduzir a falha da Galeria em QA antes de propor qualquer correção de navegação.
2. Avaliar com o jogador a sutileza das animações e o conforto da interface, preservando salvamento apenas nas torres.
