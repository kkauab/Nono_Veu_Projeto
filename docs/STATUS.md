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

## Última entrega — fluidez dos atores
- Sprites atuais de Senu/Khopesh/Adagas e inimigos combinados com respiração de 1 px, contrapasso e transferência de peso no tronco; pés e sombras permanecem no chão.
- Senu marca as passadas pela distância real após colisão: parede interrompe os passos, corrida acelera o ciclo e troca de direção/arma conserva a fase de apoio.
- Impactos guardam a direção da origem; preparação, impulso e recuperação usam deslocamentos visuais de até 2 px, sem mudar dano, janelas, equilíbrio, IA ou movimento físico.
- `actor_pixel_motion.gd` desenha faixas com nearest e base fixa; equipamento acompanha as mãos. A abertura encenada e a prévia no caderno usam o mesmo contrato visual.
- Godot 4.7.2: importação aprovada; pranchas de oito direções, Adagas e cinco tipos de inimigo, mais sequência real no cais em `qa/actor_motion/`.
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
