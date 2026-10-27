# Bases, passagens e fachadas — v8

Os problemas das imagens não eram apenas de estilo. As bases desenhadas nos sprites ocupam uma superfície isométrica, mas os objetos eram posicionados como pontos. Armazéns estavam além da borda do chão e tinham apenas um círculo de colisão de 14 pixels. Alguns arcos estavam alinhados com a estrada, com um pilar no percurso, em vez de atravessarem a passagem.

## Correções

- Dois patamares de pedra conectam santuário/cais e mercado/armazém. São piso real, com colisões e navegação correspondentes; acrescentam quatro células, totalizando 4.350. Não foram alargados os corredores dos portões fechados.
- Aberturas dos arcos são centralizadas nos pontos de passagem. As entradas no eixo transversal usam a orientação espelhada necessária. Cada pilar tem sua própria base física, preservando o vão vazio para Senu.
- As fachadas antigas e novas foram recuadas para dentro do piso, com apoio sob todos os cantos. A fundação do armazém usa o polígono do plano do chão, não o retângulo da imagem inteira nem um pequeno círculo no centro.
- Sombras arquitetônicas acompanham as fundações. O arco deixa de ter uma sombra central no espaço vazio entre os pilares.
- Foram retiradas cargas imediatamente duplicadas no cais e no armazém; bancas sobrepostas no mercado foram reduzidas. O templo do arquivo e a escadaria dos sinos foram apoiados dentro de seus pátios.
- As artes v7 foram reutilizadas. Não foram geradas novas imagens para esconder os problemas de posicionamento.

## Verificação

`tests/scene_support_v8_test.gd` verificou o chão sob os cantos e centros das arestas de 25 estruturas, a quantidade de colisões e a abertura dos arcos: **65/65**. O teste dos três selos percorreu fisicamente o mapa: **124/124**, em **9.445 passos físicos**. A rota original também passou: **121/121**.

O planejador do teste físico consulta as mesmas fundações dos objetos por `blocks_ground_point`, em vez de assumir que todo objeto é um círculo. Os testes usam apenas o progresso de QA.

Arquivos alterados: `scripts/world/port_layout.gd`, `scripts/world/port_dressing.gd`, `scripts/world/world_prop.gd`, `tests/route_test.gd` e `tests/world_v6_test.gd`. Os blocos de desenho 12×12 permanecem ativos.

Registros: `qa/scene_support_v8_test.log`, `qa/world_scene_v8_test.log` e `qa/route_scene_v8_test.log`.
