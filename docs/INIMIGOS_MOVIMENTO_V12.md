# Movimento dos inimigos v12

Os quatro tipos comuns usam ciclos completos de oito poses de caminhada. Os pés mudam de apoio a cada quatro unidades de deslocamento no chão: uma passada completa cobre 32 unidades. A animação usa a distância que o corpo realmente percorreu depois da colisão. Esperar, perder o alvo ou ficar bloqueado mantém os pés parados.

O desenho acompanha a direção real da rota. A direção usada para acertar Senu continua sendo a do combate. A antecipação, o contato, a continuação e o retorno da arma acompanham os tempos existentes dos estados do inimigo, sem mudar quando o dano é aplicado.

## Quadros

Cada linha do atlas corresponde a guarda, corredor, lanceiro ou guardião. O chefe mantém o desenho de guardião com o fator fixo 1,35.

| Índices | Uso |
| --- | --- |
|0|Parado, pés apoiados|
|1–8|Ciclo de caminhada com apoios alternados|
|9–10|Erguer e preparar a arma|
|11|Contato, junto ao evento de dano|
|12|Continuação do golpe|
|13|Retorno da arma|
|14|Recuo ao receber dano|
|15|Guarda após a recuperação|

O pivô dos pés fica em (64,112) dentro de cada quadro de 128×128. A textura tem 16 colunas e 4 linhas, 2048×512 pixels. Há uma vista de três quartos por tipo e espelhamento horizontal. O corpo mantém escala fixa durante o movimento; não há aumento ou diminuição para simular passos.

As alturas do ajuste v9 permanecem: corredor 40 px, guarda 44 px, lanceiro 46 px, guardião 46 px e chefe aproximadamente 62 px. As vidas continuam 85, 110, 135, 160 e 400, respectivamente. Velocidades, colisões, alcance, tempos de golpe e grafo de navegação foram preservados.

## Verificação

`tests/enemy_motion_v12_test.gd` exercita uma perseguição real, a mudança de direção da apresentação, a parada ao perder o alvo, a progressão dos golpes, o contato de dano único, o recuo e o reinício no ponto de descanso. Os testes de combate, resistência v9, navegação e desenho em repouso complementam a verificação.

`tools/qa/capture_enemy_motion_v12.gd` apresenta os quatro tipos com Senu em escala comum 3× e grava os quadros para revisão da caminhada e dos ataques.

Verificação final: movimento 28/28, combate 26/26, resistência 56/56, navegação 8/8 e cache/desempenho 6/6. O teste de movimento compara também os pixels das oito poses de passos e das cinco poses de golpe de cada tipo, para detectar repetições literais.

A prévia `qa/enemy_motion_v12_preview.gif` contém 80 quadros em 4 segundos, 960×540, capturados pelo Godot. A folha `qa/enemy_v12_guard_stride_review.png` permite conferir lado a lado os apoios do guarda.
