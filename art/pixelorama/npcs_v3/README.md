# Moradores e Ankhet — sprites reimaginados v3

O remador tem silhueta magra, cabelo curto e rosto sem barba; a aparência de Nakht permanece exclusiva do ferreiro. Substitui a arte simplificada dos 12 tipos de moradores/vendedores do catálogo e de Ankhet. Hori, Sabu, Merit, Nakht, Adiam e Tarek já usam a arte detalhada de `interiors_v4` e foram preservados. As instâncias do mapa continuam compartilhando as mesmas aparências do catálogo; IDs, rotinas, missões e colisões não mudam.

## Fontes e padrão

- `sources/*.png`: 13 folhas novas geradas com ImageGen integrado. Os prompts completos ficam ao lado de cada folha (`*.prompt.txt` ou `*_prompt.txt`). Referência visual: os NPCs nomeados de `art/pixelorama/interiors_v2/sources/npcs_key.png`.
- Cada morador tem 16 desenhos completos: repouso, quatro passos, conversa, repouso com carga, quatro passos com carga, curvar-se, respirar, piscar, respirar com carga e piscar com carga. Ankhet tem repouso, respiração, piscada e gesto.
- `townsfolk_v3.pxo`: 192 cels de 64×64, pivô nos pés (32,58), 16 colunas e uma tag por aparência. O canvas maior é margem transparente para mãos/cargas, sem ampliar o personagem ou sua colisão. Altura de repouso próxima de 44 pixels; escala única por personagem na preparação.
- `ankhet_v3.pxo`: quatro cels de 128×144, pivô (64,112), cajado apoiado no chão.
- Paleta de 33 cores do Porto/interiores, alpha binário, nearest e desenho no tamanho nativo. O importador alinha desenhos completos por translações inteiras, não estica partes. Os últimos dezoito pixels de pernas/barra e apoio dos estados de repouso são compartilhados para evitar pés/barra tremendo. Registros e hashes ficam nos planos JSON.

## Editar e exportar

Abra os `.pxo` no Pixelorama. Após edições manuais, execute **apenas** `tools/pixelorama/export_npcs_v3.ps1`: exporta PNG + JSON pelo Pixelorama 1.2.3, copia os manifestos e importa no Godot 4.7.2. O jogo usa `assets/world/townsfolk_v3.png` e `ankhet_v3.png`.

`tools/pixelorama/build_npcs_v3.py` é o construtor de produção inicial. Ele exige Pillow e não sobrescreve os projetos v3 existentes sem `--force`. Não reconstrua sobre trabalho manual. `--only nome` gera apenas uma prancha de diagnóstico; `--update remador` substitui somente as 16 poses do remador, guarda uma cópia em QA e confere que os demais cels e Ankhet continuam idênticos; registros opcionais em `sources/registrations.json` ajustam recortes e pivôs sem editar as fontes. Versões anteriores permanecem intactas.

## Conferir

- `tests/npc_sprites_v3_test.gd`: contrato dos atlases/fontes/cels, cores, transparência, recortes, índices e pés de repouso, sem carregar mundo ou save.
- `tests/port_life_test.gd -- --qa` e `tests/isle_test.gd -- --qa`: integração com rotinas/comércio/ilha em slots exclusivos de QA.
- `tests/npc_sprites_v3_preview.gd -- --qa`: Godot gráfico, seis capturas reais do mercado/cais/Ankhet em `qa/npcs_v3/`.
- Pranchas/GIF: `qa/npcs_v3/residents_idle.png`, `residents_idle.gif`, `residents_poses.png` e `old_vs_new.png`. São prévias da arte já reduzida para a escala do jogo, não apenas das folhas grandes.
