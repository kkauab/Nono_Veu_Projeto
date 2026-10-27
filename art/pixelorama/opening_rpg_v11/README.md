# Elementos originais da abertura RPG v11

Este atlas é dedicado à abertura encenada no jogo. Não reutiliza os objetos, os barcos ou os personagens do cenário jogável. O desenho foi construído em resolução nativa, com contornos em pixels e uma paleta de 48 cores compatível com pedra verde-petróleo, madeira, bronze e linho do projeto.

Fonte editável: `intro_atlas.pxo`, oito cels de 128×128 e seis camadas: terreno/objetos, pernas/botas, manto/bolsa, túnica/braços, rosto/lenço e acabamentos. O barqueiro tem anatomia fixa e três poses de apoio/passo, com braços e pernas em contramovimento. O corpo mede cerca de 38 pixels, sem normalizar ou redimensionar cada pose.

Contrato do PNG, exportado pelo Pixelorama instalado: `D:/Nono_Veu/assets/cinematics/rpg_v11/intro_atlas.png`, 512×256, quatro colunas e duas linhas.

| Cel | Elemento | Apoio |
|---|---|---|
| 0 | Piso de pedra, losango 64×32 | região local `(32,96,64,32)`, centro `(64,112)` |
| 1 | Piso de madeira, losango 64×32 | mesma região e centro |
| 2 | Barqueiro adulto parado, manto ocre e lenço | `(64,112)` |
| 3 | Passo esquerdo do barqueiro | `(64,112)` |
| 4 | Passo direito do barqueiro | `(64,112)` |
| 5 | Barca aberta original, assentos, remo e corda | `(64,112)`, aproximadamente 104×60 |
| 6 | Lamparina de bronze com chama | `(64,112)`, aproximadamente 40 de altura |
| 7 | Placa para o santuário com sigilo solar | `(64,112)`, aproximadamente 40 de altura |

Não há letras minúsculas incorporadas à placa. A transparência é binária, sem antialiasing. O PNG final é produzido pela exportação nativa do Pixelorama; `tools/pixelorama/build_opening_rpg_v11.py` prepara os cels/camadas e `tools/pixelorama/export_opening_rpg_v11.ps1` executa a exportação. Metadados completos e cores estão em `export_plan.json`; registro em `qa/pixelorama_opening_rpg_v11.log` e folha de contato2× em `qa/opening_rpg_v11_contact_2x.png`.
