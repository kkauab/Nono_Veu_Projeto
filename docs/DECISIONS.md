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
