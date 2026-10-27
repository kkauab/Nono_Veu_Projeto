# Cortes da Khopesh — v7

O ataque da espada usava o corpo preparado para dois socos. A lâmina modular girava na mão enquanto o braço permanecia estendido. A versão v7 usa as poses de corte da folha de combate fornecida pelo usuário: guarda, braço levantado, contato e retorno, com punho e lâmina desenhados juntos.

O corpo em repouso, a caminhada, a corrida, a esquiva e as adagas continuam usando o corpo compartilhado v6. Os cortes preservam a roupa, a faixa, o cabelo e as proporções dos desenhos originais. Todas as poses são extraídas na mesma escala de 1,22; o jogo não altera o tamanho do corpo durante o golpe. O ponto de apoio fica em (128, 200), num quadro de 256 × 256.

O corte leve mantém o contato em 0,075 s e o pesado em 0,24 s. O pesado usa a mesma sequência limpa, com antecipação mais longa. As poses pesadas da folha original se sobrepõem a figuras vizinhas e foram excluídas desta entrega. Dano, alcance, recuperação e bloqueio de ações continuam definidos no jogador.

A folha fornecida contém poucas vistas de corte. As oito direções do controle têm sequências explícitas, com espelhamento ou vista próxima nas direções cardinais. O nordeste usa o espelhamento do noroeste completo, pois a seleção original cortava a lâmina. A ordem dos dois quadros centrais para cima foi corrigida para levantar o braço antes do contato. Isso não equivale a oito vistas novas desenhadas.

## Arquivos editáveis e exportação

- Projeto nativo: `art/pixelorama/senu/senu_sword_v7.pxo`.
- Abrir no editor: `ABRIR_COMBATE_PIXELORAMA.cmd`.
- Exportar e atualizar o Godot: `EXPORTAR_COMBATE.cmd`.
- Atlas de execução: `assets/sprites/senu_sword_v7.png`, 2048 × 1024, 32 quadros. O PNG é exportado pelo Pixelorama 1.2.3 oficial.
- Descrição dos quadros: `assets/sprites/senu_sword_v7_manifest.json`.
- Seleção de fontes e reconstrução do projeto: `tools/pixelorama/build_sword_v7.py`.
- Prévia em oito direções: `qa/senu_sword_v7_all_directions.gif`.

O atlas acrescenta cerca de 8 MiB de pixels descompactados. Ele é carregado uma vez, quando a espada executa o primeiro corte.

## Verificação

O teste específico verifica 97 condições: golpe leve e pesado em oito direções, sincronização do contato, pivô e escala constantes, recuperação, ausência de recorte de membros, retorno ao corpo comum e preservação das adagas. Também foram executadas as verificações de combate, animação, movimento e padronização do corpo.
