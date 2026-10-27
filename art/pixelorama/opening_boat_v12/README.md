# Barca da chegada v12

Arte original na resolução nativa, com cinco camadas editáveis. A projeção usa os mesmos eixos2:1 do cais; o casco fica paralelo à margem. O fundo, as tábuas internas, dois bancos, a rede remendada, o rolo de corda e o remo guardado têm contornos e sombras da paleta de madeira/linho/petróleo do jogo.

O bordo frontal é separado para que o corpo do passageiro possa ficar dentro do casco. Não se deve desenhar o casco inteiro por cima de Senu nem por baixo dos pés como se fosse uma plataforma plana.

Fonte: `arrival_boat.pxo`. Entrega nativa do Pixelorama: `D:/Nono_Veu/assets/cinematics/rpg_v12/arrival_boat.png`,512×128, quatro cels128×128. Pivô `(64,112)` em todos os cels. Transparência binária; sem redimensionamento no jogo.

| Cel | Uso |
|---|---|
|0|Casco distante, piso, bancos e equipamento|
|1|Parede próxima e bordo frontal, desenhados após o passageiro|
|2|Linha d'água A|
|3|Linha d'água B, deslocamento de um pixel na água|

A ordem de composição é água→casco distante→passageiro→bordo frontal. A linha d'água pode alternar a2fps; o casco mantém escala e geometria fixas.

| Âncora | Cel local | Relativa ao pivô |
|---|---|---|
|Pé do passageiro parado|`(69,87)`|`(5,-25)`|
|Ponto de entrada da passarela|`(89,88)`|`(25,-24)`|
|Amarra na proa|`(103,97)`|`(39,-15)`|

Para a geometria atual do cais, uma posição de barco `(125,280)` coloca o piso interno do passageiro em `(130,255)` e a entrada em `(150,256)`. O bordo frontal do cais segue `y=.5*x+156`, portanto a passarela pode terminar no cais em `(175,243.5)`. A equação inclui a esquina frontal do losango: para a célula `(x,5)`, o centro é `(170+32x,225+16x)` e a esquina frontal fica16pixels abaixo. Isso corrige a origem antiga `(205,214)`, que estava no interior do piso, e o pé antigo do passageiro, abaixo do piso interno da barca.

O helper `tools/pixelorama/build_opening_boat_v12.py` prepara as camadas nativas. `tools/pixelorama/export_opening_boat_v12.ps1` abre o projeto no Pixelorama instalado e verifica código de saída, data de atualização e registro antes de publicar o manifesto. O helper não gera o PNG final do jogo.
