# A01 — Porto dos Esquecidos, expansão 2

## Intenção

A primeira demonstração tinha 158 células caminháveis. A expansão possui **1.287 células**, cerca de **8,1 vezes a área caminhável**, distribuídas em 13 setores. A proporção mede o espaço em células; não é uma estimativa da duração da partida.

O percurso agora contorna um bairro portuário, atravessa mercados e armazéns, passa por uma ponte estreita e retorna por jardins e guaritas. A exploração inclui uma alcova e um embarcadouro lateral, em vez de apenas aumentar o tamanho das salas antigas.

## Setores

| ID | Setor | Identidade e função |
|---|---|---|
| hub | Santuário da Primeira Palavra | Pedra com mosaicos, selo de iniciação e retorno da jornada. |
| p1 | Cais dos Esquecidos | Passadiços de madeira, bordas sustentadas por estacas e rota de chegada. |
| market | Mercado das Cinzas | Chão arenoso e espaço para bancas, inscrições e descanso intermediário. |
| p2 | Armazém das Vozes | Pedra urbana, poço inundado e rota entre depósitos. |
| bridge | Ponte dos Barqueiros | Travessia estreita de madeira sobre a água. |
| p3 | Pátio das Memórias | Mosaico deteriorado, cisterna aberta e bifurcações. |
| secret | Alcova do Escriba | Pedra violeta, adagas e recompensa de exploração. |
| lower_dock | Embarcadouro Velho | Cais lateral e dois pequenos píeres para pistas e coletáveis. |
| garden | Jardim Inundado | Piso esverdeado, espelhos de água e passagem contornável entre os poços. |
| p4 | Guarita do Retorno | Checkpoint próximo do chefe e alavanca do retorno ao santuário. |
| b1 | O Limiar Sem Nome | Arena ampla com selo circular e saída selada pelo chefe. |
| a02 | Catacumbas do Eco | Entrada de teste, alcançada depois de abrir o portão do chefe. |
| aqueduct | Aqueduto Silencioso | Atalho entre Mercado e Jardim, inicialmente fechado pelo lado distante. |

## Percurso e retornos

Rota principal: **Santuário → Cais → Mercado → Armazém → Ponte → Pátio → Jardim → Guarita → Arena → Catacumbas**.

- A alavanca da **Guarita**, célula `(5,20)`, abre o corredor de retorno ao hub. Na malha sem props, o caminho do hub à alavanca cai de 85 para 27 passos entre células.
- A alavanca do **Jardim**, célula `(18,24)`, abre o Aqueduto. O caminho Mercado–Jardim cai de 45 para 29 passos entre células, sem exigir arma ou habilidade opcional.
- O **Pátio** oferece desvios para a Alcova e o Embarcadouro. Nenhum deles é necessário para chegar ao chefe.
- O corredor das **Catacumbas** continua bloqueado pelo portão do Porteiro Sem Nome. Há apenas uma fronteira caminhável nesse gargalo.

Os três portões são dados em `PortLayout.GATES`. As relações usadas pelo mapa da interface estão em `ROOM_LINKS`, incluindo as flags `shortcut` e `aqueduct`.

## Arte e profundidade

O piso usa materiais distintos de madeira, pedra, mosaico, areia e cripta. Bordas expostas possuem faces verticais, apoios de madeira, juntas escuras e marcas de desgaste. Cisternas e recortes da margem quebram as superfícies retangulares. Selos no chão identificam o santuário, o pátio, a alcova e a arena.

O desenho do piso é estático e reutilizado pelo Godot. Somente a água, em um `Node2D` separado, é redesenhada a 10 Hz; a expansão não redesenha mais de mil células a cada quadro. Arquitetura, vegetação, barcos, bancas e oclusão do personagem são integrados pelo controlador do mundo e pelos props.

## Contrato de integração

- Isometria preservada: meia célula de `(32,16)` pixels; `iso()` e `unproject()` continuam compatíveis.
- `MARKERS` contém santuários, alavancas, pickups, inscrições e posições de captura.
- `ENEMY_SPAWNS` mantém os IDs antigos dos dois marinheiros e do Porteiro, com novos encontros distribuídos pelo bairro.
- `MAIN_ROUTE_WAYPOINTS` contorna os quatro poços internos. O recorte no canto nordeste da arena impede uma conexão acidental entre o corredor do hub e a arena.
- Os IDs `hub` e `s1` permanecem estáveis para reaparecimento. Há um marcador `market_rest` para um descanso intermediário; sua persistência é responsabilidade do controlador/save.

## Verificação deste layout

Uma análise da malha de células confirmou: 13 setores, 1.287 células; todos os marcadores e segmentos da rota principal sobre chão caminhável; todas as células conectadas quando os portões estão abertos; alavancas alcançáveis pela rota principal; Catacumbas inacessíveis antes da abertura do portão do chefe; os dois atalhos reduzem os percursos correspondentes.

Essa análise estática não substitui testes de colisão no Godot nem uma partida humana. A validação do controlador, dos props, do mapa da interface e do novo personagem é registrada em `TESTES.md` após a integração.
