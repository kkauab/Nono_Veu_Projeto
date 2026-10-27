# Sentinelas — proporções e resistência finais

Os inimigos foram recalibrados em relação ao corpo de Senu, com aproximadamente 38 pixels de altura no mundo. Guarda 44 px, corredor 40 px, lanceiro 46 px, guardião 46 px; chefe cerca de 62 px. As alturas são gravadas na preparação nativa, com escala fixa em todas as poses de cada arquétipo. O chefe usa um fator estático de 1,35. Não há mudança de tamanho durante passos ou golpes.

Projeto nativo: `port_enemies_v9.pxo`, 16 cels de 128×128, apoio dos pés em (64,112). Atlas exportado pelo Pixelorama: `assets/sprites/port_enemies_v9.png`, 512×512. Fonte preservada em `source_sheet.png`, mesma folha gerada por ImageGen nas etapas anteriores. A revisão de proporção não gerou imagens novas.

Vida: guarda 110, corredor 85, lanceiro 135, guardião 160, chefe 400. Com ataques leves reais sem melhorias, o guarda morre no quinto contato do combo, o corredor no quarto, o lanceiro no sexto e o guardião no sétimo. O chefe suporta 17 contatos e cai no 18º, caso não haja poderes ou ataques fortes. Dano e velocidade de Senu permanecem iguais.

Colisão cobre somente os pés: raio6 para comuns e10 para chefe. Arma/capa não criam uma parede invisível. Sombras, aviso de golpe e barras de vida acompanham as proporções atuais.

`tools/pixelorama/build_enemy_pixel_v9.py` prepara os cels e `export_enemy_pixel_v9.ps1` executa a exportação instalada. Os atalhos `ABRIR_INIMIGOS_PIXELORAMA.cmd` e `EXPORTAR_INIMIGOS.cmd` abrem/exportam esta versão. Comparativo na mesma escala: `qa/actor_proportions_v9.png`. Teste de resistência: 56/56, com golpes e recuperação reais, derrota e restauração no checkpoint; combate26/26.
