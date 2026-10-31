# Decisões vigentes — O Nono Véu
Consolidação em 2026-10-29. Registra escolhas duradouras; andamento fica em [STATUS.md](STATUS.md).

## Documentação e contexto
- AGENTS é o ponto de entrada curto; STATUS contém somente estado, pendências e próximos passos. Abrir documentos específicos conforme a tarefa, sem carregar todos os históricos.
- O [GDD completo](O_NONO_VEU_GDD.md) permanece intacto como referência de design/narrativa, com propostas e conteúdo futuro. Sua antiga exigência de leitura integral não faz parte do fluxo atual; consultar seções pertinentes.
- Instruções atuais do usuário orientam o trabalho. Código e verificações confirmam o que existe; não apresentar planos do GDD como funcionalidades prontas.
- `DECISOES.md` e `PROGRESSO.md` preservam o histórico inicial. Trechos antigos do README sobre autosave/“salvar e sair” foram superados pelas regras abaixo.

## Projeto e colaboração
- A entrega principal fica em `D:\Nono_Veu` na máquina do Kauã e em `A:\nono veu` na do Gustavo. Worktrees são áreas de trabalho distintas; integrar somente mudanças pertinentes após conferir a versão principal e preservar alterações de terceiros.
- Godot 4.7/GDScript, GL Compatibility e apresentação 2D isométrica. O mundo renderiza em 640×360; a interface usa a janela e fontes no tamanho final para manter legibilidade.
- `port_demo.gd` coordena; comportamento específico pertence aos módulos. Definições de armas são recursos; desbloqueios, equipamento e progressão pertencem ao estado da jornada.
- O fluxo de colaboração e as zonas de Kauã/Gustavo estão em [COLABORACAO.md](COLABORACAO.md); esta documentação não autoriza operações Git por si só.

## Direção visual e diálogo
- Preservar os modelos de sprites existentes, inclusive Senu nas duas armas e na prévia do caderno. Referências visuais orientam a composição, sem acrescentar equipamentos ou estatísticas fictícias.
- Fontes editáveis no Pixelorama e exports no Godot; nearest para sprites. No piso 2:1, base, sombra, colisão e profundidade devem representar o mesmo contato físico; interiores atuais usam o atlas v4.
- Abertura obrigatória ao iniciar nova jornada, com opção de pular segurando Espaço continuamente por 3 s. Retratos sem fundo, atrás da caixa; apenas o falante anima, com atuação independente da digitação. Ver [sistema de diálogo](SISTEMA_DIALOGO_RETRATOS.md).
- Reutilizar o padrão documentado de morte, fragmentos e moedas ao criar efeitos compatíveis: [guia](GUIA_ANIMACOES_REUTILIZAVEIS.md).
- O chão usa a mesma família de cores das construções (madeiras, arenito ocre/oliva, areia, dourado; cinzas frios só na cripta) e é uma textura contínua por tema, sem borda por tile: ver [chão v8](MUNDO_CHAO_V8.md).

## Interface e progressão
- A pausa inteira é um caderno; página inicial mostra Senu. Inventário usa slots selecionáveis e prévia com descrição/estatísticas reais. Controles ficam dentro de Configurações; saída não oferece salvar. Ver [caderno v8](CADERNO_PAUSA_V8.md).
- A árvore contém 13 nós; seleção mostra detalhes e aprender exige pressão contínua de 1,5 s. Cancelar não cobra; concluir compra uma única vez após validar saldo/requisitos.
- Só a interação com torres grava a jornada. Coletas, compras, missões, habilidades e puzzles atualizam a sessão; sair/fechar não salva. Descanso bem-sucedido restaura vida/cargas e renova inimigos comuns, preservando chefes vencidos no estado ancorado.
- Nova jornada arquiva o último progresso em disco e mantém o slot anterior até sua primeira torre. Preservar IDs e migração de saves; nunca converter alterações não salvas em backup persistente. Ver [persistência](SALVAR_NAS_TORRES.md).

## Áudio e Música
- Sons ambientes e instrumentais são sintetizados em Python puro determinístico (sem dependências externas), com loops contínuos marcados por blocos `smpl` no cabeçalho WAV.
- O sistema `VeilAmbient` orquestra o vento do porto e a aproximação de templos no bus `Ambiente`. Músicos de rua usam `AudioStreamPlayer2D` com atenuação espacial no bus `Musica`.
- Cada setor tem um perfil em `ambient_profiles.gd` (leito sonoro, vento, zumbido sagrado e luz por `CanvasModulate` no mundo, sem afetar o HUD). O zumbido toca só nos lugares sagrados; no barco valem os perfis de mar.

## Mundo, fauna e moradores
- Áreas novas (Claustro, Ilha do Íbis, Recife) vivem em módulos próprios (`cloister*.gd`, `far_isles*.gd`). Suas interações reaproveitam o tipo `isle_altar`, sem tocar `port_demo.gd`. O progresso vai em `collected` com ids próprios, sem campo novo no save. Recompensas não dão Nous.
- Poleiros de aves ficam presos a uma peça real do cenário, com a altura medida na arte; sem a peça, o poleiro é desligado. Aves e animais usam escala 1 e pivô nos pés. A leitura de ameaça de Senu fica em `fauna_threat.gd`.
- Moradores usam a folha v3 do Kauã. Aparências além das 12 dela ficam numa folha nossa (`townsfolk_v3_extra.png`), sem editar o binário do Kauã.
- Perigos do mar (crocodilos) não são inimigos do porto: módulo próprio (`sea_beasts.gd`), fora do grupo "enemies" e sem tocar `enemy.gd`. A água em volta dos píeres é segura para embarcar e atracar.
- Senu na água: controles de combate desligados e corpo movido pelo módulo do mar, preso pelas mesmas bordas que seguram o barco; `player.gd` não muda. Escadas só em chão alcançável com todos os portões fechados (santuário e píeres), para o mar não pular puzzle, atalho nem chefe. Subindo num chão com píer, o barco vai para esse píer (ninguém fica preso numa ilha).

## Verificação
- Separar QA do progresso real: mundo com `-- --qa`, dados exclusivos em `user://qa/`. Verificar somente o escopo alterado e distinguir execução automatizada de conferência visual/humana.
- Novos resultados substituem conclusões antigas; não supor que uma suíte inteira passa por haver registros históricos. Comandos e limites: [TESTES.md](TESTES.md).

## Porteiro Sem Nome — escopo solicitado em 2026-10-30
- O Porteiro é o primeiro grande chefe de A01, na Guarita do Retorno, e não encerra o Capítulo I. Sua aparência permanece humana nas duas fases; a mudança é de comportamento e atuação. Concepts fornecidos pelo jogador orientam o visual; o pedido escrito determina narrativa/escopo.
- Preservar as quatro marcas de Iri, o relicário, os diálogos existentes e as duas rotas de memória parcial de Hori/Sabu (sino ou vitória, com cordão e conversas). A vitória não cura a Inversão nem desbloqueia habilidades avançadas do Reverso.
- Produção local com ferramentas gratuitas e recursos originais, sem APIs pagas. O jogador autorizou continuar até a integração completa enquanto estava ausente. Animações de Senu preservadas; arma pesada tem integração modular enquanto não houver suporte visual compatível. Implementação e limites em [PORTEIRO_SEM_NOME.md](PORTEIRO_SEM_NOME.md).
- Direção de atuação solicitada para a estocada do Porteiro: seguir o lanceiro comum — empunhar, preparar o corpo, estocar e recuperar. Caminhada e perfil ainda exigem avaliação visual; os estudos locais v1/v2 não são arte aprovada.
- Presença do Porteiro: priorizar a qualidade da silhueta, volumes e materiais no mapa, usando os concepts do jogador. Na revisão v4, preservar o rosto/cabelo da v3, preferido explicitamente pelo jogador, junto aos refinamentos do manto e bronze.
- Golpes do Porteiro: cada um possui clipe corporal próprio e contato definido no JSON; avisos, efeitos e alcances compartilham esses dados. Reutilizar CombatFx e o pool de áudio; o ator aplica dano pelos contatos, o desenho nunca concede progresso. Caminhada usa deslocamento real e navegação existente. Oito vistas nativas têm atlas compacto e offsets que preservam os pivôs; revisão ativa v9, com fontes e ensaios anteriores separados.
- Ataques longos identificam explicitamente o agressor e o resultado da defesa. A janela base de parry permanece 0,25 s; os primeiros 0,10 s dão o desequilíbrio maior do Último Nome. Cancelar um golpe remove seus contatos, ecos, partículas e vozes próprias, sem apagar efeitos de Senu.
- Silhueta do Porteiro: ombros/cintura/pernas legíveis, túnica em abas e manto assimétrico; evitar coluna vermelha uniforme. Costas devem distinguir cabelo/nuca/gola e mostrar manto sobre o dorso, com braços/arma em profundidades separadas. Placas pendem ao longo do cinto, sem barra lateral. Preservar rosto v3 e densidade/pivô; fontes anteriores ficam separadas para comparação. Exports antigos só são reutilizados após comprovar igualdade dos pixels nativos.
- Porteiro só confirma `porteiro`/`flags.boss` após a morte narrativa; `gatekeeper_reward` e `gatekeeper_key_spear` são marcadores únicos em `collected`. Vitória e recompensa são ancoradas juntas pela próxima torre. Saves antigos oferecem recuperação explícita nos pertences. Chave-lança é um pertence de classe pesada, sem botão de equipar nem poder funcional até haver suporte no arsenal.

## Chão, mar e mergulho — 2026-10-30
- O chão recua atrás das figuras: tons vizinhos de valor parecido, variação por manchas e juntas longe do escuro dos contornos (faixa p5–p95 de cada tema perto de 50). Madeira não se mistura em pontilhado com outro chão: termina numa viga. Detalhes em [MUNDO_CHAO_V8.md](MUNDO_CHAO_V8.md).
- No mar, **Espaço** salta do barco parado, mergulha e volta à tona; **E** sobe no barco pela água. Mergulhado, Senu não é alvo dos crocodilos. Fôlego acabando devolve Senu à tona com dano, sem morte instantânea.
- Tesouros do fundo usam IDs `dive_*` em `collected` e pagam só óbolos (nada de Nous). A camada do fundo vive em `world_stage`, a SubViewport de pixel do mundo, como os atores. Detalhes em [MUNDO_BARCO_ILHA.md](MUNDO_BARCO_ILHA.md).
