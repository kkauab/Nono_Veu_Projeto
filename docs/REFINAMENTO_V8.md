# Refinamento do porto, interface e combate

Atualizado em 27/10/2026. Este documento consolida as revisões atuais; as versões anteriores permanecem como histórico.

## Interface e menus

O mundo usa um SubViewport de 640×360, enquanto a interface renderiza em 1280×720, com fontes rasterizadas no tamanho final. Assim, a arte conserva seus pixels e o texto continua nítido. A câmera, os cliques do mouse e os indicadores de interação usam a conversão entre essas duas superfícies. A separação segue o recurso de [SubViewportContainer do Godot](https://docs.godotengine.org/en/stable/classes/class_subviewportcontainer.html).

O HUD é compacto: alturas lógicas de 76 para vida, 112 para objetivo e 70 para arma, reduzidas de 102/166/93. Dados usam fonte sans legível e fundo de maior contraste. Nomes de áreas, objetivos e mensagens aceitam até duas linhas. Capturas foram verificadas em 720p e 1080p.

O menu inicial tem água, reflexos, capa e faixa animados. O retrato da pausa pisca e movimenta a faixa com 12 cels independentes, preservando rosto e proporções. Fonte editável em `art/pixelorama/menu_v8/senu_menu_idle_v8.pxo`; atalhos `ABRIR_MENU_PIXELORAMA.cmd` e `EXPORTAR_MENU.cmd`.

## Proporções e resistência

Senu mede aproximadamente 38 pixels no mundo. A escala dos inimigos foi ajustada em relação a ele, com anatomia constante durante a animação:

| Tipo | Altura aproximada | Vida | Contatos leves de espada sem melhorias para derrotar |
|---|---:|---:|---:|
| Corredor | 40 px | 85 | 4 |
| Guarda | 44 px | 110 | 5 |
| Lanceiro | 46 px | 135 | 6 |
| Guardião | 46 px | 160 | 7 |
| Chefe | 62 px | 400 | 18 |

Esses contatos incluem a cadência real do combo. Colisão cobre os pés, com raio 6 nos comuns e 10 no chefe. O teste de resistência executa golpes, recuperação, derrota e restauração reais: 56/56. O ajuste de tamanho v9 foi mantido; os novos movimentos ficam em `art/pixelorama/enemies_v12/`, com atlas `assets/sprites/port_enemies_v12.png`.

Cada tipo recebeu oito poses de caminhada e cinco fases de ataque, além de descanso e recuo. Os passos usam a distância que o corpo realmente percorreu depois da colisão; ficar parado ou bloqueado não faz os pés dançarem. A arma acompanha a preparação, o contato do dano e a recuperação existentes. O tamanho do desenho permanece constante. Dois quadros do guarda receberam retoque nativo do tronco e da junção da coxa para reduzir a oscilação da cabeça a dois pixels, mantendo os apoios das botas. Detalhes em [INIMIGOS_MOVIMENTO_V12.md](INIMIGOS_MOVIMENTO_V12.md); fontes, prompts e exportação em [enemies_v12/README.md](../art/pixelorama/enemies_v12/README.md).

## Espada

O corte tem seis fases: guarda, antecipação, aceleração, contato, continuação e retorno. São cinco vistas próprias e três espelhos, com um total de 48 cels. A vista frontal foi corrigida para cortar à frente sem virar para sudeste. A mesma escala é aplicada a todas as fases; punho e lâmina são desenhados juntos.

O golpe leve acerta em 0,12 s, o pesado em 0,24 s. As adagas mantêm seus contatos em 0,075/0,17 s. Dano e velocidade de Senu foram preservados. Detalhes em [SENU_ESPADA_V8.md](SENU_ESPADA_V8.md), com fonte editável `art/pixelorama/senu/senu_sword_v8.pxo` e prompts em `art/pixelorama/senu/SENU_SWORD_V8_PROMPT.md`. As novas poses foram criadas com ImageGen integrado e exportadas pelo Pixelorama instalado.

## Cenário e navegação

Arcos receberam patamares reais e bases independentes, com o vão central livre. Fachadas foram recuadas para que todos os cantos se apoiem no piso; sua colisão segue a fundação desenhada. Cargas e bancas imediatamente duplicadas foram retiradas. O mapa conserva 27 setores e agora tem 4.350 pisos.

A navegação considera as mesmas fundações, com um índice espacial criado uma vez por mundo. Pontos e trechos atravessando construções ficam fora dos caminhos. O teste físico de perseguição comprovou que um inimigo contorna um armazém e alcança Senu sem atravessar a parede, reaproveitando o grafo.

Verificações: apoios 65/65, rota original 121/121, mundo e puzzles 124/124 em 9.445 passos físicos, navegação 8/8 e perseguição da fundação 5/5. Detalhes em [CENARIO_APOIOS_V8.md](CENARIO_APOIOS_V8.md).

## Abertura de RPG

A abertura atual é encenada em um cais próprio, com Senu, um pescador, desembarque, câmera e24 falas aprovadas pelo autor. O pescador recebe a corda antes de Senu descer da barca. O personagem no mundo conserva oito poses e corpo de 40 px, com lenço, túnica, rede e cesto. Fonte `art/pixelorama/fisherman_v13/fisherman.pxo`, prompt preservado na mesma pasta e PNG exportado pelo Pixelorama em `assets/cinematics/rpg_v12/fisherman.png`.

A conversa usa o componente reutilizável `scripts/ui/portrait_dialogue.gd`: Senu à esquerda, pescador à direita e caixa inferior, com moldura escura, bronze e selos geométricos. Os bustos ficam recortados diretamente sobre o cenário, sem cards, fundos ou bordas individuais. Somente o personagem da vez anima; o ouvinte mantém pose e expressão imóveis. As novas folhas `dialogue_v15` têm 20 retratos completos por personagem, com quatro expressões, repouso, aberturas de boca e duas fases da piscada. A atuação tem ritmo próprio e pausas, independente da digitação. A revelação instantânea do texto mantém a atuação; avançar encerra a fala. A arte foi criada como novas poses completas e exportada pelo Pixelorama. API e dados em [SISTEMA_DIALOGO_RETRATOS.md](SISTEMA_DIALOGO_RETRATOS.md).

A barca ganhou casco isométrico com profundidade, bancos, rede, corda e remo guardado. Fundo e bordo frontal ficam em camadas diferentes para que Senu apareça dentro da embarcação. A passarela agora alcança a margem física do piso, e o desembarque percorre o casco, a passarela e o cais. Fonte editável de cinco camadas em `art/pixelorama/opening_boat_v12/arrival_boat.pxo`; terreno, lamparinas e placa conservam o atlas original do cais. Os atalhos `ABRIR_PESCADOR_PIXELORAMA.cmd`, `ABRIR_BARCO_PIXELORAMA.cmd` e `EXPORTAR_ABERTURA.cmd` abrem e exportam as fontes atuais.

Cada nova jornada inicia a abertura automaticamente. Enter, E ou clique na caixa revela a fala e depois avança; o tempo de leitura pertence ao jogador. Somente manter Espaço pressionado por três segundos contínuos pula a cena. Soltar a tecla ou perder foco cancela o progresso; Escape não pula. Não há uma opção separada para ativar a abertura.

O contexto apresenta Alexandria, o Porto dos Esquecidos, a Inversão e a busca de Senu por Iri. O pescador relata apenas o que viu: um homem carregando livros embrulhados seguiu para os armazéns. O irmão do pescador perguntou quanto custava uma rede que ele próprio ensinou a fazer. Senu segue a pista com a promessa de voltar com o que descobrir. A guarita e a inscrição de Iri continuam descobertas da exploração. O jogador real permanece parado e protegido enquanto a encenação roda; controles, HUD e mundo são restaurados juntos.

O teste pelo botão Novo Jogo aprovou 23/23 verificações, incluindo24 falas, interação, manutenção contínua da tecla Espaço, segunda nova jornada e conclusão natural. O componente aprovou 64/64. A integração adicional verifica retratos, boca independente da escrita, pausas, piscadas, expressões, clique, leitura 720p/1080p e restauração do jogador. Movimento dos inimigos: 28/28; combate: 26/26; resistência: 56/56; navegação: 8/8; desenho em repouso: 6/6. Os resultados anteriores da migração (32/32), HUD (19/19), espada (118/118), compatibilidade (97/97) e padronização (58/58) continuam registrados.

Prévias atuais: `qa/portrait_dialogue_v15_preview.gif` e `qa/enemy_motion_v12_preview.gif`. A prévia da conversa mostra os bustos e a atuação natural; a dos inimigos compara os quatro tipos com Senu na mesma escala e mostra os passos e golpes na cadência do jogo. A filmagem antiga de seis falas fica como histórico.

Os testes usam somente `user://qa/`. O progresso real não foi apagado. Reabra `JOGAR.cmd` para carregar os arquivos atuais.

