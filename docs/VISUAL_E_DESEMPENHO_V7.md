# Revisão de cenário e desempenho — 26/10/2026

O porto, a capa e o retrato agora seguem uma direção em pixels. O mapa conserva 27 setores, 4.346 pisos, 38 inimigos, os três selos e o progresso salvo.

## Critérios de arte

- Piso em losango 64×32, com quatro variantes por material e detalhes de desgaste discretos. Sem fotografias de materiais nem textura realista aplicada por cima.
- Objetos em resolução de mundo 1:1, degraus de contorno definidos, paleta comum de 33 cores, luz superior esquerda e cores compatíveis com a capa, o bronze e o linho do Senu.
- Pedra em tons cinza esverdeados; areia quente; madeira marrom; água verde-petróleo. O piso da cisterna deixou de ser uma grade dourada gigante.
- Água com oito cels de 128×128 a 8 fps, correnteza em pixels e espuma animada junto às paredes do cais. O chão de pedra permanece estável; o movimento vem da água, das chamas e dos atores.
- Sombras de contato encostam nos pés dos objetos. Arquitetura não é espelhada aleatoriamente. Barcos ocupam água, e bases de muros/armazéns apoiam-se na borda do piso.
- Capa 640×360 e retrato 160×192 desenhados em pixels, com a identidade do mesmo Senu. Janela padrão 1280×720 amplia o mundo 640×360 em 2×, sem filtro suave.

As fontes de arquitetura, capa e retrato foram criadas com ImageGen integrado, com referências do personagem. Pisos e água foram construídos como cels de baixa resolução; a preparação organizou os projetos nativos. O Pixelorama 1.2.3 instalado executou as exportações finais. Não houve desenho manual pela interface. Fontes e prompts integrais em `art/pixelorama/port_v7/ART_PROMPTS.md`.

## Correções de encaixe

O barco legado(38,35) bloqueava visualmente a nova ligação ao Cais do Cobre e foi deslocado para a água(38,39). Dois armazéns antigos em(40,1)/(40,7) haviam ficado dentro de Caravanas e foram removidos. Muros/armazéns foram apoiados nas margens; bases de armazém têm colisão. Inscrições, meditação, sinos, válvulas e obeliscos reutilizam a arquitetura, com símbolos de interação, sem antigos blocos bege.

## Medição real

GTX 1060 6GB, i5-7400, janela visível 1280×720, movimentação e combate reais em arquivo QA separado. Sem VSync, sem limite artificial de FPS, cinco segundos de aquecimento e cinco de coleta por região. Uma instância antiga do usuário permaneceu aberta nas duas medições. O limite normal de 60 FPS pode continuar habilitado no menu.

| Região | Antes | Depois | Tempo de quadro p 95 depois |
|---|---:|---:|---:|
| Santuário |20,1 FPS|237,6 FPS|5,24 ms|
| Cisterna |19,6 FPS|200,4 FPS|6,45 ms|
| Caravanas |19,6 FPS|227,9 FPS|5,64 ms|

As chamadas de desenho medianas caíram de cerca de 10.200 para 352–474. Nenhum quadro da coleta depois superou 33 ms. A física ficou em torno de 1 ms; o maior gargalo era desenhar todo o chão e a água, mesmo fora da tela.

O chão agora usa blocos 12×12, com limites de desenho próprios, permitindo descartar os setores fora da câmera. A água usa uma superfície com animação na GPU; deixou de reconstruir centenas de retângulos e linhas a cada 0,1 s. Inimigos parados reutilizam desenhos; a busca de pontos de navegação consulta primeiro a vizinhança local. Somente o atlas atual de Senu é carregado, com reserva antiga sob demanda.

Os resultados finais incluem os novos sprites dos inimigos. Dados em `qa/benchmark_world_v7_before.json` e `qa/benchmark_world_v7_final.json`; roteiro repetível `tools/qa/benchmark_world_v7.gd`. O corte da espada tem um atlas compacto próprio, carregado no primeiro golpe.

Validações de integração: mundo 124/124 com 9.458 passos físicos, HUD 19/19, espada 97/97, padronização 58/58, movimento 74/74, animações 27/27 e combate 26/26. A captura de 12 quadros do porto confirmou mudança na água em todos os quadros, com atores parados para isolar a superfície.

## Projetos editáveis

Exportações finais usadas pelo jogo:

- `D:/Nono_Veu/assets/world/port_pixel_v7.png`: pisos, arquitetura e água.
- `D:/Nono_Veu/assets/ui/port_title_v7.png`: capa pixelada.
- `D:/Nono_Veu/assets/ui/senu_portrait_v7.png`: Senu do menu.
- `D:/Nono_Veu/assets/sprites/port_enemies_v7.png`: sentinelas.
- `D:/Nono_Veu/assets/sprites/senu_sword_v7.png`: cortes de espada.

Modo de criação das novas imagens: ImageGen integrado. Prompts: `D:/Nono_Veu/art/pixelorama/port_v7/ART_PROMPTS.md`. Preparação dos cels em resolução nativa e exportação final pelo Pixelorama instalado.

- `art/pixelorama/port_v7/port_pixel_v7.pxo`: 52 cels, 32 variantes de pisos, 12 objetos e 8 quadros de água.
- `port_title_v7.pxo` e `senu_portrait_v7.pxo`: capa e retrato independentes.
- `ABRIR_MAPA_PIXELORAMA.cmd`, `ABRIR_CAPA_PIXELORAMA.cmd`, `ABRIR_RETRATO_PIXELORAMA.cmd` e `EXPORTAR_MAPA.cmd` abrem/exportam esses projetos.
- `art/pixelorama/enemies_v7/port_enemies_v7.pxo`: 16 poses de sentinelas, paleta do porto, exportação 512×512. Use `ABRIR_INIMIGOS_PIXELORAMA.cmd` e `EXPORTAR_INIMIGOS.cmd`.
- `art/pixelorama/senu/senu_sword_v7.pxo`: cortes reais de espada; documentação em `SENU_ESPADA_V7.md`.

Reabra `JOGAR.cmd` para recarregar scripts e imagens. O progresso real não é apagado.
