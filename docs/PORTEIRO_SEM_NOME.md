# O Porteiro Sem Nome — implementação e referências

Estado atual, 2026-10-30: **integrado à partida normal em `D:\Nono_Veu`**, Godot 4.7.2. O jogador autorizou prosseguir até a implementação enquanto estava ausente; depois solicitou mais vida, dano e velocidade. Sem commit, push ou merge nesta entrega.

## Entrega atual

- Diagnóstico, arte funcional em oito vistas, fases 1/2, narrativa, recompensa e persistência integrados. Polimento técnico verificado; avaliação humana de movimento e dificuldade continua necessária.
- `JOGAR.cmd`: encontro normal após os três selos. `TESTAR_PORTEIRO.cmd`: mesmo encontro, Senu inicial e torre da Guarita preparada, em progresso exclusivo de QA. Não precisa atravessar o Porto para experimentar. O ensaio artístico V5/V6 em `VER_GOLPES_PORTEIRO.cmd` permanece separado.
- Novo ator `scripts/actors/nameless_gatekeeper.gd` especializa o inimigo atual. `gatekeeper_encounter.gd` coordena entrada/cenas/portões; ganchos pequenos no mundo preservam os outros módulos. Nenhuma mudança nas animações/fontes de Senu ou no atlas dos inimigos comuns.
- V9: 1.336 cels em oito direções; cinco camadas editáveis e arquivos `.pxo` por vista. Corpo57 px, canvas192² com pivô96,144; atlas runtime2048×2208 (~18 MB RGBA). Mantidos rosto v3, passada22 px, 16 poses de andar e 32 de assentamento por vista. Fonte em `art/pixelorama/porteiro_live_v9/`. Costas refinadas após o pedido do jogador: cabelo/nuca distintos da gola, manto cobrindo o dorso, dobras diagonais e abertura inferior assimétrica, com braços separados da arma. As cinco vistas frontais/laterais preservam todos os pixels da v8;4.175 camadas foram comparadas antes de reutilizar seus exports Pixelorama. Três vistas traseiras reexportadas; V8 e anteriores preservadas. Prévia nativa de caminhada em46 px/s; jogo continua sincronizado à distância real, sem deslizar os pés para acelerar.
- Os nove golpes têm clipes corporais próprios e um relógio JSON comum a contato, avisos e efeitos. Investida e eco usam deslocamento físico; onda circular só atinge a borda em expansão; zonas têm aviso de0,8 s; correntes só reduzem movimento por0,6 s quando acertam. Parry explícito e esquiva consomem o contato, impedindo dano tardio repetido.
- Aos50%, interrompe golpes e projéteis, protege o chefe e usa o diálogo solicitado. Em0 PV, ajoelha/examina placa/morre sem explosão, confirma vitória uma vez, revela o portão e devolve controles/câmera. Espaço por3 s pula; fechar o diálogo e sair da cena também liberam o estado.
- Recompensas: passagem, 2 Nous únicos e chave-lança no inventário; XP/óbolos pela coleta existente. Chave-lança tem recurso de arma pesada/Último Chamado preparado, mas **não é uma terceira arma equipável nem executa o poder**. Esse limite modular foi autorizado no pedido original. Nenhuma habilidade avançada do Reverso concedida.
- `porteiro`, `flags.boss`, Hori/Sabu, quatro marcas e relicário preservados. Só torres escrevem a vitória em disco. Ao morrer, chefe/portões/efeitos/slow reiniciam; introdução já vista é pulada naquela sessão. Save antigo com vitória produz corpo e permite recuperar recompensa uma vez ao examinar os pertences.
- Quatro registros opcionais próprios; nomes no piso e moldura de pedra/sinos/correntes no portão, sem novos obstáculos. Ambiente/mar/tochas existentes mantidos. Música em duas camadas, sinos, correntes, passos e respirações sintetizados localmente. Risos/gritos/esforço têm pontos de integração em `gatekeeper_audio.json`; os sons atuais são **placeholders sintéticos**, sem dublagem humana gravada.

### Dificuldade atual solicitada pelo jogador

Vida720 e danos abaixo mantidos. No refinamento atual, andar36→46 px métricos/s; fase2:40,32→54,28. Pausas extras entre golpes0,40→0,28 s /0,22→0,16 s. Fase2 passa de1,06× para1,10×, usando o mesmo relógio para animação, avisos e contatos; Último Nome ainda antecipa por1,50 s nessa fase. Alcances e janelas de parry/desequilíbrio preservados.

| Golpe | Dano anterior → atual |
|---|---:|
| Investida |22→32|
| Varredura |18→26|
| Registro |26→38|
| Sino |16→24|
| Última Advertência |30→44|
| Ecos |22+12→32+18|
| Nomes |18→26|
| Correntes |14→22|
| Último Nome |36→52|

Parâmetros em `resources/bosses/gatekeeper_combat.json` e `gatekeeper_attacks.json`. O dano do eco também vem do JSON; não fica duplicado no ator.

### Verificações desta integração

Rodada atual v9: combate67/67, IA24/24 (velocidades medidas46,00/54,28 e todos os nove golpes escolhidos autonomamente), persistência27/27 e pixels5062/5062 aprovados. Rodadas anteriores desta integração: UI6/6 em janelas960×540,1920×1080 e800×900; ensaios preservados com pixels853, ataques104, caminhada68, mapa33 e seleção16 aprovados. O verificador da v5 compara tempos/contatos, permitindo alterar dano sem regenerar fontes antigas. Regressões da integração completa: percurso139, progressão125, renovação59, história56, torres28, inventário26, HUD20, botões592, habilidades44, mundo134, missões72, migração34, abertura24, efeitos110 e combate base26 aprovados. Alguns encerramentos ainda avisam sobre recursos/instâncias retidos; não houve erro de script nas rodadas finais dessas suítes. QA usa somente `user://qa/`.

Capturas/GIFs atuais: `qa/porteiro_refino_v9/runtime/`, incluindo `silhueta_no_mapa.png`, `vista_*.png` e caminhadas das três costas; comparação em `qa/porteiro_refino_v9/comparacao_costas.png`. Provas anteriores em `qa/porteiro_combate/` e `qa/porteiro_silhueta_v8/` preservadas. O hitstop é desligado apenas na captura determinística; o encontro jogável o mantém. Capturas e testes técnicos não representam aprovação artística nem uma partida humana balanceada. Relatos de etapas anteriores abaixo são históricos e não descrevem mais as ausências da partida normal.

## Diagnóstico e etapas anteriores (histórico preservado)

Base inicial inspecionada: `D:\Nono_Veu`, branch `develop`, Godot4.7.2. As propostas/pendências nas seções seguintes registram o estado anterior à integração acima.

## 1. Escopo e referências

- Primeiro grande chefe de **A01 — Porto dos Esquecidos**, na Guarita do Retorno de Alexandria. A02 e o encerramento do Capítulo I permanecem distintos.
- Homem envelhecido, alto e debilitado; rosto humano descoberto, cabelos escuros/grisalhos, barba irregular, manto vinho, tecido bege/marrom, bronze gasto, placas, sinos e inscrições nos braços. A fase 2 muda atuação e postura, sem transformação corporal.
- Chave-lança: haste, dentes de chave e lâmina cerimonial, com sinos/correntes curtas; identidade legível em pixels antes dos ornamentos.
- Concept arts fornecidos pelo jogador, preservados sem edição: [prancha de combate/arena](concept_art/porteiro_sem_nome/concept_01.png) e [prancha de personagem](concept_art/porteiro_sem_nome/concept_02.png). Textos e rótulos nas imagens são referências; roteiro e escopo seguem o pedido escrito. Não converter a frase das pranchas numa regra nova de progressão.
- Fontes consultadas: `AGENTS.md`, `STATUS.md`, `COLABORACAO.md`, `DECISIONS.md`, `SALVAR_NAS_TORRES.md`, `GUIA_ANIMACOES_REUTILIZAVEIS.md`, `NPCS_INTERIORES_MISSOES_V2.md`, seções 3, 4 e 5 do GDD pertinentes à Inversão/A01, e sistemas abaixo. O GDD e a abertura aprovada não foram alterados.
- Restrição de produção: ferramentas gratuitas, assets originais e pipeline local. Não usar ImageGen ou serviços/APIs pagos para produzir os sprites desta entrega. Os concepts não são uma folha de animação pronta.

## 2. O que existe no código

| Sistema | Evidência atual | Consequência para o trabalho |
|---|---|---|
| Entrada e mundo | `scenes/boot/main.tscn` → `scripts/world/port_demo.gd`; mundo em SubViewport 640×360, GL Compatibility, nearest | Manter apresentação em pixels e coordenadas de chão; HUD na janela, usando `world_to_ui` quando necessário. |
| Chefe atual | `port_layout.gd`: spawn `porteiro`, tile (-6,23); `port_demo.gd::_spawn_enemy` cria `VeilEnemy` | Substituir somente esse encontro, preservando ID e referências tipadas `VeilEnemy`. |
| IA atual | `enemy.gd`: WAIT/CHASE/WINDUP/STRIKE/RECOVER/STAGGER/DEAD; chefe com 400 PV, velocidade 39 e dois padrões alternados | Há base de colisão, navegação e dano; faltam nove ataques, fases, limites da arena e encenação. Valores atuais não constituem balanceamento aprovado. |
| Arte atual | `enemy_pixel_view.gd`: atlas `port_enemies_v12.png`, célula 128², pivô (64,112), 16 poses por arquétipo; chefe usa `keeper` em escala 1,35 | O chefe não tem aparência própria. Não retocar ou regenerar o atlas compartilhado para substituir esse personagem. |
| Senu | `player.gd`, `senu_supplied_view.gd`, `senu_sword_view.gd`; oito direções, ataques, esquiva, parry, riposta, duas armas | Reutilizar contratos de combate e preservar todas as fontes/animações atuais de Senu. |
| Dano | `receive_hit(amount, from_position, stagger)`; grupo `enemies`; ataques de Senu consultam arco/alcance e oclusão por cenário | O ator específico deve continuar aceitando esses golpes, incluindo projétil, habilidades e empurrões. |
| Defesa | Janela base de parry 0,25 s, recarga 0,67 s; esquiva com invulnerabilidade base 0,28 s | Não existe uma categoria separada de parry perfeito. A compatibilidade precisa ser explicitada, não presumida. |
| Reação ao parry | Senu chama `receive_hit(5, ..., true)` nos inimigos a até 20 px métricos da origem do golpe | Origem visual de um golpe longo não deve impedir desequilíbrio. Não usar esse dano de 5 como identificação exclusiva de um parry. |
| Impactos/morte | `combat_fx.gd` observa estados de `VeilEnemy`; dano fatal gera fragmentos/anel; `enemy.gd` emite `defeated` imediatamente e some em 0,45 s | Morte narrativa exige adiar o sinal de vitória e suprimir a dissolução visual apenas neste chefe. |
| Arena | Sala `b1` (-12,16), 13×15 tiles, ligada a `p4` e `a02`; portões `boss_entry` e `boss` | Reutilizar a sala e seus acessos; não redesenhar o Porto inteiro. |
| Acesso | Três selos abrem `boss_entry`; vitória abre saída `boss` | Separar acesso resolvido da barreira temporária do encontro; não fechar a porta definitivamente ao morrer. |
| Torre | `s1`, tile (7,20), na Guarita; integra cura, cargas, renovação e checkpoint | Usar a torre existente. Medir retorno em partida; não conceder checkpoint/salvamento automático na entrada. |
| Conversa | `game_hud_v6.gd::show_dialog/show_conversation`; `npc_speech_bubble.gd` pagina em até quatro linhas e emite `finished` | Reutilizar estilo/paginação; o ator Porteiro ainda não é resolvido como falante nos balões. |
| Cutscene | `opening_cutscene.gd` tem controle de sequência e skip, mas é específica do cais; `portrait_dialogue.gd` tem retratos apenas de Senu/Pescador | Não reutilizar o rosto do pescador para o Porteiro. Adaptar o componente de diálogo para o novo falante; manter roteiro da abertura intacto. |
| HUD de chefe | `game_hud_v6.gd` já desenha nome e barra por proximidade (<240 px) | Evoluir essa apresentação, sem sobrepor outra barra; visibilidade deve seguir encontro ativo e não só distância. |
| Persistência | `defeated` contém `porteiro`; `flags.boss` impede novo spawn; `_save` só sincroniza sessão | Vitória conserva-se em memória e vai ao disco na próxima torre. Fechar antes dela recarrega o estado ancorado anterior. |
| Recompensas | `Economy.reward_for`: 120 XP e 55–65 óbolos; `_drop_loot` conectado antes de `_on_enemy_defeated` | Preservar ordem e garantia de pagamento único. Não há Fragmentos de Nous concedidos diretamente pela morte do chefe atual. |
| Arsenal | `WeaponDefinition` já aceita `pesada`, mas jogador, arrays de cooldown/desbloqueio, apresentação e save têm duas armas | Um `.tres` sozinho não entrega uma terceira arma funcional. Preparar integração modular sem usar animação incompatível. |

## 3. Continuidade narrativa que deve permanecer

### Hori e Sabu

`port_story.gd::_talk_to_brother` já aceita **sino tocado OU `flags.boss`**, depois de obter o cordão de Hori, para avançar `fisher_named`. A vitória não nomeia Sabu automaticamente; ainda é necessário conversar e retornar a Hori para `fisher_done` e seus 2 Fragmentos de Nous. Preservar a alternativa pelo sino, inclusive para quem concluiu a missão antes do chefe. Encontrar Sabu antes de Hori e saves antigos continuam válidos. Essa ligação já atende ao avanço parcial da memória após o limiar, sem uma cura geral da Inversão.

### Marcas de Iri

Preservar os quatro IDs e textos: `iri_mark_archive`, `iri_mark_oracle`, `iri_mark_buried`, `iri_mark_guard`. A marca da Guarita está em (5,27.5), fora da sala `b1`, e atualmente pode ser lida antes da vitória. O relicário `iri_relic` exige as quatro marcas e paga 3 fragmentos. Não mover a marca nem impor a vitória como quinto requisito. A passagem liberada continua levando ao limiar demonstrativo de A02; nenhuma revelação nova das Catacumbas.

### Passado do guarda

Propor quatro registros opcionais com IDs próprios em `collected`, reutilizando as inscrições existentes: memória extraordinária do guarda; nomes de marinheiros apagados; temor de esquecer a família; correções repetidas nas placas. Não revelar um nome verdadeiro obrigatório, não substituir documentos de Tarek e não conceder habilidades do Reverso. Textos novos serão apresentados na etapa narrativa.

## 4. Proposta de arquitetura

Arquivos abaixo são **planejados**, ainda não criados:

- `scripts/actors/nameless_gatekeeper.gd`: especialização de `VeilEnemy`, com estados do encontro, seleção de ataques, cooldowns, dano, stagger e reinício. Preserva tipagem e contratos usados por combate/renovação/loot.
- `scripts/actors/nameless_gatekeeper_view.gd`: leitura do atlas/manifest, animações, pivôs e avisos visuais. Não concede dano, recompensas ou progresso.
- `scripts/world/gatekeeper_encounter.gd`: entrada na sala, barreira temporária, câmera, sequência narrativa e limpeza. Ganchos curtos em `port_demo.gd`, sem reorganizá-lo.
- `resources/bosses/gatekeeper_attacks.gd`: definições dos golpes e seus marcos temporais. Um único relógio determina cel de contato e ativação do dano; o desenho nunca dispara uma segunda hitbox.
- `resources/dialogue/gatekeeper_dialogue.gd`: as três sequências fornecidas pelo jogador, sem reescrita de falas aprovadas.
- `art/pixelorama/porteiro_v1/` e `assets/sprites/porteiro_v1*`: fontes próprias, projeto `.pxo`, atlas PNG e manifest. Ferramentas locais em `tools/pixelorama/`; não regenerar fontes compartilhadas.

Fluxo proposto: `INTRO → IDLE ↔ APPROACH → ATTACK → RECOVERY`; `STAGGER` retorna à recuperação. Aos 50%: `PHASE_TRANSITION` uma única vez, depois fase 2 no mesmo fluxo. Em zero: `DEFEATED` inicia a atuação final, depois confirma a vitória uma única vez. O estado de fase é separado do enum básico observado pelos efeitos comuns; expor um mapeamento explícito evita sons errados e mantém a compatibilidade.

Invariantes para a implementação:

1. Na introdução, transição, derrota e reinício, cancelar golpes pendentes, ecos, áreas, lentidão e projéteis do encontro; bloquear dano em ambas as direções. O corte aos 50% deve impedir que uma rajada pule a fase 2.
2. Guardar/restaurar controles, câmera e pausa em um caminho comum de saída. Falha, skip, morte, troca de cena e liberação do nó devem encerrar o bloqueio; não depender somente de um `await` terminar.
3. Travar mira/origem durante antecipação; não redirecionar a investida no contato. Movimento real com colisão, sem teleporte através de pilares ou portões. IA confinada ao chão livre da arena, com margem de segurança.
4. Uma aplicação por alvo por golpe/onda/eco; leitura das mesmas formas métricas isométricas na sinalização e no teste de dano. Não usar um disco cheio para uma onda que só é perigosa na borda.
5. Morte de Senu reinicia o encontro com vida/fase inicial, limpa efeitos e abre o acesso temporário. A renovação da torre também chama o reinício. Tentativas fracassadas não pagam nada.
6. Corpo derrotado permanece na arena, sem bloquear passagem. O nó pode sair do grupo de alvos; sua pose final não usa fade do inimigo comum. Definir representação do corpo também ao carregar um estado já vencido.
7. Confirmação de vitória une flag/ID e marcadores de recompensa na sessão; sinal de loot emitido uma vez, antes do registro que bloqueia repetição. A próxima torre ancora o conjunto, conforme a regra vigente.
8. Saves legados com `flags.boss` ou `porteiro` derrotado não revivem o chefe. Recompensa nova não será distribuída ao carregar silenciosamente: usar recuperação única e explícita no cenário se necessária, com marcador de coleta e sem novo combate.

## 5. Arte e primeira avaliação visual

Meta inicial: corpo de aproximadamente **57 px no mundo**, referência de cerca de 38 px de Senu (145 px de corpo-fonte × 0,26 no construtor v6), confirmar lado a lado no Godot. A altura considera cabeça até os pés, não a ponta da lança. Não ampliar Senu nem usar a altura total do canvas para medir o corpo.

Proposta de canvas nativo: 160×160, pivô de chão (80,140), escala 1, com margens para a haste; dimensões finais dependem de não cortar a arma em nenhum contato. O pivô é por personagem, não precisa copiar numericamente o canvas-fonte de Senu; coincide no mesmo chão do mundo. Oito direções sem trocar a mão da arma ou espelhar inscrições de modo incoerente. Uma escala por personagem, alfa binário, nearest, pés/sombra estáveis e mesma densidade visual do cenário.

Primeira entrega de arte para avaliação: repouso humano em vistas frontal, lateral e traseira; comparação ao lado de Senu real em 1× e ampliação inteira; oito cels de caminhada em uma direção; seis cels de perfuração (preparação, antecipação, aceleração, contato, continuação e recuperação). Somente após avaliar rosto, silhueta, apoio e arma, expandir o conjunto direcional.

Clipes planejados: idle normal/exausto/desesperado, caminhada, investida, antecipação, corte horizontal, vertical, perfuração, sino, defesa, dano, stagger, busca nas placas/transição, ataques da fase 2, queda/ajoelhar e morte silenciosa. Os nove golpes podem reutilizar gestos coerentes; não chamar uma pose repetida de animação completa. Fonte `.pxo` com camadas de corpo/tecido/bronze/arma e tags documentadas; eventos de contato ligados ao manifest e testados.

Arena: aproveitar piso/água e arquitetura existentes; acrescentar portão/placas/sinos/correntes e ruínas em assets próprios. Não ocupar bocas de passagem nem área útil de esquiva. Névoa e tochas discretas, sem cobrir avisos; profundidade dos pilares coerente com a base. Captura real inicial: `qa/porteiro_diagnostico/arena_atual.png` — representa o chefe antigo, não a arte proposta.

## 6. Proposta inicial dos golpes

Valores abaixo são hipóteses para teste, não balanceamento entregue. Tempos em segundos; dano bruto antes das defesas. Distâncias em pixels métricos do mundo, com Y do combate dividido por 0,70, conforme o sistema atual. A fase 2 reduz deslocamentos/intervalos, mantendo antecipações mínimas legíveis. Nenhum ataque exige habilidades avançadas.

| Golpe | Fase | Antecipação / contato / recuperação | Forma e defesa | Dano inicial |
|---|---|---|---|---:|
| Investida da Guarita | 1 e 2 | 0,90 / até 0,38 / 1,05 | Corredor de 110 px, meia largura 10; alvo travado; esquiva lateral e parry compatível | 22 |
| Varredura Cerimonial | 1 e 2 | 0,80 / 0,20 / 0,90 | Arco frontal de 150°, raio 62; não atingir pelas costas fora do arco | 18 |
| Golpe do Registro | 1 e 2 | 1,10 / 0,18 / 1,20 | Elipse de raio métrico 24 no ponto indicado até 55 px à frente; breve reação ao impacto | 26 |
| Sino do Esquecimento | 1 e 2 | 1,20 / onda de 0,85 / 1,10 | Borda de anel até raio 120, espessura 10; centro seguro após passagem da borda | 16 |
| Última Advertência | 1 e 2 | 1,45 / 0,20 / 1,30 | Guarda marcada, golpe frontal; parry concede stagger de 1,50 | 30 |
| Ecos da Investida | 2 | 0,95 / investida + eco / 1,20 após eco | Eco na trajetória já fixada; aviso próprio de 0,65 s após investida, sem perseguir Senu | 22 + 12 |
| Nomes Esquecidos | 2 | 1,00 / pulsos locais / 1,15 | Até três áreas de raio 18, aviso individual ≥0,80 s; garantir rota segura e não sobrepor tudo no jogador | 18 por área, sem repetição da mesma |
| Correntes do Limiar | 2 | 1,00 / avanço de 0,40 / 1,00 | Faixa direcional até 90 px; lentidão 20% por no máximo 0,60 s, só se causar dano, sem impedir ações | 14 |
| Golpe do Último Nome | 2 | 1,65 / 0,24 / 1,70 | Golpe amplo frontal com final travado; esquiva ou parry, melhor acerto de parry amplia stagger | 36 |

Compatibilidade de parry a resolver na etapa 3: `receive_hit` atualmente não distingue sino/áreas/golpes e retorna `false` tanto para parry quanto invulnerabilidade. Não inferir parry apenas por esse retorno. Proposta: pequeno resultado/sinal explícito de defesa no sistema atual; manter a janela de 0,25 s e usar seus primeiros 0,10 s como bônus de precisão do Último Nome, sem introduzir outro comando ou retirar a defesa normal. Testar origem do atacante em golpes de longa distância e reação do chefe; representar o ponto perigoso separadamente da posição do atacante. Avisos/áreas continuam esquiváveis mesmo sem parry. Confirmar o comportamento antes de codificar classificações adicionais.

Seleção da IA: aproximação fora de alcance; investidas para média/longa distância, arcos para curta e sino sob cooldown próprio. Na fase 2, introduzir novos padrões aos poucos, sem repetir imediatamente o mesmo golpe nem sobrepor áreas/eco ao Último Nome. Usar relógio de física com `delta`, não o número de quadros. Iniciar com os 400 PV atuais; só ajustar após ensaios com equipamento de entrada e progressão plausível.

## 7. Sequências, som, recompensas e HUD

- Introdução: ajoelhado diante do portão, examina placas, ergue cabeça, falas do pedido de “Diga seu nome.” até “Onde escreveram o meu?”, pega arma, revela arena e nome; nenhuma hitbox ativa antes de devolver controle.
- Transição: aos 50%, solta arma, busca placas, riso/choro, inscrições com brilho discreto; manter exatamente “Eu escrevi todos...”, “Todos...”, “POR QUE NÃO CONSIGO ENCONTRAR O MEU?”. Retomar após margem segura e aviso do próximo ataque.
- Derrota: cai a arma, ajoelha, encontra placa e falha ao pronunciar; “Eu me lembrava de todos...” / pausa / “Por que ninguém se lembrou de mim?”. Cabeça baixa, sinos silenciam, câmera mostra passagem. Confirmar vitória ao concluir ou pular a sequência, uma única vez.
- Apresentação: reutilizar tipografia/caixa e controle de avanço de diálogo existentes; adaptar o falante/retrato por parâmetro em vez de duplicar todo o sistema ou editar a abertura. Skip com liberação segura deve aplicar o mesmo resultado; pular falas não pula o combate.
- Áudio: reaproveitar `VeilSfx`, buses SFX/Ambiente/Vozes e água/vento existentes; acrescentar bancos originais de bronze grave, passo molhado, correntes, esforço e respiração. `tools/audio/build_combat_sfx.py` é referência de síntese local. Música/ambiente em duas camadas, transição suave, silêncio na derrota. Não apresentar síntese como dublagem humana definitiva; gritos/risos podem permanecer pontos de integração identificados até haver material adequado. Ouvir no jogo é validação necessária.
- Recompensa proposta: manter XP/óbolos atuais e conceder **2 Fragmentos de Nous** uma única vez na vitória, com marcador próprio. O valor é inicial para avaliação e não substitui os fragmentos dos irmãos ou do relicário. Não desbloquear habilidades do Reverso.
- Chave-Lança: preparar `WeaponDefinition` pesada com descrição fornecida e `power_id = ultimo_chamado`. Poder futuro: impacto no chão, ressonância curta e stagger em inimigos próximos, usando dano/stagger existentes. Sem poses compatíveis de Senu para haste longa, entregar como objeto único de equipamento com integração preparada, sem opção falsa de equipar. A ativação completa requer ampliar cadastro de armas, arrays, visualização, ícones, inventário e validador de saves em conjunto; não fazer o poder desconhecido cair no `else` da riposta atual.
- HUD: evoluir barra existente para nome centralizado, faixa escura, ouro discreto e mudança sutil de fase. Aparecer no encontro ativo, desaparecer na derrota/reinício; layout pelo mesmo fator de janela do HUD. Verificar 960×540, 1280×720, 1920×1080 e janela estreita.

## 8. Etapas e provas para avaliação

| Etapa | Resultado apresentado | Verificação antes de avançar |
|---|---|---|
| 1 — Diagnóstico | Este plano, captura da arena antiga, testes iniciais e limites conhecidos | Conferir integração e referências com o jogador. Nenhuma mudança de gameplay. |
| 2 — Arte | Prancha inicial e ciclos curtos, depois atlas próprio aprovado e fonte editável | Consistência humana, altura relativa, oito vistas, pivôs, arma sem cortes, importação/manifest. |
| 3 — Combate | Fase 1 jogável com cinco golpes e HUD integrado | Alcances reais, avisos, esquiva/parry, uma aplicação de dano, paredes, cooldowns, recuperação e reinício. |
| 4 — Evolução | Corte aos 50% e quatro golpes novos | Transição única, cancelamento de ataques, ecos fixos, zonas com saída segura, lentidão curta e limpeza ao morrer. |
| 5 — Narrativa | Três sequências, passagem, registros, Nous e integração modular da arma | Skip/fechar/pausa sem travar, vitória única, save na torre, legado derrotado, quatro marcas e duas rotas de Hori/Sabu. |
| 6 — Polimento | Capturas/vídeo real, áudio original e ensaio de dificuldade | Legibilidade em resoluções diferentes, desempenho, equilíbrio com equipamento inicial, revisão humana de som e animação. |

Testes novos devem exercitar contratos, não apenas conferir constantes: passar pelo contato com invulnerabilidade/parry; sair da área antes do impacto; interromper fase/morte com eco agendado; repetir sinal final; morrer e tentar novamente; salvar em torre/carregar; carregar legado já vencido; concluir irmãos antes/depois e relicário em ordens diferentes. Adaptar testes antigos que pressupõem vitória instantânea para aguardar a sequência narrativa pelo mesmo caminho do jogo. Nenhum teste do mundo usa progresso real.

## 9. Verificação inicial executada

Logs em `qa/porteiro_diagnostico/`. Importação Godot 4.7.2: saída 0. Captura gráfica pelo modo existente `-- --qa --capture-arena`: saída 0, OpenGL Compatibility, captura inspecionada. Todos os testes do mundo foram executados com `-- --qa`; as suítes usam slots exclusivos em `user://qa/`.

| Suíte | Resultado observado |
|---|---|
| `combat_test.gd` | 26/26, saída 0 |
| `skill_combat_test.gd` | 44/44, saída 0 |
| `enemy_v9_balance_test.gd` | 56/56, saída 0 |
| `side_story_test.gd` | 56/56, saída 0 |
| `npc_quests_test.gd` | 72/72, saída 0 |
| `tower_only_save_test.gd` | 28/28, saída 0 |
| `enemy_respawn_test.gd` | 59/59, saída 0 |
| `hud_v6_test.gd` | 20/20, saída 0 |
| `route_test.gd` (time-scale 4) | 139/139, saída 0; passagem pela Guarita, arena, Catacumbas e Galeria do Eco. A falha antiga da Galeria não se reproduziu nesta execução; nenhuma correção de navegação realizada. |
| `save_migration_test.gd` | 26/28, saída 1: expectativa de gravação imediata de cache/pistas (linha 99) e busca de botão diretamente no HUD, incompatível com o popup atual (linha 118). Falhas anteriores a qualquer alteração do chefe. |
| `progression_test.gd` | 122/123, saída 1: comparação sessão/disco depois da vitória sem nova torre (linha 186), expectativa incompatível com salvamento somente nas torres. Falha anterior a qualquer alteração do chefe. |

Algumas suítes aprovadas também emitem avisos de instâncias/recursos retidos ao encerrar (combate, habilidades, história paralela e percurso); as duas suítes com falha emitem os mesmos avisos. Não afirmar execução livre de avisos. Os testes acima não avaliam o chefe novo, animação proposta, áudio ou justiça do combate; esses itens permanecem por produzir. Nenhum commit, push ou merge realizado.

Referências preservadas com igualdade SHA-256 entre anexo e cópia: concept 01 `6DB60D63F60A446615F0FDEB3E674AE9C54A7D9C6BE5942258534DD3790D254E`; concept 02 `9BDC4FB76E24009209F7A39C423C0DA5C25CDB0343081D364F6C68CCFED6EDDE`.

## 10. Estado da avaliação de arte e direção corrigida

O jogador aprovou iniciar a etapa 2, não aprovou os sprites produzidos. Foram preparados estudos locais em `art/pixelorama/porteiro_v1/` e `porteiro_v2/`, com prévias em `qa/porteiro_art_v1/` e `porteiro_art_v2/`. Não estão ligados ao chefe da partida. O perfil v1 foi rejeitado por parecer caricato; a v2 remove o rosto pintado por cima e usa textura do concept na lâmina, mas ainda não foi aprovada. A caminhada foi considerada ruim e deve ser refeita antes de expandir direções.

Direção explícita para o ataque: seguir a atuação dos inimigos comuns com lança. Primeiro empunhar a arma, preparar os braços e o peso do corpo, dar a estocada e recuperar a postura. Inspecionar o ciclo do lanceiro comum e produzir poses corporais completas, com mãos/arma conectadas e pés apoiados; a passagem da arma vertical à horizontal por si só não atende ao pedido. Os 17 cels de estudo não devem ser apresentados como animação final.

A produção foi suspensa para integrar e verificar o PR #11; essa integração foi concluída conforme `INTEGRACAO_PR11.md`. O jogador pediu a retomada do Porteiro em seguida.

### Novo ciclo para avaliação — v3

Fonte em `art/pixelorama/porteiro_v3/porteiro_v3.pxo`, com README de manutenção nessa pasta. A v3 substitui os recortes rígidos do perfil por um estudo de corpo inteiro na vista `down_right`, usando materiais do concept e poses articuladas locais. O rosto é uma peça rígida do concept, sem olhos/boca pintados por cima. Não houve uso de API paga nem alterações nas fontes de Senu ou dos inimigos comuns.

Caminhada: oito fases, com joelhos/tornozelos, apoio alternado e tecido ligado ao corpo. Estocada: nove fases, com as duas mãos na lança, recolhimento da arma, carregamento do tronco, antecipação sustentada, aceleração, contato, continuação e recuperação até a guarda. A atuação usa o lanceiro comum como referência. Contato visual em 1,00 s, após a preparação completa; isso ainda é um marcador de arte, não uma hitbox implementada.

18 cels de 160×160, pivô (80,140), escala 1 e referência de corpo 57 px. Uma única direção para avaliação; não espelhar para fingir direções ainda não produzidas. Exportação realizada pelo Pixelorama instalado, PNG+JSON+manifest em `assets/sprites/porteiro_v3*`; os estudos anteriores permanecem preservados. O renderizador próprio lê a v3, mas não é chamado pelo chefe da partida.

Provas em `qa/porteiro_art_v3/`: GIFs de caminhada/estocada, pranchas, 13 capturas do estúdio (120 quadros de animação renderizados com os sprites reais de Senu e do lanceiro), `arena_guarda.png` e `arena_estocada.png`. QA final: fonte/pixels/anatomia181/181, seleção de quadros16/16, inimigos28/28 e Senu v658/58. Exportação, importação, estúdio e arena com saída 0; mundo somente com `-- --qa`. Essas verificações não aprovam naturalidade artística nem testam o combate futuro.

Próximo marco: avaliação visual deste ciclo antes de expandir direções e demais clipes. Chefia em duas fases, diálogo, narrativa, recompensas, hitboxes e persistência específica ainda não implementados; a versão normal segue usando o chefe de teste antigo.

### Revisão de presença no mapa — v4

O jogador esclareceu que “grandioso” significa elevar a presença no mapa e a qualidade dos sprites. A revisão mantém a altura de referência e trabalha silhueta mais ampla do manto, volumes de tecido, chave-lança com bronze sólido e gasto, placas com nomes e detalhes de sinos/correntes. O corpo permanece humano e magro. Fonte editável em `art/pixelorama/porteiro_v4/`, com 18 cels na vista-piloto, atuação e pivôs da v3.

**Rosto:** uma substituição pelo painel de expressões foi rejeitada. A versão atual restaura exatamente a camada de rosto/cabelo da v3 nos 18 cels, conservando os refinamentos de manto e bronze. O validador compara essas camadas pixel a pixel com o projeto v3; preservar essa escolha em revisões futuras.

Provas em `qa/porteiro_art_v4/`, incluindo GIFs e capturas comparáveis na mesma arena com Senu. Somente slots de QA são usados. A v4 continua em avaliação artística e não substitui o chefe da partida. Não considerar a qualidade visual aprovada só porque os contratos de pixels e animação passam.

## 11. Nove animações próprias e caminhada no mapa — v5

Pedido seguinte do jogador: trabalhar todos os tipos de golpe, cada um com animação específica, impactos e partículas no chão, usando JSON; o Porteiro também deve caminhar pelo mapa. A entrega atual avança a avaliação de arte/movimentos e oferece uma prévia interativa, sem substituir prematuramente o encontro normal.

`art/pixelorama/porteiro_v5/porteiro_v5.pxo` contém 99 cels editáveis em quatro camadas: os 18 anteriores e nove clipes de nove poses. São Investida, Varredura, Registro, Sino, Advertência, Ecos, Nomes, Correntes e Último Nome. Cada clipe tem posições próprias de corpo, mãos, arma e apoio, com tempos de preparação/contato/recuperação em `resources/bosses/gatekeeper_attacks.json`. O eco retoma a linguagem da investida, como solicitado, e repete o contato após 0,65 s. Registro, Nomes e Último Nome possuem passadas, ângulos, carregamentos e recuperações distintos. O último golpe tem antecipação de 1,65 s e impacto mais forte. A camada de rosto/cabelo permanece idêntica ao rosto v3 preferido, normalizada pela posição, nos 99 cels.

`gatekeeper_attack_player.gd` dispara contatos pelo mesmo relógio que seleciona os cels. Cancelar limpa os eventos atrasados; pausa congela o relógio; atravessar um contato com delta grande não duplica o efeito. As lascas ampliam CombatFx existente, separando posição no chão, altura, gravidade, sombra e rebote, com limite de 72 pedras e expiração. Poeira mais densa e lascas claras/escuras dão leitura sobre a pedra do cenário. Golpes fortes usam hitstop, tremor e som já existentes. Ressonância circular, inscrições com aviso, correntes e eco são discretos e temporários. Dois WAVs originais sintetizados localmente fornecem sino/metal, pelo pool compartilhado; são placeholders, não áudio final ou música.

Abra **`VER_GOLPES_PORTEIRO.cmd`**: Senu se move com os controles normais e o Porteiro acompanha pela navegação, desvio de obstáculos e colisões de VeilEnemy. Os passos avançam pela distância efetivamente percorrida; o personagem deixa de caminhar durante a preparação e recuperação do golpe. Teclas **1–9** escolhem um clipe; **Tab** alterna a sequência automática. O estudo usa o mapa real com slots `user://qa/`, não causa dano, não registra vitória e não entrega recompensas. A vista continua sendo o piloto `down_right`, sem fingir outras vistas por espelhamento. O ator de ensaio fica em `tests/`, fora da lógica da partida.

### Verificação desta entrega

| Verificação executada | Resultado |
|---|---|
| Pixelorama PNG/JSON/manifest + importação Godot | Exportados e importados; saída 0 |
| Fonte/pixels/rosto/contatos/tempos nativos/áudio | 853/853 |
| Seleção de cels, pivô e caminhada por distância | 16/16 |
| Nove clipes, contato único, cancelamento, pausa, formas e partículas | 104/104 |
| Caminhada no mundo, mudança de alvo, oito poses e transição aos nove clipes | 25/25; headless e captura gráfica |
| Efeitos de combate compartilhados | 110/110 |
| Combate existente | 26/26 |
| Pool/feedback de áudio e botões | 592 verificações, sem falhas |
| Prévia interativa e captura dos nove golpes | Saída 0, OpenGL Compatibility, somente QA |

O teste de água dentro da suíte de FX pressupunha água onde o PR aprovado acrescentou o Claustro; a fixture foi deslocada para mar aberto, com a borda de chão atual e população de peixes reiniciada após o ajuste da câmera. Não foi alterada a lógica de água ou o mundo. Algumas suítes headless ainda avisam sobre instâncias/recursos retidos ao encerrar, inclusive combate; não afirmar execução livre de avisos.

Provas em `qa/porteiro_attacks_v5/`: `nove_golpes_arena.gif`, GIFs individuais `*_arena.gif`, `caminhada_no_mapa.gif`, prancha e relatórios/logs. São capturas do renderizador real; os GIFs `*_sprites.gif` contêm somente os cels. A captura de contato desliga o hitstop para manter o tempo determinístico; a prévia interativa mantém os efeitos em tempo real. A naturalidade dos golpes ainda exige avaliação visual do jogador.

**Limites:** ainda faltam outras direções, IA de seleção/cooldowns do encontro definitivo, deslocamento físico das investidas, dano/hurtboxes/parry/efeito de lentidão, transição de fase, introdução/derrota narrativa, HUD, recompensas e persistência específica. Os campos de combate no JSON são preparação, não uma implementação dessas regras. A partida normal continua com o chefe anterior; quatro marcas, irmãos, abertura, saves e progressão não foram alterados por esta entrega.

### Revisão dos passos — v6

O jogador considerou os passos da v5 esquisitos. A revisão substitui somente a caminhada, em um atlas/fonte próprios (`porteiro_walk_v6`), preservando os nove ataques e o rosto preferido. O ciclo passa de oito para 16 poses; os apoios são calculados no plano avanço/altura e então projetados, evitando dobrar os joelhos diretamente na perspectiva achatada. A passada é de 22 px, com levantamento máximo de 2 px e velocidade de ensaio de 24 px/s; a compressão de peso é de apenas 1 px, sem a oscilação lateral anterior da cabeça. Pernas têm base opaca de tecido para evitar falhas na textura e o manto acompanha o peso com atraso discreto.

Uma pose de passagem compacta inicia a caminhada. Cada uma das 16 fases possui duas poses próprias para recolher os pés e retornar aos pixels exatos da guarda original, mantendo pelo menos um apoio. A fonte totaliza 49 cels: ciclo16, fechamento32 e guarda1. Tempos, velocidade, passada e apoios são definidos em `resources/bosses/gatekeeper_walk.json`; os ataques continuam no JSON/atlas v5. O ensaio evita alternar centros de tiles em chão livre da arena; usa a navegação existente quando há obstáculo, buraco ou outra sala. Não houve mudança no inimigo comum ou na IA da partida normal.

Verificação desta revisão: pixels/fonte/rosto/apoio465/465; seleção16/16; caminhada/parada, interrupção por ataque e pausa68/68; nove golpes104/104; mundo33/33, incluindo deslocamento real, mudanças de alvo, parada, obstáculo físico e retorno à navegação. Um golpe solicitado em movimento espera os pés assentarem; só então inicia seu relógio JSON, preservando a antecipação e o contato. Exportação Pixelorama, importação Godot e captura OpenGL com saída0. Algumas execuções headless ainda avisam sobre instâncias/recursos retidos ao encerrar. Capturas somente com `-- --qa`, sem progresso real. Provas em `qa/porteiro_walk_v6/`: comparação do ciclo, caminhada e parada no mapa; acesso interativo pelo mesmo `VER_GOLPES_PORTEIRO.cmd`. A revisão continua limitada à vista-piloto e requer avaliação visual; os limites do encontro completo acima permanecem.
