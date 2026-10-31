# Estado atual — O Nono Véu
Atualizado em 2026-10-30; base principal neste computador: `D:\Nono_Veu`; Gustavo usa `A:\nono veu`.

## Funcionalidades existentes
- Porto dos Esquecidos: 33 setores, atalhos, três puzzles de selos, Porteiro Sem Nome em duas fases e limiar demonstrativo das Catacumbas.
- Senu: oito direções, caminhada/corrida, esquiva, ataques leves/fortes, parry e riposta; Khopesh/Adagas com corpo compartilhado e poderes próprios; 13 habilidades.
- Combate com efeitos, áudio, XP, óbolos e coleta física; 45 inimigos no mapa expandido (614 XP e 311 óbolos no catálogo do PR).
- Moradores v3: 12 aparências do Kauã e quatro em `townsfolk_v3_extra.png`; nomeados/Ankhet preservados; aves, cães e gatos com fuga e colisão.
- Comércio, quatro interiores, missões de Merit/Nakht/Adiam/Tarek; Hori/Sabu concluível sem chefe e quatro marcas de Iri até o relicário.
- Claustro dos Iniciados; barco até Bennu, Íbis Afogado e Recife do Navio Esquecido; 96 peças adicionais e vida nas novas áreas.
- Mar com seis crocodilos do Nilo/Sobek, casco de 100, naufrágio, nado e escadas; perímetro dos píeres seguro. Mergulho (Espaço): fôlego em bolhas, fundo com ruínas, casco do Recife, 5 ânforas e uma estela; nado animado (braçada de peito na superfície, corpo deitado ou pernada no fundo, 8 direções); água rasa mais clara perto do chão e sem emendas. Novos progressos usam IDs em `collected`.
- Ambientação por setor (som, vento, zumbido sagrado e luz), 20 perfis e Mendigo das Cordas com alaúde; retratos de um quadro aceitos nos diálogos.
- Abertura do cais preservada, pulável segurando Espaço por 3 s; balões seguem o falante, até quatro linhas; fonte Pixel Operator e bustos vivos.
- HUD minimalista; pausa em caderno com inventário, habilidades, mapa e missões; aprender exige segurar 1,5 s; controles em Configurações.
- Somente torres gravam, curam/recarregam e renovam inimigos comuns; chefes vencidos ficam no estado ancorado. Sair/fechar e morrer não gravam.

## Integração e trabalho local
- PR #11 aprovado: principal atualizada de `3135f61` para `49256ed` por fast-forward, sem novo commit/push. Documentos conciliados e nenhum conflito pendente. Godot importou/abriu; menu e Cais capturados em QA. Pronto para teste pelo `JOGAR.cmd`; relatório em `docs/INTEGRACAO_PR11.md`.
- Antes da atualização, 84 arquivos locais preservados por SHA-256 e ZIP em `qa/pr11_integracao_49256ed/`; stash de segurança dos dois documentos mantido. Fontes/arte locais de NPCs e Porteiro não foram substituídas pelo PR.
- Caminhada NPC v4 local: 192 cels, oito fases por aparência/modo, ciclo por 24 px; fontes e edições manuais preservadas. Atlas/manifesto existem aqui; os quatro novos moradores usam a folha extra. QA atual: caminhada64, atlas1453, rotinas367, v32468 e extra302, todos aprovados com a expansão.
- Casco v4 preservado: comprimento 74, boca 28, interior maior e remos/Senu mantidos; fonte `sea_v4`. Embarque/desembarque: seis poses em oito vistas, sem loop, pivô fixo. QA atual: barco75, transições85 e perigos/naufrágio/nado355; validação anterior da arte: casco482 e atlas683.
- Porteiro integrado à partida normal: nove ataques JSON, duas fases, parry explícito, ecos/zonas/correntes sinalizados, impactos de pedra/poeira, introdução/transição/morte humana, portões e câmera. Vitória conserva os IDs antigos e só grava na próxima torre; 2 Nous e chave-lança únicos, sem liberar habilidades do Reverso. Hori/Sabu e quatro marcas preservados. Detalhes: `docs/PORTEIRO_SEM_NOME.md`.
- Arte v9: 1.336 cels/oito vistas/cinco camadas; corpo57 px, pivô96,144 em192², atlas2048×2208 (~18 MB). Costas refinadas: cabelo/nuca separados da gola, manto sobre o dorso, dobras diagonais e abertura assimétrica; braços independentes. Cinco vistas frontais/laterais e rosto v3 mantidos pixel a pixel; caminhada16/fechamento32 por distância. Dificuldade atual:720 PV, velocidade46/54,28, fase2 em1,10×, pausas adicionais0,28/0,16 s, dano22–52/eco18. `TESTAR_PORTEIRO.cmd`: QA; `JOGAR.cmd`: normal. Fontes `porteiro_live_v9`; provas/capturas/GIFs `qa/porteiro_refino_v9/`. Senu/inimigos comuns preservados.
- QA v9: combate67, IA autônoma24 (velocidades físicas46/54,28), persistência27 e pixels5062 aprovados. Rodadas anteriores desta integração: UI6, ataques104, caminhada68, ensaio33, pixels antigos853, percurso139, progressão125, missões72, história56, mundo134 e regressões de HUD/inventário/combate aprovados. Algumas suítes avisam sobre recursos retidos ao sair. Música/sinos/correntes/passos originais; vozes usam respirações sintéticas provisórias. Chave-lança visível no inventário; equipar/Último Chamado aguardam suporte de animação/arsenal. Balanceamento e atuação precisam de avaliação humana.
- Pós-integração: 33 suítes, 9.430 verificações aprovadas. Progressão125, migração34, casas56 e atlas1453 atualizados para torres/popup/catálogo; fade de áudio129 usa tempo decorrido. Percurso139, mundo134, chão2007 e profundidade293 passaram. Logs/resultados em `qa/pr11_integracao_49256ed/`; progresso real não usado, avisos de recursos retidos permanecem em algumas suítes. STATUS local anterior preservado nessa pasta.
- Chão v8 (Gustavo): texturas contínuas por tema na paleta das construções; paredões com blocos; arena em calcário claro para o Porteiro destacar. Ajuste posterior: contraste do piso quase pela metade (tons por manchas), cripta em lajes 2×1, terra do jardim clara, transição em grãos agrupados de até um tile e viga onde o píer encontra outro chão. Gerador `build_ground_v8.gd`; detalhes em `docs/MUNDO_CHAO_V8.md`, capturas em `qa/chao/` e `qa/chao_ajuste/`.

## Pendências conhecidas
- Cinco testes foram conciliados com os contratos vigentes, sem mudar regras do jogo; revisão visual/humana de áudio e movimentos continua necessária. Detalhes e resultados no relatório de integração.
- Senu quadro a quadro: produção não iniciada; captura do canvas Pixelorama falhou nas duas interfaces. Sem novos quadros dessa tarefa; retomar apenas com canvas visível e validar um ciclo antes das oito direções.
- Galeria do Eco: percurso atual passou139/139; falha antiga108/109 não se reproduziu, sem correção de navegação.
- `title_menu_test` pode falhar no áudio de seleção sob carga. `map_ground_test` dá 2010/2011: Senu não consegue parar na frente de `gatekeeper_record_02`; a falha já existia antes do ajuste do chão. Alguns testes emitem avisos de instâncias/recursos retidos ao encerrar.
- Retratos dos moradores ainda divergem da v3; Caravaneiro usa retrato do cervejeiro. HUD chama todo o mar de Baía das Garças; Arquivo/Sinos/Observatório usam molde comum.
- Caminhos dos moradores ainda não enxergam fixtures/estelas das ilhas; entrar na água de propósito só pelo barco parado (Espaço), ainda não pelo píer.
- Avaliar leitura dos balões/caderno e sutileza dos movimentos; apoios dos móveis não foram revalidados nesta integração. README/históricos ainda têm regras antigas de autosave.
- Campanha/arsenal completos, relíquias, gamepad e exportação independente continuam pendentes; GDD inclui conteúdo futuro.

## Próximos passos
1. Jogador testar a versão principal integrada pelo `JOGAR.cmd`, incluindo Claustro, ilhas, píeres, casco e nado; guardar avanços meditando em uma torre.
2. Avaliar a luta completa pelo `TESTAR_PORTEIRO.cmd` (progresso separado), especialmente dificuldade nova, leitura dos golpes e caminhada; o mesmo chefe já está no `JOGAR.cmd` após os três selos. Salvar a vitória normal em uma torre.
