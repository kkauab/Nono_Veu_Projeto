# O Nono Véu — colaboração entre Kauã e Gustavo

Duas pessoas trabalham ao mesmo tempo no mesmo repositório (`kkauab/Nono_Veu_Projeto`). Este documento define as branches, a rotina e quem mexe em quais arquivos, para que os dois não editem o mesmo arquivo em paralelo.

## Branches

```
main            versão estável; só recebe a develop quando tudo foi testado
 └─ develop     integração; recebe o trabalho dos dois por pull request
     ├─ kaua/...      trabalho do Kauã
     └─ gustavo/dev   trabalho do Gustavo
```

- Ninguém envia commits direto para `main` ou `develop`. Tudo entra na `develop` por pull request (PR) aberto no GitHub.
- Cada pessoa trabalha só na própria branch. Para uma tarefa grande, pode criar `nome/tema` (ex.: `gustavo/puzzle-farol`) a partir da `develop`.
- A `main` é atualizada a partir da `develop` em comum acordo, depois de rodar os testes.
- Usar **merge**, não rebase, em branches já enviadas: rebase exige `push --force` e pode apagar trabalho.

### Por que integrar a cada entrega, e não só no final

Quanto mais tempo as branches ficam separadas, maiores os conflitos, principalmente em `port_demo.gd` e nos arquivos binários (que o Git não sabe juntar). Cada parte terminada (a cada um a três dias) vira um PR para a `develop`. Assim os conflitos aparecem pequenos e cedo.

## Rotina

Ao começar a trabalhar:

```powershell
git switch gustavo/dev
git fetch origin
git merge origin/develop
```

Ao salvar o trabalho:

```powershell
git status                         # conferir o que mudou
git add <arquivos da sua zona>     # nunca "git add ." sem olhar a lista
git commit -m "descrição curta"
git push -u origin gustavo/dev     # só na primeira vez; depois basta "git push"
```

Ao terminar uma parte: abrir PR `gustavo/dev → develop` (ou `kaua/... → develop`), o outro olha e faz o merge. Antes do PR, rodar os testes da zona alterada (comandos em [TESTES.md](TESTES.md)).

## Zonas de arquivos

Cada zona tem um responsável. Só o responsável edita os arquivos da zona; o outro pede antes. Para assumir uma zona livre, atualize a tabela no seu próximo PR.

| Zona | Responsável |
|---|---|
| 1. Inimigos | **Kauã** (em andamento) |
| 2. Senu e combate | livre |
| 3. Mundo, mapa e puzzles | livre |
| 4. Interface, menu e abertura | livre |

### 1. Inimigos

- `scripts/actors/enemy.gd`, `scripts/actors/enemy_pixel_view.gd`
- `assets/sprites/port_enemies_*`
- `art/pixelorama/enemies_v*/`
- `tools/pixelorama/build_enemy_*`, `tools/pixelorama/export_enemy_*`
- `tests/enemy_*`
- `docs/INIMIGOS_MOVIMENTO_V12.md`
- `ABRIR_INIMIGOS_PIXELORAMA.cmd`, `EXPORTAR_INIMIGOS.cmd`

### 2. Senu e combate

- `scripts/actors/player.gd`, `senu_supplied_view.gd`, `senu_sword_view.gd`
- `scripts/data/weapon_definition.gd`, `resources/weapons/`, `resources/characters/`
- `assets/sprites/senu_*`
- `art/pixelorama/senu/`
- `tools/pixelorama/`: `build_senu_*`, `build_motion_*`, `build_shared_senu_v6.py`, `build_sword_*`, `build_attack_guides_v6.py`, `build_pixelorama_project.py`, `capture_*`, `export_senu.ps1`, `export_shared_senu_v6.ps1`, `export_sword_*`, `import_*senu*`, `import_pixelorama_export.gd`, `preview_senu.gd`, `source_frames.json`
- `blender/`, `tools/blender/`, `scripts/art/`, `scenes/art/`
- `tests/combat_test.gd`, `tests/senu_*`
- `docs/DESIGN_SENU.md`, `docs/SENU_ESPADA_*.md`
- `ABRIR_SENU_PIXELORAMA.cmd`, `ABRIR_COMBATE_PIXELORAMA.cmd`, `EXPORTAR_SENU.cmd`, `EXPORTAR_COMBATE.cmd`

### 3. Mundo, mapa e puzzles

- `scripts/world/port_layout.gd`, `port_dressing.gd`, `world_prop.gd`, `interactable.gd`, `port_gate.gd`, `port_art.gd`
- `assets/world/`, `assets/shaders/harbor_pixel_*`
- `art/pixelorama/port_v6/`, `art/pixelorama/port_v7/port_pixel_v7.pxo` e as fontes de cenário em `port_v7/sources/`
- `tools/pixelorama/build_port_*`, `export_port_pixel_v7.ps1`, `import_port_art_v6.gd`
- `tests/route_test.gd`, `navigation_v6_test.gd`, `foundation_navigation_v8_test.gd`, `world_v6_test.gd`, `scene_support_v8_test.gd`
- `docs/MAPA_A01_*.md`, `docs/CENARIO_APOIOS_V8.md`, `docs/O_NONO_VEU_MAPA_MESTRE.*`
- `ABRIR_MAPA_PIXELORAMA.cmd`

### 4. Interface, menu e abertura

- `scripts/ui/game_hud_v6.gd`, `scripts/ui/opening_cutscene.gd` (`game_hud.gd` é legado e não é usado)
- `assets/ui/`, `assets/cinematics/`, `assets/shaders/menu_title_v8.*`, `assets/shaders/opening_rpg_water_v11.*`
- `art/pixelorama/menu_v8/`, `opening_rpg_v11/`, `opening_boat_v12/`, `fisherman_v*/`, `port_v7/port_title_v7.pxo`, `port_v7/senu_portrait_v7.pxo`
- `tools/pixelorama/build_menu_*`, `build_opening_*`, `build_fisherman_*`, `export_menu_*`, `export_opening_*`, `export_fisherman_*`, `tools/ui/`
- `tests/hud_v6_test.gd`, `tests/opening_*`, `tests/viewport_v8_test.gd`
- `docs/ABERTURA_RPG_V11.md`, `docs/CUTSCENE_ABERTURA_V9.md`
- `ABRIR_ABERTURA/BARCO/PESCADOR/MENU/RETRATO/CAPA_PIXELORAMA.cmd`, `EXPORTAR_ABERTURA.cmd`, `EXPORTAR_MENU.cmd`, `EXPORTAR_RETRATO.cmd`

## Arquivos compartilhados

Estes arquivos são usados por todas as zonas. Regra: **um por vez**. Avise no chat antes ("vou mexer no `port_demo.gd`") e depois ("liberei, já está na develop").

| Arquivo | Por que é sensível | Como mexer |
|---|---|---|
| `scripts/world/port_demo.gd` | Cena principal: monta o mundo, cria inimigos e itens, puzzles, selos, habilidades, save e abertura. Todo recurso novo passa por ele. | Coloque a lógica no arquivo da sua zona e só chame daqui. Acrescente funções no fim; não reorganize nem reformate o que já existe. |
| `scripts/save/save_store.gd` | Formato do save; qualquer recurso pode criar um campo novo. | Só acrescente campos; nunca renomeie nem remova. Rode `progression_test` e `save_migration_test`. |
| `scripts/core/input_bindings.gd` | Controles do jogo. | Avise qual tecla vai usar antes, para não repetir. |
| `project.godot`, `scenes/boot/main.tscn` | O Godot altera sozinho ao abrir o editor. | Não faça commit de mudanças que você não fez de propósito (`git restore project.godot`). |
| `README.md`, `docs/PROGRESSO.md`, `docs/TESTES.md`, `docs/DECISOES.md`, `docs/REFINAMENTO_V8.md`, `docs/O_NONO_VEU_GDD.md` | Os dois escrevem neles. | Acrescente no fim, numa seção com data e nome. Não reescreva parágrafos do outro. |
| `.gitignore`, `.gitattributes`, `EXPORTAR_MAPA.cmd`, este arquivo | Configuração comum; `EXPORTAR_MAPA.cmd` exporta mapa, capa e retrato juntos. | Só com acordo dos dois. |

## Arquivos binários

`.pxo`, `.png`, `.blend` e `.pyc` não podem ser juntados pelo Git. Se os dois editarem o mesmo, um dos dois perde o trabalho.

- Só o responsável da zona edita esses arquivos.
- Para mudar a arte de outra zona, combine antes ou crie uma versão nova (`v13`), como o projeto já faz.
- Os scripts `EXPORTAR_*.cmd` regeneram PNGs e reimportam no Godot. Antes do commit, desfaça o que não é da sua zona: `git restore <arquivo>`.
- Se houver conflito em binário, não há junção: escolha uma versão (`git checkout --ours <arquivo>` ou `--theirs`) e refaça a outra mudança à mão.

## Arquivos gerados pelo Godot

- `*.import` e `*.uid` entram no commit junto com o asset ou script que os gerou.
- Não faça commit de `.import` de assets que você não alterou; uma reimportação pode reescrevê-los.
- Os dois devem usar as mesmas versões: **Godot 4.7.2** e **Pixelorama 1.2.3**, nos caminhos de Downloads esperados pelos atalhos `.cmd`. Versões diferentes reescrevem `project.godot` e os `.import`.

## Ajustes pendentes no repositório

Encontrados na análise de 27/10/2026. Combinar antes de aplicar, pois mexem em arquivos compartilhados.

1. `.gitignore` tem `qa/`, que também ignora `tools/qa/`. Por isso `tools/qa/capture_enemy_motion_v12.gd`, citado em `docs/INIMIGOS_MOVIMENTO_V12.md`, não foi para o GitHub. Trocar por `/qa/` e o Kauã enviar o arquivo.
2. `tools/pixelorama/__pycache__/*.pyc` está versionado. Rodar qualquer script Python gera diferença binária. Acrescentar `__pycache__/` ao `.gitignore` e executar `git rm -r --cached tools/pixelorama/__pycache__`.
3. `.gitattributes`: acrescentar `*.pxo binary` para deixar explícito.
4. No GitHub, o dono do repositório (Kauã) pode proteger `main` e `develop` em *Settings → Branches*, exigindo PR para entrar.
