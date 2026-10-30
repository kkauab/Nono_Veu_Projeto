# Senu no barco — poses v2

O Senu desta versão usa cabeça, cabelo, rosto, manto e roupa do corpo compartilhado v6 na mesma densidade de pixels do jogo. Os braços da postura parada foram removidos: braços e antebraços têm articulações próprias, mãos fechadas nos cabos e cotovelos que flexionam durante a puxada e a recuperação. O tronco inclina sobre o quadril fixo; a cabeça se move como um segmento inteiro. Joelhos ficam dobrados sobre o banco. O casco vazio original v1 é preservado.

- `boat_v2.pxo`: 160 quadros, 16 direções × (repouso, oito fases de remada, vazio); célula 96×80 e pivô de água (48,54). Três camadas: casco/remo distante, corpo, borda/remo e braço próximos. A proa gira em 16 direções, enquanto o corpo reutiliza as oito vistas reais de Senu. Senu olha para a popa.
- `senu_boat_v2.pxo`: 96 quadros, embarque/desembarque em oito vistas, seis poses por ação sem repetição; célula 96×96 e pivô nos pés (48,76). Antecipação, impulso, pernas recolhidas no ar, contato e assentamento têm poses diferentes. Corpo e pernas são segmentos, sem encolher o personagem inteiro.
- Os arquivos `*_export_plan.json` registram tags, pivôs, ordem dos quadros e hashes das fontes. Os exports usados no jogo são PNG + JSON/manifesto. O desenho e a temporização são GDScript; os construtores do projeto são Python/GDScript, não JavaScript.

Para editar, abra os dois `.pxo` no Pixelorama 1.2.3. Depois rode `tools/pixelorama/export_senu_boat_v2.ps1`, que exporta os projetos editados sem reconstruí-los. Caminhos das ferramentas podem ser passados como parâmetros. O exportador usa Downloads ou A:\Ferramentas, como os existentes.

`tools/pixelorama/build_senu_boat_v2.py` é o construtor de produção inicial (Pillow). Ele recusa sobrescrever um `.pxo` existente; `--replace-generated` só deve ser usado para reconstrução intencional, pois descarta alterações manuais desta versão. As fontes v1/v6 nunca são gravadas pelo construtor.

Integração: `scripts/actors/senu_boat_view.gd` amostra as poses de travessia; `sea.gd` mantém o pivô físico no chão e aplica altura apenas ao desenho. Um único sprite transitório é limpo ao sentar, desembarcar ou reaparecer; pausa congela desenho e deslocamento. `sea_boat.gd` usa a folha v2 e mantém Senu sentado durante o encaixe no píer. Navegação, colisão do casco, locais de atracação, missões e IDs de save são os mesmos.

QA: `tests/senu_boat_animation_test.gd` (atlas e movimento da região dos braços/tronco); `tests/boat_transfer_test.gd -- --qa` (entrada/saída, pausa, interrupção nos dois píeres e nenhum salvamento); `tests/boat_test.gd -- --qa` (travessia, costa, ânforas e retorno). Pranchas, GIFs e capturas em `qa/boat_senu/`.
