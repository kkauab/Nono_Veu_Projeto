# Integração local do PR #11

Base: `D:\Nono_Veu`, 2026-10-30. Pedido do Kauã: resolver a integração antes de continuar o Porteiro e deixar a versão principal pronta para teste.

## Estado Git e preservação

- [PR #11 — Vida no Porto, Claustro, ilhas Íbis e Recife e mar perigoso](https://github.com/kkauab/Nono_Veu_Projeto/pull/11) já estava incorporado a `origin/develop` no commit `49256edf6948dac564974d77bc40781a4e9db362`.
- A versão local estava em `3135f61`, oito commits atrás. Não havia merge em andamento ou arquivos não resolvidos antes da atualização.
- Atualização feita por **fast-forward** para o commit aprovado. Nenhum commit novo ou push realizado.
- Sobreposição local/remota em `docs/STATUS.md` e `docs/DECISIONS.md`. Somente esses dois documentos foram guardados temporariamente em stash; as alterações de NPCs e estudos do Porteiro ficaram na pasta principal.
- `DECISIONS.md` combinou automaticamente. `STATUS.md` precisou de conciliação: reúne o mapa/mar novos, o trabalho local de NPCs/barco, o estado real da arte do Porteiro e as pendências de ambas as versões; permanece abaixo de 40 linhas.
- Cópia anterior de **84 arquivos locais**: `qa/pr11_integracao_49256ed/alteracoes_locais.zip`; índice SHA-256 em `hashes_antes.json`. As duas versões locais anteriores dos documentos e suas bases também estão nessa pasta. Stash de segurança mantido.
- A pendência do PR sobre o atlas de caminhada ausente no remoto não representa ausência nesta máquina: PNG, JSON, manifest e `.pxo` locais foram preservados e devem ser verificados junto da expansão.
- Os estudos v1/v2 do Porteiro continuam isolados, sem substituir o chefe na partida. O jogador rejeitou o perfil v1 e a caminhada atual; não representam arte aprovada.

## Conteúdo recebido

Claustro dos Iniciados, Ilha do Íbis Afogado, Recife do Navio Esquecido, vida nas novas áreas, moradores adicionais em atlas separado, fauna, perfis de ambientação, alaúde e perigos do mar. O mar inclui crocodilos, dano ao casco, naufrágio, nado e escadas de saída sem liberar portões da progressão. Detalhes de design em `MUNDO_PROPOSTA_2026-10-30.md` e `MUNDO_BARCO_ILHA.md`.

## Verificação pós-integração

Concluída: **33 suítes, 9.430 verificações aprovadas**, todas com saída 0 nas execuções finais. Importação Godot 4.7.2 e execução gráfica também com saída 0, sem erro de script. Menu e Cais capturados e inspecionados em `menu_integrado.png` e `cais_integrado.png`. Nenhum conflito no índice, nenhum merge em andamento, `develop` coincide com `origin/develop` no commit aprovado; alterações locais continuam disponíveis sem commit.

Logs, `verificacao_final.json` e tabela completa em `qa/pr11_integracao_49256ed/`. Testes do mundo usaram `-- --qa` e slots próprios em `user://qa/`; nenhum progresso real carregado ou gravado. O percurso completo passou 139/139, o mundo com movimento real 134/134 (`physical_steps=9677`, sem `--logic-only`), chão 2007/2007 e profundidade 293/293.

Preservação final: **81 dos 84 arquivos locais idênticos por SHA-256**. Os outros três são `STATUS.md`, `DECISIONS.md` e `PORTEIRO_SEM_NOME.md`, atualizados intencionalmente para a conciliação e a orientação do jogador. Nenhum arquivo ausente. Metadados de importação que só diferiam pela representação local foram comparados com o hash do blob aprovado, copiados para `metadados_reimportados.zip` e normalizados; nenhum ajuste de importação real do jogador foi removido.

### Ajustes de compatibilidade nos testes

| Teste | Ajuste | Execução final |
|---|---|---:|
| `npc_walk_assets_test.gd` | Mantém as 12 aparências originais e verifica que as quatro anexadas recusam esse atlas, permitindo a folha extra. O teste próprio da extra confirmou as quatro aparências no renderizador. | 1453/1453 |
| `progression_test.gd` | Confirma vitória ainda não ancorada e medita numa torre antes de comparar sessão com disco. | 125/125 |
| `save_migration_test.gd` | Confirma ausência de autosave, ancora na torre e encontra `ConfirmNewJourney` dentro do popup atual; também verifica reinício, abertura e arquivo da jornada anterior. | 34/34 |
| `house_interior_test.gd` | Abrir o baú não grava; a recompensa é conferida no disco depois de sair da casa e meditar na torre. | 56/56 |
| `ambience_places_test.gd` | Conserva o limiar de redução do som na pausa, aguardando até 1,5 s em vez de 30 quadros, cujo tempo varia no modo headless. | 129/129 |

As primeiras execuções reproduziram as expectativas antigas de saves/popup, a incompatibilidade do catálogo e o tempo insuficiente do teste de áudio. Os logs iniciais foram preservados; as execuções corrigidas têm sufixo `_corrigido`. **Nenhuma regra de combate, salvamento, moradores ou áudio do jogo foi alterada por esses ajustes.**

Outras coberturas aprovadas: perigos do mar355, barco75, embarque85, ilhas novas107, Claustro38, Bennu59, moradores367, aves469, animais118, fauna163, ambiente/alaúde37, combate26, habilidades44, torres28, popup32, HUD20, abertura24, missões72, história56, caminhada64, NPC v32468, NPC extra302, inventário26, menu25.

Limites: algumas suítes ainda emitem avisos de instâncias/recursos retidos ao encerrar, apesar das verificações aprovadas. Os testes não substituem ouvir e jogar. Divergências de retratos, nome genérico do mar, navegação de moradores perto das fixtures das ilhas e ausência de entrada voluntária na água continuam pendências do conteúdo recebido. Arte/combate novos do Porteiro não fazem parte desta validação e permanecem em revisão.

## Teste do jogador

Usar `JOGAR.cmd` na pasta principal. Novos conteúdos a conferir: Claustro próximo ao santuário, novas ilhas pelo barco, segurança junto dos píeres e comportamento do casco/nado longe deles. Somente a meditação numa torre conserva os avanços entre sessões, conforme a regra existente. A implementação do Porteiro permanece suspensa para esse teste, com caminhada a refazer e estocada seguindo a atuação do lanceiro comum.
