# Porteiro — passos refinados v6

Revisão isolada da caminhada de três quartos para avaliação. O atlas v5 dos nove golpes permanece intacto; a partida normal ainda usa o chefe anterior. Abra `VER_GOLPES_PORTEIRO.cmd` na raiz para ver o Porteiro acompanhar Senu no mapa, parar e executar os clipes selecionados por 1–9. Somente progresso de QA, sem dano ou recompensas.

## Movimento

- Ciclo com 16 poses, passada de 22 px e ritmo de ensaio de 24 px/s. Fase de apoio ocupa pouco mais da metade do ciclo, com breves apoios duplos. Os pés sobem no máximo 2 px.
- Joelho resolvido no plano avanço/altura e projetado na câmera isométrica; a sola de apoio compensa o deslocamento da raiz. Compressão de peso de 1 px, cabeça firme, haste nas duas mãos e manto com movimento discreto.
- Início pela pose de passagem compacta. Cada fase tem fechamento próprio: primeiro recolher um pé, apoiar e então recolher o outro. A parada termina na guarda original, sem trocar diretamente uma passada aberta pela pose parada. Um ataque solicitado enquanto caminha aguarda esse apoio antes de começar sua própria preparação/relógio JSON.
- 49 cels editáveis, quatro camadas: ciclo16 + fechamentos32 + guarda1. Canvas 160×160, pivô (80,140), corpo de referência 57 px. Rosto/cabelo v3 preservados pixel a pixel; bronze/manto v4.

`resources/bosses/gatekeeper_walk.json` define passada, ritmo, fases, tempos de fechamento e projeção. `export_plan.json`/manifest contêm metadados dos apoios, regiões e sequências. `nameless_gatekeeper_view.gd` seleciona este atlas somente para caminhar/recolher os pés; os ataques conservam textura e tempos v5. A prévia avança os cels pela distância real, sem andar no lugar quando bloqueada. Em chão livre da arena aproxima diretamente; obstáculos mantêm a navegação compartilhada.

## Produção e manutenção

Construção local com materiais dos concepts e poses próprias; a fonte não foi desenhada manualmente na interface do Pixelorama. A exportação PNG/JSON é feita pelo Pixelorama instalado, sem API paga. Fontes anteriores e Senu preservados. Os construtores v1–v4 são dependências; não regeneram seus arquivos ao construir esta versão. Hashes recusam sobrescrever edições manuais.

```powershell
python -B tools/pixelorama/build_gatekeeper_walk_v6.py
& tools/pixelorama/export_gatekeeper_art_v1.ps1 -ArtVersion 6
python -B tools/pixelorama/validate_gatekeeper_walk_v6.py
godot --headless --path . --script tests/gatekeeper_walk_test.gd -- --qa
godot --path . --script tests/gatekeeper_rehearsal_test.gd -- --qa --capture-walk
python -B tools/pixelorama/package_gatekeeper_walk_review.py
```

Provas em `qa/porteiro_walk_v6/`: `comparacao_caminhada.gif` compara os sprites à mesma altura e nos ritmos respectivos; `caminhada_no_mapa.gif` e `parada_no_mapa.gif` são capturas do Godot. A comparação em estúdio não pretende demonstrar navegação ou colisões. Validações numéricas não aprovam naturalidade artística. Outras direções, combate, narrativa e persistência do encontro completo continuam pendentes.
