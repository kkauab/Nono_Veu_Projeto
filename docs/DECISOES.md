# O Nono Véu — decisões da primeira demo

Data: 24/10/2026. Fonte principal: `docs/O_NONO_VEU_GDD.md`, versão 1.1, lida integralmente. Este registro define a implementação inicial; não transforma propostas narrativas ou de balanceamento em requisitos definitivos.

## Escopo

A primeira entrega é uma demo de **A01 — Porto dos Esquecidos** com retorno físico ao **Santuário da Primeira Palavra**. Ela deve permitir andar, combater, receber dano, esquivar, aparar, morrer, reaparecer, descobrir uma segunda arma, abrir um atalho, coletar Nous, comprar uma habilidade, salvar/carregar e vencer o chefe protótipo. A porta final conduz somente a uma entrada demonstrativa de A02.

O projeto mantém as decisões do GDD: câmera isométrica, mundo interconectado, três categorias de armas e progressão por exploração. As outras 11 áreas, arte final, campanha completa, relíquias, domínio das armas e arsenal completo pertencem a etapas posteriores.

## Ambiente e ferramentas

| Item | Local identificado | Situação neste registro |
|---|---|---|
| Godot | `C:\Users\Kauã\Downloads\Godot_v4.7.2-stable_win64.exe` | `--version` confirmou `4.7.2.stable.official.ed1daf0bf`. Importação e execução do jogo são verificações separadas. |
| Blender | `D:\blender.exe` | `--version` confirmou `5.2.3 LTS`, hash `e13b728c6880`. Execução dos scripts de produção ainda precisa ser verificada. |
| Linguagem | GDScript | Escolhida para a demo, conforme preferência do GDD. C# não é requisito. |

Usar os executáveis identificados por caminho explícito. Não instalar addons ou integrações MCP para viabilizar esta etapa. O protótipo deve funcionar com placeholders mesmo antes da prova artística do Blender.

O desenvolvimento está sendo preparado em uma cópia de trabalho, pois a pasta `D:\Nono_Veu` apresentou restrição de escrita. A cópia só deve ser descrita como atualizada na pasta final depois de a transferência ser realizada e verificada.

## Espaço, câmera e arte temporária

- Implementar um **jogo 2D com apresentação isométrica**, `CharacterBody2D`, `Camera2D`, cenário modular e ordenação por Y.
- Usar o plano de chão em **coordenadas da tela** para deslocamento, colisão, alcance, hitboxes e telegráficos. Não aplicar uma segunda transformação isométrica à física. Pisos em losango e desenho dos objetos estabelecem a perspectiva visual.
- Normalizar a entrada antes de aplicar a compressão vertical `y × 0,70`, permitindo movimento em oito direções no plano da tela. O ponto de origem do personagem e a ordenação devem corresponder aos pés. As colisões representam a ocupação do chão, não a altura inteira da imagem.
- Começar com resolução **640 × 360**, enquadramento 16:9, filtragem **nearest** e câmera fixa quanto à orientação. Esses parâmetros são de protótipo; resolução final, tamanho de tiles e matriz de sprites continuam ajustáveis.
- Produzir placeholders originais com silhuetas e cores distintas, sombras de contato e indicação de direção. Telegráficos de inimigos e do chefe devem continuar visíveis diante de pilares e paredes.
- Separar a arte das colisões e das janelas de dano. As pranchas conceituais servem apenas como referência; não são sprite sheets.

## Controles do protótipo

| Ação | Entrada |
|---|---|
| Mover | WASD ou setas |
| Ataque leve | J ou botão esquerdo do mouse |
| Ataque forte | F |
| Esquiva | Espaço |
| Parry | K ou botão direito do mouse |
| Poder da arma | Q |
| Interagir/meditar | E |
| Trocar arma | Tab |
| Árvore de habilidades | T |
| Mapa | M |
| Pausa | Esc |

Os controles são uma escolha inicial para validação. O README e a UI devem refletir as ações efetivamente implementadas.

## Combate e armas

Manter movimento, vida, equipamento e ataque em componentes ou scripts pequenos. Reutilizar o contrato de dano entre jogador, inimigo e chefe. Ataques possuem preparação, janela ativa e recuperação configuráveis; um mesmo golpe não deve causar dano repetidamente ao mesmo alvo por acidente.

`WeaponDefinition` é um `Resource` de dados, identificado por ID estável. Suas categorias permitidas são exatamente **leve**, **espada** e **pesada**. Dados de definição não guardam desbloqueio, arma equipada ou experiência do jogador. Esse estado pertence ao inventário e ao salvamento.

| Arma da demo | Papel | Diferença a validar |
|---|---|---|
| E01 — Khopesh do Discípulo | Espada inicial | Combo curto, ataque forte e riposta ligada a parry bem-sucedido. |
| L01 — Adagas do Reverso | Arma leve encontrada em desvio opcional | Sequência mais rápida, alcance/recuperação próprios e efeito evasivo simples, com sinalização visível. |

A obtenção antecipada de L01 é uma concessão da demo prevista na seção 10.8 do GDD; não fixa sua localização na campanha. A infraestrutura reconhece a categoria pesada, mas não exige criar uma terceira arma agora.

Não permitir que a troca conserve hitboxes ou poderes pendentes da arma anterior. A primeira regra de troca deve ser simples e consistente, preferencialmente bloqueando a troca durante ações comprometidas. Custos, cooldowns, dano, combo, parry, invulnerabilidade e stagger permanecem parâmetros de teste. **A demo não usa stamina.** Domínio de armas fica para depois de validar o combate.

## Mapa e progressão

Construir o percurso **H0 → P1 → P2 → P3 → S1 → P4 → B1**, com uma alavanca em P4 abrindo um retorno curto a H0. O jogador encontra o portão fechado pelo lado do hub e depois o abre pelo lado oposto. A rota principal não depende da segunda arma nem da compra de um nó opcional.

- H0: hub, meditação e acesso à árvore.
- P1: cais para aprender movimento e colisão.
- P2: armazém com um inimigo de teste.
- P3: pátio com Fragmento de Nous e desvio para a arma alternativa.
- S1: santuário próximo do chefe.
- P4: guarita, interação contextual e alavanca do atalho.
- B1: arena do Porteiro Sem Nome, com dois ataques distinguíveis e janelas de punição.

O Reverso completo, suas trocas de camada e os atalhos entre regiões ficam para a expansão do capítulo. Uma inscrição curta pode apresentar a Inversão sem conceder prematuramente habilidades narrativas.

Na árvore, implementar **três nós opcionais**, com custos provisórios de **1, 1 e 2 Nous**, descrição e pré-requisitos visíveis. Garantir saldo suficiente na demo; comprar desconta uma vez, aplica o efeito uma vez e persiste. **Não há perda de moeda ao morrer.**

## Estado do mundo e salvamento

Configurar o nome do jogo como **O Nono Véu** e a pasta de dados do usuário como **`nono_veu_demo`**. Salvar em `user://`, fora dos dados imutáveis do projeto, com versão de formato, escrita atômica e cópia de segurança. Usar IDs estáveis para pickups, portas, checkpoint, habilidades, armas e chefe. Validar os campos carregados e voltar a uma entrada segura se um ponto de reaparecimento for inválido.

O conjunto mínimo inclui checkpoint, saldo e IDs de Nous coletados, nós comprados, armas possuídas/equipada, atalho aberto e chefe derrotado. Coletáveis consumidos e o chefe vencido não reaparecem ao carregar ou voltar à sala. Morte conserva os avanços permanentes e repõe o jogador no último checkpoint; a política de reinício de inimigos comuns deve ser registrada quando implementada.

Salvar automaticamente nos eventos de progresso, além da meditação no checkpoint. Falhas de escrita devem preservar a última cópia válida e gerar um aviso identificável para diagnóstico.

## Validação e próxima prova visual

Verificar separadamente importação, execução sem interface, interação real e persistência. Um teste sem interface não comprova câmera, legibilidade nem resposta dos controles. Registrar comandos e resultados reais em `docs/PROGRESSO.md`.

Depois de o combate funcionar, executar uma prova pequena do Blender: script não destrutivo, blockout original de Senu, câmera ortográfica e PNG transparente reproduzível. Integrar a imagem à cena de teste, conferir pivô/escala/direção e preservar fonte e export. Esse teste não equivale a concluir modelos, animações ou arte final.

## Revisão do protótipo — 25/10/2026

A pedido do usuário, a A01 foi ampliada para 13 setores/1.287 células, com dois retornos físicos e um segredo narrativo opcional. O checkpoint `market_rest` complementa `hub` e `s1`; os IDs antigos de coletas, armas e chefe permanecem. Novas flags são aditivas no formato de save1. Nova jornada gera um arquivo do estado anterior antes de reiniciar.

O personagem principal passou a usar o atlas Senu v2 pré-renderizado no Blender, com 64 quadros e pivô48,94. Hitbox, dano, tempos e demais regras do combate foram mantidos. A câmera usa zoom1,1 para acomodar o cenário, e objetos altos reduzem sua opacidade ao encobrir o herói. A prancha ImageGen é referência artística; o atlas de produção e o modelo são arquivos independentes.
