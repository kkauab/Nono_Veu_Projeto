# Mundo do Porto — bugs, melhorias e história

Análise da zona **Mundo, mapa e puzzles** (responsável: Gustavo), feita em 27/10/2026 sobre a `develop` em `80805d4`, com leitura do código e execução no Godot 4.7.2.

Testes da zona na `develop`, sem alterações: `route_test` 121/121, `world_v6_test` 124/124, `navigation_v6_test` 8/8, `foundation_navigation_v8_test` 5/5 e `scene_support_v8_test` 65/65. Todos passam porque nenhum deles recarrega o save no meio de um puzzle.

## Como o mundo está montado

| Arquivo | Papel |
|---|---|
| `scripts/world/port_layout.gd` | Dados do mapa: 27 salas, 26 conectores, 2 patamares, 8 buracos d'água, marcadores, 4 portões, 38 inimigos e a rota principal. Desenha o chão em blocos de 12×12 pisos e cria a colisão do contorno. |
| `scripts/world/port_dressing.gd` | Cenário das 13 salas originais, posicionado à mão, e um gerador genérico para as 14 salas da expansão. |
| `scripts/world/world_prop.gd`, `interactable.gd`, `port_gate.gd`, `port_art.gd` | Objetos, interativos, portões e leitura do atlas do Pixelorama. |
| `scripts/world/port_demo.gd` (compartilhado) | Cria os itens, tem os textos, a lógica dos três puzzles, os selos e os objetivos. |

Conferido à mão: todos os conectores ligam as salas certas, nenhuma sala se sobrepõe, nenhum marcador ou inimigo cai na água. Os buracos d'água em `(-1,16)` e `(0,31)` fecham de propósito as passagens indevidas para a arena do chefe.

## Bugs

| # | Gravidade | Onde | Problema | Correção proposta |
|---|---|---|---|---|
| 1 | **Alta** | `port_demo.gd:425`, `save_store.gd:21-44` | **Selo do Céu pode travar depois de recarregar o jogo.** O altar compara `puzzles["stars"] == [1, 3, 2]`. O JSON devolve números como `float`, e a comparação de arrays do Godot também compara o tipo: `[1.0, 3, 2]` é diferente de `[1, 3, 2]`. Se o jogador acertar um obelisco, sair do jogo e voltar, o altar recusa o alinhamento correto até ele girar aquele obelisco quatro vezes. Como o selo é obrigatório, isso bloqueia o chefe. O `world_v6_test.gd` resolve o puzzle numa sessão só e não pega o caso. **Confirmado no Godot 4.7.2:** salvar `[1, 3, 2]` e recarregar devolve `[1.0, 3.0, 2.0]`, e o altar responde falso. | **Corrigido:** o altar converte as posições para `int` antes de comparar. A conversão no carregamento do save foi descartada, porque o `progression_test` compara o save recarregado com a versão em float. Teste: `tests/puzzle_reload_test.gd`. |
| 2 | Média | `port_demo.gd:386` e `:391` | **Erro dos sinos nunca aparece.** Ao tocar fora de ordem, o jogo mostra "A harmonia se desfaz. Recomece pela Lua." e na mesma hora o substitui por "Sinos: 0 de 3 notas", porque o `toast` do HUD guarda só a última mensagem. **Confirmado no Godot 4.7.2:** depois de tocar a Aurora primeiro, a mensagem na tela é "Sinos: 0 de 3 notas reconhecidas." | **Corrigido:** um único aviso por toque. Errar com a Lua agora diz que a sequência recomeçou com 1 de 3; antes, a mensagem "Recomece pela Lua" levava o jogador a repetir o mesmo erro. Teste: `tests/puzzle_reload_test.gd`. |
| 3 | Baixa | `port_demo.gd:487` | Depois de entrar nas Catacumbas, o objetivo manda "reencontrar o santuário pelo atalho", mesmo que a alavanca da guarita não tenha sido puxada. | **Resolvido com a Galeria do Eco:** depois das Catacumbas, o objetivo manda subir pela galeria e erguer a grade do santuário. |
| 4 | Baixa | `port_layout.gd:54` | O corredor do atalho, com 14 pisos, conta como sala `hub`; o HUD mostra "Santuário da Primeira Palavra" durante todo o corredor. | Dar ao corredor um nome próprio ou contá-lo como guarita na metade sul. |
| 5 | Baixa | `port_demo.gd:280`, `:282`, `:295` | Os textos terminam com "— Memória fictícia do Porto" e "Inscrição fictícia", na tela do jogo. O GDD só pede que as falas não sejam citações históricas (linhas 116 e 1110). | Retirar os rótulos da tela. |
| 6 | Média | `port_gate.gd`, `world_prop.gd` | **Senu desenhado atrás de portões e prédios** (achado jogando, 27/10/2026). Cada portão e cada construção grande tinham uma só profundidade, a do centro ou a da quina da frente. Perto da ponta de um portão comprido, ao lado da parede de um armazém ou sob um arco, Senu ficava atrás do objeto inteiro, e o objeto ainda ficava meio transparente, como um fantasma. A barraca, os caixotes pintados do armazém e o farol deixavam Senu entrar no desenho. | **Corrigido:** portões e fachadas largas (armazém, templo, arco, barraca e farol) são desenhados em fatias, e cada fatia usa como profundidade o ponto onde a própria arte toca o chão. A transparência só aparece quando a arte cobre Senu de verdade. A barraca e o farol ganharam base sólida do tamanho do desenho, e a base do armazém passou a incluir os caixotes da frente. Teste: `tests/depth_sort_test.gd`. |
| 7 | Baixa | `port_dressing.gd` | **Ruínas flutuando sobre a água.** Quatro muros decorativos estavam fora de qualquer piso: ao lado da ponte `(29,5; 16)`, junto à Alcova `(39,5; 20,5)`, ao norte da arena `(-6; 14,5)` e ao norte das Catacumbas `(-21; 19)`. Um pilar da arena estava dentro do buraco d'água `(-1; 18)`. | **Corrigido:** cada muro foi para a borda norte de pedra da sala mais próxima, e o pilar foi para `(-2; 18)`. Os demais objetos fora do piso são barcos e juncos, que ficam na água de propósito. |

## Riscos para a expansão

- **A ordem das salas importa.** `port_dressing.gd` decora com o gerador apenas `ROOMS.slice(13)`. Uma sala nova inserida no meio da lista desloca a decoração das outras. Salas novas sempre no fim de `ROOMS`.
- **Conteúdo do mundo dentro do arquivo compartilhado.** Itens, textos e a lógica dos puzzles estão em `port_demo.gd`. Cada puzzle novo obrigaria a mexer no arquivo que os dois usam. Proposta: uma única vez, em acordo com o Kauã, mover isso para `scripts/world/port_content.gd` (itens e textos) e `scripts/world/port_puzzles.gd` (regras). Depois disso, o `port_demo.gd` só chama esses arquivos e quase todo o trabalho de mundo fica na zona Mundo.
- **Coordenadas soltas.** Os círculos dos selos em `port_layout.gd:238-244` usam posições fixas fora de `MARKERS`.
- **Desempenho (baixa prioridade).** Cada interativo redesenha a cada 0,1 s mesmo longe da câmera ou já recolhido. O contorno do mapa cria um segmento de colisão por aresta de piso; segmentos alinhados podem ser unidos.

## Melhorias de mundo

1. **Identidade dos distritos novos.** Os 14 distritos da expansão usam o mesmo molde: quatro pilares nos cantos, tochas na borda de cima, arco, estátua e entulho. Cada um deveria contar o que foi:
   - Fornos: fornalhas e escória.
   - Estrada do Sal: carroças e montes de sal.
   - Observatório: astrolábios.
   - Arquivo: estantes e tabuletas.
   - Praça dos Sinos: um campanário visível de longe.
2. **Marcos visíveis de longe.** O farol, o campanário e o templo do Arquivo podem orientar o jogador sem abrir o mapa.
3. **Rota escondida do GDD.** O GDD prevê uma rota secreta do Armazém à Guarita (linha 366), que hoje não existe.

## História

### O que o GDD define

- **A Inversão** adoece o mundo: mortos voltam sem reconhecer parentes, estátuas falam, templos somem.
- **Senu**, discípulo de Hermes Trismegisto, procura o mestre **Iri** depois do ataque à ordem.
- **O Primeiro Copista** quer fundir todas as consciências com a Coroa do Silêncio.
- **Temas:** memória e identidade, mestre e discípulo, liberdade contra unidade imposta. Tom sombrio e melancólico.
- **A01 serve para ensinar** "exploração, combate e mistério das identidades roubadas" (linha 187), com "marinheiros sem memória".
- **Ligações:** A01 → A02 (Catacumbas do Eco) e A01 → A04 (Jardim das Formas, em Faium).
- **Princípio central** (linhas 1216-1218): ver um portão trancado, esquecê-lo, vencer um obstáculo e voltar por trás dele.

### Lacunas na demo

- **Nenhum NPC no mapa jogável.** O pescador da abertura conta que o irmão "nem lembra meu nome"; Senu promete voltar, mas o pescador nunca reaparece. O GDD pede NPCs com desejo próprio e estados que mudam (linhas 723-729).
- **O Porteiro Sem Nome não tem história.** Vencê-lo leva à mensagem "Você concluiu o percurso desta primeira demonstração"; o GDD pede um fechamento local, sem tela de "próxima fase" (linha 740).
- **Os "marinheiros sem memória" só aparecem como inimigos.**
- **A chegada não bate.** O GDD diz que Senu foi iniciado no Santuário (linha 339), mas na abertura ele precisa do pescador para achá-lo.
- **Não há sinal do caminho para Faium (A04).**

### Propostas (para discutir com o Kauã)

Ordem de prioridade do GDD (linha 1063): jogabilidade, mapa e atalhos, save, combate, chefe, narrativa, conteúdo extra, polimento. As propostas abaixo são narrativa: vêm depois dos bugs.

1. **O pescador e o irmão.** O pescador fica no Cais procurando o irmão. O irmão aparece como um esquecido não hostil no Embarcadouro Velho, repetindo os gestos do trabalho. A conversa muda depois de cada selo e depois do Porteiro, quando o irmão lembra um fragmento, talvez o nome do pescador. Fecha a promessa da abertura e mostra as "identidades roubadas" sem combate.
2. **Quem era o Porteiro Sem Nome.** O mapa já tem o Arquivo dos Nomes Velados. O Porteiro pode ter sido o escriba que registrava o nome de quem chegava ao porto, o primeiro a ter o próprio nome reescrito.
   - As três lembranças da porta seriam os três registros que ele guardava: o sino que anunciava os navios (Voz), a maré que regia as cargas (Maré) e as estrelas que guiavam as rotas (Céu).
   - Vencido, ele recupera o nome por um instante e fala do homem com o livro que desceu às Catacumbas. Isso dá o fechamento local e o gancho para A02.
3. **A trilha de Iri.** Duas ou três marcas deixadas por Iri pelo porto, no Arquivo, no Observatório e na Guarita, todas apontando para as Catacumbas. Mostram o laço entre mestre e discípulo sem revelar a culpa dele, que é revelação de A08 e A11.
4. **Moradores esquecidos.** Figuras não hostis no Mercado e no Cais repetindo frases cortadas. Depois do Porteiro, algumas lembram algo; isso faz o porto mudar com a campanha.
5. **O caminho de Faium.** O Portão das Caravanas já existe. Uma caravana parada "até alguém mapear o oásis" vira um portão visível e fechado para a ligação A01 → A04 no futuro.
6. **Conciliar a chegada.** Senu conhece o Santuário, mas chega por mar e não sabe se ele ainda resiste à Inversão. Isso é ajuste de fala na abertura, que é da zona Interface: combinar com quem a assumir.

## Galeria do Eco (feita em 27/10/2026)

É o atalho C03 do GDD (linha 315): uma grade aberta **pelo lado das Catacumbas** que devolve o jogador ao santuário. Cumpre o princípio das linhas 1216-1218: ver um portão trancado, esquecê-lo e voltar por trás dele.

- **No mapa:** duas salas novas no mar vazio, a Descida do Eco `(-19, 3, 3, 17)` e a Galeria do Eco `(-19, -4, 13, 7)`, mais duas aberturas: a borda oeste do Santuário (com a grade, em `x = -5,5`) e a borda norte das Catacumbas. Os 27 setores anteriores não mudaram de lugar nem de tamanho.
- **No jogo:** a grade fica visível e fechada desde o início. Depois do Porteiro, o jogador sobe pela descida, ergue a grade pela alavanca e sai no Santuário.
- **Decoração:** as salas novas têm `"generated": false` em `ROOMS`; o gerador de distritos as ignora e os objetos ficam na lista manual de `port_dressing.gd`, fora da linha de caminhada.
- **Save:** marca nova `echo`, falsa nos saves novos e acrescentada aos antigos ao carregar.
- **Alavancas:** `port_demo.gd` passou a ligar alavanca, marca e portão por `LEVER_FLAGS`, em vez de um caso especial por alavanca.
- **Testes:** `route_test` percorre fisicamente Catacumbas → descida → galeria, confirma que a grade fechada segura Senu, ergue a grade e volta ao santuário (137/137). `world_v6_test` confirma que, com a grade fechada, a galeria e as Catacumbas não são alcançáveis a partir do santuário (125/125).
- **Captura:** `-- --qa --capture-echo` grava `qa/porto_demo-echo.png`.

## Trilha de Iri e o pescador (feitos em 27/10/2026)

Conteúdo opcional, pedido para o porto "ter mais coisa para fazer". Nenhum setor mudou. A lógica e os textos ficam em `scripts/world/port_story.gd`, na zona Mundo. O `port_demo.gd` ganhou só três ganchos: o `preload`, `Story.build(self)` em `_build_objects()` e um caso em `activate()`.

- **Trilha de Iri:** quatro estelas com o sinal de Hermes, no Arquivo `(10, -31)`, no Observatório `(85; 30,5)`, no Santuário Soterrado `(-4; 35,5)` e na Guarita `(5; 27,5)`, lidas em qualquer ordem. Cada uma traz um recado de Iri para Senu, sobre a mão que reescreve os nomes, o céu que ninguém copia, a primeira lição e o caminho de volta, sem revelar a culpa de Iri (A08/A11). As quatro abrem o **relicário de Iri** no Santuário `(1; -3,5)`: o cordão de contas do mestre, um recado de que ele desceu às Catacumbas e +3 Fragmentos de Nous.
- **O pescador e o irmão:** o pescador da abertura, agora chamado **Hori**, fica no Cais `(12,6; 1,6)`. O irmão, **Sabu**, enrola cordas no Embarcadouro Velho `(27; 32,5)`, com cores apagadas.
  - **Passos:** Hori pede ajuda; Senu acha Sabu; Hori entrega o nó que o irmão lhe ensinou; Sabu reconhece o nó, mas o nome só volta depois do Porteiro; Hori recompensa com +2 Fragmentos de Nous.
  - **Depois:** Sabu passa a ficar no cais ao lado do irmão. Antes de alguém perguntar por ele, as falas de Sabu mudam a cada selo desperto.
  - **Arte:** os dois usam o sprite do pescador do Kauã (`assets/cinematics/rpg_v12/fisherman.png`); Sabu aparece espelhado e com outra cor.
- **Save sem migração:** o progresso fica em `collected`, com os ids `iri_mark_*`, `iri_relic` e `fisher_*`, e as recompensas usam `collect(id, n)`. Saves antigos abrem sem mudança, e o `save_store.gd` não foi tocado.
- **Diálogos:** usam `hud.show_dialog`. O aviso de missão também aparece na última linha do diálogo, porque o toast do HUD expira enquanto o diálogo pausa o jogo. Os retratos de diálogo do Kauã podem entrar depois, se a zona Interface quiser.
- **Tipo `npc`:** desenha uma figura (`figure`) a partir de folhas de sprite. A sessão de lojas combinou reaproveitar esse tipo para os lojistas.
- **Teste:** `tests/side_story_test.gd` cobre as posições (piso, espaço livre e salas certas), cada passo das duas histórias, as recompensas sem repetição e o estado depois de reabrir o save.

## Ordem sugerida

1. ~~Bugs 1 e 2~~: corrigidos em 27/10/2026, só em `port_demo.gd`.
2. Separar conteúdo e puzzles do `port_demo.gd`, em acordo com o Kauã.
3. Identidade visual dos distritos.
4. História: ~~o pescador e o irmão~~ e ~~a trilha de Iri~~, feitos em 27/10/2026. Falta o Porteiro (Sala dos Nomes).
5. Novas ligações: caminho de Faium. O atalho das Catacumbas já existe: é a Galeria do Eco.

## Ferramentas

Na máquina do Gustavo, o Godot 4.7.2 e o Pixelorama ficam em `A:\Ferramentas\` e não em Downloads; os atalhos `.cmd` não os encontram. Para rodar um teste:

```powershell
& "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --time-scale 4 --script res://tests/world_v6_test.gd -- --qa
```

A primeira importação neste computador reescreveu 35 arquivos `.import` só no fim de linha (LF/CRLF), sem mudar conteúdo. Esses arquivos não devem ir para commit: `git restore` neles. Acrescentar `*.import text eol=lf` ao `.gitattributes` evitaria o ruído; é arquivo compartilhado, então combinar com o Kauã.
