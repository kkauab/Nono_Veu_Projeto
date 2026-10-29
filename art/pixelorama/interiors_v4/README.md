# Interiores v4: projeção e apoio no piso

Este projeto corrige os cels nativos dos móveis v3. Novas gerações por descrição não garantiram a inclinação exata do piso; a correção final é geométrica, feita nos pixels do `.pxo`.

`tools/pixelorama/build_interiors_v4.gd` lê o projeto v3, mede as duas faces de cada móvel e desloca cada coluna por um número inteiro de pixels. As diagonais passam a seguir os eixos 2:1 do mapa; a altura das colunas, cores e detalhes verticais são mantidos. Não há redimensionamento em tempo de execução. As poses dos NPCs são copiadas sem alterações.

O centro da base, e não seu canto dianteiro, fica sobre o ponto de colocação do móvel. Os vasos e objetos redondos têm sua área real de contato centrada, sem serem forçados a uma caixa.

`export_plan.json` registra `ground_base` e os limites das colunas pintadas. Desenho, colisão, sombra de contato e ordenação por profundidade usam essa mesma informação. As bases são mantidas dentro do piso, com folga da parede.

Abra **ABRIR_INTERIORES_PIXELORAMA.cmd** para editar este arquivo. **EXPORTAR_INTERIORES.cmd** exporta pelo Pixelorama e importa no Godot. Reconstruir o projeto pelo script substitui os cels: preserve eventuais edições manuais antes dessa operação.

Verificações: `interiors_art_test.gd` compara PNG e projeto nativo; `interior_grounding_test.gd` verifica inclinação, centro, colisões, sombras e pés dentro da sala. A conferência visual das quatro salas é feita com `npc_visual_preview.gd -- --qa`.
