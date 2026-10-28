# A vida no Porto — 27/10/2026

Pedido do Gustavo: dar vida ao mundo, com moradores fazendo a sua vida pelo mapa, venda nas bancadas e o movimento do comércio marítimo. Tudo fica na zona 3 (Mundo). No `port_demo.gd` entram só três ganchos: o preload `Life`, a chamada `Life.build(self)` e o caso `"townsfolk", "vendor"` em `activate`.

O GDD descreve o Porto dos Esquecidos como "ruas portuárias degradadas e cais tomados por marinheiros sem memória". Os moradores seguem essa ideia: perderam o nome como todos aqui e repetem a rotina sem lembrar por quê. As falas tocam nisso, sem revelar a trama.

## O que tem

| O quê | Onde | Como funciona |
|---|---|---|
| 4 bancadas | Mercado das Cinzas (2) e Portão das Caravanas (2) | O vendedor fica ao lado da barraca. Apertar E compra comida, que cura na hora: peixe seco (8 óbolos, +25), tâmaras do Faium (5, +15), pão de cevada (6, +20) e cerveja de cevada (4, +10). Com a vida cheia ou sem óbolos, não cobra. O vendedor gesticula quando um freguês compra. |
| 22 moradores | Santuário, Cais, Mercado, Armazém, Pátio, Embarcadouro, Cais do Cobre, Caravanas, Fornos, Escadaria, Escribas, Arquivo, Cisterna e Jardim | Cada um tem uma rotina de paradas. Ações: andar, ficar parado, conversar (vira para quem está perto), rezar, pescar (com linha e boia na água), comprar numa bancada e pegar ou largar carga. E fala com eles; cada conversa traz a fala seguinte. |
| 2 navios mercantes | Embarcadouro Velho e Cais do Cobre | Chegam do mar aberto de proa, atracam, ficam ancorados enquanto os estivadores descarregam, saem e somem no mar. Depois voltam. O ciclo não tem sorteio. |
| 4 estivadores dos navios | junto às vagas | Esperam o navio na borda do cais. Com o navio atracado, pegam a carga e levam até a pilha ou o armazém. |

## Regras

- **Corpo:** os moradores ficam na camada de colisão 4, a mesma dos inimigos. O Senu esbarra neles, e a espada não os acerta, porque não estão no grupo `enemies`. Andando, o morador espera o Senu liberar o caminho.
- **Dar passagem:** se o Senu fica encostado num morador por mais de 0,2 s, o morador dá um passo para o lado, para fora da linha do Senu. Conta o tempo de contato, não o empurrão, porque encostado e travado o Senu fica com velocidade zero. Se não houver chão livre por mais de um segundo, o morador deixa de ser sólido por 1,5 s e o Senu passa. Assim ninguém tranca um corredor, e os testes de percurso passam com os moradores andando.
- **Caminhos:** `port_life.gd` monta um grafo A* nos centros dos tiles livres. Livre quer dizer longe do cenário sólido e a mais de 0,3 tile da borda do chão. Depois o caminho é encurtado onde a linha reta também está livre. O grafo leva cerca de 0,3 s ao montar o mundo.
- **Desempenho:** a mais de 1100 px do Senu, a rotina pausa.
- **Navios sem corpo:** um corpo andando empurraria o barco de Sabu (combinado com a sessão do barco). O navio usa o shader de linha d'água do `sea.gd` (`Sea.seat_ship`), como os barcos ancorados.
- **Direção da arte do navio:** a arte só tem a proa para longe da câmera (nordeste; espelhada, noroeste). O navio do Embarcadouro entra de proa entre os dois píeres, recua de ré até o mar aberto e sai para oeste. O do Cobre atraca de lado e segue em frente para oeste.
- **Vagas:** os barcos parados de `(29, 38)` e do Cais do Cobre saíram; as vagas agora são dos navios mercantes.

## Arte

`assets/world/townsfolk_v1.png` é gerada pelo script `tools/pixelorama/build_townsfolk_v1.gd`, pixel a pixel e na paleta do Porto v7. Tem 12 aparências (estivador, carregador, peixeira, mercador, marinheiro, remador, escriba, peregrina, velho, aguadeira, padeira e caravaneiro) e 12 poses cada. As poses são: parado, quatro passos, falando, carregando parado, quatro passos carregando e curvado. Cada célula tem 32 × 52 px, com o pé em (16, 49). Todos olham para a direita, e o jogo espelha. A carga muda com a aparência: caixote na cabeça, saco nas costas, cesto, ânfora ou rolo de papiro.

Para gerar de novo:

```powershell
& "A:\Ferramentas\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path . --script res://tools/pixelorama/build_townsfolk_v1.gd -- --preview
```

O `--preview` grava `qa/townsfolk_v1_preview.png` em escala 3×.

## Arquivos

| Arquivo | Papel |
|---|---|
| `scripts/world/port_life_catalog.gd` | Quem vive onde: bancadas, navios e rotinas, em tiles |
| `scripts/world/port_life.gd` | Monta tudo, calcula os caminhos e trata falar e comprar |
| `scripts/world/townsfolk.gd` | O morador e o vendedor (subclasse de `PortInteractable`) |
| `scripts/world/trade_ship.gd` | O navio mercante e o ciclo dele |
| `tests/port_life_test.gd` | Teste |

## Para acrescentar

- **Morador novo:** uma entrada em `TOWNSFOLK`, com paradas em chão livre e fora da boca das passagens. O teste confere as paradas e o caminho entre elas.
- **Bancada nova:** precisa de uma barraca (`stall`) no cenário a menos de 2 tiles do tile informado.
- **Navio novo:** `arrive`, `astern` e `leave` só pela água, com a proa sempre para longe da câmera ao andar para a frente.

## Ideias para depois

- Moradores que se afastam quando há luta por perto.
- Variações das falas depois do chefe, como pede o GDD: "o hub muda de aparência e população conforme os acontecimentos".
- Barcos de pesca a remo na Baía das Garças, com a arte do barco de Sabu.
