# O Nono Véu — progresso e backlog da demo A01

Atualizado em 25/10/2026. Referência: GDD v1.1 e `docs/DECISOES.md`.

## Situação registrada

- [x] GDD v1.1 lido integralmente e escopo da primeira demo delimitado.
- [x] Decisões técnicas e backlog inicial documentados.
- [x] Versões reais de Godot e Blender verificadas com `--version`.
- [x] Execução do projeto Godot e dos scripts Blender verificada.
- [x] Primeira demonstração jogável implementada e validada por testes automatizados e inspeção de capturas reais.
- [x] Cópia de trabalho transferida e conferida na pasta final `D:\Nono_Veu`.

O backlog abaixo foi registrado antes da implementação. Os sistemas essenciais da primeira demonstração estão implementados; evidências e limites da verificação constam em `docs/TESTES.md`. A aprovação de balanceamento por uma partida humana ainda está pendente.

## Backlog em ordem de entrega

| Etapa | Trabalho | Aceite observável |
|---|---|---|
| 0 — Ambiente | Confirmar os dois executáveis e suas versões; criar estrutura mínima, cena principal, ações de entrada e instruções de execução. | Godot importa e abre a cena inicial sem erros. Registrar versão, comando e resultado. |
| 1 — Espaço jogável | Montar H0/P1 com chão isométrico, paredes, obstáculos, câmera e personagem original; movimento em oito direções e interação contextual. | Movimento diagonal normalizado; personagem colide no chão e passa à frente/atrás dos objetos com ordenação coerente. |
| 2 — Combate | Vida, dano, preparação/ataque/recuperação, Khopesh por `Resource`, ataque leve/forte, esquiva, parry, inimigo e respawn. | É possível lutar, desviar, aparar, receber dano, morrer e voltar ao checkpoint. Sinais de ataque são legíveis. |
| 3 — Loop do mapa | Ligar P1–P4, S1 e hub; portão inicialmente fechado, alavanca acionável pelo lado distante e atalho físico. | O jogador reconhece o hub ao abrir o retorno; porta mantém seu estado ao sair e voltar. |
| 4 — Progressão e arma alternativa | Nous único, três nós opcionais de custos 1/1/2, pickup de Adagas, troca e UI de arma/categoria/poder. | Duas armas de categorias diferentes têm ações distintas; compra valida custo/requisitos e aplica efeito uma vez; avanço não exige build específica. |
| 5 — Persistência | Save versionado e atômico em `user://`, backup, autosave por evento, checkpoint, pickups, saldo, habilidades, armas, atalho e chefe. | Fechar e reabrir mantém os avanços; morte não perde moeda nem duplica pontos ou armas; carregamento inválido tem recuperação segura. |
| 6 — Chefe e encerramento | Porteiro Sem Nome com dois padrões e recuperação; inscrição original; porta final para mock de A02. | Jogador vence por leitura dos ataques, atravessa a nova porta e pode voltar ao hub. Chefe vencido e porta liberada persistem. |
| 7 — Verificação da demo | Rever importação, erros de execução, jornada completa, controles, UI, colisões e persistência; corrigir problemas encontrados. | Percurso completo do início ao chefe e retorno, com salvamento/reabertura, validado de fato. Registrar limites restantes. |
| 8 — Prova Blender/Godot | Smoke test sem alterar arquivos externos; blockout de Senu por script; render PNG transparente e integração de teste. | Fonte/script/export reproduzíveis, escala/pivô corretos e imagem legível em tamanho real. |
| 9 — Build Windows | Verificar templates compatíveis e exportar somente quando disponíveis. | Executável abre e permite iniciar a demo. Ausência de templates deve ser registrada, sem declarar export concluído. |

## Checklist de aceite integrado

- [x] Hub e A01 formam um percurso com retorno físico aberto pelo lado oposto.
- [x] Movimento, câmera, colisões e ordenação por Y são coerentes.
- [x] Ataques leves/fortes, esquiva e parry respondem aos controles documentados.
- [x] Inimigo comum e chefe anunciam seus golpes e possuem recuperação.
- [x] Khopesh e Adagas diferem em comportamento, sem resíduos de ataque após troca.
- [x] Categoria pesada é reconhecida pelo modelo de dados; não é apresentada como arma jogável sem implementação.
- [x] Pickup de Nous e pickup de arma são únicos após morte, transição e load.
- [x] Compra da habilidade consome saldo e aplica o efeito uma única vez.
- [x] Nenhum gate obrigatório depende da compra opcional ou da arma alternativa.
- [x] Checkpoint restaura o jogador com segurança e preserva avanços permanentes.
- [x] Atalho aberto e chefe morto persistem depois de fechar e reabrir.
- [x] UI mostra vida, Nous, arma equipada e informações de interação sem ocultar combate.
- [x] Porta liberada pelo chefe conduz a uma entrada demonstrativa de A02.
- [x] Prova do Blender tem comando, fonte e export reproduzíveis, se executada nesta entrega.
- [x] Limitações e validações não executadas estão identificadas antes de entregar.

## Registro de verificações

| Verificação | Resultado |
|---|---|
| Godot | 4.7.2.stable.official.ed1daf0bf, renderer Compatibility/OpenGL 3.3, GTX 1060. |
| Blender | 5.2.3 LTS, build e13b728c6880. |
| Importação e execução | Sem erros; cena principal executada por 120 quadros. |
| Combate | 26 verificações aprovadas. |
| Percurso | 39 verificações aprovadas; IA isolada para testar navegação. |
| Persistência/progressão | 111 verificações aprovadas; slots de teste separados. |
| Inspeção visual | Capturas reais do menu, jogo, árvore e arena conferidas. |
| Blender/Godot | Modelo e atlas gerados; cena de prova executada sem erros. |
| Partida humana/balanceamento | Pendente. |
| Exportação independente | Não realizada; templates ausentes. |
| Pasta final | 56 arquivos copiados e conferidos por SHA-256; projeto importado e executado em D:\Nono_Veu sem erros. Repositório Git local iniciado na branch main, sem commits. |

## Próximas etapas após aceite

Expandir A02–A04 e a Visão do Reverso somente depois de estabilizar a demo. Avaliar arte pré-renderizada, terceira arma pesada, relíquias e domínio em incrementos separados. Manter propostas de balanceamento, resolução e produção artística ajustáveis por testes.

## Resultado da primeira implementação

Concluídos: cena principal, movimento/câmera/colisões, profundidade visual, combate, duas armas, inimigos, chefe com dois padrões, percurso H0/P1–P4/S1/B1/A02 de teste, atalho físico por alavanca, três Nous, três melhorias, mapa descoberto, checkpoints e save com backup. Foram aprovadas 26 verificações de combate, 39 de percurso e 111 de persistência/progressão. Menu, jogo, árvore e arena foram revisados em capturas reais do Godot. O Blender gerou `.blend`, atlas PNG e metadados; a cena de prova foi executada no Godot. Veja `docs/TESTES.md` para comandos e limites.

Continuam pendentes: teste humano de dificuldade e sensação de controle, IA com cálculo de caminhos, animações/arte final, áudio, gamepad, relíquias, terceira arma, demais áreas e build independente. O personagem Blender é uma prova de idle em cena separada; não substitui as animações do personagem jogável.

## Expansão e visual — 25/10/2026

- [x] Porto ampliado de 158 para 1.287 células caminháveis, com treze setores e dois atalhos físicos.
- [x] Mercado, jardim inundado, alcova, embarcadouro, ponte e aqueduto conectados à rota principal.
- [x] Arquitetura com fachadas, arcos, barcos, palmeiras, bancas, tochas e oclusão transparente do herói. Pisos de pedra/mosaico/areia/madeira; água animada separada do piso estático.
- [x] Senu v2 integrado: corpo renderizado no Blender, oito direções e 64 quadros; armas em camada independente. Prancha conceitual e fonte `.blend` preservadas.
- [x] Novas pistas e relicário opcional, checkpoint intermediário e mapa de descoberta escalável.
- [x] Salvamentos anteriores preservados; Nova jornada arquiva o estado antigo antes de reiniciar.
- [x] Combate26, percurso121, progressão111 e migração/menu/segredo31: 289 verificações aprovadas. Inspeção de capturas reais do Godot concluída.

O registro da primeira implementação acima é histórico. A prova antiga de idle foi sucedida pelo Senu v2 jogável. Detalhes: `docs/DESIGN_SENU.md`, `docs/MAPA_A01_V2.md` e `docs/TESTES.md`.

## Sprites fornecidos e Pixelorama — 25/10/2026

- [x] Quatro folhas enviadas pelo usuário preservadas em `art/pixelorama/senu/sources/`.
- [x] Projeto nativo `art/pixelorama/senu/senu_v3.pxo` preparado para Pixelorama 1.2.3, com 124 quadros únicos e 75 tags.
- [x] Exportação real do PNG e dos metadados pelo próprio Pixelorama, com efeitos nativos de limpeza de halos.
- [x] Apresentação do Khopesh organizada em nove estados e seleção em oito direções, usando vistas próximas ou espelhadas nas orientações ausentes.
- [x] Atalhos para abrir o projeto no Pixelorama e reexportar ao Godot; recurso SpriteFrames com durações da linha do tempo preservadas.
- [x] Versão final conferida no Godot: combate 26/26, animações 27/27, captura no mercado e prancha com nove estados; quatro originais conferidos por SHA-256.

O programa foi utilizado pelo modo automatizado de exportação, pois o controle de sua janela não ficou disponível. Os quadros vêm das imagens fornecidas e não foram redesenhados do zero. As Adagas conservam a apresentação v2 até haver sprites compatíveis sem a Khopesh incorporada. A caminhada frontal ainda precisa de quadros adicionais. O registro de verificações v3 é separado dos resultados históricos acima, em `docs/TESTES.md`.

## Fluidez e Adagas v4 — 25/10/2026

- Projeto nativo v4 com variantes de Khopesh e Adagas, mantendo o canvas e o pivô dos pés.
- Caminhada de 12 quadros em cada direção para ambas as armas e repouso com quatro quadros, preparados por deformação de partes e poses de referência.
- Artes próprias das duas Adagas, com folhas de direções e combate geradas a partir da identidade do Senu; originais e prompts preservados.
- Fase da passada mantida ao virar ou trocar de arma, recuperação visual ajustada à ação e segundo impacto das Adagas sem reiniciar a animação.
- Regras de movimento, colisão e dano preservadas. A validação final está em `docs/TESTES.md`.
- [x] Exportação final pelo Pixelorama: 603 quadros, 145 tags e duas variantes; atlas importado no Godot.
- [x] Combate 26/26, animações 27/27 e integração v4 40/40: 93 verificações aprovadas; 16 ciclos com 12 imagens distintas conferidos no PNG final.
- [x] Adagas conferidas no mapa, prancha com nove estados e prévia animada renderizada no Godot.
