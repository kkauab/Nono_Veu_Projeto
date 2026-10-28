# Árvore das Emanações — 27/10/2026

O Porto oferece agora 13 habilidades funcionais, seguindo os três caminhos e os híbridos do GDD. A árvore é acessada com **T**; selecionar um nó mostra seus detalhes e não gasta pontos. A compra é feita pelo botão **Aprender**, somente quando os pré-requisitos e o saldo estão completos. Nós aprendidos ficam dourados; os demais explicam por que estão bloqueados.

| Habilidade | Caminho | Nous | Requisitos | Efeito no jogo |
|---|---|---:|---|---|
| Mão firme | Vontade | 1 | — | +4 de dano aos golpes da arma. |
| Fôlego da pedra | Matéria | 1 | — | +20 de vida máxima. |
| Memória do éter | Intelecto | 2 | — | Poder da arma recarrega 20% mais rápido. |
| Ritmo da lâmina | Vontade | 2 | Mão firme | +8 de dano ao terceiro ataque leve; janela do combo de 1,15 s. |
| Lâmina Ascendente | Vontade | 3 | Ritmo da lâmina | **F**, com o Khopesh: golpe ascendente com +20 de dano e +14 de alcance. |
| Passo Etéreo | Matéria | 2 | Fôlego da pedra | Recarga da esquiva 20% menor e proteção ampliada em 0,06 s. |
| Pele de alabastro | Matéria | 3 | Passo Etéreo | Redução de 15% do dano recebido, com arredondamento para dano inteiro. |
| Selo de Mercúrio | Intelecto | 3 | Memória do éter | **C**: projétil de 32 de dano, alcance de 260 unidades e recarga de 8 s. Segue a última direção de Senu. |
| Olho do escriba | Intelecto | 2 | Selo de Mercúrio | Marca em dourado coletas, memórias e relicários opcionais em até 220 unidades. Não recolhe nem resolve os mecanismos. |
| Contra-ataque ágil | Vontade + Matéria | 2 | Ritmo da lâmina + Passo Etéreo | Aparar recarrega a esquiva e concede +12 no próximo ataque leve em até 2,8 s. Nas Adagas o bônus vale para um contato. |
| Reflexo da Palavra | Vontade + Intelecto | 2 | Ritmo da lâmina + Selo de Mercúrio | Aparar devolve ao agressor um projétil de 24 de dano. |
| Esquiva etérea | Matéria + Intelecto | 2 | Passo Etéreo + Selo de Mercúrio | Atravessa corpos de inimigos durante a esquiva, mantendo colisão com cenário e portões. |
| Convergência do Nous | Convergência | 3 | Os três híbridos | **C** passa a atingir até três inimigos diferentes e recarrega em 6 s. |

## Pontos e exploração

Existem **22 Nous únicos** nesta versão: 12 Fragmentos pelo mapa, 3 recompensas dos selos, 2 do relicário das testemunhas, 3 do relicário de Iri e 2 pela missão de Hori e Sabu. A árvore inteira custa **28**. Isso permite especializações completas, sem exigir comprar tudo. O caminho mínimo até Convergência custa **20** e ainda permite comprar Olho do escriba com os dois pontos restantes.

As compras não bloqueiam a campanha. Os três puzzles, o Porteiro e as Catacumbas continuam independentes da escolha de habilidades. Visão do Reverso e Passo Mercurial, previstos como habilidades narrativas de outras etapas, continuam separados desta árvore.

## Persistência e integração

Os IDs, os custos e os efeitos das três habilidades antigas foram preservados. Salvar mantém a lista de compras, o saldo de Nous e as compras das lojas. Recarregar ou trocar de arma reconstrói os atributos e não acumula bônus. Sandálias de caravana e Passo Etéreo combinam seus multiplicadores de recarga.

Compras recusadas não descontam Nous. Fragmentos continuam preservados na morte. O selo tem recarga própria, independente do poder de arma em Q; paredes e portões interrompem o projétil, inclusive na Convergência.

Fontes de implementação: `scripts/progression/skill_catalog.gd`, `scripts/save/save_store.gd`, `scripts/actors/player.gd`, `scripts/actors/mercury_projectile.gd`, `scripts/world/port_demo.gd` e `scripts/ui/game_hud_v6.gd`.
