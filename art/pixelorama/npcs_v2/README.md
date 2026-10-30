# NPCs: poses complementares v2

O catálogo atual foi conferido no código: seis personagens nomeados (Hori, Sabu, Merit, Nakht, Adiam e Tarek), Ankhet e doze aparências compartilhadas por moradores/vendedores. Todos já tinham uma imagem. Esta entrega completa os estados ausentes, sem criar personagens futuros nem substituir os seis nomeados de `interiors_v4`.

- `townsfolk_v2.pxo`: 192 quadros de 32×52, pivô nos pés (16,49). Cada aparência mantém as 12 poses originais de `townsfolk_v1`, byte a byte, e acrescenta respiração, piscada, respiração com carga e piscada com carga. Dezesseis colunas; ordem das aparências e poses no plano JSON. Cada tag contém uma aparência inteira.
- `ankhet_v2.pxo`: quatro quadros de 128×144, pivô (64,112): repouso, respiração, piscada e gesto com a mão livre. Cajado e barra da roupa ficam apoiados no mesmo lugar.

Os componentes de pixel art são os mesmos dos construtores anteriores. O novo construtor desenha quadros completos com o tronco abrindo 1 px; pés, cabeça e cargas ficam ancorados. A piscada pinta uma pálpebra opaca, sem apagar o rosto. O jogo intercala repouso e respiração com uma piscada de 0,125 s, em fases diferentes por aparência. Movimento, colisões, rotinas, missões e saves continuam usando os contratos existentes.

Abra os `.pxo` no Pixelorama para editar. Depois use `tools/pixelorama/export_npcs_v2.ps1`: ele só exporta esses projetos e importa no Godot. Os construtores `build_townsfolk_v2.gd` e `build_ankhet_v2.gd` são fontes de produção inicial; **não os rode novamente sobre edições manuais**. Os projetos antigos não são regenerados.

Prévia: `qa/npcs_v2/residents_1.png` e `residents_2.png`. Colunas: repouso, respiração, piscada, fala, repouso com carga, respiração com carga, piscada com carga, curvar-se. Linhas na ordem do catálogo. `qa/npcs_v2/ankhet.png` mostra as quatro poses da guardiã.

Verificação de contrato: `tests/npc_sprites_v2_test.gd`. Integração: `tests/port_life_test.gd` e `tests/isle_test.gd`, sempre com `-- --qa`.
